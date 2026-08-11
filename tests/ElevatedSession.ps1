# Stands in for the elevated session Invoke-Elevated opens: the command it is handed runs in-process,
# with Test-Elevated true for its duration. A test then asserts what the elevated session did, not which
# command carried it there. Parameter names bind as the child shell binds them.
#
#   BeforeAll { . "$PSScriptRoot/../ElevatedSession.ps1" }
#   BeforeEach {
#       Mock -ModuleName easypeasy Test-Elevated -MockWith $elevatedTestMock
#       Mock -ModuleName easypeasy Invoke-Elevated -MockWith $elevatedSessionMock
#   }

$script:elevatedTestMock = { $script:elevatedSession -eq $true }

$script:elevatedSessionMock = {
    $script:elevatedSession = $true
    try {
        $named = @{}
        $positional = @()

        for ($index = 1; $index -lt $Command.Count; $index++) {
            $token = $Command[$index]

            if ($token -isnot [string] -or $token -notmatch '^-\w') {
                $positional += $token
                continue
            }

            # a parameter takes the token after it, unless that is a parameter itself: then it is a switch
            $value = ($index + 1) -lt $Command.Count ? $Command[$index + 1] : $null
            if ($null -ne $value -and -not ($value -is [string] -and $value -match '^-\w')) {
                $named[$token.Substring(1)] = $value
                $index++
            }
            else {
                $named[$token.Substring(1)] = $true
            }
        }

        & $Command[0] @named @positional | Out-Null
    }
    finally {
        $script:elevatedSession = $false
    }
}
