# HAProxy — High Availability Load Balancer

> Install, configure, and manage HAProxy for TCP/HTTP load balancing, SSL termination, health checks, and traffic management. Covers frontend/backend config, algorithms, ACLs, stats page, and rate limiting.

## Safety Rules

- Always validate config before reload: `haproxy -c -f /etc/haproxy/haproxy.cfg`.
- Use `reload` (not `restart`) to avoid dropping connections.
- Don't expose the stats page without authentication.
- SSL private keys must have restricted permissions (`chmod 600`).
- Test backend health checks in staging — aggressive checks can overload backends.
- `maxconn` limits protect backends from overload — tune carefully.

## Quick Reference

```bash
# Install (Debian/Ubuntu — latest stable)
sudo apt install -y haproxy

# Install latest LTS from PPA
sudo add-apt-repository -y ppa:vbernat/haproxy-2.8
sudo apt update && sudo apt install -y haproxy

# Install (RHEL/Rocky)
sudo dnf install -y haproxy

# Service management
sudo systemctl enable --now haproxy
sudo systemctl status haproxy
sudo systemctl reload haproxy          # Graceful — no dropped connections
sudo systemctl restart haproxy

# Validate config
haproxy -c -f /etc/haproxy/haproxy.cfg

# Version
haproxy -v
haproxy -vv                            # Verbose — build options, OpenSSL version
```

## Configuration Structure

Config file: `/etc/haproxy/haproxy.cfg`

```
global
    log /dev/log local0
    log /dev/log local1 notice
    chroot /var/lib/haproxy
    stats socket /run/haproxy/admin.sock mode 660 level admin
    stats timeout 30s
    user haproxy
    group haproxy
    daemon

    # SSL tuning
    ssl-default-bind-ciphersuites TLS_AES_128_GCM_SHA256:TLS_AES_256_GCM_SHA384:TLS_CHACHA20_POLY1305_SHA256
    ssl-default-bind-options ssl-min-ver TLSv1.2 no-tls-tickets
    tune.ssl.default-dh-param 2048
    maxconn 50000

defaults
    log     global
    mode    http
    option  httplog
    option  dontlognull
    option  forwardfor
    option  http-server-close
    timeout connect 5s
    timeout client  30s
    timeout server  30s
    timeout http-request 10s
    timeout http-keep-alive 10s
    timeout queue 60s
    errorfile 400 /etc/haproxy/errors/400.http
    errorfile 403 /etc/haproxy/errors/403.http
    errorfile 500 /etc/haproxy/errors/500.http
    errorfile 502 /etc/haproxy/errors/502.http
    errorfile 503 /etc/haproxy/errors/503.http
    errorfile 504 /etc/haproxy/errors/504.http
```

## Frontend & Backend

### Basic HTTP Load Balancer

```
frontend http_front
    bind *:80
    default_backend app_servers

backend app_servers
    balance roundrobin
    option httpchk GET /health
    http-check expect status 200

    server app1 10.0.0.1:3000 check inter 5s fall 3 rise 2
    server app2 10.0.0.2:3000 check inter 5s fall 3 rise 2
    server app3 10.0.0.3:3000 check inter 5s fall 3 rise 2
```

### HTTPS with SSL Termination

```
frontend https_front
    bind *:443 ssl crt /etc/haproxy/certs/combined.pem
    bind *:80
    http-request redirect scheme https unless { ssl_fc }

    # Route based on hostname
    acl is_api hdr(host) -i api.example.com
    acl is_app hdr(host) -i app.example.com

    use_backend api_servers if is_api
    use_backend app_servers if is_app
    default_backend app_servers

backend api_servers
    balance leastconn
    option httpchk GET /health
    server api1 10.0.0.10:8080 check
    server api2 10.0.0.11:8080 check

backend app_servers
    balance roundrobin
    cookie SERVERID insert indirect nocache
    server app1 10.0.0.1:3000 check cookie s1
    server app2 10.0.0.2:3000 check cookie s2
```

```bash
# Create combined PEM (cert + key)
cat /etc/letsencrypt/live/example.com/fullchain.pem \
    /etc/letsencrypt/live/example.com/privkey.pem \
    > /etc/haproxy/certs/combined.pem
chmod 600 /etc/haproxy/certs/combined.pem
```

## Load Balancing Algorithms

```
backend app_servers
    # Round Robin (default) — equal distribution
    balance roundrobin

    # Least Connections — send to server with fewest active connections
    balance leastconn

    # Source IP hash — same client always hits same server (sticky)
    balance source

    # URI hash — same URI always hits same server (good for caching)
    balance uri

    # Random — random server selection
    balance random

    # First — fill first server before using next (minimize active servers)
    balance first

    # Weighted — servers get proportional traffic
    server app1 10.0.0.1:3000 weight 3 check     # Gets 3x traffic
    server app2 10.0.0.2:3000 weight 1 check     # Gets 1x traffic
```

## Health Checks

```
backend app_servers
    # HTTP health check
    option httpchk GET /health
    http-check expect status 200

    # Custom health check with headers
    option httpchk
    http-check send meth GET uri /health hdr Host example.com
    http-check expect string "ok"

    # TCP health check (just check port is open)
    option tcp-check

    # Check timing: interval, fall (failures to mark down), rise (successes to mark up)
    server app1 10.0.0.1:3000 check inter 5s fall 3 rise 2

    # Backup server (only used when all primary servers are down)
    server backup1 10.0.0.99:3000 check backup
```

## ACLs & Routing

```
frontend http_front
    bind *:80

    # Host-based routing
    acl is_api hdr(host) -i api.example.com
    acl is_static hdr(host) -i static.example.com

    # Path-based routing
    acl is_api_path path_beg /api/
    acl is_static_path path_beg /static/
    acl is_websocket hdr(Upgrade) -i WebSocket

    # IP-based
    acl is_internal src 10.0.0.0/8 192.168.0.0/16

    # Method-based
    acl is_post method POST

    # Rate limiting
    acl is_rate_limited sc_http_req_rate(0) gt 100
    http-request deny if is_rate_limited

    # Routing rules
    use_backend api_servers if is_api || is_api_path
    use_backend static_servers if is_static || is_static_path
    use_backend ws_servers if is_websocket
    default_backend app_servers

    # Block unless internal
    http-request deny unless is_internal
```

## Stats Page

```
# Dedicated stats frontend
listen stats
    bind *:8404
    mode http
    stats enable
    stats uri /stats
    stats refresh 10s
    stats show-legends
    stats show-node
    stats auth admin:strong_password   # Basic auth

    # Admin mode (enable/disable servers from UI)
    stats admin if TRUE

# Or embed in existing frontend
frontend http_front
    bind *:80
    stats enable
    stats uri /haproxy-stats
    stats auth admin:password
    acl is_stats path_beg /haproxy-stats
    acl is_internal src 10.0.0.0/8
    http-request deny if is_stats !is_internal
```

Access at: `http://your-server:8404/stats`

## TCP Mode (Layer 4)

```
# Database load balancing
frontend mysql_front
    mode tcp
    bind *:3306
    default_backend mysql_servers

backend mysql_servers
    mode tcp
    balance leastconn
    option mysql-check user haproxy
    server db1 10.0.0.20:3306 check
    server db2 10.0.0.21:3306 check backup

# SSH load balancing
frontend ssh_front
    mode tcp
    bind *:2222
    default_backend ssh_servers

backend ssh_servers
    mode tcp
    balance source
    server ssh1 10.0.0.1:22 check
    server ssh2 10.0.0.2:22 check
```

## Rate Limiting & Connection Limits

```
frontend http_front
    bind *:80

    # Stick table for rate tracking
    stick-table type ip size 200k expire 5m store http_req_rate(10s),conn_cur

    # Track client IP
    http-request track-sc0 src

    # Deny if >100 requests per 10 seconds
    http-request deny deny_status 429 if { sc_http_req_rate(0) gt 100 }

    # Deny if >50 concurrent connections
    http-request deny deny_status 429 if { sc_conn_cur(0) gt 50 }

    default_backend app_servers

backend app_servers
    balance roundrobin
    # Limit connections per server
    server app1 10.0.0.1:3000 check maxconn 200
    server app2 10.0.0.2:3000 check maxconn 200
```

## Runtime Management

```bash
# HAProxy socket commands (via socat)
echo "show stat" | sudo socat stdio /run/haproxy/admin.sock
echo "show info" | sudo socat stdio /run/haproxy/admin.sock

# Disable/enable server
echo "disable server app_servers/app1" | sudo socat stdio /run/haproxy/admin.sock
echo "enable server app_servers/app1" | sudo socat stdio /run/haproxy/admin.sock

# Set server to drain mode (finish existing connections, no new ones)
echo "set server app_servers/app1 state drain" | sudo socat stdio /run/haproxy/admin.sock

# Set weight dynamically
echo "set weight app_servers/app1 50%" | sudo socat stdio /run/haproxy/admin.sock

# Show server state
echo "show servers state" | sudo socat stdio /run/haproxy/admin.sock

# Show active sessions
echo "show sess" | sudo socat stdio /run/haproxy/admin.sock

# Clear counters
echo "clear counters all" | sudo socat stdio /run/haproxy/admin.sock
```

## Logging

```
# In global section — log to rsyslog
global
    log /dev/log local0 info
    log /dev/log local1 notice

# rsyslog config: /etc/rsyslog.d/49-haproxy.conf
# local0.* /var/log/haproxy/haproxy.log
# local1.notice /var/log/haproxy/haproxy-admin.log

# Custom log format
frontend http_front
    log-format "%ci:%cp [%tr] %ft %b/%s %TR/%Tw/%Tc/%Tr/%Ta %ST %B %CC %CS %tsc %ac/%fc/%bc/%sc/%rc %sq/%bq %hr %hs %{+Q}r"
```

```bash
# Create log directory
sudo mkdir -p /var/log/haproxy
sudo systemctl restart rsyslog

# View logs
sudo tail -f /var/log/haproxy/haproxy.log
```

## Troubleshooting

```bash
# Config syntax check
haproxy -c -f /etc/haproxy/haproxy.cfg

# HAProxy won't start
sudo journalctl -u haproxy --no-pager -n 50
haproxy -c -f /etc/haproxy/haproxy.cfg  # Check for errors

# Port already in use
sudo ss -tlnp | grep -E ':80|:443'

# Backend servers showing DOWN
echo "show stat" | sudo socat stdio /run/haproxy/admin.sock | \
  awk -F',' '{printf "%-20s %-15s %-10s\n", $1, $2, $18}'

# Connection refused to backend
curl -v http://10.0.0.1:3000/health    # Test backend directly

# SSL issues
openssl s_client -connect localhost:443 -servername example.com
# Verify PEM has cert + key:
openssl x509 -in /etc/haproxy/certs/combined.pem -noout -text | head -5
openssl rsa -in /etc/haproxy/certs/combined.pem -check -noout

# High connection count
echo "show info" | sudo socat stdio /run/haproxy/admin.sock | grep -i conn

# 503 errors — all backends down
echo "show stat" | sudo socat stdio /run/haproxy/admin.sock | grep -v "^#" | \
  awk -F',' '$18 == "DOWN" {print $1 "/" $2}'
```
