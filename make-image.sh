#!/usr/bin/env bash
set -euo pipefail

# --- Usage -----------------------------------------------------------
usage() { echo "Usage: $0 <playbook> <size> [suffix]   (pass \"\" as suffix for a stable image name)"; exit 1; }
[[ $# -lt 2 ]] && usage

playbook="$1"
size="$2"
suffix="${3-$(date +%y%m%d-%H%M)}"   # explicit "" third arg means no suffix

# --- Validate ---------------------------------------------------------
[[ ! -f "$playbook" ]] && echo "Error: playbook '$playbook' not found" && exit 1

# --- Derive names -----------------------------------------------------
name=$(basename -- "${playbook%.yml}")
name="${name%.yaml}"
image="${name}${suffix:+-${suffix}}"
vm="${image}-build"            # build VM name; kept distinct from the image

# --- Cleanup trap -----------------------------------------------------
vm_created=false
cleanup() {
  if [[ "$vm_created" == "true" ]]; then
    echo "Cleaning up VM '$vm'..."
    machine0 stop "$vm" 2>/dev/null || true
    machine0 rm "$vm" -y 2>/dev/null || true
  fi
}
trap cleanup EXIT

# --- Pipeline ---------------------------------------------------------
echo "==> Creating VM '$vm' (size: $size)..."
machine0 new "$vm" --size "$size"
vm_created=true

echo "==> Provisioning '$playbook'..."
machine0 provision "$vm" "$playbook"

echo "==> Stopping VM..."
machine0 stop "$vm"

echo "==> Creating image '$image'..."
existing=false
machine0 images get "$image" >/dev/null 2>&1 && existing=true
machine0 images save "$vm" "$image"

# Saving onto an existing image name creates a DRAFT version — promote it so
# the new build becomes the version that `--image $image` resolves to.
if [[ "$existing" == "true" ]]; then
  draft=$(machine0 images versions ls "$image" --json | jq -r '[.[] | select(.status == "DRAFT")] | max_by(.version) | .version // empty')
  if [[ -n "$draft" && "$draft" != "null" ]]; then
    echo "==> Promoting draft version $draft of '$image'..."
    machine0 images versions promote "$image" "$draft"
  fi
fi

echo "==> Removing VM..."
machine0 rm "$vm" -y
vm_created=false               # Prevent trap from double-removing

echo "==> Done! Image '$image' is ready."
