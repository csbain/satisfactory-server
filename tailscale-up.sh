#!/bin/bash
# Wait for tailscaled socket to become available
for i in {1..15}; do
    if [ -S /var/run/tailscale/tailscaled.sock ]; then
        break
    fi
    sleep 1
done

# Authenticate if socket is ready
if [ -S /var/run/tailscale/tailscaled.sock ]; then
    HOSTNAME="${TS_HOSTNAME:-satisfactory-server}"
    echo "Running tailscale up with hostname $HOSTNAME..."
    /usr/bin/tailscale up --authkey="$TS_AUTHKEY" --hostname="$HOSTNAME" --accept-routes || true
else
    echo "tailscaled socket not found. Skipping tailscale up."
fi
