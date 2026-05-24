#!/usr/bin/env bash
# Setup script: Starts CockroachDB cluster via Docker and initializes TPC-C schema
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=benchmark-config.env
source "$SCRIPT_DIR/benchmark-config.env"
# shellcheck source=lib.sh
source "$SCRIPT_DIR/lib.sh"

export PATH="/opt/homebrew/bin:/usr/local/bin:$HOME/homebrew/bin:$PATH"

COMPOSE=$(docker_compose_cmd) || {
  echo "[ERROR] Docker Compose not found. Run: ./install-and-run.sh"
  exit 1
}

cd "$SCRIPT_DIR/../docker"

echo "[1/6] Stopping and removing existing containers + volumes (clean slate)..."
$COMPOSE down -v 2>/dev/null || true

echo "[2/6] Starting fresh containers (8 vCPU / 32GB RAM profile)..."
$COMPOSE up -d

echo "[3/6] Waiting for nodes to be ready..."
sleep 10

echo "[4/6] Initializing cluster (Raft quorum)..."
docker exec cockroach1 ./cockroach init --insecure --host=cockroach1:26257

echo "[5/6] Cluster nodes:"
docker exec cockroach1 ./cockroach node ls --insecure --host=cockroach1:26257

echo "[6/6] Initializing TPC-C database (${BENCHMARK_WAREHOUSES} warehouses)..."
docker exec cockroach1 ./cockroach workload init tpcc \
  --warehouses "$BENCHMARK_WAREHOUSES" \
  "$DB_URL"

echo "Done. Admin UI: http://localhost:8080"
