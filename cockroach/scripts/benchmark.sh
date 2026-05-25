#!/usr/bin/env bash
# Benchmark script: Runs TPC-C workload against CockroachDB cluster (inside Docker)
# Usage: ./benchmark.sh [warehouses] [max_ops] [ramp] [concurrency]
# Defaults: from benchmark-config.env
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/benchmark-config.env"

WAREHOUSES="${1:-$BENCHMARK_WAREHOUSES}"
MAX_OPS="${2:-$BENCHMARK_MAX_OPS}"
RAMP="${3:-$BENCHMARK_RAMP}"
CONCURRENCY="${4:-$BENCHMARK_CONCURRENCY}"
OUTDIR="$SCRIPT_DIR/../results/raw"
mkdir -p "$OUTDIR"

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
OUTFILE="$OUTDIR/tpcc_${WAREHOUSES}wh_${MAX_OPS}ops_${TIMESTAMP}.log"

echo "[INFO] Running TPC-C: warehouses=$WAREHOUSES, max-ops=$MAX_OPS, ramp=$RAMP, concurrency=$CONCURRENCY"
echo "[INFO] Output: $OUTFILE"

WAIT_FLAG=""
if [ "${BENCHMARK_WAIT:-}" = "true" ]; then
  WAIT_FLAG="--wait"
fi

docker exec cockroach1 ./cockroach workload run tpcc \
  --warehouses "$WAREHOUSES" \
  --max-ops "$MAX_OPS" \
  --ramp "$RAMP" \
  --concurrency "$CONCURRENCY" \
  --tolerate-errors \
  $WAIT_FLAG \
  "$DB_URL" \
  | tee "$OUTFILE"

echo "[INFO] Running consistency check..."
docker exec cockroach1 ./cockroach workload check tpcc \
  --warehouses "$WAREHOUSES" \
  "$DB_URL"

echo "[INFO] Benchmark complete. Results saved to $OUTFILE"
