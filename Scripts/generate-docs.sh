#!/usr/bin/env bash
set -euo pipefail

echo "Generating Jazzy docs..."
jazzy --clean --config .jazzy.yaml

# Enforce zero undocumented symbols by inspecting Jazzy's output JSON
if [ ! -f docs/undocumented.json ]; then
  echo "Error: docs/undocumented.json not found after Jazzy run" >&2
  exit 1
fi

ruby -rjson -e "j=JSON.parse(File.read('docs/undocumented.json')); w=j['warnings'] || []; if !w.empty?; STDERR.puts(\"Jazzy undocumented warnings: #{w.size}\"); w.first(50).each{|x| STDERR.puts(\"#{x['file']}:#{x['line']} #{x['symbol']} #{x['warning']}\")}; exit 1; end"
echo "Docs generated under ./docs"

