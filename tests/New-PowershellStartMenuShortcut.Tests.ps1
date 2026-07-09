BeforeAll {
    Import-Module "$PSScriptRoot/../easypeasy.psd1" -Force
    $script:wsh = New-Object -ComObject WScript.Shell
}

Describe 'New-PowershellStartMenuShortcut' {

    BeforeAll {
        $script:folder = Join-Path ([System.IO.Path]::GetTempPath()) "easypeasy-ps-$(New-Guid)"
        New-Item -ItemType Directory -Path $folder -Force | Out-Null
    }

    BeforeEach {
        Mock -ModuleName easypeasy Get-StartMenuProgramsPath { $folder }
    }

    AfterAll { Remove-Item $folder -Recurse -Force -ErrorAction SilentlyContinue }

    It 'creates a pwsh shortcut that runs the command' {
        $path = New-PowershellStartMenuShortcut -Command 'Get-Date' -Name 'ShowDate'

        $path | Should -Exist
        $shortcut = $wsh.CreateShortcut($path)
        $shortcut.TargetPath | Should -Match 'pwsh'
        $shortcut.Arguments | Should -Match '-Command'
    }

    It 'keeps the window open with -KeepOpen (-NoExit)' {
        $path = New-PowershellStartMenuShortcut -Command 'Get-Date' -Name 'KeepOpen' -KeepOpen
        $wsh.CreateShortcut($path).Arguments | Should -Match '-NoExit'
    }
}
