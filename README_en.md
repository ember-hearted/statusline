# Claude Code Statusline

| [中文文档](README.md)
| English

A cross-platform statusline script for Claude Code, featuring dynamic color progress bars, Git status integration, and real-time activity display.

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

## Features

- **Progress bar first**: Battery-style progress bar displayed at the beginning of the first line
- **Two-level directory display**: Shows paths in `parent/current` format
- **Battery-style progress bar**: `•` positive pole + `■` full block + `□` empty block + subscript percentage
- **Dynamic colors**: Changes color based on Context usage
  - 🟢 Green (< 55%)
  - 🟡 Yellow (55% ~ 75%)
  - 🔴 Red (> 75%)
- **LLM balance/usage query**: Configurable multi-provider mode supporting DeepSeek, Kimi, Xiaomi MiMo, SCNet (API/TokenPlan dual-mode auto-routing), Volcengine Ark (Coding/Agent Plan dual-mode auto-routing), and more
- **Smart switching**: Configure multiple providers, automatically display the first one with a valid token
- **Real-time activity display**: Shows running Tools, Agents, and Todos count
- **Git status integration**: Displays branch name and file change statistics
- **Cross-platform**: Windows (Git Bash/WSL), macOS, Linux

## Installation

### Option 1: One-line Install (Recommended)

```bash
# Download and run install script via curl
curl -fsSL https://raw.githubusercontent.com/ASmallMatch/statusline/master/bin/install.sh | bash

# Or run directly in Claude Code
bash -c "$(curl -fsSL https://raw.githubusercontent.com/ASmallMatch/statusline/master/bin/install.sh)"
```

After installation, run in Claude Code:
```
/reload-plugins
```

### Option 2: Clone and Install

```bash
# Clone repository
git clone git@github.com:ASmallMatch/statusline.git
cd statusline

# Run install script
bash bin/install.sh
```

After installation, run in Claude Code:
```
/reload-plugins
```

### Install Script Options

```bash
# Show help
bash bin/install.sh --help

# Install to custom directory
bash bin/install.sh -d /path/to/custom/dir

# Check installation status
bash bin/install.sh -c

# Uninstall
bash bin/install.sh -u
```

### Reinstall and Cache Preservation

When upgrading by re-running `bash bin/install.sh`, the script backs up the old directory before overwriting. The `~/.claude/statusline/cache/` directory (which stores runtime state such as the Volcengine Ark Cookie and balance caches) is preserved during the overwrite, so you don't need to log in again or reconfigure the Cookie.

### Manual Installation

If the install script doesn't work:

```bash
# 1. Clone repository
git clone git@github.com:ASmallMatch/statusline.git
cd statusline

# 2. Create install directory
mkdir -p ~/.claude/statusline

# 3. Copy files
cp bin/statusline.sh ~/.claude/statusline/
cp bin/query-balance.sh ~/.claude/statusline/
cp config/config.json ~/.claude/statusline/
cp config/providers/*.sh ~/.claude/statusline/providers/
cp scripts/transcript-parser-lite.js ~/.claude/statusline/
mkdir -p ~/.claude/statusline/scripts
cp scripts/refresh-xiaomimimo-cookie.js ~/.claude/statusline/scripts/
cp scripts/refresh-xiaomimimo-cookie.sh ~/.claude/statusline/scripts/

# 4. Add execute permission
chmod +x ~/.claude/statusline/statusline.sh

# 5. Configure Claude Code
# Edit ~/.claude/settings.json, add:
# {
#   "statusLine": {
#     "command": "bash ~/.claude/statusline/statusline.sh",
#     "type": "command"
#   }
# }

# 6. Reload plugins
# Run in Claude Code: /reload-plugins
```

## Configuration

Edit `~/.claude/statusline/config.json`:

```json
{
  "bar_length": 10,
  "colors": {
    "thresholds": {
      "green": 55,
      "yellow": 75
    },
    "branch": "33"
  },
  "balance": {
    "deepseek": {
      "token_env": "DEEPSEEK_API_KEY",
      "api_url": "https://api.deepseek.com/user/balance"
    },
    "kimi": {
      "token_env": "ANTHROPIC_API_KEY",
      "api_url": "https://api.kimi.com/coding/v1/usages"
    },
    "xiaomimimo": {
      "api_url": "https://platform.xiaomimimo.com/api/v1/tokenPlan/usage"
    },
    "scnet": {
      "token_env": "ANTHROPIC_AUTH_TOKEN",
      "api_url": "https://www.scnet.cn/acx/charge/flow/llmapi/resource/list"
    },
    "scnet-tp": {
      "token_env": "ANTHROPIC_AUTH_TOKEN",
      "api_url": "https://www.scnet.cn/acx/charge/account/currentuser/tokenplan/list"
    },
    "volces": {
      "token_env": "ANTHROPIC_AUTH_TOKEN",
      "api_url": "https://console.volcengine.com/api/top/ark/cn-beijing/2024-01-01"
    }
  },
  "panel": {
    "git": {
      "show_git": true,
      "show_git_changes": true
    },
    "show_time": true,
    "show_tools": true,
    "show_agents": true,
    "show_todos": true
  }
}
```

`balance` is an **object format** where keys are provider names. The system automatically infers the current provider by reading `ANTHROPIC_BASE_URL` and looks up the matching configuration directly.

### Configuration Options

**colors group** - Color-related settings:

| Option | Description | Default |
|--------|-------------|---------|
| `colors.thresholds.green` | Green threshold (percentage) | 55 |
| `colors.thresholds.yellow` | Yellow threshold (percentage) | 75 |
| `colors.branch` | Branch name color code | 33 (orange) |

**balance group** - Balance/usage query configuration:

| Option | Description | Default |
|--------|-------------|---------|
| `balance.<name>.token_env` | Environment variable name for API token | See provider docs |
| `balance.<name>.api_url` | Balance query API endpoint | See provider docs |

**Token configuration**: Set tokens and base URL in `env` within `~/.claude/settings.json`:

```json
{
  "env": {
    "ANTHROPIC_BASE_URL": "https://api.kimi.com/coding/",
    "ANTHROPIC_API_KEY": "eyJ...",
    "DEEPSEEK_API_KEY": "sk-..."
  }
}
```

The system automatically reads `ANTHROPIC_BASE_URL`, extracts the provider identifier from the domain (e.g. `api.kimi.com` → `kimi`), and directly hits the matching `balance.kimi` config. If `ANTHROPIC_BASE_URL` is not set or doesn't match, it falls back to the first key in the `balance` object.

**panel group** - Panel display options:

| Option | Description | Default |
|--------|-------------|---------|
| `panel.git.show_git` | Show Git status | true |
| `panel.git.show_git_changes` | Show file change statistics | true |
| `panel.show_time` | Show time | true |
| `panel.show_tools` | Show tool activities | true |
| `panel.show_agents` | Show agent status | true |
| `panel.show_todos` | Show todo progress | true |

| `bar_length` | Progress bar length | 10 |

## Display Preview

```
# Main status line (DeepSeek)
❦ •■■■■■□□□□₅₆[¥98.66] ↯ claude-space/statusline ▸  test ~2 -1 ▸ 05:42

# Main status line (Kimi)
❦ •■■■■■□□□□₅₆[Kimi 69%/10%] ↯ claude-space/statusline ▸  test ~2 -1 ▸ 05:42

# Activity lines (shown only when activities are running)
  ❦ Tools  3 running
  ❦ Agents 2 running
  ❦ Todos  2/5
```

Format description:

- `❦` - Progress bar prefix symbol
- `•` - Battery positive pole (always shown)
- `■■■■■` - Used Context (green/yellow/red)
- `□□□□` - Unused Context
- `₅₆` - Usage percentage (subscript digits)
- `[¥98.66]` - DeepSeek balance (colored inside brackets)
- `[Kimi 69%/10%]` - Kimi Coding Plan usage (5h rate / weekly quota, each colored independently)
- `[方舟Coding 21%/3%]` - Volcengine Ark Coding Plan usage (5h / weekly rate, each colored independently); Agent Plan shows as `方舟Agent`
- `↯` - Separator between balance and path
- `▸` - Separator between path, branch, and time
- `claude-space/statusline` - Two-level directory name (cyan)
- ` test` - Git branch (orange)
- `~2 -1` - File change statistics (2 modified, 1 deleted)
- `05:42` - Time (gray)

**Activity lines** (only shown when there are running activities):
- `❦ Tools  3 running` - 3 tools currently executing (yellow)
- `❦ Agents 2 running` - 2 agents currently working (cyan)
- `❦ Todos  2/5` - 2 todos in progress, 5 total (green)

## File Structure

```
~/.claude/statusline/
├── config.json              # Configuration file
├── statusline.sh            # Main script
├── query-balance.sh         # Balance query dispatcher
├── providers/               # Provider scripts directory
│   ├── deepseek.sh          # DeepSeek balance query
│   ├── kimi.sh              # Kimi Coding Plan usage query
│   ├── xiaomimimo.sh        # Xiaomi MiMo Token Plan usage query
│   ├── scnet.sh             # SCNet resource usage query (API mode)
│   ├── scnet-tp.sh          # SCNet TokenPlan usage query
│   └── volces.sh            # Volcengine Ark Coding/Agent Plan usage query (Cookie auth)
├── scripts/                 # Helper scripts directory
│   ├── refresh-xiaomimimo-cookie.js   # MiMo cookie auto-refresh (Playwright)
│   ├── refresh-xiaomimimo-cookie.sh   # MiMo cookie refresh entry script
│   ├── refresh-volces-cookie.js       # Volcengine Ark cookie auto-refresh (Playwright)
│   ├── refresh-volces-cookie.sh       # Volcengine Ark cookie refresh entry script
│   └── check-volces-cookie.sh         # Volcengine Ark cookie expiration check (SessionStart hook)
├── cache/                   # Runtime cache (auto-generated)
│   ├── xiaomimimo_cookie.txt          # MiMo auth cookie
│   ├── volces_cookie.txt              # Volcengine Ark auth cookie
│   ├── balance_volces_coding.txt      # Volcengine Ark Coding Plan usage cache
│   ├── balance_volces_agent.txt       # Volcengine Ark Agent Plan usage cache
│   └── balance_*.txt                  # Other provider balance cache
└── transcript-parser-lite.js # Transcript parser
```

| File | Description |
|------|-------------|
| `statusline.sh` | Main script: parses input, generates statusline output |
| `config.json` | Configuration: color thresholds, display options, balance providers |
| `query-balance.sh` | Balance dispatcher: reads config and calls provider (supports jq multi-provider parsing) |
| `providers/` | Provider scripts directory, each `.sh` encapsulates a vendor's query logic and manages its own colors/format |
| `scripts/` | Helper scripts, including MiMo cookie auto-refresh tools |
| `transcript-parser-lite.js` | Transcript parser: extracts Tools/Agents/Todos status |
| `install.sh` | Install script: deploys to `~/.claude/statusline/` |

## Provider Documentation

### DeepSeek

- **Endpoint**: `GET https://api.deepseek.com/user/balance`
- **Display**: `¥balance`
- **Color**: Red if balance < ¥5, otherwise yellow

### Kimi Coding Plan

- **Endpoint**: `GET https://api.kimi.com/coding/v1/usages`
- **Display**: `Kimi 5h_usage%/weekly_usage%`
- **Color**: Each percentage is **independently colored**
  - 5-hour window: >80% red, >50% yellow, otherwise green
  - Weekly quota: >90% red, >70% yellow, otherwise green
- **Token**: Uses `ANTHROPIC_API_KEY` (Kimi connects via OpenAI-compatible protocol)

### Xiaomi MiMo Token Plan

- **Endpoint**: `GET https://platform.xiaomimimo.com/api/v1/tokenPlan/usage`
- **Auth**: Cookie (`api-platform_serviceToken`), **not API Key**
- **Display**: `Mimo percentage(used/total)`
- **Color**: >90% red, >70% yellow, otherwise green
- **Dependencies**: Node.js + Playwright (install script handles this automatically; for manual install run `cd ~/.claude/statusline/scripts && npm install playwright && npx playwright install chromium`)
- **Cookie Setup**: Xiaomi doesn't provide an API Key endpoint for usage queries — cookie must be obtained via browser login
  ```bash
  # First run: opens browser for manual Xiaomi account login
  ~/.claude/statusline/scripts/refresh-xiaomimimo-cookie.sh

  # Subsequent runs: auto-refresh using saved session (headless)
  ~/.claude/statusline/scripts/refresh-xiaomimimo-cookie.sh --quiet
  ```
- **Cookie Lifetime**: ~1 day, auto-refresh attempted on expiry with user hint
- **Scheduled Refresh**: Recommended cron job to refresh every 12 hours
  ```bash
  0 */12 * * * ~/.claude/statusline/scripts/refresh-xiaomimimo-cookie.sh --quiet
  ```
- **config.json**: No `token_env` needed, script reads from `~/.claude/statusline/cache/xiaomimimo_cookie.txt`
  ```json
  "xiaomimimo": {
    "api_url": "https://platform.xiaomimimo.com/api/v1/tokenPlan/usage"
  }
  ```

### SCNet

SCNet (超算互联网) has two billing modes. The system auto-routes based on API key format:

| Mode | API Key Format | Balance Endpoint |
|------|---------------|-----------------|
| API mode | `sk-*` (standard) | `POST .../flow/llmapi/resource/list` |
| TokenPlan mode | `sk-tp*` | `GET .../tokenplan/list` |

**Shared**:
- **Auth**: Cookie (browser login at [scnet.cn](https://www.scnet.cn) required), **not API Key**
- **Color**: >90% red, >70% yellow, otherwise green
- **Cookie Lifetime**: Depends on session validity; script will prompt to re-login when expired

#### API mode (`scnet`)
- **Display**: `SCNet percentage(used/total)`
- **Endpoint**: `POST https://www.scnet.cn/acx/charge/flow/llmapi/resource/list`
- **Cookie File**: `~/.claude/statusline/cache/scnet_cookie.txt`

#### TokenPlan mode (`scnet-tp`)
- **Display**: `SCNet-TP percentage(used/total)`
- **Endpoint**: `GET https://www.scnet.cn/acx/charge/account/currentuser/tokenplan/list`
- **Cookie File**: `~/.claude/statusline/cache/scnet_tp_cookie.txt`
- **Response format**: `data[].totalAmount` (total CREDITS) / `data[].usedAmount` (used)

**Cookie Setup**:
```bash
# 1. Login at https://www.scnet.cn in browser
# 2. F12 → Network → copy Cookie request header
# 3. Save to the correct cookie file
echo 'cookie_string' > ~/.claude/statusline/cache/scnet_cookie.txt      # API mode
echo 'cookie_string' > ~/.claude/statusline/cache/scnet_tp_cookie.txt   # TokenPlan mode
```

**Auto-routing**: System extracts `scnet` from `ANTHROPIC_BASE_URL`, then checks `ANTHROPIC_AUTH_TOKEN`:
- `sk-tp*` → routes to `scnet-tp` provider
- Other → routes to `scnet` provider

**config.json**:
```json
"scnet": {
    "token_env": "ANTHROPIC_AUTH_TOKEN",
    "api_url": "https://www.scnet.cn/acx/charge/flow/llmapi/resource/list"
},
"scnet-tp": {
    "token_env": "ANTHROPIC_AUTH_TOKEN",
    "api_url": "https://www.scnet.cn/acx/charge/account/currentuser/tokenplan/list"
}
```

### Volcengine Ark (火山方舟)

Usage query for Volcengine Ark Coding Plan and Agent Plan. Auto-routes based on the `ANTHROPIC_BASE_URL` path:

- `/api/coding` → `GetCodingPlanUsage` endpoint, label `方舟Coding`
- `/api/plan` → `GetAgentPlanAFPUsage` endpoint, label `方舟Agent`

Display format is `5h-rate/weekly-rate`, each percentage colored by threshold independently, e.g. `方舟Coding 21%/3%`.

- **Auth**: Cookie + `x-csrf-token` (console proxy endpoint, not the official OpenAPI). The official OpenAPI requires AK/SK V4 signing; this plugin uses the console Cookie proxy to avoid extra keys.
- **Cookie File**: `~/.claude/statusline/cache/volces_cookie.txt`
- **token_env**: `ANTHROPIC_AUTH_TOKEN` (only to pass the dispatcher's non-empty token check; actual auth uses the Cookie)

**Cookie retrieval**:

1. Log in to https://console.volcengine.com in your browser
2. F12 → Network → find any request → copy the full `Cookie` header (must include `userInfo`, `digest`, `csrfToken`)
3. Save to file:
   ```bash
   echo 'cookie-string' > ~/.claude/statusline/cache/volces_cookie.txt
   chmod 600 ~/.claude/statusline/cache/volces_cookie.txt
   ```

> ⚠️ The `digest` JWT in the Cookie expires in ~2 days. When expired, the status line shows `方舟 ⚠ Cookie已过期`; re-copy the Cookie.

**Auto-refresh** (recommended): a Playwright script logs in and extracts the Cookie automatically, avoiding manual copy:

```bash
~/.claude/statusline/scripts/refresh-volces-cookie.sh          # first run opens a browser for login
~/.claude/statusline/scripts/refresh-volces-cookie.sh --quiet  # quiet mode (sends a Lark notification on expired session, then exits; for cron)
```

- First run opens a browser for manual Volcengine login; session persists to `cache/volces_state/`
- Subsequent runs refresh headlessly, writing to `volces_cookie.txt`
- Requires Node.js + Playwright (auto-installed during setup, shared with the MiMo refresh script)
- Recommended to run via cron or `/loop` every 1–2 days
- In `--quiet` mode, an expired session triggers a Lark DM via lark-cli (deduped per day, no spam); re-login manually with `--force`

**config.json**:
```json
"volces": {
  "token_env": "ANTHROPIC_AUTH_TOKEN",
  "api_url": "https://console.volcengine.com/api/top/ark/cn-beijing/2024-01-01"
}
```

## License

MIT License

---

Author: 一只小火柴๑҉ <lin.llt@qq.com>
