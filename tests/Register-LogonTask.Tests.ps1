BeforeAll {
    Import-Module "$PSScriptRoot/../easypeasy.psd1" -Force
}

Describe 'Register-LogonTask' {

    # Only Register-ScheduledTask has a side effect; the New-ScheduledTask*
    # builders just construct in-memory objects, so let them run for real.
    BeforeEach {
        Mock -ModuleName easypeasy Register-ScheduledTask { }
    }

    It 'registers the task with the given name and path' {
        Register-LogonTask -Name 'MyTask' -Path '\MyFolder' -Executable 'C:\app.exe' -Argument 'x'

        Should -Invoke -ModuleName easypeasy Register-ScheduledTask -Times 1 -Exactly `
            -ParameterFilter { $TaskName -eq 'MyTask' -and $TaskPath -eq '\MyFolder' }
    }

    It 'registers in the Programs root task path by default' {
        Register-LogonTask -Name 'MyTask' -Executable 'C:\app.exe' -Argument 'x'

        Should -Invoke -ModuleName easypeasy Register-ScheduledTask -Times 1 -Exactly `
            -ParameterFilter { $TaskPath -eq '\' }
    }

    It 'runs the executable with its argument' {
        Register-LogonTask -Name 'MyTask' -Executable 'C:\app.exe' -Argument '/t'

        Should -Invoke -ModuleName easypeasy Register-ScheduledTask -Times 1 -Exactly -ParameterFilter {
            $InputObject.Actions[0].Execute -eq 'C:\app.exe' -and $InputObject.Actions[0].Arguments -eq '/t'
        }
    }

    It 'runs the executable without an argument when none is given' {
        Register-LogonTask -Name 'MyTask' -Executable 'C:\app.exe'

        Should -Invoke -ModuleName easypeasy Register-ScheduledTask -Times 1 -Exactly -ParameterFilter {
            $InputObject.Actions[0].Execute -eq 'C:\app.exe' -and -not $InputObject.Actions[0].Arguments
        }
    }

    It 'triggers the task at logon' {
        Register-LogonTask -Name 'MyTask' -Executable 'C:\app.exe' -Argument 'x'

        Should -Invoke -ModuleName easypeasy Register-ScheduledTask -Times 1 -Exactly -ParameterFilter {
            $InputObject.Triggers[0].CimClass.CimClassName -eq 'MSFT_TaskLogonTrigger'
        }
    }

    It 'starts the task when available, on batteries, without a time limit' {
        Register-LogonTask -Name 'MyTask' -Executable 'C:\app.exe' -Argument 'x'

        Should -Invoke -ModuleName easypeasy Register-ScheduledTask -Times 1 -Exactly -ParameterFilter {
            $InputObject.Settings.StartWhenAvailable -and
            -not $InputObject.Settings.DisallowStartIfOnBatteries -and
            -not $InputObject.Settings.StopIfGoingOnBatteries -and
            $InputObject.Settings.ExecutionTimeLimit -eq 'PT0S'
        }
    }

    It 'passes -Force through when overwriting' {
        Register-LogonTask -Name 'MyTask' -Executable 'C:\app.exe' -Argument 'x' -Force

        Should -Invoke -ModuleName easypeasy Register-ScheduledTask -Times 1 -Exactly `
            -ParameterFilter { $Force }
    }

    It 'does nothing under -WhatIf' {
        Register-LogonTask -Name 'MyTask' -Executable 'C:\app.exe' -Argument 'x' -WhatIf

        Should -Invoke -ModuleName easypeasy Register-ScheduledTask -Times 0 -Exactly
    }

    It 'requires -<parameter>' -ForEach @(
        @{ parameter = 'Name'; arguments = @{ Executable = 'C:\app.exe' } }
        @{ parameter = 'Executable'; arguments = @{ Name = 'MyTask' } }
    ) {
        { Register-LogonTask @arguments -ErrorAction Stop } | Should -Throw

        Should -Invoke -ModuleName easypeasy Register-ScheduledTask -Times 0 -Exactly
    }
}
