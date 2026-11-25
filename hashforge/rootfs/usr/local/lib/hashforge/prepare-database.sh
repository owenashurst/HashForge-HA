#!/usr/bin/env bash
# Runs once PostgreSQL is up: makes sure the pool's login and database exist. If the database had to be
# created and a dump from a Home Assistant backup is present, the dump is loaded into it.
set -euo pipefail

# shellcheck source=options.sh
source /usr/local/lib/hashforge/options.sh

dump="$HASHFORGE_DATA/backup/hashforge.sql"

as_postgres() {
    s6-setuidgid postgres "$@"
}

query() {
    as_postgres psql --host /run/postgresql --dbname postgres --quiet --tuples-only --no-align \
        --set ON_ERROR_STOP=1 --command "$1"
}

until as_postgres pg_isready --quiet --host /run/postgresql; do
    sleep 1
done

# The password is hexadecimal (see prepare.sh), so it is safe to place inside the quotes.
password="$(cat "$HASHFORGE_DATA/secrets/postgres_password")"
if [ -z "$(query "SELECT 1 FROM pg_roles WHERE rolname = 'hashforge'")" ]; then
    query "CREATE ROLE hashforge LOGIN PASSWORD '$password'"
else
    query "ALTER ROLE hashforge PASSWORD '$password'"
fi

if [ -n "$(query "SELECT 1 FROM pg_database WHERE datname = 'hashforge'")" ]; then
    exit 0
fi

query "CREATE DATABASE hashforge OWNER hashforge"
if [ -s "$dump" ]; then
    log "Restoring the pool's database from the backup taken on $(date --reference "$dump" '+%Y-%m-%d %H:%M')"
    as_postgres psql --host /run/postgresql --dbname hashforge --quiet --set ON_ERROR_STOP=1 \
        --file "$dump" > /dev/null
fi
