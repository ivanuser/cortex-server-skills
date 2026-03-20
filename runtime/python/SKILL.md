# Python — Runtime Environment & Package Management

> Install Python, manage virtual environments, use pip/pyenv, run ASGI/WSGI servers with uvicorn/gunicorn, and deploy Python apps as systemd services.

## Safety Rules

- Always use virtual environments — never `pip install` into the system Python.
- Never run `pip` as root unless installing into a system-managed venv.
- Pin dependencies in `requirements.txt` with exact versions for reproducible builds.
- Use `python3` explicitly (not `python`) to avoid Python 2 ambiguity.
- Test with `--dry-run` or a staging venv before upgrading production dependencies.

## Quick Reference

```bash
# Check version
python3 --version
pip3 --version

# Create and activate venv
python3 -m venv .venv
source .venv/bin/activate

# Install dependencies
pip install -r requirements.txt

# Run a script
python3 app.py

# Run uvicorn server
uvicorn main:app --host 0.0.0.0 --port 8000

# Deactivate venv
deactivate
```

## Installation

### Install on Debian/Ubuntu

```bash
# System Python (usually pre-installed)
sudo apt update && sudo apt install -y python3 python3-pip python3-venv

# Install specific version from deadsnakes PPA
sudo add-apt-repository -y ppa:deadsnakes/ppa
sudo apt update
sudo apt install -y python3.12 python3.12-venv python3.12-dev
```

### Install on RHEL/Rocky/Alma

```bash
sudo dnf install -y python3 python3-pip python3-devel
# Specific version
sudo dnf install -y python3.12 python3.12-devel
```

### Build from source (any version)

```bash
sudo apt install -y build-essential zlib1g-dev libncurses5-dev libgdbm-dev \
  libnss3-dev libssl-dev libreadline-dev libffi-dev libsqlite3-dev wget libbz2-dev

wget https://www.python.org/ftp/python/3.12.8/Python-3.12.8.tgz
tar xzf Python-3.12.8.tgz && cd Python-3.12.8
./configure --enable-optimizations --prefix=/usr/local
make -j$(nproc)
sudo make altinstall   # altinstall to not override system python
python3.12 --version
```

## pyenv — Python Version Manager

### Install pyenv

```bash
# Install dependencies
sudo apt install -y make build-essential libssl-dev zlib1g-dev libbz2-dev \
  libreadline-dev libsqlite3-dev wget curl llvm libncursesw5-dev xz-utils \
  tk-dev libxml2-dev libxmlsec1-dev libffi-dev liblzma-dev

# Install pyenv
curl https://pyenv.run | bash

# Add to ~/.bashrc
cat >> ~/.bashrc << 'EOF'
export PYENV_ROOT="$HOME/.pyenv"
[[ -d $PYENV_ROOT/bin ]] && export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init -)"
eval "$(pyenv virtualenv-init -)"
EOF
source ~/.bashrc
```

### Manage Python versions with pyenv

```bash
# List available versions
pyenv install --list | grep "^  3\." | tail -20

# Install a version
pyenv install 3.12.8
pyenv install 3.11.11

# Set global default
pyenv global 3.12.8

# Set per-project version
cd my-project
pyenv local 3.11.11   # Creates .python-version file

# List installed versions
pyenv versions

# Uninstall
pyenv uninstall 3.10.14
```

## Virtual Environments

### venv (built-in)

```bash
# Create
python3 -m venv .venv

# Activate
source .venv/bin/activate         # Linux/macOS
# .venv\Scripts\activate          # Windows

# Verify
which python
python --version

# Install packages
pip install flask requests

# Freeze dependencies
pip freeze > requirements.txt

# Deactivate
deactivate

# Delete venv
rm -rf .venv
```

### pyenv-virtualenv

```bash
# Create named virtualenv
pyenv virtualenv 3.12.8 my-project-env

# Activate
pyenv activate my-project-env

# Auto-activate per directory
pyenv local my-project-env   # Creates .python-version

# List virtualenvs
pyenv virtualenvs

# Delete
pyenv virtualenv-delete my-project-env
```

## pip — Package Management

```bash
# Install packages
pip install flask
pip install flask==3.1.0           # Specific version
pip install "flask>=3.0,<4.0"      # Version range

# Install from requirements
pip install -r requirements.txt

# Upgrade a package
pip install --upgrade flask

# Uninstall
pip uninstall flask

# List installed packages
pip list
pip list --outdated

# Show package info
pip show flask

# Generate requirements
pip freeze > requirements.txt

# Install in editable mode (development)
pip install -e .
pip install -e ".[dev]"            # With extras

# Download wheels (for offline install)
pip download -r requirements.txt -d ./wheels
pip install --no-index --find-links=./wheels -r requirements.txt

# Security audit
pip audit   # Requires pip-audit: pip install pip-audit
```

### Common packages

```bash
# Web frameworks
pip install flask django fastapi starlette

# API / HTTP
pip install requests httpx aiohttp

# Database
pip install sqlalchemy psycopg2-binary pymongo redis

# Data / ML
pip install numpy pandas scikit-learn matplotlib

# Dev tools
pip install black ruff mypy pytest
```

## ASGI/WSGI Servers

### uvicorn (ASGI — FastAPI, Starlette)

```bash
# Install
pip install uvicorn[standard]

# Run
uvicorn main:app --host 0.0.0.0 --port 8000
uvicorn main:app --host 0.0.0.0 --port 8000 --workers 4    # Multi-worker
uvicorn main:app --host 0.0.0.0 --port 8000 --reload        # Dev mode

# With SSL
uvicorn main:app --host 0.0.0.0 --port 443 \
  --ssl-keyfile=key.pem --ssl-certfile=cert.pem
```

### gunicorn (WSGI — Flask, Django + uvicorn workers)

```bash
# Install
pip install gunicorn

# Run Flask/Django
gunicorn --bind 0.0.0.0:8000 --workers 4 app:app          # Flask
gunicorn --bind 0.0.0.0:8000 --workers 4 myproject.wsgi    # Django

# Run with uvicorn workers (ASGI apps)
gunicorn main:app --bind 0.0.0.0:8000 \
  --workers 4 --worker-class uvicorn.workers.UvicornWorker

# Production settings
gunicorn app:app \
  --bind 0.0.0.0:8000 \
  --workers $(( $(nproc) * 2 + 1 )) \
  --timeout 120 \
  --access-logfile /var/log/gunicorn/access.log \
  --error-logfile /var/log/gunicorn/error.log \
  --capture-output \
  --enable-stdio-inheritance
```

## Systemd Service

### Example: FastAPI with uvicorn

```ini
# /etc/systemd/system/my-python-app.service
[Unit]
Description=My Python App (FastAPI)
After=network.target

[Service]
Type=simple
User=appuser
Group=appuser
WorkingDirectory=/opt/my-app
Environment=PATH=/opt/my-app/.venv/bin:/usr/bin
Environment=PYTHONUNBUFFERED=1
ExecStart=/opt/my-app/.venv/bin/uvicorn main:app --host 0.0.0.0 --port 8000 --workers 4
Restart=on-failure
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
```

### Example: Flask with gunicorn

```ini
# /etc/systemd/system/my-flask-app.service
[Unit]
Description=My Flask App (Gunicorn)
After=network.target

[Service]
Type=notify
User=appuser
Group=appuser
WorkingDirectory=/opt/my-flask-app
Environment=PATH=/opt/my-flask-app/.venv/bin:/usr/bin
ExecStart=/opt/my-flask-app/.venv/bin/gunicorn --bind 0.0.0.0:8000 --workers 4 app:app
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
```

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now my-python-app
sudo systemctl status my-python-app
sudo journalctl -u my-python-app -f
```

## Deployment Pattern

```bash
# 1. Clone and setup
cd /opt
sudo git clone https://github.com/user/my-app.git
sudo chown -R appuser:appuser my-app
cd my-app

# 2. Create venv and install
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt

# 3. Run migrations (if applicable)
python manage.py migrate      # Django
alembic upgrade head          # Alembic/SQLAlchemy

# 4. Start service
sudo systemctl enable --now my-python-app
```

## Troubleshooting

```bash
# "externally-managed-environment" error (Debian/Ubuntu 23.04+)
# Solution: use a venv!
python3 -m venv .venv && source .venv/bin/activate

# pip not found
python3 -m ensurepip --upgrade

# Module not found in systemd service
# Ensure the venv python is used in ExecStart, not system python

# Permission denied on port 80/443
# Use a reverse proxy (nginx) instead of binding directly

# Virtual env not activating in scripts
# Use full path: /opt/my-app/.venv/bin/python

# SSL certificate errors (corporate proxy)
pip install --trusted-host pypi.org --trusted-host pypi.python.org --trusted-host files.pythonhosted.org package_name

# Build fails — missing headers
sudo apt install -y python3-dev build-essential libffi-dev libssl-dev
```
