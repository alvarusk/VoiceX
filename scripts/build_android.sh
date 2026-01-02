#!/usr/bin/env bash
# Build Android release with optional dart-defines for secrets.
# Usage:
#   chmod +x scripts/build_android.sh
#   ./scripts/build_android.sh --supabase-url "https://xxx.supabase.co" --supabase-key "..." \
#     --r2-account "..." --r2-access "..." --r2-secret "..." --r2-bucket "voicex-video" --r2-public "https://pub-xxxx.r2.dev"

set -euo pipefail

SUPABASE_URL=""
SUPABASE_KEY=""
R2_ACCOUNT=""
R2_ACCESS=""
R2_SECRET=""
R2_BUCKET=""
R2_PUBLIC=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --supabase-url) SUPABASE_URL="$2"; shift 2;;
    --supabase-key) SUPABASE_KEY="$2"; shift 2;;
    --r2-account) R2_ACCOUNT="$2"; shift 2;;
    --r2-access) R2_ACCESS="$2"; shift 2;;
    --r2-secret) R2_SECRET="$2"; shift 2;;
    --r2-bucket) R2_BUCKET="$2"; shift 2;;
    --r2-public) R2_PUBLIC="$2"; shift 2;;
    *) echo "Unknown arg: $1" && exit 1;;
  esac
done

DEFINES=()
[[ -n "$SUPABASE_URL" ]] && DEFINES+=("--dart-define=SUPABASE_URL=$SUPABASE_URL")
[[ -n "$SUPABASE_KEY" ]] && DEFINES+=("--dart-define=SUPABASE_ANON_KEY=$SUPABASE_KEY")
[[ -n "$R2_ACCOUNT" ]] && DEFINES+=("--dart-define=R2_ACCOUNT_ID=$R2_ACCOUNT")
[[ -n "$R2_ACCESS" ]] && DEFINES+=("--dart-define=R2_ACCESS_KEY=$R2_ACCESS")
[[ -n "$R2_SECRET" ]] && DEFINES+=("--dart-define=R2_SECRET_KEY=$R2_SECRET")
[[ -n "$R2_BUCKET" ]] && DEFINES+=("--dart-define=R2_BUCKET=$R2_BUCKET")
[[ -n "$R2_PUBLIC" ]] && DEFINES+=("--dart-define=R2_PUBLIC_BASE=$R2_PUBLIC")

echo "Building Android APK release..."
flutter build apk --release "${DEFINES[@]}"

echo "Optionally build App Bundle for Play Store..."
flutter build appbundle --release "${DEFINES[@]}"

echo "Done. APK in build/app/outputs/flutter-apk/, AAB in build/app/outputs/bundle/release/."
