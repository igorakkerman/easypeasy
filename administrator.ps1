function local:Test-Elevated {
    $identity = [Security.Principal.WindowsPrincipal] [System.Security.Principal.WindowsIdentity]::GetCurrent()
    return $identity.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Assert-Administrator {
    [CmdletBinding()]
    param ()

    if (! (Test-Elevated)) {
        Write-Error "This operation requires administrator privileges." -ErrorAction Stop
    }
}

function Invoke-Elevated {
    <#
    .SYNOPSIS
        Runs a command as administrator.

    .DESCRIPTION
        Runs the given command with its arguments in an elevated PowerShell session via
        Start-Process -Verb RunAs. Windows prompts for confirmation with a User Account Control
        dialog and the elevated session runs in its own window. Waits for the session to finish and
        reports a terminating error if the elevated command fails - a terminating error or a non-zero
        exit code, but not a non-terminating error on its own.

        Arguments are passed through as typed. An argument that contains whitespace is single-quoted
        so it reaches the elevated session as a single token.

    .PARAMETER Command
        The command to run elevated, followed by its arguments, exactly as it would be typed at the prompt.

    .EXAMPLE
        Invoke-Elevated New-Item -ItemType Directory 'C:\Program Files\MyTool'

    .EXAMPLE
        sudops Restart-Service -Name Spooler

    .NOTES
        Aliases: sudops, sups
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param (
        [Parameter(Mandatory = $true, Position = 0, ValueFromRemainingArguments = $true)]
        [string[]] $Command
    )

    $line = ($Command | ForEach-Object { if ($_ -match '\s') { "'$_'" } else { $_ } }) -join ' '

    if ($PSCmdlet.ShouldProcess($line, "Run elevated")) {
        # exit $LASTEXITCODE so only a real failure - a terminating error or a native non-zero exit -
        # sets the exit code; a non-terminating error alone would otherwise make -Command exit 1
        $script = "$line; exit `$LASTEXITCODE"
        $encodedCommand = [Convert]::ToBase64String([System.Text.Encoding]::Unicode.GetBytes($script))
        $powershell = (Get-Process -Id $PID).Path
        $process = Start-Process -FilePath $powershell -Verb RunAs -Wait -PassThru `
            -ArgumentList "-NoProfile", "-EncodedCommand", $encodedCommand
        if ($process.ExitCode -ne 0) {
            Write-Error "Elevated command failed with exit code $($process.ExitCode): $line" -ErrorAction Stop
        }
    }
}

New-Alias -Name sudops -Value Invoke-Elevated -ErrorAction SilentlyContinue | Out-Null
New-Alias -Name sups -Value Invoke-Elevated -ErrorAction SilentlyContinue | Out-Null
