#!/usr/bin/env bash
set -euo pipefail

# ===== CONFIG=====
REPO_URL="https://github.com/detilyganska/KNESS_test.git"
APP_DIR="/opt/app"

# Postgres creds stored as docker secrets files inside APP_DIR/secrets
PG_USER="appuser"
PG_PASS="appuser"

# Which linux user should be able to run docker without sudo
# If you connect via browser-SSH, it's usually your username (check in console)
DOCKER_USER="${DOCKER_USER:-syshmaks}"
# =================================

log() { echo "[startup] $*"; }

log "Detecting OS..."
if [[ ! -f /etc/os-release ]]; then
  log "ERROR: /etc/os-release not found"
  exit 1
fi
. /etc/os-release
if [[ "${ID:-}" != "ubuntu" ]]; then
  log "ERROR: This script supports Ubuntu only. Detected: ID=${ID:-unknown}"
  exit 1
fi

log "Updating apt + installing base packages..."
apt-get update -y
apt-get install -y ca-certificates curl gnupg git

log "Installing Docker Engine + Compose plugin..."
install -m 0755 -d /etc/apt/keyrings
if [[ ! -f /etc/apt/keyrings/docker.gpg ]]; then
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  chmod a+r /etc/apt/keyrings/docker.gpg
fi

CODENAME="$(. /etc/os-release && echo "$VERSION_CODENAME")"
cat >/etc/apt/sources.list.d/docker.list <<EOF
deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu ${CODENAME} stable
EOF

apt-get update -y
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

log "Enabling + starting Docker..."
systemctl enable --now docker

log "Ensuring user '${DOCKER_USER}' exists..."
if id "${DOCKER_USER}" >/dev/null 2>&1; then
  log "User ${DOCKER_USER} exists."
else
  log "User ${DOCKER_USER} not found. Creating it..."
  useradd -m -s /bin/bash "${DOCKER_USER}"
fi

log "Adding '${DOCKER_USER}' to docker group..."
usermod -aG docker "${DOCKER_USER}" || true

log "Preparing app directory: ${APP_DIR}"
mkdir -p "${APP_DIR}"
chown -R "${DOCKER_USER}:${DOCKER_USER}" "${APP_DIR}"

if [[ -d "${APP_DIR}/.git" ]]; then
  log "Repo exists, pulling updates..."
  sudo -u "${DOCKER_USER}" git -C "${APP_DIR}" pull --ff-only || true
else
  log "Cloning repo..."
  sudo -u "${DOCKER_USER}" git clone "${REPO_URL}" "${APP_DIR}"
fi

log "Creating secrets for Postgres..."
mkdir -p "${APP_DIR}/secrets"
printf "%s" "${PG_USER}" > "${APP_DIR}/secrets/postgres_user.txt"
printf "%s" "${PG_PASS}" > "${APP_DIR}/secrets/postgres_password.txt"
chmod 600 "${APP_DIR}/secrets/postgres_user.txt" "${APP_DIR}/secrets/postgres_password.txt"
chown -R "${DOCKER_USER}:${DOCKER_USER}" "${APP_DIR}/secrets"

log "Bringing up docker compose (build + detached)..."
cd "${APP_DIR}"
sudo -u "${DOCKER_USER}" docker compose up -d --build

log "docker compose ps:"
sudo -u "${DOCKER_USER}" docker compose ps || true

log "Configuring UFW if active (open tcp/80 and tcp/22)..."
if command -v ufw >/dev/null 2>&1; then
  if ufw status | grep -qi "Status: active"; then
    ufw allow 80/tcp || true
    ufw allow 22/tcp || true
    ufw reload || true
    log "UFW active -> ensured ports 80/tcp and 22/tcp are allowed."
  else
    log "UFW installed but not active. Skipping."
  fi
else
  log "UFW not installed. Skipping."
fi

log "Local health check:"
curl -sI http://localhost/ | head -n 5 || true

