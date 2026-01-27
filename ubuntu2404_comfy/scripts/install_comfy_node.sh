#!/usr/bin/env bash
set -euo pipefail

# install_comfyui_nodes.sh
#
# Goal: install custom nodes + deps (matching your Dockerfile), on a native ComfyUI install.
#
# Key points:
# - Always use the venv python to run pip:  $VENV_PATH/bin/python -m pip ...
#   (avoids PATH/hash/alias issues with multiple pip locations)
# - Use official PyPI only for node requirements to avoid mirror 404 issues.
# - Correct pip syntax: "pip install ... --index-url ..." (index-url is install option)
#
# Usage:
#   bash install_comfyui_nodes.sh
#   COMFYUI_PATH=/opt/ComfyUI bash install_comfyui_nodes.sh

COMFYUI_PATH="${COMFYUI_PATH:-$HOME/ComfyUI}"
CUSTOM_NODES_DIR="${CUSTOM_NODES_DIR:-$COMFYUI_PATH/custom_nodes}"
VENV_PATH="${VENV_PATH:-$COMFYUI_PATH/.venv}"

PIP_INDEX_URL="${PIP_INDEX_URL:-https://pypi.org/simple}"

log()  { printf "\n\033[1;32m==>\033[0m %s\n" "$*"; }
warn() { printf "\n\033[1;33m[WARN]\033[0m %s\n" "$*"; }
die()  { printf "\n\033[1;31m[ERR]\033[0m %s\n" "$*" >&2; exit 1; }

need_cmd() { command -v "$1" >/dev/null 2>&1 || die "Missing command: $1"; }

PY=""

ensure_paths() {
  [[ -d "$COMFYUI_PATH" ]] || die "COMFYUI_PATH not found: $COMFYUI_PATH"
  [[ -d "$VENV_PATH" ]] || die "Venv dir not found: $VENV_PATH"
  PY="$VENV_PATH/bin/python"
  [[ -x "$PY" ]] || die "Venv python not found/executable: $PY"
  mkdir -p "$CUSTOM_NODES_DIR"
}

pip_cmd() {
  # Always use venv python -m pip (no PATH ambiguity)
  "$PY" -m pip "$@"
}

self_check() {
  log "Self-check (must be venv python/pip)"
  echo "COMFYUI_PATH=$COMFYUI_PATH"
  echo "VENV_PATH=$VENV_PATH"
  echo "PY=$PY"
  "$PY" -V
  "$PY" -c 'import sys; print("sys.executable:", sys.executable)'
  pip_cmd --version
}

apt_install_deps() {
  need_cmd sudo
  log "Installing OS dependencies (Ubuntu) for various nodes"
  sudo apt-get update

  # Some distros use libgl1-mesa-glx, some use libgl1. Try both.
  set +e
  sudo DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    pkg-config \
    libcairo2 libcairo2-dev \
    libglib2.0-0 libglib2.0-dev \
    libpixman-1-0 libpixman-1-dev \
    libfreetype6 libfreetype6-dev \
    libpng-dev libjpeg-dev zlib1g-dev \
    libffi-dev \
    python3-dev \
    python-is-python3 \
    build-essential \
    cmake \
    meson \
    ninja-build \
    libgl1-mesa-glx >/dev/null 2>&1
  rc=$?
  set -e

  if [[ $rc -ne 0 ]]; then
    warn "libgl1-mesa-glx install failed; retrying with libgl1"
    sudo DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
      pkg-config \
      libcairo2 libcairo2-dev \
      libglib2.0-0 libglib2.0-dev \
      libpixman-1-0 libpixman-1-dev \
      libfreetype6 libfreetype6-dev \
      libpng-dev libjpeg-dev zlib1g-dev \
      libffi-dev \
      python3-dev \
      python-is-python3 \
      build-essential \
      cmake \
      meson \
      ninja-build \
      libgl1
  fi

  sudo rm -rf /var/lib/apt/lists/* || true
}

git_clone_or_update() {
  local url="$1"
  local dir="$2"
  local branch="${3:-main}"
  local depth="${4:-0}"

  if [[ -d "$dir/.git" ]]; then
    log "Updating $(basename "$dir")"
    git -C "$dir" fetch --all --prune
    # Try checkout branch if exists; ignore if repo uses different default
    git -C "$dir" checkout "$branch" >/dev/null 2>&1 || true
    git -C "$dir" pull --ff-only || true
  else
    log "Cloning $(basename "$dir")"
    if [[ "$depth" != "0" ]]; then
      git clone --depth "$depth" -b "$branch" "$url" "$dir"
    else
      git clone -b "$branch" "$url" "$dir"
    fi
  fi
}

pip_install_if_requirements() {
  local dir="$1"
  if [[ -f "$dir/requirements.txt" ]]; then
    log "Installing requirements for $(basename "$dir") (PyPI only)"
    # Correct syntax: "install" first, then --index-url (install option)
    pip_cmd install --isolated --index-url "$PIP_INDEX_URL" -r "$dir/requirements.txt"
  fi
}

run_install_py_if_exists() {
  local dir="$1"
  if [[ -f "$dir/install.py" ]]; then
    log "Running install.py for $(basename "$dir")"
    "$PY" "$dir/install.py"
  fi
}

install_node_repo() {
  local name="$1"
  local url="$2"
  local branch="${3:-main}"
  local depth="${4:-0}"
  local dir="$CUSTOM_NODES_DIR/$name"

  git_clone_or_update "$url" "$dir" "$branch" "$depth"
  pip_install_if_requirements "$dir"
  run_install_py_if_exists "$dir"
}

main() {
  need_cmd git
  need_cmd python3
  ensure_paths

  # Ensure venv pip toolchain is healthy
  log "Upgrading pip toolchain in venv"
  pip_cmd install -U pip wheel setuptools >/dev/null

  self_check
  apt_install_deps

  # Marker for some nodes/managers to skip downloading models (harmless otherwise)
  touch "$CUSTOM_NODES_DIR/skip_download_model" 2>/dev/null || true

  # ---- Manual installs (from your Dockerfile) ----
  install_node_repo "ComfyUI-ToSVG" "https://github.com/Yanick112/ComfyUI-ToSVG" "main"
  install_node_repo "ComfyUI-Lotus" "https://github.com/kijai/ComfyUI-Lotus" "main"
  install_node_repo "comfyui_bmad_nodes" "https://github.com/bmad4ever/comfyui_bmad_nodes" "main"
  install_node_repo "ComfyUI-KJNodes" "https://github.com/kijai/ComfyUI-KJNodes" "main"

  # deps already installed by apt_install_deps (matches your Dockerfile block)
  install_node_repo "comfyui_controlnet_aux" "https://github.com/Fannovel16/comfyui_controlnet_aux" "main"
  install_node_repo "ComfyUI-Marigold" "https://github.com/kijai/ComfyUI-Marigold" "main"
  install_node_repo "comfyui-various" "https://github.com/jamesWalker55/comfyui-various" "main"
  install_node_repo "ComfyUI-Light-Tool" "https://github.com/polpo-space/ComfyUI-Light-Tool.git" "main" "7"
  install_node_repo "ComfyUI-DepthAnythingV2" "https://github.com/kijai/ComfyUI-DepthAnythingV2.git" "main"
  install_node_repo "ComfyUI-DepthAnythingV3" "https://github.com/PozzettiAndrea/ComfyUI-DepthAnythingV3.git" "main"

  log "All nodes installed."

  cat <<EOF

Restart ComfyUI:
  sudo systemctl restart comfyui || true

EOF
}

main "$@"
