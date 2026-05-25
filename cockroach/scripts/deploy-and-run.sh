#!/usr/bin/env bash
# One-shot install dependencies + run benchmark on current repo (Vultr/Ubuntu).
# Assumes you have already cd into the repo root.
# Usage:
#   chmod +x cockroach/scripts/deploy-and-run.sh
#   ./cockroach/scripts/deploy-and-run.sh
set -euo pipefail

SESSION="tpcc-overnight"

echo "[INFO] === Install & Run from current repo ==="

# 1) Install Docker
echo "[INFO] Installing Docker..."
if ! command -v docker > /dev/null 2>&1; then
  curl -fsSL https://get.docker.com | sh
  systemctl start docker 2>/dev/null || service docker start 2>/dev/null || true
fi

# 2) Install Docker Compose plugin
echo "[INFO] Installing Docker Compose..."
if ! docker compose version > /dev/null 2>&1; then
  apt-get update -qq
  apt-get install -y docker-compose-plugin
fi

# 3) Install git + tmux
echo "[INFO] Installing git + tmux..."
apt-get install -y git tmux

# 4) Ensure scripts are executable
echo "[INFO] Preparing scripts..."
chmod +x cockroach/scripts/*.sh

# 5) Launch overnight benchmark
echo "[INFO] Launching overnight benchmark in tmux session: $SESSION"
cd cockroach/scripts
./run-overnight.sh
