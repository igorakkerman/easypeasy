. "$PSScriptRoot\environment.ps1"
. "$PSScriptRoot\timestamp.ps1"

function Add-SystemPathLocation {
  [CmdletBinding()]
  param (
    [Parameter(Mandatory = $true)]
    [string]$Folder
  )
  
  $env:PATH > "$env:TEMP\PATH-$(Get-Timestamp).txt"

  $oldPath = Get-EnvironmentVariable -Name "Path"
  
  $oldFolders = $oldPath -split ';'
  
  foreach ($oldFolder in $oldFolders) {
    if ($oldFolder.TrimEnd("\") -eq $Folder.TrimEnd("\")) {
      return
    }
  }

  $oldPathWithoutSemicolon = $oldPath.TrimEnd(";")

  $newPath = "$oldPathWithoutSemicolon;$Folder"

  Set-EnvironmentVariable -Name "Path" -Value $newPath
}
