<#
.SYNOPSIS
    Stages the module for publishing.

.DESCRIPTION
    Copies the files that make up the published module into a staging folder named after the module and
    returns the path to that folder, ready to be passed to Publish-Module. Development artifacts - the
    tests, the agent skills, the instructions for agents, and everything whose name starts with a dot,
    such as the CI workflows and the editor and agent folders - are left out, since Publish-Module
    packs the whole folder it is pointed at.

.PARAMETER Destination
    Folder to stage the module in. Default: a new folder in the temp folder.

.OUTPUTS
    string - Path to the staged module folder.

.EXAMPLE
    ./build.ps1

.EXAMPLE
    Publish-Module -Path (./build.ps1) -Repository PSGallery -NuGetApiKey $key

.EXAMPLE
    ./build.ps1 -Destination .\out
#>
[CmdletBinding()]
[OutputType([string])]
param (
    [string] $Destination = (Join-Path ([System.IO.Path]::GetTempPath()) "easypeasy-build-$(New-Guid)")
)

$ErrorActionPreference = "Stop"

$moduleName = "easypeasy"

# development artifacts, not part of the published package. Everything whose name starts with a dot
# goes too - the repository, the CI workflows, the editor and agent folders, and whatever tool adds
# the next one - so a new dot folder cannot reach the package by being forgotten here.
$excluded = @(
    "tests"
    "skills"
    "AGENTS.md"
    "CLAUDE.md"
    "build.ps1"
)

$destinationRoot = (New-Item -ItemType Directory -Path $Destination -Force).FullName
$stagedModule = Join-Path $destinationRoot $moduleName

if (Test-Path -LiteralPath $stagedModule) {
    Remove-Item -LiteralPath $stagedModule -Recurse -Force
}

New-Item -ItemType Directory -Path $stagedModule -Force | Out-Null

Get-ChildItem -LiteralPath $PSScriptRoot -Force `
| Where-Object { $_.Name -notin $excluded -and -not $_.Name.StartsWith(".") } `
# never copy the destination into itself, which a destination inside the module folder would do
| Where-Object { -not $_.FullName.StartsWith($destinationRoot, [System.StringComparison]::OrdinalIgnoreCase) } `
| ForEach-Object { Copy-Item -LiteralPath $_.FullName -Destination $stagedModule -Recurse -Force }

return $stagedModule
