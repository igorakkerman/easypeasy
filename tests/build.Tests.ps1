BeforeAll {
    $script:buildScript = "$PSScriptRoot/../build.ps1"
}

Describe 'build.ps1' {

    BeforeAll {
        $script:destination = Join-Path ([IO.Path]::GetTempPath()) "easypeasy-build-test-$(New-Guid)"
        $script:staged = & $script:buildScript -Destination $script:destination
        $script:stagedNames = @(Get-ChildItem -LiteralPath $script:staged -Force | ForEach-Object { $_.Name })
    }

    AfterAll {
        Remove-Item -LiteralPath $script:destination -Recurse -Force -ErrorAction SilentlyContinue
    }

    It 'stages into a folder named after the module' {
        (Split-Path $script:staged -Leaf) | Should -Be 'easypeasy'
    }

    It 'stages the module <file>' -ForEach @(
        @{ file = 'easypeasy.psd1' }
        @{ file = 'easypeasy.psm1' }
        @{ file = 'easypeasy.format.ps1xml' }
        @{ file = 'systempath.ps1' }
        @{ file = 'environment.ps1' }
        @{ file = 'LICENSE.txt' }
        @{ file = 'README.md' }
    ) {
        $script:stagedNames | Should -Contain $file
    }

    It 'leaves out the development artifact <artifact>' -ForEach @(
        @{ artifact = 'tests' }
        @{ artifact = 'skills' }
        @{ artifact = 'AGENTS.md' }
        @{ artifact = 'CLAUDE.md' }
        @{ artifact = 'build.ps1' }
    ) {
        $script:stagedNames | Should -Not -Contain $artifact
    }

    It 'leaves out every entry whose name starts with a dot' {
        # .git, .github, .vscode, .claude, and whatever tool adds the next one
        @($script:stagedNames | Where-Object { $_.StartsWith('.') }) | Should -BeNullOrEmpty
    }
}
