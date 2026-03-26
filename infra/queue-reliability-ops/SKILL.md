# Queue Reliability Operations

> Keep asynchronous systems healthy using retries, DLQs, backpressure, and poison-message handling.

## Safety Rules

- Never enable infinite retries without backoff.
- Route failed messages to DLQ for inspection.
- Make handlers idempotent before increasing retry attempts.

## Quick Reference

```bash
# RabbitMQ overview
rabbitmqctl list_queues name messages consumers

# Redis queue lag sample
redis-cli llen jobs:pending
```

## Reliability Patterns

- Exponential backoff with jitter.
- Dead-letter queue per primary queue.
- Visibility timeout tuned to handler duration.
- Consumer concurrency caps to protect downstreams.

## Poison Message Workflow

1. Detect repeated failures.
2. Move to DLQ with failure metadata.
3. Triage root cause.
4. Replay safely after fix.

## Troubleshooting

- Queue lag grows with normal traffic: consumers under-provisioned or downstream bottleneck.
- High retries and duplicates: missing idempotency keys or timeout mismatch.
