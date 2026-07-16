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

    It 'passes -Force through when overwriting' {
        Register-LogonTask -Name 'MyTask' -Executable 'C:\app.exe' -Argument 'x' -Force

        Should -Invoke -ModuleName easypeasy Register-ScheduledTask -Times 1 -Exactly `
            -ParameterFilter { $Force }
    }

    It 'does nothing under -WhatIf' {
        Register-LogonTask -Name 'MyTask' -Executable 'C:\app.exe' -Argument 'x' -WhatIf

        Should -Invoke -ModuleName easypeasy Register-ScheduledTask -Times 0 -Exactly
    }
}
