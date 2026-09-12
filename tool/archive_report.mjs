// 图书馆存档体检：用真实对话日志度量人设与工程健康度。
//
// 用法：
//   node tool/archive_report.mjs beyond-time-library-2026-09-12_20-46-51-667.json
//   node tool/archive_report.mjs <存档.json> --full   （额外输出对话全文摘要）
//
// 这是"日志驱动迭代"的入口（D2）：改动人设 / system prompt / 记忆策略后，
// 跑一遍真实存档，看指标是否真的变好。零依赖，只用 node 内置模块。
//
// 支持存档格式 v1 与 v2。v2 起消息带 kind、并包含 openThreads。

import fs from 'node:fs';

const src = process.argv[2];
const full = process.argv.includes('--full');
if (!src) {
  console.error('用法：node tool/archive_report.mjs <存档.json> [--full]');
  process.exit(1);
}

const j = JSON.parse(fs.readFileSync(src, 'utf8'));
const msgs = j.messages ?? [];
const version = Number(j.version ?? 1);
const threads = j.openThreads ?? [];
const A = msgs.filter((m) => m.role === 'assistant');
const U = msgs.filter((m) => m.role === 'user');

// v2 存档自带 kind，可以直接信任；v1 存档只能靠内容特征反推噪音。
const isNoise = (m) => {
  if (m.kind && m.kind !== 'chat') return true;
  const t = (m.content ?? '').trim();
  return (
    /^(这个房间|欢迎回来|你好像在想|天花板|蜡烛的火焰|书架上有本书|你还在听|灯芯跳|炉火弱|茶凉了|一天没见|门外的事|你回来了|嗯。去吧|好。我不问|才离开|外面的雨|我刚刚翻了翻|你要是想睡|我以为你不会回来|我还以为|要走一会儿吗|去吧。|回来了？|这么快就回来了)/.test(
      t,
    ) ||
    t.includes('还没有填写 API Key') ||
    t.includes('属于图书馆了') ||
    t.includes('已经在书页里了') ||
    t.startsWith('连接没有成功')
  );
};
const real = A.filter((m) => !isNoise(m));

const line = (t) => console.log(`\n=== ${t} ===`);
const pct = (n, d) => `${n}/${d}${d ? ` (${Math.round((n / d) * 100)}%)` : ''}`;
const stat = (a) =>
  a.length
    ? `min=${Math.min(...a)} max=${Math.max(...a)} avg=${Math.round(a.reduce((x, y) => x + y, 0) / a.length)}`
    : 'n/a';

console.log(`存档：${src}`);
console.log(`导出时间 ${j.exportedAt}　格式 v${version}`);
console.log(
  `消息 ${msgs.length}（艾蕾塔 ${A.length} / 来访者 ${U.length}）　记忆 ${(j.libraryMemory ?? []).length}　未决之事 ${threads.length}　心声进度 ${j.quickOptionPoolIndex}`,
);

line('1. 存档洁净度');
const seen = new Map();
msgs.forEach((m, i) => {
  const k = `${m.role}\u0000${m.content}`;
  if (!seen.has(k)) seen.set(k, []);
  seen.get(k).push(i);
});
const dups = [...seen.entries()].filter(([, idx]) => idx.length > 1);
console.log(
  `完全重复的消息：${dups.length} 组 / 涉及 ${dups.reduce((a, [, i]) => a + i.length, 0)} 条`,
);
for (const [, idx] of dups.slice(0, 8)) {
  const m = msgs[idx[0]];
  console.log(`  x${idx.length} [${m.role}] ${m.content.replace(/\s+/g, ' ').slice(0, 46)}`);
}
if (dups.length > 8) console.log(`  …另有 ${dups.length - 8} 组`);
const noise = A.length - real.length;
console.log(
  `环境语 / 系统回执 / 报错混入对话流：${noise} 条　${noise === 0 ? '✅ 干净' : '❌ 应当只存在于 UI'}`,
);
if (version >= 2) {
  const kinds = {};
  for (const m of msgs) kinds[m.kind ?? 'chat'] = (kinds[m.kind ?? 'chat'] ?? 0) + 1;
  console.log(`消息种类分布：${JSON.stringify(kinds)}（v2 只应出现 chat）`);
}

line('2. 回复长度与截断');
console.log(`真实角色回复 ${real.length} 条，长度 ${stat(real.map((m) => m.content.length))}`);
const lens = real.map((m) => m.content.length);
console.log(`超出人设上限 360 字：${pct(lens.filter((l) => l > 360).length, lens.length)}`);
const truncated = real.filter((m) => !/[。！？…”』】」]$/.test(m.content.trim()));
console.log(
  `结尾无标点（疑似被 max_tokens 截断）：${pct(truncated.length, real.length)}　${
    truncated.length === 0 ? '✅' : '❌'
  }`,
);
for (const m of truncated) console.log(`  [${msgs.indexOf(m)}] …${m.content.trim().slice(-42)}`);

line('3. 称呼一致性');
console.log(`用「您」：${pct(real.filter((m) => /您/.test(m.content)).length, real.length)}`);
console.log(`用「你」：${pct(real.filter((m) => /你/.test(m.content)).length, real.length)}`);
const mixed = real.filter((m) => /您/.test(m.content) && /你/.test(m.content));
console.log(`同一条里混用：${mixed.length} 条`);

line('4. 附和度（反谄媚指标）');
const AFFIRM =
  /^(正是如此|确实如此|说得|这句话|你说得|没错|是的|对。|你倒|你知道|因为|我懂|我理解|我猜|你读得|你问得|问得好|这个设定|这个念头|这个安排|这|对)/;
console.log(
  `以附和 / 承接词开头：${pct(real.filter((m) => AFFIRM.test(m.content.trim())).length, real.length)}`,
);
console.log(`以「这句话」开头：${real.filter((m) => /^这句话/.test(m.content.trim())).length}`);
console.log(`含「值得被」：${real.filter((m) => /值得被/.test(m.content)).length}`);
const DISAGREE = /(不过|但是|可是|我倒|我并不|未必|不见得|别急着|我不这么|这不对|我不同意)/;
console.log(
  `含转折 / 保留意见：${pct(real.filter((m) => DISAGREE.test(m.content)).length, real.length)}　（目标 ≥25%）`,
);
console.log(
  `以问号收尾：${pct(real.filter((m) => /[？?]\s*$/.test(m.content.trim())).length, real.length)}`,
);

line('5. 记忆与未决之事');
const mem = j.libraryMemory ?? [];
const byCat = {};
for (const m of mem) byCat[m.category] = (byCat[m.category] ?? 0) + 1;
console.log(`分类分布：${JSON.stringify(byCat)}`);
const bookmarks = mem.filter((m) => m.category === '书签' || m.source === '手动书签');
console.log(`书签占比：${pct(bookmarks.length, mem.length)}　（书签有自己的书架，不算关于来访者的事实）`);
const injected = mem.slice(-12); // 复现 conversation_context.dart 的注入策略
console.log(
  `按当前策略注入的最近 12 条 ≈ ${injected.reduce((a, m) => a + m.content.length + (m.evidence ?? '').length, 0)} 字符`,
);
if (threads.length) {
  const open = threads.filter((t) => (t.status ?? 'open') === 'open');
  console.log(`未决之事：${open.length} 件还悬着 / ${threads.length - open.length} 件已有下文`);
  for (const t of open.slice(0, 6)) console.log(`  · ${t.topic}${t.detail ? `（${t.detail}）` : ''}`);
} else {
  console.log('未决之事：0 件（v1 存档不含此数据，导入后会从新对话里重新积累）');
}

line('6. 来访者输入画像');
const short = U.filter((m) => m.content.trim().length <= 12);
console.log(`≤12 字的短消息：${pct(short.length, U.length)}　（纯赞叹/催促会强化附和回路）`);
console.log('  例：' + short.slice(0, 12).map((m) => m.content.trim()).join(' ｜ '));
const userChars = U.reduce((a, m) => a + m.content.length, 0);
const asstChars = A.reduce((a, m) => a + m.content.length, 0);
console.log(
  `来访者输入 ${userChars} 字符 vs 艾蕾塔输出 ${asstChars} 字符　（比值 1 : ${(asstChars / (userChars || 1)).toFixed(1)}）`,
);

if (full) {
  line('7. 对话全文（来访者完整 / 艾蕾塔截断 260 字）');
  msgs.forEach((m, i) => {
    const c = (m.content ?? '').replace(/\r/g, '');
    if (m.role === 'user') console.log(`\n[${i}] 来访者：${c}`);
    else {
      const flat = c.replace(/\n+/g, ' / ');
      console.log(`[${i}] 艾蕾塔：${flat.length > 260 ? `${flat.slice(0, 260)} …(+${flat.length - 260})` : flat}`);
    }
  });
}

console.log('\n（加 --full 可输出对话全文摘要）');
