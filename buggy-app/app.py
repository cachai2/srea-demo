"""
Sample Order API — intentionally buggy for Azure SRE Agent demo.
Deploy to Azure Container Apps or App Service, then let SREA find the bugs
via source code integration.

Known bugs planted:
  1. /orders/<id> — unhandled None dereference when order not found (500)
  2. /orders        — SQL-injection-style string formatting (flaggable)
  3. /health        — DB connection string logged at INFO level (secret leak)
  4. /slow          — artificial N+1 query pattern causing latency spikes
"""

import os
import logging
import time

# Wire up App Insights BEFORE importing/creating Flask so auto-instrumentation hooks in
from azure.monitor.opentelemetry import configure_azure_monitor
if os.environ.get("APPLICATIONINSIGHTS_CONNECTION_STRING"):
    configure_azure_monitor(
        connection_string=os.environ["APPLICATIONINSIGHTS_CONNECTION_STRING"],
        logger_name="order-api",
    )

from flask import Flask, jsonify, request

app = Flask(__name__)
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("order-api")

# ---------- Simulated data store ----------
DB_CONNECTION_STRING = os.environ.get(
    "DB_CONNECTION_STRING",
    "Server=proddb.database.windows.net;Database=orders;User Id=admin;Password=DEMO-NOT-A-REAL-PASSWORD;"
)

ORDERS = {
    "1":  {"id": "1",  "item": "Widget A",  "qty": 10, "status": "shipped"},
    "2":  {"id": "2",  "item": "Widget B",  "qty": 5,  "status": "processing"},
    "3":  {"id": "3",  "item": "Gadget C",  "qty": 2,  "status": "delivered"},
    "4":  {"id": "4",  "item": "Gizmo D",   "qty": 8,  "status": "shipped"},
    "5":  {"id": "5",  "item": "Doohickey E", "qty": 1, "status": "processing"},
    "6":  {"id": "6",  "item": "Thingamajig F", "qty": 20, "status": "shipped"},
    "7":  {"id": "7",  "item": "Whatchamacallit G", "qty": 3, "status": "delivered"},
    "8":  {"id": "8",  "item": "Widget H",  "qty": 15, "status": "processing"},
    "9":  {"id": "9",  "item": "Gadget I",  "qty": 7,  "status": "shipped"},
    "10": {"id": "10", "item": "Widget J",  "qty": 12, "status": "delivered"},
}


# ---------- Routes ----------

@app.route("/")
def index():
    return jsonify({"service": "order-api", "version": "1.2.0"})


@app.route("/health")
def health():
    # BUG 3: Logging the full connection string (contains password)
    logger.info(f"Health check OK — connected to {DB_CONNECTION_STRING}")
    return jsonify({"status": "healthy", "db": "connected"})


@app.route("/orders")
def list_orders():
    status_filter = request.args.get("status", "")
    # BUG 2: Naive string interpolation instead of parameterized query
    query = f"SELECT * FROM orders WHERE status = '{status_filter}'"
    logger.info(f"Executing query: {query}")

    # Simulated result
    if status_filter:
        results = {k: v for k, v in ORDERS.items() if v["status"] == status_filter}
    else:
        results = ORDERS
    return jsonify(list(results.values()))


@app.route("/orders/<order_id>")
def get_order(order_id):
    order = ORDERS.get(order_id)
    # BUG 1: No null check — accessing .get("item") on None raises 500
    item_name = order.get("item")
    return jsonify({"order_id": order_id, "item": item_name, "detail": order})


@app.route("/slow")
def slow_endpoint():
    """BUG 4: Simulated N+1 query — loops with a sleep per 'row'."""
    results = []
    for oid, order in ORDERS.items():
        time.sleep(0.5)  # simulates individual DB round-trip
        enriched = {**order, "warehouse": "US-WEST-2"}
        results.append(enriched)
    return jsonify(results)


if __name__ == "__main__":
    port = int(os.environ.get("PORT", 8080))
    app.run(host="0.0.0.0", port=port)
