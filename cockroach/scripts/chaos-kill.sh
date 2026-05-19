#!/usr/bin/env bash
set -euo pipefail

NODE="${1:-cockroach3}"
OUTDIR="$(dirname "$0")/../results/raw"
mkdir -p "$OUTDIR"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
OUTFILE="$OUTDIR/chaos_${NODE}_${TIMESTAMP}.log"

echo "[INFO] Starting background workload before killing $NODE..."
cockroach workload run tpcc \
  --warehouses 50 --duration 6m --ramp 30s --tolerate-errors \
  "postgresql://root@cockroach1:26257?sslmode=disable" > "$OUTFILE" 2>&1 &
WORKLOAD_PID=$!
sleep 45

echo "[INFO] Killing $NODE at $(date +%s)"
KILL_TIME=$(date +%s)
docker kill "$NODE"

echo "[INFO] Waiting for recovery..."
sleep 30

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
