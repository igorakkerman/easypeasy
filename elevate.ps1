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
        Runs the given command with its arguments as administrator through the Windows sudo command,
        forced into inline mode (sudo --inline) so it runs in the current terminal instead of a
        separate window, whatever mode sudo is configured for. Windows prompts for confirmation with a
        User Account Control dialog. Waits for the command to finish and reports a terminating error if
        it fails - a terminating error or a non-zero exit code, but not a non-terminating error on its own.

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
        Requires the Windows sudo feature.
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
        # --inline forces sudo to run in the current terminal, whatever mode the system is configured for
        sudo --inline $powershell -NoProfile -EncodedCommand $encodedCommand
        if ($LASTEXITCODE -ne 0) {
            Write-Error "Elevated command failed. exitCode: $LASTEXITCODE, command: $line" -ErrorAction Stop
        }
    }
}

New-Alias -Name sudops -Value Invoke-Elevated -ErrorAction SilentlyContinue | Out-Null
New-Alias -Name sups -Value Invoke-Elevated -ErrorAction SilentlyContinue | Out-Null
