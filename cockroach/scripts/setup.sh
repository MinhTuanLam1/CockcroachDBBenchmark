#!/usr/bin/env bash
# Setup script: Starts CockroachDB cluster via Docker and initializes Raft quorum
set -euo pipefail

# Ensure Homebrew binaries are in PATH
export PATH="$HOME/homebrew/bin:$PATH"

cd "$(dirname "$0")/../docker"

echo "[1/4] Stopping and removing existing containers + volumes (clean slate)..."
docker-compose down -v 2>/dev/null || true

echo "[2/4] Starting fresh containers..."
docker-compose up -d

echo "[3/4] Waiting for nodes to be ready..."
sleep 5

echo "[4/4] Initializing cluster (Raft quorum)..."
docker exec cockroach1 ./cockroach init --insecure --host=cockroach1:26257

echo "[5/5] Cluster nodes:"
docker exec cockroach1 ./cockroach node ls --insecure --host=cockroach1:26257

echo "[6/6] Initializing TPC-C database (10 warehouses)..."
docker exec cockroach1 ./cockroach workload init tpcc --warehouses 5 "postgresql://root@cockroach1:26257?sslmode=disable"

echo "Done. Admin UI available at http://localhost:8080"
