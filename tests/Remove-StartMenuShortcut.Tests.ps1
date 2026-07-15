BeforeAll {
    Import-Module "$PSScriptRoot/../easypeasy.psd1" -Force
    $script:wsh = New-Object -ComObject WScript.Shell
    $script:allUsers = $wsh.SpecialFolders("AllUsersPrograms")
    $script:userPrograms = $wsh.SpecialFolders("Programs")
}

Describe 'Remove-StartMenuShortcut' {

    Context 'the shortcut exists' {

        BeforeEach {
            Mock -ModuleName easypeasy Test-Path { $true }
            Mock -ModuleName easypeasy Remove-Item { }
            Mock -ModuleName easypeasy Get-ChildItem { }   # folder empty after removal
        }

        It 'removes the .lnk under the current user Programs folder by default' {
            Remove-StartMenuShortcut -Name 'Foo'

            Should -Invoke -ModuleName easypeasy Remove-Item -Times 1 -Exactly `
                -ParameterFilter { $LiteralPath -eq "$userPrograms\Foo\Foo.lnk" }
        }

        It 'uses -Folder for the containing folder when given' {
            Remove-StartMenuShortcut -Name 'Foo' -Folder 'Bar'

            Should -Invoke -ModuleName easypeasy Remove-Item -Times 1 -Exactly `
                -ParameterFilter { $LiteralPath -eq "$userPrograms\Bar\Foo.lnk" }
        }

        It 'targets the All Users Programs folder with -AllUsers' {
            Remove-StartMenuShortcut -Name 'Foo' -AllUsers

            Should -Invoke -ModuleName easypeasy Remove-Item -Times 1 -Exactly `
                -ParameterFilter { $LiteralPath -eq "$allUsers\Foo\Foo.lnk" }
        }

        It 'removes the containing folder when it is now empty' {
            Remove-StartMenuShortcut -Name 'Foo'

            Should -Invoke -ModuleName easypeasy Remove-Item -Times 1 -Exactly `
                -ParameterFilter { $LiteralPath -eq "$userPrograms\Foo" }
        }

        It 'keeps the containing folder when it still holds other items' {
            Mock -ModuleName easypeasy Get-ChildItem { 'C:\Old\Other.lnk' }

            Remove-StartMenuShortcut -Name 'Foo'

            Should -Invoke -ModuleName easypeasy Remove-Item -Times 0 -Exactly `
                -ParameterFilter { $LiteralPath -eq "$userPrograms\Foo" }
        }

        It 'removes nothing under -WhatIf' {
            Remove-StartMenuShortcut -Name 'Foo' -WhatIf

            Should -Invoke -ModuleName easypeasy Remove-Item -Times 0 -Exactly
        }
    }

    Context 'the shortcut is absent' {

        BeforeEach {
            Mock -ModuleName easypeasy Test-Path { $false }
            Mock -ModuleName easypeasy Remove-Item { }
        }

        It 'throws and removes nothing' {
            { Remove-StartMenuShortcut -Name 'Foo' } | Should -Throw '*not found*'
            Should -Invoke -ModuleName easypeasy Remove-Item -Times 0 -Exactly
        }
    }
}
