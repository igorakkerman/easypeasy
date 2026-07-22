$systemPathSeparator = [IO.Path]::PathSeparator

class ValidRegexAttribute : System.Management.Automation.ValidateEnumeratedArgumentsAttribute {

    [void] ValidateElement([object] $element) {
        $pattern = [string] $element
        try { [void] [regex]::new($pattern) }
        catch { throw "Invalid regular expression. pattern: '$pattern', reason: $($_.Exception.InnerException.Message)" }
    }

    <#
    .SYNOPSIS
        Validates that an argument is a valid regular expression.
    .DESCRIPTION
        Rejects an argument that cannot be parsed as a regular expression, reporting the pattern and the reason.
        Every element of a collection is validated separately.
    .EXAMPLE
        [ValidRegexAttribute()] [string[]] $Match
    #>
}

class SystemPathLocation {

    [string] $Scope
    [ValidateNotNullOrEmpty()] [string] $Location

    SystemPathLocation($Scope, $Location) {
        $this.Scope = $Scope
        $this.Location = $Location
    }

    <#
    .SYNOPSIS
        A folder location on the system Path and the scope it belongs to.
    .DESCRIPTION
        Holds a folder location on the system Path together with its scope:
        'Machine' (local machine), 'User' (current user) or 'Process' (local to the current shell).
    .EXAMPLE
        $location = [SystemPathLocation]::new("Machine", "C:\Program Files\Git\bin")
    #>
}

function Backup-SystemPath {
    <# 
    .SYNOPSIS
        Backs up the system Path to a file in the temp folder.
    .DESCRIPTION
        Backs up the system Path to a file in the temp folder.
    .EXAMPLE
        Backup-SystemPath
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param ()
    
    $backupFile = "$env:TEMP\PATH-$(Get-Timestamp).txt"

    if ($PSCmdlet.ShouldProcess($backupFile, "Backup system Path")) {
        $env:PATH > $backupFile
    }
}

function local:Add-PathLocation {
    <#
    .SYNOPSIS
        Adds a location to a semicolon-separated path.
    .DESCRIPTION
        Permanently adds the specified location to the specified semicolon-separated path and returns the path.
        Adding is idempotent: if the path already contains the location and -First is not specified,
        the path is returned unchanged.
        If the path already contains the location and -First is specified,
        the existing location is moved to the beginning of the path.
    .PARAMETER Path
        Semiocolon separated path to add the location to.
    .PARAMETER Location
        Folder location to add to the path.
    .PARAMETER First
        If specified, the location is added to the beginning of the path.
        Otherwise, it is added to the end.
        If the location already exists, -First moves it to the beginning.
    .OUTPUTS
        Modified path.
    .EXAMPLE
        Add-PathLocation -Path "C:\Windows;C:\Windows\System32" -Location "C:\Program Files\Git\bin" -First
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
        [bool] $First
    )

    $oldLocations = $Path -split $systemPathSeparator

    $alreadyPresent = $oldLocations | Where-Object { $_.TrimEnd("\") -ieq $Location.TrimEnd("\") }

    if ($alreadyPresent) {
        if (-not $First) {
            # idempotent: the location is already present, leave the path unchanged
            return $Path
        }

        # move the existing location to the front
        $remaining = Remove-PathLocation -Path $Path -Location $Location
        return $remaining ? (($Location, $remaining) -join $systemPathSeparator) : $Location
    }

    $pathWithoutSeparator = $Path.TrimEnd($systemPathSeparator)

    return $First `
        ? (($Location, $pathWithoutSeparator) -join $systemPathSeparator) `
        : (($pathWithoutSeparator, $Location) -join $systemPathSeparator)
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
  
    $newPath = $Path -split $systemPathSeparator `
    | Where-Object { $_.TrimEnd("\") -ine $Location.TrimEnd("\") } `
    | Join-String -Separator $systemPathSeparator

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

    $unique = $Path -split $systemPathSeparator `
    | Where-Object { $_ -and $seen.Add($_.TrimEnd("\")) }

    return $unique -join $systemPathSeparator
}

function local:Get-PathScopeCounts {
    <#
    .SYNOPSIS
        Returns how often each location occurs on a persisted scope Path.
    .DESCRIPTION
        Reads the Path environment variable for the given scope and returns a case-insensitive dictionary
        mapping each trailing-backslash-trimmed location key to the number of times it occurs. Used to tag
        the effective Path's locations by consuming these counts in order.
    .PARAMETER Scope
        The scope to read, either "Machine" or "User".
    .OUTPUTS
        A case-insensitive hashtable of location key to occurrence count.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateSet("Machine", "User")]
        [string] $Scope
    )

    # a PowerShell hashtable literal is case-insensitive and yields $null (not an error) for absent keys
    $counts = @{}

    $context = @{ $Scope = $true }
    (Get-EnvironmentVariable @context -Name Path -ErrorAction SilentlyContinue) -split $systemPathSeparator `
    | Where-Object { $_ } `
    | ForEach-Object {
        $key = $_.TrimEnd("\")
        $counts[$key] = [int] $counts[$key] + 1
    }

    return $counts
}

function local:Test-LocationCriteria {
    <#
    .SYNOPSIS
        Tests a location against the exact, substring, wildcard and regex criteria.
    .DESCRIPTION
        Returns $true when the location satisfies every given criterion. Criteria of different kinds, and multiple
        values of the same kind, are combined with AND. An absent criterion is not applied; when no criterion is
        given at all, every location satisfies them.
        Matching is case-insensitive throughout. Trailing backslashes are ignored on the location and on the
        -Exact, -Contains and -Filter criteria; the -Match patterns are applied as given, since a trailing
        backslash is meaningful in a regular expression.
    .PARAMETER Location
        The location to test.
    .PARAMETER Exact
        Location the tested location must equal.
    .PARAMETER Contains
        Substrings the location must contain. Taken literally: wildcard and regex characters carry no meaning.
    .PARAMETER Filter
        Wildcard patterns the location must match.
    .PARAMETER Match
        Regular expressions the location must match.
    .OUTPUTS
        Boolean indicating whether the location satisfies every given criterion.
    .EXAMPLE
        Test-LocationCriteria -Location "C:\Program Files\Git\bin" -Contains "Git"
    .EXAMPLE
        Test-LocationCriteria -Location "C:\Program Files\Git\bin" -Contains "Git", "bin" -Match "\\bin$"
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param (
        [Parameter(Mandatory = $true)]
        [string] $Location,

        [Parameter(Mandatory = $false)]
        [string] $Exact,

        [Parameter(Mandatory = $false)]
        [string[]] $Contains,

        [Parameter(Mandatory = $false)]
        [string[]] $Filter,

        [Parameter(Mandatory = $false)]
        [string[]] $Match
    )

    $trimmedLocation = $Location.TrimEnd("\")

    if ($Exact -and $trimmedLocation -ine $Exact.TrimEnd("\")) {
        return $false
    }

    foreach ($substring in $Contains) {
        if (-not $trimmedLocation.Contains($substring.TrimEnd("\"), [System.StringComparison]::OrdinalIgnoreCase)) {
            return $false
        }
    }

    foreach ($pattern in $Filter) {
        if ($trimmedLocation -inotlike $pattern.TrimEnd("\")) {
            return $false
        }
    }

    foreach ($pattern in $Match) {
        if ($trimmedLocation -inotmatch $pattern) {
            return $false
        }
    }

    return $true
}

function Get-SystemPath {
    <#
    .SYNOPSIS
        Retrieves the system Path.
    .DESCRIPTION
        Retrieves the system Path, either for the current user, for the local machine
        or the system Path in effect in the current context.
        The Path is returned as an array of SystemPathLocation objects by default, each carrying its Location and Scope.
        For the effective Path (the default) each location is tagged with its origin scope: 'Machine' or 'User' when the
        location is on the corresponding persisted Path, or 'Process' when it is only on the current shell's Path.
        For -Machine or -User every location carries that scope.
        If the -Join switch is specified, the Path is returned as a semicolon-separated string of locations instead.
        The -Contains, -Filter and -Match criteria select locations. Multiple criteria, of the same kind or of
        different kinds, must all be satisfied. Without any criterion, every location is returned.
    .PARAMETER Machine
        If specified, the system Path for the local machine is returned.
    .PARAMETER User
        If specified, the system Path for the current user is returned.
    .PARAMETER Effective
        Default; if specified, the effective system Path is returned. The effective system Path is the Path in effect in the current shell.
    .PARAMETER Join
        If specified, the system Path is returned as a semicolon-separated string. Otherwise, it is returned as an array of SystemPathLocation objects.
    .PARAMETER Contains
        Substrings, positional; only locations containing all of them are returned. Taken literally: wildcard and
        regex characters carry no meaning. Matching is case-insensitive and ignores trailing backslashes.
    .PARAMETER Filter
        Wildcard patterns; only locations matching all of them are returned. Matching is case-insensitive and
        ignores trailing backslashes.
    .PARAMETER Match
        Regular expressions; only locations matching all of them are returned. Matching is case-insensitive.
        An invalid regular expression is a terminating error.
    .OUTPUTS
        SystemPathLocation objects with a Location and a Scope property, or a semicolon-separated string when -Join is specified.
    .NOTES
        Alias: path
    .EXAMPLE
        Get-SystemPath
    .EXAMPLE
        Get-SystemPath -Machine
    .EXAMPLE
        Get-SystemPath -User -Join
    .EXAMPLE
        Get-SystemPath Git
    .EXAMPLE
        Get-SystemPath Git bin
    .EXAMPLE
        Get-SystemPath -Filter "*\Git\*"
    .EXAMPLE
        Get-SystemPath -Match "\\Git\\(cmd|bin)$"
    .EXAMPLE
        Get-SystemPath Git -Filter "*\bin" -Machine
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

        [Parameter(Mandatory = $false, Position = 0, ValueFromRemainingArguments = $true)]
        [string[]] $Contains,

        [Parameter(Mandatory = $false)]
        [string[]] $Filter,

        [Parameter(Mandatory = $false)]
        [ValidRegexAttribute()]
        [string[]] $Match
    )

    $allLocations =
    if ($Machine) {
        (Get-EnvironmentVariable -Machine -Name Path) -split $systemPathSeparator `
        | Where-Object { $_ } `
        | ForEach-Object { [SystemPathLocation]::new("Machine", $_) }
    }
    elseif ($User) {
        (Get-EnvironmentVariable -User -Name Path) -split $systemPathSeparator `
        | Where-Object { $_ } `
        | ForEach-Object { [SystemPathLocation]::new("User", $_) }
    }
    else {
        # effective: the live shell Path, each location tagged with the persisted scope it originates from.
        # The process Path lists machine locations before user locations, so consume the machine occurrences
        # first, then user; a location on both scopes therefore appears once as Machine and once as User.
        $machineRemaining = Get-PathScopeCounts -Scope Machine
        $userRemaining = Get-PathScopeCounts -Scope User

        $env:PATH -split $systemPathSeparator `
        | Where-Object { $_ } `
        | ForEach-Object {
            $key = $_.TrimEnd("\")
            $scope =
            if ([int] $machineRemaining[$key] -gt 0) { $machineRemaining[$key]--; "Machine" }
            elseif ([int] $userRemaining[$key] -gt 0) { $userRemaining[$key]--; "User" }
            else { "Process" }

            [SystemPathLocation]::new($scope, $_)
        }
    }

    $criteria = @{
        Contains = $Contains
        Filter   = $Filter
        Match    = $Match
    }

    $selectedLocations = $allLocations | Where-Object { Test-LocationCriteria -Location $_.Location @criteria }

    return $Join `
        ? (($selectedLocations | ForEach-Object { $_.Location }) -join $systemPathSeparator) `
        : $selectedLocations
}

New-Alias -Name path -Value Get-SystemPath -ErrorAction SilentlyContinue | Out-Null

function local:Set-SystemPath {
    <#
    .SYNOPSIS
        Modifies the system Path.
    .DESCRIPTION
        Sets the system Path to the specified path, either for the current user or for the local machine. 
    .PARAMETER Path
        Semiocolon separated path to set.
    .PARAMETER Machine
        If specified, the system Path for the local machine is used.
    .PARAMETER User
        If specified, the system Path for the current user is used.
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

    Backup-SystemPath

    $context = $Machine ? @{ Machine = $true } : @{ User = $true }

    $params = @{
        Name  = "Path"
        Value = $Path
    }

    Set-EnvironmentVariable @context @params
}

function Add-SystemPathLocation {
    <#
    .SYNOPSIS
        Adds a location to the system Path.
    .DESCRIPTION
        Adds the specified location to the system Path, either for the current user or for the local machine.
        Adding is idempotent: if the location is already present, the Path is left unchanged and a warning is reported.
        If the location is already present and -First is specified, it is moved to the beginning of the Path.
    .PARAMETER Location
        Folder location to add to the system Path.
    .PARAMETER Machine
        If specified, the system Path for the local machine is used.
    .PARAMETER User
        If specified, the system Path for the current user is used. (Default.)
    .PARAMETER First
        If specified, the location is added to the beginning of the Path. Otherwise, it is added to the end.
        If the location is already present, -First moves it to the beginning.
        Alias: Front.
    .NOTES
        Alias: addpath
        Default scope is User.
    .EXAMPLE
        Add-SystemPathLocation -Location "C:\Program Files\Git\bin"
    .EXAMPLE
        Add-SystemPathLocation -Location "C:\Program Files\Git\bin" -Machine
    .EXAMPLE
        Add-SystemPathLocation -Location "C:\Program Files\Git\bin" -User
    .EXAMPLE
        Add-SystemPathLocation -Location "C:\Program Files\Git\bin" -First
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param (
        [Parameter(Position = 0, Mandatory = $true)]
        [Alias("Folder")]
        [string] $Location,

        [Parameter(Mandatory = $false)]
        [Alias("Front")]
        [switch] $First,

        [Parameter(Mandatory = $true, ParameterSetName = "Machine")]
        [switch] $Machine,

        [Parameter(Mandatory = $false, ParameterSetName = "User")]
        [switch] $User
    )

    $context = $Machine ? @{ Machine = $true } : @{ User = $true }

    $currentPath = Get-SystemPath @context -Join
    $newPath = Add-PathLocation -Path $currentPath -Location $Location -First:$First

    # idempotent: nothing changed means the location is already present
    if ($newPath -eq $currentPath) {
        Write-Warning "Location is already on the system Path: '$Location'"
        return
    }

    if ($PSCmdlet.ShouldProcess($Location, "Add location to system Path")) {
        Set-SystemPath @context -Path $newPath

        # enable new location immediately
        $env:PATH = Add-PathLocation -Path "$env:PATH" -Location $Location -First:$First
    }
}

function Remove-SystemPathLocation {
    <#
    .SYNOPSIS
        Removes a location from the system Path.
    .DESCRIPTION
        Removes the specified location from the system Path, either for the current user or for the local machine.
        Removing is idempotent: if the location is not present, the Path is left unchanged and a warning is reported.
    .PARAMETER Location
        Folder location to remove from the system Path.
    .PARAMETER Machine
        If specified, the system Path for the local machine is used.
    .PARAMETER User
        If specified, the system Path for the current user is used. (Default.)
    .NOTES
        Alias: rmpath
        Default scope is User.
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
        
        [Parameter(Mandatory = $true, ParameterSetName = "Machine")]
        [switch] $Machine,

        [Parameter(Mandatory = $false, ParameterSetName = "User")]
        [switch] $User
    )

    $context = $Machine ? @{ Machine = $true } : @{ User = $true }

    $currentPath = Get-SystemPath @context -Join
    $newPath = Remove-PathLocation -Path $currentPath -Location $Location

    # idempotent: nothing changed means the location is not present
    if ($newPath -eq $currentPath) {
        Write-Warning "Location is not on the system Path: '$Location'"
        return
    }

    if ($PSCmdlet.ShouldProcess($Location, "Remove location from system Path")) {
        Set-SystemPath @context -Path $newPath
        # disable location immediately
        # TODO: remove only if not present in the other context
        $env:PATH = Remove-PathLocation -Path "$env:PATH" -Location $Location
    }
}

function Remove-DuplicateSystemPathLocations {
    <#
    .SYNOPSIS
        Removes duplicate locations from the system Path.
    .DESCRIPTION
        Removes duplicate locations from the system Path, for the local machine, for the current user, or both combined.
        Within a scope, only the first occurrence of each location is kept.
        When both scopes are cleaned (the default, when neither -Machine nor -User is specified), a location present on
        both scopes is kept on only one: the machine Path by default, or the user Path if -KeepUser is specified.
        Removing duplicates is idempotent: if there are no duplicates, the Path is left unchanged.
    .PARAMETER Machine
        If specified, only the local machine system Path is cleaned.
    .PARAMETER User
        If specified, only the current user system Path is cleaned.
    .PARAMETER KeepMachine
        Default. When cleaning both scopes, a location present on both is kept on the machine Path and removed from the user Path.
    .PARAMETER KeepUser
        When cleaning both scopes, a location present on both is kept on the user Path and removed from the machine Path.
    .NOTES
        Alias: cleanpath
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
            foreach ($location in ($userDeduped -split $systemPathSeparator)) {
                if ($location) { $machineDeduped = Remove-PathLocation -Path $machineDeduped -Location $location }
            }
        }
        else {
            foreach ($location in ($machineDeduped -split $systemPathSeparator)) {
                if ($location) { $userDeduped = Remove-PathLocation -Path $userDeduped -Location $location }
            }
        }

        if ($machineDeduped -ne $machinePath -and $PSCmdlet.ShouldProcess("machine", "Remove duplicate locations from system Path")) {
            Set-SystemPath -Machine -Path $machineDeduped
            $changed = $true
        }

        if ($userDeduped -ne $userPath -and $PSCmdlet.ShouldProcess("user", "Remove duplicate locations from system Path")) {
            Set-SystemPath -User -Path $userDeduped
            $changed = $true
        }
    }
    else {
        $context = $Machine ? @{ Machine = $true } : @{ User = $true }
        $scope = $Machine ? "machine" : "user"

        $currentPath = Get-SystemPath @context -Join
        $deduped = Remove-DuplicatePathLocation -Path $currentPath

        if ($deduped -ne $currentPath -and $PSCmdlet.ShouldProcess($scope, "Remove duplicate locations from system Path")) {
            Set-SystemPath @context -Path $deduped
            $changed = $true
        }
    }

    # keep the current process Path free of duplicates too
    if ($changed) {
        $env:PATH = Remove-DuplicatePathLocation -Path "$env:PATH"
    }
}

function Move-SystemPathLocation {
    <#
    .SYNOPSIS
        Moves a location between the machine and user system Paths.
    .DESCRIPTION
        Moves the specified location from the machine system Path to the user system Path (-ToUser),
        or from the user system Path to the machine system Path (-ToMachine).
        The location is removed from the source Path and added to the target Path.
        If the location is not on the source Path - whether it is already on the target Path or on neither -
        nothing is moved and a warning is reported.
        Moving to or from the machine Path requires administrator privileges.
    .PARAMETER Location
        Folder location to move, positional.
    .PARAMETER ToUser
        Move the location from the machine system Path to the user system Path.
    .PARAMETER ToMachine
        Move the location from the user system Path to the machine system Path.
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

    # not on the source Path: nothing to move
    if ($newSource -eq $sourcePath) {
        $onTarget = (Get-SystemPath @target -Join) -split $systemPathSeparator `
        | Where-Object { $_ -and $_.TrimEnd("\") -ieq $Location.TrimEnd("\") }

        $reason = $onTarget ? "already on the $targetName Path" : "not on the $sourceName Path"
        Write-Warning "Nothing to move. reason: $reason, location: '$Location'"
        return
    }

    $targetPath = Get-SystemPath @target -Join
    $newTarget = Add-PathLocation -Path $targetPath -Location $Location -First:$false

    if (-not $PSCmdlet.ShouldProcess($Location, "Move location from the $sourceName to the $targetName system Path")) {
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
        Finds a location on the system Path.
    .DESCRIPTION
        Returns the locations on the system Path that satisfy the given criteria,
        either for the current user, for the local machine or the system Path in effect in the current context.
        Each result carries the matched location and the scope it was found in: 'Machine' or 'User', or - for the
        effective Path - 'Process' when the location is only on the current shell's Path.
        Multiple criteria, of the same kind or of different kinds, must all be satisfied. At least one of
        -Location, -Contains, -Filter and -Match is required.
        Matching is case-insensitive and ignores trailing backslashes. Nothing is returned when no location matches.
    .PARAMETER Location
        Exact folder location to look for.
    .PARAMETER Contains
        Substrings, positional; only locations containing all of them are returned. Taken literally: wildcard and
        regex characters carry no meaning.
    .PARAMETER Filter
        Wildcard patterns; only locations matching all of them are returned.
    .PARAMETER Match
        Regular expressions; only locations matching all of them are returned.
        An invalid regular expression is a terminating error.
    .PARAMETER Machine
        If specified, the system Path for the local machine is searched.
    .PARAMETER User
        If specified, the system Path for the current user is searched.
    .OUTPUTS
        For each match, an object with a Location and a Scope property.
    .EXAMPLE
        Get-SystemPathLocation Git
    .EXAMPLE
        Get-SystemPathLocation -Location "C:\Program Files\Git\bin"
    .EXAMPLE
        Get-SystemPathLocation -Filter "*\Git\*" -Machine
    .EXAMPLE
        Get-SystemPathLocation Git -Match "\\(cmd|bin)$"
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false)]
        [Alias("Folder")]
        [string] $Location,

        [Parameter(Mandatory = $false, Position = 0, ValueFromRemainingArguments = $true)]
        [string[]] $Contains,

        [Parameter(Mandatory = $false)]
        [string[]] $Filter,

        [Parameter(Mandatory = $false)]
        [ValidRegexAttribute()]
        [string[]] $Match,

        [Parameter(Mandatory = $false)]
        [switch] $Machine,

        [Parameter(Mandatory = $false)]
        [switch] $User
    )

    if ($Machine -and $User) {
        Write-Error "Specify only one of -Machine and -User." -ErrorAction Stop
    }

    if (-not $Location -and -not $Contains -and -not $Filter -and -not $Match) {
        Write-Error "Specify at least one of -Location, -Contains, -Filter and -Match." -ErrorAction Stop
    }

    $context = `
        if ($Machine) { @{ Machine = $true } } `
        elseif ($User) { @{ User = $true } } `
        else { @{} }

    $criteria = @{
        Exact    = $Location
        Contains = $Contains
        Filter   = $Filter
        Match    = $Match
    }

    # Get-SystemPath already tags each location with its scope, so reuse that instead of recomputing it here
    Get-SystemPath @context | Where-Object { Test-LocationCriteria -Location $_.Location @criteria }
}

function Test-SystemPathLocation {
    <#
    .SYNOPSIS
        Tests whether a location is on the system Path.
    .DESCRIPTION
        Returns $true if a location satisfying the given criteria is present on the system Path,
        either for the current user, for the local machine or the system Path in effect in the current context.
        Multiple criteria, of the same kind or of different kinds, must all be satisfied. At least one of
        -Location, -Contains, -Filter and -Match is required.
        Matching is case-insensitive and ignores trailing backslashes.
    .PARAMETER Location
        Exact folder location to look for.
    .PARAMETER Contains
        Substrings, positional; the location must contain all of them. Taken literally: wildcard and regex
        characters carry no meaning.
    .PARAMETER Filter
        Wildcard patterns the location must match.
    .PARAMETER Match
        Regular expressions the location must match. An invalid regular expression is a terminating error.
    .PARAMETER Machine
        If specified, the system Path for the local machine is searched.
    .PARAMETER User
        If specified, the system Path for the current user is searched.
    .OUTPUTS
        Boolean indicating whether a matching location is present.
    .EXAMPLE
        Test-SystemPathLocation Git
    .EXAMPLE
        Test-SystemPathLocation -Location "C:\Program Files\Git\bin"
    .EXAMPLE
        Test-SystemPathLocation -Filter "*\Git\*" -User
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param (
        [Parameter(Mandatory = $false)]
        [Alias("Folder")]
        [string] $Location,

        [Parameter(Mandatory = $false, Position = 0, ValueFromRemainingArguments = $true)]
        [string[]] $Contains,

        [Parameter(Mandatory = $false)]
        [string[]] $Filter,

        [Parameter(Mandatory = $false)]
        [ValidRegexAttribute()]
        [string[]] $Match,

        [Parameter(Mandatory = $false)]
        [switch] $Machine,

        [Parameter(Mandatory = $false)]
        [switch] $User
    )

    return @(Get-SystemPathLocation @PSBoundParameters).Count -gt 0
}

New-Alias -Name addpath -Value Add-SystemPathLocation -ErrorAction SilentlyContinue | Out-Null
New-Alias -Name rmpath -Value Remove-SystemPathLocation -ErrorAction SilentlyContinue | Out-Null
New-Alias -Name cleanpath -Value Remove-DuplicateSystemPathLocations -ErrorAction SilentlyContinue | Out-Null
New-Alias -Name movepath -Value Move-SystemPathLocation -ErrorAction SilentlyContinue | Out-Null
