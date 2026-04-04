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

  # Bug 2: SQL injection pattern in query param
  STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$APP_URL/orders?status=shipped'%20OR%201=1--") || true
  echo "  /orders?status=sqli → $STATUS (expect 200)"

  # Bug 3: Secret leak — health endpoint logs connection string
  STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$APP_URL/health") || true
  echo "  /health             → $STATUS (expect 200)"

  # Bug 4: Slow endpoint — N+1 pattern
  STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$APP_URL/slow") || true
  echo "  /slow               → $STATUS (expect 200)"

  # Normal traffic so failures stand out
  curl -s -o /dev/null "$APP_URL/" || true
  curl -s -o /dev/null "$APP_URL/orders" || true
  curl -s -o /dev/null "$APP_URL/orders/1" || true

  sleep 2
done

echo ""
echo "Done. Wait 3-5 minutes for App Insights ingestion, then start the demo."
