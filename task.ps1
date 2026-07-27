function Register-LogonTask {
    <#
    .SYNOPSIS
        Registers a task to run at user logon.

    .DESCRIPTION
        Registers a scheduled task that runs when the current user logs in. The task starts when available,
        runs on batteries and is given no execution time limit.
        An existing task is left untouched unless -Force is given.

    .PARAMETER Name
        Name of the task.

    .PARAMETER Executable
        The location of the executable to run.

    .PARAMETER Argument
        The argument to pass to the executable.

    .PARAMETER Path
        Path to the task in the task scheduler. Default: root path ("\").

    .PARAMETER Force
        If specified, overwrites the task if it already exists.

    .OUTPUTS
        Nothing.

    .EXAMPLE
        Register-LogonTask -Name "MyTask" -Executable "C:\MyFolder\MyExecutable.exe"

    .EXAMPLE
        Register-LogonTask -Name "MyTask" -Path "\MyFolder" -Executable "C:\MyFolder\MyExecutable.exe" -Argument "MyArgument"

    .NOTES
        Registering a task in the task scheduler requires administrator privileges.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param (
        [Parameter(Mandatory = $true)]
        [string] $Name,

        [Parameter(Mandatory = $true)]
        [string] $Executable,

        [string] $Argument,

        [string] $Path = "\",

        [switch] $Force
    )

    # New-ScheduledTaskAction rejects a blank -Argument, so it is passed only where there is one
    $actionArgument = $Argument ? @{ Argument = $Argument } : @{}

    $action = New-ScheduledTaskAction -Execute $Executable @actionArgument
    $trigger = New-ScheduledTaskTrigger -AtLogOn -User "${env:USERDOMAIN}\${env:USERNAME}"
    $settings = New-ScheduledTaskSettingsSet `
        -StartWhenAvailable `
        -AllowStartIfOnBatteries `
        -DontStopIfGoingOnBatteries `
        -ExecutionTimeLimit (New-TimeSpan)

    $task = New-ScheduledTask `
        -Trigger $trigger `
        -Action $action `
        -Settings $settings

    # the task path ends in a backslash only at the root, so the name is joined on with one where it does not
    $taskLocation = $Path.EndsWith("\") ? "$Path$Name" : "$Path\$Name"

    if ($PSCmdlet.ShouldProcess($taskLocation, "Register logon task")) {
        Register-ScheduledTask `
            -TaskName $Name `
            -TaskPath $Path `
            -InputObject $task `
            -Force:$Force `
        | Out-Null
    }
}

