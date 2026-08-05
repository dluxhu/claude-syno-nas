# Terminal variant: the REAL Claude Code TUI served in a browser via ttyd.
# Ships its own Node (sidesteps Synology's packaged-Node segfault).
# Build this image ON the NAS (or for its arch) — multi-arch handled below.
FROM node:22-bookworm-slim

ARG TTYD_VERSION=1.7.7

RUN apt-get update && apt-get install -y --no-install-recommends \
      git \
      ca-certificates \
      ripgrep \
      curl \
      bash \
      tmux \
    && rm -rf /var/lib/apt/lists/*

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

# Grok Build (xAI's coding agent CLI). Installer picks the right arch binary.
RUN GROK_BIN_DIR=/usr/local/bin bash -c \
      "curl -fsSL https://x.ai/cli/install.sh | bash" \
    && grok --version

# Claude Code writes config/auth under $HOME/.claude — persist via the /config mount.
ENV HOME=/config
WORKDIR /workspace

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

EXPOSE 7681
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
