function Assert-Administrator {
    [CmdletBinding()]
    param ()

    $identity = [Security.Principal.WindowsPrincipal] [System.Security.Principal.WindowsIdentity]::GetCurrent()
    if (! $identity.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)) {
        Write-Error "This operation requires administrator privileges." -ErrorAction Stop
    }
}

function Invoke-Elevated {
    <#
    .SYNOPSIS
        Runs a command as administrator using sudo.

    .DESCRIPTION
        Runs the given command with its arguments in an elevated PowerShell session via the Windows
        sudo command (sudo pwsh -NoProfile -Command ...). Windows prompts for confirmation with a
        User Account Control dialog. Requires the Windows sudo feature to be installed and enabled.

        Arguments are passed through as typed. An argument that contains whitespace is single-quoted
        so it reaches the elevated session as a single token.

    .PARAMETER Command
        The command to run elevated, followed by its arguments, exactly as it would be typed at the prompt.

    .EXAMPLE
        Invoke-Elevated addpath -Machine 'C:\Tools'

    .EXAMPLE
        sudops setenv -Machine JAVA_HOME 'C:\Java\jdk-21'

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
        sudo pwsh -NoProfile -Command $line
    }
}

New-Alias -Name sudops -Value Invoke-Elevated -ErrorAction SilentlyContinue | Out-Null
New-Alias -Name sups -Value Invoke-Elevated -ErrorAction SilentlyContinue | Out-Null

