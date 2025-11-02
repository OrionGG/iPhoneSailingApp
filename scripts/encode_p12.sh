#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -lt 1 ]; then
  echo "Usage: $0 <file> [out_file]"
  exit 2
fi

INFILE="$1"
OUTFILE="-"
if [ "$#" -ge 2 ]; then
  OUTFILE="$2"
fi

if [ ! -f "$INFILE" ]; then
  echo "File not found: $INFILE" >&2
  exit 1
fi

# macOS base64 wraps lines by default; produce a single-line base64 string
if command -v base64 >/dev/null 2>&1; then
  B64=$(base64 "$INFILE" | tr -d '\n')
else
  # fallback
  B64=$(openssl base64 -in "$INFILE" | tr -d '\n')
fi

if [ "$OUTFILE" = "-" ]; then
  printf "%s" "$B64"
else
  printf "%s" "$B64" > "$OUTFILE"
  echo "Wrote base64 to $OUTFILE"
fi

echo "# Example macOS usage:`n# ./encode_p12.sh mycert.p12 > p12_base64.txt`"
