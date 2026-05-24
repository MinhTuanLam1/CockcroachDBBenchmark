#!/usr/bin/env bash
# Shared helpers for Docker / Compose detection

docker_compose_cmd() {
  if docker compose version &>/dev/null 2>&1; then
    echo "docker compose"
  elif command -v docker-compose &>/dev/null; then
    echo "docker-compose"
  else
    return 1
  fi
}

wait_for_docker() {
  local max_wait="${1:-120}"
  local elapsed=0
  echo "[INFO] Waiting for Docker daemon (max ${max_wait}s)..."
  until docker info &>/dev/null 2>&1; do
    if (( elapsed >= max_wait )); then
      echo "[ERROR] Docker daemon not ready after ${max_wait}s."
      echo "        macOS: open Docker Desktop from Applications, then re-run."
      exit 1
    fi
    sleep 2
    elapsed=$((elapsed + 2))
  done
  echo "[INFO] Docker daemon is ready."
}
