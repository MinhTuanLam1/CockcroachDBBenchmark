#!/usr/bin/env bash
set -euo pipefail

WAREHOUSES="${1:-10}"
DURATION="${2:-3m}"
RAMP="${3:-30s}"
OUTDIR="$(dirname "$0")/../results/raw"
mkdir -p "$OUTDIR"

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
OUTFILE="$OUTDIR/tpcc_${WAREHOUSES}wh_${TIMESTAMP}.log"

echo "[INFO] Running TPC-C: warehouses=$WAREHOUSES, duration=$DURATION, ramp=$RAMP"
echo "[INFO] Output: $OUTFILE"

cockroach workload run tpcc \
  --warehouses "$WAREHOUSES" \
  --duration "$DURATION" \
  --ramp "$RAMP" \
  --tolerate-errors \
  "postgresql://root@cockroach1:26257?sslmode=disable" \
  | tee "$OUTFILE"

echo "[INFO] Benchmark complete. Results saved to $OUTFILE"
