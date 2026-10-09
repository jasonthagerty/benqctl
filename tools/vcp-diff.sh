#!/usr/bin/env bash
# Map BenQ vendor VCP codes by diffing snapshots taken around an OSD change.
# Usage: vcp-diff.sh            -> snapshot, wait for you to change one OSD setting, snapshot, diff
#        vcp-diff.sh snap FILE  -> write a single snapshot to FILE
set -euo pipefail

BUS="${BENQ_BUS:-$(ddcutil detect --terse 2>/dev/null | awk '/I2C bus:/{b=$3} /Monitor:.*RD280U/{sub("/dev/i2c-","",b); print b; exit}')}"
CODES=(10 12 14 16 18 1A 52 60 62 72 86 87 8A 8D C9 CA CC D1 D2 D7 D9 DC E1 E2 E3 E5 E6 E7 E9 EB EE EF F0 F1 F8 FD)

snap() {
  for c in "${CODES[@]}"; do
    printf '%s %s\n' "$c" "$(ddcutil --bus "$BUS" getvcp "$c" --terse 2>&1 | cut -d' ' -f3- | tr '\n' ' ')"
  done
}

if [[ "${1:-}" == snap ]]; then
  snap > "$2"
  exit
fi

before=$(mktemp); after=$(mktemp)
trap 'rm -f "$before" "$after"' EXIT
echo "Snapshotting..." >&2
snap > "$before"
read -rp "Change ONE setting in the monitor OSD, then press Enter: " _
snap > "$after"
diff --unchanged-line-format= --old-line-format='- %L' --new-line-format='+ %L' "$before" "$after" || true
