// 网页入口体检：只检查那些"JS 语法没问题、但页面会被锁死"的东西。
//
// 起因（2026-10-11）：更新提示的 CSS 写成 `#shelf-notice { display: flex }`，
// 而元素上带 `hidden`。**作者样式永远优先于浏览器默认样式表**，所以
// `[hidden] { display: none }` 被压掉，遮罩从第一帧就永久盖住整页，
// `el.hidden = true` 也永远不起作用。`node --check` 完全查不出来——它只查语法。
//
// 用法：node tool/check_web_entry.mjs
// 零依赖，只用 node 内置模块。

import fs from 'node:fs';

const SRC = 'web/index.html';
let failures = 0;
const check = (name, ok) => {
  console.log(`${ok ? 'PASS' : 'FAIL'}: ${name}`);
  if (!ok) failures++;
};

const html = fs.readFileSync(SRC, 'utf8');

// ---------------------------------------------------------------- 样式
const styleBlocks = [...html.matchAll(/<style[^>]*>([\s\S]*?)<\/style>/gi)].map((m) => m[1]);
// 必须先剥掉注释：注释里出现的 `[hidden]{display:none}` 这种片段会被朴素解析器
// 当成一条规则，把后面的选择器全部带跑（这个检查器第一版就是这么自己绊倒的）。
const css = styleBlocks
  .join('\n')
  .replace(/\/\*[\s\S]*?\*\//g, '')
  .replace(/\/\/[^\n]*/g, '');

// 取出所有规则的 {选择器, 声明体}
const rules = [...css.matchAll(/([^{}]+)\{([^{}]*)\}/g)].map((m) => ({
  selector: m[1].trim().replace(/\s+/g, ' '),
  body: m[2].trim(),
}));

const noticeRules = rules.filter((r) =>
  r.selector.split(',').some((s) => s.trim().replace(/\s+/g, ' ').startsWith('#shelf-notice')),
);
check('样式里能找到 #shelf-notice 的规则', noticeRules.length > 0);

// 关键不变量：**不带 .is-on 的规则里不能出现可见的 display**。
// 默认必须不可见——这样即使脚本整段没跑，页面也不会被盖住。
const baseRules = noticeRules.filter(
  (r) => !r.selector.split(',').some((s) => s.includes('.is-on')),
);
const baseDisplay = baseRules
  .map((r) => /(?:^|;)\s*display\s*:\s*([^;]+)/.exec(r.body))
  .filter(Boolean)
  .map((m) => m[1].trim().toLowerCase());
check(
  '#shelf-notice 的基础规则把 display 设为 none（脚本没跑也不会盖住页面）',
  baseDisplay.length > 0 && baseDisplay.every((d) => d === 'none'),
);
check(
  '没有任何基础规则把 #shelf-notice 设成可见（作者样式会压过 [hidden]）',
  !baseDisplay.some((d) => ['flex', 'block', 'grid', 'inline-flex', 'inline-block'].includes(d)),
);
check(
  '显示 #shelf-notice 的规则只挂在 .is-on 上',
  noticeRules.some((r) => r.selector.includes('.is-on') && /display\s*:\s*flex/.test(r.body)),
);
check(
  '淡入动画不带 forwards（否则会把 opacity 永久锁在 1，绕开显隐控制）',
  !noticeRules.some((r) => /animation[^;]*forwards/.test(r.body)),
);

// ---------------------------------------------------------------- 元素
const noticeTag = /<div[^>]*id=["']shelf-notice["'][^>]*>/i.exec(html);
check('页面上有 #shelf-notice 元素', noticeTag !== null);
check(
  '#shelf-notice 不再依赖 hidden 属性（改用 class，避免被作者样式压掉）',
  noticeTag !== null && !/\shidden(\s|>|=)/i.test(noticeTag[0]),
);

// ---------------------------------------------------------------- 脚本
const scripts = [...html.matchAll(/<script>([\s\S]*?)<\/script>/gi)].map((m) => m[1]);
const js = scripts.join('\n');

check('用 classList 控制显隐，而不是 el.hidden', /classList\.(add|toggle)\(/.test(js));
check(
  '遮罩最终是从 DOM 删除的（removeChild），任何样式都撤不回来',
  /removeChild\(/.test(js),
);
check('用 AbortController 给预热请求设了超时', /AbortController/.test(js));
check(
  '有一个"无论如何都 reload"的绝对期限',
  /setTimeout\(\s*reloadOnce\s*,/.test(js),
);
const deadline = Number(
  (/RELOAD_DEADLINE_MS\s*=\s*(\d+)/.exec(js) ?? [])[1] ?? Number.NaN,
);
check(`reload 期限是有限的数字（当前 ${deadline}ms）`, Number.isFinite(deadline) && deadline > 0 && deadline <= 5000);
const noticeVisible = Number(
  (/NOTICE_VISIBLE_MS\s*=\s*(\d+)/.exec(js) ?? [])[1] ?? Number.NaN,
);
check(
  `遮罩可见时间受上限约束（当前 ${noticeVisible}ms）`,
  Number.isFinite(noticeVisible) && noticeVisible > 0 && noticeVisible <= 2500,
);
check('没有再残留对已删除函数的调用', !/\bhideNotice\b/.test(js) && !/\bOVERLAY_MAX_MS\b/.test(js));

// ---------------------------------------------------------------- 结果
console.log('');
if (failures === 0) {
  console.log('网页入口检查全部通过。');
} else {
  console.log(`${failures} 项失败。`);
  process.exitCode = 1;
}
