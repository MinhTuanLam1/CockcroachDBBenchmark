#!/usr/bin/env bash
# Overnight end-to-end benchmark runner — single tmux window, sequential.
# Usage: ./run-overnight.sh
# Attach: tmux attach -t tpcc-overnight
# Detach: Ctrl+B then D
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SESSION="tpcc-overnight"
RESULTS_DIR="$SCRIPT_DIR/../results/raw"
mkdir -p "$RESULTS_DIR"

# Kill existing session if any
tmux kill-session -t "$SESSION" 2>/dev/null || true

echo "[INFO] Creating tmux session: $SESSION"

# Build the commands in a temp script to avoid quoting hell
TMP_SCRIPT="$(mktemp)"
cat > "$TMP_SCRIPT" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="__SCRIPT_DIR__"
RESULTS_DIR="__RESULTS_DIR__"
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

# Keep shell alive for scrolling
bash
EOF

# Inject real paths into temp script
sed -i "s|__SCRIPT_DIR__|$SCRIPT_DIR|g" "$TMP_SCRIPT"
sed -i "s|__RESULTS_DIR__|$RESULTS_DIR|g" "$TMP_SCRIPT"
chmod +x "$TMP_SCRIPT"

# Launch tmux with the temp script
tmux new-session -d -s "$SESSION" "$TMP_SCRIPT"

echo ""
echo "========================================"
echo "[INFO] Overnight session: $SESSION"
echo ""
echo "  Attach:       tmux attach -t $SESSION"
echo "  Detach:       Ctrl+B then D"
echo "  Kill:         tmux kill-session -t $SESSION"
echo ""
echo "  Runs in order:"
echo "    1. Setup cluster"
echo "    2. 3x benchmark (10 wh, 10k ops)"
echo "    3. Serializable verify"
echo "    4. Chaos kill + recovery"
echo "    5. Post-chaos verify"
echo "    6. 1-node baseline"
echo ""
echo "  Results:      $RESULTS_DIR"
echo "========================================"
echo ""

if [ -t 1 ]; then
  tmux attach -t "$SESSION"
else
  echo "[INFO] Detached. Attach with: tmux attach -t $SESSION"
fi
