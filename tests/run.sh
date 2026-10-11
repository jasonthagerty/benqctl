#!/usr/bin/env bash
# Runs the QML unit and integration tests. Integration tests run the widget's
# backend against bin/ddcutil, a fake that answers from fixtures/.
# Extra arguments go to qmltestrunner, e.g. "-functions" or "-input tests/tst_runner.qml".
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"

runner="${QMLTESTRUNNER:-$(command -v qmltestrunner6 || command -v qmltestrunner || echo /usr/lib/qt6/bin/qmltestrunner)}"
FAKE_DDCUTIL_DIR="$(mktemp -d)"
trap 'rm -rf "$FAKE_DDCUTIL_DIR"' EXIT

export FAKE_DDCUTIL_DIR
export PATH="$here/bin:$PATH"
export QML_XHR_ALLOW_FILE_READ=1
export QT_QPA_PLATFORM="${QT_QPA_PLATFORM:-offscreen}"
export QT_FORCE_STDERR_LOGGING=1

if [[ " $* " != *" -input "* ]]; then
  set -- -input "$here" "$@"
fi
exec "$runner" "$@"
