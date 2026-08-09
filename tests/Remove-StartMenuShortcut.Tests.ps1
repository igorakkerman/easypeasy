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
            Mock -ModuleName easypeasy Test-Elevated { $true }
            Mock -ModuleName easypeasy Invoke-Elevated { throw 'should not elevate' }
        }

        It 'removes the .lnk from the current user Programs root by default' {
            Remove-StartMenuShortcut -Name 'Foo'

            Should -Invoke -ModuleName easypeasy Remove-Item -Times 1 -Exactly `
                -ParameterFilter { $LiteralPath -eq "$userPrograms\Foo.lnk" }
        }

        It 'takes the shortcut name positionally' {
            Remove-StartMenuShortcut 'Foo'

            Should -Invoke -ModuleName easypeasy Remove-Item -Times 1 -Exactly `
                -ParameterFilter { $LiteralPath -eq "$userPrograms\Foo.lnk" }
        }

        It 'uses -Folder for the containing folder when given' {
            Remove-StartMenuShortcut -Name 'Foo' -Folder 'Bar'

            Should -Invoke -ModuleName easypeasy Remove-Item -Times 1 -Exactly `
                -ParameterFilter { $LiteralPath -eq "$userPrograms\Bar\Foo.lnk" }
        }

        It 'targets the All Users Programs folder with -AllUsers' {
            Remove-StartMenuShortcut -Name 'Foo' -AllUsers

            Should -Invoke -ModuleName easypeasy Remove-Item -Times 1 -Exactly `
                -ParameterFilter { $LiteralPath -eq "$allUsers\Foo.lnk" }
        }

        It 'removes the containing folder when it is now empty' {
            Remove-StartMenuShortcut -Name 'Foo' -Folder 'Bar'

            Should -Invoke -ModuleName easypeasy Remove-Item -Times 1 -Exactly `
                -ParameterFilter { $LiteralPath -eq "$userPrograms\Bar" }
        }

        It 'keeps the containing folder when it still holds other items' {
            Mock -ModuleName easypeasy Get-ChildItem { 'C:\Old\Other.lnk' }

            Remove-StartMenuShortcut -Name 'Foo' -Folder 'Bar'

            Should -Invoke -ModuleName easypeasy Remove-Item -Times 0 -Exactly `
                -ParameterFilter { $LiteralPath -eq "$userPrograms\Bar" }
        }

        It 'never removes the Programs root when -Folder is omitted' {
            Remove-StartMenuShortcut -Name 'Foo'

            Should -Invoke -ModuleName easypeasy Remove-Item -Times 0 -Exactly `
                -ParameterFilter { $LiteralPath -eq $userPrograms }
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

        It 'reports the missing shortcut with its error id and location' {
            $errorRecord = { Remove-StartMenuShortcut -Name 'Foo' } | Should -Throw -PassThru

            $errorRecord.CategoryInfo.Category | Should -Be 'ObjectNotFound'
            $errorRecord.FullyQualifiedErrorId | Should -BeLike 'ShortcutNotFound,*'
            $errorRecord.TargetObject | Should -BeLike '*\Foo.lnk'
        }
    }

    Context 'when not elevated' {

        BeforeEach {
            Mock -ModuleName easypeasy Test-Path { $true }
            Mock -ModuleName easypeasy Remove-Item { }
            Mock -ModuleName easypeasy Get-ChildItem { }
            Mock -ModuleName easypeasy Test-Elevated { $false }
            Mock -ModuleName easypeasy Invoke-Elevated { }
        }

        It 'removes the shortcut in an elevated session with -AllUsers' {
            Remove-StartMenuShortcut -Name 'Foo' -AllUsers

            Should -Invoke -ModuleName easypeasy Invoke-Elevated -Times 1 -Exactly -ParameterFilter {
                $Command -contains 'Remove-StartMenuShortcut' -and
                $Command -contains 'Foo' -and
                $Command -contains '-AllUsers'
            }
            Should -Invoke -ModuleName easypeasy Remove-Item -Times 0 -Exactly
        }

        It 'passes -Folder on to the elevated session' {
            Remove-StartMenuShortcut -Name 'Foo' -Folder 'Bar' -AllUsers

            Should -Invoke -ModuleName easypeasy Invoke-Elevated -Times 1 -Exactly -ParameterFilter {
                $Command -contains '-Folder' -and $Command -contains 'Bar'
            }
        }

        It 'does not elevate for the current user' {
            Remove-StartMenuShortcut -Name 'Foo'

            Should -Invoke -ModuleName easypeasy Invoke-Elevated -Times 0 -Exactly
            Should -Invoke -ModuleName easypeasy Remove-Item -Times 1 -Exactly
        }

        It 'does not elevate under -WhatIf' {
            Remove-StartMenuShortcut -Name 'Foo' -AllUsers -WhatIf

            Should -Invoke -ModuleName easypeasy Invoke-Elevated -Times 0 -Exactly
            Should -Invoke -ModuleName easypeasy Remove-Item -Times 0 -Exactly
        }

        It 'reports a missing shortcut before elevating' {
            Mock -ModuleName easypeasy Test-Path { $false }

            { Remove-StartMenuShortcut -Name 'Foo' -AllUsers } | Should -Throw '*not found*'
            Should -Invoke -ModuleName easypeasy Invoke-Elevated -Times 0 -Exactly
        }
    }
}
