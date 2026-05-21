#!/usr/bin/env bash
# Chaos testing script: Kills a CockroachDB node to measure cluster recovery time
# Usage: ./chaos-kill.sh [node_name]
# Default: kills cockroach3, runs 50-warehouse workload for 6 minutes
# WARNING: Use only in test/dev environments - may cause data loss in production
set -euo pipefail

NODE="${1:-cockroach3}"
OUTDIR="$(dirname "$0")/../results/raw"
mkdir -p "$OUTDIR"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
OUTFILE="$OUTDIR/chaos_${NODE}_${TIMESTAMP}.log"

echo "[INFO] Starting background workload before killing $NODE..."
# Run workload inside Docker container (no local cockroach CLI needed)
docker exec cockroach1 ./cockroach workload run tpcc \
  --warehouses 5 --duration 6m --ramp 30s --tolerate-errors \
  "postgresql://root@cockroach1:26257?sslmode=disable" > "$OUTFILE" 2>&1 &
WORKLOAD_PID=$!
sleep 45

echo "[INFO] Killing $NODE at $(date +%s)"
KILL_TIME=$(date +%s)
docker kill "$NODE"

echo "[INFO] Waiting for recovery..."
sleep 30

# Poll until all ranges have full replication (3 replicas)
for i in {1..60}; do
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
