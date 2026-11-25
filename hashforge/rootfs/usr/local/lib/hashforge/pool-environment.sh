#!/usr/bin/env bash
# Turns the app's options into the settings the pool reads at start-up.
#
# Usage: pool-environment.sh <output directory>
#
# Writes one file per setting, named after the setting and holding its value, which is the layout
# s6-envdir loads. A file per setting copes with values that contain spaces, quotes or '#', where a
# shell-style list of NAME=value lines would need escaping.
set -euo pipefail

# shellcheck source=options.sh
source "$(dirname "${BASH_SOURCE[0]}")/options.sh"

[ "$#" -eq 1 ] || fail "usage: pool-environment.sh <output directory>"
output="$1"
secrets="$HASHFORGE_DATA/secrets"
# The fixed address Home Assistant's ingress gateway connects from.
INGRESS_GATEWAY="172.30.32.2"

setting() {
    printf '%s' "$2" > "$output/$1"
}

is_positive() {
    awk -v value="$1" 'BEGIN { exit !(value + 0 > 0) }'
}

# One of the four built-in pools. The Stratum ports are fixed inside the container; the host ports
# they are published on are chosen on the app's Network tab.
pool() {
    local index="$1" key="$2" scheme="$3" port="$4" enabled_by_default="$5"
    local enabled fee prefix="Mining__Pools__${index}__"

    enabled="$(option "${key}_enabled" "$enabled_by_default")"
    fee="$(option "${key}_fee_percent" 0)"
    if [ "$enabled" = "true" ] && is_positive "$fee" && [ -z "$fee_address" ]; then
        fail "The ${key} pool charges a fee of ${fee}%, so pool_fee_address must be set (or set ${key}_fee_percent to 0)."
    fi

    setting "${prefix}Name" "$key"
    setting "${prefix}Scheme" "$scheme"
    setting "${prefix}Enabled" "$enabled"
    setting "${prefix}Port" "$port"
    setting "${prefix}FeePercent" "$fee"
    setting "${prefix}FeeAddress" "$fee_address"
    if [ "$scheme" != "Solo" ]; then
        setting "${prefix}MaxCoinbaseOutputs" "$(option max_coinbase_outputs 500)"
    fi
}

bitcoin_node() {
    if uses_bundled_node; then
        setting BitcoinNode__RpcUrl "http://127.0.0.1:8332/"
        setting BitcoinNode__RpcUser "hashforge"
        setting BitcoinNode__RpcPassword "$(cat "$secrets/rpc_password")"
        # The node pushes each new block here the instant it arrives, so miners switch work without delay.
        setting BitcoinNode__ZmqBlockUrl "tcp://127.0.0.1:28332"
        return
    fi

    local user password
    user="$(option external_node_rpc_user)"
    password="$(option external_node_rpc_password)"
    if [ -z "$user" ] || [ -z "$password" ]; then
        fail "external_node_rpc_url is set, so external_node_rpc_user and external_node_rpc_password must be set too."
    fi

    setting BitcoinNode__RpcUrl "$(option external_node_rpc_url)"
    setting BitcoinNode__RpcUser "$user"
    setting BitcoinNode__RpcPassword "$password"
    # Optional: without it the pool still finds new blocks, by asking the node every few seconds.
    setting BitcoinNode__ZmqBlockUrl "$(option external_node_zmq_block_url)"
}

storage() {
    setting Persistence__RedisConnectionString "127.0.0.1:6379"
    setting Persistence__PostgresConnectionString \
        "Host=127.0.0.1;Database=hashforge;Username=hashforge;Password=$(cat "$secrets/postgres_password")"
}

pools() {
    fee_address="$(option pool_fee_address)"
    setting Mining__CoinbaseTag "$(option coinbase_tag "/HashForge/")"
    setting Mining__TemplateRefreshSeconds "$(option template_refresh_seconds 30)"
    setting Mining__NetworkStatsRefreshSeconds "$(option network_stats_refresh_seconds 30)"

    # Someone mining at home most likely wants a solo pool, so that is the only one on by default.
    pool 0 solo Solo 3333 true
    pool 1 pplns Pplns 3334 false
    pool 2 prop Prop 3335 false
    pool 3 bonus FinderBonus 3336 false
    setting Mining__Pools__1__PplnsWindowMultiplier "$(option pplns_window_multiplier 2)"
    setting Mining__Pools__3__FinderBonusSatoshis "$(option bonus_finder_satoshis 100000000)"

    setting Stratum__InitialDifficulty "$(option stratum_initial_difficulty 1024)"
    setting Stratum__MinDifficulty "$(option stratum_min_difficulty 0.001)"
}

notifications() {
    setting Notifications__DiscordWebhookUrl "$(option discord_webhook_url)"
    setting Notifications__NotifyBlockFound "$(option discord_notify_block_found true)"
    setting Notifications__NotifyBestShare "$(option discord_notify_best_share true)"
    setting Notifications__BestShareCooldownSeconds "$(option discord_best_share_cooldown_seconds 60)"
    setting Notifications__SenderName "$(option brand_name HashForge)"
}

branding() {
    setting Branding__Name "$(option brand_name HashForge)"
    setting Branding__Tagline "$(option brand_tagline "Open-source Bitcoin mining pool")"
    setting Branding__AccentColor "$(option brand_accent_color "#f7931a")"
    setting Branding__LogoUrl "$(option brand_logo_url)"
}

web() {
    local index=0 network
    setting ASPNETCORE_HTTP_PORTS "8080"
    setting Web__StratumHost "$(option stratum_host homeassistant.local)"
    setting Web__TrustedProxies__0 "$(option trusted_proxy)"
    while IFS= read -r network; do
        setting "Admin__AllowedNetworks__${index}" "$network"
        index=$((index + 1))
    done < <(option_list admin_networks)
    # Requests that come through Home Assistant's sidebar arrive from its ingress gateway, and Home
    # Assistant has already checked that the visitor is one of its administrators.
    setting "Admin__AllowedNetworks__${index}" "$INGRESS_GATEWAY/32"
    # The gateway strips its own prefix from the address and names it in this header; the pool needs it
    # back to write links that work inside Home Assistant.
    setting Web__PathBaseHeader "X-Ingress-Path"
    # The pool keeps the keys that protect its web forms under its home folder; in /data they survive updates.
    setting HOME "$HASHFORGE_DATA/pool"
}

rm -rf "$output"
mkdir -p "$output"
bitcoin_node
storage
pools
notifications
branding
web
