#!/usr/bin/env bash
# Pre-flight cluster/storage health check and interactive PVE dist-upgrade
set -euo pipefail

echo "=== 1. Proxmox Version & Kernel ==="
pveversion
uname -r

echo -e "\n=== 2. Cluster Quorum & Node Status ==="
pvecm status | grep -E "Cluster name:|Quorate:|Nodes:|Expected votes:" || true
pvecm nodes

echo -e "\n=== 3. Storage Pool Status ==="
pvesm status

echo -e "\n=== 4. Local Running VMs & LXCs on $(hostname) ==="
qm list | awk 'NR==1 || /running/'
pct list | awk 'NR==1 || /running/'

echo -e "\n=== 5. Checking Pending Package Updates ==="
apt-get update -qq
UPDATES=$(apt list --upgradable 2>/dev/null | grep -v "^Listing..." || true)

if [[ -z "$UPDATES" ]]; then
  echo "System is completely up to date. No packages to install."
  exit 0
fi

echo "$UPDATES"

echo -e "\n------------------------------------------------------------"
read -rp "Migrate critical VMs off $(hostname) first if needed. Proceed with dist-upgrade? [y/N]: " CONFIRM
if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
  echo "Aborted by user."
  exit 0
fi

apt-get dist-upgrade -y
apt-get autoremove --purge -y

echo -e "\n=== 6. Post-Update Reboot Check ==="
if [[ -f /var/run/reboot-required ]]; then
  echo "WARNING: Reboot is REQUIRED on $(hostname) to load the new kernel/libraries."
  cat /var/run/reboot-required.pkgs 2>/dev/null || true
else
  echo "No reboot required on $(hostname)."
fi