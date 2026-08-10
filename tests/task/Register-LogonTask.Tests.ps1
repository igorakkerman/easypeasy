BeforeAll {
    Import-Module "$PSScriptRoot/../../easypeasy.psd1" -Force
}

Describe 'Register-LogonTask' {

    # Only Register-ScheduledTask has a side effect; the New-ScheduledTask*
    # builders just construct in-memory objects, so let them run for real.
    BeforeEach {
        Mock -ModuleName easypeasy Register-ScheduledTask { }
        Mock -ModuleName easypeasy Test-Elevated { $true }
        Mock -ModuleName easypeasy Invoke-Elevated { throw 'should not elevate' }
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

    It 'runs the task at the highest privileges with -Elevated' {
        Register-LogonTask -Name 'MyTask' -Executable 'C:\app.exe' -Elevated

        Should -Invoke -ModuleName easypeasy Register-ScheduledTask -Times 1 -Exactly -ParameterFilter {
            $InputObject.Principal.RunLevel -eq 'Highest' -and
            $InputObject.Principal.LogonType -eq 'Interactive'
        }
    }

    It 'runs the task at the logon privileges by default' {
        Register-LogonTask -Name 'MyTask' -Executable 'C:\app.exe'

        Should -Invoke -ModuleName easypeasy Register-ScheduledTask -Times 1 -Exactly `
            -ParameterFilter { $InputObject.Principal.RunLevel -ne 'Highest' }
    }

    It 'takes -Administrator for -Elevated' {
        Register-LogonTask -Name 'MyTask' -Executable 'C:\app.exe' -Administrator

        Should -Invoke -ModuleName easypeasy Register-ScheduledTask -Times 1 -Exactly `
            -ParameterFilter { $InputObject.Principal.RunLevel -eq 'Highest' }
    }

    Context 'when not elevated' {

        BeforeEach {
            Mock -ModuleName easypeasy Test-Elevated { $false }
            Mock -ModuleName easypeasy Invoke-Elevated { }
            Mock -ModuleName easypeasy Assert-SudoAvailable { }
        }

        It 'hands the task to the task scheduler in an elevated session' {
            Register-LogonTask -Name 'MyTask' -Path '\MyFolder' -Executable 'C:\app.exe' -Elevated -Force

            Should -Invoke -ModuleName easypeasy Invoke-Elevated -Times 1 -Exactly -ParameterFilter {
                $Command -contains 'Register-ScheduledTask' -and
                $Command -contains '-TaskName' -and
                $Command -contains 'MyTask' -and
                $Command -contains '-TaskPath' -and
                $Command -contains '\MyFolder' -and
                $Command -contains '-Xml' -and
                $Command -contains '-Force'
            }
            Should -Invoke -ModuleName easypeasy Register-ScheduledTask -Times 0 -Exactly
        }

        It 'hands over the task as XML, at the highest run level' {
            Register-LogonTask -Name 'MyTask' -Executable 'C:\app.exe' -Argument '/t' -Elevated

            Should -Invoke -ModuleName easypeasy Invoke-Elevated -Times 1 -Exactly -ParameterFilter {
                $xml = $Command[$Command.IndexOf('-Xml') + 1]
                $xml -like '*<RunLevel>HighestAvailable</RunLevel>*' -and
                $xml -like '*<Command>C:\app.exe</Command>*' -and
                $xml -like '*<Arguments>/t</Arguments>*'
            }
        }

        It 'writes nothing through from the elevated session' {
            Mock -ModuleName easypeasy Invoke-Elevated { "task the elevated session registered" }

            Register-LogonTask -Name 'MyTask' -Executable 'C:\app.exe' -Elevated | Should -BeNullOrEmpty
        }

        It 'does not re-run itself elevated' {
            Register-LogonTask -Name 'MyTask' -Executable 'C:\app.exe' -Elevated

            Should -Invoke -ModuleName easypeasy Invoke-Elevated -Times 1 -Exactly `
                -ParameterFilter { $Command -notcontains 'Register-LogonTask' }
        }

        It 'registers a task of the current user without elevating' {
            Register-LogonTask -Name 'MyTask' -Executable 'C:\app.exe'

            Should -Invoke -ModuleName easypeasy Invoke-Elevated -Times 0 -Exactly
            Should -Invoke -ModuleName easypeasy Register-ScheduledTask -Times 1 -Exactly
        }

        It 'does not elevate under -WhatIf' {
            Register-LogonTask -Name 'MyTask' -Executable 'C:\app.exe' -Elevated -WhatIf

            Should -Invoke -ModuleName easypeasy Invoke-Elevated -Times 0 -Exactly
            Should -Invoke -ModuleName easypeasy Register-ScheduledTask -Times 0 -Exactly
        }

        It 'fails an -Elevated registration before anything is registered when sudo is not available' {
            Mock -ModuleName easypeasy Assert-SudoAvailable { throw 'sudo not available' }

            { Register-LogonTask -Name 'NoSudo' -Executable 'C:\app.exe' -Elevated } | Should -Throw '*sudo*'

            Should -Invoke -ModuleName easypeasy Invoke-Elevated -Times 0 -Exactly
            Should -Invoke -ModuleName easypeasy Register-ScheduledTask -Times 0 -Exactly
        }
    }

    It 'does not elevate when already elevated' {
        Register-LogonTask -Name 'MyTask' -Executable 'C:\app.exe' -Elevated

        Should -Invoke -ModuleName easypeasy Invoke-Elevated -Times 0 -Exactly
    }

    It 'requires -<parameter>' -ForEach @(
        @{ parameter = 'Name'; arguments = @{ Executable = 'C:\app.exe' } }
        @{ parameter = 'Executable'; arguments = @{ Name = 'MyTask' } }
    ) {
        { Register-LogonTask @arguments -ErrorAction Stop } | Should -Throw

        Should -Invoke -ModuleName easypeasy Register-ScheduledTask -Times 0 -Exactly
    }
}
