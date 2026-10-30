#!/usr/bin/env bash
# Runs the PDF engine tests against the host PDFium build that pdfium_dart's
# build hook downloads into .dart_tool/ (macOS or Linux).
set -euo pipefail
cd "$(dirname "$0")/.."
lib=$(find .dart_tool -name 'libpdfium.dylib' -path '*mac-*' 2>/dev/null | head -1)
[ -z "$lib" ] && lib=$(find .dart_tool -name 'libpdfium.so' -path '*linux-x64*' 2>/dev/null | head -1)
if [ -z "$lib" ]; then
  echo "No host PDFium found. Run 'flutter build apk --debug' or 'flutter test' once so the build hook downloads it." >&2
  exit 1
fi
PDFIUM_PATH="$PWD/$lib" flutter test test/core/pdf_engine_host_test.dart test/core/pdf_stamper_host_test.dart "$@"
