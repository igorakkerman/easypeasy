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
    [CmdletBinding(SupportsShouldProcess)]
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

    try {
        if ($User) {
            $environment = [System.EnvironmentVariableTarget]::User
            $envType = "User"
        }
        # Machine is the default
        else {
            Assert-Administrator
            $environment = [System.EnvironmentVariableTarget]::Machine
            $envType = "Machine"
        }
    
        if ($PSCmdlet.ShouldProcess($Name, "Set environment variable in ${envType} environment")) {
            [Environment]::SetEnvironmentVariable($Name, $Value, $environment)
            # take effect in current shell
            Set-Item -Path env:${Name} -Value (
                (Get-EnvironmentVariable -User -Name $Name -ErrorAction SilentlyContinue) ?? 
                (Get-EnvironmentVariable -Machine -Name $Name -ErrorAction SilentlyContinue)
            )
        }
    }
    catch {
        Write-Error "$($_.Exception.Message) Trying to set a machine environment variable."
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
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Position = 0, Mandatory = "true")]
        [string] $Name,

        [Parameter(Mandatory = $false, ParameterSetName = "Machine")]
        [switch] $Machine,

        [Parameter(Mandatory = $true, ParameterSetName = "User")]
        [switch] $User
    )

    try {
        if ($User) {
            $environment = [System.EnvironmentVariableTarget]::User
            $envType = "User"
        }
        # Machine is default
        else {
            Assert-Administrator
            $environment = [System.EnvironmentVariableTarget]::Machine
            $envType = "Machine"
        }
    
        if ($PSCmdlet.ShouldProcess($Name, "Remove environment variable from ${envType} environment")) {
            [Environment]::SetEnvironmentVariable($Name, $null, $environment)
            # take effect in current shell
            Set-Item -Path env:${Name} -Value (
                (Get-EnvironmentVariable -User -Name $Name -ErrorAction SilentlyContinue) ?? 
                (Get-EnvironmentVariable -Machine -Name $Name -ErrorAction SilentlyContinue)
            )
        }
    }
    catch {
        Write-Error "$($_.Exception.Message) Trying to remove a machine environment variable."
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

New-Alias -Name getenv -Value Get-EnvironmentVariable -ErrorAction SilentlyContinue | Out-Null
New-Alias -Name setenv -Value Set-EnvironmentVariable -ErrorAction SilentlyContinue | Out-Null
New-Alias -Name rmenv -Value Remove-EnvironmentVariable -ErrorAction SilentlyContinue | Out-Null
