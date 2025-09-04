#!/usr/bin/env bash
set -euo pipefail

echo "Generating Jazzy docs..."
# Fail the build if there are documentation warnings (e.g., undocumented symbols)
jazzy --clean --config .jazzy.yaml --fail-on-warnings
echo "Docs generated under ./docs"

