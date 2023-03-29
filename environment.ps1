function Get-EnvironmentVariable() {
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

    if ($Machine) {
        [Environment]::GetEnvironmentVariable($Name, [System.EnvironmentVariableTarget]::Machine)
    }
    elseif ($User) {
        [Environment]::GetEnvironmentVariable($Name, [System.EnvironmentVariableTarget]::User)        
    }
    else {
        (Get-Item env:$Name).Value
    }

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

    .ALIAS getenv

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
}

function Set-EnvironmentVariable() {
    [CmdletBinding()]
    param(
        [Parameter(Position = 0, Mandatory = $true)]
        [string] $Name,

        [Parameter(Position = 1, Mandatory = $true)]
        [string] $Value,

        [Parameter(Mandatory = $false, ParameterSetName = "Machine")]
        [switch] $Machine,

        [Parameter(Mandatory = $true, ParameterSetName = "User")]
        [switch] $User
    )

    if ($User) {
        [Environment]::SetEnvironmentVariable($Name, $Value, [System.EnvironmentVariableTarget]::User)
    }
    else {
        [Environment]::SetEnvironmentVariable($Name, $Value, [System.EnvironmentVariableTarget]::Machine)
    }

    <#
    .SYNOPSIS
        Sets the value of an environment variable.

    .DESCRIPTION
        Sets the value of the specified environment variable, 
        either in the machine environment or the user environment.

    .PARAMETER Name
        The name of the environment variable.

    .PARAMETER Value
        The value to set the environment variable to.

    .PARAMETER Machine
        If specified, the environment variable is set in the machine environment.

    .PARAMETER User
        If specified, the environment variable is set in the user environment.

    .ALIAS setenv

    .EXAMPLE
        Set-EnvironmentVariable -Name "JAVA_HOME" -Value "C:\Java\JDK" -Machine

    .EXAMPLE
        Set-EnvironmentVariable -Name "GOPATH" -Value "C:\Go\GOPATH" -User
    #>
}

function Remove-EnvironmentVariable() {
    [CmdletBinding()]
    param(
        [Parameter(Position = 0, Mandatory = "true")]
        [string] $Name,

        [Parameter(Mandatory = $false, ParameterSetName = "Machine")]
        [switch] $Machine,

        [Parameter(Mandatory = $true, ParameterSetName = "User")]
        [switch] $User
    )
    if ($User) {
        [Environment]::SetEnvironmentVariable($Name, $null, [System.EnvironmentVariableTarget]::User)
    }
    else {
        [Environment]::SetEnvironmentVariable($Name, $null, [System.EnvironmentVariableTarget]::Machine)
    }

    <#
    .SYNOPSIS
        Removes an environment variable.

    .DESCRIPTION
        Removes the specified environment variable, 
        either from the machine environment or the user environment.

    .PARAMETER Name
        The name of the environment variable.

    .PARAMETER Machine
        If specified, the environment variable is removed from the machine environment.

    .PARAMETER User
        If specified, the environment variable is removed from the user environment.

    .ALIAS rmenv

    .EXAMPLE
        Remove-EnvironmentVariable -Name "JAVA_HOME" -Machine

    .EXAMPLE
        Remove-EnvironmentVariable -Name "GOPATH" -User
    #>
}

New-Alias -Name getenv -Value Get-EnvironmentVariable
New-Alias -Name setenv -Value Set-EnvironmentVariable
New-Alias -Name rmenv -Value Remove-EnvironmentVariable
