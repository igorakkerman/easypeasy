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
        Mock -ModuleName easypeasy Get-StartMenuProgramsLocation { $folder }
    }

    AfterAll { Remove-Item $folder -Recurse -Force -ErrorAction SilentlyContinue }

    It 'creates a pwsh shortcut that runs the command' {
        $location = New-PowershellStartMenuShortcut -Command 'Get-Date' -Name 'ShowDate'

        $location | Should -Exist
        $shortcut = $wsh.CreateShortcut($location)
        $shortcut.TargetPath | Should -Match 'pwsh'
        $shortcut.Arguments | Should -Match '-Command'
    }

    It 'keeps the window open with -KeepOpen (-NoExit)' {
        $location = New-PowershellStartMenuShortcut -Command 'Get-Date' -Name 'KeepOpen' -KeepOpen
        $wsh.CreateShortcut($location).Arguments | Should -Match '-NoExit'
    }

    It 'creates the shortcut in the given -Folder' {
        Mock -ModuleName easypeasy New-StartMenuProgramsFolder { $folder }

        New-PowershellStartMenuShortcut -Command 'Get-Date' -Name 'InFolder' -Folder 'MyFolder' | Out-Null

        Should -Invoke -ModuleName easypeasy New-StartMenuProgramsFolder -Times 1 -Exactly `
            -ParameterFilter { $Name -eq 'MyFolder' }
    }

    It 'forwards -AllUsers to Get-StartMenuProgramsLocation' {
        New-PowershellStartMenuShortcut -Command 'Get-Date' -Name 'AllUsersRoot' -AllUsers | Out-Null

        Should -Invoke -ModuleName easypeasy Get-StartMenuProgramsLocation -Times 1 -Exactly `
            -ParameterFilter { $AllUsers }
    }

    It 'forwards -AllUsers to New-StartMenuProgramsFolder' {
        Mock -ModuleName easypeasy New-StartMenuProgramsFolder { $folder }

        New-PowershellStartMenuShortcut -Command 'Get-Date' -Name 'AllUsersFolder' -Folder 'MyFolder' -AllUsers | Out-Null

        Should -Invoke -ModuleName easypeasy New-StartMenuProgramsFolder -Times 1 -Exactly `
            -ParameterFilter { $AllUsers }
    }

    It 'does not target the All Users folder by default' {
        New-PowershellStartMenuShortcut -Command 'Get-Date' -Name 'DefaultScope' | Out-Null

        Should -Invoke -ModuleName easypeasy Get-StartMenuProgramsLocation -Times 1 -Exactly `
            -ParameterFilter { -not $AllUsers }
    }

    It 'fails when the shortcut already exists without -Force' {
        New-PowershellStartMenuShortcut -Command 'Get-Date' -Name 'Dup' | Out-Null

        { New-PowershellStartMenuShortcut -Command 'Get-Date' -Name 'Dup' } |
            Should -Throw '*already exists*'
    }

    It 'overwrites an existing shortcut with -Force' {
        New-PowershellStartMenuShortcut -Command 'Get-Date' -Name 'Over' | Out-Null

        $location = New-PowershellStartMenuShortcut -Command 'Get-ChildItem' -Name 'Over' -Force
        $wsh.CreateShortcut($location).Arguments | Should -Match 'Get-ChildItem'
    }

    It 'uses icon index 0 by default' {
        $location = New-PowershellStartMenuShortcut -Command 'Get-Date' -Name 'IconDefault' `
            -IconLocation 'C:\Windows\explorer.exe'

        $wsh.CreateShortcut($location).IconLocation | Should -Be 'C:\Windows\explorer.exe,0'
    }

    It 'uses the given icon index' {
        $location = New-PowershellStartMenuShortcut -Command 'Get-Date' -Name 'IconIndexed' `
            -IconLocation 'C:\Windows\explorer.exe' -IconIndex 3

        $wsh.CreateShortcut($location).IconLocation | Should -Be 'C:\Windows\explorer.exe,3'
    }

    It 'accepts the icon file under the -IconFile alias' {
        $location = New-PowershellStartMenuShortcut -Command 'Get-Date' -Name 'IconFileAlias' `
            -IconFile 'C:\Windows\explorer.exe' -IconIndex 3

        $wsh.CreateShortcut($location).IconLocation | Should -Be 'C:\Windows\explorer.exe,3'
    }

    It 'takes the combined location from -Icon' {
        $location = New-PowershellStartMenuShortcut -Command 'Get-Date' -Name 'IconCombined' `
            -Icon 'C:\Windows\explorer.exe,3'

        $wsh.CreateShortcut($location).IconLocation | Should -Be 'C:\Windows\explorer.exe,3'
    }

    It 'fails when -Icon is combined with -IconLocation' {
        { New-PowershellStartMenuShortcut -Command 'Get-Date' -Name 'IconBoth' `
                -Icon 'C:\Windows\explorer.exe,3' -IconLocation 'C:\Windows\explorer.exe' } |
            Should -Throw '*cannot be combined*'
    }

    It 'fails when -Icon is combined with -IconIndex' {
        { New-PowershellStartMenuShortcut -Command 'Get-Date' -Name 'IconBothIndex' `
                -Icon 'C:\Windows\explorer.exe,3' -IconIndex 0 } |
            Should -Throw '*cannot be combined*'
    }
}
