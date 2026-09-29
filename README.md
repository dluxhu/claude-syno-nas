# claude-nas

Run Claude Code on a Synology NAS, in Docker, and use it from your browser instead of SSH-ing in every time.

There are three ways in, and they sit on top of the same sandbox:

- **Chat** — a chat website (Open WebUI) wired up to Claude Code. Handy for quick questions, using it from your phone, or letting other people in the house use it.
- **Terminal** — the actual Claude Code terminal, served in a browser tab (ttyd).
- **SSH** — the same box reached over key-only OpenSSH instead of a browser. Use your own terminal, `scp`/`sftp`, or VS Code Remote-SSH.

Terminal and SSH are the **same image and the same container** — two doors into one toolbox. You pick which door(s) to open with `TTYD=1` and/or `SSHD=1`; with neither set, the container refuses to start. The chat stack is separate, and you can run any combination. Either way, a container can only see the one folder you mount into it — nothing else on the NAS.

## Background

People have been running Claude Code straight on DSM over SSH for a while. A recent DSM update broke that: Synology's bundled Node.js started segfaulting, and Claude Code would die a few seconds after launch. The fix that worked was to stop using Synology's Node.

That's what these containers do — they bring their own Node, so DSM's copy never enters the picture and the crash doesn't happen. Running it in Docker also keeps it fenced in: an agent that gets a little too determined can only reach the folder you handed it, not the whole NAS.

One design choice worth knowing: the coding agents themselves (`claude`, `codex`, `gemini`, and a dozen others) are **not baked into the terminal image**. You install them once into your home folder with a bundled helper, and from then on they live on the persistent mount — so they keep themselves up to date and survive image updates, instead of being pinned to whatever version the image was built with.

## What you need

- A Synology NAS on DSM 7.2 or newer with Container Manager installed.
- A Claude Pro or Max subscription — that's what it logs in with.
- SSH access for a couple of one-time commands.

One thing on billing: the chat option runs Claude headless, which draws from the monthly Agent SDK credits included with your plan (separate from your normal interactive usage). The terminal option is interactive, so it uses your regular allowance.

## The home folder

There's exactly **one** folder to mount: `HOME_DIR`. Inside the container it becomes `/home`, and it's the home directory of the user everything runs as. It holds:

- the agents you install (`~/.local`, `~/.npm-global`) and their config/auth (`~/.claude`, `~/.grok`, …) — logins survive restarts and image updates
- ssh keys for the SSH door (`~/.ssh/authorized_keys`, plus the generated host key)
- your projects — any layout you like: directly in the home folder, in `~/src`, wherever

It's also the only thing the container can see, so it's the sandbox boundary: don't put anything in it you wouldn't hand to the agent.

## Setup

You only do this once.

1. Get a login token. On any computer that already has Claude Code signed in to your account, run:

   ```
   claude setup-token
   ```

   Copy the token it prints — it starts with `sk-ant-oat01-`.

2. Copy this project onto the NAS, for example to `/volume1/docker/claude-nas`.

3. Create the home folder and make it yours (over SSH). The `webui` one is only needed for the chat option:

   ```
   sudo mkdir -p /volume1/docker/claude-nas/{home,webui}
   sudo chown -R 1026:100 /volume1/docker/claude-nas/home
   ```

   `1026:100` is the usual Synology admin user and group — run `id` to confirm yours.

4. Make your config file and fill it in:

   ```
   cd /volume1/docker/claude-nas
   cp .env.example .env
   ```

   Set your token, your user/group IDs, and the bits for whichever option you're running.

### Migrating from the old two-folder layout

Earlier versions mounted separate `workspace` and `config` folders. Now there's just the home folder. To keep your logins and projects:

```
sudo mv /volume1/docker/claude-nas/config /volume1/docker/claude-nas/home
sudo mv /volume1/docker/claude-nas/workspace /volume1/docker/claude-nas/home/workspace
sudo mv /volume1/docker/claude-nas/home/ssh /volume1/docker/claude-nas/home/.ssh   # ssh users only
```

Then set `HOME_DIR` in `.env` and redeploy. (Your old `config` folder was already `$HOME` inside the container, so `~/.claude`, `~/.grok` etc. carry over unchanged; the ssh keys move from `ssh/` to the standard `.ssh/`.)

## Option A — Chat

Set `BRIDGE_API_KEY` in `.env` to any long random string (`openssl rand -hex 32` is an easy way to get one).

Start it from Container Manager (Project → Create → point it at this folder → Run), or over SSH:

```
sudo docker compose up -d
```

This pulls the prebuilt image from GHCR. To build it yourself instead, add `--build`.

Open `http://your-nas:3000`, make an account — the first one becomes the admin — pick the `claude-code` model, and start chatting. Anything it creates lands in your home folder.

A few things to know about the chat option:

- It's a chat box, so it can't show the "allow this command?" prompts the real Claude Code does. Instead it runs with those prompts off and does its work inside the sandbox. Don't put anything in the home folder you wouldn't be happy for it to change.
- Plan mode and slash commands aren't really a chat thing, so they're not here. Use the terminal option if you want them.
- To let other people use it: there's no open sign-up once an admin exists, which is what you want. Add people under Admin Panel → Users, then turn the model on for them under Admin Panel → Settings → Models → `claude-code` → Access → Public. Miss that last step and they'll just see an empty model list.

## Option B — Terminal (web) and/or SSH

One container, two doors. In `.env`, open the ones you want:

- `TTYD=1` — the web terminal. Also set `TTYD_USER` and `TTYD_PASS`; this is a real shell behind a web page, so give it a real password. (`TTYD_SHELL=claude` lands you straight in Claude Code instead of a shell prompt.)
- `SSHD=1` — key-only OpenSSH. Put your public key(s) in `<HOME_DIR>/.ssh/authorized_keys` first; the ssh door refuses to start without one.

Then:

```
sudo docker compose -f docker-compose.terminal.yml up -d
```

This pulls the prebuilt image from GHCR. To build it yourself instead, add `--build`.

Get a shell inside:

- **Web:** open `http://your-nas:7681` and log in with `TTYD_USER`/`TTYD_PASS`.
- **SSH:** `ssh -p 2222 claude@your-nas` (the username is always `claude`; inside it runs as your `PUID`). The host key is generated on first start and kept in `~/.ssh/`, so it stays stable across image updates. Password auth is off, and sshd itself runs as your non-root user.

### Install the agents (first run)

The agent CLIs aren't in the image — install the ones you want into your home folder, once:

```
install-agents list           # see everything available
install-agents claude codex   # pick the ones you want
install-agents all            # or the whole zoo
```

The roster: `claude` (Claude Code), `grok` (Grok Build), `aider`, `goose` (Block), `cursor` (Cursor Agent), `droid` (Factory), `cline`, `codex` (OpenAI), `gemini` (Google), `copilot` (GitHub), `qwen` (Qwen Code), `opencode`, `amp`, `auggie` (Augment), and `crush` (Charm).

They land under `~/.local` and `~/.npm-global` (both already on `PATH`), so they persist across restarts and image updates — and they keep themselves current: the vendor-installer ones (`claude`, `grok`, `aider`, `goose`, `cursor`, `droid`) self-update, and the npm ones update with `npm update -g` (or just re-run `install-agents`). Each agent has its own login/auth on first run.

The first time you start `claude` it'll ask you to log in — choose the subscription option and do the one-time browser login. After that it's remembered, because the config lives in your home folder. (The token in `.env` covers the chat option and any headless `claude -p` you run in this shell — those work right away.)

### What's in the box

The image ships `tmux`, the GitHub CLI (`gh`), and a developer toolbox agents lean on: `git`, `ripgrep`, `fd`, `jq`, `yq`, `curl`, `sqlite3`, `shellcheck`, `python3` (with `requests`, `pandas`, `numpy`, BeautifulSoup, and pip — `pip install --user` persists in your home folder), and the usual archive, network, and editor utilities (`unzip`, `rsync`, `dig`, `nano`, `vim`, …). The chat backend's image carries the same toolbox minus the interactive-only bits. The tmux is 3.7b built from source with utf8proc, and the image sets a UTF-8 locale plus `tmux-256color`/truecolor defaults — so Claude Code and other TUIs render correctly inside tmux instead of coming out garbled.

Missing something? Add your own packages at build time — see below.

### Startup script

To run something every time the container starts, put a script at `<home folder>/.config/startup.sh`. It runs as your user (PUID:PGID), in your home folder, in the background, before the terminal and ssh open. Its output goes to `.config/startup.log` next to it. A common use is to start a tmux session that you attach to later with `tmux attach`.

It's a shell with your token in it, so keep the password on. If you want to reach the web terminal from outside your house, put it behind Synology's reverse proxy with HTTPS or a VPN rather than forwarding port 7681 straight to the internet.

## Adding your own packages

Both images take an `EXTRA_PACKAGES` build argument — a space-separated list of extra Debian packages baked in at build time. Set it in `.env` and build locally:

```
EXTRA_PACKAGES=golang htop imagemagick
```

```
sudo docker compose -f docker-compose.terminal.yml up -d --build
```

It only takes effect when you build (`--build`); the prebuilt GHCR images are the stock package set. Your local build keeps being used on later `up -d` runs until you `docker compose pull` again. (For things that don't need to be system-wide, you may not need a rebuild at all: `pip install --user` and `npm install -g` both land in your home folder and persist.)

## Building it yourself

The compose files pull prebuilt images from GHCR by default, so a plain `up -d` never compiles anything. If you'd rather build from source (e.g. you changed a Dockerfile, or you set `EXTRA_PACKAGES`), append `--build` to any of the compose commands above — compose then builds from `bridge/` or `terminal/` and tags the result under the same image name, so later `up -d` runs keep using your local build until you `docker compose pull` again.

## Run it from the registry (Portainer)

Every push to `main` kicks off a GitHub Actions workflow (`.github/workflows/build.yml`) that builds the images for amd64 and arm64 and pushes them to GitHub's container registry:

- `ghcr.io/dluxhu/claude-nas-bridge`
- `ghcr.io/dluxhu/claude-nas-terminal`

After the first build finishes, make those packages public (GitHub → your profile → Packages → the package → Package settings → Change visibility → Public) so the NAS can pull them without logging in. If you'd rather keep them private, add `ghcr.io` as a registry in Portainer with a personal access token instead.

### Create these folders first

Over SSH on the NAS (skip `webui` if you only run the terminal stack):

```
sudo mkdir -p /volume1/docker/claude-nas/{home,webui}
sudo chown -R 1026:100 /volume1/docker/claude-nas/home
```

| Folder | Mounted at | What it holds |
|---|---|---|
| `home` | `/home` | the only place the agent can read/write — its config/logins, the installed agents, ssh keys, and your projects |
| `webui` | Open WebUI data | the chat UI's database (chat stack only) |

`home` mounts **read-write** and must be owned by the `PUID:PGID` the container runs as — `1026:100` is the usual Synology admin user/group (run `id` to confirm yours). To give the agent a different working area, like a media library, point `HOME_DIR` at a folder that contains (or links to) it and make sure that user can write there.

### Terminal stack

Portainer → **Stacks → Add stack** → name it `claude-nas-terminal` → paste `portainer/terminal-stack.yml` (or the below) → fill the environment variables → **Deploy**.

```yaml
services:
  terminal:
    image: ghcr.io/dluxhu/claude-nas-terminal:latest
    container_name: claude-terminal
    restart: unless-stopped
    user: "${PUID}:${PGID}"
    environment:
      - CLAUDE_CODE_OAUTH_TOKEN=${CLAUDE_CODE_OAUTH_TOKEN}
      - TTYD=${TTYD:-}
      - SSHD=${SSHD:-}
      - TTYD_USER=${TTYD_USER:-}
      - TTYD_PASS=${TTYD_PASS:-}
      - TTYD_SHELL=${TTYD_SHELL:-bash}
    ports:
      - "${TTYD_PORT:-7681}:7681"
      - "${SSH_PORT:-2222}:2222"
    volumes:
      - ${HOME_DIR}:/home
    cap_drop: [ALL]
    security_opt: ["no-new-privileges:true"]
    networks: [claude-net]
networks:
  claude-net:
    driver: bridge
```

Environment variables: `PUID`, `PGID`, `CLAUDE_CODE_OAUTH_TOKEN`, `HOME_DIR`, `TTYD`/`SSHD` (at least one set to `1`), `TTYD_USER`, `TTYD_PASS`, `TTYD_PORT`, `SSH_PORT`.

### Chat stack

Same steps, named `claude-nas-chat`:

```yaml
services:
  bridge:
    image: ghcr.io/dluxhu/claude-nas-bridge:latest
    container_name: claude-bridge
    restart: unless-stopped
    user: "${PUID}:${PGID}"
    environment:
      - PORT=8000
      - CLAUDE_CODE_OAUTH_TOKEN=${CLAUDE_CODE_OAUTH_TOKEN}
      - BRIDGE_API_KEY=${BRIDGE_API_KEY}
      - CLAUDE_MODEL=${CLAUDE_MODEL:-sonnet}
      - CLAUDE_PERMISSION_MODE=${CLAUDE_PERMISSION_MODE:-bypassPermissions}
      - ALLOWED_TOOLS=${ALLOWED_TOOLS:-}
      - SHOW_TOOL_CALLS=${SHOW_TOOL_CALLS:-true}
      - MAX_TURNS=${MAX_TURNS:-40}
    volumes:
      - ${HOME_DIR}:/home
    cap_drop: [ALL]
    security_opt: ["no-new-privileges:true"]
    networks: [claude-net]
    healthcheck:
      test: ["CMD", "curl", "-fsS", "http://localhost:8000/health"]
      interval: 30s
      timeout: 5s
      retries: 3
      start_period: 20s
  open-webui:
    image: ghcr.io/open-webui/open-webui:main
    container_name: claude-webui
    restart: unless-stopped
    depends_on: [bridge]
    ports:
      - "${WEBUI_PORT:-3000}:8080"
    environment:
      - OPENAI_API_BASE_URL=http://bridge:8000/v1
      - OPENAI_API_KEY=${BRIDGE_API_KEY}
      - ENABLE_OLLAMA_API=false
      - WEBUI_NAME=Claude NAS
      - WEBUI_SECRET_KEY=${BRIDGE_API_KEY}
    volumes:
      - ${WEBUI_DATA_DIR}:/app/backend/data
    security_opt: ["no-new-privileges:true"]
    networks: [claude-net]
networks:
  claude-net:
    driver: bridge
```

Environment variables: `PUID`, `PGID`, `CLAUDE_CODE_OAUTH_TOKEN`, `BRIDGE_API_KEY`, `HOME_DIR`, `WEBUI_DATA_DIR`, `WEBUI_PORT`.

### Ports and Synology reverse proxy

| Stack | NAS port (env) | → container | What it serves |
|---|---|---|---|
| Chat | `WEBUI_PORT` (default 3000) | open-webui `:8080` | the chat website |
| Terminal | `TTYD_PORT` (default 7681) | terminal `:7681` | the web terminal (when `TTYD=1`) |
| Terminal | `SSH_PORT` (default 2222) | terminal `:2222` | key-only sshd (when `SSHD=1`) |

The terminal stack maps both ports; a door you haven't enabled simply refuses connections. The chat stack's `bridge` has **no** published port on purpose — only Open WebUI reaches it, over the internal network. Leave it that way.

To serve either over HTTPS at a hostname, use Synology's reverse proxy — **Control Panel → Login Portal → Advanced → Reverse Proxy → Create**:

- **Source:** HTTPS, your hostname (e.g. `claude.example.com`), port 443.
- **Destination:** HTTP, `localhost`, port `3000` (chat) or `7681` (terminal).
- **Custom Header tab → Create → WebSocket.** Required — both Open WebUI and ttyd run over WebSockets and won't work through the proxy without it.

Then reach it at `https://claude.example.com` instead of the raw port. Keep 3000/7681 off the public internet directly; go through the reverse proxy, behind Synology's firewall or a VPN.

### Rolling out updates

New commits to `main` rebuild and push `:latest`. To deploy one, hit **Pull and redeploy** on the stack. For hands-off updates, enable the stack's webhook in Portainer and have the workflow ping it after a build, or run Watchtower against the containers. Your agents and their logins live in the home folder, so an image update doesn't touch them.

## How it's locked down

All variants run the same way:

- Only the home folder is mounted in, so the container can't see the rest of the NAS.
- It runs as your normal user, not root — files stay editable from DSM, and nothing inside has root.
- Linux capabilities are dropped and privilege escalation is turned off.
- The Docker socket is not mounted, so it can't touch other containers or the host.
- The chat backend isn't exposed on your network (only the web UI is, and it needs the shared key). The web terminal sits behind its password. The ssh door is key-only — password auth is off, and sshd itself runs as your non-root user.

Want the chat agent on a shorter leash? Set `CLAUDE_PERMISSION_MODE=dontAsk` and list only safe tools in `ALLOWED_TOOLS`, like `Read,Grep,Glob`. Then it can look but not touch.

## Settings

Everything lives in `.env`:

| Setting | Used by | What it does |
|---|---|---|
| `CLAUDE_CODE_OAUTH_TOKEN` | both | Your token from `claude setup-token`. Required. |
| `PUID` / `PGID` | both | The user and group the container runs as. |
| `HOME_DIR` | both | The one host folder, mounted to `/home` ( = `$HOME`). |
| `EXTRA_PACKAGES` | both | Extra Debian packages baked in when building with `--build`. |
| `BRIDGE_API_KEY` | chat | Shared secret between the UI and the backend. Required. |
| `WEBUI_DATA_DIR` / `WEBUI_PORT` | chat | Where the UI keeps its data / the port you open (default 3000). |
| `CLAUDE_MODEL` | chat | `sonnet`, `opus`, `haiku`, or a full model id. |
| `CLAUDE_PERMISSION_MODE` / `ALLOWED_TOOLS` | chat | Leave on default, or lock down with `dontAsk` + a tool list. |
| `SHOW_TOOL_CALLS` / `MAX_TURNS` | chat | Show the agent's tool activity / cap how many steps per message. |
| `TTYD` / `SSHD` | terminal | Set to `1` to enable the web terminal / the ssh door. At least one. |
| `TTYD_USER` / `TTYD_PASS` | terminal | The login for the web terminal. Required when `TTYD=1`. |
| `TTYD_PORT` | terminal | The web-terminal port you open (default 7681). |
| `TTYD_SHELL` | terminal | `bash` (default) or `claude`. |
| `SSH_PORT` | terminal | The host port sshd is reachable on (default 2222). |

## Updating

The images update with a pull; the agents update themselves (they live in your home folder, not the image):

```
# Chat
sudo docker compose pull && sudo docker compose up -d

# Terminal / SSH
sudo docker compose -f docker-compose.terminal.yml pull && sudo docker compose -f docker-compose.terminal.yml up -d
```

If you build locally instead, swap `pull` for `build --no-cache` (or add `--build --no-cache` to `up`). To update the agents by hand: the vendor-installer ones update themselves, and `install-agents` can always be re-run; the npm-installed ones take `npm update -g`.

## If something's off

- Chat shows no models, or 401s: your `BRIDGE_API_KEY` doesn't match. Fix `.env` and redeploy.
- A non-admin sees an empty model list: the model is still private — make it Public (see Option A).
- The terminal container exits immediately with "neither TTYD=1 nor SSHD=1": that's the door selection — set at least one in `.env`.
- `claude: command not found` in the shell: the agents aren't baked into the image — run `install-agents claude` (or `all`) once.
- The terminal asks for a login: that's the `TTYD_USER` / `TTYD_PASS` prompt, working as intended.
- Login errors in the logs: the token is wrong or expired. Run `claude setup-token` again, update `.env`, redeploy.
- "raised permissions while running as root": your `PUID`/`PGID` are zero or the folder isn't owned by them. Re-run the `chown`.
- "Exec format error": the image was built for the wrong CPU. Build it on the NAS itself (`uname -m` to see your arch) and rebuild with `--no-cache`.
- Logs: `sudo docker logs claude-bridge`, `claude-webui`, or `claude-terminal`.

## What's in here

```
docker-compose.yml            chat: Open WebUI + the backend
docker-compose.terminal.yml   terminal: ttyd and/or key-only OpenSSH (one image, TTYD/SSHD pick)
.env.example                  config for all variants
bridge/                       the chat backend (Node + the Claude Agent SDK)
terminal/                     the terminal image (ttyd + sshd + toolbox; agents install to $HOME)
.github/workflows/build.yml   builds both images and pushes them to GHCR on every push to main
portainer/                    ready-to-paste Portainer stacks that pull those images
```

## Thanks

Built on [Open WebUI](https://github.com/open-webui/open-webui), [ttyd](https://github.com/tsl0922/ttyd), and the [Claude Agent SDK](https://github.com/anthropics/claude-agent-sdk-typescript). Started from a Synology subreddit thread about the post-update segfault and a comment suggesting Docker to keep it contained.
