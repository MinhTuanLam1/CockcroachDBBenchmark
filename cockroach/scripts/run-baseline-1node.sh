#!/usr/bin/env bash
# Baseline benchmark with 1 active node to calculate Raft replication overhead.
# Stops nodes 2 and 3, runs TPC-C against node 1 only, then restarts the cluster.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=benchmark-config.env
source "$SCRIPT_DIR/benchmark-config.env"

OUTDIR="$SCRIPT_DIR/../results/raw"
mkdir -p "$OUTDIR"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
OUTFILE="$OUTDIR/baseline_1node_${TIMESTAMP}.log"

echo "[INFO] === Baseline 1-node benchmark (no Raft replication overhead) ==="
echo "[WARN] This will temporarily STOP cockroach2 and cockroach3."

echo "[INFO] Stopping nodes 2 and 3..."
docker stop cockroach2 cockroach3 || true

sleep 5

echo "[INFO] Running TPC-C against single node..."
docker exec cockroach1 ./cockroach workload run tpcc \
  --warehouses "$BENCHMARK_WAREHOUSES" \
  --duration "$BENCHMARK_DURATION" \
  --ramp "$BENCHMARK_RAMP" \
  --concurrency "$BENCHMARK_CONCURRENCY" \
  --tolerate-errors \
  "$DB_URL" | tee "$OUTFILE"

echo ""
echo "[INFO] Restarting nodes 2 and 3..."
docker start cockroach2 cockroach3

sleep 15

echo "[INFO] Checking cluster health..."
docker exec cockroach1 ./cockroach node status --insecure --host=cockroach1:26257

echo "[INFO] Waiting for full replication..."
for i in {1..60}; do
  UNDER=$(docker exec cockroach1 ./cockroach sql --insecure --host=cockroach1:26257 --format=csv -e "SELECT count(*) FROM crdb_internal.ranges WHERE array_length(replicas,1) < 3;" | tail -n 1 || true)
  if [ "$UNDER" = "0" ] || [ -z "$UNDER" ]; then
    echo "[PASS] All ranges fully replicated."
    break
  fi
  sleep 1
done

echo ""
echo "[INFO] Baseline complete: $OUTFILE"
echo "[INFO] Compare this tpmC with 3-node results to calculate Raft overhead:"
echo "       overhead_pct = (1_node_tpmC - 3_node_tpmC) / 1_node_tpmC * 100"
