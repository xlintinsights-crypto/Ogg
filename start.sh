#!/usr/bin/env bash
set -e

echo "======================================"
echo "      OGG Railway Miner Startup"
echo "======================================"

Required variable

if [ -z "${WALLET_ADDRESS:-}" ]; then
echo "ERROR: WALLET_ADDRESS not set"
exit 1
fi

Defaults

POOL_HOST="${POOL_HOST:-pool.oggcoin.org}"
POOL_PORT="${POOL_PORT:-8008}"
WORKER_NAME="${WORKER_NAME:-railway-worker}"
CPU_THREADS="${CPU_THREADS:-2}"

echo "Wallet: ${WALLET_ADDRESS}"
echo "Pool: ${POOL_HOST}:${POOL_PORT}"
echo "Worker: ${WORKER_NAME}"
echo "Threads: ${CPU_THREADS}"

echo "Starting SRBMiner..."

exec /opt/miner/SRBMiner-MULTI 
--algorithm oggpow 
--pool "${POOL_HOST}:${POOL_PORT}" 
--wallet "${WALLET_ADDRESS}" 
--worker "${WORKER_NAME}" 
--cpu-threads "${CPU_THREADS}" 
--disable-gpu
log_uptime() {
    local now elapsed hours mins secs
    now=$(date +%s)
    elapsed=$(( now - START_TIME ))
    hours=$(( elapsed / 3600 ))
    mins=$(( (elapsed % 3600) / 60 ))
    secs=$(( elapsed % 60 ))
    echo "$(ts) [UPTIME] Running ${hours}h ${mins}m ${secs}s | Crash count: ${CRASH_COUNT}"
}

# ---- Watchdog loop ----
echo "$(ts) [WATCHDOG] Starting miner with crash restart enabled..."
log_stats_header

while true; do
    log_uptime
    echo "$(ts) [MINER] Launching SRBMiner-MULTI..."
    echo "$(ts) [MINER] Watch for: 'Accepted' = good share | 'Rejected' = bad share | 'H/s' = hashrate"
    echo "$(ts) ─────────────────────────────────────────────────"

    # ---- Run the miner ----
    # --algorithm oggpow     : OggPoW algorithm
    # --pool                 : stratum URL with wallet.worker format
    # --cpu-threads          : number of CPU threads to use
    # --log-file-disabled    : keep all output to stdout (Railway logs)
    # --disable-gpu          : explicit CPU-only (no CUDA/OpenCL)
    # --log-level            : verbosity (2 = standard, 3 = verbose)
    set +e

/opt/miner/SRBMiner-MULTI \
    --algorithm oggpow \
    --pool ${POOL_HOST}:${POOL_PORT} \
    --wallet ${WALLET_ADDRESS} \
    --worker ${WORKER_NAME} \
    --cpu-threads ${CPU_THREADS} \
    --disable-gpu \
    2>&1 | while IFS= read -r line; do
        echo "$(ts) [MINER] ${line}"
    done

EXIT_CODE=${PIPESTATUS[0]}
set -e
    CRASH_COUNT=$(( CRASH_COUNT + 1 ))
    echo "$(ts) ─────────────────────────────────────────────────"
    echo "$(ts) [WATCHDOG] Miner exited (code: ${EXIT_CODE}) — crash #${CRASH_COUNT}"
    log_uptime

    # ---- Escalating restart delay (cap at 60s) ----
    WAIT=$(( RESTART_DELAY * CRASH_COUNT ))
    if (( WAIT > 60 )); then WAIT=60; fi
    echo "$(ts) [WATCHDOG] Restarting in ${WAIT}s..."
    sleep "${WAIT}"
done
