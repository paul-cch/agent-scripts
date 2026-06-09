# Tools Reference

CLI tools available or planned on Paul's machine. Treat status as live-checkable, not permanent truth.

| Tool | Status | Paul route |
| --- | --- | --- |
| `gh` | active | GitHub CLI on PATH |
| `gws` | active | Google-facing assistant work |
| `peekaboo` | active | macOS screenshot/UI inspection when permissions allow |
| `mcporter` | active | Browser/MCP fallback |
| `yt-dlp`/`ffmpeg` | active | Video transcript/download helper |
| `op` | optional | Not mandatory; configure only when needed |
| `rem` | missing | Apple Reminders CLI candidate |
| `things` | missing | Things 3 CLI candidate |
| `tailscale` | missing | Homelab remote routing candidate |
| `prlctl` | missing | Parallels VM workflow candidate |
| `bird` | ported later | X/Twitter workflow not configured |
| `sonoscli` | ported later | Local speaker workflow not configured |
| `clawdis` | ported later | Messaging gateway not configured |
| `oracle` | active candidate | Local prompt-forwarding workflow |

## bird 🐦
Twitter/X CLI for posting, replying, reading tweets.

Status on Paul's machine: `ported later`; do not run until configured.

**Location**: `~/Projects/bird/bird`

**Commands**:
```bash
bird tweet "<text>"                    # Post a tweet
bird reply <tweet-id-or-url> "<text>"  # Reply to a tweet
bird read <tweet-id-or-url>            # Fetch tweet content
bird replies <tweet-id-or-url>         # List replies to a tweet
bird thread <tweet-id-or-url>          # Show full conversation thread
bird search "<query>" [-n count]       # Search tweets
bird mentions [-n count]               # Find tweets mentioning @clawdbot
bird whoami                            # Show logged-in account
bird check                             # Show credential sources
```

**Auth**: Uses Firefox cookies by default. Pass `--firefox-profile <name>` to switch.

---

## sonoscli 🔊
Control Sonos speakers over local network (UPnP/SOAP).

Status on Paul's machine: `ported later`; do not run until configured.

**Location**: `~/Projects/sonoscli/bin/sonos`

**Commands**:
```bash
sonos discover                         # Find speakers on network
sonos status --name "Room"             # Current playback status
sonos play/pause/stop --name "Room"    # Playback control
sonos next/prev --name "Room"          # Track navigation
sonos volume get/set --name "Room" 25  # Volume control
sonos mute get/toggle --name "Room"    # Mute control

# Grouping
sonos group status                     # Show current groups
sonos group join --name "A" --to "B"   # Join A into B's group
sonos group unjoin --name "Room"       # Make standalone
sonos group party --to "Room"          # Join all to one group

# Spotify (via SMAPI)
sonos smapi search --service "Spotify" --category tracks "query"
sonos open --name "Room" spotify:track:<id>
```

**Known issues**:
- SSDP multicast may fail; use `--ip <speaker-ip>` as fallback
- Default HTTP keep-alives can cause timeouts (fix pending: DisableKeepAlives)

---

## peekaboo 👀
Screenshot, screen inspection, and click automation.

Status on Paul's machine: `active`.

**Location**: `~/Projects/Peekaboo`

**Commands**:
```bash
peekaboo capture                       # Take screenshot
peekaboo see                           # Describe what's on screen (OCR)
peekaboo click                         # Click at coordinates
peekaboo list                          # List windows/apps
peekaboo tools                         # Show available tools
peekaboo permissions status            # Check TCC permissions
```

**Requirements**: Screen Recording + Accessibility permissions.

**Docs**: `~/Projects/Peekaboo/docs/commands/`

---

## sweetistics 📊
Twitter/X analytics desktop app (Tauri).

Status on Paul's machine: `ported later`; do not run until configured.

**Location**: `~/Projects/sweetistics`

Use for deeper Twitter data analysis beyond what `bird` provides.

---

## clawdis 📡
WhatsApp/Telegram messaging gateway and agent interface.

Status on Paul's machine: `ported later`; do not run until configured.

**Location**: `~/Projects/clawdis`

**Commands**:
```bash
clawdis login                          # Link WhatsApp via QR
clawdis send --to <number> --message "text"  # Send message
clawdis agent --message "text"         # Talk to agent directly
clawdis gateway                        # Run WebSocket gateway
clawdis status                         # Session health
```

---

## oracle 🧿
Hand prompts + files to other AIs (GPT-5 Pro, etc.).

Status on Paul's machine: `active candidate`.

**Usage**: `npx -y @steipete/oracle --help` (run once per session to learn syntax)

---

## gh
GitHub CLI for PRs, issues, CI, releases.

Status on Paul's machine: `active`.

**Usage**: `gh help`

When someone shares a GitHub URL, use `gh` to read it:
```bash
gh issue view <url> --comments
gh pr view <url> --comments --files
gh run list / gh run view <id>
```

---

## mcporter
MCP server launcher for browser automation, web scraping.

Status on Paul's machine: `active`.

**Usage**: `npx mcporter --help`

Common servers: `iterm`, `firecrawl`, `XcodeBuildMCP`
