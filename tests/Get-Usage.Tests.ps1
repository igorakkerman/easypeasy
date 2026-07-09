BeforeAll {
    Import-Module "$PSScriptRoot/../easypeasy.psd1" -Force
}

Describe 'Get-Usage' {

    BeforeAll {
        $script:root = Join-Path ([System.IO.Path]::GetTempPath()) "easypeasy-usage-$(New-Guid)"
        New-Item -ItemType Directory -Path "$root\sub" -Force | Out-Null
        Set-Content -Path "$root\sub\file.txt" -Value ('x' * 2048)
    }

    AfterAll { Remove-Item $root -Recurse -Force -ErrorAction SilentlyContinue }

    It 'lists child items of the given location' {
        $output = Get-Usage -Location $root | Out-String
        $output | Should -Match 'sub'
    }

    It 'accepts the location from the pipeline' {
        $output = $root | Get-Usage | Out-String
        $output | Should -Match 'sub'
    }
}
