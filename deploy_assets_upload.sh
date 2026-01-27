#!/usr/bin/env bash
set -euo pipefail

REMOTE="${REMOTE:-evans@13.247.118.240}"
REMOTE_DIR="${REMOTE_DIR:-/tmp}"

PROJECT="$(pwd)"

SPA_OUT="spa.tgz"
CFG_OUT="config.tgz"
MOD_OUT="modules.tgz"

SPA_REMOTE="$REMOTE_DIR/spa.tgz"
CFG_REMOTE="$REMOTE_DIR/config.tgz"
MOD_REMOTE="$REMOTE_DIR/modules.tgz"

echo "📁 Using project directory:"
echo "   $PROJECT"
echo

pick_dir() {
  # usage: pick_dir "name" "primary" "fallback"
  local label="$1" p1="$2" p2="$3"
  if [ -d "$p1" ]; then
    echo "$p1"
  elif [ -d "$p2" ]; then
    echo "$p2"
  else
    echo ""
  fi
}

SPA_DIR="$(pick_dir "frontend" "frontend" "./frontend")"
CFG_DIR="$(pick_dir "configuration" "configuration" "backend/configuration")"
MOD_DIR="$(pick_dir "modules" "modules" "backend/modules")"

echo "🔎 Detected folders:"
echo "   SPA:           ${SPA_DIR:-❌ not found}"
echo "   configuration: ${CFG_DIR:-❌ not found}"
echo "   modules:       ${MOD_DIR:-❌ not found}"
echo

echo "What do you want to upload?"
echo "  [1] SPA (frontend)"
echo "  [2] configuration"
echo "  [3] modules"
echo "  [4] all"
read -p "👉 Selection (e.g. 1,3 or 4): " SEL

want_spa=false
want_cfg=false
want_mod=false

SEL="$(echo "$SEL" | tr -d '[:space:]')"
if [ "$SEL" = "4" ] || [ "$SEL" = "all" ] || [ "$SEL" = "ALL" ]; then
  want_spa=true; want_cfg=true; want_mod=true
else
  IFS=',' read -ra parts <<< "$SEL"
  for p in "${parts[@]}"; do
    case "$p" in
      1) want_spa=true ;;
      2) want_cfg=true ;;
      3) want_mod=true ;;
      *) echo "❌ Invalid option: $p"; exit 1 ;;
    esac
  done
fi

echo

# ---------- SPA ----------
if $want_spa; then
  if [ -z "$SPA_DIR" ]; then
    echo "❌ Cannot upload SPA: frontend directory not found (expected ./frontend)"
    exit 1
  fi
  echo "📦 Packaging SPA → $SPA_OUT (from $SPA_DIR) ..."
  rm -f "$SPA_OUT"
  tar -czf "$SPA_OUT" -C "$SPA_DIR" .
  echo "📤 Uploading $SPA_OUT → $REMOTE:$SPA_REMOTE"
  scp "$SPA_OUT" "$REMOTE:$SPA_REMOTE"
  echo "✅ SPA uploaded: $REMOTE:$SPA_REMOTE"
  echo
fi

# ---------- configuration ----------
if $want_cfg; then
  if [ -z "$CFG_DIR" ]; then
    echo "❌ Cannot upload configuration: directory not found (expected ./configuration or ./backend/configuration)"
    exit 1
  fi
  echo "📦 Packaging configuration → $CFG_OUT (from $CFG_DIR) ..."
  rm -f "$CFG_OUT"
  tar -czf "$CFG_OUT" -C "$CFG_DIR" .
  echo "📤 Uploading $CFG_OUT → $REMOTE:$CFG_REMOTE"
  scp "$CFG_OUT" "$REMOTE:$CFG_REMOTE"
  echo "✅ configuration uploaded: $REMOTE:$CFG_REMOTE"
  echo
fi

# ---------- modules ----------
if $want_mod; then
  if [ -z "$MOD_DIR" ]; then
    echo "❌ Cannot upload modules: directory not found (expected ./modules or ./backend/modules)"
    exit 1
  fi
  echo "📦 Packaging modules → $MOD_OUT (from $MOD_DIR) ..."
  rm -f "$MOD_OUT"
  tar -czf "$MOD_OUT" -C "$MOD_DIR" .
  echo "📤 Uploading $MOD_OUT → $REMOTE:$MOD_REMOTE"
  scp "$MOD_OUT" "$REMOTE:$MOD_REMOTE"
  echo "✅ modules uploaded: $REMOTE:$MOD_REMOTE"
  echo
fi

echo "✅ Upload complete."
echo "Remote files (if selected):"
$want_spa && echo "  - $SPA_REMOTE"
$want_cfg && echo "  - $CFG_REMOTE"
$want_mod && echo "  - $MOD_REMOTE"
