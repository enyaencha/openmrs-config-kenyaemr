#!/usr/bin/env bash
set -euo pipefail

REMOTE="evans@13.247.118.240"
OUT="/tmp/spa.tgz"
PROJECT="$(pwd)"

echo "📁 Using project directory:"
echo "   $PROJECT"
echo

# sanity check
if [ ! -d "frontend" ]; then
  echo "❌ frontend/ directory not found in $PROJECT"
  exit 1
fi

echo "📦 Packaging frontend → spa.tgz ..."
tar -czf spa.tgz -C frontend .

echo "📤 Uploading spa.tgz to $REMOTE:$OUT ..."
scp spa.tgz "$REMOTE:$OUT"

echo
echo "✅ Upload complete"
echo "➡️  Remote file: $REMOTE:$OUT"
