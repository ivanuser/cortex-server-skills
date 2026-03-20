# Go (Golang) — Runtime & Build Environment

> Install Go, manage modules, build/run/test programs, cross-compile for multiple platforms, and deploy Go services with systemd.

## Safety Rules

- Always use Go modules (`go mod init`) — GOPATH mode is legacy.
- Vet code before deploying: `go vet ./...` catches common mistakes.
- Use `-race` flag during development/testing to detect race conditions.
- Pin dependencies with `go.sum` — commit both `go.mod` and `go.sum`.
- Never deploy debug builds to production — use `-ldflags="-s -w"` to strip symbols.

## Quick Reference

```bash
# Check version
go version

# Initialize a module
go mod init github.com/user/myproject

# Run a file
go run main.go

# Build a binary
go build -o myapp .

# Run tests
go test ./...

# Format code
go fmt ./...

# Download dependencies
go mod tidy
```

## Installation

### Install on Linux (official method)

```bash
# Download latest (check https://go.dev/dl/)
GO_VERSION=1.23.6
wget "https://go.dev/dl/go${GO_VERSION}.linux-amd64.tar.gz"

# Remove old and extract
sudo rm -rf /usr/local/go
sudo tar -C /usr/local -xzf "go${GO_VERSION}.linux-amd64.tar.gz"
rm "go${GO_VERSION}.linux-amd64.tar.gz"

# Add to PATH (add to ~/.bashrc or ~/.profile)
echo 'export PATH=$PATH:/usr/local/go/bin:$HOME/go/bin' >> ~/.bashrc
source ~/.bashrc

# Verify
go version
```

### Install on ARM (aarch64)

```bash
GO_VERSION=1.23.6
wget "https://go.dev/dl/go${GO_VERSION}.linux-arm64.tar.gz"
sudo rm -rf /usr/local/go
sudo tar -C /usr/local -xzf "go${GO_VERSION}.linux-arm64.tar.gz"
rm "go${GO_VERSION}.linux-arm64.tar.gz"
```

### Update Go

```bash
# Same as install — download new version and extract over /usr/local/go
GO_VERSION=1.24.0
wget "https://go.dev/dl/go${GO_VERSION}.linux-amd64.tar.gz"
sudo rm -rf /usr/local/go
sudo tar -C /usr/local -xzf "go${GO_VERSION}.linux-amd64.tar.gz"
rm "go${GO_VERSION}.linux-amd64.tar.gz"
go version
```

### Install via package manager (may be older)

```bash
# Debian/Ubuntu
sudo apt install -y golang-go

# RHEL/Rocky
sudo dnf install -y golang
```

## GOPATH & Directory Structure

```bash
# Default GOPATH
echo $GOPATH   # Usually ~/go

# Directories
~/go/
├── bin/       # Compiled binaries (go install)
├── pkg/       # Cached package objects
└── src/       # Legacy — not needed with modules

# Module-based project (recommended)
mkdir my-project && cd my-project
go mod init github.com/user/my-project
```

## Modules — Dependency Management

```bash
# Initialize a new module
go mod init github.com/user/myproject

# Add a dependency (auto-detected from imports)
go mod tidy

# Add specific dependency
go get github.com/gin-gonic/gin@latest
go get github.com/gin-gonic/gin@v1.10.0   # Specific version

# Update all dependencies
go get -u ./...

# Update a specific dependency
go get -u github.com/gin-gonic/gin

# List dependencies
go list -m all

# Show why a dependency is needed
go mod why github.com/some/package

# Download dependencies (for offline builds)
go mod download

# Vendor dependencies
go mod vendor
go build -mod=vendor ./...

# Clean module cache
go clean -modcache

# Show module graph
go mod graph
```

## Build, Run, Test

### Run

```bash
# Run a file
go run main.go

# Run a package
go run .
go run ./cmd/server

# Run with arguments
go run main.go --port 8080
```

### Build

```bash
# Build current package
go build -o myapp .

# Build a specific package
go build -o server ./cmd/server

# Production build (stripped, smaller binary)
go build -ldflags="-s -w" -o myapp .

# Build with version info
go build -ldflags="-s -w -X main.version=1.2.3 -X main.buildTime=$(date -u +%Y%m%d%H%M%S)" -o myapp .

# Build all packages (check for errors)
go build ./...

# Install binary to $GOPATH/bin
go install ./cmd/server
```

### Test

```bash
# Run all tests
go test ./...

# Run tests in specific package
go test ./pkg/handlers

# Verbose output
go test -v ./...

# Run specific test function
go test -run TestMyFunction ./...

# With race detector
go test -race ./...

# With coverage
go test -cover ./...
go test -coverprofile=coverage.out ./...
go tool cover -html=coverage.out -o coverage.html

# Benchmark
go test -bench=. ./...
go test -bench=BenchmarkMyFunc -benchmem ./...

# Timeout
go test -timeout 60s ./...

# Count (run N times, detect flaky tests)
go test -count=5 ./...
```

### Code Quality

```bash
# Format all code
go fmt ./...
gofmt -s -w .           # Simplified formatting

# Vet (find common mistakes)
go vet ./...

# Static analysis (install first)
go install golang.org/x/tools/cmd/staticcheck@latest
staticcheck ./...

# Linting (install golangci-lint)
curl -sSfL https://raw.githubusercontent.com/golangci/golangci-lint/master/install.sh | sh -s -- -b $(go env GOPATH)/bin
golangci-lint run ./...
```

## Cross-Compilation

```bash
# Linux (amd64)
GOOS=linux GOARCH=amd64 go build -ldflags="-s -w" -o myapp-linux-amd64 .

# Linux (ARM64 — Raspberry Pi, AWS Graviton)
GOOS=linux GOARCH=arm64 go build -ldflags="-s -w" -o myapp-linux-arm64 .

# Linux (ARM v7 — older Raspberry Pi)
GOOS=linux GOARCH=arm GOARM=7 go build -ldflags="-s -w" -o myapp-linux-armv7 .

# macOS (Apple Silicon)
GOOS=darwin GOARCH=arm64 go build -ldflags="-s -w" -o myapp-darwin-arm64 .

# macOS (Intel)
GOOS=darwin GOARCH=amd64 go build -ldflags="-s -w" -o myapp-darwin-amd64 .

# Windows
GOOS=windows GOARCH=amd64 go build -ldflags="-s -w" -o myapp-windows-amd64.exe .

# List all supported platforms
go tool dist list

# Build all platforms script
for os in linux darwin windows; do
  for arch in amd64 arm64; do
    ext="" && [[ "$os" == "windows" ]] && ext=".exe"
    GOOS=$os GOARCH=$arch go build -ldflags="-s -w" -o "dist/myapp-${os}-${arch}${ext}" .
  done
done
```

## Systemd Service

```ini
# /etc/systemd/system/my-go-app.service
[Unit]
Description=My Go Application
After=network.target
Wants=network-online.target

[Service]
Type=simple
User=appuser
Group=appuser
WorkingDirectory=/opt/my-go-app
ExecStart=/opt/my-go-app/myapp
Restart=on-failure
RestartSec=10
StandardOutput=journal
StandardError=journal
Environment=PORT=8080
Environment=GIN_MODE=release
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
```

```bash
# Deploy
sudo cp myapp /opt/my-go-app/
sudo chown appuser:appuser /opt/my-go-app/myapp
sudo chmod 755 /opt/my-go-app/myapp

sudo systemctl daemon-reload
sudo systemctl enable --now my-go-app
sudo systemctl status my-go-app
sudo journalctl -u my-go-app -f
```

## Common Patterns

### Build + deploy

```bash
# Build production binary
CGO_ENABLED=0 go build -ldflags="-s -w" -o myapp .

# SCP to server
scp myapp user@server:/opt/my-go-app/myapp-new

# On server: swap binary and restart
ssh user@server "sudo mv /opt/my-go-app/myapp-new /opt/my-go-app/myapp && sudo systemctl restart my-go-app"
```

### Docker multi-stage build

```dockerfile
FROM golang:1.23-alpine AS builder
WORKDIR /app
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 go build -ldflags="-s -w" -o /app/myapp .

FROM alpine:3.20
RUN apk --no-cache add ca-certificates
COPY --from=builder /app/myapp /usr/local/bin/myapp
EXPOSE 8080
CMD ["myapp"]
```

## Troubleshooting

```bash
# Module errors — clean and re-download
go clean -modcache
go mod tidy

# "go: not found" after install
export PATH=$PATH:/usr/local/go/bin
source ~/.bashrc

# CGO issues (linking errors)
CGO_ENABLED=0 go build .   # Disable CGO for static binary

# Binary too large
go build -ldflags="-s -w" .   # Strip debug info
# Or use upx: upx --best myapp

# Race conditions
go test -race ./...
go run -race main.go

# Check Go environment
go env
go env GOPATH GOROOT GOPROXY
```
