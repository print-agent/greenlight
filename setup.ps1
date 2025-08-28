# setup.ps1: Initial project setup script
param([switch]$Force)

Write-Host "🚀 Setting up Greenlight project..." -ForegroundColor Cyan

# Check and set execution policy
$currentPolicy = Get-ExecutionPolicy
Write-Host "Current execution policy: $currentPolicy" -ForegroundColor Yellow

if ($currentPolicy -eq "Restricted") {
    if ($Force) {
        Write-Host "Setting execution policy to RemoteSigned..." -ForegroundColor Yellow
        Set-ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
        Write-Host "✅ Execution policy updated" -ForegroundColor Green
    } else {
        Write-Host "⚠️  Execution policy is Restricted. This will prevent scripts from running." -ForegroundColor Red
        Write-Host "Run this script with -Force flag to automatically set it to RemoteSigned, or run manually:" -ForegroundColor Yellow
        Write-Host "Set-ExecutionPolicy RemoteSigned -Scope CurrentUser" -ForegroundColor Cyan
        exit 1
    }
}

# Check if .env file exists
if (-not (Test-Path ".env")) {
    Write-Host "Creating sample .env file..." -ForegroundColor Yellow
    @"
# Database configuration
GREENLIGHT_DB_DSN=postgres://greenlight:pass@localhost/greenlight?sslmode=disable

# Server configuration
PORT=4000
ENV=development

# JWT secrets (generate your own!)
JWT_SECRET=your-super-secret-jwt-key-here

# SMTP configuration (for sending emails)
SMTP_HOST=smtp.mailtrap.io
SMTP_PORT=587
SMTP_USERNAME=your-smtp-username
SMTP_PASSWORD=your-smtp-password
SMTP_SENDER=Greenlight <no-reply@greenlight.local>

# Rate limiting
LIMITER_RPS=2
LIMITER_BURST=4
LIMITER_ENABLED=true

# CORS
CORS_TRUSTED_ORIGINS=http://localhost:3000,http://localhost:8080
"@ | Out-File -FilePath ".env" -Encoding utf8
    Write-Host "✅ Created .env file with sample configuration" -ForegroundColor Green
    Write-Host "⚠️  Please update the values in .env with your actual configuration" -ForegroundColor Yellow
} else {
    Write-Host "✅ .env file already exists" -ForegroundColor Green
}

# Check if .gitignore includes .env
if (Test-Path ".gitignore") {
    $gitignoreContent = Get-Content ".gitignore" -Raw
    if ($gitignoreContent -notmatch "\.env") {
        Write-Host "Adding .env to .gitignore..." -ForegroundColor Yellow
        Add-Content ".gitignore" "`n# Environment variables`n.env"
        Write-Host "✅ Added .env to .gitignore" -ForegroundColor Green
    } else {
        Write-Host "✅ .env already in .gitignore" -ForegroundColor Green
    }
} else {
    Write-Host "Creating .gitignore..." -ForegroundColor Yellow
    @"
# Binaries for programs and plugins
*.exe
*.exe~
*.dll
*.so
*.dylib
bin/
dist/

# Test binary, built with `go test -c`
*.test

# Output of the go coverage tool
*.out

# Go workspace file
go.work

# Environment variables
.env

# IDE files
.vscode/
.idea/
*.swp
*.swo
*~

# OS generated files
.DS_Store
.DS_Store?
._*
.Spotlight-V100
.Trashes
ehthumbs.db
Thumbs.db
"@ | Out-File -FilePath ".gitignore" -Encoding utf8
    Write-Host "✅ Created .gitignore file" -ForegroundColor Green
}

# Test the environment loading
Write-Host "Testing environment loading..." -ForegroundColor Yellow
try {
    . ./load_env.ps1 -Verbose
    Write-Host "✅ Environment loading works correctly" -ForegroundColor Green
} catch {
    Write-Host "❌ Error loading environment: $_" -ForegroundColor Red
    exit 1
}

Write-Host "🎉 Setup complete! You can now use:" -ForegroundColor Green
Write-Host "  make run      - Start the API server" -ForegroundColor Cyan
Write-Host "  make db-up    - Run database migrations" -ForegroundColor Cyan
Write-Host "  make db-cli   - Open database CLI" -ForegroundColor Cyan
Write-Host "  make help     - See all available commands" -ForegroundColor Cyan
