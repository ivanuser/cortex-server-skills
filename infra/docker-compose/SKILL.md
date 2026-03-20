# Docker Compose — Multi-Container Applications

> Install, configure, and manage Docker Compose for defining and running multi-container applications. Covers compose files, networking, volumes, profiles, override files, and common patterns.

## Safety Rules

- **`docker compose down -v` deletes volumes** — data loss if volumes contain databases.
- Always review `docker compose config` before applying changes.
- Don't store secrets in compose files — use Docker secrets or environment files.
- Named volumes persist across `down`/`up` — anonymous volumes don't.
- Port mappings expose services to the host network — use `127.0.0.1:port:port` to restrict.
- `docker compose pull` before deploying to ensure latest images.

## Quick Reference

```bash
# Install (Docker Compose v2 — plugin, recommended)
# Comes with Docker Desktop, or install separately:
sudo apt install -y docker-compose-plugin

# Or standalone binary
COMPOSE_VERSION="v2.29.0"
sudo curl -L "https://github.com/docker/compose/releases/download/${COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# Version check
docker compose version

# Core commands
docker compose up -d                   # Start in background
docker compose down                    # Stop and remove containers
docker compose ps                      # List containers
docker compose logs                    # View logs
docker compose logs -f app             # Follow specific service logs
docker compose restart                 # Restart all services
docker compose stop                    # Stop without removing
docker compose start                   # Start stopped containers
docker compose build                   # Build/rebuild images
docker compose pull                    # Pull latest images
docker compose exec app bash           # Execute command in running container
docker compose run --rm app npm test   # Run one-off command
docker compose config                  # Validate and view resolved config
docker compose top                     # Show running processes
```

## Compose File Basics

### `docker-compose.yml` (or `compose.yml`)

```yaml
version: "3.9"                         # Optional in Compose v2

services:
  app:
    image: node:20-alpine
    container_name: myapp
    working_dir: /app
    volumes:
      - ./src:/app
      - node_modules:/app/node_modules
    ports:
      - "3000:3000"
    environment:
      NODE_ENV: production
      DATABASE_URL: postgres://app:secret@db:5432/myapp
    depends_on:
      db:
        condition: service_healthy
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:3000/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s

  db:
    image: postgres:16-alpine
    container_name: myapp-db
    volumes:
      - pgdata:/var/lib/postgresql/data
      - ./init.sql:/docker-entrypoint-initdb.d/init.sql
    environment:
      POSTGRES_DB: myapp
      POSTGRES_USER: app
      POSTGRES_PASSWORD: secret
    ports:
      - "127.0.0.1:5432:5432"         # Localhost only
    restart: unless-stopped
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U app -d myapp"]
      interval: 10s
      timeout: 5s
      retries: 5

  redis:
    image: redis:7-alpine
    container_name: myapp-redis
    command: redis-server --requirepass secret
    volumes:
      - redisdata:/data
    ports:
      - "127.0.0.1:6379:6379"
    restart: unless-stopped

volumes:
  pgdata:
  redisdata:
  node_modules:
```

## Build Configuration

```yaml
services:
  app:
    build:
      context: .
      dockerfile: Dockerfile
      args:
        NODE_VERSION: "20"
        BUILD_ENV: production
      target: production                # Multi-stage build target
      cache_from:
        - myapp:latest
    image: myapp:latest                 # Tag the built image

  # Simple build (Dockerfile in current dir)
  simple:
    build: .
```

## Networking

```yaml
services:
  frontend:
    image: nginx:alpine
    networks:
      - frontend
    ports:
      - "80:80"

  app:
    image: myapp
    networks:
      - frontend
      - backend

  db:
    image: postgres:16
    networks:
      - backend

networks:
  frontend:
    driver: bridge
  backend:
    driver: bridge
    internal: true                     # No external access

  # Use existing network
  external_net:
    external: true
    name: my-existing-network

  # Custom subnet
  custom:
    driver: bridge
    ipam:
      config:
        - subnet: 172.28.0.0/16
```

## Volumes

```yaml
services:
  db:
    volumes:
      # Named volume
      - pgdata:/var/lib/postgresql/data

      # Bind mount (host path)
      - ./data:/app/data

      # Read-only bind mount
      - ./config/nginx.conf:/etc/nginx/nginx.conf:ro

      # tmpfs (in-memory)
      - type: tmpfs
        target: /tmp
        tmpfs:
          size: 100000000              # 100MB

volumes:
  pgdata:
    driver: local

  # Named volume with driver options (NFS)
  nfs_data:
    driver: local
    driver_opts:
      type: nfs
      o: addr=10.0.0.1,nolock,soft,rw
      device: ":/path/to/share"

  # External volume (pre-existing)
  existing:
    external: true
    name: my-volume
```

## Environment Variables

```yaml
services:
  app:
    # Inline
    environment:
      NODE_ENV: production
      API_KEY: ${API_KEY}              # From shell environment
      DB_HOST: db

    # From file
    env_file:
      - .env
      - .env.production

    # Both (inline overrides file)
    env_file: .env
    environment:
      NODE_ENV: production
```

```bash
# .env file (in same directory as compose file)
POSTGRES_PASSWORD=secret
API_KEY=abc123
APP_PORT=3000

# .env is loaded automatically by docker compose
# Use ${VAR} or ${VAR:-default} in compose file
```

## Profiles

```yaml
services:
  app:
    image: myapp
    # No profile — always starts

  db:
    image: postgres:16
    # No profile — always starts

  debug:
    image: myapp-debug
    profiles:
      - debug

  monitoring:
    image: prometheus
    profiles:
      - monitoring

  grafana:
    image: grafana/grafana
    profiles:
      - monitoring
```

```bash
# Start default services only
docker compose up -d

# Start with specific profile
docker compose --profile monitoring up -d

# Multiple profiles
docker compose --profile debug --profile monitoring up -d
```

## Override Files

```yaml
# docker-compose.yml (base)
services:
  app:
    image: myapp:latest
    ports:
      - "3000:3000"
    environment:
      NODE_ENV: production

# docker-compose.override.yml (auto-loaded for dev)
services:
  app:
    build: .
    volumes:
      - ./src:/app/src
    environment:
      NODE_ENV: development
      DEBUG: "true"
    ports:
      - "9229:9229"                    # Debug port

# docker-compose.prod.yml (explicit production)
services:
  app:
    image: registry.example.com/myapp:${TAG:-latest}
    deploy:
      replicas: 3
      resources:
        limits:
          memory: 512M
          cpus: "0.5"
    restart: always
```

```bash
# Dev (uses base + override automatically)
docker compose up -d

# Production (explicit files)
docker compose -f docker-compose.yml -f docker-compose.prod.yml up -d

# Skip override file
docker compose -f docker-compose.yml up -d
```

## Common Patterns

### Web App + Database + Cache

```yaml
services:
  nginx:
    image: nginx:alpine
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf:ro
      - ./certs:/etc/nginx/certs:ro
    depends_on:
      - app

  app:
    build: .
    expose:
      - "3000"                         # Internal only (no host mapping)
    environment:
      DATABASE_URL: postgres://app:secret@db:5432/myapp
      REDIS_URL: redis://:secret@redis:6379
    depends_on:
      db:
        condition: service_healthy
      redis:
        condition: service_started

  worker:
    build: .
    command: npm run worker
    environment:
      DATABASE_URL: postgres://app:secret@db:5432/myapp
      REDIS_URL: redis://:secret@redis:6379
    depends_on:
      - db
      - redis

  db:
    image: postgres:16-alpine
    volumes:
      - pgdata:/var/lib/postgresql/data
    environment:
      POSTGRES_DB: myapp
      POSTGRES_USER: app
      POSTGRES_PASSWORD: secret
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U app"]
      interval: 5s
      timeout: 5s
      retries: 5

  redis:
    image: redis:7-alpine
    command: redis-server --requirepass secret
    volumes:
      - redisdata:/data

volumes:
  pgdata:
  redisdata:
```

## Resource Limits

```yaml
services:
  app:
    deploy:
      resources:
        limits:
          cpus: "1.0"
          memory: 512M
        reservations:
          cpus: "0.25"
          memory: 128M
    # Logging limits
    logging:
      driver: json-file
      options:
        max-size: "10m"
        max-file: "3"
```

## Troubleshooting

```bash
# Validate compose file
docker compose config

# View resolved config (with env vars interpolated)
docker compose config --resolve-image-digests

# Container not starting
docker compose logs app                # Check logs
docker compose ps -a                   # Show all containers (including stopped)

# Service can't reach another service
docker compose exec app ping db        # Test connectivity
docker compose exec app nslookup db    # DNS resolution
# Services reach each other by service name within the same network

# Port already in use
docker compose down
sudo ss -tlnp | grep :3000

# Volume permissions
docker compose exec app ls -la /app/data
docker compose exec --user root app chown -R node:node /app/data

# Rebuild after code/Dockerfile changes
docker compose build --no-cache app
docker compose up -d --force-recreate app

# Remove everything (containers + networks + volumes)
docker compose down -v --remove-orphans

# Orphaned containers from old compose files
docker compose down --remove-orphans

# Disk space
docker system df
docker system prune -af --volumes      # ⚠ Removes ALL unused data
docker volume prune                    # Remove unused volumes only

# Slow builds — use BuildKit
DOCKER_BUILDKIT=1 docker compose build
```
