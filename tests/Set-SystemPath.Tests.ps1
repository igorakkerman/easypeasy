BeforeAll {
    Import-Module "$PSScriptRoot/../easypeasy.psd1" -Force
    . "$PSScriptRoot/PathEntries.ps1"
}

Describe 'Set-SystemPath' {

    BeforeEach {
        Mock -ModuleName easypeasy Backup-SystemPath { }
        Mock -ModuleName easypeasy Set-EnvironmentVariable { }
    }

    Context 'persisting entries' {

        It 'writes the Path as an expandable (REG_EXPAND_SZ) value' {
            $entries = New-PathEntries 'C:\A;C:\B'

            InModuleScope easypeasy -Parameters @{ e = $entries } { Set-SystemPath -Entries $e -User }

            Should -Invoke -ModuleName easypeasy Set-EnvironmentVariable -Times 1 -Exactly `
                -ParameterFilter { $Name -eq 'Path' -and $Expandable }
        }

        It 'persists the stored form, keeping a %...% reference unexpanded' {
            $entries = @(New-PathEntry -ExpandableLocation '%SystemRoot%\S32' -Location 'C:\WINDOWS\S32') +
                @(New-PathEntries 'C:\Keep')

            InModuleScope easypeasy -Parameters @{ e = $entries } { Set-SystemPath -Entries $e -User }

            Should -Invoke -ModuleName easypeasy Set-EnvironmentVariable -Times 1 -Exactly `
                -ParameterFilter { $Value -eq '%SystemRoot%\S32;C:\Keep' }
        }

        It 'backs up the Path before writing' {
            $entries = New-PathEntries 'C:\A'

            InModuleScope easypeasy -Parameters @{ e = $entries } { Set-SystemPath -Entries $e -User }

            Should -Invoke -ModuleName easypeasy Backup-SystemPath -Times 1 -Exactly
        }

        It 'targets the machine scope with -Machine' {
            $entries = New-PathEntries 'C:\A' -Scope Machine

            InModuleScope easypeasy -Parameters @{ e = $entries } { Set-SystemPath -Entries $e -Machine }

            Should -Invoke -ModuleName easypeasy Set-EnvironmentVariable -Times 1 -Exactly `
                -ParameterFilter { $Machine -and -not $User }
        }

        It 'targets the user scope with -User' {
            $entries = New-PathEntries 'C:\A'

            InModuleScope easypeasy -Parameters @{ e = $entries } { Set-SystemPath -Entries $e -User }

            Should -Invoke -ModuleName easypeasy Set-EnvironmentVariable -Times 1 -Exactly `
                -ParameterFilter { $User -and -not $Machine }
        }
    }
}
