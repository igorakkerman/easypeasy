function Register-LogonUserTask {
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
    $settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit (New-TimeSpan)

    $task = New-ScheduledTask -Trigger $trigger -Action $action -Settings $settings

    Register-ScheduledTask -TaskName $Name -TaskPath $Path -InputObject $task -Force:$Force | Out-Null
}

