function Get-MyDocumentsFolder {
    [CmdletBinding()]
    Param()
    
    $wshShell = New-Object -ComObject WScript.Shell
    return $wshShell.SpecialFolders("MyDocuments")

    <#
    .SYNOPSIS
        Returns the path to the My Documents folder.

    .DESCRIPTION
        Returns the path to the My Documents folder.

    .ALIASES
        docs
    #>
}

function Get-DesktopFolder {
    [CmdletBinding()]
    Param()
    
    return [Environment]::GetFolderPath("Desktop")

    <#
    .SYNOPSIS
        Returns the path to the user's Desktop folder.

    .DESCRIPTION
        Returns the path to the user's Desktop folder.

    .ALIASES
        desktop
    #>
}

New-Alias -Name docs -Value Get-MyDocumentsFolder
New-Alias -Name desktop -Value Get-MyDocumentsFolder
