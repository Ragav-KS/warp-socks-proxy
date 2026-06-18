#!/usr/bin/env bash

set -Eeuo pipefail

cleanup() {
    echo "Stopping warp-svc..."

    if kill -0 "$WARP_PID" 2>/dev/null; then
        kill -TERM "$WARP_PID"
        wait "$WARP_PID" || true
    fi

    exit 0
}

trap cleanup SIGINT SIGTERM

echo "Starting warp-svc..."

warp-svc \
    > >(grep -ivE "dbus|debug") \
    2> >(grep -ivE "dbus|debug" >&2) &

WARP_PID=$!

echo "Waiting for daemon..."

for i in $(seq 1 30); do
    if warp-cli --accept-tos status >/dev/null 2>&1; then
        break
    fi
    sleep 1
done

if ! warp-cli --accept-tos status >/dev/null 2>&1; then
    echo "warp-svc never became ready."
    exit 1
fi

echo "warp-svc is ready."

#
# Register only once
#

if ! warp-cli --accept-tos registration show >/dev/null 2>&1; then
    echo "Registering..."

    warp-cli --accept-tos registration new

    if [[ -n "${WARP_LICENSE:-}" ]]; then
        warp-cli --accept-tos registration license "$WARP_LICENSE"
    fi
fi

#
# Configure
#

warp-cli --accept-tos mode proxy
warp-cli --accept-tos proxy port 40000
warp-cli --accept-tos dns log disable
warp-cli --accept-tos dns families "${FAMILIES_MODE:-off}"

#
# Connect
#

warp-cli --accept-tos connect || true

echo "Waiting for connection..."

for i in $(seq 1 60); do

    STATUS="$(warp-cli --accept-tos status || true)"

    echo "$STATUS"

    if echo "$STATUS" | grep -qi "Connected"; then
        echo "Connected."

        supervisorctl start healthcheck || true

        wait "$WARP_PID"
        exit 0
    fi

    sleep 1

done

echo "Failed to connect."

exit 1