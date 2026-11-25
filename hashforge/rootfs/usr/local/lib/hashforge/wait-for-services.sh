#!/usr/bin/env bash
# Blocks until Redis and the Bitcoin node answer, because the pool expects both to be there when it
# starts. The node may still be synchronising; the pool copes with that itself.
set -euo pipefail

# shellcheck source=options.sh
source /usr/local/lib/hashforge/options.sh

settings="$HASHFORGE_RUN/pool-environment"

node_answers() {
    curl --silent --fail --max-time 8 \
        --user "$(cat "$settings/BitcoinNode__RpcUser"):$(cat "$settings/BitcoinNode__RpcPassword")" \
        --header 'content-type: text/plain' \
        --data-binary '{"jsonrpc":"1.0","id":"hashforge","method":"getblockcount","params":[]}' \
        "$(cat "$settings/BitcoinNode__RpcUrl")" > /dev/null
}

until redis-cli -h 127.0.0.1 ping > /dev/null 2>&1; do
    sleep 1
done

waited=0
until node_answers; do
    # A node with a large chain can spend several minutes checking its files before it answers.
    if [ $((waited % 30)) -eq 0 ]; then
        log "Waiting for the Bitcoin node at $(cat "$settings/BitcoinNode__RpcUrl") to answer"
    fi
    sleep 5
    waited=$((waited + 5))
done
