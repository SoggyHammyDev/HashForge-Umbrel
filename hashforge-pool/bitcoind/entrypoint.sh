#!/bin/sh
# Starts Bitcoin Core from environment variables so the same image serves every network.
set -eu

: "${RPC_USER:?RPC_USER must be set}"
: "${RPC_PASSWORD:?RPC_PASSWORD must be set}"

NETWORK="${NETWORK:-mainnet}"
PRUNE_MB="${PRUNE_MB:-550}"
BLOCK_RESERVED_WEIGHT="${BLOCK_RESERVED_WEIGHT:-100000}"
DB_CACHE_MB="${DB_CACHE_MB:-450}"

case "$NETWORK" in
    mainnet) NETWORK_FLAG="" ;;
    testnet | testnet4) NETWORK_FLAG="-testnet4" ;;
    signet) NETWORK_FLAG="-signet" ;;
    regtest) NETWORK_FLAG="-regtest" ;;
    *) echo "Unknown NETWORK '$NETWORK' (use mainnet, testnet4, signet or regtest)" >&2; exit 1 ;;
esac

# Bitcoin Core stores a salted hash of the RPC password rather than the password itself.
SALT="$(openssl rand -hex 16)"
HASH="$(printf '%s' "$RPC_PASSWORD" | openssl dgst -sha256 -hmac "$SALT" | sed 's/^.* //')"

# PRUNE_MB=0 keeps every block (a full archival node); anything else is the disk budget for blocks in MiB.
if [ "$PRUNE_MB" = "0" ]; then
    PRUNE_FLAG="-prune=0"
    echo "Starting Bitcoin Core on $NETWORK as a full node"
else
    PRUNE_FLAG="-prune=$PRUNE_MB"
    echo "Starting Bitcoin Core on $NETWORK as a pruned node (${PRUNE_MB} MiB of blocks)"
fi

# The data folder is mounted from the host and may be owned by anyone, so claim it, then give up root.
RUN_AS=""
if [ "$(id -u)" = "0" ]; then
    chown bitcoin:bitcoin /data
    RUN_AS="setpriv --reuid=bitcoin --regid=bitcoin --init-groups"
fi

# shellcheck disable=SC2086 # RUN_AS and NETWORK_FLAG are intentionally unquoted so empty values add no arguments.
exec $RUN_AS bitcoind \
    $NETWORK_FLAG \
    -datadir=/data \
    -printtoconsole \
    -server=1 \
    -rpcauth="${RPC_USER}:${SALT}\$${HASH}" \
    -disablewallet=1 \
    -rpcbind=0.0.0.0 \
    -rpcallowip=10.0.0.0/8 \
    -rpcallowip=172.16.0.0/12 \
    -rpcallowip=192.168.0.0/16 \
    -rpcport=8332 \
    -port=8333 \
    -listenonion=0 \
    -zmqpubhashblock=tcp://0.0.0.0:28332 \
    -dbcache="$DB_CACHE_MB" \
    -blockreservedweight="$BLOCK_RESERVED_WEIGHT" \
    "$PRUNE_FLAG" \
    "$@"
