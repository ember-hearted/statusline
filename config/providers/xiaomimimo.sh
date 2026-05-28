#!/bin/bash
# Xiaomi Mimo Token Plan 用量查询 Provider
# 接口: GET https://platform.xiaomimimo.com/api/v1/tokenPlan/usage
# 认证: Cookie (api-platform_serviceToken)
# 输入: $1 = cookie 字符串, $2 = api_url (可选)
# 输出: 带 ANSI 颜色的用量字符串

set -e

COOKIE="$1"
if [ -z "$COOKIE" ]; then
    exit 1
fi

CACHE_DIR="${HOME}/.claude/statusline/cache"
CACHE_FILE="${CACHE_DIR}/balance_xiaomimimo.txt"
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

API_URL="${2:-https://platform.xiaomimimo.com/api/v1/tokenPlan/usage}"

RESPONSE=$(curl -s --max-time 10 "$API_URL" \
    -H "accept: */*" \
    -H "content-type: application/json" \
    -H "referer: https://platform.xiaomimimo.com/console/plan-manage" \
    -b "$COOKIE" 2>/dev/null || true)

if [ -z "$RESPONSE" ]; then
    if [ -f "$CACHE_FILE" ]; then
        cat "$CACHE_FILE"
        exit 0
    fi
    exit 1
fi

# 优先用 jq 解析
if command -v jq >/dev/null 2>&1; then
    RESP_CODE=$(echo "$RESPONSE" | jq -r '.code // 1' 2>/dev/null || echo "1")
    if [ "$RESP_CODE" != "0" ]; then
        if [ -f "$CACHE_FILE" ]; then cat "$CACHE_FILE"; exit 0; fi
        exit 1
    fi

    PERCENT=$(echo "$RESPONSE" | jq -r '.data.usage.percent // .data.monthUsage.percent // empty' 2>/dev/null || true)
    PLAN_USED=$(echo "$RESPONSE" | jq -r '.data.usage.items[0].used // empty' 2>/dev/null || true)
    PLAN_LIMIT=$(echo "$RESPONSE" | jq -r '.data.usage.items[0].limit // empty' 2>/dev/null || true)
else
    # Fallback: grep/sed
    RESPONSE_FLAT=$(echo "$RESPONSE" | tr '\n' ' ')
    RESP_CODE=$(echo "$RESPONSE_FLAT" | grep -o '"code"[[:space:]]*:[[:space:]]*[0-9]*' | head -1 | grep -o '[0-9]*$' || echo "1")
    if [ "$RESP_CODE" != "0" ]; then
        if [ -f "$CACHE_FILE" ]; then cat "$CACHE_FILE"; exit 0; fi
        exit 1
    fi
    PERCENT=$(echo "$RESPONSE_FLAT" | grep -o '"percent"[[:space:]]*:[[:space:]]*[0-9.]*' | head -1 | grep -o '[0-9.]*$' || true)
    PLAN_USED=$(echo "$RESPONSE_FLAT" | grep -o '"plan_total_token"[[:space:]]*:[[:space:]]*{[^}]*}' | grep -o '"used"[[:space:]]*:[[:space:]]*[0-9]*' | head -1 | grep -o '[0-9]*$' || true)
    PLAN_LIMIT=$(echo "$RESPONSE_FLAT" | grep -o '"plan_total_token"[[:space:]]*:[[:space:]]*{[^}]*}' | grep -o '"limit"[[:space:]]*:[[:space:]]*[0-9]*' | head -1 | grep -o '[0-9]*$' || true)
fi

if [ -z "$PERCENT" ]; then
    if [ -f "$CACHE_FILE" ]; then cat "$CACHE_FILE"; exit 0; fi
    exit 1
fi

# 转为百分比整数
PCT_INT=$(awk "BEGIN {printf \"%d\", $PERCENT * 100}")

# 颜色
if [ "$PCT_INT" -gt 90 ] 2>/dev/null; then
    COLOR="\033[31m"
elif [ "$PCT_INT" -gt 70 ] 2>/dev/null; then
    COLOR="\033[33m"
else
    COLOR="\033[32m"
fi

# 格式化 used/limit
format_tokens() {
    local val="$1"
    if [ "$val" -ge 100000000 ] 2>/dev/null; then
        awk "BEGIN {printf \"%.1f亿\", $val/100000000}"
    elif [ "$val" -ge 10000 ] 2>/dev/null; then
        awk "BEGIN {printf \"%d万\", $val/10000}"
    else
        echo "$val"
    fi
}

if [ -n "$PLAN_USED" ] && [ -n "$PLAN_LIMIT" ] && [ "$PLAN_LIMIT" -gt 0 ] 2>/dev/null; then
    USED_FMT=$(format_tokens "$PLAN_USED")
    LIMIT_FMT=$(format_tokens "$PLAN_LIMIT")
    OUTPUT="Mimo ${COLOR}${PCT_INT}%\033[0m(${USED_FMT}/${LIMIT_FMT})"
else
    OUTPUT="Mimo ${COLOR}${PCT_INT}%\033[0m"
fi

mkdir -p "$CACHE_DIR"
printf '%b' "$OUTPUT" > "$CACHE_FILE"
printf '%b' "$OUTPUT"
