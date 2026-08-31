#!/bin/bash
#
# Pull the current translations from WowAce straight into the checked-out
# locale/<lang>.lua files, so a translator can run the addon from a repo
# checkout and still see their own language without building a package.
#
# The packager normally does this at release time by expanding the
# @localization@ marker in each locale file; this does the same expansion
# locally. It rewrites tracked files in place, so don't commit the result:
#
#   ./bin/wowace-locale-export.sh              # every language the addon ships
#   ./bin/wowace-locale-export.sh deDE frFR    # just these
#   ./bin/wowace-locale-export.sh --pin deDE   # ...and hide the local edit from git
#   ./bin/wowace-locale-export.sh --unpin      # stop hiding the edits
#   ./bin/wowace-locale-export.sh --reset      # restore locale/ from HEAD
#
# --pin sets skip-worktree so `git status` stays clean and you can't commit the
# fill by accident; the tradeoff is that `git pull` will complain if it needs to
# touch a pinned file, so --unpin (or --reset) before pulling locale changes.
#
# Needs a personal WowAce API token in CF_API_KEY, from
# https://www.wowace.com/account/api-tokens

set -u

site="https://www.wowace.com"
localedir="locale"

cd "$( dirname "$0" )/.." || exit 1

pin=
case "${1:-}" in
  --reset)
    git update-index --no-skip-worktree "$localedir"/*.lua 2>/dev/null
    git checkout -- "$localedir" && echo "restored $localedir/ from HEAD"
    exit $?
    ;;
  --unpin)
    git update-index --no-skip-worktree "$localedir"/*.lua && echo "unpinned $localedir/*.lua"
    exit $?
    ;;
  --pin)
    pin=1
    shift
    ;;
esac

project=$( sed -n 's/.*X-Curse-Project-ID:[[:space:]]*\([0-9][0-9]*\).*/\1/p' ./*.toc | head -1 )
[ -n "$project" ] || { echo "no X-Curse-Project-ID in the toc" >&2; exit 1; }

# The languages the addon actually ships, read from the locale XML.
known=$( sed -n 's/.*AllowLoadTextLocale \([A-Za-z]*\).*/\1/p' "$localedir"/*.xml | sort -u | tr '\n' ' ' )

if [ "$#" -gt 0 ]; then
  targets="$*"
else
  targets="$known"
fi

[ -n "${CF_API_KEY:-}" ] || { echo "set CF_API_KEY to a WowAce API token (https://www.wowace.com/account/api-tokens)" >&2; exit 1; }

body=$( mktemp )
clean=$( mktemp )
trap 'rm -f "$body" "$clean"' EXIT

status=0
for lang in $targets; do
  file="$localedir/$lang.lua"

  case " $known " in
    *" $lang "*) ;;
    *) echo "skip $lang: not listed in $localedir/*.xml" >&2; status=1; continue ;;
  esac
  if ! grep -q -- '--@localization(' "$file" 2>/dev/null; then
    echo "skip $lang: no @localization marker in $file (run --reset first?)" >&2
    status=1
    continue
  fi

  printf '%s' "$lang... "
  code=$( curl -sS -w '%{http_code}' -o "$body" \
    -H "X-Api-Token: $CF_API_KEY" \
    "$site/api/projects/$project/localization/export?lang=$lang&unlocalized=Ignore" ) || { status=1; echo "request failed"; continue; }
  if [ "$code" != "200" ] || grep -qi '<!doctype\|<html' "$body"; then
    echo "error! ($code)"
    [ -s "$body" ] && grep -q errorMessage "$body" && { command -v jq >/dev/null && jq -r .errorMessage "$body" || cat "$body"; }
    status=1
    continue
  fi

  # Keep everything up to and including the marker, drop whatever a previous
  # run appended after it, then splice the fetched strings in. Reading the
  # translations with getline avoids awk treating backslashes as escapes.
  tr -d '\r' < "$body" > "$clean"
  awk -v tf="$clean" '
    { print }
    /^[[:space:]]*--@localization\(/ {
      while ((getline line < tf) > 0) print line
      close(tf)
      exit
    }
  ' "$file" > "$file.tmp" && mv "$file.tmp" "$file"
  [ -n "$pin" ] && git update-index --skip-worktree "$file"

  echo "$( grep -c '^L\[' "$file" ) strings"
done

if [ "$status" -eq 0 ]; then
  if [ -n "$pin" ]; then
    echo "done -- pinned; --unpin (or --reset) before pulling locale changes"
  else
    echo "done -- $localedir/ is modified locally; 'git checkout -- $localedir/' or --reset to undo"
  fi
fi
exit $status
