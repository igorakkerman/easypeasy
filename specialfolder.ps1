function Get-ProgramFilesFolder {
    <#
    .SYNOPSIS
        Returns the path to the Program Files folder.

    .DESCRIPTION
        Returns the path to the Program Files folder.

    .NOTES
        Alias: programs
    #>
    [CmdletBinding()]
    Param()
    
    return [System.Environment]::GetFolderPath([System.Environment+SpecialFolder]::ProgramFiles)
}
function Get-MyDocumentsFolder {
    <#
    .SYNOPSIS
        Returns the path to the My Documents folder.

    .DESCRIPTION
        Returns the path to the My Documents folder.

    .NOTES
        Alias: docs
    #>
    [CmdletBinding()]
    Param()
    
    return $wshShell.SpecialFolders("MyDocuments")
}

function Get-DesktopFolder {
    <#
    .SYNOPSIS
        Returns the path to the user's Desktop folder.

    .DESCRIPTION
        Returns the path to the user's Desktop folder.

    .NOTES
        Alias: desktop
    #>
    [CmdletBinding()]
    Param()
    
    return [Environment]::GetFolderPath("Desktop")
}

New-Alias -Name programs -Value Get-ProgramFilesFolder -ErrorAction SilentlyContinue | Out-Null
New-Alias -Name docs -Value Get-MyDocumentsFolder -ErrorAction SilentlyContinue | Out-Null
New-Alias -Name desktop -Value Get-DesktopFolder -ErrorAction SilentlyContinue | Out-Null
