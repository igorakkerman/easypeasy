function Backup-SystemPath {
    $env:PATH > "$env:TEMP\PATH-$(Get-Timestamp).txt"
}

function local:Add-PathLocation {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string] $Path,

        [Parameter(Mandatory = $true)]
        [Alias("Folder")]
        [string] $Location,

        [Parameter(Mandatory = $true)]
        [bool] $First
    )

    Backup-SystemPath

    $oldLocations = $Path -split ";"
  
    foreach ($oldLocation in $oldLocations) {
        if ($oldLocation.TrimEnd("\") -ieq $Location.TrimEnd("\")) {
            return $Path
        }
    }

    $pathWithoutSemicolon = $Path.TrimEnd(";")

    return $First ? "$Location;$pathWithoutSemicolon" : "$pathWithoutSemicolon;$Location"
}

function local:Remove-PathLocation {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string] $Path,

        [Parameter(Mandatory = $true)]
        [Alias("Folder")]
        [string] $Location
    )
  
    Backup-SystemPath

    return $Path -split ";" `
  | Where-Object { $_.TrimEnd("\") -ine $Location.TrimEnd("\") } `
  | Join-String -Separator ";"
}

function Get-SystemPath {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, ParameterSetName = "Machine")]
        [switch] $Machine,

        [Parameter(Mandatory = $true, ParameterSetName = "User")]
        [switch] $User,

        [Parameter(Mandatory = $false, ParameterSetName = "Effective")]
        [switch] $Effective,

        [Parameter(Mandatory = $false)]
        [switch] $Join
    )

    $params = @{
        Name = "Path"
    }

    if ($Machine -or $User) {
        $context = `
            if ($Machine) { @{ Machine = $true } } `
            elseif ($User) { @{ User = $true } }

        $path = Get-EnvironmentVariable @context @params
    }
    else {
        $path = $env:PATH
    }

    return $Join ? $path : $path -split ";"
}

New-Alias -Name path -Value Get-SystemPath

function local:Set-SystemPath {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string] $Path,

        [Parameter(Mandatory = $true, ParameterSetName = "Machine")]
        [switch] $Machine,

        [Parameter(Mandatory = $true, ParameterSetName = "User")]
        [switch] $User
    )

    $context = `
        if ($Machine) { @{ Machine = $true } } `
        elseif ($User) { @{ User = $true } }

    $params = @{
        Name  = "Path"
        Value = $Path
    }

    Set-EnvironmentVariable @context @params
}


function Add-SystemPathLocation {
    [CmdletBinding()]
    param (
        [Parameter(Position = 0, Mandatory = $true)]
        [Alias("Folder")]
        [string] $Location,

        [Parameter(Mandatory = $false)]
        [Alias("Prepend", "Front")]
        [switch] $First,

        [Parameter(Mandatory = $false, ParameterSetName = "Machine")]
        [switch] $Machine,

        [Parameter(Mandatory = $true, ParameterSetName = "User")]
        [switch] $User
    )

    $context = `
        if ($User) { @{ User = $true } } `
        else { @{ Machine = $true } } 

    $params = @{
        Path = Add-PathLocation -Path (Get-SystemPath @context -Join)
    }
    
    Set-SystemPath @context @params
    
    # enable new location immediately
    $env:PATH = Add-PathLocation -Path "$env:PATH" -Location $Location -First $First 
}

function Remove-SystemPathLocation {
    param (
        [Parameter(Position = 0, Mandatory = $true)]
        [Alias("Folder")]
        [string] $Location,
        
        [Parameter(Mandatory = $false, ParameterSetName = "Machine")]
        [switch] $Machine,
        
        [Parameter(Mandatory = $true, ParameterSetName = "User")]
        [switch] $User
    )
                
    $context = `
        if ($User) { @{ User = $true } } `
        else { @{ Machine = $true } } 

    $params = @{
        Path = Remove-PathLocation -Path (Get-SystemPath @context -Join) -Location $Location
    }

    Set-SystemPath @context @params
    # disable new location immediately
    $env:PATH = Remove-PathLocation -Path "$env:PATH" -Location $Location 
}
