#!/bin/bash
set -euo pipefail

cd docs

# For each README.html in registry tree, also emit index.html so /dir/ URLs resolve
find registry -name 'README.html' | while read -r f; do
  d=$(dirname "$f")
  cp "$f" "$d/index.html"
  echo "Created $d/index.html from $f"
done

echo "Build finalization complete"
