#!/usr/bin/env bash
# FR-PRT-07 / FR-UNL-07 (RELEASE_V1_4): passwords are never logged. Fails
# (exit 1) on any logging call that mentions a password on the same line, in
# the app and in the native plugin (Dart, Kotlin, Swift).
set -euo pipefail
cd "$(dirname "$0")/.."
log='(\bprint\(|debugPrint\(|\blog\(|\bLog\.[a-z]+\(|\blogger\.|AppLog\.|println\(|NSLog\(|os_log\(|Logger\(|\.(debug|info|warning|error|notice)\()'
bad=$(grep -rnEi "$log.*passw|passw.*$log" lib packages/docukit_native/lib packages/docukit_native/android/src \
  packages/docukit_native/ios --include='*.dart' --include='*.kt' --include='*.swift' || true)
if [ -n "$bad" ]; then
  echo "Logging call that mentions a password (FR-PRT-07):"
  echo "$bad"
  exit 1
fi
echo "no password logging OK"
