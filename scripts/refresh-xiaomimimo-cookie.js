#!/usr/bin/env node
/**
 * Xiaomi MiMo Token Plan Cookie 自动刷新脚本
 *
 * 使用 Playwright 保持浏览器登录态，自动提取 api-platform_serviceToken cookie。
 * 首次运行会打开浏览器手动登录，之后复用 session 自动刷新。
 *
 * 用法:
 *   node refresh-xiaomimimo-cookie.js          # 正常运行（首次登录会打开浏览器）
 *   node refresh-xiaomimimo-cookie.js --quiet  # 静默模式（仅自动刷新，登录态失效时静默退出）
 */

const { chromium } = require('playwright');
const fs = require('fs');
const path = require('path');

const COOKIE_FILE = path.join(process.env.HOME, '.claude/statusline/cache/xiaomimimo_cookie.txt');
const STATE_DIR = path.join(process.env.HOME, '.claude/statusline/cache/xiaomimimo_state');
const LOGIN_MARKER = path.join(STATE_DIR, '.login_ok');
const CONSOLE_URL = 'https://platform.xiaomimimo.com/console/plan-manage';
const LOGIN_URL = 'https://account.xiaomi.com/pass/serviceLogin';
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
        if (!QUIET) console.log('正在打开小米 MiMo 控制台...');
        await page.goto(CONSOLE_URL, { waitUntil: 'networkidle', timeout: 30000 });

        // 检查是否被重定向到登录页
        const currentUrl = page.url();
        if (!QUIET) console.log('当前页面:', currentUrl);
        if (currentUrl.includes('account.xiaomi.com')) {
            // 清除登录标记，下次运行时会打开有头浏览器
            try { fs.unlinkSync(LOGIN_MARKER); } catch {}
            if (QUIET) {
                // 静默模式下登录态失效，直接退出
                await browser.close();
                process.exit(1);
            }

            // 等待用户手动登录（最多 5 分钟）
            if (!QUIET) {
                console.log('请在浏览器中完成小米账号登录...');
            }
            await page.waitForURL('**/console/**', { timeout: 300000 });
            // 登录后等待页面加载
            await page.waitForLoadState('networkidle', { timeout: 15000 }).catch(() => {});
        }

        // 等待页面稳定（登录后可能有跳转）
        await new Promise(r => setTimeout(r, 2000));
        await page.waitForLoadState('networkidle', { timeout: 10000 }).catch(() => {});

        // 提取所有 platform cookies（API 需要多个 cookie 共同认证）
        const cookies = await browser.cookies('https://platform.xiaomimimo.com');
        const serviceToken = cookies.find(c => c.name === 'api-platform_serviceToken');

        if (!serviceToken || !serviceToken.value) {
            if (!QUIET) {
                console.error('未找到 api-platform_serviceToken cookie');
                console.log('可用 cookies:', cookies.map(c => `${c.name}@${c.domain}`).join(', '));
            }
            await browser.close();
            process.exit(1);
        }

        // 写入所有 platform cookies（name=value 格式，用分号分隔）
        const cookieValue = cookies
            .filter(c => c.domain.includes('xiaomimimo.com'))
            .map(c => `${c.name}=${c.value}`)
            .join('; ');
        fs.writeFileSync(COOKIE_FILE, cookieValue, 'utf8');

        // 标记登录成功（用于后续无头模式判断）
        fs.writeFileSync(LOGIN_MARKER, new Date().toISOString(), 'utf8');

        if (!QUIET) {
            const expiresDate = serviceToken.expires
                ? new Date(serviceToken.expires * 1000).toLocaleString('zh-CN')
                : '未知';
            console.log(`Cookie 已保存到 ${COOKIE_FILE}`);
            console.log(`过期时间: ${expiresDate}`);
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
