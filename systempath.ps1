$systemPathSeparator = [IO.Path]::PathSeparator

class ValidRegexAttribute : System.Management.Automation.ValidateEnumeratedArgumentsAttribute {

    [void] ValidateElement([object] $element) {
        $pattern = [string] $element
        try {
            [void] [regex]::new($pattern)
        }
        catch {
            throw "Invalid regular expression. pattern: '$pattern', reason: $($_.Exception.InnerException.Message)"
        }
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
    [ValidateNotNullOrEmpty()] [string] $StoredValue
    [string] $Location

    SystemPathLocation($Scope, $StoredValue, $Location) {
        $this.Scope = $Scope
        $this.StoredValue = $StoredValue
        $this.Location = $Location
    }

    <#
    .SYNOPSIS
        A folder location on the system Path and the scope it belongs to.
    .DESCRIPTION
        Holds a folder location on the system Path together with its scope:
        'Machine' (local machine), 'User' (current user) or 'Process' (local to the current shell).
        StoredValue is the value as persisted, verbatim: any %...% reference is kept as indirection,
        as is a repeated or trailing backslash and a '..' segment.
        Location is what that value resolves to - expanded and normalized to an absolute folder - or null when
        it cannot be resolved. The two are equal when the stored value is already a normalized absolute folder.
    .EXAMPLE
        $location = [SystemPathLocation]::new("Machine", "%ProgramFiles%\Git\bin", "C:\Program Files\Git\bin")
    #>
}

function Backup-SystemPath {
    <#
    .SYNOPSIS
        Backs up the system Path to a file in the temp folder.
    .DESCRIPTION
        Writes the Path in effect in the current shell - the expanded, effective $env:PATH, not the
        persisted machine and user Paths - to a timestamped file in the temp folder, and returns the
        location of that file. Every write to a scope Path takes one of these first.
    .OUTPUTS
        string - Location of the backup file. Nothing under -WhatIf.
    .EXAMPLE
        Backup-SystemPath
    .EXAMPLE
        $backup = Backup-SystemPath
    #>
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([string])]
    param ()

    $backupFile = "$env:TEMP\PATH-$(Get-Timestamp).txt"

    if ($PSCmdlet.ShouldProcess($backupFile, "Backup system Path")) {
        $env:PATH > $backupFile

        return $backupFile
    }
}

function local:ConvertTo-ComparableLocation {
    <#
    .SYNOPSIS
        Reduces a location to the key locations are compared on.
    .DESCRIPTION
        Returns the location with repeated backslashes collapsed to one and a trailing backslash removed,
        so that two spellings of the same folder yield the same key. A leading '\\' is kept, holding a UNC
        root apart from a single leading backslash.
        Case is left as it is: comparison is case-insensitive through the operator, not here.
    .PARAMETER Location
        The location to reduce.
    .OUTPUTS
        The comparison key of the location.
    .EXAMPLE
        ConvertTo-ComparableLocation -Location "C:\Program Files\\Git\bin\"
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param (
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string] $Location
    )

    # every run of backslashes collapses to one; a leading run is a UNC root, so its first backslash is
    # captured and put back
    return ($Location -replace '(^\\)?\\+', '$1\').TrimEnd("\")
}

function local:ConvertTo-NormalizedLocation {
    <#
    .SYNOPSIS
        Resolves a stored Path value to the absolute folder it names.
    .DESCRIPTION
        Expands any %...% reference, resolves the result against the current directory, collapses repeated
        backslashes and '..' segments, and drops a trailing backslash. A root keeps its trailing backslash,
        'C:\' being a folder where 'C:' is a drive-relative reference; a leading '\\' is kept, holding a UNC
        root apart from a single leading backslash. Case is left as it is.
        A value that cannot be resolved - one carrying a %...% reference no variable resolves, or one
        exceeding the path limit - returns null. Reporting the reference is left to the caller.
    .PARAMETER Location
        The location to resolve, treated as expandable.
    .OUTPUTS
        The absolute, normalized location, or null when the value cannot be resolved.
    .EXAMPLE
        ConvertTo-NormalizedLocation -Location "%SystemRoot%\\system32\"
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param (
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string] $Location
    )

    # a reference no variable resolves names no folder: expansion would leave it standing and the
    # current directory would be prefixed to it
    if (Get-UnresolvedVariableName -Value $Location) {
        return $null
    }

    $expanded = [Environment]::ExpandEnvironmentVariables($Location)

    # GetFullPath resolves against [Environment]::CurrentDirectory, which does not follow the shell's
    # location; $PWD is what the current directory means to a caller, where the shell is on a filesystem
    $base = $PWD.Provider.Name -eq "FileSystem" `
        ? $PWD.ProviderPath `
        : [Environment]::CurrentDirectory

    # GetFullPath rejects values it cannot resolve; represent the missing normalized form as null
    try {
        $full = [IO.Path]::GetFullPath($expanded, $base)
        return $full -ne [IO.Path]::GetPathRoot($full) `
            ? $full.TrimEnd([IO.Path]::DirectorySeparatorChar) `
            : $full
    }
    catch {
        return $null
    }
}

function local:ConvertTo-LocationIdentity {
    <#
    .SYNOPSIS
        Reduces a stored value and what it resolves to into the identity entries are matched on.
    .DESCRIPTION
        Returns the resolved location where the stored value resolves, and the comparable stored value
        where it does not, so an entry carrying an unresolved %...% reference still matches the same
        reference spelled the same way. Case is left as it is: comparison is case-insensitive through
        the operator, not here.
    .PARAMETER StoredValue
        The value as persisted, keeping any %...% reference.
    .PARAMETER Location
        What the stored value resolves to, or null where it does not resolve.
    .OUTPUTS
        The identity of the location.
    .EXAMPLE
        ConvertTo-LocationIdentity -StoredValue "%JAVA_HOME%\bin" -Location $null
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param (
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string] $StoredValue,
        [AllowEmptyString()]
        [AllowNull()]
        [string] $Location
    )

    return [string]::IsNullOrEmpty($Location) `
        ? (ConvertTo-ComparableLocation -Location $StoredValue) `
        : $Location
}

function local:Get-StoredPathString {
    <#
    .SYNOPSIS
        Joins the stored form of Path entries into a semicolon-separated string.
    .DESCRIPTION
        Returns the entries' StoredValue values joined by the path separator, the form persisted to the
        registry. Used to compare two sets of entries for equality.
    .PARAMETER Entries
        The SystemPathLocation entries to join.
    .OUTPUTS
        The semicolon-separated stored path.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [SystemPathLocation[]] $Entries
    )

    return (
        $Entries `
            | ForEach-Object {
                $_.StoredValue
            }
    ) -join $systemPathSeparator
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
    $trailing = @(
        $effective `
            | Select-Object -Skip $firstPersisted `
            | Where-Object {
                $_.Scope -eq "Process"
            }
    )

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
        Sets the current process Path to the machine Path followed by the user Path - the order Windows itself
        builds a process Path in, so a shell easypeasy has touched holds what a fresh shell would. A location
        on both scopes therefore appears once per scope, as Windows leaves it.
        Each location is expanded, and expanded only: nothing expands a %...% reference while a command is
        looked up, so a process Path carrying one would name no folder. The spelling is kept otherwise, as
        Windows keeps it, so the process Path holds each location as its scope Path spells it rather than a
        normalized rewrite of it.
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
        [AllowEmptyCollection()]
        [SystemPathLocation[]] $LeadingProcessLocations = @(),
        [AllowEmptyCollection()]
        [SystemPathLocation[]] $TrailingProcessLocations = @()
    )

    $persisted = @(Get-SystemPath -Machine -ErrorAction SilentlyContinue) + @(Get-SystemPath -User -ErrorAction SilentlyContinue)

    $locations = @($LeadingProcessLocations) + $persisted + @($TrailingProcessLocations)

    # StoredValue expanded, not Location: expansion is all Windows does to a scope Path location,
    # so the stored spelling survives into the process Path
    $env:PATH = (
        $locations `
            | ForEach-Object {
                [Environment]::ExpandEnvironmentVariables($_.StoredValue)
            }
    ) -join $systemPathSeparator
}

function local:Add-PathLocation {
    <#
    .SYNOPSIS
        Adds a location to a list of Path entries.
    .DESCRIPTION
        Adds the specified location to the given SystemPathLocation entries and returns the new entries.
        The location is stored verbatim as the entry's StoredValue, keeping any %...% reference, and what it
        resolves to becomes the entry's Location. Presence is decided on the resolved Location, so an entry
        stored as %SystemRoot% matches the literal folder it resolves to.
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
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [SystemPathLocation[]] $Entries,
        [Parameter(Mandatory)]
        [Alias("Folder")]
        [string] $Location,
        [Parameter(Mandatory)]
        [bool] $First,
        [Parameter(Mandatory)]
        [string] $Scope
    )

    $normalized = ConvertTo-NormalizedLocation -Location $Location
    $identity = ConvertTo-LocationIdentity -StoredValue $Location -Location $normalized

    $present = @(
        $Entries `
            | Where-Object {
                (ConvertTo-LocationIdentity -StoredValue $_.StoredValue -Location $_.Location) -ieq $identity
            }
    )

    if ($present) {
        if (-not $First) {
            # idempotent: the location is already present, leave the entries unchanged
            return @($Entries)
        }

        # move the existing entry to the front, keeping its stored form
        $remaining = @(
            $Entries `
                | Where-Object {
                    (ConvertTo-LocationIdentity -StoredValue $_.StoredValue -Location $_.Location) -ine $identity
                }
        )
        return $present + $remaining
    }

    $newEntry = [SystemPathLocation]::new($Scope, $Location, $normalized)

    return $First `
        ? (@($newEntry) + @($Entries)) `
        : (@($Entries) + @($newEntry))
}

function local:Remove-PathLocation {
    <#
    .SYNOPSIS
        Removes a location from a list of Path entries and returns the entries.
    .DESCRIPTION
        Removes each entry that resolves to the specified location from the given SystemPathLocation entries.
        The location argument is resolved the same way the entries are and matched on their Location, so either
        the stored (%...%) form or the resolved folder removes the entry.
        Removing is idempotent: if no entry resolves to the location, the entries are returned unchanged.
        Repeated and trailing backslashes on the location argument and on the entries are ignored.
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
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [SystemPathLocation[]] $Entries,
        [Parameter(Mandatory)]
        [Alias("Folder")]
        [string] $Location
    )

    $normalized = ConvertTo-NormalizedLocation -Location $Location
    $identity = ConvertTo-LocationIdentity -StoredValue $Location -Location $normalized

    return @(
        $Entries `
            | Where-Object {
                (ConvertTo-LocationIdentity -StoredValue $_.StoredValue -Location $_.Location) -ine $identity
            }
    )
}

function local:Remove-DuplicatePathLocation {
    <#
    .SYNOPSIS
        Removes duplicate locations from a list of Path entries.
    .DESCRIPTION
        Returns the SystemPathLocation entries with duplicates removed, keeping the first occurrence of each
        location. Duplicates are decided on the resolved Location, case-insensitively, so two entries that
        resolve to the same folder count as one. Entries that do not resolve are compared on their stored
        value instead, so a %...% reference no variable resolves still counts as a duplicate of itself.
        The kept entry retains its stored value.
    .PARAMETER Entries
        The SystemPathLocation entries to deduplicate.
    .OUTPUTS
        The SystemPathLocation entries with duplicates removed.
    .EXAMPLE
        Remove-DuplicatePathLocation -Entries $entries
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [SystemPathLocation[]] $Entries
    )

    $seen = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)

    return @(
        $Entries `
            | Where-Object {
                $seen.Add((ConvertTo-LocationIdentity -StoredValue $_.StoredValue -Location $_.Location))
            }
    )
}

function local:Get-PathScopeStoredForms {
    <#
    .SYNOPSIS
        Maps each location on a persisted scope Path to the stored forms it occurs as.
    .DESCRIPTION
        Reads the Path environment variable for the given scope in its stored form and returns a
        case-insensitive dictionary mapping each resolved location's comparison key to a queue
        of the stored values it occurs as, in order. Used to tag the effective Path's locations
        with their origin scope and recover the value each one is persisted as, by consuming the
        queues in order. A location occurring more than once has one queue entry per occurrence.
        A stored value that cannot be resolved is omitted because it has no comparison key.
    .PARAMETER Scope
        The scope to read, either "Machine" or "User".
    .OUTPUTS
        A case-insensitive hashtable of location key to a queue of stored location values.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [ValidateSet("Machine", "User")]
        [string] $Scope
    )

    # a PowerShell hashtable literal is case-insensitive and yields $null (not an error) for absent keys
    $storedForms = @{}

    $context = @{ $Scope = $true }
    (Get-EnvironmentVariable @context -Name Path -Expandable -ErrorAction SilentlyContinue) -split $systemPathSeparator `
        | Where-Object {
            $_
        } `
        | ForEach-Object {
            $normalized = ConvertTo-NormalizedLocation -Location $_
            if ($null -eq $normalized) {
                return
            }
            if (-not $storedForms.ContainsKey($normalized)) {
                $storedForms[$normalized] = [System.Collections.Generic.Queue[string]]::new()
            }
            $storedForms[$normalized].Enqueue($_)
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
        Matching is case-insensitive throughout. -Exact is a location and is resolved the way the tested
        location was, so any spelling of the same folder equals it. Repeated and trailing backslashes are
        ignored on the -Contains and -Filter criteria, which are a substring and a wildcard pattern and are
        not resolved; the -Match patterns are applied as given, since a backslash is meaningful in a regular
        expression.
        A location that does not resolve is matched on its stored value, so a %...% reference no variable
        resolves is still found by the criteria naming it.
        A leading '\\' is the one run that carries meaning and is kept, holding a UNC root apart from a single
        leading backslash.
    .PARAMETER Location
        The location to test, already resolved, or null when it could not be resolved.
    .PARAMETER StoredValue
        The value the location is stored as, matched on where the location does not resolve.
    .PARAMETER Exact
        Location the tested location must equal, resolved before comparing.
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
        [Parameter(Mandatory)]
        [AllowNull()]
        $Location,
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string] $StoredValue,
        [string] $Exact,
        [string[]] $Contains,
        [string[]] $Filter,
        [string[]] $Match
    )

    # every criterion below runs against the resolved location,
    # or against the stored value where nothing resolves, e.g. an unset %...% reference
    $searched = ConvertTo-LocationIdentity -StoredValue $StoredValue -Location $Location

    if ($Exact) {
        $exactNormalized = ConvertTo-NormalizedLocation -Location $Exact
        if ($searched -ine (ConvertTo-LocationIdentity -StoredValue $Exact -Location $exactNormalized)) {
            return $false
        }
    }

    foreach ($substring in $Contains) {
        $comparableSubstring = ConvertTo-ComparableLocation -Location $substring
        if (-not $searched.Contains($comparableSubstring, [System.StringComparison]::OrdinalIgnoreCase)) {
            return $false
        }
    }

    foreach ($pattern in $Filter) {
        if ($searched -inotlike (ConvertTo-ComparableLocation -Location $pattern)) {
            return $false
        }
    }

    foreach ($pattern in $Match) {
        if ($searched -inotmatch $pattern) {
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
        StoredValue - the value as persisted, keeping any %...% reference - and its Location, the absolute
        normalized folder that value resolves to, or null when it cannot be resolved.
        For the effective Path (the default) each location is tagged with its origin scope: 'Machine' or 'User' when the
        location is on the corresponding persisted Path, or 'Process' when it is only on the current shell's Path.
        For -Machine or -User every location carries that scope.
        If the -Join switch is specified, the Path is returned as a semicolon-separated string of the stored
        values instead.
        The -Exact, -Contains, -Filter and -Match criteria select locations. Multiple criteria, of the same kind or
        of different kinds, must all be satisfied. Without any criterion, every location is returned.
        A location carrying a %...% reference whose variable is not set is listed with its stored value and an
        empty Location, names the variable in an error of its own, and is selected on that stored value.
    .PARAMETER Machine
        If specified, the system Path for the local machine is returned.
    .PARAMETER User
        If specified, the system Path for the current user is returned.
    .PARAMETER Effective
        Default; if specified, the effective system Path is returned. The effective system Path is the Path in effect in the current shell.
    .PARAMETER Process
        If specified, only the locations local to the current shell are returned, those on neither persisted Path.
    .PARAMETER Join
        If specified, the system Path is returned as a semicolon-separated string of the stored values.
        Otherwise, it is returned as an array of SystemPathLocation objects.
    .PARAMETER Exact
        Exact folder location; only a location equal to it is returned. It is resolved the way the Path's own
        locations are, so any spelling of the same folder matches; comparison is case-insensitive. A leading
        '\\' holds a UNC root apart from a single leading backslash.
        Aliases: Location, Folder.
    .PARAMETER Contains
        Substrings, positional; only locations containing all of them are returned. Taken literally: wildcard and
        regex characters carry no meaning. Matching is case-insensitive and ignores repeated and trailing
        backslashes.
    .PARAMETER Filter
        Wildcard patterns; only locations matching all of them are returned. Matching is case-insensitive and
        ignores repeated and trailing backslashes.
    .PARAMETER Match
        Regular expressions; only locations matching all of them are returned. Matching is case-insensitive.
        An invalid regular expression is a terminating error.
    .OUTPUTS
        SystemPathLocation objects with a Scope, a StoredValue and a Location property, or a
        semicolon-separated string of the stored values when -Join is specified.
    .NOTES
        Alias: path
    .EXAMPLE
        Get-SystemPath
    .EXAMPLE
        Get-SystemPath -Machine
    .EXAMPLE
        Get-SystemPath -User -Join
    .EXAMPLE
        Get-SystemPath -Process
    .EXAMPLE
        Get-SystemPath -Exact "C:\Program Files\Git\bin"
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
        [Parameter(Mandatory, ParameterSetName = "Machine")]
        [switch] $Machine,
        [Parameter(Mandatory, ParameterSetName = "User")]
        [switch] $User,
        [Parameter(ParameterSetName = "Effective")]
        [switch] $Effective,
        [Parameter(Mandatory, ParameterSetName = "Process")]
        [switch] $Process,
        [switch] $Join,
        [Alias("Location", "Folder")]
        [string] $Exact,
        [Parameter(Position = 0, ValueFromRemainingArguments = $true)]
        [string[]] $Contains,
        [string[]] $Filter,
        [ValidRegexAttribute()]
        [string[]] $Match
    )

    $allLocations =
    if ($Machine) {
        # read the stored form so a %...% reference is preserved, then resolve it for Location
        (Get-EnvironmentVariable -Machine -Name Path -Expandable -ErrorAction SilentlyContinue) -split $systemPathSeparator `
            | Where-Object {
                $_
            } `
            | ForEach-Object {
                [SystemPathLocation]::new(
                    "Machine",
                    $_,
                    (ConvertTo-NormalizedLocation -Location $_)
                )
            }
    }
    elseif ($User) {
        (Get-EnvironmentVariable -User -Name Path -Expandable -ErrorAction SilentlyContinue) -split $systemPathSeparator `
            | Where-Object {
                $_
            } `
            | ForEach-Object {
                [SystemPathLocation]::new(
                    "User",
                    $_,
                    (ConvertTo-NormalizedLocation -Location $_)
                )
            }
    }
    else {
        # effective and process: the live shell Path, each location tagged with the persisted scope it originates from.
        # The process Path lists machine locations before user locations, so consume the machine occurrences
        # first, then user; a location on both scopes therefore appears once as Machine and once as User.
        # Windows expands the process block, so the stored %...% form is recovered from the originating scope;
        # a process-only location has no persisted form and keeps the expanded one.
        $machineRemaining = Get-PathScopeStoredForms -Scope Machine
        $userRemaining = Get-PathScopeStoredForms -Scope User

        $env:PATH -split $systemPathSeparator `
            | Where-Object {
                $_
            } `
            | ForEach-Object {
                $normalized = ConvertTo-NormalizedLocation -Location $_
                $scope = "Process"
                $stored = $_

                if ($null -ne $normalized) {
                    if ($machineRemaining[$normalized].Count -gt 0) {
                        $scope = "Machine"
                        $stored = $machineRemaining[$normalized].Dequeue()
                    }
                    elseif ($userRemaining[$normalized].Count -gt 0) {
                        $scope = "User"
                        $stored = $userRemaining[$normalized].Dequeue()
                    }
                }

                [SystemPathLocation]::new($scope, $stored, $normalized)
            }
    }

    # -Process keeps what the scope tagging above found on neither persisted Path
    if ($Process) {
        $allLocations = $allLocations | Where-Object {
            $_.Scope -eq "Process"
        }
    }

    $criteria = @{
        Exact    = $Exact
        Contains = $Contains
        Filter   = $Filter
        Match    = $Match
    }

    $selectedLocations = $allLocations `
        | Where-Object {
            Test-LocationCriteria -Location $_.Location -StoredValue $_.StoredValue @criteria
        }

    # reads name every reference the listed locations carry that no variable resolves
    $selectedLocations `
        | ForEach-Object {
            Write-UnresolvedVariableError -Value $_.StoredValue
        }

    # -Join reproduces the stored form (StoredValue), keeping %...% references
    return $Join `
        ? ((
            $selectedLocations `
                | ForEach-Object {
                    $_.StoredValue
                }
        ) -join $systemPathSeparator) `
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
        listed once per scope, as Windows leaves it, and every location is resolved to its absolute folder.
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
        local machine. The entries' StoredValue is persisted, so a %...% reference is kept as indirection;
        the Path is written as an expandable (REG_EXPAND_SZ) value.
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
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [SystemPathLocation[]] $Entries,
        [Parameter(Mandatory, ParameterSetName = "Machine")]
        [switch] $Machine,
        [Parameter(Mandatory, ParameterSetName = "User")]
        [switch] $User
    )

    # the backup location goes to the caller of Backup-SystemPath, not into this function's output
    Backup-SystemPath | Out-Null

    $context = $Machine `
        ? @{ Machine = $true } `
        : @{ User = $true }

    # persist the stored form so %...% references survive, as an expandable (REG_EXPAND_SZ) value
    $value = (
        $Entries `
            | ForEach-Object {
                $_.StoredValue
            }
    ) -join $systemPathSeparator

    # capture what only the session knows before the write, while a removed location is still
    # distinguishable from one the session added
    $processLocations = Get-ProcessOnlyPathLocations

    # the write stays quiet about the Path's own references: the command that took the location reported them
    Set-EnvironmentVariable @context -Name Path -Value $value -Expandable -ErrorAction SilentlyContinue

    # derive the process Path from both scopes; runs after the write, so it is the authoritative one
    Sync-ProcessPath @processLocations
}

function Add-SystemPathLocation {
    <#
    .SYNOPSIS
        Adds a location to the system Path.
    .DESCRIPTION
        Adds the specified location to the system Path, either for the current user or for the local machine.
        A location naming no existing folder is reported as a terminating error and nothing is written,
        unless -Force is given. The location is checked resolved.
        A %...% reference whose variable is not set names the variable in an error of its own and is added
        anyway, keeping the reference as indirection: what it resolves to once the variable is set is not
        this command's business.
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
    .PARAMETER Force
        Add the location even when it names no existing folder, e.g. to put a folder on the Path
        before whatever creates it runs.
    .NOTES
        Alias: addpath
        Default scope is User.
        An unelevated machine write prompts for elevation once and runs the whole addition elevated.
    .EXAMPLE
        Add-SystemPathLocation -Location "C:\Program Files\Git\bin"
    .EXAMPLE
        Add-SystemPathLocation -Location "C:\Program Files\Git\bin" -Machine
    .EXAMPLE
        Add-SystemPathLocation -Location "C:\Program Files\Git\bin" -User
    .EXAMPLE
        Add-SystemPathLocation -Location "C:\Program Files\Git\bin" -First
    .EXAMPLE
        Add-SystemPathLocation -Location "%JAVA_HOME%\bin" -Force
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param (
        [Parameter(Mandatory, Position = 0)]
        [Alias("Folder")]
        [string] $Location,
        [Alias("Front")]
        [switch] $First,
        [Parameter(Mandatory, ParameterSetName = "Machine")]
        [switch] $Machine,
        [Parameter(ParameterSetName = "User")]
        [switch] $User,
        [switch] $Force
    )

    # fail fast: a machine write that cannot elevate stops before anything is read or written
    if ($Machine -and -not (Test-Elevated)) {
        Assert-SudoAvailable
    }

    # the location is checked before anything is read or written, so -WhatIf reports the error a real run would hit
    $resolvedLocation = ConvertTo-NormalizedLocation -Location $Location

    # a reference no variable resolves is reported and added anyway, keeping the reference as indirection:
    # what it will resolve to once the variable is set is no business of this command
    $unresolved = @(Get-UnresolvedVariableName -Value $Location)
    Write-UnresolvedVariableError -Value $Location

    if (-not $Force -and -not $unresolved -and ($null -eq $resolvedLocation -or -not (Test-Path -LiteralPath $resolvedLocation -PathType Container))) {
        $detail =
        if ($null -eq $resolvedLocation) {
            "location: '$Location', resolved: `$null"
        }
        elseif ($resolvedLocation -ceq $Location) {
            "location: '$Location'"
        }
        else {
            "location: '$Location', resolved: '$resolvedLocation'"
        }

        Write-Error "Location is not an existing folder, use -Force to add it anyway. $detail" `
            -ErrorId "PathLocationNotFound" `
            -Category ObjectNotFound `
            -TargetObject $Location `
            -ErrorAction Stop
    }

    $context = $Machine `
        ? @{ Machine = $true } `
        : @{ User = $true }
    $scope = $Machine `
        ? "Machine" `
        : "User"

    # the read stays quiet: this command reports the references of the location it was given, not those
    # the Path already carries
    $currentEntries = @(Get-SystemPath @context -ErrorAction SilentlyContinue)
    $newEntries = Add-PathLocation -Entries $currentEntries -Location $Location -First:$First -Scope $scope

    # idempotent: nothing changed means the location is already present
    if ((Get-StoredPathString -Entries $newEntries) -eq (Get-StoredPathString -Entries $currentEntries)) {
        Write-Warning "Location is already on the system Path: '$Location'"
        return
    }

    if (-not $PSCmdlet.ShouldProcess($Location, "Add location to system Path")) {
        return
    }

    # when not already elevated, the whole addition runs in an elevated session instead of in-process,
    # so the Path is read and written on the same side of the boundary and never crosses it
    if ($Machine -and -not (Test-Elevated)) {
        $processLocations = Get-ProcessOnlyPathLocations

        $command = @("Add-SystemPathLocation", $Location, "-Machine")
        if ($First) { $command += "-First" }
        if ($Force) { $command += "-Force" }
        Invoke-Elevated $command

        Sync-ProcessPath @processLocations
        return
    }

    # Set-SystemPath rebuilds the process Path, so the new location takes effect immediately
    Set-SystemPath @context -Entries $newEntries
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
        An unelevated machine write prompts for elevation once and runs the whole removal elevated.
    .EXAMPLE
        Remove-SystemPathLocation -Location "C:\Program Files\Git\bin"
    .EXAMPLE
        Remove-SystemPathLocation -Location "C:\Program Files\Git\bin" -Machine
    .EXAMPLE
        Remove-SystemPathLocation -Location "C:\Program Files\Git\bin" -User
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param (
        [Parameter(Mandatory, Position = 0)]
        [Alias("Folder")]
        [string] $Location,
        [Parameter(Mandatory, ParameterSetName = "Machine")]
        [switch] $Machine,
        [Parameter(ParameterSetName = "User")]
        [switch] $User
    )

    # fail fast: a machine write that cannot elevate stops before anything is read or written
    if ($Machine -and -not (Test-Elevated)) {
        Assert-SudoAvailable
    }

    $context = $Machine `
        ? @{ Machine = $true } `
        : @{ User = $true }

    # as in Add-SystemPathLocation: the read reports nothing, the location argument does
    Write-UnresolvedVariableError -Value $Location

    $currentEntries = @(Get-SystemPath @context -ErrorAction SilentlyContinue)
    $newEntries = @(Remove-PathLocation -Entries $currentEntries -Location $Location)

    # idempotent: nothing changed means the location is not present
    if ((Get-StoredPathString -Entries $newEntries) -eq (Get-StoredPathString -Entries $currentEntries)) {
        Write-Warning "Location is not on the system Path: '$Location'"
        return
    }

    if (-not $PSCmdlet.ShouldProcess($Location, "Remove location from system Path")) {
        return
    }

    # as in Add-SystemPathLocation: an unelevated machine write runs the whole removal elevated
    if ($Machine -and -not (Test-Elevated)) {
        $processLocations = Get-ProcessOnlyPathLocations
        Invoke-Elevated Remove-SystemPathLocation $Location -Machine
        Sync-ProcessPath @processLocations
        return
    }

    # Set-SystemPath rebuilds the process Path from both scopes, so the location stays available
    # when the other scope still carries it
    Set-SystemPath @context -Entries $newEntries
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
        A run that changes the machine Path elevates through User Account Control when the session is not
        already elevated: the whole cleanup runs in the elevated session, so it is applied as a whole or
        not at all.
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
        An unelevated run that changes the machine Path prompts for elevation once, before either Path
        is written. Each scope Path is written on its own, leaving one backup file per write.
    .EXAMPLE
        Remove-DuplicateSystemPathLocations
    .EXAMPLE
        Remove-DuplicateSystemPathLocations -Machine
    .EXAMPLE
        Remove-DuplicateSystemPathLocations -KeepUser
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param (
        [Parameter(Mandatory, ParameterSetName = "Machine")]
        [switch] $Machine,
        [Parameter(Mandatory, ParameterSetName = "User")]
        [switch] $User,

        # -KeepMachine and -KeepUser decide a cross-scope duplicate, so they belong to the both-scopes set alone
        [Parameter(ParameterSetName = "BothScopes")]
        [switch] $KeepMachine,
        [Parameter(ParameterSetName = "BothScopes")]
        [switch] $KeepUser
    )

    if ($KeepMachine -and $KeepUser) {
        Write-Error "Specify only one of -KeepMachine and -KeepUser." `
            -ErrorId "ConflictingKeepScope" `
            -Category InvalidArgument `
            -TargetObject "-KeepMachine, -KeepUser" `
            -ErrorAction Stop
    }

    # fail fast: a machine cleanup that cannot elevate stops before any Path is read
    if ($Machine -and -not (Test-Elevated)) {
        Assert-SudoAvailable
    }

    # clean both scopes when neither scope switch is given
    if (-not $Machine -and -not $User) {
        $machineEntries = @(Get-SystemPath -Machine)
        $userEntries = @(Get-SystemPath -User)

        $machineDeduped = @(Remove-DuplicatePathLocation -Entries $machineEntries)
        $userDeduped = @(Remove-DuplicatePathLocation -Entries $userEntries)

        # cross-scope: drop from the non-kept scope every location present in the kept scope
        if ($KeepUser) {
            foreach ($entry in $userDeduped) {
                if ($null -ne $entry.Location) {
                    $machineDeduped = @(Remove-PathLocation -Entries $machineDeduped -Location $entry.Location)
                }
            }
        }
        else {
            foreach ($entry in $machineDeduped) {
                if ($null -ne $entry.Location) {
                    $userDeduped = @(Remove-PathLocation -Entries $userDeduped -Location $entry.Location)
                }
            }
        }

        $machineChanged = (Get-StoredPathString -Entries $machineDeduped) -ne (Get-StoredPathString -Entries $machineEntries)

        # fail fast: a cleanup that cannot elevate stops before the first gate is asked
        if ($machineChanged -and -not (Test-Elevated)) {
            Assert-SudoAvailable
        }

        # both gates are asked before either write, so -WhatIf reports every scope a real run would write
        $writeMachine = $machineChanged `
            -and $PSCmdlet.ShouldProcess("machine", "Remove duplicate locations from system Path")
        $writeUser = (Get-StoredPathString -Entries $userDeduped) -ne (Get-StoredPathString -Entries $userEntries) `
            -and $PSCmdlet.ShouldProcess("user", "Remove duplicate locations from system Path")

        # when not already elevated, the whole cleanup runs in an elevated session instead of in-process:
        # one prompt for both writes, and no half-applied cleanup when it is declined
        if ($writeMachine -and -not (Test-Elevated)) {
            # capture what only the session knows before the elevated writes, while a removed location is
            # still distinguishable from one the session added
            $processLocations = Get-ProcessOnlyPathLocations

            if ($KeepUser) {
                Invoke-Elevated Remove-DuplicateSystemPathLocations -KeepUser
            }
            else {
                Invoke-Elevated Remove-DuplicateSystemPathLocations -KeepMachine
            }

            # the elevated session synced its own process Path; this one derives its own from both scopes
            Sync-ProcessPath @processLocations
            return
        }

        if ($writeMachine) {
            Set-SystemPath -Machine -Entries $machineDeduped
        }

        if ($writeUser) {
            Set-SystemPath -User -Entries $userDeduped
        }
    }
    else {
        $context = $Machine `
            ? @{ Machine = $true } `
            : @{ User = $true }
        $scope = $Machine `
            ? "machine" `
            : "user"

        $currentEntries = @(Get-SystemPath @context)
        $deduped = @(Remove-DuplicatePathLocation -Entries $currentEntries)

        if (-not ((Get-StoredPathString -Entries $deduped) -ne (Get-StoredPathString -Entries $currentEntries) `
                    -and $PSCmdlet.ShouldProcess($scope, "Remove duplicate locations from system Path"))) {
            return
        }

        # as above: an unelevated machine cleanup runs in an elevated session, passing no Path across
        if ($Machine -and -not (Test-Elevated)) {
            $processLocations = Get-ProcessOnlyPathLocations
            Invoke-Elevated Remove-DuplicateSystemPathLocations -Machine
            Sync-ProcessPath @processLocations
            return
        }

        Set-SystemPath @context -Entries $deduped
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
        A move that changes the machine Path elevates through User Account Control when the session is not
        already elevated: the whole move runs in the elevated session, so it is applied as a whole or not
        at all. Moving to the machine Path a location the machine Path already holds changes the user Path
        alone and does not elevate.
    .PARAMETER Location
        Folder location to move, positional.
    .PARAMETER ToUser
        Move the location from the machine system Path to the user system Path.
    .PARAMETER ToMachine
        Move the location from the user system Path to the machine system Path.
    .NOTES
        Alias: movepath
        An unelevated move prompts for elevation once, before either Path is written.
        Both scope Paths are written, each on its own, leaving one backup file per write.
    .EXAMPLE
        Move-SystemPathLocation "C:\Program Files\Git\bin" -ToUser
    .EXAMPLE
        Move-SystemPathLocation "C:\Program Files\Git\bin" -ToMachine
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param (
        [Parameter(Mandatory, Position = 0)]
        [Alias("Folder")]
        [string] $Location,
        [Parameter(Mandatory, ParameterSetName = "ToUser")]
        [switch] $ToUser,
        [Parameter(Mandatory, ParameterSetName = "ToMachine")]
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

    # as in Add-SystemPathLocation: the reads report nothing, the location argument does
    Write-UnresolvedVariableError -Value $Location

    $sourceEntries = @(Get-SystemPath @source -ErrorAction SilentlyContinue)
    $normalized = ConvertTo-NormalizedLocation -Location $Location
    $identity = ConvertTo-LocationIdentity -StoredValue $Location -Location $normalized
    $moved = @(
        $sourceEntries `
            | Where-Object {
                (ConvertTo-LocationIdentity -StoredValue $_.StoredValue -Location $_.Location) -ieq $identity
            }
    )

    # not on the source Path: nothing to move
    if ($moved.Count -eq 0) {
        $onTarget = @(Get-SystemPath @target -ErrorAction SilentlyContinue) `
            | Where-Object {
                (ConvertTo-LocationIdentity -StoredValue $_.StoredValue -Location $_.Location) -ieq $identity
            }

        $reason = $onTarget `
            ? "already on the $targetName Path" `
            : "not on the $sourceName Path"
        Write-Warning "Nothing to move. reason: $reason, location: '$Location'"
        return
    }

    $newSource = @(Remove-PathLocation -Entries $sourceEntries -Location $Location)

    $targetEntries = @(Get-SystemPath @target -ErrorAction SilentlyContinue)
    $onTarget = @(
        $targetEntries `
            | Where-Object {
                (ConvertTo-LocationIdentity -StoredValue $_.StoredValue -Location $_.Location) -ieq $identity
            }
    )
    # append the moved entry, keeping its stored (%...%) form, unless the target already has it
    $targetChanged = $onTarget.Count -eq 0
    $newTarget = $targetChanged `
        ? (@($targetEntries) + @($moved[0])) `
        : $targetEntries

    if (-not $targetChanged) {
        Write-Verbose "Target Path already holds location. scope: $targetName, location: '$Location'"
    }

    # the machine Path is written whenever it is the source, and as the target only when it changes
    $writesMachine = $ToUser -or $targetChanged

    # fail fast: a move that cannot elevate stops before the gate is asked and before any Path is written
    if ($writesMachine -and -not (Test-Elevated)) {
        Assert-SudoAvailable
    }

    if (-not $PSCmdlet.ShouldProcess($Location, "Move location from the $sourceName to the $targetName system Path")) {
        return
    }

    # when not already elevated, the whole move runs in an elevated session instead of in-process:
    # one prompt for both writes, and no half-applied move when it is declined
    if ($writesMachine -and -not (Test-Elevated)) {
        # capture what only the session knows before the elevated writes, while a removed location is
        # still distinguishable from one the session added
        $processLocations = Get-ProcessOnlyPathLocations

        if ($ToUser) {
            Invoke-Elevated Move-SystemPathLocation $Location -ToUser
        }
        else {
            Invoke-Elevated Move-SystemPathLocation $Location -ToMachine
        }

        # the elevated session synced its own process Path; this one derives its own from both scopes
        Sync-ProcessPath @processLocations
        return
    }

    # target first, so a failing write leaves the location on its source Path rather than on neither
    if ($targetChanged) {
        Set-SystemPath @target -Entries $newTarget
    }

    Set-SystemPath @source -Entries $newSource
}

function Test-SystemPathLocation {
    <#
    .SYNOPSIS
        Tests whether a location is on the system Path.
    .DESCRIPTION
        Returns $true if the specified location is present on the system Path, either for the current user,
        for the local machine or the system Path in effect in the current context.
        The location is compared exactly and case-insensitively, resolved the way the Path's own locations
        are, so any spelling of the same folder matches; a substring, a wildcard pattern or a regular
        expression selects nothing. Use Get-SystemPath -Contains, -Filter or -Match for those.
    .PARAMETER Location
        Exact folder location to look for, positional. It is resolved before comparing, so any spelling of
        the same folder matches; comparison is case-insensitive.
        Alias: Folder.
    .PARAMETER Machine
        If specified, the system Path for the local machine is searched.
    .PARAMETER User
        If specified, the system Path for the current user is searched.
    .PARAMETER Effective
        Default; if specified, the system Path in effect in the current shell is searched.
    .PARAMETER Process
        If specified, only the locations local to the current shell are searched, those on neither persisted Path.
    .OUTPUTS
        Boolean indicating whether the location is present.
    .NOTES
        Alias: testpath
    .EXAMPLE
        Test-SystemPathLocation "C:\Program Files\Git\bin"
    .EXAMPLE
        Test-SystemPathLocation "C:\Program Files\Git\bin" -Machine
    .EXAMPLE
        Test-SystemPathLocation -Location "C:\Temp\session" -Process
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param (
        [Parameter(Mandatory, Position = 0)]
        [Alias("Folder")]
        [string] $Location,
        [Parameter(Mandatory, ParameterSetName = "Machine")]
        [switch] $Machine,
        [Parameter(Mandatory, ParameterSetName = "User")]
        [switch] $User,
        [Parameter(ParameterSetName = "Effective")]
        [switch] $Effective,
        [Parameter(Mandatory, ParameterSetName = "Process")]
        [switch] $Process
    )

    # the exact comparison lives in Get-SystemPath -Exact; the scope switch picks its parameter set
    $locations =
    if ($Machine) {
        Get-SystemPath -Exact $Location -Machine
    }
    elseif ($User) {
        Get-SystemPath -Exact $Location -User
    }
    elseif ($Process) {
        Get-SystemPath -Exact $Location -Process
    }
    else {
        Get-SystemPath -Exact $Location -Effective
    }

    return @($locations).Count -gt 0
}

New-Alias -Name addpath -Value Add-SystemPathLocation -ErrorAction SilentlyContinue | Out-Null
New-Alias -Name rmpath -Value Remove-SystemPathLocation -ErrorAction SilentlyContinue | Out-Null
New-Alias -Name cleanpath -Value Remove-DuplicateSystemPathLocations -ErrorAction SilentlyContinue `
    | Out-Null
New-Alias -Name movepath -Value Move-SystemPathLocation -ErrorAction SilentlyContinue | Out-Null
New-Alias -Name testpath -Value Test-SystemPathLocation -ErrorAction SilentlyContinue | Out-Null
