# AGENTS.md

This file provides guidance to coding agents when working with code in this repository.

## What this is

`easypeasy` is a PowerShell 7 (Core-only) module published to the PowerShell Gallery. It wraps common Windows system-administration tasks (system Path, environment variables, Start Menu shortcuts, scheduled tasks, timestamps, admin checks) behind `Verb-Noun` functions plus short aliases.

Consumer-facing breaking changes and the v1 → v2 migration steps are documented in `UPGRADING-v2.md`; keep it in sync when renaming or removing a public function, parameter or alias.

## Architecture

- `easypeasy.psm1` is the root **module**: dot-sources each `.ps1` in `$PSScriptRoot`, only place load order is decided — no file dot-sources another. Order matters: `common.ps1` first, then helpers `timestamp.ps1`, `elevate.ps1`, `environment.ps1` before their dependents, `shortcut.ps1` before `startmenu.ps1`.
- `easypeasy.psd1` is the manifest. **`FunctionsToExport` and `AliasesToExport` are explicit lists (no wildcards).** New public function or alias stays invisible to consumers until listed here — keep in sync when adding or renaming exports.
- Each `.ps1` is one domain: `systempath.ps1`, `environment.ps1`, `startmenu.ps1`, `shortcut.ps1`, `task.ps1`, `specialfolder.ps1`, `explorer.ps1`, `elevate.ps1`, `timestamp.ps1`. Exception is `common.ps1`, holding what crosses domains: single `$wshShell` WScript.Shell COM object used by shortcut, Start Menu and special folder functions.
- Layering: `systempath.ps1` builds on `environment.ps1` (Path is an env var); `startmenu.ps1` builds on `shortcut.ps1` — its shortcut functions resolve `<Programs>\<Folder>\<Name>.lnk`, then hand every field to `New-Shortcut`, which owns creation, `-Force` check and `ShouldProcess` gate. `New-Shortcut` validates the shortcut folder before that gate, so `-WhatIf` reports the error a real run hits; Start Menu functions pass `-CreateFolder`, owning that folder. `Assert-Elevated` stays exported for callers wanting a hard admin check.
- **Elevation** covers writes only administrators may perform: `-Machine` on Path and environment functions, `-AllUsers` on Start Menu ones, `-Elevated` on `Register-LogonTask` (task registered at logon privileges of the current user needs none). Two shapes:
  - **Re-run the whole command** through `Invoke-Elevated` (`elevate.ps1`) when the session is not elevated, then sync whatever the parent caches. One prompt per command, never one per write; read-modify-write stays inside the elevated session instead of straddling it.
  - **Elevate one primitive alone** — `Register-LogonTask -Elevated` and the Start Menu functions build in-process, needing no privilege, then elevate `Register-ScheduledTask -Xml`, `New-Item`, `Copy-Item` or `Remove-Item`. **Elevated session runs a built-in, not a module command**, so the write no longer depends on the child resolving `easypeasy` on its own `PSModulePath`, and no parameter value crosses as text. Prefer wherever the privileged step is a single primitive fed by something the module hands over — serialized object, or path.
  - `New-StartMenuShortcut -AllUsers` shows that pattern where the primitive writes a file: shortcut built unelevated in a staging folder mirroring Programs, published by one merging `Copy-Item`, folder and shortcut behind a single prompt. It owns the `-Force` check itself, against the published location, since the `New-Shortcut` running there writes to staging.
  - Exception: `Set-`/`Remove-EnvironmentVariable`, the primitive Path functions write through, elevates its own single write.
  - A command that will elevate calls `local:Assert-SudoAvailable` first — as early as the elevation is known, before any read, prompt or write — so sudo missing, switched off in Settings or by group policy, or capped below inline mode fails the command up front, not halfway through. `Invoke-Elevated` asserts again before running sudo.

## Conventions (match these when editing)

- **Internal helpers are scoped with `function local:Name`** (e.g. `local:Add-PathLocation`, `local:Set-SystemPath`) so they aren't exported. Public functions are plain `function Name`.
- **A simple internal helper takes the short form**, `function local:quote($Value) { ... }`, preceded by a one-line comment where it needs one: a short bare name instead of `Verb-Noun`, no `[CmdletBinding()]`, no `param` block, no comment-based help. The `Verb-Noun` name with the full signature and help is for public functions, and for a helper whose parameters carry attributes, validation or parameter sets.
- **Aliases** are registered at the bottom of each file: `New-Alias -Name x -Value Verb-Noun -ErrorAction SilentlyContinue | Out-Null`. The alias must also be listed in `AliasesToExport` in the manifest. Document the alias in the function's help under `.NOTES` (`Alias: x`) — comment-based help has no keyword for aliases.
- **Machine / User / Effective parameter-set pattern**: read functions offer `-Machine`, `-User`, and a default `-Effective` (current-process value); write functions offer `-Machine` and `-User` (the default). Inside its `ShouldProcess` block a write checks `Test-Elevated`; a `-Machine` write that is not already elevated calls `Invoke-Elevated <self> <args>`, which runs the command elevated inline in the current terminal (`sudo --inline`) instead of writing in-process. Either way the parent syncs its own process afterward.
- **State-changing functions use `[CmdletBinding(SupportsShouldProcess)]`** and gate the mutation behind `if ($PSCmdlet.ShouldProcess(...))`, so `-WhatIf`/`-Confirm` work. Preserve this when adding side effects.
- Path edits keep the current process (`$env:PATH`) and the persisted registry value in sync; location comparisons go through `local:ConvertTo-ComparableLocation`, which ignores repeated and trailing backslashes.
- **Unresolved `%...%` references never fail a command.** `local:Get-UnresolvedVariableName` names the references a value carries that the process environment does not set; `ConvertTo-NormalizedLocation` returns `$null` for such a value rather than prefixing the current directory to it, and `local:ConvertTo-LocationIdentity` falls back to the comparable stored value, so an unresolved reference is matched, selected, deduplicated and scope-tagged by the reference itself. **Every comparison of a stored value goes through that identity**, `local:Get-PathScopeStoredForms` included — keying it on the resolved location alone drops unresolved references from the scope maps, and `Get-SystemPath` then tags a persisted `%...%\bin` as `Process`, which makes every write re-add it to the process Path and leaves `Remove-SystemPathLocation` unable to clear it. The identity is for equality — `-Exact` included, both sides being locations; the text criteria `-Contains`, `-Filter` and `-Match` are not equality and search **both** forms of an entry, the comparable stored value and the resolved location, either satisfying the criterion. A resolved entry searched on its identity alone is not found by the reference it is stored as. `local:Write-UnresolvedVariableWarning` reports one **warning** per missing variable — the command completes, so an error would leave `$?` false and end a caller running under `-ErrorAction Stop` — and only where a command puts such a value on a scope that did not carry it: `Add-SystemPathLocation`, `Move-SystemPathLocation` and `Set-EnvironmentVariable -Expandable`. A read says nothing, the listing accenting the entry itself, and a removal says nothing either, an unresolved reference being the reason to be rid of the entry rather than news about it — a warning far from the value it is about only puzzles the reader.
- **`SystemPathLocation.Location` is typed `[string]`, so the `$null` it is constructed with arrives as an empty string.** Test it with `[string]::IsNullOrEmpty`, never against `$null` — `$null -eq $_.Location` is always false, which silently sent an unresolved reference down the resolved-location branch of `easypeasy.format.ps1xml`.
- **Message format** (errors, warnings, and any other log output): name the subject, then attach data as `field: value` pairs. A single value is appended after a colon (`Environment variable not found: $Name`); multiple values are a period-terminated sentence followed by comma-separated pairs (`Environment variable has a blank value. name: $Name, value: '$value'`). Quote values that may be empty or blank.
- **Parameter attributes**: never write `Mandatory = $false` — it is the default. Where it is all the attribute holds, drop the whole `[Parameter()]` line; where the attribute also carries `ParameterSetName` or the like, keep that and drop only the `Mandatory`. Keep the mandatory parameters grouped at the top of the `param` block, in the order the comment-based help lists them, with no blank line between parameters, whatever attributes they carry. Keep a `Position =` that is already there, even where it is redundant; do not add one where it is missing, unless the user explicitly requests it.
- **Error metadata**: an error naming a condition a caller may want to catch or filter carries `-ErrorId`, `-Category` and `-TargetObject` on `Write-Error`, never a bare message string alone — a bare string arrives uncategorized with no target, so category filters and `$_.TargetObject` come up empty. Add `-ErrorAction Stop` where the condition ends the command; leave it off, followed by `return`, where the caller's `-ErrorAction` should govern (a not-found read, say). **Do not pass `-Exception`**: its only effect is to enable `catch [Type]`, and a .NET exception type would claim a parent failure the module is not having. `-ErrorId` is what callers discriminate on. Write each parameter on its own continuation line, message first.
- **A requirement is stated positively, and nothing else.** `PowerShell 7.4 or later` — not what it excludes (`does not run on 5.1 or 6`), not why the floor sits there (`oldest supported release`). Holds for README, `CHANGELOG.md` and comment-based help alike.
- **Listing marks are settings, not constants.** `easypeasy.format.ps1xml` reads `EASYPEASY_USE_COLORS` (default `true`) and `EASYPEASY_USE_WARNING_SYMBOL` (default `false`) per row, takes `true` or `false` case-insensitively and warns on anything else, keeping the default. An environment variable holds no boolean — `$true` arrives as the string `True`, which the case-insensitive parse covers. The symbol trails the folder rather than prefixing it, so however wide a terminal draws the glyph no column moves. **A warning raised from a format scriptblock goes to the host, not the pipeline** — neither `-WarningVariable` nor `3>&1` reaches it unless `Format-Table` is spelled out ahead of `Out-String`, which is why `New-Rendered` in `tests/Format.Tests.ps1` does.

## Developing

No build step for development. Iterate by importing the module from source:

```powershell
Import-Module .\easypeasy.psd1 -Force
```

`build.ps1` is only for packaging: it stages the publishable files into a folder named after the module and returns its path. `Publish-Module` packs the whole folder it is pointed at, so the staging leaves out the development artifacts: `tests/`, `AGENTS.md`, `CLAUDE.md`, `build.ps1` itself, and **everything whose name starts with a dot** (`.git/`, `.github/`, `.vscode/`, `.claude/`, and whatever tool adds the next one) — a new dot folder is excluded without touching the list. Run it to inspect what a release would ship:

```powershell
./build.ps1 -Destination .\out
```

### Testing

- Pester v6 specs in `tests/`, one file per command, grouped into a folder named after the module file the command lives in: `tests/<module>/<Command>.Tests.ps1`, e.g. `tests/systempath/Get-SystemPath.Tests.ps1`. Specs covering the package rather than one module — `build.Tests.ps1`, `Format.Tests.ps1`, `Manifest.Tests.ps1` — stay at the root of `tests/`.
- Assert observable behavior; mock side effects — registry, scheduled tasks, file and registry writes, module-internal helpers — with `Mock -ModuleName easypeasy`. State-changing functions are also checked under `-WhatIf`.
- **A spec asserts what a command does, never how it arranges the work.** The outcome — file written, value persisted, record returned, warning raised — survives any rewrite of the internals; the shape of an argument array, the helper picked, the order of internal steps does not, and a spec pinned to those fails on every refactor that keeps the behavior. Mock a collaborator to keep the side effect off the machine, then assert the state the run leaves behind. Where the module writes past a boundary it cannot read back — registry, scheduled tasks — the values handed to that boundary are the outcome, and asserting them is the exception, not the pattern. Every new spec follows this; an existing one moves over as it is touched.
- Elevated writes take that through `tests/ElevatedSession.ps1`: `$elevatedSessionMock` runs whatever command `Invoke-Elevated` is handed in-process with `Test-Elevated` true, `$elevatedTestMock` reports that state. Point the scope at a temp folder (`Get-StartMenuProgramsLocation`, say), then assert the file the run leaves, its fields, and that exactly one elevation happened.
- **Any test reaching a function that auto-elevates must mock `Test-Elevated` (`{ $true }` for the in-process path) and `Invoke-Elevated`** — unmocked, the test opens a real UAC dialog and writes to the real machine. Mock `Invoke-Elevated { throw 'should not elevate' }` in the surrounding `BeforeEach`, so an unexpected elevation fails the test instead of prompting.
- A test taking the unelevated path also mocks `Assert-SudoAvailable { }`, otherwise it passes or fails by whether the host has the Windows sudo feature.
- **Fixture locations name folders no real Path carries** (`C:\EasypeasyTool\bin`, not `C:\Program Files\Git\bin`): an effective `Get-SystemPath` read recovers `Scope` and `StoredValue` from the persisted scopes, so a fixture the host happens to carry makes the test pass or fail by machine.

Run the full suite before every commit; do not commit if any test fails:

```powershell
Invoke-Pester -Path ./tests -Output Detailed
```

Needs Pester 6.0.0 or later (Windows ships 3.x); install with `Install-Module Pester -MinimumVersion 6.0.0 -Scope CurrentUser -Force -SkipPublisherCheck`. CI runs the suite on every push and pull request (`.github/workflows/test.yaml`).

Lint with PSScriptAnalyzer (config in `.vscode/analyzersettings.psd1`):

```powershell
Invoke-ScriptAnalyzer -Path . -Settings .vscode\analyzersettings.psd1 -Recurse
```

## Releasing

Publishing is automated by `.github/workflows/publish.yaml`: creating a GitHub **release** (tag `vX.Y.Z`) stages the package with `build.ps1` and runs `Publish-Module` on the staged folder to the PowerShell Gallery.

- **Version** — bump `ModuleVersion` in `easypeasy.psd1` following SemVer: **patch** for fixes/docs, **minor** for new public functions or aliases. Commit the bump on its own (`Bump module version to vX.Y.Z`).
- **Notes** — `CHANGELOG.md` is the source of truth for release notes ([Keep a Changelog](https://keepachangelog.com/en/1.1.0/) format, newest first); each GitHub release mirrors its matching section. Add a `## [X.Y.Z] - YYYY-MM-DD` section for the release before tagging.
- **Cut the release** — tag `vX.Y.Z` and mirror that changelog section into the release body: `gh release create vX.Y.Z --title vX.Y.Z --notes-file <section>`. Revise a body later with `gh release edit vX.Y.Z --notes-file <section>`.
- **Auth** — the workflow signs in with the `GALLERY_KEY` repo secret (a PowerShell Gallery API key). An invalid/expired key fails the `Publish` step with HTTP **403**; update it via `gh secret set GALLERY_KEY`, then `gh run rerun <run-id>` — no need to recreate the release.
- **Verify** — watch with `gh run watch <run-id>`, then confirm the package with `Find-Module easypeasy -RequiredVersion X.Y.Z`.

### Changelog style

Entries are terse. Write the change, then stop.

- **No articles** — `a`, `an`, `the`. e.g. `Removed: Entire component — Get-Theme, Set-Theme, Switch-Theme and alias theme.` — not `The entire component ... and the alias theme`.
- **Drop implied auxiliaries** — `Administrator privileges no longer required by default.` — not `are no longer required`. `tests, CI workflows and editor settings staged out` — not `are staged out`.
- **State the change, not its rationale, mechanics or consequences.** `Added: -WhatIf and -Confirm on Register-LogonTask` — not `... — the task is registered only after confirmation; -WhatIf reports what it would register without touching the task scheduler`. `rejects invalid regular expressions` — not `rejects an invalid regular expression up front, naming the pattern and the reason`.
- **Release summary** — short paragraphs separated by blank lines, one theme each.
