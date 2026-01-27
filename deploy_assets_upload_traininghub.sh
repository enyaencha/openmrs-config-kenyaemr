#!/usr/bin/env bash
set -euo pipefail

# Remote deployment target (Ubuntu server)
REMOTE_USER="${REMOTE_USER:-ubuntu}"
REMOTE_HOST="${REMOTE_HOST:-13.247.5.151}"
REMOTE_PORT="${REMOTE_PORT:-22}"

# SSH key is expected to exist on the LOCAL machine (home directory)
SSH_KEY="${SSH_KEY:-$HOME/training-instance.pem}"

REMOTE="${REMOTE_USER}@${REMOTE_HOST}"
REMOTE_DIR="${REMOTE_DIR:-/tmp}"

PROJECT="$(pwd)"

SPA_OUT="spa.tgz"
CFG_OUT="config.tgz"
MOD_OUT="modules.tgz"

SPA_REMOTE="$REMOTE_DIR/spa.tgz"
CFG_REMOTE="$REMOTE_DIR/config.tgz"
MOD_REMOTE="$REMOTE_DIR/modules.tgz"

# SSH/SCP common options
SSH_OPTS=(-i "$SSH_KEY" -p "$REMOTE_PORT" -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new)
SCP_OPTS=(-i "$SSH_KEY" -P "$REMOTE_PORT" -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new)

echo "📁 Using project directory:"
echo "   $PROJECT"
echo

# ---- Preflight checks ----
[ -f "$SSH_KEY" ] || {
  echo "❌ SSH key not found: $SSH_KEY"
  echo "   Expected key in local home directory"
  exit 1
}

chmod 600 "$SSH_KEY" 2>/dev/null || true

echo "🔐 Preflight SSH to $REMOTE_HOST..."
if ! ssh "${SSH_OPTS[@]}" -o BatchMode=yes -o ConnectTimeout=10 "$REMOTE" "echo '✅ SSH OK on ' \$(hostname)" >/dev/null; then
  echo "❌ SSH preflight failed."
  echo "   Check: correct user ($REMOTE_USER), correct key ($SSH_KEY), server has your public key, and security group allows SSH."
  exit 1
fi
echo "✅ SSH preflight OK"
echo

pick_dir() {
  # usage: pick_dir "name" "primary" "fallback"
  local _label="$1" p1="$2" p2="$3"
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

upload_one() {
  local label="$1" src_dir="$2" out_tgz="$3" remote_path="$4"
  [ -n "$src_dir" ] || { echo "❌ Cannot upload $label: source directory not found."; exit 1; }

  echo "📦 Packaging $label → $out_tgz (from $src_dir) ..."
  rm -f "$out_tgz"
  tar -czf "$out_tgz" -C "$src_dir" .

  echo "📤 Uploading $out_tgz → $REMOTE:$remote_path"
  scp "${SCP_OPTS[@]}" "$out_tgz" "$REMOTE:$remote_path"
  echo "✅ $label uploaded: $REMOTE:$remote_path"
  echo
}

# ---------- SPA ----------
if $want_spa; then
  upload_one "SPA" "$SPA_DIR" "$SPA_OUT" "$SPA_REMOTE"
fi

# ---------- configuration ----------
if $want_cfg; then
  upload_one "configuration" "$CFG_DIR" "$CFG_OUT" "$CFG_REMOTE"
fi

# ---------- modules ----------
if $want_mod; then
  upload_one "modules" "$MOD_DIR" "$MOD_OUT" "$MOD_REMOTE"
fi

echo "✅ Upload complete."
echo "Remote files (if selected):"
$want_spa && echo "  - $SPA_REMOTE"
$want_cfg && echo "  - $CFG_REMOTE"
$want_mod && echo "  - $MOD_REMOTE"

