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
        Removes each occurence of location from the specified semicolon-separated path.
        Removing is idempotent: if the path does not contain the location, the path is returned unchanged.
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

    return $newPath
}

function local:Remove-DuplicatePathLocation {
    <#
    .SYNOPSIS
        Removes duplicate locations from a semicolon-separated path.
    .DESCRIPTION
        Returns the path with duplicate locations removed, keeping the first occurrence of each location.
        Comparison is case-insensitive and ignores trailing backslashes. Empty locations are dropped.
    .PARAMETER Path
        Semicolon-separated path to deduplicate.
    .OUTPUTS
        The path with duplicate locations removed.
    .EXAMPLE
        Remove-DuplicatePathLocation -Path "C:\A;C:\B;C:\a\"
        # -> "C:\A;C:\B"
    #>


    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string] $Path
    )

    $seen = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)

    $unique = $Path -split ";" `
    | Where-Object { $_ -and $seen.Add($_.TrimEnd("\")) }

    return $unique -join ";"
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
        Adding is idempotent: if the location is already present, the path is left unchanged and a warning is reported.
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
        Default scope is Machine for backward compatibility. In v2 the default will change to User.
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

    $context = `
        if ($User) { @{ User = $true } } `
        else { @{ Machine = $true } }

    $currentPath = Get-SystemPath @context -Join
    $newPath = Add-PathLocation -Path $currentPath -Location $Location -Front:$Front

    # idempotent: nothing changed means the location is already present
    if ($newPath -eq $currentPath) {
        Write-Warning "Location is already on the system path: '$Location'"
        return
    }

    if ($PSCmdlet.ShouldProcess($Location, "Add location to system path")) {
        Set-SystemPath @context -Path $newPath

        # enable new location immediately
        $env:PATH = Add-PathLocation -Path "$env:PATH" -Location $Location -Front:$Front
    }
}

function Remove-SystemPathLocation {
    <#
    .SYNOPSIS
        Removes a location from the system path.
    .DESCRIPTION
        Removes the specified location from the system path, either for the current user or for the local machine.
        Removing is idempotent: if the location is not present, the path is left unchanged and a warning is reported.
    .PARAMETER Location
        Folder location to remove from the system path.
    .PARAMETER Machine
        If specified, the system path for the local machine is used.
    .PARAMETER User
        If specified, the system path for the current user is used.
    .NOTES
        Alias: rmpath, removepath
        Default scope is Machine for backward compatibility. In v2 the default will change to User.
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

    $context = `
        if ($User) { @{ User = $true } } `
        else { @{ Machine = $true } }

    $currentPath = Get-SystemPath @context -Join
    $newPath = Remove-PathLocation -Path $currentPath -Location $Location

    # idempotent: nothing changed means the location is not present
    if ($newPath -eq $currentPath) {
        Write-Warning "Location is not on the system path: '$Location'"
        return
    }

    if ($PSCmdlet.ShouldProcess($Location, "Remove location from system path")) {
        Set-SystemPath @context -Path $newPath
        # disable location immediately
        # TODO: remove only if not present in the other context
        $env:PATH = Remove-PathLocation -Path "$env:PATH" -Location $Location
    }
}

function Remove-DuplicateSystemPathLocations {
    <#
    .SYNOPSIS
        Removes duplicate locations from the system path.
    .DESCRIPTION
        Removes duplicate locations from the system path, for the local machine, for the current user, or both combined.
        Within a scope, only the first occurrence of each location is kept.
        When both scopes are cleaned (the default, when neither -Machine nor -User is specified), a location present on
        both scopes is kept on only one: the machine path by default, or the user path if -KeepUser is specified.
        Removing duplicates is idempotent: if there are no duplicates, the path is left unchanged.
    .PARAMETER Machine
        If specified, only the local machine system path is cleaned.
    .PARAMETER User
        If specified, only the current user system path is cleaned.
    .PARAMETER KeepMachine
        Default. When cleaning both scopes, a location present on both is kept on the machine path and removed from the user path.
    .PARAMETER KeepUser
        When cleaning both scopes, a location present on both is kept on the user path and removed from the machine path.
    .NOTES
        Alias: deduppath
    .EXAMPLE
        Remove-DuplicateSystemPathLocations
    .EXAMPLE
        Remove-DuplicateSystemPathLocations -Machine
    .EXAMPLE
        Remove-DuplicateSystemPathLocations -KeepUser
    #>


    [CmdletBinding(SupportsShouldProcess)]
    param (
        [Parameter(Mandatory = $false)]
        [switch] $Machine,

        [Parameter(Mandatory = $false)]
        [switch] $User,

        [Parameter(Mandatory = $false)]
        [switch] $KeepMachine,

        [Parameter(Mandatory = $false)]
        [switch] $KeepUser
    )

    if ($KeepMachine -and $KeepUser) {
        Write-Error "Specify only one of -KeepMachine and -KeepUser." -ErrorAction Stop
    }

    $changed = $false

    # clean both scopes when neither (or both) scope switches are given
    if ($Machine -eq $User) {
        $machinePath = Get-SystemPath -Machine -Join
        $userPath = Get-SystemPath -User -Join

        $machineDeduped = Remove-DuplicatePathLocation -Path $machinePath
        $userDeduped = Remove-DuplicatePathLocation -Path $userPath

        # cross-scope: drop from the non-kept scope every location present in the kept scope
        if ($KeepUser) {
            foreach ($location in ($userDeduped -split ";")) {
                if ($location) { $machineDeduped = Remove-PathLocation -Path $machineDeduped -Location $location }
            }
        }
        else {
            foreach ($location in ($machineDeduped -split ";")) {
                if ($location) { $userDeduped = Remove-PathLocation -Path $userDeduped -Location $location }
            }
        }

        if ($machineDeduped -ne $machinePath -and $PSCmdlet.ShouldProcess("machine", "Remove duplicate locations from system path")) {
            Set-SystemPath -Machine -Path $machineDeduped
            $changed = $true
        }

        if ($userDeduped -ne $userPath -and $PSCmdlet.ShouldProcess("user", "Remove duplicate locations from system path")) {
            Set-SystemPath -User -Path $userDeduped
            $changed = $true
        }
    }
    else {
        $context = if ($Machine) { @{ Machine = $true } } else { @{ User = $true } }
        $scope = if ($Machine) { "machine" } else { "user" }

        $currentPath = Get-SystemPath @context -Join
        $deduped = Remove-DuplicatePathLocation -Path $currentPath

        if ($deduped -ne $currentPath -and $PSCmdlet.ShouldProcess($scope, "Remove duplicate locations from system path")) {
            Set-SystemPath @context -Path $deduped
            $changed = $true
        }
    }

    # keep the current process path free of duplicates too
    if ($changed) {
        $env:PATH = Remove-DuplicatePathLocation -Path "$env:PATH"
    }
}

function Move-SystemPathLocation {
    <#
    .SYNOPSIS
        Moves a location between the machine and user system paths.
    .DESCRIPTION
        Moves the specified location from the machine system path to the user system path (-ToUser),
        or from the user system path to the machine system path (-ToMachine).
        The location is removed from the source path and added to the target path.
        If the location is not on the source path - whether it is already on the target path or on neither -
        nothing is moved and a warning is reported.
        Moving to or from the machine path requires administrator privileges.
    .PARAMETER Location
        Folder location to move, positional.
    .PARAMETER ToUser
        Move the location from the machine system path to the user system path.
    .PARAMETER ToMachine
        Move the location from the user system path to the machine system path.
    .NOTES
        Alias: movepath
    .EXAMPLE
        Move-SystemPathLocation "C:\Program Files\Git\bin" -ToUser
    .EXAMPLE
        Move-SystemPathLocation "C:\Program Files\Git\bin" -ToMachine
    #>


    [CmdletBinding(SupportsShouldProcess)]
    param (
        [Parameter(Position = 0, Mandatory = $true)]
        [Alias("Folder")]
        [string] $Location,

        [Parameter(Mandatory = $true, ParameterSetName = "ToUser")]
        [switch] $ToUser,

        [Parameter(Mandatory = $true, ParameterSetName = "ToMachine")]
        [switch] $ToMachine
    )

    if ($ToUser) {
        $source = @{ Machine = $true }; $sourceName = "machine"
        $target = @{ User = $true }; $targetName = "user"
    }
    else {
        $source = @{ User = $true }; $sourceName = "user"
        $target = @{ Machine = $true }; $targetName = "machine"
    }

    $sourcePath = Get-SystemPath @source -Join
    $newSource = Remove-PathLocation -Path $sourcePath -Location $Location

    # not on the source path: nothing to move
    if ($newSource -eq $sourcePath) {
        $onTarget = (Get-SystemPath @target -Join) -split ";" `
        | Where-Object { $_ -and $_.TrimEnd("\") -ieq $Location.TrimEnd("\") }

        $reason = $onTarget ? "it is already on the $targetName path" : "it is not on the $sourceName path"
        Write-Warning "Nothing to move; $($reason): '$Location'"
        return
    }

    $targetPath = Get-SystemPath @target -Join
    $newTarget = Add-PathLocation -Path $targetPath -Location $Location -Front:$false

    if (-not $PSCmdlet.ShouldProcess($Location, "Move location from the $sourceName to the $targetName system path")) {
        return
    }

    Set-SystemPath @source -Path $newSource

    if ($newTarget -ne $targetPath) {
        Set-SystemPath @target -Path $newTarget
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
New-Alias -Name deduppath -Value Remove-DuplicateSystemPathLocations -ErrorAction SilentlyContinue | Out-Null
New-Alias -Name movepath -Value Move-SystemPathLocation -ErrorAction SilentlyContinue | Out-Null
