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

    $user = [Environment]::GetEnvironmentVariable($Name, [System.EnvironmentVariableTarget]::User)
    $machine = [Environment]::GetEnvironmentVariable($Name, [System.EnvironmentVariableTarget]::Machine)

    $effective = ($null -ne $user) ? $user : $machine

    if ($null -eq $effective) {
        Remove-Item -Path "env:$Name" -ErrorAction SilentlyContinue
    }
    else {
        Set-Item -Path "env:$Name" -Value $effective
    }
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
        Returns every environment variable of the machine environment or the user environment
        as EnvironmentVariable records, each carrying its Name, Value and Scope.

    .PARAMETER Machine
        If specified, the environment variables of the machine environment are returned.

    .PARAMETER User
        If specified, the environment variables of the user environment are returned.

    .OUTPUTS
        EnvironmentVariable records with a Scope, Name and Value property.

    .EXAMPLE
        Get-Environment -Machine

    .EXAMPLE
        Get-Environment -User
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, ParameterSetName = "Machine")]
        [switch] $Machine,

        [Parameter(Mandatory = $true, ParameterSetName = "User")]
        [switch] $User
    )

    if ($Machine) {
        $target = [System.EnvironmentVariableTarget]::Machine
        $scope = "Machine"
    }
    else {
        $target = [System.EnvironmentVariableTarget]::User
        $scope = "User"
    }

    [Environment]::GetEnvironmentVariables($target).GetEnumerator() `
    | Sort-Object -Property Key `
    | ForEach-Object { [EnvironmentVariable]::new($scope, $_.Key, $_.Value) }
}

function Set-EnvironmentVariable() {
    <#
    .SYNOPSIS
        Sets the value of an environment variable.

    .DESCRIPTION
        Sets the value of the specified environment variable,
        either in the machine environment or the user environment.
        The change also takes effect in the current process immediately.

    .PARAMETER Name
        The name of the environment variable.

    .PARAMETER Value
        The value to set the environment variable to.

    .PARAMETER Machine
        If specified, the environment variable is set in the machine environment.

    .PARAMETER User
        If specified, the environment variable is set in the user environment. (Default.)

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
        Assert-Administrator
        $environment = [System.EnvironmentVariableTarget]::Machine
        $envType = "Machine"
    }
    # User is the default
    else {
        $environment = [System.EnvironmentVariableTarget]::User
        $envType = "User"
    }

    if ($PSCmdlet.ShouldProcess($Name, "Set environment variable in ${envType} environment")) {
        [Environment]::SetEnvironmentVariable($Name, $Value, $environment)
        Sync-ProcessEnvironmentVariable -Name $Name
    }
}

function Remove-EnvironmentVariable() {
    <#
    .SYNOPSIS
        Removes an environment variable.

    .DESCRIPTION
        Removes the specified environment variable,
        either from the machine environment or the user environment.
        The change also takes effect in the current process immediately.

    .PARAMETER Name
        The name of the environment variable.

    .PARAMETER Machine
        If specified, the environment variable is removed from the machine environment.

    .PARAMETER User
        If specified, the environment variable is removed from the user environment. (Default.)

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
        Assert-Administrator
        $environment = [System.EnvironmentVariableTarget]::Machine
        $envType = "Machine"
    }
    # User is default
    else {
        $environment = [System.EnvironmentVariableTarget]::User
        $envType = "User"
    }

    if ($PSCmdlet.ShouldProcess($Name, "Remove environment variable from ${envType} environment")) {
        [Environment]::SetEnvironmentVariable($Name, $null, $environment)
        Sync-ProcessEnvironmentVariable -Name $Name
    }
}

New-Alias -Name getenv -Value Get-EnvironmentVariable -ErrorAction SilentlyContinue | Out-Null
New-Alias -Name setenv -Value Set-EnvironmentVariable -ErrorAction SilentlyContinue | Out-Null
New-Alias -Name rmenv -Value Remove-EnvironmentVariable -ErrorAction SilentlyContinue | Out-Null
