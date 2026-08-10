function Register-LogonTask {
    <#
    .SYNOPSIS
        Registers a task to run at user logon.

    .DESCRIPTION
        Registers a scheduled task that runs when the current user logs in. The task starts when available,
        runs on batteries and is given no execution time limit.
        An existing task is left untouched unless -Force is given.
        The task runs with the privileges the user logs on with, unless -Elevated is given.

    .PARAMETER Name
        Name of the task.

    .PARAMETER Executable
        The location of the executable to run.

    .PARAMETER Argument
        The argument to pass to the executable.

    .PARAMETER Path
        Path in the task scheduler. Default: root path ("\").

    .PARAMETER Elevated
        If specified, the task runs with the highest privileges available to the user,
        as "Run with highest privileges" in the task scheduler.

    .PARAMETER Force
        If specified, overwrites the task if it already exists.

    .OUTPUTS
        Nothing.

    .EXAMPLE
        Register-LogonTask -Name "MyTask" -Executable "C:\MyFolder\MyExecutable.exe"

    .EXAMPLE
        Register-LogonTask -Name "MyTask" -Path "\MyFolder" -Executable "C:\MyFolder\MyExecutable.exe" -Argument "MyArgument"

    .EXAMPLE
        Register-LogonTask -Name "MyTask" -Executable "C:\MyFolder\MyExecutable.exe" -Elevated

    .NOTES
        Alias for -Elevated: -Administrator
        A task of the current user needs no administrator privileges. An -Elevated task does:
        it auto-elevates through Invoke-Elevated (sudo --inline) when the session is not already elevated.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param (
        [Parameter(Mandatory)]
        [string] $Name,
        [Parameter(Mandatory)]
        [string] $Executable,
        [string] $Argument,
        [string] $Path = "\",
        [Alias("Administrator")]
        [switch] $Elevated,
        [switch] $Force
    )

    # -Elevated asks for a run level only an administrator registers,
    # so an unelevated session hands the registration over to an elevated one
    $elevates = $Elevated -and -not (Test-Elevated)

    if ($elevates) { Assert-SudoAvailable }

    # trailing backslash at root only
    $taskLocation = $Path.EndsWith("\") ? "$Path$Name" : "$Path\$Name"

    # New-ScheduledTaskAction rejects blank -Argument, so passed only where there is one
    $actionArgument = $Argument ? @{ Argument = $Argument } : @{}

    $action = New-ScheduledTaskAction -Execute $Executable @actionArgument
    $trigger = New-ScheduledTaskTrigger -AtLogOn -User "${env:USERDOMAIN}\${env:USERNAME}"
    $settings = New-ScheduledTaskSettingsSet `
        -StartWhenAvailable `
        -AllowStartIfOnBatteries `
        -DontStopIfGoingOnBatteries `
        -ExecutionTimeLimit (New-TimeSpan)

    # default principal: current user, interactive, limited run level
    # principal built for Highest run level alone
    $elevatedPrincipal = $Elevated `
        ? @{ Principal = New-ScheduledTaskPrincipal `
                -UserId "${env:USERDOMAIN}\${env:USERNAME}" `
                -LogonType Interactive `
                -RunLevel Highest
        } `
        : @{}

    $task = New-ScheduledTask `
        -Trigger $trigger `
        -Action $action `
        -Settings $settings `
        @elevatedPrincipal

    if ($PSCmdlet.ShouldProcess($taskLocation, "Register logon task")) {
        # task built here, handed over as XML, so the elevated session runs
        # the task scheduler's own command, resolvable anywhere
        if ($elevates) {
            $command = @(
                "Register-ScheduledTask"
                "-TaskName", $Name
                "-TaskPath", $Path
                "-Xml", ($task | Export-ScheduledTask)
            )
            if ($Force) { $command += "-Force" }
            # registered task written through by elevated session, dropped as in-process
            Invoke-Elevated $command | Out-Null
            return
        }

        Register-ScheduledTask `
            -TaskName $Name `
            -TaskPath $Path `
            -InputObject $task `
            -Force:$Force `
            -ErrorAction Stop `
        | Out-Null
    }
}

