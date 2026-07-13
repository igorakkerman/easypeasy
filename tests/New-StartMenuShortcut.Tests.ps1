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

    It 'forwards -User to New-StartMenuProgramsFolder' {
        New-StartMenuShortcut -Name 'UserApp' -Executable 'C:\Windows\notepad.exe' -User | Out-Null

        Should -Invoke -ModuleName easypeasy New-StartMenuProgramsFolder -Times 1 -Exactly `
            -ParameterFilter { $User }
    }

    It 'does not target the user folder by default' {
        New-StartMenuShortcut -Name 'DefaultApp' -Executable 'C:\Windows\notepad.exe' | Out-Null

        Should -Invoke -ModuleName easypeasy New-StartMenuProgramsFolder -Times 1 -Exactly `
            -ParameterFilter { -not $User }
    }

    It 'fails when the shortcut already exists without -Force' {
        New-StartMenuShortcut -Name 'Dup' -Executable 'C:\Windows\notepad.exe' | Out-Null

        { New-StartMenuShortcut -Name 'Dup' -Executable 'C:\Windows\notepad.exe' } |
            Should -Throw '*already exists*'
    }

    It 'overwrites an existing shortcut with -Force' {
        New-StartMenuShortcut -Name 'Over' -Executable 'C:\Windows\notepad.exe' | Out-Null

        $path = New-StartMenuShortcut -Name 'Over' -Executable 'C:\Windows\regedit.exe' -Force
        $wsh.CreateShortcut($path).TargetPath | Should -Be 'C:\Windows\regedit.exe'
    }
}
