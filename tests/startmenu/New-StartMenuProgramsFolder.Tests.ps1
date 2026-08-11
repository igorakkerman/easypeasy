BeforeAll {
    Import-Module "$PSScriptRoot/../../easypeasy.psd1" -Force
    . "$PSScriptRoot/../ElevatedSession.ps1"
    Initialize-ElevatedSession
}

AfterAll { Remove-ElevatedSession }

Describe 'New-StartMenuProgramsFolder' {

    BeforeEach {
        Mock -ModuleName easypeasy Test-Elevated { $true }
        Mock -ModuleName easypeasy sudo { throw 'should not elevate' }
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
            $script:programs = Join-Path ([System.IO.Path]::GetTempPath()) "easypeasy-pf-$(New-Guid)"
            New-Item -ItemType Directory -Path $programs -Force | Out-Null
            Mock -ModuleName easypeasy Get-StartMenuProgramsLocation { $programs }

            Mock -ModuleName easypeasy Test-Elevated { $false }
            Mock -ModuleName easypeasy sudo -MockWith $sudoMock
            Mock -ModuleName easypeasy Get-SudoModeValue { 3 }
        }

        AfterEach { Remove-Item -LiteralPath $programs -Recurse -Force -ErrorAction SilentlyContinue }

        It 'creates the folder elevated for -AllUsers, returning its path' {
            $result = New-StartMenuProgramsFolder -Name 'EasypeasyTest' -AllUsers

            $result | Should -Be "$programs\EasypeasyTest"
            "$programs\EasypeasyTest" | Should -Exist
            Should -Invoke -ModuleName easypeasy sudo -Times 1 -Exactly
        }

        It 'does not elevate for the current user' {
            New-StartMenuProgramsFolder -Name 'EasypeasyTest' -User | Out-Null

            "$programs\EasypeasyTest" | Should -Exist
            Should -Invoke -ModuleName easypeasy sudo -Times 0 -Exactly
        }

        It 'creates nothing under -WhatIf' {
            New-StartMenuProgramsFolder -Name 'EasypeasyTest' -AllUsers -WhatIf | Out-Null

            "$programs\EasypeasyTest" | Should -Not -Exist
            Should -Invoke -ModuleName easypeasy sudo -Times 0 -Exactly
        }

        It 'fails for -AllUsers before anything is created when sudo is not available' {
            Mock -ModuleName easypeasy Get-SudoModeValue { 0 }

            { New-StartMenuProgramsFolder -Name 'EasypeasyTest' -AllUsers } | Should -Throw '*sudo*'

            "$programs\EasypeasyTest" | Should -Not -Exist
            Should -Invoke -ModuleName easypeasy sudo -Times 0 -Exactly
        }
    }
}
