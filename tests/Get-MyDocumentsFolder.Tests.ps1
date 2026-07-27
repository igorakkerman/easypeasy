BeforeAll {
    Import-Module "$PSScriptRoot/../easypeasy.psd1" -Force
}

Describe 'Get-MyDocumentsFolder' {

    It 'returns an existing directory' {
        $location = Get-MyDocumentsFolder
        $location | Should -Not -BeNullOrEmpty
        Test-Path -LiteralPath $location -PathType Container | Should -BeTrue
    }

    It 'returns the MyDocuments special folder' {
        $myDocuments = New-Object -ComObject WScript.Shell | ForEach-Object { $_.SpecialFolders("MyDocuments") }

        Get-MyDocumentsFolder | Should -Be $myDocuments
    }
}
