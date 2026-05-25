#!/usr/bin/env bash
# Internal pipeline — sequential benchmark steps.
# Called by run-overnight.sh inside tmux.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
RESULTS_DIR="$SCRIPT_DIR/../results/raw"
mkdir -p "$RESULTS_DIR"

cd "$SCRIPT_DIR"

echo "[$(date)] ===== Starting overnight benchmark pipeline ====="

# 1) Setup
TS=$(date +%Y%m%d_%H%M%S)
./setup.sh 2>&1 | tee "$RESULTS_DIR/setup_${TS}.log"

# 2) 3 benchmark runs
for i in 1 2 3; do
  TS=$(date +%Y%m%d_%H%M%S)
  echo "[$(date)] ==== Benchmark run $i/3 ===="
  ./benchmark.sh 2>&1 | tee "$RESULTS_DIR/bench_run${i}_${TS}.log"
done

# 3) Serializable verification
TS=$(date +%Y%m%d_%H%M%S)
echo "[$(date)] ==== Serializable verification ===="
./verify-serializable.sh 2>&1 | tee "$RESULTS_DIR/serializable_${TS}.log"

# 4) Chaos test
TS=$(date +%Y%m%d_%H%M%S)
echo "[$(date)] ==== Chaos test ===="
./chaos-kill.sh 2>&1 | tee "$RESULTS_DIR/chaos_${TS}.log"

# 5) Post-chaos verify
TS=$(date +%Y%m%d_%H%M%S)
echo "[$(date)] ==== Post-chaos verification ===="
./verify-post-chaos.sh 2>&1 | tee "$RESULTS_DIR/post_chaos_${TS}.log"

# 6) 1-node baseline
TS=$(date +%Y%m%d_%H%M%S)
echo "[$(date)] ==== 1-node baseline ===="
./run-baseline-1node.sh 2>&1 | tee "$RESULTS_DIR/baseline_${TS}.log"

echo "[$(date)] ===== ALL DONE! ====="
echo "Logs: $RESULTS_DIR"
ls -lt "$RESULTS_DIR" | head -20

# Keep shell alive
bash
