#!/bin/sh
# Healthy once the node answers RPC. It may still be synchronising; the pool handles that itself.
set -eu

curl --silent --fail --max-time 8 \
    --user "${RPC_USER}:${RPC_PASSWORD}" \
    --header 'content-type: text/plain' \
    --data-binary '{"jsonrpc":"1.0","id":"health","method":"getblockcount","params":[]}' \
    http://127.0.0.1:8332/ > /dev/null
