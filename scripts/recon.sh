#!/bin/bash
# ─────────────────────────────────────────────────────
# GemeniFlow — recon.sh
# Automated recon pipeline for bug bounty hunting
# Usage: ./recon.sh target.com
# Run from: ~/hunts/target.com/
# GitHub: https://github.com/OmaRrAlaa101/gemeniflow
# ─────────────────────────────────────────────────────

set -e

DOMAIN=$1

if [ -z "$DOMAIN" ]; then
  echo ""
  echo "  Usage: $0 target.com"
  echo ""
  exit 1
fi

# ── Tool check — fail early if anything is missing ──
MISSING=0
for tool in subfinder assetfinder amass httpx katana gau; do
  if ! command -v $tool &>/dev/null; then
    echo "✗ MISSING: $tool"
    echo "  Install guide: docs/methodology.md → Prerequisites"
    MISSING=1
  fi
done
[ $MISSING -eq 1 ] && exit 1

# ── Create folder structure ─────────────────────────
mkdir -p ./targets/$DOMAIN/{raw,processed,notes}

echo ""
echo "  ═══════════════════════════════════════"
echo "  GemeniFlow Recon — $DOMAIN"
echo "  ═══════════════════════════════════════"
echo ""

# ── 1. Subdomain enumeration ────────────────────────
echo "[1/6] Subfinder..."
subfinder -d $DOMAIN -silent > ./targets/$DOMAIN/raw/subs.txt

echo "[2/6] Assetfinder..."
assetfinder --subs-only $DOMAIN >> ./targets/$DOMAIN/raw/subs.txt

echo "[3/6] Amass passive (5 min timeout)..."
timeout 300 amass enum -passive -d $DOMAIN >> ./targets/$DOMAIN/raw/subs.txt || true

echo "      Deduplicating..."
sort -u ./targets/$DOMAIN/raw/subs.txt \
  -o ./targets/$DOMAIN/processed/unique_subs.txt

# ── 2. Live host check ──────────────────────────────
echo "[4/6] Live host check (httpx)..."
cat ./targets/$DOMAIN/processed/unique_subs.txt \
  | httpx -silent \
          -mc 200,301,302,403,401 \
          -title \
          -tech-detect \
          -status-code \
          -follow-redirects \
  > ./targets/$DOMAIN/processed/live.txt

# ── 3. Endpoint discovery ───────────────────────────
echo "[5/6] Endpoint crawl (katana, depth 3)..."
cat ./targets/$DOMAIN/processed/live.txt \
  | awk '{print $1}' \
  | katana -silent -d 3 -jc \
  > ./targets/$DOMAIN/processed/endpoints.txt

echo "[6/6] Historical URLs (gau)..."
cat ./targets/$DOMAIN/processed/unique_subs.txt \
  | gau --blacklist png,jpg,gif,svg,woff,woff2,ttf,css,ico \
  >> ./targets/$DOMAIN/processed/endpoints.txt

sort -u ./targets/$DOMAIN/processed/endpoints.txt \
  -o ./targets/$DOMAIN/processed/endpoints_unique.txt

# ── Summary ─────────────────────────────────────────
echo ""
echo "  ═══════════════════════════════════════"
echo "  Done: $DOMAIN"
echo "  ═══════════════════════════════════════"
printf "  %-22s %s\n" "Raw subdomains:"    "$(wc -l < ./targets/$DOMAIN/raw/subs.txt)"
printf "  %-22s %s\n" "Unique subdomains:" "$(wc -l < ./targets/$DOMAIN/processed/unique_subs.txt)"
printf "  %-22s %s\n" "Live hosts:"        "$(wc -l < ./targets/$DOMAIN/processed/live.txt)"
printf "  %-22s %s\n" "Unique endpoints:"  "$(wc -l < ./targets/$DOMAIN/processed/endpoints_unique.txt)"
echo "  ═══════════════════════════════════════"
echo ""
echo "  Output files:"
echo "    ./targets/$DOMAIN/processed/live.txt"
echo "    ./targets/$DOMAIN/processed/endpoints_unique.txt"
echo ""
echo "  Next step — feed output to Gemini CLI:"
echo "    cd ~/hunts/$DOMAIN && gemini"
echo ""
