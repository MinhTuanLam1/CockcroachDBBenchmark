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

# Launch tmux running the real pipeline script
tmux new-session -d -s "$SESSION" "bash '$SCRIPT_DIR/run-pipeline.sh'"

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
