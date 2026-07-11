#!/bin/bash
# 火山方舟 Cookie 自动刷新入口
# 用法:
#   ~/.claude/statusline/scripts/refresh-volces-cookie.sh          # 正常运行
#   ~/.claude/statusline/scripts/refresh-volces-cookie.sh --quiet  # 静默模式
#   ~/.claude/statusline/scripts/refresh-volces-cookie.sh --force  # 强制重新登录(有头)
#
# 首次运行: 打开浏览器手动登录火山引擎账号
# 后续运行: 复用登录态自动刷新 cookie（无头模式）
# Cookie 有效期约 2 天，建议配合 cron 或 /loop 定时刷新

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COOKIE_FILE="${HOME}/.claude/statusline/cache/volces_cookie.txt"
NODE_SCRIPT="${SCRIPT_DIR}/refresh-volces-cookie.js"

# 检查 node
if ! command -v node >/dev/null 2>&1; then
    echo "错误: 需要安装 Node.js" >&2
    exit 1
fi

# 检查 playwright，未安装时自动安装（与 MiMo 刷新脚本共用同一依赖）
# node 从 NODE_SCRIPT 所在目录解析 playwright（与 node_modules 同目录）
if ! [ -d "$SCRIPT_DIR/node_modules/playwright" ]; then
    echo "首次运行，正在安装 Playwright..." >&2
    (cd "$SCRIPT_DIR" && npm install playwright 2>&1 | tail -1)
    # 复用系统 Google Chrome，无需下载 Playwright chromium（channel=chrome 由 .js 指定）
    (cd "$SCRIPT_DIR" && npx playwright install chrome 2>&1 | tail -1)
fi

# 运行刷新脚本（退出码透传，供 cron 判断登录态是否失效）
node "$NODE_SCRIPT" "$@"
exit $?

# 显示结果
if [ "$1" != "--quiet" ] && [ -f "$COOKIE_FILE" ]; then
    echo ""
    echo "当前 cookie 长度: $(wc -c < "$COOKIE_FILE") 字节"
    echo "已写入: $COOKIE_FILE"
fi
