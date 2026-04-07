#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# Generate telemetry data for the SREA demo.
# Run this 5-10 minutes BEFORE the live demo so App Insights has data.
# ---------------------------------------------------------------------------
set -euo pipefail

RG="${1:-rg-srea-demo}"

APP_URL=$(az deployment group show -g "$RG" -n main \
  --query properties.outputs.appUrl.value -o tsv 2>/dev/null)

if [[ -z "$APP_URL" ]]; then
  echo "ERROR: Could not retrieve APP_URL. Is the deployment in resource group '$RG' named 'main'?"
  exit 1
fi

echo "Target: $APP_URL"
echo "Generating errors — this will take ~2 minutes..."
echo ""

ROUNDS=10

for i in $(seq 1 $ROUNDS); do
  echo "── Round $i/$ROUNDS ──"

  # Bug 1: 500 — null dereference on missing order
  STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$APP_URL/orders/999") || true
  echo "  /orders/999        → $STATUS (expect 500)"

  # Bug 2: SQL injection probes — multiple patterns so the agent sees a realistic attack
  for payload in \
    "shipped'%20OR%201=1--" \
    "shipped'%20UNION%20SELECT%20NULL--" \
    "shipped';%20DROP%20TABLE%20orders--" \
    "shipped'%20AND%201=1--"; do
    STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$APP_URL/orders?status=$payload") || true
    echo "  /orders?status=sqli → $STATUS (expect 200)"
  done

  # Bug 3: Secret leak — health endpoint logs connection string
  STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$APP_URL/health") || true
  echo "  /health             → $STATUS (expect 200)"

  # Bug 4: Slow endpoint — CONCURRENT requests to spike p95 latency
  # Sequential calls won't trigger the alert — need parallel load
  for j in 1 2 3 4 5; do
    curl -s -o /dev/null "$APP_URL/slow" &
  done
  wait
  echo "  /slow x5 concurrent → done (expect ~5s each)"

  # Normal traffic so failures stand out
  curl -s -o /dev/null "$APP_URL/" || true
  curl -s -o /dev/null "$APP_URL/orders" || true
  curl -s -o /dev/null "$APP_URL/orders/1" || true

  sleep 2
done

echo ""
echo "Done. Wait 3-5 minutes for App Insights ingestion, then start the demo."
