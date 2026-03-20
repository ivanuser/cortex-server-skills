# GitLab Runner — CI/CD Job Executor

> Install, register, and manage GitLab Runner for executing CI/CD pipelines. Covers Docker and Shell executors, configuration, caching, autoscaling, and troubleshooting.

## Safety Rules

- Don't use shared runners for sensitive builds — they can leak secrets between projects.
- Shell executor runs as the gitlab-runner user — limit its privileges.
- Docker executor: don't mount `/var/run/docker.sock` unless absolutely necessary (Docker-in-Docker).
- Registration tokens are sensitive — don't commit to repos.
- Limit concurrent jobs based on system resources.
- Clean up Docker images/volumes regularly — runners accumulate build artifacts.

## Quick Reference

```bash
# Install (Debian/Ubuntu)
curl -L "https://packages.gitlab.com/install/repositories/runner/gitlab-runner/script.deb.sh" | sudo bash
sudo apt install -y gitlab-runner

# Install (RHEL/Rocky)
curl -L "https://packages.gitlab.com/install/repositories/runner/gitlab-runner/script.rpm.sh" | sudo bash
sudo dnf install -y gitlab-runner

# Install (binary)
sudo curl -L --output /usr/local/bin/gitlab-runner \
  "https://gitlab-runner-downloads.s3.amazonaws.com/latest/binaries/gitlab-runner-linux-amd64"
sudo chmod +x /usr/local/bin/gitlab-runner
sudo useradd --comment 'GitLab Runner' --create-home gitlab-runner --shell /bin/bash
sudo gitlab-runner install --user=gitlab-runner --working-directory=/home/gitlab-runner

# Service management
sudo gitlab-runner start
sudo gitlab-runner stop
sudo gitlab-runner restart
sudo gitlab-runner status

# Check version
gitlab-runner --version

# List registered runners
sudo gitlab-runner list

# Verify runners can connect to GitLab
sudo gitlab-runner verify
```

## Registration

### Register Runner (Interactive)

```bash
sudo gitlab-runner register
# Enter GitLab URL: https://gitlab.example.com/
# Enter registration token: <from GitLab UI>
# Enter description: my-runner
# Enter tags: docker,linux
# Enter executor: docker
# Enter default Docker image: ubuntu:22.04
```

### Register Runner (Non-Interactive)

```bash
# Docker executor
sudo gitlab-runner register \
  --non-interactive \
  --url "https://gitlab.example.com/" \
  --registration-token "PROJECT_REGISTRATION_TOKEN" \
  --description "docker-runner" \
  --tag-list "docker,linux" \
  --executor "docker" \
  --docker-image "ubuntu:22.04" \
  --docker-privileged=false \
  --docker-volumes "/cache" \
  --run-untagged=true \
  --locked=false

# Shell executor
sudo gitlab-runner register \
  --non-interactive \
  --url "https://gitlab.example.com/" \
  --registration-token "PROJECT_REGISTRATION_TOKEN" \
  --description "shell-runner" \
  --tag-list "shell,build" \
  --executor "shell" \
  --run-untagged=false

# GitLab 16+ (runner authentication tokens)
sudo gitlab-runner register \
  --non-interactive \
  --url "https://gitlab.example.com/" \
  --token "glrt-XXXXXXXXXXXXXXXXXXXX" \
  --executor "docker" \
  --docker-image "node:20"
```

### Where to Find Registration Token

```
# Project runner: Settings → CI/CD → Runners → Expand
# Group runner: Group Settings → CI/CD → Runners
# Instance runner (admin): Admin → CI/CD → Runners
```

### Unregister Runner

```bash
sudo gitlab-runner unregister --name "docker-runner"
sudo gitlab-runner unregister --all-runners
```

## Configuration

### `/etc/gitlab-runner/config.toml`

```toml
concurrent = 4                         # Max concurrent jobs across all runners
check_interval = 3                     # Job check interval (seconds)
shutdown_timeout = 30

[session_server]
  listen_address = "[::]:8093"
  advertise_address = "runner.example.com:8093"

# Docker executor
[[runners]]
  name = "docker-runner"
  url = "https://gitlab.example.com/"
  token = "RUNNER_TOKEN"
  executor = "docker"
  limit = 2                            # Max concurrent jobs for THIS runner
  output_limit = 16384                 # Max job log size (KB)

  [runners.docker]
    image = "ubuntu:22.04"
    privileged = false
    disable_entrypoint_overwrite = false
    oom_kill_disable = false
    disable_cache = false
    volumes = ["/cache", "/var/run/docker.sock:/var/run/docker.sock"]
    shm_size = 0
    pull_policy = ["if-not-present"]
    memory = "2g"
    cpus = "2"
    allowed_images = ["ruby:*", "python:*", "node:*"]
    allowed_services = ["postgres:*", "redis:*"]

  [runners.cache]
    Type = "s3"
    Shared = true
    [runners.cache.s3]
      ServerAddress = "s3.amazonaws.com"
      BucketName = "gitlab-runner-cache"
      BucketLocation = "us-east-1"
      AccessKey = "AKIAIOSFODNN7EXAMPLE"
      SecretKey = "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY"

# Shell executor
[[runners]]
  name = "shell-runner"
  url = "https://gitlab.example.com/"
  token = "RUNNER_TOKEN_2"
  executor = "shell"
  limit = 1

  [runners.custom_build_dir]
    enabled = true

  environment = ["GIT_SSL_NO_VERIFY=1"]
```

## Docker Executor

### Docker-in-Docker (DinD)

```yaml
# .gitlab-ci.yml
build_image:
  image: docker:24
  services:
    - docker:24-dind
  variables:
    DOCKER_TLS_CERTDIR: "/certs"
  script:
    - docker build -t myapp:$CI_COMMIT_SHA .
    - docker push registry.example.com/myapp:$CI_COMMIT_SHA
  tags:
    - docker
```

### Docker Socket Binding (faster, less isolated)

```toml
# In config.toml
[runners.docker]
  volumes = ["/var/run/docker.sock:/var/run/docker.sock", "/cache"]
```

```yaml
# .gitlab-ci.yml
build:
  image: docker:24
  script:
    - docker build -t myapp .
  tags:
    - docker
```

## Shell Executor

```bash
# The shell executor runs commands directly on the host
# Install build dependencies on the runner machine:
sudo apt install -y build-essential nodejs npm python3 python3-pip docker.io

# Add gitlab-runner to docker group (if needed)
sudo usermod -aG docker gitlab-runner
sudo systemctl restart gitlab-runner
```

## Caching

### Local Cache

```yaml
# .gitlab-ci.yml
cache:
  key: ${CI_COMMIT_REF_SLUG}
  paths:
    - node_modules/
    - .npm/

install:
  script:
    - npm ci --cache .npm --prefer-offline
  cache:
    key:
      files:
        - package-lock.json
    paths:
      - node_modules/
```

### S3/GCS Cache

```toml
# config.toml
[runners.cache]
  Type = "s3"
  Shared = true
  [runners.cache.s3]
    ServerAddress = "s3.amazonaws.com"
    BucketName = "runner-cache"
    BucketLocation = "us-east-1"
    Insecure = false
```

### Cache Clearing

```bash
# Clear runner cache
sudo gitlab-runner cache-clear

# Or delete from S3/local filesystem
sudo rm -rf /home/gitlab-runner/cache/*
```

## Example `.gitlab-ci.yml`

```yaml
stages:
  - build
  - test
  - deploy

variables:
  NODE_ENV: production

# Cache node_modules across stages
cache:
  key:
    files:
      - package-lock.json
  paths:
    - node_modules/

build:
  stage: build
  image: node:20
  script:
    - npm ci
    - npm run build
  artifacts:
    paths:
      - dist/
    expire_in: 1 hour
  tags:
    - docker

test:
  stage: test
  image: node:20
  services:
    - postgres:15
  variables:
    POSTGRES_DB: test
    POSTGRES_USER: test
    POSTGRES_PASSWORD: test
    DATABASE_URL: "postgres://test:test@postgres:5432/test"
  script:
    - npm ci
    - npm test
  coverage: '/Statements\s*:\s*(\d+\.?\d*)%/'
  tags:
    - docker

deploy:
  stage: deploy
  image: alpine:latest
  script:
    - apk add --no-cache openssh-client rsync
    - rsync -avz dist/ deploy@server:/opt/app/
  only:
    - main
  when: manual
  environment:
    name: production
    url: https://app.example.com
  tags:
    - docker
```

## Monitoring

```bash
# Runner status
sudo gitlab-runner status
sudo gitlab-runner list
sudo gitlab-runner verify

# Check running jobs
sudo gitlab-runner --debug run          # Run in foreground with debug

# Logs
sudo journalctl -u gitlab-runner --no-pager -n 50
sudo journalctl -u gitlab-runner -f     # Follow

# Docker cleanup (if using Docker executor)
docker system prune -af --volumes       # ⚠ Removes ALL unused containers/images
docker system df                        # Check disk usage

# Prometheus metrics (enable in config.toml)
# listen_address = "0.0.0.0:9252"
# Metrics at: http://runner:9252/metrics
```

## Troubleshooting

```bash
# Runner not picking up jobs
sudo gitlab-runner verify              # Check registration
sudo gitlab-runner list                # Verify runner exists
# Check tags match between .gitlab-ci.yml and runner config
# Check runner is not paused in GitLab UI

# Docker executor: image pull fails
docker pull ubuntu:22.04               # Test manually
# Check Docker daemon: sudo systemctl status docker

# Permission denied errors (shell executor)
# Runner runs as gitlab-runner user — check file permissions
sudo -u gitlab-runner ls /path/to/files

# SSL certificate errors
# Add to config.toml under [[runners]]:
# tls-ca-file = "/etc/ssl/certs/ca-certificates.crt"
# Or set GIT_SSL_NO_VERIFY=1 in environment (not recommended)

# Job stuck / pending
# Check: Settings → CI/CD → Runners (is runner online?)
# Check: runner tags match job tags
# Check: concurrent limit not reached

# Build artifacts too large
# Set max artifact size in GitLab: Admin → Settings → CI/CD → Maximum artifacts size

# Docker: no space left on device
docker system prune -af --volumes
df -h /var/lib/docker

# Cache not working
sudo gitlab-runner cache-clear
# Verify cache config in config.toml
# Check S3 bucket permissions if using remote cache

# Reinstall / reset
sudo gitlab-runner unregister --all-runners
sudo apt remove --purge gitlab-runner
sudo rm -rf /etc/gitlab-runner /home/gitlab-runner
```
