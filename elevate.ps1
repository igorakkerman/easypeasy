function Test-Elevated {
    <#
    .SYNOPSIS
        Tests whether the current session runs as administrator.

    .DESCRIPTION
        Returns whether the current session is elevated, so a caller can offer an unelevated path
        instead of failing. Assert-Elevated reports an error instead.

    .OUTPUTS
        Boolean indicating whether the current session runs as administrator.

    .EXAMPLE
        Test-Elevated

    .EXAMPLE
        if (-not (Test-Elevated)) { Invoke-Elevated Restart-Service -Name Spooler }
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param ()

    $identity = [Security.Principal.WindowsPrincipal] [System.Security.Principal.WindowsIdentity]::GetCurrent()
    return $identity.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Assert-Elevated {
    <#
    .SYNOPSIS
        Requires the current session to run as administrator.

    .DESCRIPTION
        Reports a terminating error when the current session is not elevated, ending a command that has
        no unelevated path. An elevated session passes silently. Test-Elevated returns the state instead.

    .EXAMPLE
        Assert-Elevated
    #>
    [CmdletBinding()]
    param ()

    if (! (Test-Elevated)) {
        Write-Error "Operation requires administrator privileges." `
            -ErrorId "ElevationRequired" `
            -Category PermissionDenied `
            -TargetObject ([System.Security.Principal.WindowsIdentity]::GetCurrent().Name) `
            -ErrorAction Stop
    }
}

function local:Get-SudoModeValue {
    <#
    .SYNOPSIS
        Reads the sudo mode from a registry key.

    .DESCRIPTION
        Returns the Enabled value of the given machine key, or $null where key or value is missing.

    .PARAMETER Key
        Machine registry key holding the value, without the hive.

    .OUTPUTS
        Mode as integer, or $null where key or value is missing.

    .EXAMPLE
        Get-SudoModeValue -Key "SOFTWARE\Policies\Microsoft\Windows\Sudo"
    #>
    [CmdletBinding()]
    [OutputType([int])]
    param (
        [Parameter(Mandatory)]
        [string] $Key
    )

    return [Microsoft.Win32.Registry]::GetValue("HKEY_LOCAL_MACHINE\$Key", "Enabled", $null)
}

function local:Assert-SudoAvailable {
    <#
    .SYNOPSIS
        Requires the Windows sudo feature to be usable.

    .DESCRIPTION
        Reports a terminating error when Invoke-Elevated could not elevate: sudo missing from the system,
        the sudo feature switched off in Settings or by group policy, or its mode capped below the inline
        mode the elevation runs in. A command that will elevate asserts before it reads or writes anything,
        so an impossible elevation fails it up front rather than halfway through.

    .EXAMPLE
        Assert-SudoAvailable

    .EXAMPLE
        if ($Machine -and -not (Test-Elevated)) { Assert-SudoAvailable }
    #>
    [CmdletBinding()]
    param ()

    if (-not (Get-Command sudo -ErrorAction SilentlyContinue)) {
        Write-Error "Elevation denied: sudo not found." `
            -ErrorId "SudoNotAvailable" `
            -Category NotInstalled `
            -TargetObject "sudo" `
            -ErrorAction Stop
    }

    # the values sudo itself reads: Settings writes the first, group policy the second.
    # Each names a mode - 0 disabled, 1 new window, 2 input closed, 3 inline - capped at 3.
    # Sudo takes an unset toggle for disabled, an unset policy for every mode allowed,
    # and runs in the lower of the two.
    $settingValue = Get-SudoModeValue -Key "SOFTWARE\Microsoft\Windows\CurrentVersion\Sudo"
    $policyValue = Get-SudoModeValue -Key "SOFTWARE\Policies\Microsoft\Windows\Sudo"

    $setting = $null -eq $settingValue ? 0 : [Math]::Min([int] $settingValue, 3)
    $policy = $null -eq $policyValue ? 3 : [Math]::Min([int] $policyValue, 3)
    $mode = [Math]::Min($setting, $policy)

    if ($mode -le 0) {
        Write-Error "Elevation denied: sudo disabled. mode: $mode, setting: $setting, policy: $policy" `
            -ErrorId "SudoDisabled" `
            -Category NotEnabled `
            -TargetObject "sudo" `
            -ErrorAction Stop
    }

    # elevation runs sudo --inline, the mode sudo calls Normal
    if ($mode -lt 3) {
        Write-Error "Elevation denied: sudo inline mode forbidden. mode: $mode, setting: $setting, policy: $policy" `
            -ErrorId "SudoInlineNotAllowed" `
            -Category NotEnabled `
            -TargetObject "sudo" `
            -ErrorAction Stop
    }
}

function local:ConvertTo-ElevatedCommand {
    <#
    .SYNOPSIS
        Builds the command line that re-runs a command in an elevated session.

    .DESCRIPTION
        Returns the command name followed by the parameters it was called with, as a string array ready
        for Invoke-Elevated. A switch contributes its name alone and only where it is present; every
        other parameter contributes its name and its value. Common parameters are left out, the elevated
        session taking its own.

    .PARAMETER Name
        Name of the command to re-run, as the elevated session resolves it - an exported one.

    .PARAMETER BoundParameters
        The calling command's $PSBoundParameters.

    .OUTPUTS
        The command and its arguments as a string array.

    .EXAMPLE
        Invoke-Elevated (ConvertTo-ElevatedCommand -Name New-StartMenuShortcut -BoundParameters $PSBoundParameters)
    #>
    [CmdletBinding()]
    [OutputType([string[]])]
    param (
        [Parameter(Mandatory)]
        [string] $Name,
        [Parameter(Mandatory)]
        [System.Collections.IDictionary] $BoundParameters
    )

    $common = @([System.Management.Automation.PSCmdlet]::CommonParameters) +
        @([System.Management.Automation.PSCmdlet]::OptionalCommonParameters)

    $command = @($Name)

    foreach ($parameter in $BoundParameters.GetEnumerator()) {
        if ($parameter.Key -in $common) {
            continue
        }

        if ($parameter.Value -is [switch]) {
            if ($parameter.Value.IsPresent) {
                $command += "-$($parameter.Key)"
            }
            continue
        }

        $command += "-$($parameter.Key)"
        $command += [string] $parameter.Value
    }

    # comma keeps the array whole where the caller assigns a single value
    return , $command
}

# one literal argument on a command line: single-quoted, embedded single quote doubled
function local:quote($Value) {
    return "'{0}'" -f ($Value -replace "'", "''")
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

        Every argument is single-quoted, and an embedded single quote doubled, so it reaches the
        elevated session as one literal token whatever it holds - whitespace, a semicolon or a quote.
        An argument that is itself a collection is quoted element by element and joined with commas,
        so it reaches the elevated session as one array argument.
        The command name itself and anything written as a parameter, -Like -This, are passed through
        as typed, so the elevated session parses them as the command and its parameters.

    .PARAMETER Command
        The command to run elevated, followed by its arguments, exactly as it would be typed at the prompt.
        An argument may be a collection, passed on as an array argument.

    .EXAMPLE
        Invoke-Elevated New-Item -ItemType Directory 'C:\Program Files\MyTool'

    .EXAMPLE
        Invoke-Elevated Remove-SystemPathLocation -Location @('C:\Tools\bin', 'C:\Other\bin') -Machine

    .EXAMPLE
        sudops Restart-Service -Name Spooler

    .NOTES
        Aliases: sudops, sups
        Requires the Windows sudo feature.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param (
        [Parameter(Mandatory, Position = 0, ValueFromRemainingArguments = $true)]
        [object[]] $Command
    )

    # the command name and parameter names have to stay bare to parse as such; every other argument is
    # quoted literally, so a semicolon, a space or a quote in a value cannot reach the child as syntax
    $arguments = @(
        $Command `
            | Select-Object -Skip 1 `
            | ForEach-Object {
                if ($_ -is [string] -and $_ -match '^-\w') {
                    $_
                }
                elseif ($_ -isnot [string] -and $_ -is [System.Collections.IEnumerable]) {
                    # a collection argument stays one argument: its elements are quoted and comma-joined,
                    # the syntax an array argument is written in
                    (@($_) | ForEach-Object { quote -Value $_ }) -join ','
                }
                else {
                    quote -Value $_
                }
            }
    )
    $line = (@($Command[0]) + $arguments) -join ' '

    if ($PSCmdlet.ShouldProcess($line, "Run elevated")) {
        Assert-SudoAvailable
        # only a real failure sets the exit code: a terminating error - including a command the elevated
        # session cannot resolve, which would otherwise fall through to a successful exit - or a native
        # non-zero exit. A non-terminating error alone does not, and an unset $LASTEXITCODE after a
        # cmdlet means success rather than failure.
        $script = "try { $line } catch { Write-Error -ErrorRecord `$_; exit 1 }; exit (`$LASTEXITCODE ?? 0)"
        $encodedCommand = [Convert]::ToBase64String([System.Text.Encoding]::Unicode.GetBytes($script))
        $powershell = (Get-Process -Id $PID).Path
        # --inline forces sudo to run in the current terminal, whatever mode the system is configured for
        sudo --inline $powershell -NoProfile -EncodedCommand $encodedCommand
        if ($LASTEXITCODE -ne 0) {
            Write-Error "Elevated command failed. exitCode: $LASTEXITCODE, command: $line" `
                -ErrorId "ElevatedCommandFailed" `
                -Category OperationStopped `
                -TargetObject $line `
                -ErrorAction Stop
        }
    }
}

New-Alias -Name sudops -Value Invoke-Elevated -ErrorAction SilentlyContinue | Out-Null
New-Alias -Name sups -Value Invoke-Elevated -ErrorAction SilentlyContinue | Out-Null
