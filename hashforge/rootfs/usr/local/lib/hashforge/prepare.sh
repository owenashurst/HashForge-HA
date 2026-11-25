#!/usr/bin/env bash
# Runs once at start-up, before any service: lays out /data, makes the passwords the services use to
# talk to each other, creates the database on first run and works out the pool's settings.
set -euo pipefail

# shellcheck source=options.sh
source /usr/local/lib/hashforge/options.sh

secrets="$HASHFORGE_DATA/secrets"

# Creates a folder for one service. Ownership of what is inside is only repaired when the folder itself
# had the wrong owner (for example after restoring a backup), because walking a blockchain is slow.
service_folder() {
    local path="$1" owner="$2" mode="$3"
    if [ -d "$path" ] && [ "$(stat --format '%U' "$path")" != "$owner" ]; then
        chown --recursive "$owner:$owner" "$path"
    fi
    install --directory --owner "$owner" --group "$owner" --mode "$mode" "$path"
}

# These passwords never leave the container: each service listens on 127.0.0.1 only.
secret() {
    local file="$secrets/$1"
    if [ ! -s "$file" ]; then
        (umask 077 && openssl rand -hex 24 > "$file")
    fi
}

create_database_cluster() {
    if [ -s "$HASHFORGE_DATA/postgres/PG_VERSION" ]; then
        return
    fi

    log "First start: creating the database"
    s6-setuidgid postgres initdb \
        --pgdata "$HASHFORGE_DATA/postgres" \
        --username postgres \
        --auth-local peer \
        --auth-host scram-sha-256 \
        --encoding UTF8 \
        --locale C.UTF-8 > /dev/null
}

[ -r "$HASHFORGE_OPTIONS" ] || fail "$HASHFORGE_OPTIONS is missing; Home Assistant normally creates it."

log "HashForge pool built from $(cat /app/HASHFORGE_REF 2> /dev/null || echo 'an unknown revision')"

service_folder "$HASHFORGE_DATA/bitcoin" bitcoin 750
service_folder "$HASHFORGE_DATA/postgres" postgres 700
service_folder "$HASHFORGE_DATA/redis" redis 750
service_folder "$HASHFORGE_DATA/pool" hashforge 750
service_folder "$HASHFORGE_DATA/backup" postgres 750
service_folder /run/postgresql postgres 755
install --directory --mode 700 "$secrets" "$HASHFORGE_RUN"

secret rpc_password
secret postgres_password
create_database_cluster

/usr/local/lib/hashforge/pool-environment.sh "$HASHFORGE_RUN/pool-environment"
