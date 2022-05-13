#!/bin/sh

source SECRET.source_me

if [[ -z "${DEX_TOKEN}" ]]; then
  echo "Please ensure you have the env var 'DEX_TOKEN' defined before running."
  exit 1
fi

echo "Decoding:\n  $DEX_TOKEN\n"
echo "Decoded JWT text:"
jq -R 'split(".") | .[1] | @base64d | fromjson' <<< "$DEX_TOKEN"


