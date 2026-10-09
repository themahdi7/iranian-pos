#!/usr/bin/env bash
# Send a 1-step purchase (Rial). Completing the card on the POS is required
# for responseCode 0. 68 = timeout waiting for card; 98 = cancelled on device.
set -euo pipefail
AMOUNT="${1:-10000}"
POS_IP="${POS_IP:-192.168.1.100}"
curl -sS -X POST "http://127.0.0.1:${API_PORT:-8090}/sale" \
  -H 'Content-Type: application/json' \
  -d "{\"amount\":\"${AMOUNT}\",\"pos_ip\":\"${POS_IP}\"}"
echo
