BeforeAll {
    Import-Module "$PSScriptRoot/../easypeasy.psd1" -Force
}

Describe 'Backup-SystemPath' {

    BeforeAll {
        $script:tempDir = Join-Path ([System.IO.Path]::GetTempPath()) "easypeasy-backup-$(New-Guid)"
        New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
        $script:originalTemp = $env:TEMP
    }

    BeforeEach {
        $env:TEMP = $tempDir
        Mock -ModuleName easypeasy Get-Timestamp { 'STAMP' }
        Get-ChildItem $tempDir -Filter 'PATH-*.txt' | Remove-Item -Force
    }

    AfterAll {
        $env:TEMP = $originalTemp
        Remove-Item $tempDir -Recurse -Force -ErrorAction SilentlyContinue
    }

    It 'writes the current PATH to a timestamped file in TEMP' {
        Backup-SystemPath

        $backup = Join-Path $tempDir 'PATH-STAMP.txt'
        $backup | Should -Exist
        (Get-Content $backup -Raw).Trim() | Should -Be $env:PATH
    }

    It 'writes no file under -WhatIf' {
        Backup-SystemPath -WhatIf
        Join-Path $tempDir 'PATH-STAMP.txt' | Should -Not -Exist
    }
}
