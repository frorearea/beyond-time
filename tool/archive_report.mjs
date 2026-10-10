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
  `消息 ${msgs.length}（艾蕾塔 ${A.length} / 来访者 ${U.length}）　记忆 ${(j.libraryMemory ?? []).length}　未决之事 ${threads.length}　创作稿 ${(j.creations ?? []).length}　心声进度 ${j.quickOptionPoolIndex}`,
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
  console.log(`消息种类分布：${JSON.stringify(kinds)}（v2 起只应出现 chat）`);
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

// 这一节**只做诊断，不设目标**。
//
// 曾经有一版给"含转折 / 保留意见"定了 ≥25% 的目标，并在 prompt 里要求"每轮至少
// 留一处异议"。结果 2026-10-04 的存档显示：转折率升上去了，但来访者的评价是
// "为了反驳而反驳"——回复开始整齐地走「先肯定 → 不过我得挑一句 → 转折 → 反问」，
// 「不过我得说句不客气的 / 提个醒 / 挑一句 / 泼一点凉水」反复出现。
//
// 教训：**给性格特征设指标，模型就会生产那个特征的形状。** 所以这里量的是
// "机械感"本身（句式是否在重复），而不是"她发表了几次异议"。异议多不多不重要，
// 重要的是每一条都该是她自己的判断。
line('4. 说话方式（诊断用，不设目标）');
const AFFIRM =
  /^(正是如此|确实如此|说得|这句话|你说得|没错|是的|对。|你倒|你知道|因为|我懂|我理解|我猜|你读得|你问得|问得好|这个设定|这个念头|这个安排|这|对)/;
const DISAGREE = /(不过|但是|可是|我倒|我并不|未必|不见得|别急着|我不这么|这不对|我不同意)/;
const endsQuestion = (m) => /[？?]\s*$/.test(m.content.trim());
const startsWithAffirm = (m) => AFFIRM.test(m.content.trim());
const hasTurn = (m) => DISAGREE.test(m.content);
const hasDissent = (m) => hasTurn(m);

console.log(`以附和 / 承接词开头：${pct(real.filter(startsWithAffirm).length, real.length)}`);
console.log(`含转折词：${pct(real.filter(hasTurn).length, real.length)}`);
console.log(`含「值得被」：${real.filter((m) => /值得被/.test(m.content)).length}`);
console.log(
  `以问号收尾：${pct(real.filter(endsQuestion).length, real.length)}`,
);
console.log('  ↑ 以上全部只是诊断读数。不要把它们当目标去调 prompt。');

// 真正的"机械感"：三件套句式（先肯定 → 转折 → 反问）占了多少。
const template = real.filter(
  (m) => startsWithAffirm(m) && hasTurn(m) && endsQuestion(m),
);
console.log(
  `\n「先肯定 → 转折 → 反问」三件套：${pct(template.length, real.length)}　${
    template.length === 0 ? '✅' : '⚠️ 这是最像自动售货机的句式，越低越好'
  }`,
);

// 开头句式重复：把每条回复的第一个小句当"开场模板"，看有没有撞车。
const firstClause = (text) => {
  const head = text.trim().split(/[。！？，、；\n]/)[0] ?? '';
  return head.slice(0, 10);
};
const openingCounts = new Map();
for (const m of real) {
  const key = firstClause(m.content);
  if (key.length < 3) continue;
  openingCounts.set(key, (openingCounts.get(key) ?? 0) + 1);
}
const repeatedOpenings = [...openingCounts.entries()]
  .filter(([, n]) => n >= 3)
  .sort((a, b) => b[1] - a[1]);
console.log(`\n重复的开场句式（≥3 次）：${repeatedOpenings.length} 种`);
for (const [text, n] of repeatedOpenings.slice(0, 8)) {
  console.log(`  x${n} ${text}…`);
}

// 口癖：在 ≥4 条不同回复里出现过的 5 字短语。
const phraseReplies = new Map();
for (const m of real) {
  const flat = m.content.replace(/\s+/g, '');
  const seen = new Set();
  for (let i = 0; i + 5 <= flat.length; i++) {
    const gram = flat.slice(i, i + 5);
    if (seen.has(gram)) continue;
    seen.add(gram);
    phraseReplies.set(gram, (phraseReplies.get(gram) ?? 0) + 1);
  }
}
const memoryText = (j.libraryMemory ?? [])
  .map((m) => `${m.content ?? ''}${m.evidence ?? ''}`)
  .join('')
  .replace(/\s+/g, '');
const tics = [...phraseReplies.entries()]
  .filter(([, n]) => n >= 4)
  .sort((a, b) => b[1] - a[1])
  .slice(0, 12);
console.log(`\n口癖候选（在 ≥4 条回复里出现过的 5 字短语）：${tics.length} 条`);
for (const [phrase, n] of tics) {
  // 区分两种成因：一种是她自己的文风口癖，另一种是同一段记忆被反复取用。
  const echo = memoryText.includes(phrase) ? '　← 记忆回声（同一段记忆被反复取用）' : '';
  console.log(`  x${n} ${phrase}${echo}`);
}
if (tics.length === 0) console.log('  ✅ 没有明显的口头禅');

// 语域漂移：意象变少、句子变碎。
//
// 2026-10-11 的来访者反馈是"用语不如从前优雅、直白简单、比喻没了"。当时**按整份存档
// 比较看不出来**（两份存档大部分是同一段带过来的老历史，把变化抹平了），必须在**同一份
// 存档内部按时间切开**才看得见：意象词 2.53/千字 → 1.74，≤8 字碎句 6.7% → 12.8%，
// 句长中位 25 → 21。
//
// 所以这里同时给两个读数：全档，以及"最早四分之一 vs 最新四分之一"的对比。
// **仍然只是诊断，不设目标**——她是靠身份与气质写出来的，不是靠凑意象密度凑出来的。
const IMAGERY = /(像|仿佛|如同|宛如|犹如)/g;
const measureVoice = (seg) => {
  const chars = seg.reduce((a, m) => a + m.content.length, 0) || 1;
  let sentences = 0;
  let short = 0;
  const lens = [];
  for (const m of seg) {
    for (const para of m.content.split('\n')) {
      for (const raw of para.split(/[。！？…]/)) {
        const s = raw.trim();
        if (s.length < 2) continue;
        sentences += 1;
        lens.push(s.length);
        if (s.length <= 8) short += 1;
      }
    }
  }
  lens.sort((a, b) => a - b);
  return {
    imagery:
      ((seg.map((m) => m.content).join('').match(IMAGERY) ?? []).length / chars) *
      1000,
    shortRatio: sentences ? (short / sentences) * 100 : 0,
    medianSentence: lens.length ? lens[Math.floor(lens.length / 2)] : 0,
  };
};
const quarter = Math.max(1, Math.floor(real.length / 4));
const early = real.slice(0, quarter);
const late = real.slice(-quarter);
const allVoice = measureVoice(real);
const earlyVoice = measureVoice(early);
const lateVoice = measureVoice(late);
console.log('\n语域（诊断读数，不设目标）：');
console.log(
  `  全档　　意象 ${allVoice.imagery.toFixed(2)}/千字　≤8字碎句 ${allVoice.shortRatio.toFixed(1)}%　句长中位 ${allVoice.medianSentence}`,
);
console.log(
  `  最早 1/4　意象 ${earlyVoice.imagery.toFixed(2)}/千字　≤8字碎句 ${earlyVoice.shortRatio.toFixed(1)}%　句长中位 ${earlyVoice.medianSentence}`,
);
console.log(
  `  最新 1/4　意象 ${lateVoice.imagery.toFixed(2)}/千字　≤8字碎句 ${lateVoice.shortRatio.toFixed(1)}%　句长中位 ${lateVoice.medianSentence}`,
);
if (earlyVoice.imagery > 0 && lateVoice.imagery < earlyVoice.imagery * 0.8) {
  console.log('  ⚠️ 意象密度比开头低了 20% 以上：去查人设里是不是有人在削弱她的意象');
}
if (lateVoice.shortRatio > earlyVoice.shortRatio * 1.6) {
  console.log('  ⚠️ 碎句比例比开头高了 60% 以上：她可能正在变得直白');
}
console.log(`\n（异议条数 ${real.filter(hasDissent).length} 条仅作记录；异议该由判断决定，不该由指标决定）`);

line('5. 记忆与未决之事');
const mem = j.libraryMemory ?? [];
const byCat = {};
for (const m of mem) byCat[m.category] = (byCat[m.category] ?? 0) + 1;
console.log(`分类分布：${JSON.stringify(byCat)}`);
const bookmarks = mem.filter((m) => m.category === '书签' || m.source === '手动书签');
console.log(`书签占比：${pct(bookmarks.length, mem.length)}　（书签有自己的书架，不算关于来访者的事实）`);
const injected = mem.slice(-12); // 旧的"最近 12 条"策略，留作对照
const factsInjected = mem
  .filter((m) => m.category !== '书签' && m.source !== '手动书签')
  .slice(-9); // 复现 lib/config.dart 的 kMaxInjectedFacts
const bookmarksInjected = bookmarks.slice(-3); // 复现 kMaxInjectedBookmarks
const quotaInjected = [...factsInjected, ...bookmarksInjected];
console.log(
  `旧策略（最近 12 条，不看书签身份）≈ ${injected.reduce((a, m) => a + m.content.length + (m.evidence ?? '').length, 0)} 字符`,
);
console.log(
  `新策略（事实 ≤9 / 书签 ≤3 的配额上限；实际还会按话题挑，只会更少）≈ ${quotaInjected.reduce((a, m) => a + m.content.length + (m.evidence ?? '').length, 0)} 字符`,
);
console.log(
  `  配额里事实 ${factsInjected.length} 条 vs 书签 ${bookmarksInjected.length} 条　（旧策略可能整份额度被书签吃掉）`,
);
const creations = j.creations ?? [];
if (creations.length) {
  console.log(`创作稿：${creations.length} 份`);
  for (const c of creations.slice(0, 6)) {
    console.log(`  · 「${c.title}」[${c.kind ?? '其他'}] ${(c.content ?? '').slice(0, 40)}`);
  }
} else {
  console.log('创作稿：0 份（v2 及更早的存档不含此数据）');
}
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
