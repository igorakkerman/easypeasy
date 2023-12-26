function Get-ProgramFilesFolder {
    [CmdletBinding()]
    Param()
    
    return [System.Environment]::GetFolderPath([System.Environment+SpecialFolder]::ProgramFiles)

    <#
    .SYNOPSIS
        Returns the path to the Program Files folder.

    .DESCRIPTION
        Returns the path to the Program Files folder.

    .ALIASES
        progs
    #>
}
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

New-Alias -Name programs -Value Get-ProgramFilesFolder -ErrorAction SilentlyContinue | Out-Null
New-Alias -Name docs -Value Get-MyDocumentsFolder -ErrorAction SilentlyContinue | Out-Null
New-Alias -Name desktop -Value Get-DesktopFolder -ErrorAction SilentlyContinue | Out-Null
