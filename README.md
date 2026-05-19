# Claude Code Statusline

| 中文
| [English](README_en.md)

跨平台的 Claude Code 状态栏脚本，支持动态颜色进度条、Git 状态集成和实时活动显示。

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

## 功能特性

- **进度条前置**：电池风格进度条显示在第一行开头
- **两级目录显示**：显示 `parent/current` 格式的路径
- **电池风格进度条**：`•` 正极 + `■` 满格 + `□` 空格 + 下标百分比
- **动态颜色**：根据 Context 使用量显示不同颜色
  - 🟢 绿色 (< 55%)
  - 🟡 黄色 (55% ~ 75%)
  - 🔴 红色 (> 75%)
- **LLM 余额查询**：可配置的多 provider 模式，支持 DeepSeek、Kimi 等厂商余额/用量显示
- **智能切换**：配置多个 provider，自动显示当前生效（token 有效）的那一个
- **实时活动显示**：显示进行中的 Tools、Agents、Todos 数量
- **Git 状态集成**：显示分支名和文件变动统计
- **跨平台**：Windows (Git Bash/WSL)、macOS、Linux

## 安装

### 方式一：一键安装（推荐）

```bash
# 使用 curl 直接下载安装脚本并执行
curl -fsSL https://raw.githubusercontent.com/ASmallMatch/statusline/master/bin/install.sh | bash

# 或在 Claude Code 中直接运行
bash -c "$(curl -fsSL https://raw.githubusercontent.com/ASmallMatch/statusline/master/bin/install.sh)"
```

安装完成后，在 Claude Code 中运行：
```
/reload-plugins
```

### 方式二：克隆后安装

```bash
# 克隆仓库
git clone git@github.com:ASmallMatch/statusline.git
cd statusline

# 运行安装脚本
bash bin/install.sh
```

安装完成后，在 Claude Code 中运行：
```
/reload-plugins
```

### 安装脚本选项

```bash
# 查看帮助
bash bin/install.sh --help

# 安装到自定义目录
bash bin/install.sh -d /path/to/custom/dir

# 检查安装状态
bash bin/install.sh -c

# 卸载
bash bin/install.sh -u
```

### 手动安装

如果安装脚本无法使用，可以手动安装：

```bash
# 1. 克隆仓库
git clone git@github.com:ASmallMatch/statusline.git
cd statusline

# 2. 创建安装目录
mkdir -p ~/.claude/statusline

# 3. 复制文件
cp bin/statusline.sh ~/.claude/statusline/
cp config/config.json ~/.claude/statusline/
cp scripts/transcript-parser-lite.js ~/.claude/statusline/

# 4. 添加执行权限
chmod +x ~/.claude/statusline/statusline.sh

# 5. 配置 Claude Code
# 编辑 ~/.claude/settings.json，添加：
# {
#   "statusLine": {
#     "command": "bash ~/.claude/statusline/statusline.sh",
#     "type": "command"
#   }
# }

# 6. 重载插件
# 在 Claude Code 中运行: /reload-plugins
```

## 配置

编辑 `~/.claude/statusline/config.json`：

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

`balance` 为**对象格式**，key 是 provider 名称。系统通过读取 `ANTHROPIC_BASE_URL` 自动推断当前使用的 provider，直接命中对应的配置。

### 配置项说明

**colors 分组** - 颜色相关配置：

| 配置项 | 说明 | 默认值 |
|--------|------|--------|
| `colors.thresholds.green` | 绿色阈值（百分比） | 55 |
| `colors.thresholds.yellow` | 黄色阈值（百分比） | 75 |
| `colors.branch` | 分支名颜色代码 | 33（橙色） |

**balance 分组** - 余额/用量查询配置：

| 配置项 | 说明 | 默认值 |
|--------|------|--------|
| `balance.<name>.token_env` | API token 对应的环境变量名 | 见各 provider 说明 |
| `balance.<name>.api_url` | 余额查询 API 地址 | 见各 provider 说明 |

**Token 配置**：在 `~/.claude/settings.json` 的 `env` 中配置：

```json
{
  "env": {
    "ANTHROPIC_BASE_URL": "https://api.kimi.com/coding/",
    "ANTHROPIC_API_KEY": "eyJ...",
    "DEEPSEEK_API_KEY": "sk-..."
  }
}
```

系统会自动读取 `ANTHROPIC_BASE_URL`，从域名中提取 provider 标识（如 `api.kimi.com` → `kimi`），然后直接命中 `balance.kimi` 配置。如果 `ANTHROPIC_BASE_URL` 未设置或匹配失败，则 fallback 到 `balance` 对象的第一个 key。

**panel 分组** - 面板显示选项：

| 配置项 | 说明 | 默认值 |
|--------|------|--------|
| `panel.git.show_git` | 是否显示 Git 状态 | true |
| `panel.git.show_git_changes` | 是否显示文件变动统计 | true |
| `panel.show_time` | 是否显示时间 | true |
| `panel.show_tools` | 是否显示工具活动 | true |
| `panel.show_agents` | 是否显示代理状态 | true |
| `panel.show_todos` | 是否显示待办进度 | true |

| `bar_length` | 进度条长度 | 10 |

## 显示效果

```
# 主状态行（DeepSeek）
❦ •■■■■■□□□□₅₆[¥98.66] ▸ claude-space/statusline ▸  test ~2 -1 ▸ 05:42

# 主状态行（Kimi）
❦ •■■■■■□□□□₅₆[Kimi 69%/10%] ▸ claude-space/statusline ▸  test ~2 -1 ▸ 05:42

# 有活动时的附加行
  ❦ Tools  3 running
  ❦ Agents 2 running
  ❦ Todos  2/5
```

格式说明：

- `❦` - 进度条前缀符号
- `•` - 电池正极（始终显示）
- `■■■■■` - 已使用的 Context（绿色/黄色/红色）
- `□□□□` - 未使用的 Context
- `₅₆` - 使用百分比（下标数字）
- `[¥98.66]` - DeepSeek 余额（括号内着色）
- `[Kimi 69%/10%]` - Kimi Coding Plan 用量（5h使用率/周度使用率，各自着色）
- `▸` - 分隔符
- `claude-space/statusline` - 两级目录名（青色）
- ` test` - Git 分支（橙色）
- `~2 -1` - 文件变动统计（修改2个，删除1个）
- `05:42` - 时间（灰色）

**活动行**（仅当有进行中的活动时显示）：
- `❦ Tools  3 running` - 有3个工具正在执行（黄色）
- `❦ Agents 2 running` - 有2个代理正在工作（青色）
- `❦ Todos  2/5` - 2个待办进行中，总共5个（绿色）

## 文件结构

```
~/.claude/statusline/
├── config.json              # 配置文件
├── statusline.sh            # 主脚本
├── query-balance.sh         # 余额查询调度器
├── providers/               # Provider 脚本目录
│   ├── deepseek.sh          # DeepSeek 余额查询
│   └── kimi.sh              # Kimi Coding Plan 用量查询
└── transcript-parser-lite.js # Transcript 解析器
```

| 文件 | 说明 |
|------|------|
| `statusline.sh` | 主脚本：解析输入、生成状态栏输出 |
| `config.json` | 配置文件：颜色阈值、显示选项、余额 provider |
| `query-balance.sh` | 余额调度器：读取配置并调用对应 provider（支持 jq 多 provider 解析） |
| `providers/` | Provider 脚本目录，每个 `.sh` 封装一个厂商的查询逻辑，自行管理颜色和格式 |
| `transcript-parser-lite.js` | Transcript 解析器：提取 Tools/Agents/Todos 状态 |
| `install.sh` | 安装脚本：部署到 `~/.claude/statusline/` |

## Provider 说明

### DeepSeek

- **接口**：`GET https://api.deepseek.com/user/balance`
- **显示**：`¥余额`
- **颜色**：余额 < ¥5 红色，否则黄色

### Kimi Coding Plan

- **接口**：`GET https://api.kimi.com/coding/v1/usages`
- **显示**：`Kimi 5h使用率%/周度使用率%`
- **颜色**：两个百分比**各自独立着色**
  - 5小时窗口：>80% 红，>50% 黄，否则绿
  - 周度配额：>90% 红，>70% 黄，否则绿
- **Token**：使用 `ANTHROPIC_API_KEY`（因为 Kimi 通过 OpenAI 兼容协议接入）

## 许可证

MIT License

---

作者：一只小火柴๑҉ <lin.llt@qq.com>
