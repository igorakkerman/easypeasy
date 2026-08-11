# Environment variables

Scopes are `Machine` and `User`, both persisted in the registry, plus the effective value
the current process sees. A write updates the registry and the current process.

## Get-EnvironmentVariable (getenv)

```powershell
getenv JAVA_HOME                # -Effective, default
getenv JAVA_HOME -Machine       # -Machine, -User
getenv TMP -Expandable          # stored value, %...% left unevaluated
```

Returns the value as a string. A variable that does not exist reports an error and no value;
the caller's `-ErrorAction` governs.

## Set-EnvironmentVariable (setenv)

```powershell
setenv JAVA_HOME "C:\Java\jdk-21"               # -User, default
setenv JAVA_HOME "C:\Java\jdk-21" -Machine      # elevates
setenv TMP "%USERPROFILE%\tmp" -Expandable      # stored as reference, expanded on read
```

Without `-Expandable` a `%...%` reference is stored literally and never expands.
With `-Expandable`, a reference the process environment does not set raises a warning per
missing variable, naming it.

## Remove-EnvironmentVariable (rmenv)

```powershell
rmenv JAVA_HOME                 # -User, default
rmenv JAVA_HOME -Machine        # elevates
```

## Get-Environment

```powershell
Get-Environment                 # both scopes
Get-Environment -Machine        # one scope: -Machine, -User
```

Records carry `Scope`, `Name` and `Value`, ordered by name.
Where both scopes define a name, the user record comes first, its value being the one in effect.

`PATH` is an environment variable, but use the system Path commands for it:
they merge the scopes and keep the current process in sync. See `references/systempath.md`.
