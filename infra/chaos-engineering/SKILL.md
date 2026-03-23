# Chaos Engineering — Controlled Failure Validation

> Inject controlled faults to verify recovery, alerting, and resilience behavior before real incidents happen.

## Safety Rules

- Run chaos only on approved non-critical targets first.
- Define blast radius, duration, and rollback before starting.
- Ensure observability and alerting are active during experiments.
- Never run overlapping chaos experiments on the same critical dependency.
- Abort immediately if SLO/error budget thresholds are breached.

## Quick Reference

```bash
# Kill one worker process (example)
pkill -f -n "node worker.js"

# Inject latency/loss (temporary)
sudo tc qdisc add dev eth0 root netem delay 500ms loss 10%

# Remove netem rules
sudo tc qdisc del dev eth0 root

# Verify supervisor recovery
pm2 status
systemctl status myapp
```

## Experiment Template

- Hypothesis: what should recover automatically.
- Scope: which service/node.
- Fault: what failure is injected.
- Success criteria: restart time, error budget hit, data integrity.
- Rollback: exact command and owner.

## Process Assassination

```bash
# Kill a single non-critical worker
PID=$(pgrep -f "worker" | head -1)
kill "$PID"
sleep 5
pm2 status
```

Randomized (bounded) example:

```bash
PIDS=($(pgrep -f "node worker"))
COUNT=${#PIDS[@]}
if [ "$COUNT" -gt 0 ]; then
  IDX=$((RANDOM % COUNT))
  kill "${PIDS[$IDX]}"
fi
```

## Network Simulation with `tc`

### Add latency/loss

```bash
sudo tc qdisc add dev eth0 root netem delay 500ms 50ms distribution normal loss 10%
```

### Observe impact

```bash
curl -w "time_total=%{time_total}\n" -o /dev/null -s http://127.0.0.1:<PORT>/health
```

### Rollback network shaping

```bash
sudo tc qdisc del dev eth0 root
```

## Suggested Initial Experiments

1. Kill one app worker and confirm auto-restart under 10s.
2. Add 300-500ms latency between app and cache; validate timeout handling.
3. Drop 5-10% packets temporarily; validate retry behavior.

## Troubleshooting

- Service does not auto-restart: supervisor policy misconfigured (`Restart=always`/PM2 process list).
- Latency test affects unrelated traffic: use dedicated interface/class filtering.
- Alerts did not fire: validate alert rule thresholds and notification routes.
- Recovery succeeded but data inconsistent: add idempotency and transactional guards.
