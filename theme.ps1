$path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize"

function Set-Theme {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet("light", "dark")]
        [string] $Theme,

        [Parameter(Mandatory = $false)]
        [switch] $RestartExplorer = $false
    )

    switch ($Theme) {
        "light" { $lightTheme = 1 }
        "dark" { $lightTheme = 0 }
        default { throw "unexpected theme '$Theme'" }
    }

    if ($PSCmdlet.ShouldProcess("Windows theme", "Set value to '$Theme'")) { 
        Set-ItemProperty $path "SystemUsesLightTheme" $lightTheme
        Set-ItemProperty $path "AppsUseLightTheme" $lightTheme

        if ($RestartExplorer) {
            Stop-Explorer
        }
    }

    <#
    .SYNOPSIS
        Sets the Windows theme to either light or dark.

    .DESCRIPTION
        Sets the Windows theme to either light or dark.

    .PARAMETER Theme
        The theme to set. Valid values are "light" or "dark".

    .PARAMETER RestartExplorer
        If specified, Explorer is restarted after setting the theme.

    .EXAMPLE
        Set-Theme -Theme dark

    .EXAMPLE
        Set-Theme -Theme dark -RestartExplorer

    .EXAMPLE
        Set-Theme -Theme light -RestartExplorer
    #>
}

function Switch-Theme {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory = $false)]
        [switch] $RestartExplorer = $false
    )

    switch ($light = (Get-ItemPropertyValue $path "SystemUsesLightTheme")) {
        0 { Set-Theme light -RestartExplorer:$RestartExplorer }
        1 { Set-Theme dark -RestartExplorer:$RestartExplorer }
        default { throw "unexpected value in SystemUsesLightTheme '$light'" }
    }

    <#
    .SYNOPSIS
        Switches the Windows theme between light and dark.

    .DESCRIPTION
        Switches the Windows theme from light to dark or dark to light.

    .PARAMETER RestartExplorer
        If specified, Explorer is restarted after switching the theme.

    .ALIAS
        theme

    .EXAMPLE
        Switch-Theme

    .EXAMPLE
        Switch-Theme -RestartExplorer
    #>
}

New-Alias -Name theme -Value Switch-Theme
