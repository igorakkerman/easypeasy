BeforeAll {
    Import-Module "$PSScriptRoot/../easypeasy.psd1" -Force
}

Describe 'New-StartMenuProgramsFolder' {

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
}
