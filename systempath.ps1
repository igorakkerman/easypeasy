class SystemPathLocation {
    
    [ValidateNotNullOrEmpty()] [string] $Location
    
    SystemPathLocation($Location) {
        $this.Location = $Location
    }

    <# 
    .SYNOPSIS
        Folder location in the system path.
    .DESCRIPTION
        Folder location in the system path.
    .EXAMPLE
        $location = [SystemPathLocation]::new("C:\Program Files\Git\bin")
    #>
}

function Backup-SystemPath {
    
    [CmdletBinding(SupportsShouldProcess)]
    param ()
    
    $backupFile = "$env:TEMP\PATH-$(Get-Timestamp).txt"

    if ($PSCmdlet.ShouldProcess($backupFile, "Backup system path")) {
        $env:PATH > $backupFile
    }

    <# 
    .SYNOPSIS
        Backs up the system path to a file in the temp folder.
    .DESCRIPTION
        Backs up the system path to a file in the temp folder.
    .EXAMPLE
        Backup-SystemPath
    #>    
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

    $oldLocations = $Path -split ";"
  
    foreach ($oldLocation in $oldLocations) {
        if ($oldLocation.TrimEnd("\") -ieq $Location.TrimEnd("\")) {
            return $Path
        }
    }

    $pathWithoutSemicolon = $Path.TrimEnd(";")

    return $First ? "$Location;$pathWithoutSemicolon" : "$pathWithoutSemicolon;$Location"

    <#
    .SYNOPSIS
        Adds a location to a semicolon-separated path.
    .DESCRIPTION
        Permanently adds the specified location to the specified semicolon-separated path, 
        if the path does not contain it already, and returns the path.
    .PARAMETER Path
        Semiocolon separated path to add the location to.
    .PARAMETER Location
        Folder location to add to the path.
    .PARAMETER First
        If specified, the location is added to the beginning of the path. 
        Otherwise, it is added to the end.
    .EXAMPLE
        Add-PathLocation -Path "C:\Windows;C:\Windows\System32" -Location "C:\Program Files\Git\bin" -First
    .EXAMPLE
        Add-PathLocation -Path "C:\Windows;C:\Windows\System32" -Location "C:\Program Files\Git\bin"
    #>
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
  
    return $Path -split ";" `
    | Where-Object { $_.TrimEnd("\") -ine $Location.TrimEnd("\") } `
    | Join-String -Separator ";"

    <#
    .SYNOPSIS
        Removes a location from a semicolon-separated path and returns the path.
    .DESCRIPTION
        Removes each occurence of location from the specified semicolon-separated path, if the path contains it.
    .PARAMETER Path
        Semiocolon separated path to remove the location from.
    .PARAMETER Location
        Folder location to remove from the path. 
        Trailing backslashes on the location argument and within the path are ignored.
    .RETURN
        The path with the location removed.
    .EXAMPLE
        $newPath = Remove-PathLocation -Path "C:\Windows;C:\Program Files\Git\bin\" -Location "C:\Program Files\Git\bin"
        # -> "C:\Windows"
        # Note the missing trailing backslash
    .EXAMPLE
        $newPath = Remove-PathLocation -Path "C:\Windows;C:\Program Files\Git\bin\" -Location "C:\Program Files\Git\bin"
        # -> "C:\Windows"
    .EXAMPLE
        $newPath = Remove-PathLocation -Path "C:\Windows;C:\Windows\System32" -Location "C:\Program Files\Git\bin"
        # -> "C:\Windows;C:\Windows\System32"
    #>
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

    return $Join ? $path  : 
        ($path -split ";" | ForEach-Object { [SystemPathLocation]::new($_) }) 

    <#
    .SYNOPSIS
        Retrieves the system path.
    .DESCRIPTION
        Retrieves the system path, either for the current user, for the local machine 
        or the system path in effect in the current context. 
        The path is returned as an array of SystemPathLocation objects by default.
        If the -Join switch is specified, the path is returned as a semicolon-separated string.
    .PARAMETER Machine
        If specified, the system path for the local machine is returned.
    .PARAMETER User
        If specified, the system path for the current user is returned.
    .PARAMETER Effective
        If specified, the effective system path is returned. The effective system path is the current user path with the local machine path appended to it.
    .PARAMETER Join
        If specified, the system path is returned as a semicolon-separated string. Otherwise, it is returned as an array of SystemPathLocation objects.
    .EXAMPLE
        Get-SystemPath
    .EXAMPLE
        Get-SystemPath -Machine
    .EXAMPLE
        Get-SystemPath -User -Join
    .ALIAS
        path
    #>
}

New-Alias -Name path -Value Get-SystemPath

function local:Set-SystemPath {

    [CmdletBinding(SupportsShouldProcess)]
    param (
        [Parameter(Mandatory = $true)]
        [string] $Path,

        [Parameter(Mandatory = $true, ParameterSetName = "Machine")]
        [switch] $Machine,

        [Parameter(Mandatory = $true, ParameterSetName = "User")]
        [switch] $User
    )

    Backup-SystemPath

    $context = `
        if ($Machine) { @{ Machine = $true } } `
        elseif ($User) { @{ User = $true } }

    $params = @{
        Name  = "Path"
        Value = $Path
    }

    Set-EnvironmentVariable @context @params

    <#
    .SYNOPSIS
        Modifies the system path.
    .DESCRIPTION
        Sets the system path to the specified path, either for the current user or for the local machine. 
    .PARAMETER Path
        Semiocolon separated path to set.
    .PARAMETER Machine
        If specified, the system path for the local machine is used.
    .PARAMETER User
        If specified, the system path for the current user is used.
    .EXAMPLE
        Set-SystemPath -Path "C:\Windows;C:\Windows\System32"
    .EXAMPLE
        Set-SystemPath -Path "C:\Windows;C:\Windows\System32" -Machine
    .EXAMPLE
        Set-SystemPath -Path "C:\Windows;C:\Windows\System32" -User
    #>
}


function Add-SystemPathLocation {

    [CmdletBinding(SupportsShouldProcess)]
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
        Path = Add-PathLocation -Path (Get-SystemPath @context -Join) -Location $Location -First:$First
    }
    
    if ($PSCmdlet.ShouldProcess($Location, "Add location to system path")) {
        Set-SystemPath @context @params
        
        # enable new location immediately
        $env:PATH = Add-PathLocation -Path "$env:PATH" -Location $Location -First:$First 
    }

    <#
    .SYNOPSIS
        Adds a location to the system path.
    .DESCRIPTION
        Adds the specified location to the system path, either for the current user or for the local machine, if the path does not contain it. 
    .PARAMETER Location
        Folder location to add to the system path.
    .PARAMETER Machine
        If specified, the system path for the local machine is used.
    .PARAMETER User
        If specified, the system path for the current user is used.
    .PARAMETER First
        If specified, the location is added to the beginning of the path. Otherwise, it is added to the end.
    .EXAMPLE
        Add-SystemPathLocation -Location "C:\Program Files\Git\bin"
    .EXAMPLE
        Add-SystemPathLocation -Location "C:\Program Files\Git\bin" -Machine
    .EXAMPLE
        Add-SystemPathLocation -Location "C:\Program Files\Git\bin" -User
    .EXAMPLE
        Add-SystemPathLocation -Location "C:\Program Files\Git\bin" -First
    #>
}

function Remove-SystemPathLocation {

    [CmdletBinding(SupportsShouldProcess)]
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

    if ($PSCmdlet.ShouldProcess($Location, "Remove location from system path")) {
        Set-SystemPath @context @params
        # disable new location immediately
        $env:PATH = Remove-PathLocation -Path "$env:PATH" -Location $Location 
    }

    <#
    .SYNOPSIS
        Removes a location from the system path.
    .DESCRIPTION
        Removes the specified location from the system path, either for the current user or for the local machine, if the path contains it. 
    .PARAMETER Location
        Folder location to remove from the system path.
    .PARAMETER Machine
        If specified, the system path for the local machine is used.
    .PARAMETER User
        If specified, the system path for the current user is used.
    .EXAMPLE
        Remove-SystemPathLocation -Location "C:\Program Files\Git\bin"
    .EXAMPLE
        Remove-SystemPathLocation -Location "C:\Program Files\Git\bin" -Machine
    .EXAMPLE
        Remove-SystemPathLocation -Location "C:\Program Files\Git\bin" -User
    #>
}
