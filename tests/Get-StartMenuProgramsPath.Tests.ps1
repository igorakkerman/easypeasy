BeforeAll {
    Import-Module "$PSScriptRoot/../easypeasy.psd1" -Force
}

Describe 'Get-StartMenuProgramsPath' {

    It 'returns a non-empty path ending in Programs' {
        Get-StartMenuProgramsPath | Should -Match 'Programs$'
    }

    It 'returns an existing folder' {
        Get-StartMenuProgramsPath | Should -Exist
    }

    It 'returns the current user Programs folder under -User' {
        Get-StartMenuProgramsPath -User | Should -Match 'Programs$'
        Get-StartMenuProgramsPath -User | Should -Exist
    }

    It 'returns the current user Programs folder by default' {
        Get-StartMenuProgramsPath | Should -Be (Get-StartMenuProgramsPath -User)
    }

    It 'returns a different path for -AllUsers than for the user default' {
        Get-StartMenuProgramsPath -AllUsers | Should -Not -Be (Get-StartMenuProgramsPath)
    }
}
