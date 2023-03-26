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
}
