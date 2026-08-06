#!/usr/bin/env bash
# Health depends on which doors are enabled: check each one that is.
set -euo pipefail

if [ "${TTYD:-0}" != "1" ] && [ "${SSHD:-0}" != "1" ]; then
  exit 1
fi

if [ "${TTYD:-0}" = "1" ]; then
  curl -s -o /dev/null http://localhost:7681 || exit 1
fi

if [ "${SSHD:-0}" = "1" ]; then
  exec 3<>/dev/tcp/127.0.0.1/2222 && head -c 4 <&3 | grep -q SSH || exit 1
fi

exit 0
