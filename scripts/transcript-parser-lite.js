#!/usr/bin/env node
const fs = require('fs');
const readline = require('readline');
const path = require('path');
const os = require('os');
const crypto = require('crypto');

// 缓存目录
const CACHE_DIR = path.join(os.homedir(), '.claude', 'statusline', 'cache');

// 计算文件哈希
function hashPath(p) {
    return crypto.createHash('sha256').update(path.resolve(p)).digest('hex');
}

// 获取缓存文件路径
function getCachePath(p) {
    return path.join(CACHE_DIR, `${hashPath(p)}.json`);
}

// 获取文件状态
function getFileStat(p) {
    try {
        const s = fs.statSync(p);
        return s.isFile() ? { m: s.mtimeMs, z: s.size } : null;
    } catch {
        return null;
    }
}

// 读取缓存
function loadCache(p, stat) {
    try {
        const c = JSON.parse(fs.readFileSync(getCachePath(p), 'utf8'));
        if (c.p === path.resolve(p) && c.s?.m === stat.m && c.s?.z === stat.z) {
            return c.d;
        }
        return null;
    } catch {
        return null;
    }
}

// 写入缓存
function saveCache(p, stat, data) {
    try {
        fs.mkdirSync(CACHE_DIR, { recursive: true });
        fs.writeFileSync(getCachePath(p), JSON.stringify({ p: path.resolve(p), s: stat, d: data }), 'utf8');
    } catch {}
}

// 标准化状态
function normalizeStatus(s) {
    switch (s) {
        case 'pending':
        case 'not_started':
            return 'pending';
        case 'in_progress':
        case 'running':
            return 'in_progress';
        case 'completed':
        case 'complete':
        case 'done':
            return 'completed';
        default:
            return 'pending';
    }
}

// 获取工具目标描述
function getToolTarget(x) {
    if (!x) return undefined;
    switch (x) {
        case 'Read':
        case 'Write':
        case 'Edit':
            return x.file_path || x.path;
        case 'Glob':
            return x.pattern;
        case 'Grep':
            return x.pattern;
        case 'Bash': {
            const c = x.command;
            return c ? c.slice(0, 20) + (c.length > 20 ? '...' : '') : undefined;
        }
        default:
            return undefined;
    }
}

// 解析 transcript
async function parseTranscript(p) {
    const result = { tools: [], agents: [], todos: [] };

    if (!p || !fs.existsSync(p)) {
        return result;
    }

    const stat = getFileStat(p);
    if (!stat) {
        return result;
    }

    // 检查缓存
    const cached = loadCache(p, stat);
    if (cached) {
        return cached;
    }

    const tools = new Map();
    const agents = new Map();
    let todos = [];
    const todoIndex = new Map();

    try {
        const fileStream = fs.createReadStream(p);
        const rl = readline.createInterface({ input: fileStream, crlfDelay: Infinity });

        for await (const line of rl) {
            if (!line.trim()) continue;

            try {
                const entry = JSON.parse(line);
                const messages = entry.message?.content;
                if (!messages || !Array.isArray(messages)) continue;

                const timestamp = entry.timestamp ? new Date(entry.timestamp) : new Date();

                for (const block of messages) {
                    // 处理 tool_use
                    if (block.type === 'tool_use' && block.id && block.name) {
                        const input = block.input || {};

                        if (block.name === 'Task' || block.name === 'Agent') {
                            // Agent 启动
                            agents.set(block.id, {
                                id: block.id,
                                type: input.subagent_type || 'unknown',
                                model: input.model,
                                description: input.description,
                                status: 'running',
                                startTime: timestamp.getTime()
                            });
                        } else if (block.name === 'TodoWrite') {
                            // TodoWrite - 批量设置 todos
                            if (input.todos && Array.isArray(input.todos)) {
                                todos = input.todos.map(x => ({
                                    content: x.content,
                                    status: normalizeStatus(x.status)
                                }));
                            }
                        } else if (block.name === 'TaskCreate') {
                            // TaskCreate - 创建单个任务
                            const content = input.subject || input.description || 'Untitled';
                            const status = normalizeStatus(input.status);
                            todos.push({ content, status });
                            const id = input.taskId || block.id;
                            if (id) {
                                todoIndex.set(String(id), todos.length - 1);
                            }
                        } else if (block.name === 'TaskUpdate') {
                            // TaskUpdate - 更新任务
                            const id = input.taskId;
                            if (id !== undefined) {
                                let idx = todoIndex.get(String(id));
                                if (idx === undefined && /^\d+$/.test(String(id))) {
                                    const y = parseInt(id, 10) - 1;
                                    if (y >= 0 && y < todos.length) {
                                        idx = y;
                                    }
                                }
                                if (idx !== undefined) {
                                    if (input.status) {
                                        todos[idx].status = normalizeStatus(input.status);
                                    }
                                    if (input.subject || input.description) {
                                        todos[idx].content = input.subject || input.description;
                                    }
                                }
                            }
                        } else {
                            // 普通工具
                            tools.set(block.id, {
                                id: block.id,
                                name: block.name,
                                target: getToolTarget(input),
                                status: 'running',
                                startTime: timestamp.getTime()
                            });
                        }
                    }

                    // 处理 tool_result
                    if (block.type === 'tool_result' && block.tool_use_id) {
                        const tool = tools.get(block.tool_use_id);
                        if (tool) {
                            tool.status = block.is_error ? 'error' : 'completed';
                            tool.endTime = timestamp.getTime();
                        }

                        const agent = agents.get(block.tool_use_id);
                        if (agent) {
                            if (entry.toolUseResult?.isAsync &&
                                entry.toolUseResult.status !== 'completed' &&
                                entry.toolUseResult.status !== 'error') {
                                agent.status = 'running';
                            } else {
                                agent.status = block.is_error ? 'error' : 'completed';
                                agent.endTime = timestamp.getTime();
                            }
                        }
                    }
                }
            } catch {
                // 忽略解析错误的行
            }
        }
    } catch {
        // 忽略文件读取错误
    }

    result.tools = Array.from(tools.values()).slice(-15);
    result.agents = Array.from(agents.values()).slice(-5);
    result.todos = todos.slice(-10);

    saveCache(p, stat, result);
    return result;
}

// 主函数
(async () => {
    const p = process.argv[2];
    if (!p) {
        console.error('Usage: node transcript-parser-lite.js <transcript.jsonl>');
        process.exit(1);
    }
    console.log(JSON.stringify(await parseTranscript(p)));
})().catch(e => {
    console.error('Error:', e.message);
    process.exit(1);
});
