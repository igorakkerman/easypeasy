BeforeAll {
    Import-Module "$PSScriptRoot/../easypeasy.psd1" -Force
}

Describe 'Get-StartMenuProgramsLocation' {

    It 'returns a non-empty path ending in Programs' {
        Get-StartMenuProgramsLocation | Should -Match 'Programs$'
    }

    It 'returns an existing folder' {
        Get-StartMenuProgramsLocation | Should -Exist
    }

    It 'returns the current user Programs folder under -User' {
        Get-StartMenuProgramsLocation -User | Should -Match 'Programs$'
        Get-StartMenuProgramsLocation -User | Should -Exist
    }

    It 'returns the current user Programs folder by default' {
        Get-StartMenuProgramsLocation | Should -Be (Get-StartMenuProgramsLocation -User)
    }

    It 'returns a different path for -AllUsers than for the user default' {
        Get-StartMenuProgramsLocation -AllUsers | Should -Not -Be (Get-StartMenuProgramsLocation)
    }
}
