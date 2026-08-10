BeforeAll {
    Import-Module "$PSScriptRoot/../../easypeasy.psd1" -Force
}

Describe 'Assert-SudoAvailable' {

    BeforeEach {
        # sudo present, feature enabled inline, no policy - unless a test says otherwise
        Mock -ModuleName easypeasy Get-Command { [pscustomobject] @{ Name = 'sudo' } } -ParameterFilter { $Name -eq 'sudo' }
        Mock -ModuleName easypeasy Get-SudoModeValue { }
        Mock -ModuleName easypeasy Get-SudoModeValue { 3 } -ParameterFilter { $Key -notlike '*Policies*' }
    }

    It 'passes when sudo is present and enabled' {
        { InModuleScope easypeasy { Assert-SudoAvailable } } | Should -Not -Throw
    }

    It 'reports a terminating error when sudo is not on the system' {
        Mock -ModuleName easypeasy Get-Command { } -ParameterFilter { $Name -eq 'sudo' }

        $errorRecord = { InModuleScope easypeasy { Assert-SudoAvailable } } |
            Should -Throw '*sudo not found*' -PassThru

        $errorRecord.CategoryInfo.Category | Should -Be 'NotInstalled'
        $errorRecord.FullyQualifiedErrorId | Should -BeLike 'SudoNotAvailable,*'
        $errorRecord.TargetObject | Should -Be 'sudo'
    }

    It 'reports a terminating error when the sudo feature is switched off' {
        Mock -ModuleName easypeasy Get-SudoModeValue { 0 } -ParameterFilter { $Key -notlike '*Policies*' }

        $errorRecord = { InModuleScope easypeasy { Assert-SudoAvailable } } |
            Should -Throw '*sudo disabled*' -PassThru

        $errorRecord.CategoryInfo.Category | Should -Be 'NotEnabled'
        $errorRecord.FullyQualifiedErrorId | Should -BeLike 'SudoDisabled,*'
        $errorRecord.TargetObject | Should -Be 'sudo'
    }

    It 'takes an unset feature toggle for switched off, as sudo does' {
        Mock -ModuleName easypeasy Get-SudoModeValue { } -ParameterFilter { $Key -notlike '*Policies*' }

        { InModuleScope easypeasy { Assert-SudoAvailable } } |
            Should -Throw '*sudo disabled*'
    }

    It 'reports a terminating error when group policy disables sudo' {
        Mock -ModuleName easypeasy Get-SudoModeValue { 0 } -ParameterFilter { $Key -like '*Policies*' }

        $errorRecord = { InModuleScope easypeasy { Assert-SudoAvailable } } |
            Should -Throw '*sudo disabled*' -PassThru

        $errorRecord.FullyQualifiedErrorId | Should -BeLike 'SudoDisabled,*'
    }

    It 'passes when group policy allows sudo' {
        Mock -ModuleName easypeasy Get-SudoModeValue { 3 } -ParameterFilter { $Key -like '*Policies*' }

        { InModuleScope easypeasy { Assert-SudoAvailable } } | Should -Not -Throw
    }

    It 'reports a terminating error when the feature is capped below inline mode. mode: <mode>' -ForEach @(
        @{ mode = 1 }   # new window
        @{ mode = 2 }   # input closed
    ) {
        $script:sudoMode = $mode
        Mock -ModuleName easypeasy Get-SudoModeValue { $script:sudoMode } -ParameterFilter { $Key -notlike '*Policies*' }

        $errorRecord = { InModuleScope easypeasy { Assert-SudoAvailable } } |
            Should -Throw '*sudo inline mode forbidden*' -PassThru

        $errorRecord.CategoryInfo.Category | Should -Be 'NotEnabled'
        $errorRecord.FullyQualifiedErrorId | Should -BeLike 'SudoInlineNotAllowed,*'
        $errorRecord.TargetObject | Should -Be 'sudo'
    }

    It 'reports a terminating error when group policy caps the mode below inline' {
        Mock -ModuleName easypeasy Get-SudoModeValue { 2 } -ParameterFilter { $Key -like '*Policies*' }

        $errorRecord = { InModuleScope easypeasy { Assert-SudoAvailable } } |
            Should -Throw '*sudo inline mode forbidden*' -PassThru

        $errorRecord.FullyQualifiedErrorId | Should -BeLike 'SudoInlineNotAllowed,*'
    }

    It 'takes a mode above inline for inline, as sudo does' {
        Mock -ModuleName easypeasy Get-SudoModeValue { 4 } -ParameterFilter { $Key -notlike '*Policies*' }

        { InModuleScope easypeasy { Assert-SudoAvailable } } | Should -Not -Throw
    }
}
