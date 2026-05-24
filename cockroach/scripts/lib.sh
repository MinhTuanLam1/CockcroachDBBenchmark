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
      echo "        macOS : open Docker Desktop, then re-run."
      echo "        Linux : sudo systemctl start docker"
      exit 1
    fi
    sleep 2
    elapsed=$((elapsed + 2))
  done
  echo "[INFO] Docker daemon is ready."
}

install_docker_compose_linux_standalone() {
  local compose_bin="/usr/local/bin/docker-compose"
  if command -v docker-compose &>/dev/null; then
    return 0
  fi
  echo "[INFO] Installing standalone docker-compose binary..."
  local version="v2.24.5"
  local arch
  arch="$(uname -m)"
  case "$arch" in
    x86_64) arch="x86_64" ;;
    aarch64|arm64) arch="aarch64" ;;
    *)
      echo "[ERROR] Unsupported architecture: $arch"
      return 1
      ;;
  esac
  sudo curl -fsSL \
    "https://github.com/docker/compose/releases/download/${version}/docker-compose-linux-${arch}" \
    -o "$compose_bin"
  sudo chmod +x "$compose_bin"
  echo "[INFO] Installed: $compose_bin"
}

install_docker_linux() {
  if command -v docker &>/dev/null && docker_compose_cmd &>/dev/null; then
    echo "[INFO] Docker + Compose already installed."
    return 0
  fi

  if ! command -v apt-get &>/dev/null; then
    echo "[ERROR] Only apt-based Linux (Ubuntu/Debian) auto-install is supported."
    echo "        Install Docker manually, then: ./install-and-run.sh --skip-install"
    return 1
  fi

  echo "[INFO] Installing Docker on Linux (requires sudo)..."

  sudo apt-get update -qq
  sudo apt-get install -y ca-certificates curl gnupg

  # Try official Docker CE repository (Ubuntu / Debian)
  if [[ ! -f /etc/apt/sources.list.d/docker.list ]]; then
    echo "[INFO] Adding Docker official apt repository..."
    sudo install -m 0755 -d /etc/apt/keyrings
    # shellcheck disable=SC1091
    . /etc/os-release
    local distro="${ID:-ubuntu}"
    local codename="${VERSION_CODENAME:-}"
    if [[ -z "$codename" && -n "${UBUNTU_CODENAME:-}" ]]; then
      codename="$UBUNTU_CODENAME"
    fi
    if [[ -z "$codename" ]]; then
      codename="$(lsb_release -cs 2>/dev/null || true)"
    fi
    if [[ "$distro" != "ubuntu" && "$distro" != "debian" ]]; then
      echo "[WARN] Unknown distro '$distro', assuming ubuntu."
      distro="ubuntu"
    fi
    sudo curl -fsSL "https://download.docker.com/linux/${distro}/gpg" \
      -o /etc/apt/keyrings/docker.asc
    sudo chmod a+r /etc/apt/keyrings/docker.asc
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/${distro} ${codename} stable" \
      | sudo tee /etc/apt/sources.list.d/docker.list >/dev/null
  fi

  sudo apt-get update -qq
  if sudo apt-get install -y \
      docker-ce docker-ce-cli containerd.io \
      docker-buildx-plugin docker-compose-plugin 2>/dev/null; then
    echo "[INFO] Installed Docker CE + Compose plugin."
  else
    echo "[WARN] Docker CE repo failed; falling back to docker.io..."
    sudo apt-get install -y docker.io
    install_docker_compose_linux_standalone
  fi

  sudo systemctl enable docker 2>/dev/null || true
  sudo systemctl start docker 2>/dev/null || true

  if [[ "$(id -u)" -ne 0 ]] && ! groups "$USER" | grep -q '\bdocker\b'; then
    sudo usermod -aG docker "$USER" 2>/dev/null || true
    echo "[INFO] Added $USER to docker group. If permission denied, run: newgrp docker"
  fi

  if ! docker_compose_cmd &>/dev/null; then
    install_docker_compose_linux_standalone
  fi
}
