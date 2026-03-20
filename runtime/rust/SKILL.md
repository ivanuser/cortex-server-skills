# Rust — Systems Programming Language & Cargo Build System

> Install Rust via rustup, manage projects with Cargo, build/test/run programs, cross-compile for multiple targets, create release builds, and deploy as systemd services.

## Safety Rules

- Always use `rustup` for installation — distro packages are usually outdated.
- Run `cargo clippy` before deploying — catches common mistakes and anti-patterns.
- Use `--release` flag for production builds — debug builds are significantly slower.
- Pin `rust-toolchain.toml` in projects for reproducible builds across teams.
- Audit dependencies: `cargo audit` checks for known vulnerabilities.

## Quick Reference

```bash
# Check versions
rustc --version
cargo --version
rustup --version

# Create a new project
cargo new my-project
cd my-project

# Build and run
cargo run
cargo build --release

# Run tests
cargo test

# Check without building
cargo check

# Lint
cargo clippy
```

## Installation

### Install via rustup (recommended)

```bash
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
# Choose option 1 (default installation)

# Reload PATH
source "$HOME/.cargo/env"

# Verify
rustc --version
cargo --version
rustup --version
```

### Post-install setup

```bash
# Add to ~/.bashrc (if not auto-added)
echo 'source "$HOME/.cargo/env"' >> ~/.bashrc

# Install common components
rustup component add clippy        # Linter
rustup component add rustfmt       # Formatter
rustup component add rust-analyzer # LSP (for IDEs)
```

### Update Rust

```bash
# Update to latest stable
rustup update

# Update rustup itself
rustup self update

# Show installed toolchains
rustup show
```

### Multiple toolchains

```bash
# Install nightly
rustup toolchain install nightly

# Use nightly for current project
rustup override set nightly

# Use nightly for a single command
cargo +nightly build

# Set default toolchain
rustup default stable

# Pin toolchain per project (rust-toolchain.toml)
cat > rust-toolchain.toml << 'EOF'
[toolchain]
channel = "1.83.0"
components = ["clippy", "rustfmt", "rust-analyzer"]
targets = ["x86_64-unknown-linux-gnu"]
EOF
```

## Cargo — Project Management

### Create projects

```bash
# New binary project
cargo new my-app
cd my-app

# New library project
cargo new my-lib --lib

# Initialize in existing directory
cargo init
cargo init --lib
```

### Project structure

```
my-app/
├── Cargo.toml          # Manifest (dependencies, metadata)
├── Cargo.lock          # Locked dependency versions (commit for binaries)
├── src/
│   ├── main.rs         # Binary entry point
│   └── lib.rs          # Library entry point
├── tests/              # Integration tests
├── benches/            # Benchmarks
└── examples/           # Example programs
```

### Build

```bash
# Debug build (fast compile, slow runtime)
cargo build

# Release build (slow compile, fast runtime, optimized)
cargo build --release

# Check syntax without building (fastest)
cargo check

# Build docs
cargo doc --open

# Clean build artifacts
cargo clean
```

### Run

```bash
# Run debug build
cargo run

# Run release build
cargo run --release

# Run with arguments
cargo run -- --port 8080 --config app.toml

# Run a specific binary (workspace with multiple bins)
cargo run --bin server
cargo run --bin cli

# Run an example
cargo run --example hello
```

### Test

```bash
# Run all tests
cargo test

# Run tests with output shown
cargo test -- --nocapture

# Run specific test
cargo test test_name
cargo test tests::my_module::test_function

# Run only integration tests
cargo test --test integration_test

# Run tests in release mode
cargo test --release

# Run doc tests only
cargo test --doc

# Run ignored tests
cargo test -- --ignored

# Test with specific features
cargo test --features "feature_a feature_b"
```

### Dependencies

```bash
# Add a dependency (requires cargo-edit, or edit Cargo.toml manually)
cargo add serde --features derive
cargo add tokio --features full
cargo add clap --features derive

# Remove a dependency
cargo remove serde

# Update dependencies
cargo update                    # Update all within semver bounds
cargo update -p serde           # Update specific package

# Show dependency tree
cargo tree
cargo tree -d                   # Show duplicates
cargo tree -i serde             # Inverse: who depends on serde?

# Audit for vulnerabilities
cargo install cargo-audit
cargo audit
```

### Example `Cargo.toml`

```toml
[package]
name = "my-app"
version = "0.1.0"
edition = "2021"
authors = ["Your Name <you@example.com>"]
description = "A cool application"

[dependencies]
tokio = { version = "1", features = ["full"] }
serde = { version = "1", features = ["derive"] }
serde_json = "1"
axum = "0.7"
tracing = "0.1"
tracing-subscriber = "0.3"
anyhow = "1"

[dev-dependencies]
criterion = "0.5"

[profile.release]
opt-level = 3
lto = true
codegen-units = 1
strip = true
panic = "abort"
```

## Code Quality

```bash
# Format code
cargo fmt
cargo fmt -- --check   # Check without modifying (CI)

# Lint with clippy
cargo clippy
cargo clippy -- -D warnings   # Treat warnings as errors (CI)
cargo clippy --all-targets --all-features

# Check for unsafe code
cargo clippy -- -D unsafe_code

# Audit dependencies
cargo audit

# Check minimum supported Rust version
cargo install cargo-msrv
cargo msrv
```

## Cross-Compilation

### Using cross (easiest)

```bash
# Install cross
cargo install cross

# Build for different targets
cross build --release --target x86_64-unknown-linux-gnu
cross build --release --target aarch64-unknown-linux-gnu
cross build --release --target x86_64-unknown-linux-musl    # Static binary
cross build --release --target armv7-unknown-linux-gnueabihf
cross build --release --target x86_64-pc-windows-gnu
```

### Native cross-compilation

```bash
# Add target
rustup target add x86_64-unknown-linux-musl
rustup target add aarch64-unknown-linux-gnu

# Install linker (for aarch64)
sudo apt install -y gcc-aarch64-linux-gnu

# Configure linker in ~/.cargo/config.toml
cat >> ~/.cargo/config.toml << 'EOF'
[target.aarch64-unknown-linux-gnu]
linker = "aarch64-linux-gnu-gcc"
EOF

# Build
cargo build --release --target x86_64-unknown-linux-musl
cargo build --release --target aarch64-unknown-linux-gnu

# List installed targets
rustup target list --installed

# List all available targets
rustup target list
```

### Static binary (musl)

```bash
rustup target add x86_64-unknown-linux-musl
cargo build --release --target x86_64-unknown-linux-musl
# Binary at: target/x86_64-unknown-linux-musl/release/my-app
# Fully static — no glibc dependency, runs anywhere
```

## Release Builds & Optimization

```bash
# Standard release build
cargo build --release

# Binary location
ls -lh target/release/my-app

# Strip debug symbols (if not in Cargo.toml)
strip target/release/my-app

# Compress with UPX (optional, smaller binary)
upx --best target/release/my-app

# Check binary dependencies
ldd target/release/my-app            # Dynamic deps
file target/release/my-app           # File info
```

### Release profile optimization (`Cargo.toml`)

```toml
[profile.release]
opt-level = 3          # Maximum optimization
lto = true             # Link-time optimization
codegen-units = 1      # Single codegen unit (slower compile, faster binary)
strip = true           # Strip symbols
panic = "abort"        # Smaller binary (no unwinding)
```

## Systemd Service

```ini
# /etc/systemd/system/my-rust-app.service
[Unit]
Description=My Rust Application
After=network.target
Wants=network-online.target

[Service]
Type=simple
User=appuser
Group=appuser
WorkingDirectory=/opt/my-rust-app
ExecStart=/opt/my-rust-app/my-app
Restart=on-failure
RestartSec=10
StandardOutput=journal
StandardError=journal
Environment=RUST_LOG=info
Environment=PORT=8080
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
```

```bash
# Deploy
sudo cp target/release/my-app /opt/my-rust-app/
sudo chown appuser:appuser /opt/my-rust-app/my-app
sudo chmod 755 /opt/my-rust-app/my-app

sudo systemctl daemon-reload
sudo systemctl enable --now my-rust-app
sudo systemctl status my-rust-app
sudo journalctl -u my-rust-app -f
```

## Docker Build

```dockerfile
# Multi-stage build
FROM rust:1.83-slim AS builder
WORKDIR /app
COPY Cargo.toml Cargo.lock ./
# Cache dependencies
RUN mkdir src && echo 'fn main(){}' > src/main.rs && cargo build --release && rm -rf src
COPY src ./src
RUN cargo build --release

FROM debian:bookworm-slim
RUN apt-get update && apt-get install -y ca-certificates && rm -rf /var/lib/apt/lists/*
COPY --from=builder /app/target/release/my-app /usr/local/bin/my-app
EXPOSE 8080
CMD ["my-app"]
```

```dockerfile
# Static build with musl (smallest image)
FROM rust:1.83-alpine AS builder
RUN apk add --no-cache musl-dev
WORKDIR /app
COPY . .
RUN cargo build --release --target x86_64-unknown-linux-musl

FROM scratch
COPY --from=builder /app/target/x86_64-unknown-linux-musl/release/my-app /my-app
EXPOSE 8080
CMD ["/my-app"]
```

## Troubleshooting

```bash
# Toolchain issues
rustup update
rustup component add clippy rustfmt

# Linker errors
sudo apt install -y build-essential pkg-config libssl-dev

# OpenSSL linking issues
sudo apt install -y libssl-dev pkg-config
# Or use rustls instead of native-tls in dependencies

# Slow builds
cargo build --jobs $(nproc)   # Parallel build
# Use sccache for caching: cargo install sccache

# "edition 2021 is not supported" — old toolchain
rustup update stable

# Large binary size
# Add to Cargo.toml [profile.release]: strip = true, lto = true, panic = "abort"

# Cargo cache cleanup
cargo cache --autoclean   # Requires cargo-cache
rm -rf target/            # Nuclear option
```
