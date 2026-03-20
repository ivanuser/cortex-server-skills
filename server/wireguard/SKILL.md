# WireGuard — Modern VPN

> Install, configure, and manage WireGuard for fast, secure VPN tunnels. Covers key generation, server/client setup, peer configuration, DNS, kill switch, and multi-site networking.

## Safety Rules

- **Private keys must never be shared** — regenerate if compromised.
- Keep private key files readable only by root (`chmod 600`).
- Always use `SaveConfig = false` or understand that `wg-quick down` overwrites the config.
- Firewall the WireGuard port (default 51820/UDP) — allow only from expected peers.
- WireGuard doesn't hide that it's running — the port responds to all valid packets.
- Test connectivity before enabling kill switch — or you'll lock yourself out of SSH.

## Quick Reference

```bash
# Install (Ubuntu/Debian)
sudo apt update && sudo apt install -y wireguard wireguard-tools

# Install (RHEL/Rocky)
sudo dnf install -y wireguard-tools

# Check if kernel module is loaded
sudo modprobe wireguard
lsmod | grep wireguard

# Enable IP forwarding (required for server/gateway role)
echo "net.ipv4.ip_forward = 1" | sudo tee -a /etc/sysctl.d/99-wireguard.conf
echo "net.ipv6.conf.all.forwarding = 1" | sudo tee -a /etc/sysctl.d/99-wireguard.conf
sudo sysctl -p /etc/sysctl.d/99-wireguard.conf

# Quick status
sudo wg show
sudo wg show wg0
```

## Key Generation

```bash
# Generate private key
wg genkey | sudo tee /etc/wireguard/private.key
sudo chmod 600 /etc/wireguard/private.key

# Derive public key from private key
sudo cat /etc/wireguard/private.key | wg pubkey | sudo tee /etc/wireguard/public.key

# Generate both in one line
wg genkey | tee privatekey | wg pubkey > publickey

# Generate preshared key (optional — additional layer of security)
wg genpsk | sudo tee /etc/wireguard/preshared.key
sudo chmod 600 /etc/wireguard/preshared.key
```

## Server Setup

### Server config: `/etc/wireguard/wg0.conf`

```ini
[Interface]
# Server's private key
PrivateKey = <SERVER_PRIVATE_KEY>
Address = 10.0.0.1/24, fd00::1/64
ListenPort = 51820
# SaveConfig = false

# NAT / masquerade (for internet access through VPN)
PostUp = iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
PostUp = ip6tables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
PostDown = iptables -t nat -D POSTROUTING -o eth0 -j MASQUERADE
PostDown = ip6tables -t nat -D POSTROUTING -o eth0 -j MASQUERADE

# DNS (optional — push to clients via AllowedIPs)
DNS = 1.1.1.1, 8.8.8.8

[Peer]
# Client 1
PublicKey = <CLIENT1_PUBLIC_KEY>
PresharedKey = <PRESHARED_KEY>
AllowedIPs = 10.0.0.2/32, fd00::2/128

[Peer]
# Client 2
PublicKey = <CLIENT2_PUBLIC_KEY>
AllowedIPs = 10.0.0.3/32, fd00::3/128
```

```bash
# Start WireGuard interface
sudo wg-quick up wg0

# Enable on boot
sudo systemctl enable wg-quick@wg0

# Stop
sudo wg-quick down wg0

# Restart (after config changes)
sudo wg-quick down wg0 && sudo wg-quick up wg0
# Or: sudo systemctl restart wg-quick@wg0

# Firewall — allow WireGuard port
sudo ufw allow 51820/udp
# Or with iptables:
sudo iptables -A INPUT -p udp --dport 51820 -j ACCEPT
```

## Client Setup

### Client config: `/etc/wireguard/wg0.conf`

```ini
[Interface]
PrivateKey = <CLIENT_PRIVATE_KEY>
Address = 10.0.0.2/24, fd00::2/64
DNS = 1.1.1.1, 8.8.8.8

[Peer]
PublicKey = <SERVER_PUBLIC_KEY>
PresharedKey = <PRESHARED_KEY>
Endpoint = server.example.com:51820
AllowedIPs = 0.0.0.0/0, ::/0          # Route ALL traffic through VPN
# AllowedIPs = 10.0.0.0/24            # Only route VPN subnet (split tunnel)
PersistentKeepalive = 25              # Keep NAT mappings alive (seconds)
```

```bash
# Start client
sudo wg-quick up wg0

# Verify connection
sudo wg show wg0
ping 10.0.0.1                         # Ping server's VPN IP
curl ifconfig.me                       # Should show server's public IP
```

## Adding Peers Dynamically

```bash
# Add peer without editing config file
sudo wg set wg0 peer <CLIENT_PUBLIC_KEY> \
  allowed-ips 10.0.0.4/32 \
  preshared-key /etc/wireguard/preshared.key

# Remove peer
sudo wg set wg0 peer <CLIENT_PUBLIC_KEY> remove

# Save current runtime config to file
sudo wg-quick save wg0
```

## Split Tunneling

```ini
# Client config — only route specific networks through VPN

[Peer]
PublicKey = <SERVER_PUBLIC_KEY>
Endpoint = server.example.com:51820

# Only VPN subnet + internal network
AllowedIPs = 10.0.0.0/24, 192.168.1.0/24

# Everything EXCEPT local network through VPN
# AllowedIPs = 0.0.0.0/1, 128.0.0.0/1   # Covers all IPs except default route
```

## Kill Switch

### Method 1: iptables rules (in wg0.conf)

```ini
[Interface]
PrivateKey = <CLIENT_PRIVATE_KEY>
Address = 10.0.0.2/24
DNS = 1.1.1.1

# Kill switch — block all non-WireGuard traffic
PostUp = iptables -I OUTPUT ! -o wg0 -m mark ! --mark $(wg show wg0 fwmark) -m addrtype ! --dst-type LOCAL -j REJECT
PostUp = ip6tables -I OUTPUT ! -o wg0 -m mark ! --mark $(wg show wg0 fwmark) -m addrtype ! --dst-type LOCAL -j REJECT
PreDown = iptables -D OUTPUT ! -o wg0 -m mark ! --mark $(wg show wg0 fwmark) -m addrtype ! --dst-type LOCAL -j REJECT
PreDown = ip6tables -D OUTPUT ! -o wg0 -m mark ! --mark $(wg show wg0 fwmark) -m addrtype ! --dst-type LOCAL -j REJECT

[Peer]
PublicKey = <SERVER_PUBLIC_KEY>
Endpoint = server.example.com:51820
AllowedIPs = 0.0.0.0/0, ::/0
PersistentKeepalive = 25
```

### Method 2: UFW-based kill switch

```bash
# Allow only WireGuard traffic
sudo ufw default deny outgoing
sudo ufw default deny incoming
sudo ufw allow in on wg0
sudo ufw allow out on wg0
sudo ufw allow out to <SERVER_PUBLIC_IP> port 51820 proto udp
sudo ufw allow out to any port 53 proto udp   # DNS
sudo ufw enable
```

## Site-to-Site VPN

```
# Site A (10.1.0.0/24) ←→ Site B (10.2.0.0/24)

# Site A server — /etc/wireguard/wg0.conf
[Interface]
PrivateKey = <SITE_A_PRIVATE_KEY>
Address = 10.0.0.1/24
ListenPort = 51820
PostUp = iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
PostDown = iptables -t nat -D POSTROUTING -o eth0 -j MASQUERADE

[Peer]
PublicKey = <SITE_B_PUBLIC_KEY>
Endpoint = siteb.example.com:51820
AllowedIPs = 10.0.0.2/32, 10.2.0.0/24    # VPN IP + remote LAN
PersistentKeepalive = 25

# Site B server — /etc/wireguard/wg0.conf
[Interface]
PrivateKey = <SITE_B_PRIVATE_KEY>
Address = 10.0.0.2/24
ListenPort = 51820
PostUp = iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
PostDown = iptables -t nat -D POSTROUTING -o eth0 -j MASQUERADE

[Peer]
PublicKey = <SITE_A_PUBLIC_KEY>
Endpoint = sitea.example.com:51820
AllowedIPs = 10.0.0.1/32, 10.1.0.0/24    # VPN IP + remote LAN
PersistentKeepalive = 25
```

## DNS Configuration

### Using systemd-resolved

```ini
# In client wg0.conf
[Interface]
DNS = 10.0.0.1                        # Use VPN server as DNS

# Or use PostUp/PostDown for manual control
PostUp = resolvectl dns %i 10.0.0.1; resolvectl domain %i "~."
PostDown = resolvectl revert %i
```

### Running DNS on WireGuard server

```bash
# Install unbound (lightweight recursive DNS)
sudo apt install -y unbound

# /etc/unbound/unbound.conf.d/wireguard.conf
# server:
#     interface: 10.0.0.1
#     access-control: 10.0.0.0/24 allow
#     do-ip6: no
```

## Monitoring & Management

```bash
# Show all interfaces
sudo wg show

# Detailed interface info
sudo wg show wg0

# Per-peer stats (transfer, last handshake)
sudo wg show wg0 dump

# Key output fields:
# latest handshake — if >2 min ago, peer may be offline
# transfer — received/sent bytes
# allowed ips — configured routes

# Check interface is up
ip a show wg0
ip route | grep wg0

# Monitor in real-time
watch -n 2 sudo wg show wg0

# Generate QR code for mobile clients
sudo apt install -y qrencode
sudo cat /etc/wireguard/client-mobile.conf | qrencode -t ansiutf8
# Or save as image:
sudo cat /etc/wireguard/client-mobile.conf | qrencode -o client-mobile.png
```

## Troubleshooting

```bash
# No handshake / can't connect
# 1. Check server is listening
sudo ss -ulnp | grep 51820

# 2. Check firewall
sudo iptables -L -n | grep 51820
sudo ufw status | grep 51820

# 3. Check keys match (server has client's PUBLIC key, client has server's PUBLIC key)
sudo wg show wg0

# 4. Check endpoint is reachable
nc -zuv server.example.com 51820

# Handshake happens but no traffic
# Check AllowedIPs — must include destination network
# Check IP forwarding: sysctl net.ipv4.ip_forward (must be 1)
# Check NAT/masquerade rules

# DNS not working through VPN
resolvectl status wg0
# Ensure DNS is set in [Interface] section

# Slow performance
# Check MTU — WireGuard default is 1420
# Lower if encapsulated: MTU = 1420 - overhead
# [Interface]
# MTU = 1380

# Can't reach LAN behind VPN peer
# Ensure AllowedIPs includes the remote LAN subnet
# Ensure IP forwarding is enabled on the gateway peer
# Check routing: ip route get 10.2.0.1

# Peer shows as connected but times out
sudo wg show wg0
# Look at "latest handshake" — if recent, tunnel is up
# Check AllowedIPs on BOTH sides

# Debug logging
echo "module wireguard +p" | sudo tee /sys/kernel/debug/dynamic_debug/control
sudo dmesg -w | grep wireguard
# Disable: echo "module wireguard -p" | sudo tee /sys/kernel/debug/dynamic_debug/control
```
