function Register-LogonTask {
    [CmdletBinding()]
    Param(
        [string] $Name,
        [string] $Path = "\",
        [string] $Executable,
        [string] $Argument,
        [switch] $Force = $false
    )

    $action = New-ScheduledTaskAction -Execute $Executable -Argument $Argument
    $trigger = New-ScheduledTaskTrigger -AtLogOn -User "${env:\USERDOMAIN}\${env:USERNAME}"
    $settings = New-ScheduledTaskSettingsSet `
        -StartWhenAvailable `
        -AllowStartIfOnBatteries `
        -DontStopIfGoingOnBatteries `
        -ExecutionTimeLimit (New-TimeSpan)

    $task = New-ScheduledTask `
        -Trigger $trigger `
        -Action $action `
        -Settings $settings

    Register-ScheduledTask `
        -TaskName $Name `
        -TaskPath $Path `
        -InputObject $task `
        -Force:$Force `
    | Out-Null

    <#
   .SYNOPSIS
        Registers a task to run at user logon.

    .DESCRIPTION
        Registers a scheduled task that runs when the user logs in.

    .PARAMETER Name
        Name of the task.

    .PARAMETER Path
        Path to the task. Default: root path ("\").

    .PARAMETER Executable
        The path to the executable to run.

    .PARAMETER Argument
        The argument to pass to the executable.

    .PARAMETER Force
        If specified, overwrites the task if it already exists.

    .EXAMPLE
        Register-LogonTask -Name "MyTask" -Path "\MyFolder" -Executable "C:\MyFolder\MyExecutable.exe" -Argument "MyArgument"
    #>
}

