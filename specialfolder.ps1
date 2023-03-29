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

New-Alias -Name docs -Value Get-MyDocumentsFolder
