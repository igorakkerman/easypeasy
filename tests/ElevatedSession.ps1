# Test double for the elevated session.
# Production code calls `sudo --inline`.
# This file defines `$sudoMock`.
# A spec registers it as `Mock ... sudo -MockWith $sudoMock`,
# so that, when we test code that runs `sudo`, no elevated process starts and no UAC prompt opens.
# A spec that forgets this registration does not reach the real `sudo` either:
# `Initialize-ElevatedSession` defines a global `sudo` function, which shadows `sudo.exe` and
# throws "sudo called without a mock" as soon as tested code calls `sudo`.

# The `sudo` command accepts a command line as its parameters. 
# $sudoMock decodes that command line and runs it in a separate runspace,
# unelevated, with easypeasy imported,
# then sets $LASTEXITCODE from the payload error stream - 1 on error, 0 otherwise.
# Invoke-Elevated reads this value back when it calls `$sudoMock` as the mock's response.

# Payload runs in the runspace, outside the test session. This means, 
# if the spec calls `Invoke-Elevated My-FunctionUnderTest`
# and `My-FunctionUnderTest` calls `My-HelperFunction`, then
# - `My-HelperFunction` cannot be mocked, the real function will be called
# - `Should -Invoke ... My-HelperFunction` cannot be used for assertions
# - a spec variable cannot be passed to `My-HelperFunction`, only arguments given to `Invoke-Elevated`
#   reach the payload, and they arrive as text
# - `$env:MY_VARIABLE` or the working directory can be set, both process-wide,
#   and `My-HelperFunction` reads them
#
# A spec testing a command that elevates contains:
#
#   BeforeAll { . "$PSScriptRoot/../ElevatedSession.ps1"; Initialize-ElevatedSession }
#   AfterAll  { Remove-ElevatedSession }
#   BeforeEach {
#       Mock -ModuleName easypeasy Test-Elevated { $false }
#       Mock -ModuleName easypeasy sudo -MockWith $sudoMock
#       InModuleScope easypeasy { Mock Get-SudoModeValue { [SudoMode]::Inline } }
#   }
#
# Helpers and runspace are global:
# a function dot-sourced into BeforeAll lives in that scope alone,
# and the mock body reads the runspace from another scope again.

$global:elevatedModulePath = (Resolve-Path "$PSScriptRoot\..\easypeasy.psd1").Path

function global:Initialize-ElevatedSession {
    # placeholder command for Pester to mock and Get-Command sudo to find, where the host has no sudo
    # feature; a call reaching it names the spec that forgot the mock
    Set-Item -Path function:global:sudo -Value { throw "sudo called without a mock" }

    $global:elevatedRunspace = [powershell]::Create()
    $global:elevatedRunspace.AddScript("Import-Module '$global:elevatedModulePath' -Force").Invoke() | Out-Null

    $importError = $global:elevatedRunspace.Streams.Error | Select-Object -First 1
    if ($importError) {
        throw "Elevated session could not import the module under test: $importError"
    }

    $global:elevatedRunspace.Commands.Clear()
}

function global:Remove-ElevatedSession {
    if ($global:elevatedRunspace) {
        $global:elevatedRunspace.Dispose()
        Remove-Variable -Name elevatedRunspace -Scope Global
    }

    if (Test-Path function:global:sudo) {
        Remove-Item -Path function:global:sudo
    }
}

$script:sudoMock = {
    # sudo --inline <powershell> -NoProfile -EncodedCommand <payload>
    $payload = [System.Text.Encoding]::Unicode.GetString([Convert]::FromBase64String($args[-1]))

    $global:elevatedRunspace.Commands.Clear()
    $global:elevatedRunspace.Streams.ClearStreams()
    $global:elevatedRunspace.AddScript($payload).Invoke() | Out-Null

    $payloadError = $global:elevatedRunspace.Streams.Error | Select-Object -First 1
    if ($payloadError) {
        Write-Warning "Elevated payload wrote an error: $payloadError"
    }

    # the payload exits 1 on a terminating error, which Invoke-Elevated reports as ElevatedCommandFailed
    $global:LASTEXITCODE = $payloadError ? 1 : 0
}
