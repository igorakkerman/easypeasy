BeforeAll {
    Import-Module "$PSScriptRoot/../easypeasy.psd1" -Force
}

Describe 'New-StartMenuProgramsFolder' {

    BeforeEach {
        Mock -ModuleName easypeasy Test-Elevated { $true }
        Mock -ModuleName easypeasy Invoke-Elevated { throw 'should not elevate' }
    }

    It 'creates the folder under Start Menu > Programs and returns its path' {
        Mock -ModuleName easypeasy New-Item { }

        $result = New-StartMenuProgramsFolder -Name 'EasypeasyTest'

        $result | Should -Match 'EasypeasyTest$'
        Should -Invoke -ModuleName easypeasy New-Item -Times 1 -Exactly `
            -ParameterFilter { $Path -like '*EasypeasyTest' }
    }

    It 'returns the path but creates nothing under -WhatIf' {
        Mock -ModuleName easypeasy New-Item { }

        $result = New-StartMenuProgramsFolder -Name 'EasypeasyTest' -WhatIf

        $result | Should -Match 'EasypeasyTest$'
        Should -Invoke -ModuleName easypeasy New-Item -Times 0 -Exactly
    }

    It 'creates the folder under the current user Programs path with -User' {
        Mock -ModuleName easypeasy New-Item { }
        $userPrograms = New-Object -ComObject WScript.Shell | ForEach-Object { $_.SpecialFolders("Programs") }

        $result = New-StartMenuProgramsFolder -Name 'EasypeasyTest' -User

        $result | Should -Be "$userPrograms\EasypeasyTest"
        Should -Invoke -ModuleName easypeasy New-Item -Times 1 -Exactly `
            -ParameterFilter { $Path -eq "$userPrograms\EasypeasyTest" }
    }

    It 'creates the folder under the all users Programs path with -AllUsers' {
        Mock -ModuleName easypeasy New-Item { }
        $allUsersPrograms = New-Object -ComObject WScript.Shell | ForEach-Object { $_.SpecialFolders("AllUsersPrograms") }

        $result = New-StartMenuProgramsFolder -Name 'EasypeasyTest' -AllUsers

        $result | Should -Be "$allUsersPrograms\EasypeasyTest"
        Should -Invoke -ModuleName easypeasy New-Item -Times 1 -Exactly `
            -ParameterFilter { $Path -eq "$allUsersPrograms\EasypeasyTest" }
    }

    It 'takes the folder name positionally' {
        Mock -ModuleName easypeasy New-Item { }

        $result = New-StartMenuProgramsFolder 'EasypeasyTest'

        $result | Should -Match 'EasypeasyTest$'
    }

    It 'creates the folder as a directory' {
        Mock -ModuleName easypeasy New-Item { }

        New-StartMenuProgramsFolder -Name 'EasypeasyTest' | Out-Null

        Should -Invoke -ModuleName easypeasy New-Item -Times 1 -Exactly `
            -ParameterFilter { $ItemType -eq 'Directory' }
    }

    Context 'when not elevated' {

        BeforeEach {
            Mock -ModuleName easypeasy Test-Elevated { $false }
            Mock -ModuleName easypeasy Invoke-Elevated { }
            Mock -ModuleName easypeasy New-Item { }
        }

        It 'creates the folder in an elevated session with -AllUsers, returning its path' {
            $allUsersPrograms = New-Object -ComObject WScript.Shell | ForEach-Object { $_.SpecialFolders("AllUsersPrograms") }

            $result = New-StartMenuProgramsFolder -Name 'EasypeasyTest' -AllUsers

            $result | Should -Be "$allUsersPrograms\EasypeasyTest"
            Should -Invoke -ModuleName easypeasy Invoke-Elevated -Times 1 -Exactly -ParameterFilter {
                $Command -contains 'New-StartMenuProgramsFolder' -and
                $Command -contains 'EasypeasyTest' -and
                $Command -contains '-AllUsers'
            }
            Should -Invoke -ModuleName easypeasy New-Item -Times 0 -Exactly
        }

        It 'does not elevate for the current user' {
            New-StartMenuProgramsFolder -Name 'EasypeasyTest' -User | Out-Null

            Should -Invoke -ModuleName easypeasy Invoke-Elevated -Times 0 -Exactly
            Should -Invoke -ModuleName easypeasy New-Item -Times 1 -Exactly
        }

        It 'does not elevate under -WhatIf' {
            New-StartMenuProgramsFolder -Name 'EasypeasyTest' -AllUsers -WhatIf | Out-Null

            Should -Invoke -ModuleName easypeasy Invoke-Elevated -Times 0 -Exactly
            Should -Invoke -ModuleName easypeasy New-Item -Times 0 -Exactly
        }
    }
}
