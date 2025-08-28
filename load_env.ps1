# load_env.ps1: Enhanced PowerShell .env loader
param(
    [string]$EnvFile = ".env",
    [switch]$Verbose
)

if (-not (Test-Path $EnvFile)) {
    Write-Warning "$EnvFile file not found - skipping env load"
    exit 0
}

$envVars = @{}
$envContent = Get-Content $EnvFile -ErrorAction Stop

foreach ($line in $envContent) {
    $line = $line.Trim()

    # Skip empty lines and comments
    if (-not $line -or $line.StartsWith('#')) {
        continue
    }

    # Parse KEY=VALUE format
    if ($line -match '^([^=]+?)=(.*)$') {
        $key = $matches[1].Trim()
        $value = $matches[2].Trim()

        # Handle quoted values (supports nested quotes and escaping)
        if ($value -match '^"(.*)"$' -or $value -match "^'(.*)'$") {
            $value = $matches[1]
            # Basic escape sequence handling
            $value = $value -replace '\\n', "`n" -replace '\\t', "`t" -replace '\\\\', '\'
        }

        # Expand variables like $VAR or ${VAR} from already loaded env vars
        $value = $value -replace '\$\{([^}]+)\}', { param($match)
            $varName = $match.Groups[1].Value
            if ($envVars.ContainsKey($varName)) { $envVars[$varName] }
            elseif ([Environment]::GetEnvironmentVariable($varName)) { [Environment]::GetEnvironmentVariable($varName) }
            else { $match.Value }
        }

        # Set environment variable
        [Environment]::SetEnvironmentVariable($key, $value, 'Process')
        $envVars[$key] = $value

        if ($Verbose) {
            Write-Host "Set $key=$value" -ForegroundColor Green
        }
    }
}

if ($Verbose) {
    Write-Host "Loaded $($envVars.Count) environment variables from $EnvFile" -ForegroundColor Cyan
}
