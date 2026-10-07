#!/usr/bin/env bash
# Pre-push check for the single-file apps. Run from anywhere:
#   tools/check.sh                 # all of them
#   tools/check.sh bda-planner/bda-planner.html
#
# Catches the two kinds of mistake that have actually shipped here: a syntax
# error (a dropped comma in an object literal) and a call to a function that
# does not exist (readsPanel). Both are invisible until the page runs.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ESLINT="/home/todd/Repos/allegory-app/node_modules/.bin/eslint"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
FILES=("$@")
if [ ${#FILES[@]} -eq 0 ]; then
  FILES=( "$ROOT/bda-planner/bda-planner.html"
          "$ROOT/week-7-research-questions/research-question-studio.html"
          "$ROOT/week-7-research-questions/wk7day2.html"
          "$ROOT/week-7-research-questions/from-noticing-to-question.html" )
fi
cat > "$TMP/eslint.config.mjs" <<'CFG'
export default [{
  languageOptions: {
    ecmaVersion: 2023, sourceType: "script",
    globals: Object.fromEntries([
      "window","document","navigator","location","localStorage","sessionStorage",
      "console","fetch","setTimeout","clearTimeout","setInterval","clearInterval",
      "requestAnimationFrame","addEventListener","removeEventListener","alert","confirm",
      "prompt","Blob","File","FileReader","URL","Image","crypto","ResizeObserver",
      "getComputedStyle","innerWidth","innerHeight","print","matchMedia","structuredClone",
      "TextEncoder","TextDecoder","btoa","atob","HTMLAnchorElement","Intl","queueMicrotask",
days   ].map(g => [g, "readonly"]))
  },
  rules: { "no-undef": "error" }
}];
CFG
sed -i '/^days/d' "$TMP/eslint.config.mjs"
fail=0
for f in "${FILES[@]}"; do
  [ -f "$f" ] || { echo "  skip (missing): $f"; continue; }
  base="$(basename "$f" .html)"
  python3 - "$f" "$TMP/$base.js" <<'PY'
import re,sys,io
s=io.open(sys.argv[1],encoding="utf-8").read()
js="\n".join(m.group(1) for m in re.finditer(r'<script(?![^>]*\bsrc=)[^>]*>(.*?)</script>', s, re.S))
io.open(sys.argv[2],"w",encoding="utf-8").write(js)
PY
  printf '%-34s ' "$base"
  if ! err=$(node --check "$TMP/$base.js" 2>&1); then
    echo "SYNTAX ERROR"; echo "$err" | head -4 | sed 's/^/      /'; fail=1; continue
  fi
  if [ -x "$ESLINT" ]; then
    out=$("$ESLINT" --no-config-lookup -c "$TMP/eslint.config.mjs" "$TMP/$base.js" 2>&1)
    n=$(printf '%s\n' "$out" | grep -cE "no-undef" || true)
    if [ "${n:-0}" -gt 0 ]; then
      echo "$n undefined reference(s)"
      printf '%s\n' "$out" | grep -E "no-undef" | sed "s|$TMP/||" | head -8 | sed 's/^/      /'
      fail=1; continue
    fi
  fi
  echo "ok"
done
[ $fail -eq 0 ] && echo "ALL CLEAN" || echo "PROBLEMS ABOVE"
exit $fail
