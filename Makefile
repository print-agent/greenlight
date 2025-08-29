SHELL := pwsh.exe
.SHELLFLAGS := -NoLogo -ExecutionPolicy Bypass -Command
.DEFAULT_GOAL := help

# Include environment variables from .env file
-include .env
export

# Colors for output (PowerShell compatible)
CYAN := Write-Host -ForegroundColor Cyan
GREEN := Write-Host -ForegroundColor Green
YELLOW := Write-Host -ForegroundColor Yellow

.PHONY: help confirm env-check go/run go/dev go/test go/build go/clean go/tidy go/audit db/migration/up db/migration/down db/migration/reset db/cli db/migration/status db/migration/new install-tools

# ==================================================================================== #
# HELPERS
# ==================================================================================== #

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

## Install required tools
install-tools:
	@$(CYAN) "Installing required tools..."
	@go install -tags 'postgres' github.com/golang-migrate/migrate/v4/cmd/migrate@latest
	@go install github.com/air-verse/air@latest
	@go install honnef.co/go/tools/cmd/staticcheck@latest
	@$(GREEN) "Tools installed successfully"

# ==================================================================================== #
# DEVELOPMENT
# ==================================================================================== #

## Run the Go API server in development mode
go/run: env-check
	@$(CYAN) "Starting Go API server..."
	@go run ./cmd/api -db-dsn="$(GREENLIGHT_DB_DSN)"

## Run the API with hot reload (requires air: go install github.com/air-verse/air@latest)
go/dev: env-check
	@$(CYAN) "Starting Go API server with hot reload..."
	@air

## Build the application
go/build: env-check
	@$(CYAN) "Building application..."
	@go build -ldflags '-s' -o bin/api.exe ./cmd/api
	@$$GOOS='linux'; $$GOARCH='amd64'; go build -ldflags '-s' -o bin/linux_amd64/api ./cmd/api
	@$(GREEN) "Building complete"

## Clean build artifacts
go/clean: confirm
	@$(CYAN) "Cleaning build artifacts..."
	@if (Test-Path bin) { Remove-Item -Recurse -Force bin }

## Run database migrations up
db/migration/up: env-check confirm
	@$(CYAN) "Running up migrations..."
	@migrate -path ./migrations -database $(GREENLIGHT_DB_DSN) up

## Run database migrations down
db/migration/down: env-check confirm
	@$(CYAN) "Running down migrations..."
	@migrate -path ./migrations -database $(GREENLIGHT_DB_DSN) down

## Reset database (down all + up)
db/migration/reset: env-check confirm
	@$(CYAN) "Resetting database..."
	@migrate -path ./migrations -database $(GREENLIGHT_DB_DSN) down -all
	@migrate -path ./migrations -database $(GREENLIGHT_DB_DSN) up

## Open database CLI
db/cli: env-check
	@$(CYAN) "Opening database CLI..."
	@pgcli $(GREENLIGHT_DB_DSN)

## Show database migration status
db/migration/status: env-check
	@$(CYAN) "Database migration status:"
	@migrate -path ./migrations -database $(GREENLIGHT_DB_DSN) version

## Create a new migration file (usage: make db/migration/new name=create_users_table)
db/migration/new:
	@if (-not $Env:name) { $(YELLOW) "Usage: make db/migration/new name=your_migration_name"; exit 1 }
	@$(CYAN) "Creating migration: $Env:name"
	@migrate create -seq -ext sql -dir ./migrations $Env:name

# ==================================================================================== #
# QUALITY CONTROL
# ==================================================================================== #

## Format code and tidy module dependencies
go/tidy:
	@$(CYAN) "Formatting .go files..."
	@go fmt ./...
	@$(CYAN) "Tidying module dependencies..."
	@go mod tidy
	@$(CYAN) "Verifying and vendoring module dependencies..."
	@go mod verify
	@go mod vendor
	@$(GREEN) "Code formatting and module tidying complete"

## Run comprehensive code audit (format, vet, staticcheck, test)
go/audit: go/tidy
	@$(CYAN) "Checking module dependencies..."
	@go mod tidy -diff
	@go mod verify
	@$(CYAN) "Vetting code..."
	@go vet ./...
	@if (Get-Command staticcheck -ErrorAction SilentlyContinue) { $(CYAN) "Running staticcheck..."; staticcheck ./... } else { $(YELLOW) "staticcheck not found, run 'make install-tools' to install it" }
	@$(CYAN) "Running tests with race detection..."
	@go test -race -vet=off ./...
	@$(GREEN) "Code audit complete"

## Run tests only
go/test: env-check
	@$(CYAN) "Running tests..."
	@go test -v ./...
