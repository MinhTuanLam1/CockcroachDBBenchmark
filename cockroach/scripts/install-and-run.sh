#!/usr/bin/env bash
# Full pipeline: install Docker + Compose, setup 3-node cluster, run TPC-C benchmark
#
# Usage:
#   ./install-and-run.sh              # install (if needed) + setup + 3 benchmark runs
#   ./install-and-run.sh --skip-install
#   ./install-and-run.sh --setup-only
#   ./install-and-run.sh --benchmark-only
#   ./install-and-run.sh --with-chaos
#   ./install-and-run.sh --runs 1
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=benchmark-config.env
source "$SCRIPT_DIR/benchmark-config.env"
# shellcheck source=lib.sh
source "$SCRIPT_DIR/lib.sh"

export PATH="/opt/homebrew/bin:/usr/local/bin:$HOME/homebrew/bin:$PATH"

SKIP_INSTALL=false
SETUP_ONLY=false
BENCHMARK_ONLY=false
WITH_CHAOS=false
RUNS=3

usage() {
  sed -n '2,12p' "$0" | tail -n +2
  exit 0
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --skip-install) SKIP_INSTALL=true ;;
    --setup-only) SETUP_ONLY=true ;;
    --benchmark-only) BENCHMARK_ONLY=true ;;
    --with-chaos) WITH_CHAOS=true ;;
    --runs) RUNS="${2:?--runs requires a number}"; shift ;;
    -h|--help) usage ;;
    *) echo "[ERROR] Unknown option: $1"; usage ;;
  esac
  shift
done

log() { echo "[INFO] $*"; }
err() { echo "[ERROR] $*" >&2; }

install_homebrew_mac() {
  if command -v brew &>/dev/null; then
    return 0
  fi
  log "Installing Homebrew..."
  NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  if [[ -x /opt/homebrew/bin/brew ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  elif [[ -x /usr/local/bin/brew ]]; then
    eval "$(/usr/local/bin/brew shellenv)"
  fi
}

install_docker_mac() {
  install_homebrew_mac
  if command -v docker &>/dev/null && docker compose version &>/dev/null 2>&1; then
    log "Docker + Compose already installed."
    return 0
  fi
  log "Installing Docker Desktop (includes Compose plugin)..."
  brew install --cask docker
  if [[ ! -d /Applications/Docker.app ]]; then
    err "Docker Desktop install failed."
    exit 1
  fi
  log "Starting Docker Desktop..."
  open -a Docker
}

install_docker() {
  case "$(uname -s)" in
    Darwin) install_docker_mac ;;
    Linux) install_docker_linux ;;  # from lib.sh
    *)
      err "Unsupported OS: $(uname -s). Install Docker manually, then re-run with --skip-install."
      exit 1
      ;;
  esac
}

ensure_docker_compose() {
  if docker_compose_cmd &>/dev/null; then
    log "Compose: $(docker_compose_cmd)"
    return 0
  fi
  case "$(uname -s)" in
    Darwin)
      install_homebrew_mac
      log "Installing docker-compose standalone..."
      brew install docker-compose
      ;;
    Linux)
      install_docker_compose_linux_standalone
      ;;
  esac
}

run_benchmarks() {
  log "Running TPC-C benchmark ${RUNS} time(s): warehouses=$BENCHMARK_WAREHOUSES max-ops=$BENCHMARK_MAX_OPS concurrency=$BENCHMARK_CONCURRENCY"
  for i in $(seq 1 "$RUNS"); do
    log "=== Benchmark run ${i}/${RUNS} ==="
    "$SCRIPT_DIR/benchmark.sh"
  done
  log "Benchmark logs: $SCRIPT_DIR/../results/raw/"
}

main() {
  log "AdvancedDB CockroachDB — install & run"
  log "Target: ${BENCHMARK_WAREHOUSES} warehouses, max-ops=${BENCHMARK_MAX_OPS}, concurrency=${BENCHMARK_CONCURRENCY}"

  if [[ "$BENCHMARK_ONLY" == false && "$SKIP_INSTALL" == false ]]; then
    install_docker
    ensure_docker_compose
    wait_for_docker 180
  elif [[ "$SKIP_INSTALL" == true ]] || [[ "$BENCHMARK_ONLY" == true ]]; then
    command -v docker &>/dev/null || { err "Docker not found."; exit 1; }
    wait_for_docker 60
    docker_compose_cmd &>/dev/null || ensure_docker_compose
  fi

  if [[ "$BENCHMARK_ONLY" == false ]]; then
    "$SCRIPT_DIR/setup.sh"
  fi

  if [[ "$SETUP_ONLY" == true ]]; then
    log "Setup complete (--setup-only). Admin UI: http://localhost:8080"
    exit 0
  fi

  run_benchmarks

  if [[ "$WITH_CHAOS" == true ]]; then
    log "=== Chaos test: killing ${CHAOS_NODE} ==="
    "$SCRIPT_DIR/chaos-kill.sh"
  fi

  log "All done."
  log "  Admin UI : http://localhost:8080"
  log "  Results  : cockroach/results/raw/"
  log "  Protocol : shared/benchmark-protocol.md"
}

main "$@"
