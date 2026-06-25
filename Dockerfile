# ============================================================
# OGG (Oggcoin) CPU Miner — Railway Deployment
# Algorithm: OggPoW (ProgPoW variant)
# Miner:     SRBMiner-MULTI v3.3.6 (CPU fallback mode)
# Pool:      pool.oggcoin.org:8008
# ============================================================

FROM ubuntu:22.04

# --- Metadata ---
LABEL maintainer="ogg-miner"
LABEL description="OggPoW CPU miner for Railway deployment"
LABEL version="1.0.0"

# --- Prevent interactive prompts during apt installs ---
ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=UTC

# --- Runtime dependencies ---
RUN apt-get update && apt-get install -y --no-install-recommends \
    wget \
    curl \
    tar \
    ca-certificates \
    libssl-dev \
    libcurl4 \
    libjansson-dev \
    libhwloc-dev \
    libnuma-dev \
    numactl \
    procps \
    && rm -rf /var/lib/apt/lists/*

# --- Create non-root miner user ---
RUN useradd -m -s /bin/bash miner

# --- Working directory ---
WORKDIR /opt/miner

# --- Download SRBMiner-MULTI v3.3.6 Linux binary ---
# This is the only publicly available miner with OggPoW CPU support
RUN wget -q --show-progress \
    "https://github.com/doktor83/SRBMiner-Multi/releases/download/3.3.6/SRBMiner-Multi-3-3-6-Linux.tar.gz" \
    -O srbminer.tar.gz \
    && tar -xzf srbminer.tar.gz --strip-components=1 \
    && rm srbminer.tar.gz \
    && chmod +x SRBMiner-MULTI \
    && ls -lah

# --- Copy startup & monitoring scripts ---
COPY scripts/start.sh /opt/miner/start.sh
COPY scripts/healthcheck.sh /opt/miner/healthcheck.sh

RUN chmod +x /opt/miner/start.sh /opt/miner/healthcheck.sh \
    && chown -R miner:miner /opt/miner

# --- Switch to non-root user ---
USER miner

# --- Environment variable defaults (override via Railway dashboard) ---
ENV WALLET_ADDRESS="0x1b1f9Ea51c341F38B181ad7E2AAE91Fa991a89E6"
ENV WORKER_NAME="railway-worker-1"
ENV POOL_HOST="pool.oggcoin.org"
ENV POOL_PORT="8008"
ENV CPU_THREADS="2"
ENV CPU_AFFINITY=""
ENV LOG_LEVEL="2"
ENV RESTART_DELAY="10"

# --- Health check (pool connectivity) ---
HEALTHCHECK --interval=60s --timeout=10s --start-period=30s --retries=3 \
    CMD /opt/miner/healthcheck.sh

# --- Entrypoint ---
CMD ["/opt/miner/start.sh"]
