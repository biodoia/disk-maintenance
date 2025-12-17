#!/usr/bin/env bash
set -euo pipefail

cmd="${1:-install}"

SCRIPT_SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

install_files() {
  sudo install -d /usr/local/sbin
  sudo install -m 0755 "$SCRIPT_SRC_DIR/bin/disk-maintenance" /usr/local/sbin/disk-maintenance

  sudo install -d /etc
  if [[ ! -f /etc/disk-maintenance.conf ]]; then
    sudo install -m 0644 "$SCRIPT_SRC_DIR/etc/disk-maintenance.conf.example" /etc/disk-maintenance.conf
  fi

  sudo install -d /etc/systemd/system
  sudo install -m 0644 "$SCRIPT_SRC_DIR/systemd/"*.service /etc/systemd/system/
  sudo install -m 0644 "$SCRIPT_SRC_DIR/systemd/"*.timer /etc/systemd/system/

  sudo systemctl daemon-reload
  sudo systemctl enable --now disk-maintenance-report.timer disk-maintenance-cleanup.timer disk-maintenance-emergency.timer
}

uninstall_files() {
  sudo systemctl disable --now disk-maintenance-report.timer disk-maintenance-cleanup.timer disk-maintenance-emergency.timer || true

  sudo rm -f /etc/systemd/system/disk-maintenance-*.service /etc/systemd/system/disk-maintenance-*.timer
  sudo rm -f /usr/local/sbin/disk-maintenance

  sudo systemctl daemon-reload
}

case "$cmd" in
  install)
    install_files
    ;;
  uninstall)
    uninstall_files
    ;;
  *)
    echo "Usage: $0 [install|uninstall]" >&2
    exit 2
    ;;
esac
