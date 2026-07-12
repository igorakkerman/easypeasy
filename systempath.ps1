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
        Adding is idempotent: if the path already contains the location and -Front is not specified,
        the path is returned unchanged.
        If the path already contains the location and -Front is specified,
        the existing location is moved to the beginning of the path.
    .PARAMETER Path
        Semiocolon separated path to add the location to.
    .PARAMETER Location
        Folder location to add to the path.
    .PARAMETER Front
        If specified, the location is added to the beginning of the path.
        Otherwise, it is added to the end.
        If the location already exists, -Front moves it to the beginning.
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

    $alreadyPresent = $oldLocations | Where-Object { $_.TrimEnd("\") -ieq $Location.TrimEnd("\") }

    if ($alreadyPresent) {
        if (-not $Front) {
            # idempotent: the location is already present, leave the path unchanged
            return $Path
        }

        # move the existing location to the front
        $remaining = Remove-PathLocation -Path $Path -Location $Location
        return $remaining ? "$Location;$remaining" : $Location
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
        Adds the specified location to the system path, either for the current user or for the local machine.
        Adding is idempotent: if the location is already present, the path is left unchanged and no error is reported.
        If the location is already present and -Front is specified, it is moved to the beginning of the path.
    .PARAMETER Location
        Folder location to add to the system path.
    .PARAMETER Machine
        If specified, the system path for the local machine is used.
    .PARAMETER User
        If specified, the system path for the current user is used.
    .PARAMETER Front
        If specified, the location is added to the beginning of the path. Otherwise, it is added to the end.
        If the location is already present, -Front moves it to the beginning.
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

        $currentPath = Get-SystemPath @context -Join
        $newPath = Add-PathLocation -Path $currentPath -Location $Location -Front:$Front

        # idempotent: only persist when the path actually changed
        if ($newPath -ne $currentPath) {
            if ($PSCmdlet.ShouldProcess($Location, "Add location to system path")) {
                Set-SystemPath @context -Path $newPath

                # enable new location immediately
                $env:PATH = Add-PathLocation -Path "$env:PATH" -Location $Location -Front:$Front
            }
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

function Get-SystemPathLocation {
    <#
    .SYNOPSIS
        Finds a location on the system path.
    .DESCRIPTION
        Returns the locations on the system path that match the specified location or wildcard pattern,
        either for the current user, for the local machine or the system path in effect in the current context.
        Each result carries the matched location and the scope it was found in (Machine, User or Effective).
        Matching is case-insensitive and ignores trailing backslashes. Nothing is returned when no location matches.
    .PARAMETER Location
        Exact folder location to look for, positional.
    .PARAMETER Filter
        Wildcard pattern to match locations against, as an alternative to an exact location.
    .PARAMETER Machine
        If specified, the system path for the local machine is searched.
    .PARAMETER User
        If specified, the system path for the current user is searched.
    .OUTPUTS
        For each match, an object with a Location and a Scope property.
    .EXAMPLE
        Get-SystemPathLocation "C:\Program Files\Git\bin"
    .EXAMPLE
        Get-SystemPathLocation -Filter "*\Git\*" -Machine
    #>


    [CmdletBinding(DefaultParameterSetName = "Location")]
    param (
        [Parameter(Position = 0, Mandatory = $true, ParameterSetName = "Location")]
        [Alias("Folder")]
        [string] $Location,

        [Parameter(Mandatory = $true, ParameterSetName = "Filter")]
        [string] $Filter,

        [Parameter(Mandatory = $false)]
        [switch] $Machine,

        [Parameter(Mandatory = $false)]
        [switch] $User
    )

    if ($Machine -and $User) {
        Write-Error "Specify only one of -Machine and -User." -ErrorAction Stop
    }

    $scope = if ($Machine) { "Machine" } elseif ($User) { "User" } else { "Effective" }

    $context = `
        if ($Machine) { @{ Machine = $true } } `
        elseif ($User) { @{ User = $true } } `
        else { @{} }

    $isMatch = `
        if ($PSCmdlet.ParameterSetName -eq "Filter") { { $_.Location.TrimEnd("\") -ilike $Filter.TrimEnd("\") } } `
        else { { $_.Location.TrimEnd("\") -ieq $Location.TrimEnd("\") } }

    Get-SystemPath @context `
    | Where-Object $isMatch `
    | ForEach-Object { [PSCustomObject]@{ Location = $_.Location; Scope = $scope } }
}

function Test-SystemPathLocation {
    <#
    .SYNOPSIS
        Tests whether a location is on the system path.
    .DESCRIPTION
        Returns $true if a location matching the specified location or wildcard pattern is present on the system path,
        either for the current user, for the local machine or the system path in effect in the current context.
        Matching is case-insensitive and ignores trailing backslashes.
    .PARAMETER Location
        Exact folder location to look for, positional.
    .PARAMETER Filter
        Wildcard pattern to match locations against, as an alternative to an exact location.
    .PARAMETER Machine
        If specified, the system path for the local machine is searched.
    .PARAMETER User
        If specified, the system path for the current user is searched.
    .OUTPUTS
        Boolean indicating whether a matching location is present.
    .EXAMPLE
        Test-SystemPathLocation "C:\Program Files\Git\bin"
    .EXAMPLE
        Test-SystemPathLocation -Filter "*\Git\*" -User
    #>


    [CmdletBinding(DefaultParameterSetName = "Location")]
    [OutputType([bool])]
    param (
        [Parameter(Position = 0, Mandatory = $true, ParameterSetName = "Location")]
        [Alias("Folder")]
        [string] $Location,

        [Parameter(Mandatory = $true, ParameterSetName = "Filter")]
        [string] $Filter,

        [Parameter(Mandatory = $false)]
        [switch] $Machine,

        [Parameter(Mandatory = $false)]
        [switch] $User
    )

    return @(Get-SystemPathLocation @PSBoundParameters).Count -gt 0
}

New-Alias -Name addpath -Value Add-SystemPathLocation -ErrorAction SilentlyContinue | Out-Null
New-Alias -Name rmpath -Value Remove-SystemPathLocation -ErrorAction SilentlyContinue | Out-Null
New-Alias -Name removepath -Value Remove-SystemPathLocation -ErrorAction SilentlyContinue | Out-Null
