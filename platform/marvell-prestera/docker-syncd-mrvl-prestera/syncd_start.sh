#!/usr/bin/env bash
# Minimal starter for Bazel-built syncd images (parity with src/sonic-sairedis syncd_start.sh).
set -euo pipefail

HWSKU_DIR=/usr/share/sonic/hwsku
mkdir -p /etc/sai.d/

if [[ -f "${HWSKU_DIR}/sai.profile.j2" ]]; then
    sonic-cfggen -d -t "${HWSKU_DIR}/sai.profile.j2" > /etc/sai.d/sai.profile
elif [[ -f "${HWSKU_DIR}/sai.profile" ]]; then
    cp "${HWSKU_DIR}/sai.profile" /etc/sai.d/sai.profile
fi

exec /usr/bin/syncd -u -s -b /var/run/redis/redis.sock "$@"
