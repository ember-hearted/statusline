#!/bin/bash
# Xiaomi MiMo Cookie 自动刷新入口
# 用法:
#   ~/.claude/statusline/scripts/refresh-xiaomimimo-cookie.sh          # 正常运行
#   ~/.claude/statusline/scripts/refresh-xiaomimimo-cookie.sh --quiet  # 静默模式
#
# 首次运行: 打开浏览器手动登录小米账号
# 后续运行: 复用登录态自动刷新 cookie（无头模式）
# Cookie 有效期约 1 天，建议配合 cron 或 /loop 定时刷新

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COOKIE_FILE="${HOME}/.claude/statusline/cache/xiaomimimo_cookie.txt"
NODE_SCRIPT="${SCRIPT_DIR}/refresh-xiaomimimo-cookie.js"

# 检查 node 和 npx
if ! command -v node >/dev/null 2>&1; then
    echo "错误: 需要安装 Node.js" >&2
    exit 1
fi

# 检查 playwright，未安装时自动安装
if ! node -e "require('playwright')" 2>/dev/null; then
    echo "首次运行，正在安装 Playwright..." >&2
    npm install -g playwright 2>&1 | tail -1
    # 复用系统 Google Chrome，无需下载 Playwright chromium（channel=chrome 由 .js 指定）
    npx playwright install chrome 2>&1 | tail -1
fi

# 运行刷新脚本
node "$NODE_SCRIPT" "$@"

# 显示结果
if [ "$1" != "--quiet" ] && [ -f "$COOKIE_FILE" ]; then
    echo ""
    echo "当前 cookie 内容:"
    cat "$COOKIE_FILE"
    echo ""
fi
