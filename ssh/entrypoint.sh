#!/usr/bin/env bash
set -euo pipefail

# Running as root means PUID/PGID never made it into the deploy (sshd would
# also demand privsep setup we deliberately don't ship). Fail loud and early.
if [ "$(id -u)" = "0" ]; then
  echo "ERROR: container is running as root. Set PUID and PGID in your env" >&2
  echo "(user: \"\${PUID}:\${PGID}\" in the compose/stack) and redeploy." >&2
  exit 1
fi

SSH_DIR=/config/ssh
AUTH_KEYS="${SSH_DIR}/authorized_keys"

# Key-only access: refuse to start without at least one public key.
if [ ! -s "${AUTH_KEYS}" ]; then
  echo "ERROR: ${AUTH_KEYS} is missing or empty." >&2
  echo "Put your public key(s) in <config folder>/ssh/authorized_keys and restart." >&2
  exit 1
fi

# We run as an arbitrary PUID:PGID with no /etc/passwd entry, and both
# ssh-keygen and sshd refuse a uid they can't resolve. nss_wrapper fakes the
# passwd/group entries — set it up before touching any ssh tool.
export NSS_WRAPPER_PASSWD=/tmp/passwd
export NSS_WRAPPER_GROUP=/tmp/group
echo "claude:x:$(id -u):$(id -g):claude:/config:/bin/bash" > "${NSS_WRAPPER_PASSWD}"
echo "claude:x:$(id -g):" > "${NSS_WRAPPER_GROUP}"
LD_PRELOAD="$(ls /usr/lib/*/libnss_wrapper.so)"
export LD_PRELOAD

# Host key: generated once into /config so the host identity survives image
# updates and you don't get MITM warnings after every pull.
HOST_KEY="${SSH_DIR}/ssh_host_ed25519_key"
# A key we can't read (e.g. left behind by an accidental root run) is useless —
# regenerate it. Clients that saw the old key will get a host-key-changed warning.
if [ -f "${HOST_KEY}" ] && [ ! -r "${HOST_KEY}" ]; then
  echo "WARN: ${HOST_KEY} exists but is not readable by uid $(id -u) — regenerating." >&2
  rm -f "${HOST_KEY}" "${HOST_KEY}.pub" || {
    echo "ERROR: cannot replace ${HOST_KEY}; fix ownership of ${SSH_DIR} (chown to your PUID)." >&2
    exit 1
  }
fi
if [ ! -f "${HOST_KEY}" ]; then
  ssh-keygen -q -t ed25519 -N '' -f "${HOST_KEY}"
fi
chmod 600 "${HOST_KEY}" 2>/dev/null || true

# sshd wipes the environment for sessions, so container env the CLIs need is
# re-injected via SetEnv (nss_wrapper included, so `whoami` etc. work in-session).
{
  echo "Port 2222"
  echo "HostKey ${SSH_DIR}/ssh_host_ed25519_key"
  echo "PidFile none"
  echo "UsePAM no"
  echo "PermitRootLogin no"
  echo "PasswordAuthentication no"
  echo "KbdInteractiveAuthentication no"
  echo "AuthorizedKeysFile ${AUTH_KEYS}"
  # Synology mounts often carry ACLs/perms sshd's paranoia rejects; this is a
  # single-user jail, the mount's ownership is the boundary.
  echo "StrictModes no"
  echo "Subsystem sftp internal-sftp"
  # NB: sshd only honors the FIRST SetEnv directive — keep this one line.
  setenv="HOME=/config DISABLE_AUTOUPDATER=1 LD_PRELOAD=${LD_PRELOAD} NSS_WRAPPER_PASSWD=${NSS_WRAPPER_PASSWD} NSS_WRAPPER_GROUP=${NSS_WRAPPER_GROUP}"
  if [ -n "${CLAUDE_CODE_OAUTH_TOKEN:-}" ]; then
    setenv="${setenv} CLAUDE_CODE_OAUTH_TOKEN=${CLAUDE_CODE_OAUTH_TOKEN}"
  fi
  echo "SetEnv ${setenv}"
} > /tmp/sshd_config

echo "[claude-ssh] sshd on :2222 (container)  keys=${AUTH_KEYS}  uid=$(id -u)"

exec /usr/sbin/sshd -D -e -f /tmp/sshd_config
