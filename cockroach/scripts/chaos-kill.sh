#!/usr/bin/env bash
# Chaos testing script: Kills a CockroachDB node to measure cluster recovery time
# Usage: ./chaos-kill.sh [node_name]
# Default: kills cockroach3, runs TPC-C in background until max-ops reached
# WARNING: Use only in test/dev environments
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/benchmark-config.env"
source "$SCRIPT_DIR/lib.sh"

NODE="${1:-$CHAOS_NODE}"
OUTDIR="$SCRIPT_DIR/../results/raw"
mkdir -p "$OUTDIR"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
OUTFILE="$OUTDIR/chaos_${NODE}_${TIMESTAMP}.log"

echo "[INFO] Starting background workload before killing $NODE..."
echo "[INFO] Workload: warehouses=$CHAOS_WAREHOUSES, max-ops=$CHAOS_MAX_OPS, ramp=$CHAOS_RAMP, concurrency=$CHAOS_CONCURRENCY"

WAIT_FLAG=""
if [ "${CHAOS_WAIT:-}" = "true" ]; then
  WAIT_FLAG="--wait=1"
fi

docker exec cockroach1 ./cockroach workload run tpcc \
  --warehouses "$CHAOS_WAREHOUSES" \
  --max-ops "$CHAOS_MAX_OPS" \
  --ramp "$CHAOS_RAMP" \
  --concurrency "$CHAOS_CONCURRENCY" \
  --tolerate-errors \
  $WAIT_FLAG \
  "$DB_URL" > "$OUTFILE" 2>&1 &
WORKLOAD_PID=$!

sleep "$CHAOS_WARMUP_SEC"

echo "[INFO] Killing $NODE at $(date +%s)"
KILL_TIME=$(date +%s)
docker kill "$NODE"

echo "[INFO] Waiting for recovery..."
sleep 30

for i in {1..120}; do
  UNDER=$(docker exec cockroach1 ./cockroach sql --insecure --host=cockroach1:26257 --format=csv -e "SELECT count(*) FROM crdb_internal.ranges WHERE array_length(replicas,1) < 3;" | tail -n 1 || true)
  if [ "$UNDER" = "0" ] || [ -z "$UNDER" ]; then
    RECOVERY_TIME=$(date +%s)
    DELTA=$((RECOVERY_TIME - KILL_TIME))
    echo "[RESULT] Node $NODE killed. Recovery time: ${DELTA}s"
    break
  fi
  sleep 1
done

docker start "$NODE"
echo "[INFO] Node $NODE restarted."

wait $WORKLOAD_PID || true
echo "[INFO] Workload complete. Output: $OUTFILE"
