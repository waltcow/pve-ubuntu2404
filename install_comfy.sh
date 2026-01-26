#!/usr/bin/env bash
set -euo pipefail

# install_comfyui.sh
#
# - pip.conf: PyPI primary + TUNA extra (speed)
# - But for some packages, TUNA may return 404 for wheel/metadata objects.
#   pip may pick TUNA candidate and fail without fallback.
#   Workaround:
#     1) Install comfyui-frontend-package from official PyPI with --isolated
#     2) Install remaining requirements from requirements.txt(with that line removed)
#     3) If still fails, retry remaining requirements using official PyPI only (--isolated)
#
# Usage:
#   bash install_comfyui.sh
#   COMFY_DIR=~/ComfyUI TORCH_CUDA=cu124 bash install_comfyui.sh
#   PYTHON_BIN=python3.11 bash install_comfyui.sh

COMFY_DIR="${COMFY_DIR:-$HOME/ComfyUI}"
PYTHON_BIN="${PYTHON_BIN:-python3}"     # python3 or python3.11
TORCH_CUDA="${TORCH_CUDA:-cu124}"       # cu121 or cu124
PORT="${PORT:-8188}"
LISTEN="${LISTEN:-0.0.0.0}"

# pip sources
PIP_INDEX_URL="${PIP_INDEX_URL:-https://pypi.org/simple}"
PIP_EXTRA_INDEX_URL="${PIP_EXTRA_INDEX_URL:-https://pypi.tuna.tsinghua.edu.cn/simple}"

# Known mirror-404 package in ComfyUI requirements (can override)
FRONTEND_PKG_NAME="${FRONTEND_PKG_NAME:-comfyui-frontend-package}"
FRONTEND_PKG_VER="${FRONTEND_PKG_VER:-1.37.11}"

log()  { printf "\n\033[1;32m==>\033[0m %s\n" "$*"; }
warn() { printf "\n\033[1;33m[WARN]\033[0m %s\n" "$*"; }

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || { echo "Missing command: $1" >&2; exit 1; }
}

ensure_sudo() {
  if ! command -v sudo >/dev/null 2>&1; then
    echo "sudo not found. Please install sudo or run as root." >&2
    exit 1
  fi
}

apt_install() {
  ensure_sudo
  sudo apt update
  sudo apt -y install --no-install-recommends "$@"
}

install_system_deps() {
  log "Installing system dependencies"
  apt_install \
    git curl ca-certificates \
    build-essential python3-dev \
    libgl1 libglib2.0-0
}

configure_pip_sources() {
  log "Configuring pip sources: primary=${PIP_INDEX_URL} extra=${PIP_EXTRA_INDEX_URL}"
  mkdir -p "$HOME/.config/pip"
  cat > "$HOME/.config/pip/pip.conf" <<EOF
[global]
index-url = ${PIP_INDEX_URL}
extra-index-url = ${PIP_EXTRA_INDEX_URL}
timeout = 120
retries = 10
EOF
}

ensure_python() {
  if command -v "$PYTHON_BIN" >/dev/null 2>&1; then
    return 0
  fi

  if [[ "$PYTHON_BIN" == "python3.11" ]]; then
    log "Python 3.11 not found. Installing python3.11 and venv support"
    apt_install python3.11 python3.11-venv python3.11-dev
    return 0
  fi

  echo "Python binary not found: ${PYTHON_BIN}" >&2
  exit 1
}

clone_or_update_comfyui() {
  if [[ -d "$COMFY_DIR/.git" ]]; then
    log "ComfyUI exists. Updating: $COMFY_DIR"
    git -C "$COMFY_DIR" pull --ff-only
  else
    log "Cloning ComfyUI: $COMFY_DIR"
    git clone https://github.com/comfyanonymous/ComfyUI.git "$COMFY_DIR"
  fi
}

create_venv() {
  log "Creating venv with ${PYTHON_BIN}"
  rm -rf "$COMFY_DIR/.venv"
  "$PYTHON_BIN" -m venv "$COMFY_DIR/.venv"

  # shellcheck disable=SC1090
  source "$COMFY_DIR/.venv/bin/activate"
  python -m pip install -U pip wheel setuptools
}

install_torch_cuda() {
  # shellcheck disable=SC1090
  source "$COMFY_DIR/.venv/bin/activate"

  log "Installing PyTorch (${TORCH_CUDA}) via extra index"
  pip install \
    --extra-index-url "https://download.pytorch.org/whl/${TORCH_CUDA}" \
    torch torchvision torchaudio
}

install_frontend_pkg_from_pypi_isolated() {
  # shellcheck disable=SC1090
  source "$COMFY_DIR/.venv/bin/activate"

  local spec="${FRONTEND_PKG_NAME}==${FRONTEND_PKG_VER}"
  log "Installing ${spec} from official PyPI with --isolated (ignore pip.conf to avoid mirror-404)"
  pip --isolated install -i "${PIP_INDEX_URL}" "${spec}"
}

make_requirements_without_frontend() {
  local req="$COMFY_DIR/requirements.txt"
  local out="$1"

  if [[ ! -f "$req" ]]; then
    echo "requirements.txt not found: $req" >&2
    exit 1
  fi

  # Remove the exact frontend line if present (case-insensitive, allow underscores/hyphens)
  # Examples:
  #   comfyui-frontend-package==1.37.11
  #   comfyui_frontend_package==1.37.11
  awk -v IGNORECASE=1 -v name="${FRONTEND_PKG_NAME}" '
    BEGIN {
      gsub("-", "[-_]", name)   # allow - or _
      pat="^"name"=="
    }
    $0 ~ pat { next }
    { print }
  ' "$req" > "$out"
}

install_remaining_requirements() {
  # shellcheck disable=SC1090
  source "$COMFY_DIR/.venv/bin/activate"

  local tmpreq=""
  tmpreq="$(mktemp)"
  trap 'rm -f "${tmpreq:-}"' RETURN

  make_requirements_without_frontend "$tmpreq"

  log "Installing remaining requirements (using pip.conf indexes: PyPI + TUNA)"
  set +e
  pip install -r "$tmpreq"
  local rc=$?
  set -e

  if [[ $rc -ne 0 ]]; then
    warn "Remaining requirements install failed. Retrying with official PyPI only (--isolated)."
    pip --isolated install -i "${PIP_INDEX_URL}" -r "$tmpreq"
  fi
}

verify_gpu() {
  log "Verifying NVIDIA driver and torch CUDA"
  if command -v nvidia-smi >/dev/null 2>&1; then
    nvidia-smi || true
  else
    warn "nvidia-smi not found. NVIDIA driver may not be installed inside VM."
  fi

  # shellcheck disable=SC1090
  source "$COMFY_DIR/.venv/bin/activate"
  python - <<'PY'
import torch
print("torch:", torch.__version__)
print("cuda available:", torch.cuda.is_available())
if torch.cuda.is_available():
    print("gpu:", torch.cuda.get_device_name(0))
PY
}

create_systemd_service() {
  ensure_sudo
  local svc="/etc/systemd/system/comfyui.service"
  log "Creating systemd service: ${svc}"

  sudo tee "$svc" >/dev/null <<EOF
[Unit]
Description=ComfyUI
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
WorkingDirectory=${COMFY_DIR}
Environment=PYTHONUNBUFFERED=1
ExecStart=${COMFY_DIR}/.venv/bin/python ${COMFY_DIR}/main.py --listen ${LISTEN} --port ${PORT}
Restart=always
RestartSec=3
User=$(id -un)

[Install]
WantedBy=multi-user.target
EOF

  sudo systemctl daemon-reload
  sudo systemctl enable --now comfyui
  sudo systemctl status comfyui --no-pager || true
}

print_run_hint() {
  cat <<EOF

Done.

Run (foreground):
  cd "${COMFY_DIR}"
  source .venv/bin/activate
  python main.py --listen ${LISTEN} --port ${PORT}

Service:
  sudo systemctl status comfyui --no-pager
  sudo journalctl -u comfyui -f

Open:
  http://<VM_IP>:${PORT}

EOF
}

main() {
  need_cmd git
  install_system_deps
  configure_pip_sources
  ensure_python
  clone_or_update_comfyui
  create_venv
  install_torch_cuda

  # Workaround for TUNA 404 on comfyui-frontend-package
  install_frontend_pkg_from_pypi_isolated
  install_remaining_requirements

  verify_gpu

  if command -v systemctl >/dev/null 2>&1; then
    create_systemd_service
  else
    warn "systemctl not found; skipping systemd service creation."
  fi

  print_run_hint
}

main "$@"