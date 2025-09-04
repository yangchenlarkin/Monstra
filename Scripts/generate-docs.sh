#!/usr/bin/env bash
set -euo pipefail

echo "Generating Jazzy docs..."
jazzy --clean --config .jazzy.yaml
echo "Docs generated under ./docs"

