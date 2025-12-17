#!/usr/bin/env bash
set -euo pipefail

# This script is intentionally NOT invoked by timers.
# It is a manual helper to move Docker's data-root off /var/lib/docker.

if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
  exec sudo "$0" "$@"
fi

NEW_ROOT="${1:-}"
if [[ -z "$NEW_ROOT" ]]; then
  echo "Usage: $0 /path/to/new/docker-root" >&2
  exit 2
fi

if [[ ! -d "$NEW_ROOT" ]]; then
  echo "Creating $NEW_ROOT" >&2
  install -d -m 0711 "$NEW_ROOT"
fi

echo "Stopping docker" >&2
systemctl stop docker || true

echo "Copying /var/lib/docker -> $NEW_ROOT" >&2
rsync -aHAX --numeric-ids /var/lib/docker/ "$NEW_ROOT/"

echo "Configuring /etc/docker/daemon.json data-root" >&2
install -d -m 0755 /etc/docker

if [[ -f /etc/docker/daemon.json ]]; then
  cp -a /etc/docker/daemon.json "/etc/docker/daemon.json.bak.$(date +%Y%m%dT%H%M%S)"
fi

NEW_ROOT="$NEW_ROOT" python3 - <<'PY'
import json,os
path='/etc/docker/daemon.json'
new_root=os.environ['NEW_ROOT']
try:
  with open(path,'r') as f:
    data=json.load(f)
except FileNotFoundError:
  data={}
except json.JSONDecodeError:
  data={}

data['data-root']=new_root
with open(path,'w') as f:
  json.dump(data,f,indent=2)
  f.write('\n')
PY

echo "Starting docker" >&2
systemctl start docker

echo "Done. Verify with: docker info | grep 'Docker Root Dir'" >&2
echo "If everything works, you can later remove old data at /var/lib/docker manually." >&2
