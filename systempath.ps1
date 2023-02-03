function Add-SystemPathLocation {
  [CmdletBinding()]
  param (
    [Parameter(Mandatory = $true)]
    [string]$Folder
  )
  
  $oldPath = [Environment]::GetEnvironmentVariable("Path", "Machine")
  
  $oldFolders = $oldPath -split ';'
  
  foreach ($oldFolder in $oldFolders) {
    if ($oldFolder.TrimEnd("\") -eq $Folder.TrimEnd("\")) {
      return
    }
  }

  $oldPathWithoutSemicolon = $oldPath.TrimEnd(";")

  $newPath = "$oldPathWithoutSemicolon;$Folder"

  [Environment]::SetEnvironmentVariable("Path", $newPath, "Machine")
}
