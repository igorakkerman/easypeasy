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

    if (! $value) {
        Write-Error "Environment variable '$Name' not found."
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

    .NOTES
        Alias: setenv
        Default scope is User.

    .EXAMPLE
        Set-EnvironmentVariable -Name "JAVA_HOME" -Value "C:\Java\JDK" -Machine

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
        [switch] $User
    )

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
