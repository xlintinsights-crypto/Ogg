#!/usr/bin/env bash
# ============================================================
# OGG Railway Miner — Startup & Watchdog Script
# ============================================================
set -euo pipefail

# ---- Timestamp helper ----
ts() { date -u '+[%Y-%m-%d %H:%M:%S UTC]'; }
echo "$(ts) [DEBUG] Checking miner binary..."
ls -lah /opt/miner/
ls -lh /opt/miner/SRBMiner-MULTI
echo "===== ALGORITHMS ====="
/opt/miner/SRBMiner-MULTI --list-algorithms
echo "===== TEST ====="
/opt/miner/SRBMiner-MULTI --help
echo "EXIT CODE=$?"
sleep 300

# ---- Banner ----
echo "$(ts) =============================================="
echo "$(ts)   OGG (Oggcoin) CPU Miner — Railway Worker"
echo "$(ts)   Algorithm : OggPoW (ProgPoW / CPU mode)"
echo "$(ts)   Miner     : SRBMiner-MULTI v3.3.6"
echo "$(ts) =============================================="

# ---- Validate required env vars ----
if [[ -z "${WALLET_ADDRESS:-}" || "${WALLET_ADDRESS}" == "YOUR_OGG_WALLET_ADDRESS" ]]; then
    echo "$(ts) [FATAL] WALLET_ADDRESS is not set."
    echo "$(ts)         Set it in Railway: Settings → Variables → WALLET_ADDRESS"
    echo "$(ts)         Example: 0xYourEthCompatibleWalletAddressHere"
    exit 1
fi

# ---- Configuration summary ----
POOL_HOST="${POOL_HOST:-pool.oggcoin.org}"
POOL_PORT="${POOL_PORT:-8008}"
CPU_THREADS="${CPU_THREADS:-2}"
WORKER_NAME="${WORKER_NAME:-railway-worker-1}"
LOG_LEVEL="${LOG_LEVEL:-2}"
RESTART_DELAY="${RESTART_DELAY:-10}"

echo "$(ts) [CONFIG] Wallet  : ${WALLET_ADDRESS:0:8}...${WALLET_ADDRESS: -4}"
echo "$(ts) [CONFIG] Worker  : ${WORKER_NAME}"
echo "$(ts) [CONFIG] Pool    : ${POOL_HOST}:${POOL_PORT}"
echo "$(ts) [CONFIG] Threads : ${CPU_THREADS}"
echo "$(ts) [CONFIG] Log Lvl : ${LOG_LEVEL}"

# ---- Pool connectivity pre-check ----
echo "$(ts) [NET] Testing pool connectivity to ${POOL_HOST}:${POOL_PORT}..."
if timeout 10 bash -c "echo >/dev/tcp/${POOL_HOST}/${POOL_PORT}" 2>/dev/null; then
    echo "$(ts) [NET] Pool reachable ✓"
else
    echo "$(ts) [WARN] Cannot reach pool — will retry on miner start."
fi

# ---- Build stratum URL ----
# Format: stratum+tcp://WALLET.WORKER@HOST:PORT
STRATUM_URL="stratum+tcp://${WALLET_ADDRESS}.${WORKER_NAME}@${POOL_HOST}:${POOL_PORT}"

echo "$(ts) [INFO] Stratum URL: stratum+tcp://${WALLET_ADDRESS:0:6}...${WALLET_ADDRESS: -4}.${WORKER_NAME}@${POOL_HOST}:${POOL_PORT}"

# ---- Uptime counter ----
START_TIME=$(date +%s)
CRASH_COUNT=0

# ---- Stats tracking ----
log_stats_header() {
    echo "$(ts) [STATS] ─────────────────────────────────────────"
    echo "$(ts) [STATS]  Uptime  │ Crashes │ Status"
    echo "$(ts) [STATS] ─────────────────────────────────────────"
}

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
/opt/miner/SRBMiner-MULTI --list-algorithms \
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
