#!/bin/bash
# 余额查询调度器
# balance 为对象格式，key 是 provider 名
# 通过 ANTHROPIC_BASE_URL 推断当前使用的 provider，直接从 balance[key] 获取配置
# Provider 约定: $1 = API token, $2 = api_url (可选), 输出带 ANSI 颜色的字符串, 退出码 0=成功

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

# 检查配置文件是否存在
[ -f "$CONFIG_FILE" ] || exit 0

# 查找 provider 脚本目录
PROVIDER_DIR=""
if [ -d "${PROJECT_ROOT}/config/providers" ]; then
    PROVIDER_DIR="${PROJECT_ROOT}/config/providers"
elif [ -d "${SCRIPT_DIR}/../config/providers" ]; then
    PROVIDER_DIR="${SCRIPT_DIR}/../config/providers"
elif [ -d "${CONFIG_DIR}/providers" ]; then
    PROVIDER_DIR="${CONFIG_DIR}/providers"
fi

[ -n "$PROVIDER_DIR" ] || exit 0

# 从 settings.json 或环境变量读取值
resolve_value() {
    local var_name="$1"
    local value=""
    eval value="\$$var_name" 2>/dev/null || true
    if [ -z "$value" ] && [ -f "$SETTINGS_FILE" ]; then
        # 优先用 node 解析（正确处理含引号的值），fallback 到 grep/sed
        if command -v node >/dev/null 2>&1; then
            value=$(node -e "
                const fs = require('fs');
                const s = JSON.parse(fs.readFileSync(process.argv[1], 'utf8'));
                const keys = process.argv[2].split('.');
                let v = s;
                for (const k of keys) { v = v?.[k]; }
                if (v != null) process.stdout.write(String(v));
            " "$SETTINGS_FILE" "$var_name" 2>/dev/null || true)
        fi
        if [ -z "$value" ]; then
            value=$(grep -o "\"${var_name}\"[[:space:]]*:[[:space:]]*\"[^\"]*\"" "$SETTINGS_FILE" 2>/dev/null | head -1 | sed 's/.*:[[:space:]]*"//;s/"$//')
        fi
    fi
    echo "$value"
}

# 从 URL 中提取 provider 标识
# https://api.kimi.com/coding/     → kimi
# https://api.deepseek.com/v1/     → deepseek
# https://api.moonshot.cn/v1/      → moonshot
# https://api.openai.com/v1/       → openai
# https://api.anthropic.com/v1/    → anthropic
# https://api.groq.com/openai/v1/  → groq
# https://api.together.xyz/v1/     → together
extract_provider_hint() {
    local url="$1"
    local no_proto="${url#https://}"
    no_proto="${no_proto#http://}"
    local domain="${no_proto%%/*}"
    # 去掉常见 TLD 后缀
    local hint="$domain"
    hint="${hint%.com}"
    hint="${hint%.cn}"
    hint="${hint%.xyz}"
    hint="${hint%.io}"
    hint="${hint%.dev}"
    hint="${hint%.net}"
    # 去掉第一个子域名前缀（如 api.、token-plan-cn.）
    if [[ "$hint" == *.* ]]; then
        hint="${hint#*.}"
    fi
    # 取最后一段
    hint="${hint##*.}"
    echo "$hint"
}

# 使用 jq 解析 balance 对象
if command -v jq >/dev/null 2>&1; then
    # 1. 从 settings.json 读取 ANTHROPIC_BASE_URL，推断当前 provider
    base_url=$(resolve_value "ANTHROPIC_BASE_URL")

    provider_name=""
    if [ -n "$base_url" ]; then
        provider_hint=$(extract_provider_hint "$base_url")
        if [ -n "$provider_hint" ]; then
            # 检查 balance 对象中是否有这个 key
            has_key=$(jq -r --arg k "$provider_hint" '(.balance[$k] // null) | type' "$CONFIG_FILE" 2>/dev/null || echo "null")
            if [ "$has_key" = "object" ]; then
                provider_name="$provider_hint"
            fi
        fi
    fi

    # 2. 如果推断失败，fallback 到 balance 对象的第一个 key
    if [ -z "$provider_name" ]; then
        provider_name=$(jq -r '(.balance | keys[0]) // empty' "$CONFIG_FILE" 2>/dev/null || echo "")
    fi

    # 3. 获取配置并调用 provider
    if [ -n "$provider_name" ]; then
        token_env=$(jq -r --arg k "$provider_name" '.balance[$k].token_env // empty' "$CONFIG_FILE")
        api_url=$(jq -r --arg k "$provider_name" '.balance[$k].api_url // empty' "$CONFIG_FILE")

        if [ -z "$token_env" ]; then
            exit 0
        fi

        token=$(resolve_value "$token_env")
        if [ -z "$token" ]; then
            exit 0
        fi

        provider_script="${PROVIDER_DIR}/${provider_name}.sh"
        if [ ! -f "$provider_script" ]; then
            exit 0
        fi

        bash "$provider_script" "$token" "$api_url"
    fi
else
    # jq 不可用，fallback：从 balance 对象中找第一个 key，尝试调用
    # 用 grep 提取 balance 对象中的第一个 key
    first_key=$(grep -o '"balance"[[:space:]]*:[[:space:]]*{' "$CONFIG_FILE" -A 20 2>/dev/null | grep -o '"[a-zA-Z0-9_-]*"[[:space:]]*:' | head -1 | sed 's/"//g;s/[[:space:]]*:$//')
    [ -z "$first_key" ] && exit 0

    token_env=$(grep -o '"token_env"[[:space:]]*:[[:space:]]*"[^"]*"' "$CONFIG_FILE" | head -1 | sed 's/.*:[[:space:]]*"//;s/"$//')
    [ -z "$token_env" ] && exit 0

    api_url=$(grep -o '"api_url"[[:space:]]*:[[:space:]]*"[^"]*"' "$CONFIG_FILE" | head -1 | sed 's/.*:[[:space:]]*"//;s/"$//' || true)

    token=$(resolve_value "$token_env")
    [ -z "$token" ] && exit 0

    provider_script="${PROVIDER_DIR}/${first_key}.sh"
    [ -f "$provider_script" ] || exit 0

    bash "$provider_script" "$token" "$api_url"
fi
