#!/bin/bash
# 火山方舟 Cookie 过期检查与自动刷新
# 用法:
#   ~/.claude/statusline/scripts/check-volces-cookie.sh
#
# 逻辑:
#   - cookie 文件不存在 → 触发刷新
#   - 取不到 digest → 触发刷新
#   - digest 过期或 1 小时内即将过期 → 触发刷新
#   - 否则静默退出
#
# 设计为 Claude Code SessionStart hook 调用,async 模式避免阻塞启动。

set -e

COOKIE_FILE="${HOME}/.claude/statusline/cache/volces_cookie.txt"
REFRESH_SCRIPT="${HOME}/.claude/statusline/scripts/refresh-volces-cookie.sh"
REFRESH_THRESHOLD_SECONDS=3600  # 提前 1 小时刷新

# 未安装刷新脚本时直接退出(可能用户只装了核心组件)
[ -x "$REFRESH_SCRIPT" ] || exit 0

# cookie 文件不存在时触发刷新
if [ ! -f "$COOKIE_FILE" ]; then
    "$REFRESH_SCRIPT" --quiet
    exit 0
fi

# 从 cookie 中提取 digest JWT
DIGEST=$(grep -o 'digest=[^;]*' "$COOKIE_FILE" 2>/dev/null | head -1 | sed 's/digest=//' || true)
if [ -z "$DIGEST" ]; then
    "$REFRESH_SCRIPT" --quiet
    exit 0
fi

# 解析 JWT payload 中的 exp 字段(秒级时间戳)
EXP=$(node -e '
const digest = process.argv[1];
const part = digest.split(".")[1];
if (!part) { console.log(0); process.exit(0); }
const base64 = part.replace(/-/g, "+").replace(/_/g, "/");
const padded = base64 + "=".repeat((4 - base64.length % 4) % 4);
try {
    const payload = JSON.parse(Buffer.from(padded, "base64").toString("utf8"));
    console.log(payload.exp || 0);
} catch {
    console.log(0);
}
' "$DIGEST" 2>/dev/null || echo 0)

NOW=$(date +%s)
REFRESH_THRESHOLD=$((EXP - REFRESH_THRESHOLD_SECONDS))

# 过期、即将过期或无法解析时触发刷新
if [ "$EXP" -eq 0 ] 2>/dev/null || [ "$NOW" -ge "$REFRESH_THRESHOLD" ] 2>/dev/null; then
    "$REFRESH_SCRIPT" --quiet
fi
