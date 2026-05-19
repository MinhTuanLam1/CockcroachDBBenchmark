#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../docker"

echo "[1/4] Starting containers..."
docker-compose up -d

echo "[2/4] Waiting for nodes to be ready..."
sleep 5

echo "[3/4] Initializing cluster (Raft quorum)..."
docker exec cockroach1 ./cockroach init --insecure --host=cockroach1:26257

echo "[4/4] Cluster initialized. Nodes:"
docker exec cockroach1 ./cockroach node ls --insecure --host=cockroach1:26257

echo "Done. Admin UI available at http://localhost:8080"
