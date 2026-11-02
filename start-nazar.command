#!/bin/zsh
# Starts the NAZAR AI services and opens the console. Double-click in Finder.
# Expects the repos side by side: nazar/, nazar-vision/, nazar-agent/, nazar-console/
cd "$(dirname "$0")/.."
ROOT=$PWD
for s in "nazar-vision/Start Vision.command" "nazar-agent/Start Agent.command"; do
  if [[ -f "$ROOT/$s" ]]; then open "$ROOT/$s"; else echo "missing: $s"; fi
done
APP="$ROOT/nazar-console/build/NAZAR Console.app"
[[ -d /Applications/"NAZAR Console.app" ]] && APP=/Applications/"NAZAR Console.app"
if [[ -d "$APP" ]]; then open "$APP"; else echo "console app not built: run nazar-console/build.sh"; fi
