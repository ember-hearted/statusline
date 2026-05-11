#!/bin/bash
# DeepSeek 余额查询脚本
# 从 ~/.claude/settings.json 的 env 中读取 API token，查询 DeepSeek 账户余额
# API 文档: https://api-docs.deepseek.com/zh-cn/api/get-user-balance

set -e

CACHE_DIR="${HOME}/.claude/statusline/cache"
CACHE_FILE="${CACHE_DIR}/deepseek_balance.txt"
CACHE_TTL=300  # 5分钟缓存，避免频繁 API 调用

# 读取缓存（如果未过期）
if [ -f "$CACHE_FILE" ]; then
    cache_mtime=$(stat -f %m "$CACHE_FILE" 2>/dev/null || stat -c %Y "$CACHE_FILE" 2>/dev/null || echo 0)
    cache_age=$(($(date +%s) - cache_mtime))
    if [ "$cache_age" -lt "$CACHE_TTL" ] 2>/dev/null; then
        cat "$CACHE_FILE"
        exit 0
    fi
fi

# 从 settings.json 读取 token（优先环境变量，其次配置文件）
TOKEN="${ANTHROPIC_AUTH_TOKEN}"
if [ -z "$TOKEN" ]; then
    SETTINGS_FILE="${HOME}/.claude/settings.json"
    if [ -f "$SETTINGS_FILE" ]; then
        TOKEN=$(grep -o '"ANTHROPIC_AUTH_TOKEN"[[:space:]]*:[[:space:]]*"[^"]*"' "$SETTINGS_FILE" 2>/dev/null | head -1 | sed 's/.*:[[:space:]]*"//;s/"$//')
    fi
fi

if [ -z "$TOKEN" ]; then
    exit 0
fi

# 调用 DeepSeek API: GET /user/balance
RESPONSE=$(curl -s --max-time 5 "https://api.deepseek.com/user/balance" \
    -H "Authorization: Bearer ${TOKEN}" \
    -H "Content-Type: application/json" 2>/dev/null || true)

if [ -z "$RESPONSE" ]; then
    # API 不可用时使用过期缓存
    if [ -f "$CACHE_FILE" ]; then
        cat "$CACHE_FILE"
    fi
    exit 0
fi

# 检查账户是否可用
IS_AVAILABLE=$(echo "$RESPONSE" | grep -o '"is_available"[[:space:]]*:[[:space:]]*\(true\|false\)' | grep -o 'true\|false' || true)

if [ "$IS_AVAILABLE" != "true" ]; then
    exit 0
fi

# 提取余额信息
TOTAL_BALANCE=$(echo "$RESPONSE" | grep -o '"total_balance"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*:[[:space:]]*"//;s/"$//')
CURRENCY=$(echo "$RESPONSE" | grep -o '"currency"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*:[[:space:]]*"//;s/"$//')

if [ -z "$TOTAL_BALANCE" ]; then
    exit 0
fi

# 格式化货币符号
case "$CURRENCY" in
    CNY) CURRENCY_SYMBOL="¥" ;;
    USD) CURRENCY_SYMBOL="$" ;;
    *) CURRENCY_SYMBOL="$CURRENCY " ;;
esac

OUTPUT="${CURRENCY_SYMBOL}${TOTAL_BALANCE}"

# 写入缓存
mkdir -p "$CACHE_DIR"
echo "$OUTPUT" > "$CACHE_FILE"

echo "$OUTPUT"
