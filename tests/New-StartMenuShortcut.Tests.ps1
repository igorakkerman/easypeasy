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
        Mock -ModuleName easypeasy Get-StartMenuProgramsPath { $folder }
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

    It 'creates the shortcut in the given -Folder' {
        New-StartMenuShortcut -Name 'InFolder' -Executable 'C:\Windows\notepad.exe' -Folder 'MyFolder' | Out-Null

        Should -Invoke -ModuleName easypeasy New-StartMenuProgramsFolder -Times 1 -Exactly `
            -ParameterFilter { $Name -eq 'MyFolder' }
    }

    It 'creates the shortcut in the Programs root when -Folder is omitted' {
        New-StartMenuShortcut -Name 'InRoot' -Executable 'C:\Windows\notepad.exe' | Out-Null

        Should -Invoke -ModuleName easypeasy Get-StartMenuProgramsPath -Times 1 -Exactly
        Should -Invoke -ModuleName easypeasy New-StartMenuProgramsFolder -Times 0 -Exactly
    }

    It 'forwards -AllUsers to New-StartMenuProgramsFolder' {
        New-StartMenuShortcut -Name 'AllUsersApp' -Executable 'C:\Windows\notepad.exe' -Folder 'MyFolder' -AllUsers | Out-Null

        Should -Invoke -ModuleName easypeasy New-StartMenuProgramsFolder -Times 1 -Exactly `
            -ParameterFilter { $AllUsers }
    }

    It 'forwards -AllUsers to Get-StartMenuProgramsPath when -Folder is omitted' {
        New-StartMenuShortcut -Name 'AllUsersRoot' -Executable 'C:\Windows\notepad.exe' -AllUsers | Out-Null

        Should -Invoke -ModuleName easypeasy Get-StartMenuProgramsPath -Times 1 -Exactly `
            -ParameterFilter { $AllUsers }
    }

    It 'does not target the All Users folder by default' {
        New-StartMenuShortcut -Name 'DefaultApp' -Executable 'C:\Windows\notepad.exe' | Out-Null

        Should -Invoke -ModuleName easypeasy Get-StartMenuProgramsPath -Times 1 -Exactly `
            -ParameterFilter { -not $AllUsers }
    }

    It 'requires -Name' {
        { New-StartMenuShortcut -Executable 'C:\Windows\notepad.exe' -ErrorAction Stop } | Should -Throw
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

    It 'uses icon index 0 by default' {
        $path = New-StartMenuShortcut -Name 'IconDefault' -Executable 'C:\Windows\notepad.exe' `
            -IconLocation 'C:\Windows\explorer.exe'

        $wsh.CreateShortcut($path).IconLocation | Should -Be 'C:\Windows\explorer.exe,0'
    }

    It 'uses the given icon index' {
        $path = New-StartMenuShortcut -Name 'IconIndexed' -Executable 'C:\Windows\notepad.exe' `
            -IconLocation 'C:\Windows\explorer.exe' -IconIndex 3

        $wsh.CreateShortcut($path).IconLocation | Should -Be 'C:\Windows\explorer.exe,3'
    }

    It 'accepts the icon file under the -IconFile alias' {
        $path = New-StartMenuShortcut -Name 'IconFileAlias' -Executable 'C:\Windows\notepad.exe' `
            -IconFile 'C:\Windows\explorer.exe' -IconIndex 3

        $wsh.CreateShortcut($path).IconLocation | Should -Be 'C:\Windows\explorer.exe,3'
    }

    It 'takes the combined location from -Icon' {
        $path = New-StartMenuShortcut -Name 'IconCombined' -Executable 'C:\Windows\notepad.exe' `
            -Icon 'C:\Windows\explorer.exe,3'

        $wsh.CreateShortcut($path).IconLocation | Should -Be 'C:\Windows\explorer.exe,3'
    }

    It 'fails when -Icon is combined with -IconLocation' {
        { New-StartMenuShortcut -Name 'IconBoth' -Executable 'C:\Windows\notepad.exe' `
                -Icon 'C:\Windows\explorer.exe,3' -IconLocation 'C:\Windows\explorer.exe' } |
            Should -Throw '*cannot be combined*'
    }

    It 'fails when -Icon is combined with -IconIndex' {
        { New-StartMenuShortcut -Name 'IconBothIndex' -Executable 'C:\Windows\notepad.exe' `
                -Icon 'C:\Windows\explorer.exe,3' -IconIndex 0 } |
            Should -Throw '*cannot be combined*'
    }
}
