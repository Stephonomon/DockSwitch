#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

# Command Line Tools ship Testing.framework outside the default search paths,
# so point the compiler and linker at it explicitly.
CLT="$(xcode-select -p)"
FRAMEWORKS="$CLT/Library/Developer/Frameworks"
INTEROP_LIB_DIR="$CLT/Library/Developer/usr/lib"

exec xcrun swift test \
  -Xswiftc -F"$FRAMEWORKS" \
  -Xlinker -F"$FRAMEWORKS" \
  -Xlinker -rpath -Xlinker "$FRAMEWORKS" \
  -Xlinker -rpath -Xlinker "$INTEROP_LIB_DIR" \
  "$@"
