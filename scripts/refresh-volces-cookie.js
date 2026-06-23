#!/usr/bin/env node
/**
 * 火山方舟 (Volcengine Ark) Cookie 自动刷新脚本
 *
 * 使用 Playwright 保持浏览器登录态，自动提取 console.volcengine.com 的完整 Cookie。
 * 首次运行会打开浏览器手动登录，之后复用 session 自动刷新。
 *
 * Cookie 用于 volces.sh 查询 Coding/Agent Plan 用量，有效期约 2 天。
 *
 * 用法:
 *   node refresh-volces-cookie.js          # 正常运行（首次登录会打开浏览器）
 *   node refresh-volces-cookie.js --quiet  # 静默模式（仅自动刷新，登录态失效时静默退出）
 *   node refresh-volces-cookie.js --force  # 强制有头模式（用于重新登录）
 */

const { chromium } = require('playwright');
const fs = require('fs');
const path = require('path');

const COOKIE_FILE = path.join(process.env.HOME, '.claude/statusline/cache/volces_cookie.txt');
const STATE_DIR = path.join(process.env.HOME, '.claude/statusline/cache/volces_state');
const LOGIN_MARKER = path.join(STATE_DIR, '.login_ok');
// 用量页作为登录态探测目标（未登录会重定向到统一登录）
const CONSOLE_URL = 'https://console.volcengine.com/ark/region:cn-beijing/subscription/coding-plan';
// 未登录时可能重定向到这些域/路径
const LOGIN_HOSTS = ['signin.volcengine.com', 'passport.volcengine.com', 'console.volcengine.com/login'];
const QUIET = process.argv.includes('--quiet');
const FORCE = process.argv.includes('--force');

async function main() {
    fs.mkdirSync(path.dirname(COOKIE_FILE), { recursive: true });
    fs.mkdirSync(STATE_DIR, { recursive: true });

    // 用标记文件判断是否曾成功登录（persistent context 会自动创建目录结构）
    // --force 时强制有头模式（用于首次登录或重新登录）
    const hasState = !FORCE && fs.existsSync(LOGIN_MARKER);

    const browser = await chromium.launchPersistentContext(STATE_DIR, {
        headless: hasState, // 有登录态时无头运行，否则有头让用户登录
        viewport: { width: 1280, height: 800 },
        locale: 'zh-CN',
    });

    const page = browser.pages()[0] || await browser.newPage();

    try {
        if (!QUIET) console.log('正在打开火山方舟控制台...');
        await page.goto(CONSOLE_URL, { waitUntil: 'networkidle', timeout: 30000 }).catch(() => {});

        // 检查是否被重定向到登录页，或缺少登录态 cookie
        const currentUrl = page.url();
        if (!QUIET) console.log('当前页面:', currentUrl);
        let cookies = await browser.cookies('https://console.volcengine.com');
        const needsLogin = LOGIN_HOSTS.some(h => currentUrl.includes(h))
            || !cookies.some(c => c.name === 'userInfo');
        if (needsLogin) {
            try { fs.unlinkSync(LOGIN_MARKER); } catch {}
            if (QUIET) {
                // 静默模式下登录态失效，直接退出
                await browser.close();
                process.exit(1);
            }

            // 等待用户手动登录（最多 5 分钟），登录成功会跳回控制台域名
            if (!QUIET) {
                console.log('请在浏览器中完成火山引擎账号登录...');
            }
            await page.waitForURL('**/console.volcengine.com/**', { timeout: 300000 }).catch(() => {});
            await page.waitForLoadState('networkidle', { timeout: 15000 }).catch(() => {});
        }

        // 等待页面稳定（登录后可能有跳转）
        await new Promise(r => setTimeout(r, 2000));
        await page.waitForLoadState('networkidle', { timeout: 10000 }).catch(() => {});

        // 提取 console.volcengine.com 的全部 cookie（用量接口需 userInfo/digest/csrfToken 共同认证）
        cookies = await browser.cookies('https://console.volcengine.com');
        const userInfo = cookies.find(c => c.name === 'userInfo');
        const digest = cookies.find(c => c.name === 'digest');
        const csrfToken = cookies.find(c => c.name === 'csrfToken');

        if (!userInfo || !digest || !csrfToken) {
            if (!QUIET) {
                console.error('未找到关键 cookie (userInfo/digest/csrfToken)');
                console.log('可用 cookies:', cookies.map(c => `${c.name}@${c.domain}`).join(', '));
            }
            await browser.close();
            process.exit(1);
        }

        // 写入全部 console cookie（name=value 格式，用分号分隔）
        const cookieValue = cookies
            .filter(c => c.domain.includes('volcengine.com'))
            .map(c => `${c.name}=${c.value}`)
            .join('; ');
        fs.writeFileSync(COOKIE_FILE, cookieValue, 'utf8');
        fs.chmodSync(COOKIE_FILE, 0o600);

        // 标记登录成功（用于后续无头模式判断）
        fs.writeFileSync(LOGIN_MARKER, new Date().toISOString(), 'utf8');

        if (!QUIET) {
            // digest 是 JWT，解析 exp 显示过期时间
            let expiresStr = '未知';
            try {
                const payload = JSON.parse(Buffer.from(digest.value.split('.')[1], 'base64').toString());
                if (payload.exp) {
                    expiresStr = new Date(payload.exp * 1000).toLocaleString('zh-CN');
                }
            } catch {}
            console.log(`Cookie 已保存到 ${COOKIE_FILE}`);
            console.log(`digest 过期时间: ${expiresStr}`);
        }
    } catch (err) {
        if (!QUIET) {
            console.error('刷新失败:', err.message);
        }
        await browser.close();
        process.exit(1);
    }

    await browser.close();
}

main();
