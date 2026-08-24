#!/usr/bin/env bash
# Regenerate the sourcemap and type-check src/ in strict mode.
# The sourcemap is what lets luau-lsp resolve require(script.Parent.Foo) to a
# real module, so it has to be rebuilt whenever files are added or moved.
set -e
cd "$(dirname "$0")/.."
.tools/rojo.exe sourcemap default.project.json -o sourcemap.json >/dev/null
if .tools/luau-lsp.exe analyze \
      --sourcemap=sourcemap.json \
      --definitions=.tools/globalTypes.d.luau \
      src/ 2>&1 | grep -vE '^\[(INFO|WARN)\]'; then
  echo "TYPECHECK: errors above"
  exit 1
fi
echo "TYPECHECK: clean ($(ls src/*/*.luau | wc -l) modules)"
