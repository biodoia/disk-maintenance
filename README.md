# disk-maintenance
Aggressive-but-safe disk space maintenance for Linux desktops/servers (Manjaro/Arch friendly).

Features:
- **Learning mode**: periodic, report-only metrics logged to journald + JSONL history.
- **Cleanup mode**: runs only when `/` is above a threshold (default 85%).
- **Emergency mode**: kicks in at critical thresholds and runs bounded cleanup + generates a headless triage report via an agent CLI (optional).

## Install
```sh
sudo ./install.sh
```

## Configure
Edit `/etc/disk-maintenance.conf`.

Recommended knobs:
- `CLEANUP_THRESHOLD_PCT` (default 85)
- `EMERGENCY_THRESHOLD_PCT` (default 95)
- `EMERGENCY_MIN_FREE_BYTES` (default 1 GiB)
- `EMERGENCY_WEBHOOK_URL` (optional)
- `AGENT_CLI` (`codex` or `opencode` or `none`)

## Manual runs
```sh
sudo /usr/local/sbin/disk-maintenance report
sudo /usr/local/sbin/disk-maintenance cleanup
sudo /usr/local/sbin/disk-maintenance emergency
```

## Logs
```sh
journalctl -u disk-maintenance-\*.service
```

## Uninstall
```sh
sudo ./install.sh uninstall
```
