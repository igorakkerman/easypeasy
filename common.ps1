# Shared WScript.Shell COM object, used to read and write shortcuts and to resolve special folders.
# Creating one costs roughly a millisecond, well above the file reads around it, so the module keeps a single instance.
$wshShell = New-Object -ComObject WScript.Shell
