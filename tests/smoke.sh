#!/usr/bin/env bash
# Starts the app's image the way Home Assistant would (settings in /data/options.json) on a private
# regtest chain, and checks that all four services come up and the pool answers.
#
# Usage: tests/smoke.sh <image> [host port for the web interface]
set -euo pipefail

image="${1:?usage: tests/smoke.sh <image> [web port]}"
web_port="${2:-18080}"
name="hashforge-ha-smoke"
volume="hashforge-ha-smoke-data"

# Stops Git Bash on Windows from rewriting the container paths below; it means nothing elsewhere.
export MSYS_NO_PATHCONV=1

cleanup() {
    docker rm --force "$name" > /dev/null 2>&1 || true
    docker volume rm "$volume" > /dev/null 2>&1 || true
}
trap cleanup EXIT
cleanup

# Checks below read from here-strings rather than pipes: with pipefail, a grep that stops at its first
# match can make the command feeding it fail, which would report a failure that did not happen.
fail() {
    echo "FAILED: $*" >&2
    docker logs --tail 80 "$name" >&2 || true
    exit 1
}

# The options file has to be in /data before the container starts, as it is under Home Assistant.
docker volume create "$volume" > /dev/null
docker run --rm --interactive --volume "$volume:/data" --entrypoint sh "$image" -c 'cat > /data/options.json' << 'JSON'
{
  "network": "regtest",
  "prune_mb": 0,
  "stratum_host": "localhost",
  "solo_enabled": true,
  "pplns_enabled": true,
  "prop_enabled": false,
  "bonus_enabled": false,
  "admin_networks": ["127.0.0.0/8"]
}
JSON

docker run --detach --name "$name" --volume "$volume:/data" --publish "127.0.0.1:${web_port}:8080" "$image" > /dev/null

echo "Waiting for the pool to answer on port ${web_port}"
for attempt in $(seq 1 90); do
    if curl --silent --fail --max-time 3 "http://127.0.0.1:${web_port}/healthz" > /dev/null; then
        break
    fi
    [ "$(docker inspect --format '{{.State.Running}}' "$name")" = "true" ] || fail "the container stopped"
    [ "$attempt" -lt 90 ] || fail "the pool did not answer within three minutes"
    sleep 2
done

pools="$(curl --silent --fail --max-time 10 "http://127.0.0.1:${web_port}/api/pools")"
grep --quiet '"solo"' <<< "$pools" || fail "the solo pool is missing from /api/pools: $pools"
grep --quiet '"pplns"' <<< "$pools" || fail "the PPLNS pool is missing from /api/pools: $pools"
grep --quiet '"prop"' <<< "$pools" && fail "the proportional pool is listed although it is switched off: $pools"

home="$(curl --silent --fail --max-time 10 "http://127.0.0.1:${web_port}/")" || fail "the home page did not load"
grep --quiet '<base href="/"' <<< "$home" || fail "the home page is not based at the root when opened directly"

# Opened from Home Assistant's sidebar, every address on the page must start with the ingress prefix.
ingress="/api/hassio_ingress/smoke-token"
home="$(curl --silent --fail --max-time 10 --header "X-Ingress-Path: ${ingress}" "http://127.0.0.1:${web_port}/")"     || fail "the home page did not load through the ingress header"
grep --quiet "<base href=\"${ingress}/\"" <<< "$home" || fail "the home page ignores Home Assistant's ingress path"
# Apart from the base address itself, nothing may start at the site's root.
grep --quiet --extended-regexp '(href|src)="/[^/"]' <<< "${home//<base href=/<base at=}"     && fail "the home page has an address that escapes the ingress path"

# The Stratum port must accept a miner: subscribe and expect a reply.
reply="$(docker exec "$name" bash -c '
    exec 3<>/dev/tcp/127.0.0.1/3333
    printf "%s\n" "{\"id\":1,\"method\":\"mining.subscribe\",\"params\":[\"smoke/1.0\"]}" >&3
    IFS= read -r -t 10 line <&3
    printf "%s" "$line"')"
grep --quiet '"result"' <<< "$reply" || fail "the solo pool did not answer mining.subscribe: $reply"

# The backup hook must produce a database dump that is not empty.
docker exec "$name" /usr/local/lib/hashforge/backup-database.sh > /dev/null || fail "the backup hook failed"
docker exec "$name" test -s /data/backup/hashforge.sql || fail "the backup hook wrote no database dump"

# A restart must come back with the same data, and a database folder lost in a restore must be rebuilt
# from the dump.
docker stop --time 120 "$name" > /dev/null
docker run --rm --volume "$volume:/data" --entrypoint rm "$image" -rf /data/postgres
docker start "$name" > /dev/null
for attempt in $(seq 1 90); do
    if curl --silent --fail --max-time 3 "http://127.0.0.1:${web_port}/healthz" > /dev/null; then
        break
    fi
    [ "$attempt" -lt 90 ] || fail "the pool did not come back after its database was restored"
    sleep 2
done
logs="$(docker logs "$name" 2>&1)"
grep --quiet "Restoring the pool's database" <<< "$logs" || fail "the database dump was not restored"

echo "Smoke test passed"
