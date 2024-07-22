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
        [Parameter(Position = 0, Mandatory = $false)]
        [ValidateSet("light", "dark")]
        [string] $Theme,

        [Parameter(Mandatory = $false)]
        [switch] $RestartExplorer = $false
    )

    if ($Theme) {
        Set-Theme -Theme $Theme -RestartExplorer:$RestartExplorer
        return
    }

    switch ($theme = Get-Theme) {
        "dark" { Set-Theme light -RestartExplorer:$RestartExplorer }
        "light" { Set-Theme dark -RestartExplorer:$RestartExplorer }
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

New-Alias -Name theme -Value Switch-Theme -ErrorAction SilentlyContinue | Out-Null
