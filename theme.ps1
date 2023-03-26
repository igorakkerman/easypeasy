$path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize"

function Set-Theme {
    [CmdletBinding()]
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

    Set-ItemProperty $path "SystemUsesLightTheme" $lightTheme
    Set-ItemProperty $path "AppsUseLightTheme" $lightTheme

    if ($RestartExplorer) {
        Import-Module easypeasy
        Stop-Explorer
    }
}

function Switch-Theme {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [switch] $RestartExplorer = $false
    )

    switch ($light = (Get-ItemPropertyValue $path "SystemUsesLightTheme")) {
        0 { Set-Theme light -RestartExplorer:$RestartExplorer }
        1 { Set-Theme dark -RestartExplorer:$RestartExplorer }
        default { throw "unexpected value in SystemUsesLightTheme '$light'" }
    }
}

New-Alias -Name theme -Value Switch-Theme
