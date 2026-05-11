#!/bin/bash
# 余额查询调度器
# 根据 config.json 中的 balance 配置，查找并调用对应 provider
# Provider 约定: 接收 API token 为 $1，输出格式化余额，退出码 0=成功

set -e

CONFIG_DIR="${CLAUDE_STATUSLINE_DIR:-$HOME/.claude/statusline}"
SETTINGS_FILE="$HOME/.claude/settings.json"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# 确定配置文件路径：优先项目配置（开发模式），其次安装目录配置
if [ -f "${PROJECT_ROOT}/config/config.json" ]; then
    CONFIG_FILE="${PROJECT_ROOT}/config/config.json"
elif [ -f "${SCRIPT_DIR}/../config/config.json" ]; then
    CONFIG_FILE="${SCRIPT_DIR}/../config/config.json"
else
    CONFIG_FILE="$CONFIG_DIR/config.json"
fi

# 读取 balance.provider
BALANCE_PROVIDER=""
if [ -f "$CONFIG_FILE" ]; then
    BALANCE_PROVIDER=$(grep -o '"provider"[[:space:]]*:[[:space:]]*"[^"]*"' "$CONFIG_FILE" | head -1 | sed 's/.*:[[:space:]]*"//;s/"$//')
fi
[ -z "$BALANCE_PROVIDER" ] && exit 0

# 读取 balance.token_env
TOKEN_ENV=""
if [ -f "$CONFIG_FILE" ]; then
    TOKEN_ENV=$(grep -o '"token_env"[[:space:]]*:[[:space:]]*"[^"]*"' "$CONFIG_FILE" | head -1 | sed 's/.*:[[:space:]]*"//;s/"$//')
fi
[ -z "$TOKEN_ENV" ] && exit 0

# 获取 token: 优先环境变量，其次 settings.json
TOKEN=""
eval TOKEN="\$$TOKEN_ENV" 2>/dev/null || true
if [ -z "$TOKEN" ] && [ -f "$SETTINGS_FILE" ]; then
    TOKEN=$(grep -o "\"${TOKEN_ENV}\"[[:space:]]*:[[:space:]]*\"[^\"]*\"" "$SETTINGS_FILE" 2>/dev/null | head -1 | sed 's/.*:[[:space:]]*"//;s/"$//')
fi
[ -z "$TOKEN" ] && exit 0

# 查找 provider 脚本
PROVIDER_SCRIPT=""
if [ -f "${PROJECT_ROOT}/config/providers/${BALANCE_PROVIDER}.sh" ]; then
    PROVIDER_SCRIPT="${PROJECT_ROOT}/config/providers/${BALANCE_PROVIDER}.sh"
elif [ -f "${SCRIPT_DIR}/../config/providers/${BALANCE_PROVIDER}.sh" ]; then
    PROVIDER_SCRIPT="${SCRIPT_DIR}/../config/providers/${BALANCE_PROVIDER}.sh"
elif [ -f "${CONFIG_DIR}/providers/${BALANCE_PROVIDER}.sh" ]; then
    PROVIDER_SCRIPT="${CONFIG_DIR}/providers/${BALANCE_PROVIDER}.sh"
fi

if [ -z "$PROVIDER_SCRIPT" ] || [ ! -f "$PROVIDER_SCRIPT" ]; then
    exit 0
fi

bash "$PROVIDER_SCRIPT" "$TOKEN"
