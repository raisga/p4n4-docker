#!/usr/bin/env bash
# ==============================================================================
# InfluxDB Sandbox Bucket Initialization
# ==============================================================================
# Creates a 'sandbox' bucket for testing/development.
# Runs after InfluxDB initial setup via docker-entrypoint-initdb.d
# ==============================================================================

set -e

SANDBOX_BUCKET="${INFLUXDB_SANDBOX_BUCKET:-sandbox}"
SANDBOX_RETENTION="${INFLUXDB_SANDBOX_RETENTION:-30d}"
ORG="${DOCKER_INFLUXDB_INIT_ORG:-ming}"
TOKEN="${DOCKER_INFLUXDB_INIT_ADMIN_TOKEN:-ming-stack-token}"
HOST="http://localhost:8086"
MAX_ATTEMPTS=30

# Wait for InfluxDB API to be ready
echo "Waiting for InfluxDB API..."
attempt=0
while [ "$attempt" -lt "$MAX_ATTEMPTS" ]; do
    if influx ping --host "$HOST" 2>/dev/null; then
        echo "InfluxDB API ready."
        break
    fi
    echo "  Attempt $((attempt + 1))/$MAX_ATTEMPTS..."
    sleep 2
    attempt=$((attempt + 1))
done

if [ "$attempt" -eq "$MAX_ATTEMPTS" ]; then
    echo "ERROR: InfluxDB API not ready after $((MAX_ATTEMPTS * 2))s. Sandbox bucket NOT created."
    exit 1
fi

# Create sandbox bucket (skip if already exists)
echo "Creating sandbox bucket: $SANDBOX_BUCKET (retention: $SANDBOX_RETENTION)"

if influx bucket list --host "$HOST" --token "$TOKEN" --org "$ORG" 2>/dev/null | grep -q "$SANDBOX_BUCKET"; then
    echo "Bucket '$SANDBOX_BUCKET' already exists, skipping."
else
    if influx bucket create \
        --name "$SANDBOX_BUCKET" \
        --org "$ORG" \
        --retention "$SANDBOX_RETENTION" \
        --token "$TOKEN" \
        --host "$HOST"; then
        echo "Sandbox bucket '$SANDBOX_BUCKET' created successfully."
    else
        echo "ERROR: Failed to create bucket '$SANDBOX_BUCKET'"
        exit 1
    fi
fi
