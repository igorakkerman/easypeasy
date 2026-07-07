function Get-ProgramFilesFolder {
    <#
    .SYNOPSIS
        Returns the path to the Program Files folder.

    .DESCRIPTION
        Returns the path to the Program Files folder.

    .ALIASES
        progs
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

    .ALIASES
        docs
    #>

    [CmdletBinding()]
    Param()
    
    $wshShell = New-Object -ComObject WScript.Shell
    return $wshShell.SpecialFolders("MyDocuments")
}

function Get-DesktopFolder {
    <#
    .SYNOPSIS
        Returns the path to the user's Desktop folder.

    .DESCRIPTION
        Returns the path to the user's Desktop folder.

    .ALIASES
        desktop
    #>

    [CmdletBinding()]
    Param()
    
    return [Environment]::GetFolderPath("Desktop")
}

New-Alias -Name programs -Value Get-ProgramFilesFolder -ErrorAction SilentlyContinue | Out-Null
New-Alias -Name docs -Value Get-MyDocumentsFolder -ErrorAction SilentlyContinue | Out-Null
New-Alias -Name desktop -Value Get-DesktopFolder -ErrorAction SilentlyContinue | Out-Null
