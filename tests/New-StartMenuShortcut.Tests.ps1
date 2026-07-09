BeforeAll {
    Import-Module "$PSScriptRoot/../easypeasy.psd1" -Force
    $script:wsh = New-Object -ComObject WScript.Shell
}

Describe 'New-StartMenuShortcut' {

    BeforeAll {
        $script:folder = Join-Path ([System.IO.Path]::GetTempPath()) "easypeasy-sm-$(New-Guid)"
        New-Item -ItemType Directory -Path $folder -Force | Out-Null
    }

    BeforeEach {
        Mock -ModuleName easypeasy New-StartMenuProgramsFolder { $folder }
    }

    AfterAll { Remove-Item $folder -Recurse -Force -ErrorAction SilentlyContinue }

    It 'creates a .lnk pointing at the executable' {
        $path = New-StartMenuShortcut -Name 'MyApp' -Executable 'C:\Windows\notepad.exe'

        $path | Should -Exist
        $wsh.CreateShortcut($path).TargetPath | Should -Be 'C:\Windows\notepad.exe'
    }

    It 'creates no file under -WhatIf' {
        $path = New-StartMenuShortcut -Name 'WhatIfApp' -Executable 'C:\Windows\notepad.exe' -WhatIf
        $path | Should -Not -Exist
    }
}
