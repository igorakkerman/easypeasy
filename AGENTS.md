# AGENTS.md

This file provides guidance to coding agents when working with code in this repository.

## What this is

`easypeasy` is a PowerShell 7 (Core-only) module published to the PowerShell Gallery. It wraps common Windows system-administration tasks (system Path, environment variables, Start Menu shortcuts, scheduled tasks, timestamps, admin checks) behind `Verb-Noun` functions plus short aliases.

Consumer-facing breaking changes and the v1 → v2 migration steps are documented in `UPGRADING.md`; keep it in sync when renaming or removing a public function, parameter or alias.

## Architecture

- `easypeasy.psm1` is the root **module**. It does nothing but dot-source each `.ps1` file in `$PSScriptRoot`, and is the only place load order is decided — no file dot-sources another. Order matters: `common.ps1` comes first, then helpers like `timestamp.ps1`, `elevate.ps1` and `environment.ps1` before the files that depend on them, and `shortcut.ps1` before `startmenu.ps1`.
- `easypeasy.psd1` is the manifest. **`FunctionsToExport` and `AliasesToExport` are explicit lists (no wildcards).** A new public function or alias is invisible to module consumers until its name is added here — keep these in sync when adding/renaming exports.
- Each `.ps1` is one domain, e.g. `systempath.ps1`, `environment.ps1`, `startmenu.ps1`, `shortcut.ps1`, `task.ps1`, `specialfolder.ps1`, `explorer.ps1`, `elevate.ps1`, `timestamp.ps1`. The exception is `common.ps1`, which holds what is shared across domains: the single `$wshShell` WScript.Shell COM object used by the shortcut, Start Menu and special folder functions.
- Layering: `systempath.ps1` builds on `environment.ps1` (Path is just an env var); `startmenu.ps1` builds on `shortcut.ps1`: its shortcut functions resolve `<Programs>\<Folder>\<Name>.lnk`, then hand every shortcut field to `New-Shortcut`, which owns the creation, the `-Force` check and the `ShouldProcess` gate. `New-Shortcut` validates the shortcut folder before that gate, so `-WhatIf` reports the error a real run would hit, and the Start Menu functions pass `-CreateFolder` because they own that folder; a `-Machine` write that is not already elevated re-runs itself through `Invoke-Elevated` (from `elevate.ps1`). `Assert-Elevation` stays exported for callers that want a hard admin check.

## Conventions (match these when editing)

- **Internal helpers are scoped with `function local:Name`** (e.g. `local:Add-PathLocation`, `local:Set-SystemPath`) so they aren't exported. Public functions are plain `function Name`.
- **Aliases** are registered at the bottom of each file: `New-Alias -Name x -Value Verb-Noun -ErrorAction SilentlyContinue | Out-Null`. The alias must also be listed in `AliasesToExport` in the manifest. Document the alias in the function's help under `.NOTES` (`Alias: x`) — comment-based help has no keyword for aliases.
- **Machine / User / Effective parameter-set pattern**: read functions offer `-Machine`, `-User`, and a default `-Effective` (current-process value); write functions offer `-Machine` and `-User` (the default). Inside its `ShouldProcess` block a write checks `Test-Elevation`; a `-Machine` write that is not already elevated calls `Invoke-Elevated <self> <args>`, which runs the command elevated inline in the current terminal (`sudo --inline`) instead of writing in-process. Either way the parent syncs its own process afterward.
- **State-changing functions use `[CmdletBinding(SupportsShouldProcess)]`** and gate the mutation behind `if ($PSCmdlet.ShouldProcess(...))`, so `-WhatIf`/`-Confirm` work. Preserve this when adding side effects.
- Path edits keep the current process (`$env:PATH`) and the persisted registry value in sync; location comparisons ignore trailing backslashes.
- **Message format** (errors, warnings, and any other log output): name the subject, then attach data as `field: value` pairs. A single value is appended after a colon (`Environment variable not found: $Name`); multiple values are a period-terminated sentence followed by comma-separated pairs (`Environment variable has a blank value. name: $Name, value: '$value'`). Quote values that may be empty or blank.
- **Parameter attributes**: never write `Mandatory = $false` — it is the default. Where it is all the attribute holds, drop the whole `[Parameter()]` line; where the attribute also carries `ParameterSetName` or the like, keep that and drop only the `Mandatory`. Keep the mandatory parameters grouped at the top of the `param` block, in the order the comment-based help lists them. Keep a `Position =` that is already there, even where it is redundant; do not add one where it is missing, unless the user explicitly requests it.
- **Error metadata**: an error naming a condition a caller may want to catch or filter carries `-ErrorId`, `-Category` and `-TargetObject` on `Write-Error`, never a bare message string alone — a bare string arrives uncategorized with no target, so category filters and `$_.TargetObject` come up empty. Add `-ErrorAction Stop` where the condition ends the command; leave it off, followed by `return`, where the caller's `-ErrorAction` should govern (a not-found read, say). **Do not pass `-Exception`**: its only effect is to enable `catch [Type]`, and a .NET exception type would claim a parent failure the module is not having. `-ErrorId` is what callers discriminate on. Write each parameter on its own continuation line, message first.

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

Tests are Pester v6 specs in `tests/`, one file per command (`tests/<Command>.Tests.ps1`). They assert observable behavior and mock side effects — registry, scheduled tasks, file/registry writes, and even module-internal helpers — with `Mock -ModuleName easypeasy`. State-changing functions are also checked under `-WhatIf`. Run the full suite before every commit; do not commit if any test fails:

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
