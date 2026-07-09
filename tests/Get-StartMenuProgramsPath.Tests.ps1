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
}
