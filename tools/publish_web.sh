#!/bin/zsh
# Exporta el build Web y lo publica en la rama gh-pages (GitHub Pages).
set -e
cd "$(dirname "$0")/.."
GODOT=${GODOT:-~/Applications/Godot.app/Contents/MacOS/Godot}
rm -rf builds/web && mkdir -p builds/web
$GODOT --headless --path . --export-release "Web" builds/web/index.html
touch builds/web/.nojekyll
TMP=$(mktemp -d)
cp -R builds/web/. "$TMP"
cd "$TMP"
git init -q
git checkout -q -b gh-pages
git add -A
git commit -q -m "Build web $(date '+%Y-%m-%d %H:%M')"
git push -q -f "$(git -C "$OLDPWD" remote get-url origin)" gh-pages
echo "Publicado: https://$(git -C "$OLDPWD" remote get-url origin | sed -E 's#.*github.com[:/]([^/]+)/([^/.]+).*#\1.github.io/\2#')/"
