#!/bin/bash
# --- fill these two in ---
#offline_token="vSbkaz8jgwimH2iUC6kC8c2FBGyHnHEsevT5.9kCdDYARJW7-4jhundVsi3d6uJcedvg6td6HRBgAiCVa0L7Pyf7d8lc4c_3Qhey0WMYOGkwCHb3cn7lIKK6Lvc3rRne8bQ9doXToWAaMYa-lL-_dFJyXevRXbJ22ayVFmjv5fH7oBLyJNBA3bqdW5eSZmgrCo7dV-gMWpOOFkfFkORXphT-5x_rSmRVBiAeR8UrWwD9TdsW3g4RzrwQRL21B4uQW.-gK73t4rJVpsBs5ca30zg5al1Z511VMWVj-7ecZNvgbD-TM26af2nRPf0V8xOqaoP_xiboA8YGmgIpsyvF001y"
#checksum="675001a587c15f0c56c09beca6b1576c3be63cc4a0754e375ce93a6afda3dc8a"     # from developers.redhat.com download page
#dest="/home/libvirt/iso"        # where libvirt can see it
# -------------------------
# rhel-iso-download.sh — pull a Red Hat ISO by checksum via the Red Hat API
# Token comes from the RH_OFFLINE_TOKEN env var; checksum is passed at runtime.
#
# Usage:
#   export RH_OFFLINE_TOKEN='eyJhbGciOi...'      # set once per shell/session
#   ./rhel-iso-download.sh <sha256-checksum> [dest-dir]
#
# Example:
#   ./rhel-iso-download.sh c0dd53b7...2e1d2c80 /home/libvirt/iso

set -euo pipefail

# --- args & env -------------------------------------------------------------
checksum="${1:?Usage: $0 <sha256-checksum> [dest-dir]}"
dest="${2:-/home/libvirt/iso}"
: "${RH_OFFLINE_TOKEN:?Set RH_OFFLINE_TOKEN env var with your Red Hat offline token}"

# Basic sanity check: SHA-256 is 64 hex chars
if [[ ! "$checksum" =~ ^[0-9a-fA-F]{64}$ ]]; then
  echo "ERROR: '$checksum' is not a valid 64-char SHA-256 checksum." >&2
  exit 1
fi

command -v jq   >/dev/null || { echo "ERROR: jq not installed (sudo dnf install -y jq)"   >&2; exit 1; }
command -v curl >/dev/null || { echo "ERROR: curl not installed (sudo dnf install -y curl)" >&2; exit 1; }

mkdir -p "$dest"
cd "$dest"

# --- 1) offline token -> short-lived access token ---------------------------
echo "==> Requesting access token..."
access_token=$(curl -s \
  https://sso.redhat.com/auth/realms/redhat-external/protocol/openid-connect/token \
  -d grant_type=refresh_token -d client_id=rhsm-api \
  -d refresh_token="$RH_OFFLINE_TOKEN" | jq -r '.access_token')

if [[ -z "$access_token" || "$access_token" == "null" ]]; then
  echo "ERROR: Failed to get access token. Is RH_OFFLINE_TOKEN valid/current?" >&2
  exit 1
fi

# --- 2) resolve signed download URL + filename by checksum ------------------
echo "==> Resolving download URL for checksum $checksum ..."
image=$(curl -s -H "Authorization: Bearer $access_token" \
  "https://api.access.redhat.com/management/v1/images/$checksum/download")
filename=$(echo "$image" | jq -r '.body.filename')
url=$(echo "$image" | jq -r '.body.href')

if [[ -z "$url" || "$url" == "null" ]]; then
  echo "ERROR: API returned no download URL. Check the checksum is correct" >&2
  echo "       and that your account is entitled to this image." >&2
  echo "       API response was:" >&2
  echo "$image" | jq . >&2 || echo "$image" >&2
  exit 1
fi

# --- 3) download (resumable) ------------------------------------------------
echo "==> Downloading $filename ..."
curl --output "$filename" "$url" --continue-at -

# --- 4) verify integrity against the checksum we asked for ------------------
echo "==> Verifying SHA-256..."
actual=$(sha256sum "$filename" | awk '{print $1}')
if [[ "$actual" == "${checksum,,}" ]]; then
  echo "OK: checksum matches. Saved to $dest/$filename"
else
  echo "WARNING: checksum MISMATCH!" >&2
  echo "  expected: ${checksum,,}" >&2
  echo "  actual:   $actual" >&2
  exit 1
fi
