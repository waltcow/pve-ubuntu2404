#!/usr/bin/env bash
set -euo pipefail

# install_filebrowser.sh
#
# Install File Browser on Ubuntu 24.04 and configure a systemd service.
#
# Usage:
#   bash install_filebrowser.sh
#   FILEBROWSER_ROOT=/data FILEBROWSER_PORT=8081 bash install_filebrowser.sh
#   FILEBROWSER_VERSION=v2.27.0 FILEBROWSER_DOWNLOAD_BASE=https://ghproxy.com/https://github.com/filebrowser/filebrowser/releases/download bash install_filebrowser.sh

FILEBROWSER_USER="${FILEBROWSER_USER:-filebrowser}"
FILEBROWSER_GROUP="${FILEBROWSER_GROUP:-filebrowser}"
FILEBROWSER_ROOT="${FILEBROWSER_ROOT:-/srv}"
FILEBROWSER_ADDRESS="${FILEBROWSER_ADDRESS:-0.0.0.0}"
FILEBROWSER_PORT="${FILEBROWSER_PORT:-8080}"
FILEBROWSER_DB_DIR="${FILEBROWSER_DB_DIR:-/var/lib/filebrowser}"
FILEBROWSER_DB_PATH="${FILEBROWSER_DB_PATH:-$FILEBROWSER_DB_DIR/filebrowser.db}"
FILEBROWSER_BIN_PATH="${FILEBROWSER_BIN_PATH:-/usr/local/bin/filebrowser}"
FILEBROWSER_SERVICE_NAME="${FILEBROWSER_SERVICE_NAME:-filebrowser}"
FILEBROWSER_VERSION="${FILEBROWSER_VERSION:-}"
FILEBROWSER_DOWNLOAD_BASE="${FILEBROWSER_DOWNLOAD_BASE:-https://github.com/filebrowser/filebrowser/releases/download}"

log() { printf "\n\033[1;32m==>\033[0m %s\n" "$*"; }
die() { printf "\n\033[1;31m[ERR]\033[0m %s\n" "$*" >&2; exit 1; }

need_cmd() { command -v "$1" >/dev/null 2>&1 || die "Missing command: $1"; }

install_deps() {
  need_cmd sudo
  log "Installing dependencies"
  sudo apt-get update
  sudo DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    curl ca-certificates tar
  sudo rm -rf "/var/lib/apt/lists/"* || true
}

install_filebrowser() {
  local tag=""
  local latest_url=""
  local arch=""
  local tmpdir=""
  local file=""
  local url=""

  if [[ -n "$FILEBROWSER_VERSION" ]]; then
    tag="$FILEBROWSER_VERSION"
  else
    latest_url="$(curl -fsSL -o /dev/null -w '%{url_effective}' \
      "https://github.com/filebrowser/filebrowser/releases/latest")"
    tag="${latest_url##*/}"
  fi

  [[ -n "$tag" ]] || die "Unable to resolve latest tag. Set FILEBROWSER_VERSION explicitly."

  case "$(uname -m)" in
    *aarch64*|arm64) arch="arm64" ;;
    *64*) arch="amd64" ;;
    *86*) arch="386" ;;
    *armv5*) arch="armv5" ;;
    *armv6*) arch="armv6" ;;
    *armv7*) arch="armv7" ;;
    *) die "Unsupported architecture: $(uname -m)" ;;
  esac

  file="linux-${arch}-filebrowser.tar.gz"
  url="${FILEBROWSER_DOWNLOAD_BASE}/${tag}/${file}"

  log "Downloading File Browser: ${url}"
  tmpdir="$(mktemp -d)"
  curl -fsSL "$url" -o "$tmpdir/$file"
  tar -xzf "$tmpdir/$file" -C "$tmpdir" "filebrowser"
  chmod +x "$tmpdir/filebrowser"
  sudo mv "$tmpdir/filebrowser" "$FILEBROWSER_BIN_PATH"
  rm -rf "$tmpdir"

  if [[ ! -x "$FILEBROWSER_BIN_PATH" ]]; then
    if command -v filebrowser >/dev/null 2>&1; then
      FILEBROWSER_BIN_PATH="$(command -v filebrowser)"
    else
      die "File Browser binary not found after install"
    fi
  fi
}

ensure_user_and_dirs() {
  log "Creating system user/group and directories"
  if ! getent group "$FILEBROWSER_GROUP" >/dev/null 2>&1; then
    sudo groupadd --system "$FILEBROWSER_GROUP"
  fi
  if ! id -u "$FILEBROWSER_USER" >/dev/null 2>&1; then
    sudo useradd --system --no-create-home --shell "/usr/sbin/nologin" \
      --gid "$FILEBROWSER_GROUP" "$FILEBROWSER_USER"
  fi

  sudo mkdir -p "$FILEBROWSER_ROOT" "$FILEBROWSER_DB_DIR"
  sudo chown -R "$FILEBROWSER_USER":"$FILEBROWSER_GROUP" "$FILEBROWSER_ROOT" "$FILEBROWSER_DB_DIR"
}

write_systemd_unit() {
  log "Writing systemd unit: ${FILEBROWSER_SERVICE_NAME}.service"
  sudo tee "/etc/systemd/system/${FILEBROWSER_SERVICE_NAME}.service" >/dev/null <<EOF
[Unit]
Description=File Browser
After=network-online.target
Wants=network-online.target

[Service]
User=${FILEBROWSER_USER}
Group=${FILEBROWSER_GROUP}
Environment=FB_ADDRESS=${FILEBROWSER_ADDRESS}
Environment=FB_PORT=${FILEBROWSER_PORT}
Environment=FB_ROOT=${FILEBROWSER_ROOT}
Environment=FB_DATABASE=${FILEBROWSER_DB_PATH}
ExecStart=${FILEBROWSER_BIN_PATH}
Restart=on-failure
RestartSec=5s
NoNewPrivileges=true

[Install]
WantedBy=multi-user.target
EOF
}

enable_service() {
  log "Enabling and starting service"
  sudo systemctl daemon-reload
  sudo systemctl enable --now "${FILEBROWSER_SERVICE_NAME}.service"
}

main() {
  install_deps
  install_filebrowser
  ensure_user_and_dirs
  write_systemd_unit
  enable_service

  cat <<EOF

File Browser is running.
  Address: http://${FILEBROWSER_ADDRESS}:${FILEBROWSER_PORT}
  Root:    ${FILEBROWSER_ROOT}
  DB:      ${FILEBROWSER_DB_PATH}

First boot:
  The admin password is printed once in the service logs:
    sudo journalctl -u ${FILEBROWSER_SERVICE_NAME}.service -n 50 --no-pager
EOF
}

main "$@"
