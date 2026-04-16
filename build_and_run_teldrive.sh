#!/bin/bash
set -euo pipefail

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RUNTIME_DIR="$BASE_DIR/runtime"
UI_DIR="/www/wwwroot/marks.ia.br/marks/ecosystem/systems/teldrive-ui"
COMPOSE_FILE="$RUNTIME_DIR/docker-compose.yml"

log() { echo "[teldrive] $*"; }

ensure_dirs() {
  mkdir -p "$RUNTIME_DIR/postgres_data" "$RUNTIME_DIR/backups" "$RUNTIME_DIR/logs"
}

build_ui_assets() {
  if [[ -d "$UI_DIR" ]]; then
    log "building teldrive-ui marksdrive"
    cd "$UI_DIR"
    npm install --legacy-peer-deps
    npm run build

    log "syncing ui/dist to backend"
    mkdir -p "$BASE_DIR/ui/dist"
    rm -rf "$BASE_DIR/ui/dist"/*
    cp -a "$UI_DIR/dist/." "$BASE_DIR/ui/dist/"
  else
    log "teldrive-ui dir not found, skipping local UI build"
  fi
}

build_backend() {
  log "building backend marksdrive"
  build_ui_assets
  cd "$BASE_DIR"
  GOTOOLCHAIN=local /usr/local/go/bin/go mod download
  GOTOOLCHAIN=local /usr/local/go/bin/go mod tidy
  nice -n 10 ionice -c2 -n7 env GOTOOLCHAIN=local GOMAXPROCS=1 GOFLAGS='-p=1' CGO_ENABLED=0 GOOS=linux GOARCH=amd64 /usr/local/go/bin/go build -o marksdrive .
}

compose_up() {
  ensure_dirs
  cd "$RUNTIME_DIR"
  docker compose --env-file .env -f "$COMPOSE_FILE" up -d
}

compose_down() {
  cd "$RUNTIME_DIR"
  docker compose --env-file .env -f "$COMPOSE_FILE" down
}

compose_restart() {
  compose_down || true
  compose_up
}

compose_status() {
  cd "$RUNTIME_DIR"
  docker compose --env-file .env -f "$COMPOSE_FILE" ps
}

compose_logs() {
  cd "$RUNTIME_DIR"
  docker compose --env-file .env -f "$COMPOSE_FILE" logs --tail=100 -f
}

backup_pgdata() {
  ensure_dirs
  ts=$(date +%Y%m%d_%H%M%S)
  backup_file="$RUNTIME_DIR/backups/postgres_data_${ts}.tar.gz"
  tar -czf "$backup_file" -C "$RUNTIME_DIR" postgres_data
  log "backup created: $backup_file"
}

cmd="${1:-status}"
case "$cmd" in
  build)
    build_backend
    ;;
  install)
    ensure_dirs
    compose_up
    ;;
  start)
    compose_up
    ;;
  stop)
    compose_down
    ;;
  restart)
    compose_restart
    ;;
  status)
    compose_status
    ;;
  logs)
    compose_logs
    ;;
  backup)
    backup_pgdata
    ;;
  *)
    echo "Usage: $0 {build|install|start|stop|restart|status|logs|backup}"
    exit 1
    ;;
esac
