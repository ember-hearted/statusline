#!/bin/bash
# DeepSeek 余额查询 Provider
# 接口: $1 = API token, 输出格式化余额字符串, 退出码 0=成功
# API 文档: https://api-docs.deepseek.com/zh-cn/api/get-user-balance

set -e

TOKEN="$1"
if [ -z "$TOKEN" ]; then
    exit 1
fi

CACHE_DIR="${HOME}/.claude/statusline/cache"
CACHE_FILE="${CACHE_DIR}/balance_deepseek.txt"
CACHE_TTL=300  # 5分钟缓存

# 读取缓存
if [ -f "$CACHE_FILE" ]; then
    cache_mtime=$(stat -f %m "$CACHE_FILE" 2>/dev/null || stat -c %Y "$CACHE_FILE" 2>/dev/null || echo 0)
    cache_age=$(($(date +%s) - cache_mtime))
    if [ "$cache_age" -lt "$CACHE_TTL" ] 2>/dev/null; then
        cat "$CACHE_FILE"
        exit 0
    fi
fi

RESPONSE=$(curl -s --max-time 5 "https://api.deepseek.com/user/balance" \
    -H "Authorization: Bearer ${TOKEN}" \
    -H "Content-Type: application/json" 2>/dev/null || true)

if [ -z "$RESPONSE" ]; then
    if [ -f "$CACHE_FILE" ]; then
        cat "$CACHE_FILE"
        exit 0
    fi
    exit 1
fi

IS_AVAILABLE=$(echo "$RESPONSE" | grep -o '"is_available"[[:space:]]*:[[:space:]]*\(true\|false\)' | grep -o 'true\|false' || true)
if [ "$IS_AVAILABLE" != "true" ]; then
    exit 1
fi

TOTAL_BALANCE=$(echo "$RESPONSE" | grep -o '"total_balance"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*:[[:space:]]*"//;s/"$//')
CURRENCY=$(echo "$RESPONSE" | grep -o '"currency"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*:[[:space:]]*"//;s/"$//')

if [ -z "$TOTAL_BALANCE" ]; then
    exit 1
fi

case "$CURRENCY" in
    CNY) CURRENCY_SYMBOL="¥" ;;
    USD) CURRENCY_SYMBOL="$" ;;
    *) CURRENCY_SYMBOL="$CURRENCY " ;;
esac

OUTPUT="${CURRENCY_SYMBOL}${TOTAL_BALANCE}"

mkdir -p "$CACHE_DIR"
echo "$OUTPUT" > "$CACHE_FILE"
echo "$OUTPUT"
