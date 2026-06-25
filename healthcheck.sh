#!/usr/bin/env bash
# ============================================================
# OGG Miner — Docker Health Check
# Verifies pool TCP reachability
# ============================================================

POOL_HOST="${POOL_HOST:-pool.oggcoin.org}"
POOL_PORT="${POOL_PORT:-8008}"

if timeout 5 bash -c "echo >/dev/tcp/${POOL_HOST}/${POOL_PORT}" 2>/dev/null; then
    echo "HEALTHY: pool.oggcoin.org:${POOL_PORT} reachable"
    exit 0
else
    echo "UNHEALTHY: cannot reach pool.oggcoin.org:${POOL_PORT}"
    exit 1
fi
