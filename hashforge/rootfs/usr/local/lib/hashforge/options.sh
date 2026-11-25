#!/usr/bin/env bash
# Shared by every script in the app: where things live and how to read the options Home Assistant saves.
# Sourced, never run.

export PATH="/command:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

# Home Assistant writes the user's settings here and keeps /data across restarts and updates.
HASHFORGE_OPTIONS="${HASHFORGE_OPTIONS:-/data/options.json}"
HASHFORGE_DATA="${HASHFORGE_DATA:-/data}"
# Rebuilt on every start, so nothing secret in it outlives the container.
HASHFORGE_RUN="${HASHFORGE_RUN:-/run/hashforge}"

log() {
    echo "[hashforge] $*"
}

fail() {
    echo "[hashforge] ERROR: $*" >&2
    exit 1
}

# Prints an option's value, or the fallback when the option is missing, null or blank.
# A plain `.name // fallback` would not do: it also replaces a deliberate `false`.
option() {
    local name="$1" fallback="${2-}"
    jq --raw-output --arg name "$name" --arg fallback "$fallback" '
        if has($name) and .[$name] != null and .[$name] != "" then .[$name] else $fallback end
    ' "$HASHFORGE_OPTIONS"
}

# Prints each entry of a list option on its own line; nothing when the list is missing or empty.
option_list() {
    local name="$1"
    jq --raw-output --arg name "$name" '(.[$name] // [])[] | select(. != null and . != "")' "$HASHFORGE_OPTIONS"
}

# The app runs its own Bitcoin node unless the user points it at one they already have.
uses_bundled_node() {
    [ -z "$(option external_node_rpc_url)" ]
}
