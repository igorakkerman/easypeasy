class EnvironmentVariable {

    [string] $Scope
    [ValidateNotNullOrEmpty()] [string] $Name
    [string] $Value

    EnvironmentVariable($Scope, $Name, $Value) {
        $this.Scope = $Scope
        $this.Name = $Name
        $this.Value = $Value
    }

    <#
    .SYNOPSIS
        An environment variable and the scope it belongs to.
    .DESCRIPTION
        Holds an environment variable's name and value together with its scope:
        'Machine' (local machine) or 'User' (current user).
    .EXAMPLE
        $variable = [EnvironmentVariable]::new("User", "GOPATH", "C:\Go")
    #>
}

function local:Sync-ProcessEnvironmentVariable {
    <#
    .SYNOPSIS
        Updates the current process environment variable to the value in effect.
    .DESCRIPTION
        Recomputes the value a fresh process would resolve - the user value over the machine value -
        and applies it to the current process, so a persisted change takes effect immediately.
        PATH is left untouched: it is composed of several scopes and may carry process-only entries,
        so the system-path functions keep the current process PATH in sync themselves.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string] $Name
    )

    if ($Name -ieq "Path") {
        return
    }

    $userValue = Get-EnvironmentVariable -Name $Name -User -ErrorAction SilentlyContinue
    $machineValue = Get-EnvironmentVariable -Name $Name -Machine -ErrorAction SilentlyContinue

    # a $null value removes the variable from the current process
    Set-Item -Path "env:$Name" -Value ($userValue ?? $machineValue)
}

function Get-EnvironmentVariable() {
    <#
    .SYNOPSIS
        Returns the value of an environment variable.

    .DESCRIPTION
        Returns the value of the specified environment variable, 
        either in the machine environment, the user environment, or the value in effect.

    .PARAMETER Name
        The name of the environment variable.

    .PARAMETER Machine
        If specified, the value of the environment variable in the machine environment is returned.

    .PARAMETER User
        If specified, the value of the environment variable in the user environment is returned.

    .PARAMETER Effective
        If specified, the value of the environment variable is returned which is in effect. (Default.)

    .OUTPUTS string - The value of the environment variable.

    .NOTES
        Alias: getenv

    .EXAMPLE
        Get-EnvironmentVariable "TEMP"

    .EXAMPLE
        Get-EnvironmentVariable "TEMP" -Effective

    .EXAMPLE
        Get-EnvironmentVariable "TEMP" -Machine

    .EXAMPLE
        Get-EnvironmentVariable -Name "TEMP"

    .EXAMPLE
        Get-EnvironmentVariable -Name "TEMP" -User
    #>
    [CmdletBinding()]
    param(
        [Parameter(Position = 0, Mandatory = $true)]
        [string] $Name,

        [Parameter(Mandatory = $true, ParameterSetName = "Machine")]
        [switch] $Machine,

        [Parameter(Mandatory = $true, ParameterSetName = "User")]
        [switch] $User,

        [Parameter(Mandatory = $false, ParameterSetName = "Effective")]
        [switch] $Effective
    )

    $value = 
    if ($Machine) {
        [Environment]::GetEnvironmentVariable($Name, [System.EnvironmentVariableTarget]::Machine)
    }
    elseif ($User) {
        [Environment]::GetEnvironmentVariable($Name, [System.EnvironmentVariableTarget]::User)        
    }
    else {
        (Get-Item env:$Name -ErrorAction SilentlyContinue)?.Value
    }

    if ($null -eq $value) {
        $errorRecord = [System.Management.Automation.ErrorRecord]::new(
            [System.Management.Automation.ItemNotFoundException]::new("Environment variable not found: $Name"),
            "EnvironmentVariableNotFound",
            [System.Management.Automation.ErrorCategory]::ObjectNotFound,
            $Name
        )
        $PSCmdlet.WriteError($errorRecord)
        return
    }

    if ([string]::IsNullOrWhiteSpace($value)) {
        Write-Warning "Environment variable has a blank value. name: $Name, value: '$value'"
    }

    return $value
}

function Get-Environment() {
    <#
    .SYNOPSIS
        Returns the environment variables of a scope.

    .DESCRIPTION
        Returns environment variables as EnvironmentVariable records, each carrying its Name, Value and Scope.
        Both the machine and the user environment are returned by default; pass -Machine or -User for one scope.
        Records are ordered by name; where both scopes define a variable the user record comes first,
        since the user value is the one in effect. PATH is the exception - the machine and user paths are
        combined, machine first.

    .PARAMETER Machine
        If specified, the environment variables of the machine environment are returned.

    .PARAMETER User
        If specified, the environment variables of the user environment are returned.

    .OUTPUTS
        EnvironmentVariable records with a Scope, Name and Value property.

    .EXAMPLE
        Get-Environment

    .EXAMPLE
        Get-Environment -Machine

    .EXAMPLE
        Get-Environment -User
    #>
    [CmdletBinding()]
    param(
        [switch] $Machine,

        [switch] $User
    )

    # both scopes by default (neither or both switches)
    if ($Machine -eq $User) {
        $Machine = $true
        $User = $true
    }

    $targets = [ordered] @{}
    if ($Machine) { $targets["Machine"] = [System.EnvironmentVariableTarget]::Machine }
    if ($User) { $targets["User"] = [System.EnvironmentVariableTarget]::User }

    $variables = foreach ($scope in $targets.Keys) {
        [Environment]::GetEnvironmentVariables($targets[$scope]).GetEnumerator() `
        | ForEach-Object { [EnvironmentVariable]::new($scope, $_.Key, $_.Value) }
    }

    # by name, descending scope putting User before Machine where both scopes define the same variable
    $variables | Sort-Object -Property Name, @{ Expression = "Scope"; Descending = $true }
}

function Set-EnvironmentVariable() {
    <#
    .SYNOPSIS
        Sets the value of an environment variable.

    .DESCRIPTION
        Sets the value of the specified environment variable,
        either in the machine scope or the user scope.
        The change also takes effect in the current process immediately.

    .PARAMETER Name
        The name of the environment variable.

    .PARAMETER Value
        The value to set the environment variable to.

    .PARAMETER Machine
        If specified, the environment variable is set in the machine scope.

    .PARAMETER User
        If specified, the environment variable is set in the user scope. (Default.)

    .PARAMETER Expand
        If specified, the value is written as an expandable (REG_EXPAND_SZ) value, so a
        %...% reference in it (for example %USERPROFILE%\tmp) is kept as indirection and
        expanded on read. Without it, the value is written verbatim as REG_SZ.

    .NOTES
        Alias: setenv
        Default scope is User.

    .EXAMPLE
        Set-EnvironmentVariable -Name "JAVA_HOME" -Value "C:\Java\JDK" -Machine

    .EXAMPLE
        Set-EnvironmentVariable -Name "TMP" -Value "%USERPROFILE%\tmp" -Expand

    .EXAMPLE
        Set-EnvironmentVariable -Name "GOPATH" -Value "C:\Go\GOPATH" -User
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Position = 0, Mandatory = $true)]
        [string] $Name,

        [Parameter(Position = 1, Mandatory = $true)]
        [string] $Value,

        [Parameter(Mandatory = $true, ParameterSetName = "Machine")]
        [switch] $Machine,

        [Parameter(Mandatory = $false, ParameterSetName = "User")]
        [switch] $User,

        [switch] $Expand
    )

    # an expandable (REG_EXPAND_SZ) write is delegated to the dedicated writer, which owns
    # its own ShouldProcess, auto-elevation and current-process sync
    if ($Expand) {
        $scopeSwitch = $Machine ? @{ Machine = $true } : @{ User = $true }
        Set-EnvironmentVariableExpanded -Name $Name -Value $Value @scopeSwitch
        return
    }

    if ($Machine) {
        $environment = [System.EnvironmentVariableTarget]::Machine
        $scope = "Machine"
    }
    # User is the default
    else {
        $environment = [System.EnvironmentVariableTarget]::User
        $scope = "User"
    }

    if ($PSCmdlet.ShouldProcess($Name, "Set environment variable in the ${scope} scope")) {
        # when not already elevated, a machine write runs in an elevated process instead of in-process
        if ($Machine -and -not (Test-Elevated)) {
            Invoke-Elevated Set-EnvironmentVariable -Name $Name -Value $Value -Machine
        }
        else {
            [Environment]::SetEnvironmentVariable($Name, $Value, $environment)
        }
        Sync-ProcessEnvironmentVariable -Name $Name
    }
}

function Remove-EnvironmentVariable() {
    <#
    .SYNOPSIS
        Removes an environment variable.

    .DESCRIPTION
        Removes the specified environment variable,
        either from the machine scope or the user scope.
        The change also takes effect in the current process immediately.

    .PARAMETER Name
        The name of the environment variable.

    .PARAMETER Machine
        If specified, the environment variable is removed from the machine scope.

    .PARAMETER User
        If specified, the environment variable is removed from the user scope. (Default.)

    .NOTES
        Alias: rmenv
        Default scope is User.

    .EXAMPLE
        Remove-EnvironmentVariable -Name "JAVA_HOME" -Machine

    .EXAMPLE
        Remove-EnvironmentVariable -Name "GOPATH" -User
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Position = 0, Mandatory = "true")]
        [string] $Name,

        [Parameter(Mandatory = $true, ParameterSetName = "Machine")]
        [switch] $Machine,

        [Parameter(Mandatory = $false, ParameterSetName = "User")]
        [switch] $User
    )

    if ($Machine) {
        $environment = [System.EnvironmentVariableTarget]::Machine
        $scope = "Machine"
    }
    # User is default
    else {
        $environment = [System.EnvironmentVariableTarget]::User
        $scope = "User"
    }

    # idempotent: nothing to remove means the variable is not set in this scope
    $scopeSwitch = $Machine ? @{ Machine = $true } : @{ User = $true }
    if ($null -eq (Get-EnvironmentVariable -Name $Name @scopeSwitch -ErrorAction SilentlyContinue)) {
        Write-Warning "Environment variable is not set. scope: $scope, name: $Name"
        return
    }

    if ($PSCmdlet.ShouldProcess($Name, "Remove environment variable from the ${scope} scope")) {
        # when not already elevated, a machine write runs in an elevated process instead of in-process
        if ($Machine -and -not (Test-Elevated)) {
            Invoke-Elevated Remove-EnvironmentVariable -Name $Name -Machine
        }
        else {
            # [NullString]::Value binds to a genuine null; [string] $null would coerce to "", leaves a registry tombstone instead of deleting
            [Environment]::SetEnvironmentVariable($Name, [NullString]::Value, $environment)
        }
        Sync-ProcessEnvironmentVariable -Name $Name
    }
}

New-Alias -Name getenv -Value Get-EnvironmentVariable -ErrorAction SilentlyContinue | Out-Null
New-Alias -Name setenv -Value Set-EnvironmentVariable -ErrorAction SilentlyContinue | Out-Null
New-Alias -Name rmenv -Value Remove-EnvironmentVariable -ErrorAction SilentlyContinue | Out-Null

# --- expandable (REG_EXPAND_SZ) writes ------------------------------------------
#
# Writing an environment variable as REG_EXPAND_SZ. [Environment]::SetEnvironmentVariable
# can only ever write REG_SZ, so the persist step goes directly against the registry, and
# the WM_SETTINGCHANGE broadcast that .NET gave for free is re-added by hand.

function local:Set-EnvironmentVariableExpanded {
    <#
    .SYNOPSIS
        Sets an environment variable as an expandable (REG_EXPAND_SZ) value.

    .DESCRIPTION
        Sets the value of the specified environment variable in the machine scope or the
        user scope, persisting it as REG_EXPAND_SZ so that %...% references (for example
        %USERPROFILE%\tmp) stay as indirection and are expanded when a process reads them.
        [Environment]::SetEnvironmentVariable always writes REG_SZ and so cannot do this;
        this function writes the registry directly and broadcasts WM_SETTINGCHANGE.
        The change also takes effect in the current process immediately.

    .PARAMETER Name
        The name of the environment variable.

    .PARAMETER Value
        The value to set. A %...% reference is stored literally and expanded on read.

    .PARAMETER Machine
        If specified, the environment variable is set in the machine scope.

    .PARAMETER User
        If specified, the environment variable is set in the user scope. (Default.)

    .NOTES
        Default scope is User.
        A machine write auto-elevates through Invoke-Elevated (sudo --inline) when the
        session is not already elevated.

    .EXAMPLE
        Set-EnvironmentVariableExpanded -Name TMP -Value '%USERPROFILE%\tmp' -User

    .EXAMPLE
        Set-EnvironmentVariableExpanded -Name MYTOOL_HOME -Value '%ProgramFiles%\MyTool' -Machine
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param (
        [Parameter(Position = 0, Mandatory = $true)]
        [string] $Name,

        [Parameter(Position = 1, Mandatory = $true)]
        [string] $Value,

        [Parameter(Mandatory = $true, ParameterSetName = "Machine")]
        [switch] $Machine,

        [Parameter(Mandatory = $false, ParameterSetName = "User")]
        [switch] $User
    )

    $scope = $Machine ? "Machine" : "User"

    if ($PSCmdlet.ShouldProcess($Name, "Set expandable environment variable in the ${scope} scope")) {
        # when not already elevated, a machine write runs in an elevated process instead of in-process.
        # Re-invoke through the exported Set-EnvironmentVariable -Expand: the elevated child auto-loads
        # the module by exported command name, which this internal function is not.
        if ($Machine -and -not (Test-Elevated)) {
            Invoke-Elevated Set-EnvironmentVariable -Name $Name -Value $Value -Machine -Expand
        }
        else {
            # persist as REG_EXPAND_SZ - the type [Environment]::SetEnvironmentVariable cannot write
            $keyPath = $Machine `
                ? "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Environment" `
                : "HKCU:\Environment"
            Set-ItemProperty -LiteralPath $keyPath -Name $Name -Value $Value `
                -Type ([Microsoft.Win32.RegistryValueKind]::ExpandString)

            # a direct registry write does not notify running processes the way
            # [Environment]::SetEnvironmentVariable does; broadcast WM_SETTINGCHANGE so
            # listeners (Explorer, and the processes it launches) re-read the environment.
            # The interop type is compiled on first use and cached for the rest of the session.
            if (-not ([System.Management.Automation.PSTypeName]'Easypeasy.NativeMethods').Type) {
                Add-Type -Namespace EasyPeasy -Name NativeMethods -MemberDefinition '
                    [System.Runtime.InteropServices.DllImport("user32.dll", SetLastError = true, CharSet = System.Runtime.InteropServices.CharSet.Auto)]
                    public static extern System.IntPtr SendMessageTimeout(
                        System.IntPtr hWnd, uint Msg, System.UIntPtr wParam, string lParam,
                        uint fuFlags, uint uTimeout, out System.UIntPtr lpdwResult);
                '
            }

            # WM_SETTINGCHANGE (HWND_BROADCAST, lParam "Environment", SMTO_ABORTIFHUNG, 5s)
            $result = [UIntPtr]::Zero
            [void] [Easypeasy.NativeMethods]::SendMessageTimeout(
                [IntPtr] 0xffff, 0x1A, [UIntPtr]::Zero, 'Environment', 0x0002, 5000, [ref] $result)
        }
        Sync-ProcessEnvironmentVariable -Name $Name
    }
}
