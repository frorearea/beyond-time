// 网页更新提示的**行为**测试：把 web/index.html 里那段内联脚本抽出来，
// 在假的浏览器里真跑一遍，验证"任何情况下遮罩都会消失"。
//
// 为什么需要它（2026-10-11，两次事故）：
//   1. 第一次：reload 挂在没有超时的 fetch 上 → 网络一挂，遮罩永久停留。
//   2. 第二次（真正的元凶）：CSS 写了 `#shelf-notice { display: flex }`，
//      **作者样式压过浏览器默认的 `[hidden]{display:none}`**，遮罩从第一帧就盖住整页。
//      上一版的假浏览器把 `hidden` 当成普通属性记事件，**没模拟 CSS**，所以"通过了"——
//      验证比被测对象浅，等于没测。所以这里改成模拟 classList 与 removeChild。
//
// 用法：node tool/web_entry_test.mjs

import fs from 'node:fs';
import vm from 'node:vm';

const html = fs.readFileSync('web/index.html', 'utf8');
const src = /<script>([\s\S]*?)<\/script>/.exec(html)[1];

let failures = 0;
const check = (name, ok) => {
  console.log(`${ok ? 'PASS' : 'FAIL'}: ${name}`);
  if (!ok) failures++;
};

/** 跑一个场景，返回遮罩节点的状态。 */
function run({ runningBuild, lastAttemptAgoMs, hangMainJs, waitMs, newBuild = 'NEWBUILD' }) {
  const store = {};
  if (runningBuild !== null) store.beyondTimeRunningBuild = runningBuild;
  if (lastAttemptAgoMs !== null) {
    store.beyondTimeUpdateReloadAt = String(Date.now() - lastAttemptAgoMs);
  }

  const node = {
    classes: new Set(),
    removed: false,
    parentNode: null,
  };
  node.parentNode = { removeChild: () => { node.removed = true; } };
  node.classList = { add: (c) => node.classes.add(c) };

  let reloads = 0;
  const sandbox = {
    console, setTimeout, clearTimeout, Promise, Date, Math, JSON, RegExp,
    String, Number, Object, Array, AbortController,
    localStorage: {
      getItem: (k) => (k in store ? store[k] : null),
      setItem: (k, v) => { store[k] = v; },
      removeItem: (k) => { delete store[k]; },
    },
    document: { getElementById: () => node },
    caches: { keys: () => Promise.resolve([]), delete: () => Promise.resolve(true) },
    location: { reload: () => { reloads++; } },
    fetch: (url) => {
      const u = String(url);
      if (u.includes('bootstrap')) {
        return Promise.resolve({
          ok: true,
          text: () => Promise.resolve(`var x = {serviceWorkerVersion: "${newBuild}"}`),
        });
      }
      // 更严苛：永久挂住且**忽略 abort**，比真实 fetch 更难对付
      if (u.includes('main.dart.js') && hangMainJs) return new Promise(() => {});
      return Promise.resolve({ ok: true, text: () => Promise.resolve('') });
    },
  };
  sandbox.window = sandbox;
  vm.createContext(sandbox);
  vm.runInContext(src, sandbox);

  return new Promise((resolve) => {
    setTimeout(() => resolve({ node, reloads, store }), waitMs);
  });
}

// 场景一：main.dart.js 永久挂住（不复现也必须能恢复）
{
  const { node, reloads } = await run({
    runningBuild: 'OLDBUILD',
    lastAttemptAgoMs: 10 * 60 * 1000,
    hangMainJs: true,
    waitMs: 2200,
  });
  check('网络挂住时仍然会 reload', reloads >= 1);
  check('网络挂住时遮罩被从 DOM 删除（不会永久盖住页面）', node.removed);
}

// 场景二：一分钟内刚自动 reload 过（缓存还没换掉）
{
  const { node, reloads } = await run({
    runningBuild: 'OLDBUILD',
    lastAttemptAgoMs: 5 * 1000,
    hangMainJs: true,
    waitMs: 2200,
  });
  check('刚刷过就不再刷页面（防死循环）', reloads === 0);
  check('不再刷页面时遮罩同样被删除', node.removed);
  check('遮罩确实被显示过（不是根本没触发）', node.classes.has('is-on'));
}

// 场景三：首次访问（没有记录）——只记下构建号，不打扰
{
  const { node, reloads, store } = await run({
    runningBuild: null,
    lastAttemptAgoMs: null,
    hangMainJs: false,
    waitMs: 600,
  });
  check('首次访问不显示遮罩', !node.classes.has('is-on'));
  check('首次访问不 reload', reloads === 0);
  check('首次访问记下了构建号', store.beyondTimeRunningBuild === 'NEWBUILD');
}

// 场景四：已经是最新构建
{
  const { node, reloads } = await run({
    runningBuild: 'NEWBUILD',
    lastAttemptAgoMs: null,
    hangMainJs: false,
    waitMs: 600,
  });
  check('同版本不显示遮罩、不 reload', !node.classes.has('is-on') && reloads === 0);
}

console.log('');
if (failures === 0) {
  console.log('网页更新提示的行为测试全部通过。');
} else {
  console.log(`${failures} 项失败。`);
  process.exitCode = 1;
}
