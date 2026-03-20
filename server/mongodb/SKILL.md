# MongoDB — Document Database

> Install, configure, and manage MongoDB for document storage. Covers collections, indexes, replica sets, sharding, backup/restore, users, and security.

## Safety Rules

- **`db.dropDatabase()` is irreversible** — never run without confirmation and backup.
- Always enable authentication (`--auth`) in production.
- Never bind to `0.0.0.0` without firewall rules and auth enabled.
- Use `mongodump` before major schema changes or upgrades.
- Replica set operations can cause temporary unavailability — plan maintenance windows.
- Avoid `$regex` on unindexed fields — causes full collection scans.

## Quick Reference

```bash
# Install (Ubuntu 22.04/24.04 — MongoDB 7.x)
curl -fsSL https://www.mongodb.org/static/pgp/server-7.0.asc | \
  sudo gpg --dearmor -o /usr/share/keyrings/mongodb-server-7.0.gpg
echo "deb [signed-by=/usr/share/keyrings/mongodb-server-7.0.gpg] https://repo.mongodb.org/apt/ubuntu $(lsb_release -cs)/mongodb-org/7.0 multiverse" | \
  sudo tee /etc/apt/sources.list.d/mongodb-org-7.0.list
sudo apt update && sudo apt install -y mongodb-org

# Install (RHEL/Rocky 9)
cat <<'EOF' | sudo tee /etc/yum.repos.d/mongodb-org-7.0.repo
[mongodb-org-7.0]
name=MongoDB Repository
baseurl=https://repo.mongodb.org/yum/redhat/9/mongodb-org/7.0/x86_64/
gpgcheck=1
enabled=1
gpgkey=https://pgp.mongodb.com/server-7.0.asc
EOF
sudo dnf install -y mongodb-org

# Service management
sudo systemctl enable --now mongod
sudo systemctl status mongod
sudo systemctl restart mongod

# Connect
mongosh
mongosh "mongodb://localhost:27017"
mongosh "mongodb://user:pass@host:27017/dbname?authSource=admin"

# Quick check
mongosh --eval "db.runCommand({ ping: 1 })"
mongosh --eval "db.serverStatus().version"
```

## Configuration

### Essential `/etc/mongod.conf` settings

```yaml
# Network
net:
  port: 27017
  bindIp: 127.0.0.1                    # Add IPs or 0.0.0.0 for remote access

# Storage
storage:
  dbPath: /var/lib/mongodb
  journal:
    enabled: true
  wiredTiger:
    engineConfig:
      cacheSizeGB: 2                    # Default: 50% of RAM - 1GB

# Security
security:
  authorization: enabled                # Require authentication

# Logging
systemLog:
  destination: file
  path: /var/log/mongodb/mongod.log
  logAppend: true
  logRotate: reopen

# Replica set (uncomment for replication)
# replication:
#   replSetName: rs0
#   oplogSizeMB: 2048
```

## Database & Collection Operations

```javascript
// In mongosh:
show dbs                               // List databases
use myapp                              // Switch/create database
show collections                       // List collections
db.stats()                             // Database stats

// Create collection with options
db.createCollection("logs", {
  capped: true,
  size: 1073741824,                    // 1GB max
  max: 1000000                         // Max documents
})

// Insert documents
db.users.insertOne({ name: "Ivan", email: "ivan@example.com", age: 30 })
db.users.insertMany([
  { name: "Alice", email: "alice@example.com", age: 25 },
  { name: "Bob", email: "bob@example.com", age: 35 }
])

// Query
db.users.find()                        // All documents
db.users.find({ age: { $gte: 25 } })   // Filter
db.users.find({ name: /^I/ })          // Regex
db.users.findOne({ email: "ivan@example.com" })
db.users.find().sort({ age: -1 }).limit(10)
db.users.countDocuments({ age: { $gte: 25 } })

// Update
db.users.updateOne({ name: "Ivan" }, { $set: { age: 31 } })
db.users.updateMany({ age: { $lt: 30 } }, { $set: { group: "young" } })

// Delete
db.users.deleteOne({ name: "Bob" })
db.users.deleteMany({ age: { $lt: 18 } })

// Drop collection/database
db.users.drop()
db.dropDatabase()                      // ⚠ DESTRUCTIVE
```

## Indexes

```javascript
// List indexes
db.users.getIndexes()

// Create indexes
db.users.createIndex({ email: 1 })                    // Ascending
db.users.createIndex({ email: 1 }, { unique: true })  // Unique
db.users.createIndex({ name: 1, age: -1 })            // Compound
db.users.createIndex({ location: "2dsphere" })         // Geospatial
db.users.createIndex({ "$**": 1 })                     // Wildcard
db.logs.createIndex({ createdAt: 1 }, { expireAfterSeconds: 86400 }) // TTL — auto-delete after 24h

// Text search index
db.articles.createIndex({ title: "text", body: "text" })
db.articles.find({ $text: { $search: "mongodb tutorial" } })

// Explain query (check if index is used)
db.users.find({ email: "ivan@example.com" }).explain("executionStats")

// Drop index
db.users.dropIndex("email_1")
db.users.dropIndexes()                 // Drop all non-_id indexes
```

## Aggregation Pipeline

```javascript
db.orders.aggregate([
  { $match: { status: "completed" } },
  { $group: { _id: "$customerId", total: { $sum: "$amount" }, count: { $sum: 1 } } },
  { $sort: { total: -1 } },
  { $limit: 10 },
  { $lookup: { from: "customers", localField: "_id", foreignField: "_id", as: "customer" } },
  { $unwind: "$customer" },
  { $project: { customerName: "$customer.name", total: 1, count: 1 } }
])
```

## Users & Authentication

```javascript
// Connect without auth first, then create admin
use admin
db.createUser({
  user: "admin",
  pwd: "strong_password_here",
  roles: [{ role: "userAdminAnyDatabase", db: "admin" }, "readWriteAnyDatabase"]
})

// Create app-specific user
use myapp
db.createUser({
  user: "appuser",
  pwd: "app_password",
  roles: [{ role: "readWrite", db: "myapp" }]
})

// Read-only user
db.createUser({
  user: "reader",
  pwd: "reader_password",
  roles: [{ role: "read", db: "myapp" }]
})

// List users
use admin
db.getUsers()

// Change password
db.changeUserPassword("appuser", "new_password")

// Drop user
db.dropUser("appuser")
```

After creating admin, enable `authorization: enabled` in `/etc/mongod.conf` and restart.

## Replica Sets

```yaml
# /etc/mongod.conf on each node
replication:
  replSetName: rs0
net:
  bindIp: 0.0.0.0
  port: 27017
security:
  keyFile: /etc/mongodb/keyfile        # Shared auth key
```

```bash
# Generate keyfile (copy to all nodes)
openssl rand -base64 756 | sudo tee /etc/mongodb/keyfile
sudo chmod 400 /etc/mongodb/keyfile
sudo chown mongodb:mongodb /etc/mongodb/keyfile
```

```javascript
// On primary — initiate replica set
rs.initiate({
  _id: "rs0",
  members: [
    { _id: 0, host: "mongo1:27017", priority: 2 },
    { _id: 1, host: "mongo2:27017", priority: 1 },
    { _id: 2, host: "mongo3:27017", priority: 1 }
  ]
})

// Check status
rs.status()
rs.isMaster()
rs.conf()

// Add/remove members
rs.add("mongo4:27017")
rs.remove("mongo4:27017")

// Add arbiter (votes but doesn't store data)
rs.addArb("arbiter1:27017")

// Step down primary (trigger election)
rs.stepDown(60)                        // 60 seconds
```

## Backup & Restore

```bash
# Dump entire server
mongodump --out /backup/$(date +%Y%m%d)

# Dump specific database
mongodump --db myapp --out /backup/myapp_$(date +%Y%m%d)

# Dump specific collection
mongodump --db myapp --collection users --out /backup/

# Dump with auth
mongodump --uri="mongodb://admin:pass@localhost:27017" --authenticationDatabase=admin --out /backup/

# Dump as archive (single file)
mongodump --archive=/backup/full_$(date +%Y%m%d).gz --gzip

# Restore
mongorestore /backup/20260320/
mongorestore --db myapp /backup/myapp_20260320/myapp/
mongorestore --archive=/backup/full_20260320.gz --gzip

# Restore — drop existing data first
mongorestore --drop /backup/20260320/

# Export to JSON/CSV
mongoexport --db myapp --collection users --out users.json
mongoexport --db myapp --collection users --type=csv --fields=name,email --out users.csv

# Import
mongoimport --db myapp --collection users --file users.json
mongoimport --db myapp --collection users --type=csv --headerline --file users.csv
```

## Monitoring & Diagnostics

```javascript
// Server status
db.serverStatus()
db.serverStatus().connections          // Connection count
db.serverStatus().opcounters           // Operation counts
db.serverStatus().mem                  // Memory usage

// Current operations
db.currentOp()
db.currentOp({ "secs_running": { $gte: 5 } })  // Slow queries

// Kill an operation
db.killOp(<opid>)

// Collection stats
db.users.stats()
db.users.totalSize()                   // Data + indexes in bytes
db.users.storageSize()
db.users.totalIndexSize()

// Profiler (log slow queries)
db.setProfilingLevel(1, { slowms: 100 })   // Log queries > 100ms
db.system.profile.find().sort({ ts: -1 }).limit(5)
db.setProfilingLevel(0)                     // Disable profiler
```

```bash
# Quick stats from CLI
mongosh --eval "db.serverStatus().connections"
mongosh --eval "db.stats()"

# Log file
sudo tail -100 /var/log/mongodb/mongod.log
sudo grep -i "slow query" /var/log/mongodb/mongod.log
```

## Troubleshooting

```bash
# MongoDB won't start
sudo journalctl -u mongod --no-pager -n 50
sudo cat /var/log/mongodb/mongod.log | tail -50

# Check data directory permissions
ls -la /var/lib/mongodb/
sudo chown -R mongodb:mongodb /var/lib/mongodb

# Lock file issue after crash
sudo rm /var/lib/mongodb/mongod.lock
mongod --repair --dbpath /var/lib/mongodb   # ⚠ Run as mongodb user

# Connection refused
sudo ss -tlnp | grep 27017
grep "bindIp" /etc/mongod.conf

# High memory usage (WiredTiger cache)
# Set cacheSizeGB in mongod.conf — default is (RAM - 1GB) / 2

# Disk space
df -h /var/lib/mongodb
mongosh --eval 'db.adminCommand({ listDatabases: 1 }).databases.forEach(d => print(d.name + ": " + (d.sizeOnDisk / 1024 / 1024).toFixed(2) + " MB"))'

# Compact collection (reclaim disk space after deletes)
db.runCommand({ compact: "users" })
```
