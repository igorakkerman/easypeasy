# AGENTS.md

This file provides guidance to coding agents when working with code in this repository.

## What this is

`easypeasy` is a PowerShell 7 (Core-only) module published to the PowerShell Gallery. It wraps common Windows system-administration tasks (system PATH, environment variables, Start Menu shortcuts, scheduled tasks, theme switching, timestamps, disk usage, admin checks) behind `Verb-Noun` functions plus short aliases.

## Architecture

- `easypeasy.psm1` is the root **module**. It does nothing but dot-source each domain `.ps1` file in `$PSScriptRoot`. Load order matters: helpers like `timestamp.ps1`, `administrator.ps1`, and `environment.ps1` are sourced before the files that depend on them.
- `easypeasy.psd1` is the manifest. **`FunctionsToExport` and `AliasesToExport` are explicit lists (no wildcards).** A new public function or alias is invisible to module consumers until its name is added here — keep these in sync when adding/renaming exports.
- Each `.ps1` is one domain, e.g. `systempath.ps1`, `environment.ps1`, `startmenu.ps1`, `shortcut.ps1`, `task.ps1`, `theme.ps1`, `specialfolder.ps1`, `volume.ps1`, `explorer.ps1`, `administrator.ps1`, `timestamp.ps1`.
- Layering: `systempath.ps1` builds on `environment.ps1` (PATH is just an env var); `startmenu.ps1` dot-sources `shortcut.ps1`; most write operations call `Assert-Administrator` (from `administrator.ps1`).

## Conventions (match these when editing)

- **Internal helpers are scoped with `function local:Name`** (e.g. `local:Add-PathLocation`, `local:Send-ThemeChangeBroadcast`) so they aren't exported. Public functions are plain `function Name`.
- **Aliases** are registered at the bottom of each file: `New-Alias -Name x -Value Verb-Noun -ErrorAction SilentlyContinue | Out-Null`. The alias must also be listed in `AliasesToExport` in the manifest. Document the alias in the function's help under `.NOTES` (`Alias: x`) — comment-based help has no keyword for aliases.
- **Machine / User / Effective parameter-set pattern**: read functions offer `-Machine`, `-User`, and a default `-Effective` (current-process value); write functions offer `-Machine` (the default) and `-User`. When the effective target is Machine, the function calls `Assert-Administrator` first.
- **State-changing functions use `[CmdletBinding(SupportsShouldProcess)]`** and gate the mutation behind `if ($PSCmdlet.ShouldProcess(...))`, so `-WhatIf`/`-Confirm` work. Preserve this when adding side effects.
- PATH edits keep the current process (`$env:PATH`) and the persisted registry value in sync; location comparisons ignore trailing backslashes.

## Developing

No build step. Iterate by importing the module from source:

```powershell
Import-Module .\easypeasy.psd1 -Force
```

### Testing

Tests are Pester v5 specs in `tests/`, one file per command (`tests/<Command>.Tests.ps1`). They assert observable behavior and mock side effects — registry, scheduled tasks, file/registry writes, and even module-internal helpers — with `Mock -ModuleName easypeasy`. State-changing functions are also checked under `-WhatIf`. Run:

```powershell
Invoke-Pester -Path ./tests -Output Detailed
```

Needs Pester 6.0.0 (Windows ships 3.x); install with `Install-Module Pester -MinimumVersion 6.0.0 -Scope CurrentUser -Force -SkipPublisherCheck`. CI runs the suite on every push and pull request (`.github/workflows/test.yaml`).

Lint with PSScriptAnalyzer (config in `.vscode/analyzersettings.psd1`):

```powershell
Invoke-ScriptAnalyzer -Path . -Settings .vscode\analyzersettings.psd1 -Recurse
```

## Releasing

Publishing is automated by `.github/workflows/publish.yaml`: creating a GitHub **release** (tag `vX.Y.Z`) runs `Publish-Module` to the PowerShell Gallery.

- **Version** — bump `ModuleVersion` in `easypeasy.psd1` following SemVer: **patch** for fixes/docs, **minor** for new public functions or aliases. Commit the bump on its own (`Bump module version to vX.Y.Z`).
- **Notes** — `CHANGELOG.md` is the source of truth for release notes ([Keep a Changelog](https://keepachangelog.com/en/1.1.0/) format, newest first); each GitHub release mirrors its matching section. Add a `## [X.Y.Z] - YYYY-MM-DD` section for the release before tagging.
- **Cut the release** — tag `vX.Y.Z` and mirror that changelog section into the release body: `gh release create vX.Y.Z --title vX.Y.Z --notes-file <section>`. Revise a body later with `gh release edit vX.Y.Z --notes-file <section>`.
- **Auth** — the workflow signs in with the `GALLERY_KEY` repo secret (a PowerShell Gallery API key). An invalid/expired key fails the `Publish` step with HTTP **403**; update it via `gh secret set GALLERY_KEY`, then `gh run rerun <run-id>` — no need to recreate the release.
- **Verify** — watch with `gh run watch <run-id>`, then confirm the package with `Find-Module easypeasy -RequiredVersion X.Y.Z`.
