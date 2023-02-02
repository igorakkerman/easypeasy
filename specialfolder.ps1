function Get-MyDocumentsFolder {
    $wshShell = New-Object -ComObject WScript.Shell
    return $wshShell.SpecialFolders("MyDocuments")
}

New-Alias -Name docs -Value Get-MyDocumentsFolder
