function Backup-SystemPath {
  $env:PATH > "$env:TEMP\PATH-$(Get-Timestamp).txt"
}

function local:Add-PathLocation {
  [CmdletBinding()]
  param (
    [Parameter(Mandatory = $true)]
    [string] $Path,

    [Parameter(Mandatory = $true)]
    [string] $Folder,

    [Parameter(Mandatory = $true)]
    [bool] $First
  )

  Backup-SystemPath

  $oldFolders = $Path -split ";"
  
  foreach ($oldFolder in $oldFolders) {
    if ($oldFolder.TrimEnd("\") -ieq $Folder.TrimEnd("\")) {
      return $Path
    }
  }

  $pathWithoutSemicolon = $Path.TrimEnd(";")

  return $First ? "$Folder;$pathWithoutSemicolon" : "$pathWithoutSemicolon;$Folder"
}

function local:Remove-PathLocation {
  [CmdletBinding()]
  param (
    [Parameter(Mandatory = $true)]
    [string] $Path,

    [Parameter(Mandatory = $true)]
    [string] $Folder
  )
  
  Backup-SystemPath

  return $Path -split ";" `
  | Where-Object { $_.TrimEnd("\") -ine $Folder.TrimEnd("\") } `
  | Join-String -Separator ";"
}

function Get-SystemPath {
  [CmdletBinding()]
  param (
    [Parameter(Mandatory = $false)]
    [switch] $Split = $false
  )

  $path = Get-EnvironmentVariable -Name "Path"

  return $Split ? $path -split ";" : $path
}

New-Alias -Name path -Value Get-SystemPath

function Get-UserSystemPath {
  [CmdletBinding()]
  param (
    [Parameter(Mandatory = $false)]
    [switch] $Split = $false
  )

  $path = Get-UserEnvironmentVariable -Name "Path"

  return $Split ? $path -split ";" : $path
}

New-Alias -Name userpath -Value Get-UserSystemPath

function local:Set-SystemPath {
  [CmdletBinding()]
  param (
    [Parameter(Mandatory = $true)]
    [string] $Path
  )

  Set-EnvironmentVariable -Name "Path" -Value $Path
}

function local:Set-UserSystemPath {
  [CmdletBinding()]
  param (
    [Parameter(Mandatory = $true)]
    [string] $Path
  )

  Set-UserEnvironmentVariable -Name "Path" -Value $Path
}


function Add-SystemPathLocation {
  [CmdletBinding()]
  param (
    [Parameter(Mandatory = $true)]
    [string] $Folder,

    [Parameter(Mandatory = $false)]
    [Alias("Prepend", "Front")]
    [switch] $First = $false
  )

  Set-SystemPath -Path (Add-PathLocation -Path (Get-SystemPath) -Folder $Folder -First $First)
  # enable new location immediately
  $env:PATH = Add-PathLocation -Path "$env:PATH" -Folder $Folder -First $First 
}

function Add-UserSystemPathLocation {
  [CmdletBinding()]
  param (
    [Parameter(Mandatory = $true)]
    [string] $Folder,

    [Parameter(Mandatory = $false)]
    [Alias("Prepend", "Front")]
    [switch] $First = $false
  )

  Set-UserSystemPath -Path (Add-PathLocation -Path (Get-UserSystemPath) -Folder $Folder -First $First)
  # enable new location immediately
  $env:PATH = Add-PathLocation -Path "$env:PATH" -Folder $Folder -First $First 
}

function Remove-SystemPathLocation {
  param (
    [Parameter(Mandatory = $true)]
    [string] $Folder
  )

  Set-SystemPath (Remove-PathLocation -Path (Get-SystemPath) -Folder $Folder)
  # disable new location immediately
  $env:PATH = Remove-PathLocation -Path "$env:PATH" -Folder $Folder 
}

function Remove-UserSystemPathLocation {
  param (
    [Parameter(Mandatory = $true)]
    [string] $Folder
  )

  Set-UserSystemPath(Remove-PathLocation -Path (Get-UserSystemPath) -Folder $Folder)
  # disable new location immediately
  $env:PATH = Remove-PathLocation -Path "$env:PATH" -Folder $Folder 
}
