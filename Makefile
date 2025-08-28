SHELL := pwsh.exe
.SHELLFLAGS := -NoLogo -ExecutionPolicy Bypass -Command
.DEFAULT_GOAL := help

# Load environment variables
LOAD_ENV := . ./load_env.ps1 -Verbose

# Colors for output (PowerShell compatible)
CYAN := Write-Host -ForegroundColor Cyan
GREEN := Write-Host -ForegroundColor Green
YELLOW := Write-Host -ForegroundColor Yellow

.PHONY: help confirm env-check go/run go/dev go/test go/build go/clean db/up db/down db/reset db/cli db/status

## Show this help message
help:
	@$(CYAN) "Available commands:"
	@$$commands = @(); $$maxLength = 0; $$content = Get-Content '$(firstword $(MAKEFILE_LIST))'; for ($$i = 0; $$i -lt $$content.Length; $$i++) { if ($$content[$$i] -match '^## (.+)$$') { $$desc = $$matches[1]; if (($$i + 1) -lt $$content.Length -and $$content[$$i + 1] -match '^([a-zA-Z0-9_/-]+):') { $$target = $$matches[1]; if ($$target.Length -gt $$maxLength) { $$maxLength = $$target.Length; }; $$commands += [PSCustomObject]@{ Target = $$target; Description = $$desc }; }; }; }; $$padding = $$maxLength + 4; foreach ($$command in $$commands) { $$targetPadded = $$command.Target.PadRight($$padding); $(CYAN) "  $$targetPadded$$($$command.Description)"; }

## (Internal) Universally confirm a potentially destructive action
confirm:
	@$$goal = "$(MAKECMDGOALS)"; $$response = Read-Host "Are you sure you want to run '$$goal'? (y/N)"; if ($$response.ToLower() -ne 'y') { $(CYAN) "Operation cancelled."; exit 1; }

## Check if .env file exists and execution policy
env-check:
	@if (-not (Test-Path .env)) { $(YELLOW) "Warning: .env file not found"; exit 1 }
	@$$policy = Get-ExecutionPolicy; if ($$policy -eq "Restricted") { $(YELLOW) "Warning: ExecutionPolicy is Restricted. Run: Set-ExecutionPolicy RemoteSigned -Scope CurrentUser"; exit 1 }
	@$(GREEN) "Environment setup OK"

## Run the Go API server in development mode
go/run: env-check
	@$(CYAN) "Starting Go API server..."
	@$(LOAD_ENV); go run ./cmd/api -db-dsn="$${Env:GREENLIGHT_DB_DSN}"

## Run the API with hot reload (requires air: go install github.com/air-verse/air@latest)
go/dev: env-check
	@$(CYAN) "Starting Go API server with hot reload..."
	@$(LOAD_ENV); air

## Run tests
go/test: env-check
	@$(CYAN) "Running tests..."
	@$(LOAD_ENV); go test -v ./...

## Build the application
go/build: env-check
	@$(CYAN) "Building application..."
	@$(LOAD_ENV); go build -o bin/api.exe ./cmd/api

## Clean build artifacts
go/clean: confirm
	@$(CYAN) "Cleaning build artifacts..."
	@if (Test-Path bin) { Remove-Item -Recurse -Force bin }

## Run database migrations up
db/migration/up: env-check confirm
	@$(CYAN) "Running up migrations..."
	@$(LOAD_ENV); migrate -path ./migrations -database $$Env:GREENLIGHT_DB_DSN up

## Run database migrations down
db/migration/down: env-check confirm
	@$(CYAN) "Running down migrations..."
	@$(LOAD_ENV); migrate -path ./migrations -database $$Env:GREENLIGHT_DB_DSN down

## Reset database (down all + up)
db/migration/reset: env-check confirm
	@$(CYAN) "Resetting database..."
	@$(LOAD_ENV); migrate -path ./migrations -database $$Env:GREENLIGHT_DB_DSN down -all; migrate -path ./migrations -database $$Env:GREENLIGHT_DB_DSN up

## Open database CLI
db/cli: env-check
	@$(CYAN) "Opening database CLI..."
	@$(LOAD_ENV); pgcli $$Env:GREENLIGHT_DB_DSN

## Show database migration status
db/migration/status: env-check
	@$(CYAN) "Database migration status:"
	@$(LOAD_ENV); migrate -path ./migrations -database $$Env:GREENLIGHT_DB_DSN version

## Create a new migration file (usage: make db-migration name=create_users_table)
db/migration/new:
	@if (-not $$Env:name) { $(YELLOW) "Usage: make db/migration name=your_migration_name"; exit 1 }
	@$(CYAN) "Creating migration: $$Env:name"
	@migrate create -seq -ext sql -dir ./migrations $$Env:name

## Install required tools
install-tools:
	@$(CYAN) "Installing required tools..."
	@go install -tags 'postgres' github.com/golang-migrate/migrate/v4/cmd/migrate@latest
	@go install github.com/air-verse/air@latest
	@$(GREEN) "Tools installed successfully"
