# HashForge for Home Assistant

[![Build and test](https://github.com/owenashurst/HashForge-HA/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/owenashurst/HashForge-HA/actions/workflows/ci.yml)
[![Publish](https://github.com/owenashurst/HashForge-HA/actions/workflows/publish.yml/badge.svg?branch=main)](https://github.com/owenashurst/HashForge-HA/actions/workflows/publish.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

A Home Assistant app (formerly called an add-on) that runs
[HashForge](https://github.com/owenashurst/HashForge), the open-source Bitcoin mining pool. One install
gives you the pool, a Bitcoin Core node and the databases the pool needs, so your miners can point at
your own Home Assistant machine instead of someone else's pool.

## Installing

[![Add this repository to your Home Assistant.](https://my.home-assistant.io/badges/supervisor_add_addon_repository.svg)](https://my.home-assistant.io/redirect/supervisor_add_addon_repository/?repository_url=https%3A%2F%2Fgithub.com%2Fowenashurst%2FHashForge-HA)

Or by hand:

1. In Home Assistant, open **Settings → Apps → App store**.
2. Open the menu in the top right, choose **Repositories**, and add
   `https://github.com/owenashurst/HashForge-HA`.
3. Find **HashForge** in the store, install it, and read its **Documentation** tab before starting it.

Home Assistant OS or a supervised installation is required, on a 64-bit Intel/AMD or ARM machine.
The bundled Bitcoin node needs about 20 GB of disk on mainnet and a real drive rather than an SD card;
[the app's documentation](hashforge/DOCS.md) has the details, including how to use a node you already run.

## What is in the app

| Part | What it does |
|---|---|
| HashForge pool | The Stratum server miners connect to, the payout logic and the web interface |
| Bitcoin Core | Supplies block templates and broadcasts the blocks the pool finds |
| PostgreSQL | Keeps the permanent records: blocks found, payouts and miner statistics |
| Redis | Keeps snapshots of the pool's live state so a restart loses nothing |

A Home Assistant app is a single container, so all four run inside it under one process supervisor.
Only the pool's web interface and Stratum ports are published; the node's RPC port and both databases
listen inside the container only, with passwords generated on first start.

## Releasing an update

The app's image is built from the HashForge repository, so a pool fix or feature reaches Home Assistant
users in two steps:

1. Push the change to [HashForge](https://github.com/owenashurst/HashForge)'s `main` branch.
2. In this repository, raise `version` in [`hashforge/config.yaml`](hashforge/config.yaml), add a line
   to [`hashforge/CHANGELOG.md`](hashforge/CHANGELOG.md), and push to `main`.

The [Publish workflow](.github/workflows/publish.yml) then looks up the newest commit on HashForge's
`main`, builds the image from it for both architectures, and pushes it to the GitHub container registry
tagged with the new version. Home Assistant sees the new version number and offers the update.

To build from something other than the tip of `main`, run the Publish workflow by hand and give it a
branch, tag or commit.

> **First publish only:** GitHub may create the container package as private. If Home Assistant cannot
> download the image, open the `hashforge-ha` package on your GitHub profile, and under **Package
> settings** change its visibility to public. Do the same for `amd64-hashforge-ha` and
> `aarch64-hashforge-ha`.

## Project layout

```
repository.yaml                 Tells Home Assistant this is an app repository
hashforge/
  config.yaml                   The app's name, version, ports and options
  Dockerfile                    Builds the pool from source and adds the node and databases
  DOCS.md                       What users see on the app's Documentation tab
  translations/en.yaml          Names and descriptions of the options
  rootfs/
    etc/s6-overlay/s6-rc.d/     One folder per service, with what it depends on
    usr/local/lib/hashforge/    The scripts that prepare /data and start the services
tests/
  pool-environment.bats         Unit tests for turning options into pool settings
  smoke.sh                      Starts the image and checks the pool answers
```

## Building and testing from source

You need Docker, and [Bats](https://github.com/bats-core/bats-core) with `jq` for the unit tests.

```bash
bats tests                                  # unit tests
docker build --tag hashforge-ha:dev hashforge
tests/smoke.sh hashforge-ha:dev             # starts the image on a private regtest chain
```

The image builds the pool from HashForge's `main` branch by default. Docker may reuse an earlier
download of it; pass `--build-arg HASHFORGE_REF=<commit>` to build an exact revision.

To try a build on a real Home Assistant machine, copy the `hashforge` folder into its `/addons` folder,
remove the `image:` line from `config.yaml` so that Home Assistant builds it locally, and install it
from the **Local apps** section of the store.

## Contributing

Issues and pull requests are welcome. Please keep to the conventions already in the repository:

- Scripts are Bash with `set -euo pipefail`, pass ShellCheck, and say *why* in their comments.
- Tests are named `GIVEN_Subject_WHEN_Condition_THEN_Outcome`.
- Anything that changes what goes into the image needs a new `version` and a changelog line.

Changes to the pool itself belong in [HashForge](https://github.com/owenashurst/HashForge).

## License

[MIT](LICENSE)
