$path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize"

function Get-Theme {
    [CmdletBinding()]
    param()

    switch ($light = (Get-ItemPropertyValue $path "SystemUsesLightTheme")) {
        0 { "dark" }
        1 { "light" }
        default { throw "unexpected value in SystemUsesLightTheme '$light'" }
    }
}

<#
    .SYNOPSIS
        Returns the current Windows theme.

    .DESCRIPTION
        Returns the current Windows theme as either "light" or "dark".

    .OUTPUTS string - either "light" or "dark" according to the current Windows theme

    .EXAMPLE
        Write-Host "Windows is using $(Get-Theme) mode."
    #>


function Set-Theme {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Position = 0, Mandatory = $true)]
        [ValidateSet("light", "dark")]
        [string] $Theme,

        [Parameter(Mandatory = $false)]
        [System.Obsolete("'RestartExplorer' has become unnecessary. Theme changes are now broadcasted to other processes.")]
        [switch] $RestartExplorer = $false
    )

    switch ($Theme) {
        "light" { $lightTheme = 1 }
        "dark" { $lightTheme = 0 }
        default { throw "unexpected theme '$Theme'" }
    }

    if ($PSCmdlet.ShouldProcess("Windows theme", "Set value to '$Theme'")) { 
        Set-ItemProperty -Path $path -Name "SystemUsesLightTheme" -Value $lightTheme
        Set-ItemProperty -Path $path -Name "AppsUseLightTheme" -Value $lightTheme

        Send-ThemeChangeBroadcast
    }

    <#
    .SYNOPSIS
        Sets the Windows theme to either light or dark.

    .DESCRIPTION
        Sets the Windows theme to either light or dark.

    .PARAMETER Theme
        The theme to set. Valid values are "light" or "dark".

    .EXAMPLE
        Set-Theme -Theme dark

    .EXAMPLE
        Set-Theme -Theme light
    #>
}

function Switch-Theme {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Position = 0, Mandatory = $false)]
        [ValidateSet("light", "dark")]
        [string] $Theme,

        [Parameter(Mandatory = $false)]
        [System.Obsolete("'RestartExplorer' has become unnecessary. Theme changes are now broadcasted to other processes.")]
        [switch] $RestartExplorer = $false
    )

    if ($Theme) {
        Set-Theme -Theme $Theme
        return
    }

    switch ($theme = Get-Theme) {
        "dark" { Set-Theme -Theme light }
        "light" { Set-Theme -Theme dark }
        default { throw "unexpected value from Get-Theme '$theme'" }
    }

    <#
    .SYNOPSIS
        Switches the Windows theme between light and dark.

    .DESCRIPTION
        Switches the Windows theme from light to dark or dark to light.

    .PARAMETER Theme
        If provided, specifies the theme to set. Valid values are "light" or "dark".
        Otherwise, switches the theme from light to dark or dark to light.

    .ALIAS
        theme

    .EXAMPLE
        Switch-Theme
    #>
}

New-Alias -Name theme -Value Switch-Theme -ErrorAction SilentlyContinue | Out-Null

function local:Send-ThemeChangeBroadcast {
    if (-not ("win32.nativemethods" -As [type])) {
        Add-Type -Namespace Win32 -Name NativeMethods -MemberDefinition @"

        [DllImport("user32.dll", SetLastError = true, CharSet = CharSet.Auto)]

        public static extern IntPtr SendMessageTimeout(
            IntPtr hWnd,
            uint Msg,
            UIntPtr wParam,
            string lParam,
            uint fuFlags,
            uint uTimeout,
            out UIntPtr lpdwResult
        );
"@
    }

    # use hashtable for formatting 
    $msgArgs = @{
        hWnd       = [intptr]0xffff       # HWND_BROADCAST
        Msg        = 0x1a                 # WM_SETTINGCHANGE
        fuflags    = 0x2                  # SMTO_ABORTIFHUNG: ignore timeout if receiving thread hangs/doesn't respond
        wParam     = [uintptr]::Zero      # none
        lParam     = "ImmersiveColorSet"  # what to notify about
        uTimeout   = 5000                 # timeout in ms
        lpdwResult = [uintptr]::zero
    }

    [void](
        [win32.nativemethods]::SendMessageTimeout(
            $msgArgs.hWnd,
            $msgArgs.Msg,
            $msgArgs.wParam,
            $msgArgs.lParam,
            $msgArgs.fuflags,
            $msgArgs.uTimeout,
            [ref]$msgArgs.lpdwResult
        )
    )
}
<#
    .SYNOPSIS
        Broadcasts the theme/color change to all processes.
    .DESCRIPTION
        Broadcasts the theme/color change to all processes, so they can adapt to the updated theme.
        Some processes such as Windows Explorer don't react to a registry change alone. 
    .EXAMPLE
        Send-ThemeChangeBroadcast
    #>
