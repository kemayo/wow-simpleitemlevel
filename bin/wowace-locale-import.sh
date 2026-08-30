#!/bin/bash

tempfile=$( mktemp )

cleanup() {
  rm -f $tempfile
  rm -f exported-locale-strings.lua
}
trap cleanup EXIT

do_import() {
  project="$1"
  handling="$2"
  namespace="$3"
  file="$4"
  : > "$tempfile"

  echo -n "Importing $namespace..."
  result=$( curl -sS -X POST -w "%{http_code}" -o "$tempfile" \
    -H "X-Api-Token: $CF_API_KEY" \
    -F "metadata={ language: \"enUS\", namespace: \"$namespace\", \"missing-phrase-handling\": \"$handling\" }" \
    -F "localizations=<$file" \
    "https://www.wowace.com/api/projects/$project/localization/import"
  ) || exit 1
  case $result in
    200) echo "done." ;;
    *)
      echo "error! ($result)"
      [ -s "$tempfile" ] && grep -q "errorMessage" "$tempfile" && cat "$tempfile" | jq --raw-output '.errorMessage'
      exit 1
      ;;
  esac
}

project=$( grep -oiP '##\s*X-Curse-Project-ID:\s*\K[0-9]+' ./*.toc | head -1 )
[ -n "$project" ] || { echo "no X-Curse-Project-ID in the toc"; exit 1; }

handling="${LOCALE_MISSING_PHRASE_HANDLING:-DoNothing}"

lua bin/find-locale-strings.lua || exit 1

do_import "$project" "$handling" "" "exported-locale-strings.lua"

exit 0
