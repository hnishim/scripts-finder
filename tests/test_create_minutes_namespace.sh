#!/bin/bash
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "$0")" && pwd)
REPO_ROOT=$(cd -- "$SCRIPT_DIR/.." && pwd)
FEATURE_DIR="$REPO_ROOT/context-menu/create-minute-by-Gemini"
PYTHON_DIR="$FEATURE_DIR/python"
EXPECTED_NAMESPACE='my.gemini.minutes'
LEGACY_NAMESPACE='com.hnishim.create-minute-by-gemini'

python3 - "$PYTHON_DIR/setup.sh" "$PYTHON_DIR/run.sh" "$PYTHON_DIR/README.md" <<'PY'
import sys
from pathlib import Path

setup, run, readme = (Path(p) for p in sys.argv[1:])
expected = "my.gemini.minutes"
legacy = "com.hnishim.create-minute-by-gemini"

for path in (setup, run, readme):
    source = path.read_text(encoding="utf-8")
    if expected not in source:
        raise AssertionError(f"{path.name}: missing {expected}")
    if legacy in source:
        raise AssertionError(f"{path.name}: legacy namespace remains")
PY

TMP_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/hir129-gemini-namespace.XXXXXX")
trap 'rm -rf -- "$TMP_ROOT"' EXIT
fake_python="$TMP_ROOT/python3"
fake_bin="$TMP_ROOT/bin"
events="$TMP_ROOT/events"
home="$TMP_ROOT/home"
mkdir -p "$home" "$fake_bin"
: >"$events"

cat >"$fake_python" <<'PYTHON'
#!/bin/bash
set -euo pipefail
if [ "${1:-}" = "-c" ]; then
    exit 0
fi
if [ "${1:-}" = "-m" ] && [ "${2:-}" = "venv" ]; then
    target=$3
    printf 'venv:%s\n' "$target" >>"$FAKE_PYTHON_EVENTS"
    mkdir -p "$target/bin"
    cat >"$target/bin/python" <<'RUNTIME'
#!/bin/bash
set -euo pipefail
if [ "${1:-}" = "-m" ] && [ "${2:-}" = "pip" ]; then
    printf 'pip:%s\n' "$*" >>"$FAKE_PYTHON_EVENTS"
    exit 0
fi
printf 'runtime:%s\n' "$*" >>"$FAKE_PYTHON_EVENTS"
RUNTIME
    chmod 755 "$target/bin/python"
    exit 0
fi
exit 2
PYTHON
chmod 755 "$fake_python"

run_setup() {
    HOME="$home" PYTHON_BIN="$fake_python" FAKE_PYTHON_EVENTS="$events" \
        /bin/bash "$PYTHON_DIR/setup.sh"
}

run_setup
run_setup

new_runtime="$home/Library/Application Support/$EXPECTED_NAMESPACE"
old_runtime="$home/Library/Application Support/$LEGACY_NAMESPACE"
[ -x "$new_runtime/.venv/bin/python" ]
[ ! -e "$old_runtime" ]
[ "$(grep -c '^venv:' "$events")" -eq 1 ]

HOME="$home" FAKE_PYTHON_EVENTS="$events" /bin/bash "$PYTHON_DIR/run.sh" \
    ja "$TMP_ROOT/input.mp3"
[ "$(grep -c '^runtime:' "$events")" -eq 1 ]

cat >"$fake_bin/osascript" <<'OSA'
#!/bin/bash
exit 0
OSA
chmod 755 "$fake_bin/osascript"

before_runtime_count=$(grep -c '^runtime:' "$events")
set +e
PATH="$fake_bin:$PATH" HOME="$home" GEMINI_API_KEY_FOR_MINUTES='fixture-key' \
    FAKE_PYTHON_EVENTS="$events" /bin/bash "$FEATURE_DIR/create-minutes.sh" \
    >"$TMP_ROOT/create-minutes.out" 2>"$TMP_ROOT/create-minutes.err"
guard_status=$?
set -e
[ "$guard_status" -ne 0 ]
[ "$(grep -c '^runtime:' "$events")" -eq "$before_runtime_count" ]

printf '%s\n' '[PASS] create-minute-by-Gemini namespace and no-input guard contract'
