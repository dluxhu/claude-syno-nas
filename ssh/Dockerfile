# SSH variant: the same toolbox (claude, grok, cline, gh, tmux) reachable over
# plain OpenSSH instead of a web terminal. No ttyd in this image on purpose —
# key-only sshd is the sole way in.

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
    && rm -rf /var/lib/apt/lists/*

COPY --from=tmux-build /usr/local/bin/tmux /usr/local/bin/tmux

# GitHub CLI (gh) — not in Debian bookworm repos, use GitHub's official apt repo.
RUN set -eux; \
    curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
      -o /usr/share/keyrings/githubcli-archive-keyring.gpg; \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
      > /etc/apt/sources.list.d/github-cli.list; \
    apt-get update && apt-get install -y --no-install-recommends gh; \
    rm -rf /var/lib/apt/lists/*

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

# All CLIs write config/auth under $HOME — persist via the /config mount.
ENV HOME=/config
WORKDIR /workspace

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

# sshd listens on a fixed high port (non-root can't bind <1024); map the
# outside port you want in compose.
EXPOSE 2222
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
