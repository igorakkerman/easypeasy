$script:moduleRoot = Split-Path $PSScriptRoot -Parent
$script:manifest = Import-PowerShellDataFile "$moduleRoot/easypeasy.psd1"

# What the source defines, read from the AST rather than from the loaded module: the manifest is what makes a
# command visible, so the module's own exports cannot be the yardstick the manifest is measured against.
# A function declared as "function local:Name" is internal and is never exported.
$script:sourceFiles = @(
    Get-ChildItem -LiteralPath $moduleRoot -Filter *.ps1 -File | Where-Object { $_.Name -ne 'build.ps1' }
)

$script:definedFunctions = @(
    $sourceFiles | ForEach-Object {
        $ast = [System.Management.Automation.Language.Parser]::ParseFile($_.FullName, [ref] $null, [ref] $null)
        # top-level statements only, so class constructors and methods are not mistaken for functions
        $ast.EndBlock.Statements `
        | Where-Object { $_ -is [System.Management.Automation.Language.FunctionDefinitionAst] }
    } `
    | ForEach-Object { $_.Name } `
    | Where-Object { -not $_.Contains(':') } `
    | Sort-Object -Unique
)

$script:definedAliases = @(
    $sourceFiles | ForEach-Object {
        [regex]::Matches((Get-Content -LiteralPath $_.FullName -Raw), 'New-Alias\s+-Name\s+(\S+)')
    } `
    | ForEach-Object { $_.Groups[1].Value } `
    | Sort-Object -Unique
)

BeforeAll {
    Import-Module "$PSScriptRoot/../easypeasy.psd1" -Force
    $script:module = Get-Module easypeasy
}

Describe 'easypeasy.psd1' {

    Context 'functions' {

        It 'lists every public function the source defines' {
            $unlisted = @($definedFunctions | Where-Object { $_ -notin $manifest.FunctionsToExport })

            $unlisted | Should -BeNullOrEmpty -Because "FunctionsToExport hides: $($unlisted -join ', ')"
        }

        It 'lists no function the source does not define' {
            $undefined = @($manifest.FunctionsToExport | Where-Object { $_ -notin $definedFunctions })

            $undefined | Should -BeNullOrEmpty -Because "FunctionsToExport names: $($undefined -join ', ')"
        }

        It 'exports every function it lists' {
            $unexported = @($manifest.FunctionsToExport | Where-Object { -not $module.ExportedFunctions.ContainsKey($_) })

            $unexported | Should -BeNullOrEmpty -Because "the module does not export: $($unexported -join ', ')"
        }

        It 'exports every listed function as a resolvable command' {
            $unresolved = @($manifest.FunctionsToExport | Where-Object { -not (Get-Command $_ -Module easypeasy -ErrorAction SilentlyContinue) })

            $unresolved | Should -BeNullOrEmpty -Because "these do not resolve: $($unresolved -join ', ')"
        }
    }

    Context 'aliases' {

        It 'lists every alias the source registers' {
            $unlisted = @($definedAliases | Where-Object { $_ -notin $manifest.AliasesToExport })

            $unlisted | Should -BeNullOrEmpty -Because "AliasesToExport hides: $($unlisted -join ', ')"
        }

        It 'lists no alias the source does not register' {
            $unregistered = @($manifest.AliasesToExport | Where-Object { $_ -notin $definedAliases })

            $unregistered | Should -BeNullOrEmpty -Because "AliasesToExport names: $($unregistered -join ', ')"
        }

        It 'exports every alias it lists' {
            $unexported = @($manifest.AliasesToExport | Where-Object { -not $module.ExportedAliases.ContainsKey($_) })

            $unexported | Should -BeNullOrEmpty -Because "the module does not export: $($unexported -join ', ')"
        }

        It 'points every listed alias at an exported function' {
            $dangling = @(
                $manifest.AliasesToExport `
                | Where-Object { $module.ExportedAliases[$_].Definition -notin $manifest.FunctionsToExport }
            )

            $dangling | Should -BeNullOrEmpty -Because "these point outside the exported functions: $($dangling -join ', ')"
        }
    }

    Context 'export lists' {

        It 'names <_> explicitly, without a wildcard' -ForEach @('FunctionsToExport', 'AliasesToExport') {
            $manifest[$_] | Should -Not -BeNullOrEmpty
            @($manifest[$_] | Where-Object { $_ -match '\*|\?' }) | Should -BeNullOrEmpty
        }

        It 'exports no cmdlet' {
            $manifest.CmdletsToExport | Should -BeNullOrEmpty
        }
    }
}
