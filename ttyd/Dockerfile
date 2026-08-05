# Terminal variant: the REAL Claude Code TUI served in a browser via ttyd.
# Ships its own Node (sidesteps Synology's packaged-Node segfault).
# Build this image ON the NAS (or for its arch) — multi-arch handled below.

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

# Real Claude Code CLI + Cline CLI. Pin to the image (no auto-update mid-session).
ENV DISABLE_AUTOUPDATER=1
RUN npm install -g @anthropic-ai/claude-code cline && npm cache clean --force

# Grok Build (xAI's coding agent CLI). Installer picks the right arch binary,
# but drops it under /root/.grok (0700) with only a symlink on PATH — replace
# the symlink with the real file so non-root users can run it.
RUN GROK_BIN_DIR=/usr/local/bin bash -c \
      "curl -fsSL https://x.ai/cli/install.sh | bash" \
    && cp -L /usr/local/bin/grok /usr/local/bin/grok.bin \
    && mv /usr/local/bin/grok.bin /usr/local/bin/grok \
    && chmod 755 /usr/local/bin/grok \
    && rm -rf /root/.grok \
    && grok --version

# UTF-8 locale + 256color/truecolor tmux, or TUIs (Claude Code's ascii art)
# render garbled inside tmux.
ENV LANG=C.UTF-8
RUN printf 'set -g default-terminal "tmux-256color"\nset -ga terminal-overrides ",*:Tc"\n' > /etc/tmux.conf

# Claude Code writes config/auth under $HOME/.claude — persist via the /config mount.
ENV HOME=/config
WORKDIR /workspace

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

EXPOSE 7681
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
