function Get-EnvironmentVariable() {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = "true")]
        [string] $Name
    )

    [Environment]::GetEnvironmentVariable($Name, [System.EnvironmentVariableTarget]::Machine)
}

function Get-UserEnvironmentVariable() {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = "true")]
        [string] $Name
    )

    [Environment]::GetEnvironmentVariable($Name, [System.EnvironmentVariableTarget]::User)
}

function Set-EnvironmentVariable() {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = "true")]
        [string] $Name,

        [Parameter(Mandatory = "true")]
        [string] $Value
    )

    [Environment]::SetEnvironmentVariable($Name, $Value, [System.EnvironmentVariableTarget]::Machine)
}

function Set-UserEnvironmentVariable() {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = "true")]
        [string] $Name,

        [Parameter(Mandatory = "true")]
        [string] $Value
    )

    [Environment]::SetEnvironmentVariable($Name, $Value, [System.EnvironmentVariableTarget]::User)
}

function Remove-EnvironmentVariable() {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = "true")]
        [string] $Name
    )

    [Environment]::SetEnvironmentVariable($Name, $null, [System.EnvironmentVariableTarget]::Machine)
}

function Remove-UserEnvironmentVariable() {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = "true")]
        [string] $Name
    )

    [Environment]::SetEnvironmentVariable($Name, $null, [System.EnvironmentVariableTarget]::User)
}
