#!/usr/bin/env bash
# Pre-push check for the single-file apps.
#   tools/check.sh                      all of them
#   tools/check.sh path/to/file.html    just one
#
# Catches the two mistakes that have actually been written here: a dropped comma
# in an object literal, and a call to a function that does not exist. Both are
# invisible until the page runs in front of a student.
#
# Two traps this script has already fallen into, so do not "simplify" them away:
#  1. eslint IGNORES files outside its base path and only warns, so it must run
#     from the directory holding the file; otherwise everything reports clean.
#  2. A malformed config makes eslint throw, and an error that contains no
#     "no-undef" text also reports clean. Any non-zero exit without findings is
#     treated as a failure here, not a pass.
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

python3 - "$TMP" <<'PY'
import sys, io, json
G = ["window","document","navigator","location","history","localStorage","sessionStorage",
     "console","fetch","setTimeout","clearTimeout","setInterval","clearInterval","Date","Math",
     "JSON","Object","Array","String","Number","Boolean","Promise","Set","Map","RegExp","Error",
     "parseInt","parseFloat","isNaN","encodeURIComponent","decodeURIComponent","requestAnimationFrame",
     "addEventListener","removeEventListener","alert","confirm","prompt","Blob","File","FileReader",
     "URL","URLSearchParams","Image","crypto","ResizeObserver","MutationObserver","getComputedStyle",
     "innerWidth","innerHeight","scrollTo","print","matchMedia","structuredClone","TextEncoder",
     "TextDecoder","btoa","atob","HTMLAnchorElement","HTMLElement","Node","Intl","queueMicrotask",
     "performance","AbortController","CustomEvent","Event","FormData","DOMParser","XMLHttpRequest"]
cfg = ("export default [{\n"
       "  languageOptions: { ecmaVersion: 2023, sourceType: \"script\",\n"
       "    globals: " + json.dumps({g: "readonly" for g in G}, indent=0).replace("\n","") + " },\n"
       "  rules: { \"no-undef\": \"error\" }\n"
       "}];\n")
io.open(sys.argv[1] + "/eslint.config.mjs", "w", encoding="utf-8").write(cfg)
PY

fail=0
for f in "${FILES[@]}"; do
  [ -f "$f" ] || { echo "  skip (missing): $f"; continue; }
  base="$(basename "$f" .html)"
  python3 - "$f" "$TMP/$base.js" <<'PY'
import re, sys, io
s = io.open(sys.argv[1], encoding="utf-8").read()
js = "\n".join(m.group(1) for m in re.finditer(r'<script(?![^>]*\bsrc=)[^>]*>(.*?)</script>', s, re.S))
io.open(sys.argv[2], "w", encoding="utf-8").write(js)
PY
  printf '%-34s ' "$base"
  if ! err=$(node --check "$TMP/$base.js" 2>&1); then
    echo "SYNTAX ERROR"; printf '%s\n' "$err" | head -4 | sed 's/^/      /'; fail=1; continue
  fi
  if [ ! -x "$ESLINT" ]; then echo "syntax ok (eslint not found — no-undef NOT checked)"; continue; fi
  out=$(cd "$TMP" && "$ESLINT" --no-config-lookup -c eslint.config.mjs "$base.js" 2>&1); rc=$?
  if printf '%s\n' "$out" | grep -q "outside of base path"; then
    echo "LINTER IGNORED THE FILE — not a clean result"; fail=1; continue
  fi
  n=$(printf '%s\n' "$out" | grep -cE "no-undef" || true)
  if [ "${n:-0}" -gt 0 ]; then
    echo "$n undefined reference(s)"
    printf '%s\n' "$out" | grep -E "no-undef" | head -8 | sed 's/^/      /'; fail=1; continue
  fi
  if [ $rc -ne 0 ]; then
    echo "LINTER FAILED (exit $rc) — not a clean result"; printf '%s\n' "$out" | head -4 | sed 's/^/      /'; fail=1; continue
  fi
  echo "ok"
done
[ $fail -eq 0 ] && echo "ALL CLEAN" || echo "PROBLEMS ABOVE"
exit $fail
