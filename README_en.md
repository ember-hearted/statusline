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
- **LLM balance/usage query**: Configurable multi-provider mode supporting DeepSeek, Kimi, and more
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
cp config/config.json ~/.claude/statusline/
cp scripts/transcript-parser-lite.js ~/.claude/statusline/

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
❦ •■■■■■□□□□₅₆[¥98.66] ▸ claude-space/statusline ▸  test ~2 -1 ▸ 05:42

# Main status line (Kimi)
❦ •■■■■■□□□□₅₆[Kimi 69%/10%] ▸ claude-space/statusline ▸  test ~2 -1 ▸ 05:42

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
- `▸` - Separator
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
│   └── kimi.sh              # Kimi Coding Plan usage query
└── transcript-parser-lite.js # Transcript parser
```

| File | Description |
|------|-------------|
| `statusline.sh` | Main script: parses input, generates statusline output |
| `config.json` | Configuration: color thresholds, display options, balance providers |
| `query-balance.sh` | Balance dispatcher: reads config and calls provider (supports jq multi-provider parsing) |
| `providers/` | Provider scripts directory, each `.sh` encapsulates a vendor's query logic and manages its own colors/format |
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

## License

MIT License

---

Author: 一只小火柴๑҉ <lin.llt@qq.com>
