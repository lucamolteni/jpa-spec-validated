#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
lake build
lake env lean --run Lifecycle/Checks.lean
python3 scripts/check_spec.py
lake exe generate-book
python3 scripts/check_html.py
