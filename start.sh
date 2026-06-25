#!/usr/bin/env bash

set -e

echo "======================================"
echo "      OGG Railway Miner Startup"
echo "======================================"

if [ -z "${WALLET_ADDRESS:-}" ]; then
    echo "ERROR: WALLET_ADDRESS not set"
    exit 1
fi

POOL_HOST="${POOL_HOST:-pool.oggcoin.org}"
POOL_PORT="${POOL_PORT:-8008}"
WORKER_NAME="${WORKER_NAME:-railway-worker}"
CPU_THREADS="${CPU_THREADS:-2}"

echo "Wallet: ${WALLET_ADDRESS}"
echo "Pool: ${POOL_HOST}:${POOL_PORT}"
echo "Worker: ${WORKER_NAME}"
echo "Threads: ${CPU_THREADS}"

echo "Starting SRBMiner..."

exec /opt/miner/SRBMiner-MULTI \
    --algorithm oggpow \
    --pool "${POOL_HOST}:${POOL_PORT}" \
    --wallet "${WALLET_ADDRESS}" \
    --worker "${WORKER_NAME}" \
    --cpu-threads "${CPU_THREADS}" \
    --disable-gpu
