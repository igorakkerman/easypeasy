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
    <# 
    .SYNOPSIS
        Backs up the system path to a file in the temp folder.
    .DESCRIPTION
        Backs up the system path to a file in the temp folder.
    .EXAMPLE
        Backup-SystemPath
    #>

    
    [CmdletBinding(SupportsShouldProcess)]
    param ()
    
    $backupFile = "$env:TEMP\PATH-$(Get-Timestamp).txt"

    if ($PSCmdlet.ShouldProcess($backupFile, "Backup system path")) {
        $env:PATH > $backupFile
    }
}

function local:Add-PathLocation {
    <#
    .SYNOPSIS
        Adds a location to a semicolon-separated path.
    .DESCRIPTION
        Permanently adds the specified location to the specified semicolon-separated path and returns the path. 
        If the path already contains the location, 
        an error is reported and the execution is stopped.
    .PARAMETER Path
        Semiocolon separated path to add the location to.
    .PARAMETER Location
        Folder location to add to the path.
    .PARAMETER Front
        If specified, the location is added to the beginning of the path. 
        Otherwise, it is added to the end.
    .OUTPUTS
        Modified path.
    .EXAMPLE
        Add-PathLocation -Path "C:\Windows;C:\Windows\System32" -Location "C:\Program Files\Git\bin" -Front
    .EXAMPLE
        Add-PathLocation -Path "C:\Windows;C:\Windows\System32" -Location "C:\Program Files\Git\bin"
    #>


    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string] $Path,

        [Parameter(Mandatory = $true)]
        [Alias("Folder")]
        [string] $Location,

        [Parameter(Mandatory = $true)]
        [bool] $Front
    )

    $oldLocations = $Path -split ";"
  
    foreach ($oldLocation in $oldLocations) {
        if ($oldLocation.TrimEnd("\") -ieq $Location.TrimEnd("\")) {
            Write-Error "Path already contains location: '$Location'" -ErrorAction Stop
        }
    }

    $pathWithoutSemicolon = $Path.TrimEnd(";")

    return $Front ? "$Location;$pathWithoutSemicolon" : "$pathWithoutSemicolon;$Location"
}

function local:Remove-PathLocation {
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
    .OUTPUTS
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


    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string] $Path,

        [Parameter(Mandatory = $true)]
        [Alias("Folder")]
        [string] $Location
    )
  
    $newPath = $Path -split ";" `
    | Where-Object { $_.TrimEnd("\") -ine $Location.TrimEnd("\") } `
    | Join-String -Separator ";"

    if ($newPath -eq $Path) {
        Write-Error "Location not found in path: '$Location'"
    }

    return $newPath
}

function Get-SystemPath {
    <#
    .SYNOPSIS
        Retrieves the system path.
    .DESCRIPTION
        Retrieves the system path, either for the current user, for the local machine 
        or the system path in effect in the current context. 
        The path is returned as an array of SystemPathLocation objects by default.
        If the -Join switch is specified, the path is returned as a semicolon-separated string.
        If the -Filter parameter is specified, only locations matching the wildcard pattern are returned.
    .PARAMETER Machine
        If specified, the system path for the local machine is returned.
    .PARAMETER User
        If specified, the system path for the current user is returned.
    .PARAMETER Effective
        Default; if specified, the effective system path is returned. The effective system path is the current user path with the local machine path appended to it.
    .PARAMETER Join
        If specified, the system path is returned as a semicolon-separated string. Otherwise, it is returned as an array of SystemPathLocation objects.
    .PARAMETER Filter
        Wildcard pattern, positional; only locations matching it are returned. Matching is case-insensitive and ignores trailing backslashes.
    .NOTES
        Alias: path
    .EXAMPLE
        Get-SystemPath
    .EXAMPLE
        Get-SystemPath -Machine
    .EXAMPLE
        Get-SystemPath -User -Join
    .EXAMPLE
    Get-SystemPath -Filter "*\Git\*"
    .EXAMPLE
    Get-SystemPath *Git*
    #>


    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, ParameterSetName = "Machine")]
        [switch] $Machine,

        [Parameter(Mandatory = $true, ParameterSetName = "User")]
        [switch] $User,

        [Parameter(Mandatory = $false, ParameterSetName = "Effective")]
        [switch] $Effective,

        [Parameter(Mandatory = $false)]
        [switch] $Join,

        [Parameter(Mandatory = $false, Position = 0)]
        [string] $Filter
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

    if (-not $Filter) {
        return $Join ? $path  :
            ($path -split ";" | ForEach-Object { if ($_) { [SystemPathLocation]::new($_) } })
    }

    $locations = $path -split ";" | Where-Object { $_ -and $_.TrimEnd("\") -ilike $Filter.TrimEnd("\") }

    return $Join ? ($locations -join ";") :
        ($locations | ForEach-Object { [SystemPathLocation]::new($_) })
}

New-Alias -Name path -Value Get-SystemPath -ErrorAction SilentlyContinue | Out-Null

function local:Set-SystemPath {
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


    [CmdletBinding(SupportsShouldProcess)]
    param (
        [Parameter(Mandatory = $true)]
        [string] $Path,

        [Parameter(Mandatory = $true, ParameterSetName = "Machine")]
        [switch] $Machine,

        [Parameter(Mandatory = $true, ParameterSetName = "User")]
        [switch] $User
    )

    if ($Machine) {
        Assert-Administrator
    }

    Backup-SystemPath

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
    .PARAMETER Front
        If specified, the location is added to the beginning of the path. Otherwise, it is added to the end.
    .NOTES
        Alias: addpath
    .EXAMPLE
        Add-SystemPathLocation -Location "C:\Program Files\Git\bin"
    .EXAMPLE
        Add-SystemPathLocation -Location "C:\Program Files\Git\bin" -Machine
    .EXAMPLE
        Add-SystemPathLocation -Location "C:\Program Files\Git\bin" -User
    .EXAMPLE
        Add-SystemPathLocation -Location "C:\Program Files\Git\bin" -Front
    #>


    [CmdletBinding(SupportsShouldProcess)]
    param (
        [Parameter(Position = 0, Mandatory = $true)]
        [Alias("Folder")]
        [string] $Location,

        [Parameter(Mandatory = $false)]
        [Alias("Prepend", "First", "Start")]
        [switch] $Front,

        [Parameter(Mandatory = $false, ParameterSetName = "Machine")]
        [switch] $Machine,

        [Parameter(Mandatory = $true, ParameterSetName = "User")]
        [switch] $User
    )

    try {
        $context = `
            if ($User) { @{ User = $true } } `
            else { @{ Machine = $true } } 
    
        $params = @{
            Path = Add-PathLocation -Path (Get-SystemPath @context -Join) -Location $Location -Front:$Front
        }
        
        if ($PSCmdlet.ShouldProcess($Location, "Add location to system path")) {
            Set-SystemPath @context @params
            
            # enable new location immediately
            $env:PATH = Add-PathLocation -Path "$env:PATH" -Location $Location -Front:$Front 
        }
    }
    catch {
        Write-Error $_.Exception.Message
    }
}

function Remove-SystemPathLocation {
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
    .NOTES
        Alias: rmpath, removepath
    .EXAMPLE
        Remove-SystemPathLocation -Location "C:\Program Files\Git\bin"
    .EXAMPLE
        Remove-SystemPathLocation -Location "C:\Program Files\Git\bin" -Machine
    .EXAMPLE
        Remove-SystemPathLocation -Location "C:\Program Files\Git\bin" -User
    #>


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

    try {
        $context = `
            if ($User) { @{ User = $true } } `
            else { @{ Machine = $true } } 

        $params = @{
            Path = Remove-PathLocation -Path (Get-SystemPath @context -Join) -Location $Location -ErrorAction Stop
        }

        if ($PSCmdlet.ShouldProcess($Location, "Remove location from system path")) {
            Set-SystemPath @context @params
            # disable location immediately
            # TODO: remove only if not present in the other context 
            $env:PATH = Remove-PathLocation -Path "$env:PATH" -Location $Location 
        }
    }
    catch { 
        Write-Error $_.Exception.Message
    }
}

New-Alias -Name addpath -Value Add-SystemPathLocation -ErrorAction SilentlyContinue | Out-Null
New-Alias -Name rmpath -Value Remove-SystemPathLocation -ErrorAction SilentlyContinue | Out-Null
New-Alias -Name removepath -Value Remove-SystemPathLocation -ErrorAction SilentlyContinue | Out-Null
