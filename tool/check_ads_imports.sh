#!/usr/bin/env bash
# ADS.md §7 isolation rule: only lib/core/ads/ may import the ads and purchase
# SDKs. Fails (exit 1) and lists offending files otherwise.
set -euo pipefail
cd "$(dirname "$0")/.."
bad=$(grep -rlE "package:(google_mobile_ads|in_app_purchase)" lib --include='*.dart' | grep -v '^lib/core/ads/' || true)
if [ -n "$bad" ]; then
  echo "google_mobile_ads / in_app_purchase imported outside lib/core/ads/:"
  echo "$bad"
  exit 1
fi
echo "ads imports OK"
