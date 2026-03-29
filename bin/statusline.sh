#!/bin/bash
# Claude Code StatusLine 主脚本
# 跨平台支持: Windows (Git Bash/WSL), macOS, Linux

set -e

# 读取输入
input=$(cat)

# 配置目录
CONFIG_DIR="${CLAUDE_STATUSLINE_DIR:-$HOME/.claude/statusline}"
CONFIG_FILE="$CONFIG_DIR/config.json"

# 脚本所在目录（用于开发模式下定位资源）
SCRIPT_DIR_STATUSLINE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 解析配置（简单解析，不依赖 jq）
# 支持嵌套路径，如 "colors.thresholds.green"
parse_config() {
    local key_path="$1"
    local default="$2"

    if [ -f "$CONFIG_FILE" ]; then
        # 读取整个文件内容
        local config_content=$(cat "$CONFIG_FILE" 2>/dev/null)

        # 将路径按.分割，逐级查找
        local keys=$(echo "$key_path" | tr '.' '\n')
        local current="$config_content"
        local found=true

        for key in $keys; do
            # 在当前层级查找 key
            local pattern="\"$key\"[[:space:]]*:[[:space:]]*"
            if echo "$current" | grep -q "$pattern"; then
                # 提取该 key 的值部分
                local value=$(echo "$current" | grep -o "\"$key\"[[:space:]]*:[[:space:]]*[^,}]*" | head -1)
                if [ -n "$value" ]; then
                    # 获取值后的内容（可能是对象或简单值）
                    local after_key=$(echo "$value" | sed "s/\"$key\"[[:space:]]*:[[:space:]]*//")

                    # 如果是对象（以{开头），在 current 中查找该对象的内容
                    if echo "$after_key" | grep -q '^\s*{'; then
                        # 提取对象内容（需要匹配花括号）
                        local obj_start=$(echo "$current" | grep -b -o "\"$key\"[[:space:]]*:[[:space:]]*{" | head -1 | cut -d: -f1)
                        if [ -n "$obj_start" ]; then
                            # 从对象开始位置提取，尝试匹配花括号
                            local obj_content=$(echo "$current" | tail -c +$((obj_start + 1)))
                            # 简单匹配：找到第一个完整的 {...}
                            # 使用 sed 匹配花括号对
                            current=$(echo "$obj_content" | sed 's/[^{]*\({\).*/\1/; :a; N; s/\n//; ta' | head -c 1000 | sed 's/^{\([^{}]*\)}.*/\1/')
                        else
                            found=false
                            break
                        fi
                    else
                        # 简单值，直接使用
                        current="$after_key"
                    fi
                else
                    found=false
                    break
                fi
            else
                found=false
                break
            fi
        done

        if [ "$found" = true ] && [ -n "$current" ]; then
            # 清理值（去掉引号）
            echo "$current" | sed 's/^"//;s/"$//' | tr -d '[:space:]'
            return
        fi
    fi

    echo "$default"
}

# 读取配置（使用新的嵌套结构）
green_threshold=$(parse_config "colors.thresholds.green" "55")
yellow_threshold=$(parse_config "colors.thresholds.yellow" "75")
bar_length=$(parse_config "bar_length" "10")
show_git=$(parse_config "panel.git.show_git" "true")
show_time=$(parse_config "panel.show_time" "true")
branch_color=$(parse_config "colors.branch" "33" | tr -d '"')  # 默认橙色(33)，确保去掉引号
show_tools=$(parse_config "panel.show_tools" "true")
show_agents=$(parse_config "panel.show_agents" "true")
show_todos=$(parse_config "panel.show_todos" "true")
show_git_changes=$(parse_config "panel.git.show_git_changes" "true")

# 获取基本信息
username=$(whoami 2>/dev/null || echo "user")
full_path=$(echo "$input" | grep -o '"cwd":"[^"]*"' | cut -d'"' -f4)
[ -z "$full_path" ] && full_path="$PWD"
current_dir=$(basename "$full_path")

# 直接使用输入的 used_percentage
used_pct=$(echo "$input" | grep -o '"used_percentage":[0-9]*' | cut -d':' -f2)
[ -z "$used_pct" ] && used_pct="0"

# 颜色判断
if [ "$used_pct" -lt "$green_threshold" ] 2>/dev/null; then
    bar_color="\033[32m"      # 绿色
elif [ "$used_pct" -le "$yellow_threshold" ] 2>/dev/null; then
    bar_color="\033[33m"      # 黄色
else
    bar_color="\033[31m"      # 红色
fi

# 生成电池风格进度条
# 计算总点数 (每格100点)
total_points=$((used_pct * bar_length))
full_cells=$((total_points / 100))
remainder=$((total_points % 100))

# 电池符号: ■=满格 •=小格(正极效果) □=空格
full_block="■"
small_block="•"
empty_block="□"

progress_bar=""
i=0

# 先显示小格（正极在最前面），所有情况都显示包括0%
if [ $i -lt $bar_length ]; then
    progress_bar="${small_block}"
    i=$((i + 1))
fi

# 填充满格（小格已经占了一格位置，所以满格数不变，但总长度要减1）
filled_count=0
while [ $filled_count -lt $full_cells ] && [ $i -lt $bar_length ]; do
    progress_bar="${progress_bar}${full_block}"
    i=$((i + 1))
    filled_count=$((filled_count + 1))
done

# 填充空格
while [ $i -lt $bar_length ]; do
    progress_bar="${progress_bar}${empty_block}"
    i=$((i + 1))
done

# Git 信息
git_info=""
has_git=false
if [ "$show_git" = "true" ]; then
    if git -C "$full_path" rev-parse --git-dir > /dev/null 2>&1 || \
       (cd "$full_path" 2>/dev/null && git rev-parse --git-dir > /dev/null 2>&1); then
        has_git=true
        # 获取分支名
        branch=$(cd "$full_path" 2>/dev/null && git -c core.fileMode=false branch --show-current 2>/dev/null || echo "detached")

        # 获取状态
        status=$(cd "$full_path" 2>/dev/null && git -c core.fileMode=false status --porcelain 2>/dev/null)

        # Git 符号: +=新增 -=删除 ~=修改 ✓=暂存
        if [ -z "$status" ]; then
            git_status=""
        else
            # 统计各类变动（使用echo避免grep返回非零退出码，只取第一个数字）
            added=$(echo "$status" | grep -c "^??" 2>/dev/null | head -1 || echo "0")
            modified=$(echo "$status" | grep -c "^ M" 2>/dev/null | head -1 || echo "0")
            deleted=$(echo "$status" | grep -c "^ D" 2>/dev/null | head -1 || echo "0")
            staged=$(echo "$status" | grep -c "^[AM]." 2>/dev/null | head -1 || echo "0")
            # 构建状态字符串（过滤掉0值）
            git_status=""
            [ "$added" != "0" ] && git_status="${git_status}+${added} "
            [ "$modified" != "0" ] && git_status="${git_status}~${modified} "
            [ "$deleted" != "0" ] && git_status="${git_status}-${deleted} "
            [ "$staged" != "0" ] && git_status="${git_status}✓${staged} "
            # 去掉末尾空格（使用参数扩展代替sed）
            git_status="${git_status% }"
        fi
        git_info="${branch}${git_status}"
    fi
fi

# 颜色定义
c_gray="\033[38;5;245m"      # 灰色
c_cyan="\033[36m"           # 青色
c_blue="\033[34m"           # 蓝色
c_purple="\033[35m"         # 紫色
c_white="\033[37m"         # 白色
c_dim="\033[2m"             # 暗淡
c_yellow="\033[33m"         # 黄色
c_green="\033[32m"         # 绿色
reset_color="\033[0m"

# ========== JSON 解析函数（必须在调用前定义） ==========

# 从 JSON 解析工具活动 - 只显示进行中的数量
parse_tools_from_json() {
    local json="$1"

    # 检查是否有工具
    local has_tools=$(echo "$json" | grep -o '"tools":\[[^]]*\]' | grep -v '"tools":\[\]')
    [ -z "$has_tools" ] && return

    # 统计运行中的工具数量
    local running_count=$(echo "$json" | grep -o '"status":"running"' | wc -l | tr -d ' ')

    # 只有运行中的工具大于0才显示
    if [ "$running_count" -gt 0 ]; then
        echo "❦ Tools  ${running_count} running"
    fi
}

# 从 JSON 解析代理状态 - 只显示进行中的数量
parse_agents_from_json() {
    local json="$1"

    # 检查是否有代理
    local has_agents=$(echo "$json" | grep -o '"agents":\[[^]]*\]' | grep -v '"agents":\[\]')
    [ -z "$has_agents" ] && return

    # 统计运行中的代理数量
    local running_count=$(echo "$json" | grep -o '"status":"running"[^}]*"type":"[^"]*"' | wc -l | tr -d ' ')

    # 只有运行中的代理大于0才显示
    if [ "$running_count" -gt 0 ]; then
        echo "❦ Agents ${running_count} running"
    fi
}

# 从 JSON 解析待办进度 - 只显示进行中的数量
parse_todos_from_json() {
    local json="$1"

    # 检查是否有待办
    local has_todos=$(echo "$json" | grep -o '"todos":\[[^]]*\]' | grep -v '"todos":\[\]')
    [ -z "$has_todos" ] && return

    # 提取 todos 数组内容
    local todos_array=$(echo "$json" | sed 's/.*"todos":\[\([^]]*\)\].*/\1/')

    # 统计各状态数量
    local completed=$(echo "$todos_array" | grep -o '"status":"completed"' | wc -l | tr -d ' ')
    local in_progress_count=$(echo "$todos_array" | grep -o '"status":"in_progress"' | wc -l | tr -d ' ')
    local pending=$(echo "$todos_array" | grep -o '"status":"pending"' | wc -l | tr -d ' ')
    local total=$((completed + in_progress_count + pending))

    # 有进行中的待办才显示
    if [ "$in_progress_count" -gt 0 ]; then
        echo "❦ Todos  ${in_progress_count}/${total}"
    fi
}

# 显示两级目录名（如：parent/current）
get_two_level_path() {
    local path="$1"
    # 移除末尾的斜杠
    path="${path%/}"
    # 根目录特殊情况
    [ -z "$path" ] && path="/"
    local current=$(basename "$path")
    local parent=$(basename "$(dirname "$path")")
    # 如果当前是根目录
    [ "$current" = "/" ] && current="root"
    # 如果父目录是根目录或空，只显示当前目录
    if [ "$parent" = "/" ] || [ -z "$parent" ] || [ "$parent" = "." ]; then
        echo "$current"
    else
        echo "${parent}/${current}"
    fi
}
display_path=$(get_two_level_path "$full_path")

# 路径着色
dir_display="${c_cyan}${display_path}${reset_color}"

# 分隔符
sep="${c_gray}▸${reset_color}"

# Git 信息简化
branch_display=""
branch_color_code="\033[${branch_color}m"
if [ "$show_git" = "true" ]; then
    if [ "$has_git" = true ]; then
        # 根据配置决定是否显示文件变动详情
        if [ "$show_git_changes" = "true" ] && [ -n "$git_status" ]; then
            branch_display=" ${sep} ${branch_color_code} ${branch}${reset_color} ${git_status}"
        else
            branch_display=" ${sep} ${branch_color_code} ${branch}${reset_color}"
        fi
    else
        # 没有 Git 仓库时显示 no-git
        branch_display=" ${sep} ${c_gray}no-git${reset_color}"
    fi
fi

# 时间（只显示时间，省略日期）
time_display=""
if [ "$show_time" = "true" ]; then
    time_now=$(date +%H:%M 2>/dev/null || echo "")
    [ -n "$time_now" ] && time_display=" ${sep} ${c_gray}${time_now}${reset_color}"
fi

# ========== Transcript 解析 ==========
# 获取 transcript 路径
transcript_path=$(echo "$input" | grep -o '"transcript_path":"[^"]*"' | cut -d'"' -f4)

# 初始化活动行
tools_line=""
agents_line=""
todos_line=""

# 解析 transcript（如果路径存在且 Node.js 可用）
if [ -n "$transcript_path" ] && [ -f "$transcript_path" ] && command -v node >/dev/null 2>&1; then
    # 优先使用项目目录的解析器（开发模式），否则使用 CONFIG_DIR 中的
    if [ -f "${SCRIPT_DIR_STATUSLINE}/../scripts/transcript-parser-lite.js" ]; then
        parser_script="${SCRIPT_DIR_STATUSLINE}/../scripts/transcript-parser-lite.js"
    elif [ -f "${SCRIPT_DIR_STATUSLINE}/transcript-parser-lite.js" ]; then
        parser_script="${SCRIPT_DIR_STATUSLINE}/transcript-parser-lite.js"
    else
        parser_script="${CONFIG_DIR}/transcript-parser-lite.js"
    fi
    if [ -f "$parser_script" ]; then
        transcript_data=$(node "$parser_script" "$transcript_path" 2>/dev/null)

        if [ -n "$transcript_data" ]; then
            # 解析工具活动
            if [ "$show_tools" = "true" ]; then
                tools_line=$(parse_tools_from_json "$transcript_data")
            fi

            # 解析代理状态
            if [ "$show_agents" = "true" ]; then
                agents_line=$(parse_agents_from_json "$transcript_data")
            fi

            # 解析待办进度
            if [ "$show_todos" = "true" ]; then
                todos_line=$(parse_todos_from_json "$transcript_data")
            fi
        fi
    fi
fi

# ========== 输出生成 ==========
# 下标数字映射
subscript_digits() {
    echo "$1" | sed 's/0/₀/g; s/1/₁/g; s/2/₂/g; s/3/₃/g; s/4/₄/g; s/5/₅/g; s/6/₆/g; s/7/₇/g; s/8/₈/g; s/9/₉/g'
}
used_pct_sub=$(subscript_digits "$used_pct")

# 进度条显示
progress_display="${bar_color}❦ ${progress_bar}${used_pct_sub}${reset_color}"

# 第一行: 进度条 · 路径 · 分支 · 时间
statusline="${progress_display} ${sep} ${dir_display}${branch_display}${time_display}"

# 主状态行前缀
main_prefix=""
# 活动行前缀
activity_prefix="  "

# 输出主状态行
echo -e "${statusline}"

# 输出活动行（如果有）
[ -n "$tools_line" ] && echo -e "${activity_prefix}${c_yellow}${tools_line}${reset_color}"
[ -n "$agents_line" ] && echo -e "${activity_prefix}${c_cyan}${agents_line}${reset_color}"
[ -n "$todos_line" ] && echo -e "${activity_prefix}${c_green}${todos_line}${reset_color}"

exit 0
