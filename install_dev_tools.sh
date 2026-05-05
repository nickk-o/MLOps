#!/usr/bin/env bash

set -euo pipefail

LOG_FILE="install.log"
exec > >(tee -a "$LOG_FILE") 2>&1

echo "============================================================"
echo "DevOps + ML tools installation started: $(date -Iseconds)"
echo "============================================================"

SUDO=""
if [[ "${EUID}" -ne 0 ]]; then
  if command -v sudo >/dev/null 2>&1; then
    SUDO="sudo"
  else
    echo "ERROR: please run as root or install sudo first."
    exit 1
  fi
fi

command_exists() {
  command -v "$1" >/dev/null 2>&1
}

python_ok() {
  command_exists python3 && python3 - <<'PY'
import sys
raise SystemExit(0 if sys.version_info >= (3, 9) else 1)
PY
}

python_pkg_ok() {
  local import_name="$1"
  python3 - <<PY >/dev/null 2>&1
import importlib.util
raise SystemExit(0 if importlib.util.find_spec("$import_name") else 1)
PY
}

apt_install_if_missing() {
  local missing=()
  for pkg in "$@"; do
    if ! dpkg -s "$pkg" >/dev/null 2>&1; then
      missing+=("$pkg")
    fi
  done

  if [[ "${#missing[@]}" -gt 0 ]]; then
    echo "Installing apt packages: ${missing[*]}"
    $SUDO apt-get update
    $SUDO apt-get install -y --no-install-recommends "${missing[@]}"
  else
    echo "Apt packages already installed: $*"
  fi
}

install_docker() {
  if command_exists docker; then
    echo "Docker is already installed: $(docker --version || true)"
  else
    echo "Installing Docker Engine and plugins..."
    apt_install_if_missing ca-certificates curl gnupg lsb-release
    $SUDO install -m 0755 -d /etc/apt/keyrings

    if [[ ! -f /etc/apt/keyrings/docker.asc ]]; then
      curl -fsSL https://download.docker.com/linux/ubuntu/gpg | $SUDO tee /etc/apt/keyrings/docker.asc >/dev/null
      $SUDO chmod a+r /etc/apt/keyrings/docker.asc
    fi

    . /etc/os-release
    local docker_os="${ID:-ubuntu}"
    if [[ "$docker_os" != "ubuntu" && "$docker_os" != "debian" ]]; then
      docker_os="ubuntu"
    fi

    local codename="${VERSION_CODENAME:-}"
    if [[ -z "$codename" ]] && command_exists lsb_release; then
      codename="$(lsb_release -cs)"
    fi

    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/${docker_os} ${codename} stable" \
      | $SUDO tee /etc/apt/sources.list.d/docker.list >/dev/null

    $SUDO apt-get update
    $SUDO apt-get install -y --no-install-recommends \
      docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
  fi

  if ! docker compose version >/dev/null 2>&1; then
    echo "Docker Compose plugin is missing. Installing docker-compose-plugin..."
    $SUDO apt-get update
    $SUDO apt-get install -y --no-install-recommends docker-compose-plugin
  fi

  if [[ -n "${SUDO_USER:-}" ]] && id -nG "$SUDO_USER" | grep -qw docker; then
    echo "User $SUDO_USER is already in docker group."
  elif [[ -n "${SUDO_USER:-}" ]]; then
    echo "Adding user $SUDO_USER to docker group. Re-login may be required."
    $SUDO usermod -aG docker "$SUDO_USER"
  fi
}

install_python() {
  if python_ok; then
    echo "Python is already >= 3.9: $(python3 --version)"
  else
    echo "Installing Python >= 3.9 and pip..."
    apt_install_if_missing python3 python3-venv python3-pip

    if ! python_ok; then
      echo "Current apt Python is still older than 3.9. Trying python3.11 from apt..."
      if apt-cache show python3.11 >/dev/null 2>&1; then
        apt_install_if_missing python3.11 python3.11-venv python3.11-distutils
        if command_exists python3.11; then
          echo "Python 3.11 installed: $(python3.11 --version)"
        fi
      else
        echo "ERROR: could not automatically install Python >= 3.9 on this system."
        echo "Install Python 3.9+ manually or use pyenv, then rerun this script."
        exit 1
      fi
    fi
  fi

  if ! python3 -m pip --version >/dev/null 2>&1; then
    echo "Installing pip..."
    apt_install_if_missing python3-pip
  else
    echo "pip is already installed: $(python3 -m pip --version)"
  fi
}

install_python_dependencies() {
  python3 -m pip install --upgrade pip

  local need_install=0
  local packages=("torch:torch" "torchvision:torchvision" "Pillow:PIL" "Django:django")

  for item in "${packages[@]}"; do
    local package_name="${item%%:*}"
    local import_name="${item##*:}"
    if python_pkg_ok "$import_name"; then
      echo "Python package is already installed: $package_name"
    else
      echo "Python package is missing: $package_name"
      need_install=1
    fi
  done

  if [[ "$need_install" -eq 1 ]]; then
    echo "Installing Python packages: torch torchvision pillow Django"
    python3 -m pip install \
      --index-url https://download.pytorch.org/whl/cpu \
      --extra-index-url https://pypi.org/simple \
      torch torchvision pillow Django
  else
    echo "All required Python packages are already installed."
  fi
}

print_versions() {
  echo "---------------- Versions ----------------"
  docker --version || true
  docker compose version || true
  python3 --version || true
  python3 -m pip --version || true
  python3 - <<'PY' || true
packages = [
    ("Django", "django"),
    ("torch", "torch"),
    ("torchvision", "torchvision"),
    ("Pillow", "PIL"),
]
for package_name, import_name in packages:
    try:
        module = __import__(import_name)
        version = getattr(module, "__version__", "installed")
        print(f"{package_name}: {version}")
    except Exception as exc:
        print(f"{package_name}: not available ({exc})")
PY
  echo "------------------------------------------"
}

if ! command_exists apt-get; then
  echo "ERROR: this script supports Debian/Ubuntu systems with apt-get."
  exit 1
fi

install_docker
install_python
install_python_dependencies
print_versions

echo "Installation finished: $(date -Iseconds)"
echo "Log saved to: $LOG_FILE"
