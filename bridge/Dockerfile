# Build this image ON the Synology NAS (or for the NAS's CPU arch).
# The Agent SDK pulls a native Claude Code binary matching the build arch as an
# OPTIONAL dependency — so the arch you build on must match the arch you run on,
# and optional deps must NOT be skipped.
FROM node:20-bookworm-slim

# System tools Claude Code expects (git for repos, ripgrep for search, jq for
# JSON), plus the same agent toolbox as the terminal/ssh images — minus the
# interactive-only bits (pager, editors), since this variant is headless.
RUN apt-get update && apt-get install -y --no-install-recommends \
      git \
      ca-certificates \
      ripgrep \
      curl \
      jq \
      fd-find \
      procps \
      unzip \
      zip \
      xz-utils \
      sqlite3 \
      tree \
      file \
      moreutils \
      openssh-client \
      rsync \
      dnsutils \
      netcat-openbsd \
      shellcheck \
      python3 \
      python3-pip \
      python3-venv \
      python3-requests \
      python3-yaml \
      python3-bs4 \
      python3-lxml \
      python3-numpy \
      python3-pandas \
    && rm -rf /var/lib/apt/lists/* \
    && ln -s "$(command -v fdfind)" /usr/local/bin/fd

# yq (mikefarah) — not in bookworm's repos; static binary by arch.
ARG YQ_VERSION=v4.44.3
RUN set -eux; \
    curl -fsSL -o /usr/local/bin/yq \
      "https://github.com/mikefarah/yq/releases/download/${YQ_VERSION}/yq_linux_$(dpkg --print-architecture)"; \
    chmod +x /usr/local/bin/yq; \
    yq --version

# Let `pip install --user` work despite bookworm's PEP 668 guard. --user installs
# land under $HOME (/config), so they persist across container restarts.
ENV PIP_BREAK_SYSTEM_PACKAGES=1

ENV NODE_ENV=production
# Claude Code writes its config/state under $HOME/.claude — point it at the
# /config mount so it persists and is writable by the non-root run user.
ENV HOME=/config

WORKDIR /app
COPY package.json ./
# --omit=dev drops devDependencies but KEEPS optional deps (the native binary).
RUN npm install --omit=dev && npm cache clean --force

COPY server.js ./

EXPOSE 8000
CMD ["node", "server.js"]
