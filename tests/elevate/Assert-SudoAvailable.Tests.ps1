BeforeAll {
    Import-Module "$PSScriptRoot/../../easypeasy.psd1" -Force
}

Describe 'Assert-SudoAvailable' {

    BeforeEach {
        # sudo present, feature enabled inline, no policy - unless a test says otherwise
        Mock -ModuleName easypeasy Get-Command { [pscustomobject] @{ Name = 'sudo' } } -ParameterFilter { $Name -eq 'sudo' }
        # SudoMode lives in the module, so every mode mock is registered from inside it
        InModuleScope easypeasy {
            Mock Get-SudoModeValue { }
            Mock Get-SudoModeValue { [SudoMode]::Inline } -ParameterFilter { $Key -notlike '*Policies*' }
        }
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
        InModuleScope easypeasy {
            Mock Get-SudoModeValue { [SudoMode]::Disabled } -ParameterFilter { $Key -notlike '*Policies*' }
        }

        $errorRecord = { InModuleScope easypeasy { Assert-SudoAvailable } } |
            Should -Throw '*sudo disabled*' -PassThru

        $errorRecord.CategoryInfo.Category | Should -Be 'NotEnabled'
        $errorRecord.FullyQualifiedErrorId | Should -BeLike 'SudoDisabled,*'
        $errorRecord.TargetObject | Should -Be 'sudo'
    }

    It 'takes an unset feature toggle for switched off, as sudo does' {
        InModuleScope easypeasy {
            Mock Get-SudoModeValue { } -ParameterFilter { $Key -notlike '*Policies*' }
        }

        { InModuleScope easypeasy { Assert-SudoAvailable } } |
            Should -Throw '*sudo disabled*'
    }

    It 'reports a terminating error when group policy disables sudo' {
        InModuleScope easypeasy {
            Mock Get-SudoModeValue { [SudoMode]::Disabled } -ParameterFilter { $Key -like '*Policies*' }
        }

        $errorRecord = { InModuleScope easypeasy { Assert-SudoAvailable } } |
            Should -Throw '*sudo disabled*' -PassThru

        $errorRecord.FullyQualifiedErrorId | Should -BeLike 'SudoDisabled,*'
    }

    It 'passes when group policy allows sudo' {
        InModuleScope easypeasy {
            Mock Get-SudoModeValue { [SudoMode]::Inline } -ParameterFilter { $Key -like '*Policies*' }
        }

        { InModuleScope easypeasy { Assert-SudoAvailable } } | Should -Not -Throw
    }

    It 'reports a terminating error when the feature is capped to a new window' {
        InModuleScope easypeasy {
            Mock Get-SudoModeValue { [SudoMode]::NewWindow } -ParameterFilter { $Key -notlike '*Policies*' }
        }

        $errorRecord = { InModuleScope easypeasy { Assert-SudoAvailable } } |
            Should -Throw '*sudo inline mode forbidden*' -PassThru

        $errorRecord.CategoryInfo.Category | Should -Be 'NotEnabled'
        $errorRecord.FullyQualifiedErrorId | Should -BeLike 'SudoInlineNotAllowed,*'
        $errorRecord.TargetObject | Should -Be 'sudo'
    }

    It 'reports a terminating error when the feature is capped to input closed' {
        InModuleScope easypeasy {
            Mock Get-SudoModeValue { [SudoMode]::InputClosed } -ParameterFilter { $Key -notlike '*Policies*' }
        }

        { InModuleScope easypeasy { Assert-SudoAvailable } } |
            Should -Throw '*sudo inline mode forbidden*'
    }

    It 'reports a terminating error when the feature holds a value above the modes' {
        InModuleScope easypeasy {
            Mock Get-SudoModeValue { 4 } -ParameterFilter { $Key -notlike '*Policies*' }
        }

        $errorRecord = { InModuleScope easypeasy { Assert-SudoAvailable } } |
            Should -Throw '*not recognized*' -PassThru

        $errorRecord.CategoryInfo.Category | Should -Be 'InvalidData'
        $errorRecord.FullyQualifiedErrorId | Should -BeLike 'SudoModeInvalid,*'
    }

    It 'reports a terminating error when group policy holds a negative value' {
        InModuleScope easypeasy {
            Mock Get-SudoModeValue { -1 } -ParameterFilter { $Key -like '*Policies*' }
        }

        { InModuleScope easypeasy { Assert-SudoAvailable } } | Should -Throw '*not recognized*'
    }

    It 'reports a terminating error when the feature holds a value naming no mode' {
        InModuleScope easypeasy {
            Mock Get-SudoModeValue { 'not a mode' } -ParameterFilter { $Key -notlike '*Policies*' }
        }

        { InModuleScope easypeasy { Assert-SudoAvailable } } | Should -Throw '*not recognized*'
    }

    It 'reports a terminating error when group policy caps the mode below inline' {
        InModuleScope easypeasy {
            Mock Get-SudoModeValue { [SudoMode]::InputClosed } -ParameterFilter { $Key -like '*Policies*' }
        }

        $errorRecord = { InModuleScope easypeasy { Assert-SudoAvailable } } |
            Should -Throw '*sudo inline mode forbidden*' -PassThru

        $errorRecord.FullyQualifiedErrorId | Should -BeLike 'SudoInlineNotAllowed,*'
    }
}
