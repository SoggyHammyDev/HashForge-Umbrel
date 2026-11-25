# Bitcoin Core node for HashForge.
# Downloads the official release from bitcoincore.org, verifies it, and runs it as an unprivileged user.

FROM debian:bookworm-slim AS download

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
    && rm -rf /opt/bitcoin/share/man

FROM debian:bookworm-slim

RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates curl openssl \
    && rm -rf /var/lib/apt/lists/* \
    && useradd --system --create-home --uid 1000 bitcoin \
    && mkdir /data

COPY --from=download /opt/bitcoin /opt/bitcoin
COPY --chmod=755 entrypoint.sh healthcheck.sh /usr/local/bin/

# The release layout has changed between versions, so locate the daemon rather than assume its folder.
RUN ln -s "$(find /opt/bitcoin -type f -name bitcoind | head -n 1)" /usr/local/bin/bitcoind \
    && ln -s "$(find /opt/bitcoin -type f -name bitcoin-cli | head -n 1)" /usr/local/bin/bitcoin-cli \
    && bitcoind --version | head -n 1

# Starts as root only so the entrypoint can take ownership of the mounted data folder; it then drops to "bitcoin".
VOLUME /data

# 8332 = RPC and 28332 = ZeroMQ block announcements (both internal to the Docker network), 8333 = peer-to-peer.
# The same ports are used on every network.
EXPOSE 8332 8333 28332

HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=5 CMD ["healthcheck.sh"]
ENTRYPOINT ["entrypoint.sh"]
