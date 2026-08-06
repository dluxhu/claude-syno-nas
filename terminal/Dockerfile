# Terminal image: one toolbox, two doors. Ships BOTH ttyd (web terminal) and
# key-only OpenSSH; env vars pick what starts (TTYD=1 and/or SSHD=1 — neither
# set means the container refuses to start).
#
# The coding-agent CLIs (claude, codex, gemini, …) are deliberately NOT baked in.
# The user installs them into $HOME (the /home mount) with `install-agents`,
# where they persist across image updates and can self-update.

# tmux 3.7b from source (bookworm ships 3.3a, which mishandles wide/unicode
# chars in TUIs). utf8proc gives it correct character-width tables.
FROM node:22-bookworm-slim AS tmux-build
ARG TMUX_VERSION=3.7b
RUN apt-get update && apt-get install -y --no-install-recommends \
      gcc make bison pkg-config ca-certificates curl \
      libevent-dev libncurses-dev libutf8proc-dev \
    && curl -fsSL "https://github.com/tmux/tmux/releases/download/${TMUX_VERSION}/tmux-${TMUX_VERSION}.tar.gz" | tar xz -C /tmp \
    && cd "/tmp/tmux-${TMUX_VERSION}" \
    && ./configure --enable-utf8proc && make -j"$(nproc)" && make install

FROM node:22-bookworm-slim

ARG TTYD_VERSION=1.7.7

RUN apt-get update && apt-get install -y --no-install-recommends \
      git \
      ca-certificates \
      ripgrep \
      curl \
      jq \
      bash \
      libevent-core-2.1-7 \
      libutf8proc2 \
      openssh-server \
      libnss-wrapper \
      fd-find \
      less \
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
      nano \
      vim-tiny \
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

# User-defined extra apt packages, resolved at build time:
#   EXTRA_PACKAGES="golang htop" docker compose -f docker-compose.terminal.yml up -d --build
ARG EXTRA_PACKAGES=
RUN if [ -n "$EXTRA_PACKAGES" ]; then \
      apt-get update \
      && apt-get install -y --no-install-recommends $EXTRA_PACKAGES \
      && rm -rf /var/lib/apt/lists/*; \
    fi

# yq (mikefarah) — not in bookworm's repos; static binary by arch.
ARG YQ_VERSION=v4.44.3
RUN set -eux; \
    curl -fsSL -o /usr/local/bin/yq \
      "https://github.com/mikefarah/yq/releases/download/${YQ_VERSION}/yq_linux_$(dpkg --print-architecture)"; \
    chmod +x /usr/local/bin/yq; \
    yq --version

COPY --from=tmux-build /usr/local/bin/tmux /usr/local/bin/tmux

# GitHub CLI (gh) — not in Debian bookworm repos, use GitHub's official apt repo.
RUN set -eux; \
    curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
      -o /usr/share/keyrings/githubcli-archive-keyring.gpg; \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
      > /etc/apt/sources.list.d/github-cli.list; \
    apt-get update && apt-get install -y --no-install-recommends gh; \
    rm -rf /var/lib/apt/lists/*

# ttyd static binary matching the build architecture (x86_64 or aarch64).
RUN set -eux; \
    arch="$(dpkg --print-architecture)"; \
    case "$arch" in \
      amd64) ttyd_arch=x86_64 ;; \
      arm64) ttyd_arch=aarch64 ;; \
      *) echo "unsupported arch: $arch" >&2; exit 1 ;; \
    esac; \
    curl -fsSL -o /usr/local/bin/ttyd \
      "https://github.com/tsl0922/ttyd/releases/download/${TTYD_VERSION}/ttyd.${ttyd_arch}"; \
    chmod +x /usr/local/bin/ttyd; \
    ttyd --version

# Everything user-installed lands in $HOME so it survives image updates:
#  - `pip install --user` (PEP 668 guard off) → /home/.local
#  - `npm install -g`                         → /home/.npm-global
#  - the agent CLIs via install-agents        → /home/.local/bin + /home/.npm-global/bin
ENV PIP_BREAK_SYSTEM_PACKAGES=1
ENV NPM_CONFIG_PREFIX=/home/.npm-global
ENV PATH="/home/.local/bin:/home/.npm-global/bin:${PATH}"

# UTF-8 locale + 256color/truecolor tmux, or TUIs (Claude Code's ascii art)
# render garbled inside tmux.
ENV LANG=C.UTF-8
RUN printf 'set -g default-terminal "tmux-256color"\nset -ga terminal-overrides ",*:Tc"\n' > /etc/tmux.conf

# $HOME is the single persistent mount: CLI config/auth, the agents themselves,
# ssh keys, and whatever project layout the user wants inside it.
ENV HOME=/home
WORKDIR /home

COPY entrypoint.sh healthcheck.sh install-agents /usr/local/bin/
RUN chmod +x /usr/local/bin/entrypoint.sh /usr/local/bin/healthcheck.sh /usr/local/bin/install-agents

# 7681 = ttyd, 2222 = sshd (fixed high port; non-root can't bind <1024).
EXPOSE 7681 2222
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
