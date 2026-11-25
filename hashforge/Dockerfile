# HashForge for Home Assistant: the pool, a Bitcoin Core node, Redis and PostgreSQL in one container,
# because a Home Assistant app is a single container rather than a stack of them.

# --- The pool, built from the HashForge repository ---------------------------------------------------
# Compiled on the build machine's own architecture: the output is the same for every processor, and the
# .NET compiler does not run reliably under emulation when building for ARM on an Intel machine.
FROM --platform=$BUILDPLATFORM mcr.microsoft.com/dotnet/sdk:10.0 AS pool

# A branch, tag or commit of https://github.com/owenashurst/HashForge. The publish workflow passes the
# exact commit that main points at, so every release is built from a known revision.
ARG HASHFORGE_REF=main

WORKDIR /source
SHELL ["/bin/bash", "-euo", "pipefail", "-c"]

# global.json is removed for the same reason the pool's own Dockerfile leaves it out: it pins the SDK
# used for development, which need not be the one in this image.
RUN curl -fsSL "https://github.com/owenashurst/HashForge/archive/${HASHFORGE_REF}.tar.gz" \
        | tar -xz --strip-components=1 \
    && rm -f global.json \
    && dotnet publish src/HashForge.Web/HashForge.Web.csproj --configuration Release --output /app \
    && test -f /app/wwwroot/_framework/blazor.web.js \
    && printf '%s\n' "${HASHFORGE_REF}" > /app/HASHFORGE_REF

# --- The .NET runtime the pool needs -----------------------------------------------------------------
FROM mcr.microsoft.com/dotnet/aspnet:10.0 AS runtime

# --- Bitcoin Core, downloaded from bitcoincore.org and verified ---------------------------------------
FROM debian:trixie-slim AS bitcoin

# Pinned on purpose: the node is consensus-critical, so upgrades should be a deliberate change here.
ARG BITCOIN_VERSION=32.1
# How many release-signer signatures must check out before the download is trusted.
ARG MIN_GOOD_SIGNATURES=3
ARG TARGETARCH

RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates curl gnupg \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /download
SHELL ["/bin/bash", "-euo", "pipefail", "-c"]

RUN case "${TARGETARCH:-amd64}" in \
        amd64) ARCH=x86_64-linux-gnu ;; \
        arm64) ARCH=aarch64-linux-gnu ;; \
        *) echo "Unsupported architecture: ${TARGETARCH}" >&2; exit 1 ;; \
    esac \
    && BASE="https://bitcoincore.org/bin/bitcoin-core-${BITCOIN_VERSION}" \
    && TARBALL="bitcoin-${BITCOIN_VERSION}-${ARCH}.tar.gz" \
    && curl -fsSLO "${BASE}/${TARBALL}" \
    && curl -fsSLO "${BASE}/SHA256SUMS" \
    && curl -fsSLO "${BASE}/SHA256SUMS.asc" \
    # 1. The tarball must match the published checksum.
    && grep " ${TARBALL}\$" SHA256SUMS | sha256sum -c - \
    # 2. The checksum file must be signed by enough of the Bitcoin Core release signers.
    && curl -fsSL https://github.com/bitcoin-core/guix.sigs/archive/refs/heads/main.tar.gz | tar -xz \
    && gpg --batch --quiet --import guix.sigs-main/builder-keys/*.gpg 2>/dev/null \
    && GOOD=$( (gpg --batch --status-fd 1 --verify SHA256SUMS.asc SHA256SUMS 2>/dev/null || true) | grep -c '^\[GNUPG:\] GOODSIG' ) \
    && echo "Good release signatures: ${GOOD} (need ${MIN_GOOD_SIGNATURES})" \
    && [ "${GOOD}" -ge "${MIN_GOOD_SIGNATURES}" ] \
    && mkdir /opt/bitcoin \
    && tar -xzf "${TARBALL}" -C /opt/bitcoin --strip-components=1 \
    # Only the daemon is needed; the wallet tools, the GUI and the test binaries are left behind.
    && mkdir /opt/bitcoin-bin \
    && cp "$(find /opt/bitcoin -type f -name bitcoind | head -n 1)" /opt/bitcoin-bin/

# --- The app -----------------------------------------------------------------------------------------
# Home Assistant's Debian base image: it brings the s6 process supervisor that runs the four services,
# and Bitcoin Core's release binaries need glibc, which the Alpine base does not have.
FROM ghcr.io/home-assistant/base-debian:trixie

# Must match the major version Debian trixie ships; the database files in /data are tied to it.
ARG POSTGRES_MAJOR=17

SHELL ["/bin/bash", "-euo", "pipefail", "-c"]

# The PostgreSQL package would otherwise create a database under /var/lib that is never used.
RUN mkdir -p /etc/postgresql-common \
    && echo "create_main_cluster = false" > /etc/postgresql-common/createcluster.conf \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates curl jq openssl libicu76 \
        "postgresql-${POSTGRES_MAJOR}" redis-server \
    && rm -rf /var/lib/apt/lists/* \
    && ln -s "/usr/lib/postgresql/${POSTGRES_MAJOR}/bin/"{postgres,initdb,pg_isready,pg_dump,psql} /usr/local/bin/ \
    && useradd --system --no-create-home --shell /usr/sbin/nologin bitcoin \
    && useradd --system --no-create-home --shell /usr/sbin/nologin hashforge

COPY --from=runtime /usr/share/dotnet /usr/share/dotnet
COPY --from=bitcoin /opt/bitcoin-bin/bitcoind /usr/local/bin/bitcoind
COPY --from=pool /app /app
COPY rootfs /

RUN ln -s /usr/share/dotnet/dotnet /usr/local/bin/dotnet \
    && chmod 755 /usr/local/lib/hashforge/*.sh /etc/s6-overlay/s6-rc.d/*/run \
    && bitcoind --version | head -n 1 \
    && dotnet --list-runtimes \
    && postgres --version \
    && redis-server --version

# Start-up may take as long as it needs (the first run creates a database), and a failed start-up step
# stops the container rather than leaving a half-working pool.
ENV S6_CMD_WAIT_FOR_SERVICES_MAXTIME=0 \
    S6_BEHAVIOUR_IF_STAGE2_FAILS=2 \
    DOTNET_NOLOGO=1

LABEL \
    org.opencontainers.image.title="Home Assistant App: HashForge" \
    org.opencontainers.image.description="Run your own Bitcoin mining pool, with a Bitcoin node, from Home Assistant." \
    org.opencontainers.image.source="https://github.com/owenashurst/HashForge-HA" \
    org.opencontainers.image.licenses="MIT"
