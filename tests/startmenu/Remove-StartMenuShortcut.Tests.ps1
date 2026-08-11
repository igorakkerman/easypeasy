BeforeAll {
    Import-Module "$PSScriptRoot/../../easypeasy.psd1" -Force
    . "$PSScriptRoot/../ElevatedSession.ps1"
    Initialize-ElevatedSession
    $script:wsh = New-Object -ComObject WScript.Shell
    $script:allUsers = $wsh.SpecialFolders("AllUsersPrograms")
    $script:userPrograms = $wsh.SpecialFolders("Programs")
}

AfterAll { Remove-ElevatedSession }

Describe 'Remove-StartMenuShortcut' {

    Context 'the shortcut exists' {

        BeforeEach {
            Mock -ModuleName easypeasy Test-Path { $true }
            Mock -ModuleName easypeasy Remove-Item { }
            Mock -ModuleName easypeasy Get-ChildItem { }   # folder empty after removal
            Mock -ModuleName easypeasy Test-Elevated { $true }
            Mock -ModuleName easypeasy sudo { throw 'should not elevate' }
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
            $script:programs = Join-Path ([System.IO.Path]::GetTempPath()) "easypeasy-rm-$(New-Guid)"
            New-Item -ItemType Directory -Path "$programs\Bar" -Force | Out-Null
            New-Item -ItemType File -Path "$programs\Foo.lnk" -Force | Out-Null
            New-Item -ItemType File -Path "$programs\Bar\Foo.lnk" -Force | Out-Null
            Mock -ModuleName easypeasy Get-StartMenuProgramsLocation { $programs }

            Mock -ModuleName easypeasy Test-Elevated { $false }
            Mock -ModuleName easypeasy sudo -MockWith $sudoMock
            Mock -ModuleName easypeasy Get-SudoModeValue { 3 }
        }

        AfterEach { Remove-Item -LiteralPath $programs -Recurse -Force -ErrorAction SilentlyContinue }

        It 'removes the shortcut elevated for -AllUsers' {
            Remove-StartMenuShortcut -Name 'Foo' -AllUsers

            "$programs\Foo.lnk" | Should -Not -Exist
            Should -Invoke -ModuleName easypeasy sudo -Times 1 -Exactly
        }

        It 'removes the containing -Folder that the shortcut leaves empty' {
            Remove-StartMenuShortcut -Name 'Foo' -Folder 'Bar' -AllUsers

            "$programs\Bar" | Should -Not -Exist
        }

        It 'keeps a -Folder that still holds other items' {
            New-Item -ItemType File -Path "$programs\Bar\Other.lnk" -Force | Out-Null

            Remove-StartMenuShortcut -Name 'Foo' -Folder 'Bar' -AllUsers

            "$programs\Bar\Foo.lnk"   | Should -Not -Exist
            "$programs\Bar\Other.lnk" | Should -Exist
        }

        It 'never removes the Programs root' {
            Remove-StartMenuShortcut -Name 'Foo' -AllUsers

            $programs | Should -Exist
        }

        It 'does not elevate for the current user' {
            Remove-StartMenuShortcut -Name 'Foo'

            "$programs\Foo.lnk" | Should -Not -Exist
            Should -Invoke -ModuleName easypeasy sudo -Times 0 -Exactly
        }

        It 'removes nothing and does not elevate under -WhatIf' {
            Remove-StartMenuShortcut -Name 'Foo' -AllUsers -WhatIf

            "$programs\Foo.lnk" | Should -Exist
            Should -Invoke -ModuleName easypeasy sudo -Times 0 -Exactly
        }

        It 'reports a missing shortcut before elevating' {
            { Remove-StartMenuShortcut -Name 'Absent' -AllUsers } | Should -Throw '*not found*'

            Should -Invoke -ModuleName easypeasy sudo -Times 0 -Exactly
        }

        It 'fails for -AllUsers before anything is removed when sudo is not available' {
            Mock -ModuleName easypeasy Get-SudoModeValue { 0 }

            { Remove-StartMenuShortcut -Name 'Foo' -AllUsers } | Should -Throw '*sudo*'

            "$programs\Foo.lnk" | Should -Exist
            Should -Invoke -ModuleName easypeasy sudo -Times 0 -Exactly
        }
    }
}
