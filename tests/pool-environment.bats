#!/usr/bin/env bats
# Tests for the script that turns the app's options into the pool's settings.
# Run with: bats tests

setup() {
    script="$BATS_TEST_DIRNAME/../hashforge/rootfs/usr/local/lib/hashforge/pool-environment.sh"
    export HASHFORGE_DATA="$BATS_TEST_TMPDIR/data"
    export HASHFORGE_OPTIONS="$HASHFORGE_DATA/options.json"
    output_dir="$BATS_TEST_TMPDIR/environment"
    mkdir -p "$HASHFORGE_DATA/secrets"
    printf 'rpc-secret' > "$HASHFORGE_DATA/secrets/rpc_password"
    printf 'database-secret' > "$HASHFORGE_DATA/secrets/postgres_password"
    options '{}'
}

options() {
    printf '%s' "$1" > "$HASHFORGE_OPTIONS"
}

setting() {
    cat "$output_dir/$1"
}

@test "GIVEN_PoolEnvironment_WHEN_NoOptionsAreSet_THEN_OnlyTheSoloPoolIsEnabledWithNoFee" {
    run bash "$script" "$output_dir"

    [ "$status" -eq 0 ]
    [ "$(setting Mining__Pools__0__Name)" = "solo" ]
    [ "$(setting Mining__Pools__0__Scheme)" = "Solo" ]
    [ "$(setting Mining__Pools__0__Enabled)" = "true" ]
    [ "$(setting Mining__Pools__0__Port)" = "3333" ]
    [ "$(setting Mining__Pools__0__FeePercent)" = "0" ]
    [ "$(setting Mining__Pools__1__Enabled)" = "false" ]
    [ "$(setting Mining__Pools__2__Enabled)" = "false" ]
    [ "$(setting Mining__Pools__3__Enabled)" = "false" ]
}

@test "GIVEN_PoolEnvironment_WHEN_NoOptionsAreSet_THEN_EveryPoolHasItsOwnSchemeAndPort" {
    run bash "$script" "$output_dir"

    [ "$status" -eq 0 ]
    [ "$(setting Mining__Pools__1__Scheme)" = "Pplns" ]
    [ "$(setting Mining__Pools__1__Port)" = "3334" ]
    [ "$(setting Mining__Pools__2__Scheme)" = "Prop" ]
    [ "$(setting Mining__Pools__2__Port)" = "3335" ]
    [ "$(setting Mining__Pools__3__Scheme)" = "FinderBonus" ]
    [ "$(setting Mining__Pools__3__Port)" = "3336" ]
    [ "$(setting Mining__Pools__1__PplnsWindowMultiplier)" = "2" ]
    [ "$(setting Mining__Pools__3__FinderBonusSatoshis)" = "100000000" ]
}

@test "GIVEN_PoolEnvironment_WHEN_APoolIsSwitchedOff_THEN_FalseIsNotMistakenForUnset" {
    options '{"solo_enabled": false, "pplns_enabled": true}'

    run bash "$script" "$output_dir"

    [ "$status" -eq 0 ]
    [ "$(setting Mining__Pools__0__Enabled)" = "false" ]
    [ "$(setting Mining__Pools__1__Enabled)" = "true" ]
}

@test "GIVEN_PoolEnvironment_WHEN_NoExternalNodeIsSet_THEN_PoolUsesTheBundledNodeAndItsGeneratedPassword" {
    run bash "$script" "$output_dir"

    [ "$status" -eq 0 ]
    [ "$(setting BitcoinNode__RpcUrl)" = "http://127.0.0.1:8332/" ]
    [ "$(setting BitcoinNode__RpcUser)" = "hashforge" ]
    [ "$(setting BitcoinNode__RpcPassword)" = "rpc-secret" ]
    [ "$(setting BitcoinNode__ZmqBlockUrl)" = "tcp://127.0.0.1:28332" ]
}

@test "GIVEN_PoolEnvironment_WHEN_AnExternalNodeIsSet_THEN_PoolUsesItsAddressAndLogin" {
    options '{
        "external_node_rpc_url": "http://192.168.1.20:8332/",
        "external_node_rpc_user": "owner",
        "external_node_rpc_password": "p@ss word#1",
        "external_node_zmq_block_url": "tcp://192.168.1.20:28332"
    }'

    run bash "$script" "$output_dir"

    [ "$status" -eq 0 ]
    [ "$(setting BitcoinNode__RpcUrl)" = "http://192.168.1.20:8332/" ]
    [ "$(setting BitcoinNode__RpcUser)" = "owner" ]
    [ "$(setting BitcoinNode__RpcPassword)" = "p@ss word#1" ]
    [ "$(setting BitcoinNode__ZmqBlockUrl)" = "tcp://192.168.1.20:28332" ]
}

@test "GIVEN_PoolEnvironment_WHEN_AnExternalNodeHasNoBlockAnnouncements_THEN_ZmqAddressIsEmpty" {
    options '{
        "external_node_rpc_url": "http://192.168.1.20:8332/",
        "external_node_rpc_user": "owner",
        "external_node_rpc_password": "secret"
    }'

    run bash "$script" "$output_dir"

    [ "$status" -eq 0 ]
    [ -z "$(setting BitcoinNode__ZmqBlockUrl)" ]
}

@test "GIVEN_PoolEnvironment_WHEN_AnExternalNodeHasNoPassword_THEN_ItFailsAndSaysWhatIsMissing" {
    options '{"external_node_rpc_url": "http://192.168.1.20:8332/", "external_node_rpc_user": "owner"}'

    run bash "$script" "$output_dir"

    [ "$status" -ne 0 ]
    [[ "$output" == *"external_node_rpc_password"* ]]
}

@test "GIVEN_PoolEnvironment_WHEN_AnEnabledPoolChargesAFeeWithNoFeeAddress_THEN_ItFailsAndNamesThePool" {
    options '{"solo_fee_percent": 1.5}'

    run bash "$script" "$output_dir"

    [ "$status" -ne 0 ]
    [[ "$output" == *"solo"* ]]
    [[ "$output" == *"pool_fee_address"* ]]
}

@test "GIVEN_PoolEnvironment_WHEN_ADisabledPoolChargesAFeeWithNoFeeAddress_THEN_ItSucceeds" {
    options '{"pplns_fee_percent": 2}'

    run bash "$script" "$output_dir"

    [ "$status" -eq 0 ]
    [ "$(setting Mining__Pools__1__FeePercent)" = "2" ]
}

@test "GIVEN_PoolEnvironment_WHEN_AFeeAndFeeAddressAreSet_THEN_EveryPoolGetsTheAddress" {
    options '{"solo_fee_percent": 1.5, "pool_fee_address": "bc1qexample"}'

    run bash "$script" "$output_dir"

    [ "$status" -eq 0 ]
    [ "$(setting Mining__Pools__0__FeePercent)" = "1.5" ]
    [ "$(setting Mining__Pools__0__FeeAddress)" = "bc1qexample" ]
    [ "$(setting Mining__Pools__3__FeeAddress)" = "bc1qexample" ]
}

@test "GIVEN_PoolEnvironment_WHEN_AdminNetworksAreListed_THEN_EachGetsItsOwnNumberedSetting" {
    options '{"admin_networks": ["192.168.1.0/24", "10.0.0.0/8"]}'

    run bash "$script" "$output_dir"

    [ "$status" -eq 0 ]
    [ "$(setting Admin__AllowedNetworks__0)" = "192.168.1.0/24" ]
    [ "$(setting Admin__AllowedNetworks__1)" = "10.0.0.0/8" ]
}

@test "GIVEN_PoolEnvironment_WHEN_AdminNetworksAreListed_THEN_HomeAssistantsGatewayIsAllowedAfterThem" {
    options '{"admin_networks": ["192.168.1.0/24", "10.0.0.0/8"]}'

    run bash "$script" "$output_dir"

    [ "$status" -eq 0 ]
    [ "$(setting Admin__AllowedNetworks__2)" = "172.30.32.2/32" ]
    [ ! -e "$output_dir/Admin__AllowedNetworks__3" ]
}

@test "GIVEN_PoolEnvironment_WHEN_NoAdminNetworksAreListed_THEN_OnlyHomeAssistantsGatewayIsAllowed" {
    run bash "$script" "$output_dir"

    [ "$status" -eq 0 ]
    [ "$(setting Admin__AllowedNetworks__0)" = "172.30.32.2/32" ]
    [ ! -e "$output_dir/Admin__AllowedNetworks__1" ]
}

@test "GIVEN_PoolEnvironment_WHEN_ItRuns_THEN_PoolReadsItsSubPathFromHomeAssistantsHeader" {
    run bash "$script" "$output_dir"

    [ "$status" -eq 0 ]
    [ "$(setting Web__PathBaseHeader)" = "X-Ingress-Path" ]
}

@test "GIVEN_PoolEnvironment_WHEN_BrandingContainsSpacesQuotesAndHashes_THEN_ValuesAreKeptExactly" {
    options '{"brand_name": "Owen'"'"'s \"Pool\"", "brand_tagline": "Mine #1 at home", "brand_accent_color": "#00ff88"}'

    run bash "$script" "$output_dir"

    [ "$status" -eq 0 ]
    [ "$(setting Branding__Name)" = "Owen's \"Pool\"" ]
    [ "$(setting Branding__Tagline)" = "Mine #1 at home" ]
    [ "$(setting Branding__AccentColor)" = "#00ff88" ]
    [ "$(setting Notifications__SenderName)" = "Owen's \"Pool\"" ]
}

@test "GIVEN_PoolEnvironment_WHEN_AnOptionIsBlankOrNull_THEN_TheDefaultIsUsed" {
    options '{"brand_name": "", "coinbase_tag": null, "stratum_host": ""}'

    run bash "$script" "$output_dir"

    [ "$status" -eq 0 ]
    [ "$(setting Branding__Name)" = "HashForge" ]
    [ "$(setting Mining__CoinbaseTag)" = "/HashForge/" ]
    [ "$(setting Web__StratumHost)" = "homeassistant.local" ]
}

@test "GIVEN_PoolEnvironment_WHEN_ItRuns_THEN_StorageUsesTheGeneratedDatabasePasswordAndLocalServices" {
    run bash "$script" "$output_dir"

    [ "$status" -eq 0 ]
    [ "$(setting Persistence__RedisConnectionString)" = "127.0.0.1:6379" ]
    [ "$(setting Persistence__PostgresConnectionString)" = "Host=127.0.0.1;Database=hashforge;Username=hashforge;Password=database-secret" ]
    [ "$(setting HOME)" = "$HASHFORGE_DATA/pool" ]
    [ "$(setting ASPNETCORE_HTTP_PORTS)" = "8080" ]
}

@test "GIVEN_PoolEnvironment_WHEN_RunASecondTimeWithFewerNetworks_THEN_OldSettingsAreNotLeftBehind" {
    options '{"admin_networks": ["192.168.1.0/24", "10.0.0.0/8"]}'
    bash "$script" "$output_dir"
    options '{"admin_networks": ["192.168.1.0/24"]}'

    run bash "$script" "$output_dir"

    [ "$status" -eq 0 ]
    [ "$(setting Admin__AllowedNetworks__1)" = "172.30.32.2/32" ]
    [ ! -e "$output_dir/Admin__AllowedNetworks__2" ]
}

@test "GIVEN_PoolEnvironment_WHEN_ApiOriginsAreListed_THEN_EachGetsItsOwnNumberedSetting" {
    options '{"api_allowed_origins": ["https://stats.example.com", "http://localhost:5173"]}'

    run bash "$script" "$output_dir"

    [ "$status" -eq 0 ]
    [ "$(setting Web__ApiAllowedOrigins__0)" = "https://stats.example.com" ]
    [ "$(setting Web__ApiAllowedOrigins__1)" = "http://localhost:5173" ]
}

@test "GIVEN_PoolEnvironment_WHEN_NoApiOriginsAreListed_THEN_NoneAreSet" {
    run bash "$script" "$output_dir"

    [ "$status" -eq 0 ]
    [ ! -e "$output_dir/Web__ApiAllowedOrigins__0" ]
}

@test "GIVEN_PoolEnvironment_WHEN_NoOutputDirectoryIsGiven_THEN_ItFailsWithUsage" {
    run bash "$script"

    [ "$status" -ne 0 ]
    [[ "$output" == *"usage"* ]]
}
