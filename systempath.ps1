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
    [ValidateNotNullOrEmpty()] [string] $ExpandableLocation
    [ValidateNotNullOrEmpty()] [string] $Location

    SystemPathLocation($Scope, $ExpandableLocation, $Location) {
        $this.Scope = $Scope
        $this.ExpandableLocation = $ExpandableLocation
        $this.Location = $Location
    }

    <#
    .SYNOPSIS
        A folder location on the system Path and the scope it belongs to.
    .DESCRIPTION
        Holds a folder location on the system Path together with its scope:
        'Machine' (local machine), 'User' (current user) or 'Process' (local to the current shell).
        ExpandableLocation is the stored form, keeping any %...% reference as indirection;
        Location is that value expanded. The two are equal when the location holds no %...% reference.
    .EXAMPLE
        $location = [SystemPathLocation]::new("Machine", "%ProgramFiles%\Git\bin", "C:\Program Files\Git\bin")
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

function local:Get-StoredPathString {
    <#
    .SYNOPSIS
        Joins the stored (expandable) form of Path entries into a semicolon-separated string.
    .DESCRIPTION
        Returns the entries' ExpandableLocation values joined by the path separator, the form persisted to the
        registry. Used to compare two sets of entries for equality.
    .PARAMETER Entries
        The SystemPathLocation entries to join.
    .OUTPUTS
        The semicolon-separated stored path.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [SystemPathLocation[]] $Entries
    )

    return ($Entries | ForEach-Object { $_.ExpandableLocation }) -join $systemPathSeparator
}

function local:Get-ProcessOnlyPathLocations {
    <#
    .SYNOPSIS
        Returns the current process Path locations that no persisted scope contributes.
    .DESCRIPTION
        Takes a snapshot of the locations the current shell added on top of the persisted Path - a virtual
        environment, or the directory the host injected at startup. Read before a scope Path is written:
        afterwards a location just removed from a scope is indistinguishable from one the session added.
        The locations are split by position, so that rebuilding the process Path preserves precedence:
        Leading holds those in front of the first persisted location, Trailing the rest.
    .OUTPUTS
        A hashtable with a LeadingProcessLocations and a TrailingProcessLocations entry, ready to splat
        into Sync-ProcessPath.
    #>
    [CmdletBinding()]
    param ()

    $effective = @(Get-SystemPath)

    $firstPersisted = 0
    while ($firstPersisted -lt $effective.Count -and $effective[$firstPersisted].Scope -eq "Process") {
        $firstPersisted++
    }

    $leading = @($effective | Select-Object -First $firstPersisted)
    $trailing = @($effective | Select-Object -Skip $firstPersisted | Where-Object { $_.Scope -eq "Process" })

    return @{
        LeadingProcessLocations  = $leading
        TrailingProcessLocations = $trailing
    }
}

function local:Sync-ProcessPath {
    <#
    .SYNOPSIS
        Rebuilds the current process Path from the persisted scopes.
    .DESCRIPTION
        Sets the current process Path to the machine Path followed by the user Path, each location expanded -
        the order and the form Windows itself builds a process Path in, so a shell easypeasy has touched holds
        what a fresh shell would. A location on both scopes therefore appears once per scope, as Windows leaves it.
        The Path is derived, never patched, so a location added to or removed from one scope cannot disturb the
        other scope's locations.
        Locations only the session knows are passed in, having been captured before the write, and are put back
        around the persisted ones. Without them the process Path holds the persisted scopes alone.
    .PARAMETER LeadingProcessLocations
        Process-only locations to keep in front of the persisted ones.
    .PARAMETER TrailingProcessLocations
        Process-only locations to keep behind the persisted ones.
    .EXAMPLE
        Sync-ProcessPath

    .EXAMPLE
        $processLocations = Get-ProcessOnlyPathLocations
        # ... persist a scope Path ...
        Sync-ProcessPath @processLocations
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false)]
        [AllowEmptyCollection()]
        [SystemPathLocation[]] $LeadingProcessLocations = @(),

        [Parameter(Mandatory = $false)]
        [AllowEmptyCollection()]
        [SystemPathLocation[]] $TrailingProcessLocations = @()
    )

    # Location already carries the expanded form, which is what a process Path holds
    $persisted = @(Get-SystemPath -Machine) + @(Get-SystemPath -User)

    $locations = @($LeadingProcessLocations) + $persisted + @($TrailingProcessLocations)

    $env:PATH = ($locations | ForEach-Object { $_.Location }) -join $systemPathSeparator
}

function local:Add-PathLocation {
    <#
    .SYNOPSIS
        Adds a location to a list of Path entries.
    .DESCRIPTION
        Adds the specified location to the given SystemPathLocation entries and returns the new entries.
        The location is treated as expandable: it is stored verbatim as the entry's ExpandableLocation, keeping
        any %...% reference, and its expansion becomes the entry's Location. Presence is decided on the expanded
        Location, so an entry stored as %SystemRoot% matches the literal folder it resolves to.
        Adding is idempotent: if an entry already resolves to the location and -First is not specified,
        the entries are returned unchanged. If it is present and -First is specified, that entry - keeping its
        stored form - is moved to the beginning.
    .PARAMETER Entries
        The current SystemPathLocation entries to add the location to.
    .PARAMETER Location
        Folder location to add, treated as expandable. A %...% reference is kept as indirection.
    .PARAMETER First
        If specified, the location is added to the beginning of the entries.
        Otherwise, it is added to the end. If the location is already present, -First moves it to the beginning.
    .PARAMETER Scope
        Scope stamped on a newly created entry.
    .OUTPUTS
        The modified SystemPathLocation entries.
    .EXAMPLE
        Add-PathLocation -Entries $entries -Location "%JAVA_HOME%\bin" -First $true -Scope User
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [SystemPathLocation[]] $Entries,

        [Parameter(Mandatory = $true)]
        [Alias("Folder")]
        [string] $Location,

        [Parameter(Mandatory = $true)]
        [bool] $First,

        [Parameter(Mandatory = $true)]
        [string] $Scope
    )

    $key = [Environment]::ExpandEnvironmentVariables($Location).TrimEnd("\")

    $present = @($Entries | Where-Object { $_.Location.TrimEnd("\") -ieq $key })

    if ($present) {
        if (-not $First) {
            # idempotent: the location is already present, leave the entries unchanged
            return @($Entries)
        }

        # move the existing entry to the front, keeping its stored form
        $remaining = @($Entries | Where-Object { $_.Location.TrimEnd("\") -ine $key })
        return $present + $remaining
    }

    $newEntry = [SystemPathLocation]::new($Scope, $Location, [Environment]::ExpandEnvironmentVariables($Location))

    return $First ? (@($newEntry) + @($Entries)) : (@($Entries) + @($newEntry))
}

function local:Remove-PathLocation {
    <#
    .SYNOPSIS
        Removes a location from a list of Path entries and returns the entries.
    .DESCRIPTION
        Removes each entry that resolves to the specified location from the given SystemPathLocation entries.
        The location argument is treated as expandable and matched on the entries' expanded Location, so either
        the stored (%...%) form or the resolved folder removes the entry.
        Removing is idempotent: if no entry resolves to the location, the entries are returned unchanged.
        Trailing backslashes on the location argument and on the entries are ignored.
    .PARAMETER Entries
        The current SystemPathLocation entries to remove the location from.
    .PARAMETER Location
        Folder location to remove, treated as expandable.
    .OUTPUTS
        The SystemPathLocation entries with the location removed.
    .EXAMPLE
        Remove-PathLocation -Entries $entries -Location "C:\Program Files\Git\bin"
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [SystemPathLocation[]] $Entries,

        [Parameter(Mandatory = $true)]
        [Alias("Folder")]
        [string] $Location
    )

    $key = [Environment]::ExpandEnvironmentVariables($Location).TrimEnd("\")

    return @($Entries | Where-Object { $_.Location.TrimEnd("\") -ine $key })
}

function local:Remove-DuplicatePathLocation {
    <#
    .SYNOPSIS
        Removes duplicate locations from a list of Path entries.
    .DESCRIPTION
        Returns the SystemPathLocation entries with duplicates removed, keeping the first occurrence of each
        location. Duplicates are decided on the expanded Location, case-insensitively and ignoring trailing
        backslashes, so two entries that resolve to the same folder count as one. The kept entry retains its
        stored form.
    .PARAMETER Entries
        The SystemPathLocation entries to deduplicate.
    .OUTPUTS
        The SystemPathLocation entries with duplicates removed.
    .EXAMPLE
        Remove-DuplicatePathLocation -Entries $entries
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [SystemPathLocation[]] $Entries
    )

    $seen = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)

    return @($Entries | Where-Object { $seen.Add($_.Location.TrimEnd("\")) })
}

function local:Get-PathScopeStoredForms {
    <#
    .SYNOPSIS
        Maps each location on a persisted scope Path to the stored forms it occurs as.
    .DESCRIPTION
        Reads the Path environment variable for the given scope in its stored form and returns a
        case-insensitive dictionary mapping each expanded, trailing-backslash-trimmed location key to a queue
        of the stored (expandable) values it occurs as, in order. Used to tag the effective Path's locations
        with their origin scope and recover the %...% reference each one is persisted as, by consuming the
        queues in order. A location occurring more than once has one queue entry per occurrence.
    .PARAMETER Scope
        The scope to read, either "Machine" or "User".
    .OUTPUTS
        A case-insensitive hashtable of location key to a queue of stored location values.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateSet("Machine", "User")]
        [string] $Scope
    )

    # a PowerShell hashtable literal is case-insensitive and yields $null (not an error) for absent keys
    $storedForms = @{}

    $context = @{ $Scope = $true }
    (Get-EnvironmentVariable @context -Name Path -Expandable -ErrorAction SilentlyContinue) -split $systemPathSeparator `
    | Where-Object { $_ } `
    | ForEach-Object {
        $key = [Environment]::ExpandEnvironmentVariables($_).TrimEnd("\")
        if (-not $storedForms.ContainsKey($key)) {
            $storedForms[$key] = [System.Collections.Generic.Queue[string]]::new()
        }
        $storedForms[$key].Enqueue($_)
    }

    return $storedForms
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
        The Path is returned as an array of SystemPathLocation objects by default, each carrying its Scope, its
        Location and its ExpandableLocation - the stored form keeping any %...% reference, expanded in Location.
        For the effective Path (the default) each location is tagged with its origin scope: 'Machine' or 'User' when the
        location is on the corresponding persisted Path, or 'Process' when it is only on the current shell's Path.
        For -Machine or -User every location carries that scope.
        If the -Join switch is specified, the Path is returned as a semicolon-separated string of the stored
        (expandable) locations instead.
        The -Contains, -Filter and -Match criteria select locations. Multiple criteria, of the same kind or of
        different kinds, must all be satisfied. Without any criterion, every location is returned.
    .PARAMETER Machine
        If specified, the system Path for the local machine is returned.
    .PARAMETER User
        If specified, the system Path for the current user is returned.
    .PARAMETER Effective
        Default; if specified, the effective system Path is returned. The effective system Path is the Path in effect in the current shell.
    .PARAMETER Join
        If specified, the system Path is returned as a semicolon-separated string of the stored (expandable) locations.
        Otherwise, it is returned as an array of SystemPathLocation objects.
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
        SystemPathLocation objects with a Scope, a Location and an ExpandableLocation property, or a
        semicolon-separated string of the stored (expandable) locations when -Join is specified.
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
        # read the stored form so a %...% reference is preserved, then expand for Location
        (Get-EnvironmentVariable -Machine -Name Path -Expandable -ErrorAction SilentlyContinue) -split $systemPathSeparator `
        | Where-Object { $_ } `
        | ForEach-Object { [SystemPathLocation]::new("Machine", $_, [Environment]::ExpandEnvironmentVariables($_)) }
    }
    elseif ($User) {
        (Get-EnvironmentVariable -User -Name Path -Expandable -ErrorAction SilentlyContinue) -split $systemPathSeparator `
        | Where-Object { $_ } `
        | ForEach-Object { [SystemPathLocation]::new("User", $_, [Environment]::ExpandEnvironmentVariables($_)) }
    }
    else {
        # effective: the live shell Path, each location tagged with the persisted scope it originates from.
        # The process Path lists machine locations before user locations, so consume the machine occurrences
        # first, then user; a location on both scopes therefore appears once as Machine and once as User.
        # Windows expands the process block, so the stored %...% form is recovered from the originating scope;
        # a process-only location has no persisted form and keeps the expanded one.
        $machineRemaining = Get-PathScopeStoredForms -Scope Machine
        $userRemaining = Get-PathScopeStoredForms -Scope User

        $env:PATH -split $systemPathSeparator `
        | Where-Object { $_ } `
        | ForEach-Object {
            $key = $_.TrimEnd("\")
            $scope = "Process"
            $stored = $_

            if ($machineRemaining[$key].Count -gt 0) {
                $scope = "Machine"
                $stored = $machineRemaining[$key].Dequeue()
            }
            elseif ($userRemaining[$key].Count -gt 0) {
                $scope = "User"
                $stored = $userRemaining[$key].Dequeue()
            }

            [SystemPathLocation]::new($scope, $stored, $_)
        }
    }

    $criteria = @{
        Contains = $Contains
        Filter   = $Filter
        Match    = $Match
    }

    $selectedLocations = $allLocations | Where-Object { Test-LocationCriteria -Location $_.Location @criteria }

    # -Join reproduces the stored form (ExpandableLocation), keeping %...% references
    return $Join `
        ? (($selectedLocations | ForEach-Object { $_.ExpandableLocation }) -join $systemPathSeparator) `
        : $selectedLocations
}

New-Alias -Name path -Value Get-SystemPath -ErrorAction SilentlyContinue | Out-Null

function Sync-SystemPath {
    <#
    .SYNOPSIS
        Updates the system Path of the current shell to the persisted Path.
    .DESCRIPTION
        Rebuilds the Path of the current shell from the machine Path followed by the user Path, the way a
        fresh shell is given one, so a change made elsewhere - in the Windows settings, in another shell,
        by an installer - takes effect without opening a new shell. A location carried by both scopes is
        listed once per scope, and a %...% reference is expanded, as Windows leaves them.
        Locations only this shell knows, such as those a virtual environment added, are kept in place.
        A location no scope carries any more is one of those as far as this shell can tell, so a removal
        made elsewhere is not picked up - open a new shell for that. An addition is.
        The system-path functions rebuild the Path themselves, so this is only needed for a change
        easypeasy did not make.
    .NOTES
        Alias: syncpath
    .EXAMPLE
        Sync-SystemPath
    .EXAMPLE
        syncpath
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param ()

    if ($PSCmdlet.ShouldProcess("system Path of the current shell", "Update to the persisted Path")) {
        # nothing is being written, so what is process-only now is what should stay process-only
        $processLocations = Get-ProcessOnlyPathLocations

        Sync-ProcessPath @processLocations
    }
}

New-Alias -Name syncpath -Value Sync-SystemPath -ErrorAction SilentlyContinue | Out-Null

function local:Set-SystemPath {
    <#
    .SYNOPSIS
        Modifies the system Path.
    .DESCRIPTION
        Sets the system Path to the given SystemPathLocation entries, either for the current user or for the
        local machine. The entries' stored form (ExpandableLocation) is persisted, so a %...% reference is kept
        as indirection; the Path is written as an expandable (REG_EXPAND_SZ) value.
        The current process Path is rebuilt from both scopes afterwards, keeping the locations only the session
        knows, which are captured before the write.
    .PARAMETER Entries
        The SystemPathLocation entries to persist.
    .PARAMETER Machine
        If specified, the system Path for the local machine is used.
    .PARAMETER User
        If specified, the system Path for the current user is used.
    .EXAMPLE
        Set-SystemPath -Entries $entries -Machine
    .EXAMPLE
        Set-SystemPath -Entries $entries -User
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param (
        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [SystemPathLocation[]] $Entries,

        [Parameter(Mandatory = $true, ParameterSetName = "Machine")]
        [switch] $Machine,

        [Parameter(Mandatory = $true, ParameterSetName = "User")]
        [switch] $User
    )

    Backup-SystemPath

    $context = $Machine ? @{ Machine = $true } : @{ User = $true }

    # persist the stored form so %...% references survive, as an expandable (REG_EXPAND_SZ) value
    $value = ($Entries | ForEach-Object { $_.ExpandableLocation }) -join $systemPathSeparator

    # capture what only the session knows before the write, while a removed location is still
    # distinguishable from one the session added
    $processLocations = Get-ProcessOnlyPathLocations

    Set-EnvironmentVariable @context -Name Path -Value $value -Expandable

    # derive the process Path from both scopes; runs after the write, so it is the authoritative one
    Sync-ProcessPath @processLocations
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
    $scope = $Machine ? "Machine" : "User"

    $currentEntries = @(Get-SystemPath @context)
    $newEntries = Add-PathLocation -Entries $currentEntries -Location $Location -First:$First -Scope $scope

    # idempotent: nothing changed means the location is already present
    if ((Get-StoredPathString -Entries $newEntries) -eq (Get-StoredPathString -Entries $currentEntries)) {
        Write-Warning "Location is already on the system Path: '$Location'"
        return
    }

    if ($PSCmdlet.ShouldProcess($Location, "Add location to system Path")) {
        # Set-SystemPath rebuilds the process Path, so the new location takes effect immediately
        Set-SystemPath @context -Entries $newEntries
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

    $currentEntries = @(Get-SystemPath @context)
    $newEntries = @(Remove-PathLocation -Entries $currentEntries -Location $Location)

    # idempotent: nothing changed means the location is not present
    if ((Get-StoredPathString -Entries $newEntries) -eq (Get-StoredPathString -Entries $currentEntries)) {
        Write-Warning "Location is not on the system Path: '$Location'"
        return
    }

    if ($PSCmdlet.ShouldProcess($Location, "Remove location from system Path")) {
        # Set-SystemPath rebuilds the process Path from both scopes, so the location stays available
        # when the other scope still carries it
        Set-SystemPath @context -Entries $newEntries
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

    # clean both scopes when neither (or both) scope switches are given
    if ($Machine -eq $User) {
        $machineEntries = @(Get-SystemPath -Machine)
        $userEntries = @(Get-SystemPath -User)

        $machineDeduped = @(Remove-DuplicatePathLocation -Entries $machineEntries)
        $userDeduped = @(Remove-DuplicatePathLocation -Entries $userEntries)

        # cross-scope: drop from the non-kept scope every location present in the kept scope
        if ($KeepUser) {
            foreach ($entry in $userDeduped) {
                $machineDeduped = @(Remove-PathLocation -Entries $machineDeduped -Location $entry.Location)
            }
        }
        else {
            foreach ($entry in $machineDeduped) {
                $userDeduped = @(Remove-PathLocation -Entries $userDeduped -Location $entry.Location)
            }
        }

        if ((Get-StoredPathString -Entries $machineDeduped) -ne (Get-StoredPathString -Entries $machineEntries) `
                -and $PSCmdlet.ShouldProcess("machine", "Remove duplicate locations from system Path")) {
            Set-SystemPath -Machine -Entries $machineDeduped
        }

        if ((Get-StoredPathString -Entries $userDeduped) -ne (Get-StoredPathString -Entries $userEntries) `
                -and $PSCmdlet.ShouldProcess("user", "Remove duplicate locations from system Path")) {
            Set-SystemPath -User -Entries $userDeduped
        }
    }
    else {
        $context = $Machine ? @{ Machine = $true } : @{ User = $true }
        $scope = $Machine ? "machine" : "user"

        $currentEntries = @(Get-SystemPath @context)
        $deduped = @(Remove-DuplicatePathLocation -Entries $currentEntries)

        if ((Get-StoredPathString -Entries $deduped) -ne (Get-StoredPathString -Entries $currentEntries) `
                -and $PSCmdlet.ShouldProcess($scope, "Remove duplicate locations from system Path")) {
            Set-SystemPath @context -Entries $deduped
        }
    }
    # Set-SystemPath rebuilds the process Path from the deduplicated scopes
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

    $sourceEntries = @(Get-SystemPath @source)
    $key = [Environment]::ExpandEnvironmentVariables($Location).TrimEnd("\")
    $moved = @($sourceEntries | Where-Object { $_.Location.TrimEnd("\") -ieq $key })

    # not on the source Path: nothing to move
    if ($moved.Count -eq 0) {
        $onTarget = @(Get-SystemPath @target) | Where-Object { $_.Location.TrimEnd("\") -ieq $key }

        $reason = $onTarget ? "already on the $targetName Path" : "not on the $sourceName Path"
        Write-Warning "Nothing to move. reason: $reason, location: '$Location'"
        return
    }

    $newSource = @(Remove-PathLocation -Entries $sourceEntries -Location $Location)

    $targetEntries = @(Get-SystemPath @target)
    $onTarget = @($targetEntries | Where-Object { $_.Location.TrimEnd("\") -ieq $key })
    # append the moved entry, keeping its stored (%...%) form, unless the target already has it
    $newTarget = $onTarget.Count -gt 0 ? $targetEntries : (@($targetEntries) + @($moved[0]))

    if (-not $PSCmdlet.ShouldProcess($Location, "Move location from the $sourceName to the $targetName system Path")) {
        return
    }

    Set-SystemPath @source -Entries $newSource

    if ((Get-StoredPathString -Entries $newTarget) -ne (Get-StoredPathString -Entries $targetEntries)) {
        Set-SystemPath @target -Entries $newTarget
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
