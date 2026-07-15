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

    It 'creates the shortcut in the given -Folder' {
        Mock -ModuleName easypeasy New-StartMenuProgramsFolder { $folder }

        New-PowershellStartMenuShortcut -Command 'Get-Date' -Name 'InFolder' -Folder 'MyGroup' | Out-Null

        Should -Invoke -ModuleName easypeasy New-StartMenuProgramsFolder -Times 1 -Exactly `
            -ParameterFilter { $Name -eq 'MyGroup' }
    }

    It 'fails when the shortcut already exists without -Force' {
        New-PowershellStartMenuShortcut -Command 'Get-Date' -Name 'Dup' | Out-Null

        { New-PowershellStartMenuShortcut -Command 'Get-Date' -Name 'Dup' } |
            Should -Throw '*already exists*'
    }

    It 'overwrites an existing shortcut with -Force' {
        New-PowershellStartMenuShortcut -Command 'Get-Date' -Name 'Over' | Out-Null

        $path = New-PowershellStartMenuShortcut -Command 'Get-ChildItem' -Name 'Over' -Force
        $wsh.CreateShortcut($path).Arguments | Should -Match 'Get-ChildItem'
    }

    It 'uses icon index 0 by default' {
        $path = New-PowershellStartMenuShortcut -Command 'Get-Date' -Name 'IconDefault' `
            -IconLocation 'C:\Windows\explorer.exe'

        $wsh.CreateShortcut($path).IconLocation | Should -Be 'C:\Windows\explorer.exe,0'
    }

    It 'uses the given icon index' {
        $path = New-PowershellStartMenuShortcut -Command 'Get-Date' -Name 'IconIndexed' `
            -IconLocation 'C:\Windows\explorer.exe' -IconIndex 3

        $wsh.CreateShortcut($path).IconLocation | Should -Be 'C:\Windows\explorer.exe,3'
    }

    It 'accepts the icon file under the -IconFile alias' {
        $path = New-PowershellStartMenuShortcut -Command 'Get-Date' -Name 'IconFileAlias' `
            -IconFile 'C:\Windows\explorer.exe' -IconIndex 3

        $wsh.CreateShortcut($path).IconLocation | Should -Be 'C:\Windows\explorer.exe,3'
    }

    It 'takes the combined location from -Icon' {
        $path = New-PowershellStartMenuShortcut -Command 'Get-Date' -Name 'IconCombined' `
            -Icon 'C:\Windows\explorer.exe,3'

        $wsh.CreateShortcut($path).IconLocation | Should -Be 'C:\Windows\explorer.exe,3'
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
