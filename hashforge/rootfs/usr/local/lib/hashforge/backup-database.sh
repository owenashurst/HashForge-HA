#!/usr/bin/env bash
# Home Assistant runs this just before it backs the app up. Copying a running database's files can give
# a backup that will not start, so the database is written out as one consistent file instead and its
# own folder is left out of the backup (see backup_exclude in the app's configuration).
set -euo pipefail

# shellcheck source=options.sh
source /usr/local/lib/hashforge/options.sh

dump="$HASHFORGE_DATA/backup/hashforge.sql"

# Written under a temporary name first, so a failed dump never replaces a good one.
s6-setuidgid postgres pg_dump --host /run/postgresql --dbname hashforge --file "$dump.partial"
mv "$dump.partial" "$dump"
log "Database written to $dump for the backup"
