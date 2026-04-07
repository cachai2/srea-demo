# Order API — Incident Response & Troubleshooting Guide

Use this skill when investigating issues with the order-api service
(Azure Container App). This encodes our team's 3 years of operational
experience with this service.

## Service Overview

- **Service**: order-api (Flask/Python)
- **Hosting**: Azure Container Apps
- **Monitoring**: Application Insights + Log Analytics
- **Repo**: Connected via SRE Agent resource mapping
- **Endpoints**: `/`, `/orders`, `/orders/<id>`, `/health`, `/slow`

## Known Issue Patterns

### Pattern 1: Null Order ID (Critical)

**Symptoms**: 500 errors on `/orders/<id>` when order ID doesn't exist.

**Root cause**: Missing null check in the `get_order` function in `app.py` — `order.get("item")`
called on `None` when `ORDERS.get(order_id)` returns no match.

**Remediation**:
1. Create GitHub issue with label `bug` and `input-validation`
2. Proposed fix: add `if order is None: return jsonify({"error": "Order not found"}), 404`
3. Escalation: page @contoso-sre if error rate exceeds 5% of total requests

### Pattern 2: Slow Sequential Processing (High)

**Symptoms**: `/slow` endpoint responds in 5+ seconds. Under concurrent load
(especially EU morning traffic), causes p95 latency spikes.

**Root cause**: Loop in the `slow_endpoint` function in `app.py` — iterates all orders with a
`time.sleep(0.5)` per row simulating individual blocking calls per record.

**Immediate mitigation**:
1. Scale container app replicas to absorb load:
   `az containerapp update -n order-api-demo -g <RG> --min-replicas 5`
2. Do NOT scale above 10 replicas — cost ceiling per scaling policy.
3. Create GitHub issue with label `performance` for batch processing refactor.

### Pattern 3: SQL Injection Risk (High)

**Symptoms**: No runtime errors — returns 200. Dangerous because it's silent.

**Root cause**: String formatting in the `list_orders` function in `app.py` — user input
interpolated directly into a SQL query string via f-string.

**Remediation**:
1. Create GitHub issue with label `security` and `sql-injection`
2. Proposed fix: use parameterized queries
3. Flag as security finding in next standup

### Pattern 4: Secret Leak in Logs (Critical)

**Symptoms**: No runtime errors. Health endpoint returns 200.

**Root cause**: The `health` function in `app.py` logs the full `DB_CONNECTION_STRING`
including password at INFO level. Visible in App Insights and Log Analytics
to anyone with Reader access.

**Remediation**:
1. Create GitHub issue with label `security` and `secret-leak`
2. Proposed fix: redact or remove connection string from log output
3. Rotate the database password immediately
4. Escalation: notify security team within 1 hour

## Escalation Policy

| Severity | Response time | Who to page |
|----------|--------------|-------------|
| P1 (500 errors > 5%) | 15 min | @contoso-sre-oncall |
| P2 (latency > 3s p95) | 30 min | @contoso-sre |
| P3 (security finding) | Next standup | @contoso-security |

## Investigation Checklist

When investigating any order-api issue:

1. **Check deployment**: Was there a recent deployment? Compare `deployed_at`
   timestamp from `/` endpoint with error start time.
2. **Query App Insights**: Look at failed requests, exceptions, and response
   times for the last 2 hours.
3. **Check the known patterns above** — most issues match one of these.
4. **Search source code**: Use semantic search to locate the root cause.
   Cite exact file and line number.
5. **Take action**: Follow the remediation steps for the matching pattern.
6. **Notify**: Create GitHub issue and email the team per escalation policy.
