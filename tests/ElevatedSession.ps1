# Stands in for the elevated session sudo opens: the encoded payload Invoke-Elevated builds is decoded and
# run in a separate runspace, unelevated, with the module imported. Everything below Invoke-Elevated -
# quoting, collection joining, encoding, exit code - runs for real, and a test asserts what that session
# wrote. The runspace carries no mocks and no test state, so a payload that leans on either fails here as
# it would in the real child.
#
#   BeforeAll { . "$PSScriptRoot/../ElevatedSession.ps1"; Initialize-ElevatedSession }
#   AfterAll  { Remove-ElevatedSession }
#   BeforeEach {
#       Mock -ModuleName easypeasy Test-Elevated { $false }
#       Mock -ModuleName easypeasy sudo -MockWith $sudoMock
#       Mock -ModuleName easypeasy Get-SudoModeValue { 3 }
#   }
#
# Helpers and runspace are global: a function dot-sourced into BeforeAll lives in that scope alone, and the
# mock body reads the runspace from another scope again.

# resolved while this file runs: $PSScriptRoot inside a global function resolves against the caller,
# which would name the spec folder and let the runspace fall back to the installed module
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
