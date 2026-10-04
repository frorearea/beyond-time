// 存档清洗：把旧版本写进对话记录里的环境语 / 系统回执 / 报错剥掉，
// 产出一份可以安全导入当前版本 BeyondTime 的 v3 存档。
//
// 用法：
//   node tool/scrub_archive.mjs <存档.json>
//   node tool/scrub_archive.mjs <存档.json> --out clean.json
//
// 为什么需要它：序列化边界（LibraryArchive.toJsonText / StoreHelper.saveHistory）
// 只写 MessageKind.chat，但**旧版本**没有这层过滤。旧存档里的噪音行在导入时
// 会被 ChatMessage.fromJson 默认成 chat，于是种类过滤也拦不住，只能靠
// LibraryArchive.sanitizeMessages 的精确/前缀匹配逐条清。这个脚本把同一套规则
// 提前跑一遍，顺便告诉你到底清掉了多少。
//
// 规则与 lib/models/library_archive.dart 保持一致：
//   1. 丢掉 kind 不是 chat 的（v2 存档自带 kind）；
//   2. 丢掉已知环境语 / 回执的整行；
//   3. 丢掉以已知前缀开头的行（带动态尾巴的报错，精确匹配对不上）；
//   4. 折叠相邻完全相同的台词。
// 只做精确与前缀匹配，绝不做模糊判断，以免误删她真的说过的话。

import fs from 'node:fs';
import path from 'node:path';

const src = process.argv[2];
if (!src) {
  console.error('用法：node tool/scrub_archive.mjs <存档.json> [--out clean.json]');
  process.exit(1);
}
const outIndex = process.argv.indexOf('--out');
const out =
  outIndex >= 0 && process.argv[outIndex + 1]
    ? process.argv[outIndex + 1]
    : path.join(
        path.dirname(src),
        `${path.basename(src, '.json')}.scrubbed.json`,
      );

// 与 archive_report.mjs 同源的噪音特征：这些都是环境语/回执的固定开头，
// 她不会用它们起头，所以按前缀丢弃是安全的。
const NOISE_PREFIX =
  /^(这个房间|欢迎回来|你好像在想|天花板|蜡烛的火焰|书架上有本书|你还在听|灯芯跳|炉火弱|茶凉了|一天没见|门外的事|你回来了|嗯。去吧|好。我不问|才离开|外面的雨|我刚刚翻了翻|你要是想睡|我以为你不会回来|我还以为|要走一会儿吗|去吧。|回来了？|这么快就回来了)/;
const NOISE_CONTAINS = [
  '还没有填写 API Key',
  '属于图书馆了',
  '已经在书页里了',
];
const ERROR_PREFIX = '连接没有成功';

const isNoise = (m) => {
  if (m.kind && m.kind !== 'chat') return true;
  const t = (m.content ?? '').trim();
  if (!t) return true;
  if (NOISE_PREFIX.test(t)) return true;
  if (NOISE_CONTAINS.some((s) => t.includes(s))) return true;
  if (t.startsWith(ERROR_PREFIX)) return true;
  return false;
};

const raw = JSON.parse(fs.readFileSync(src, 'utf8'));
const messages = Array.isArray(raw.messages) ? raw.messages : [];

const cleaned = [];
let droppedKind = 0;
let droppedNoise = 0;
let droppedDup = 0;
for (const m of messages) {
  if (m.kind && m.kind !== 'chat') {
    droppedKind++;
    continue;
  }
  const role = m.role === 'assistant' ? 'assistant' : 'user';
  const content = (m.content ?? '').toString();
  if (isNoise({ ...m, role })) {
    droppedNoise++;
    continue;
  }
  const previous = cleaned[cleaned.length - 1];
  if (previous && previous.role === role && previous.content.trim() === content.trim()) {
    droppedDup++;
    continue;
  }
  cleaned.push({ role, content });
}

const result = {
  type: 'beyond-time-library-archive',
  version: 3,
  exportedAt: new Date().toISOString(),
  scrubbedFrom: path.basename(src),
  messages: cleaned,
  libraryMemory: raw.libraryMemory ?? [],
  openThreads: raw.openThreads ?? [],
  creations: raw.creations ?? [],
  quickOptionPoolIndex: Number(raw.quickOptionPoolIndex ?? raw.quickChoiceCount ?? 0),
};
// quickChoiceCount 是老字段的兼容别名，导出时与 poolIndex 保持一致。
result.quickChoiceCount = result.quickOptionPoolIndex;

fs.writeFileSync(out, `${JSON.stringify(result, null, 2)}\n`, 'utf8');

const assistants = cleaned.filter((m) => m.role === 'assistant').length;
console.log(`输入：${src}`);
console.log(`  消息 ${messages.length} 条（原格式 v${raw.version ?? 1}）`);
console.log(`  丢弃非 chat 种类：${droppedKind} 条`);
console.log(`  丢弃环境语 / 回执 / 报错：${droppedNoise} 条`);
console.log(`  折叠相邻重复：${droppedDup} 条`);
console.log(`输出：${out}`);
console.log(
  `  消息 ${cleaned.length} 条（艾蕾塔 ${assistants} / 来访者 ${cleaned.length - assistants}）` +
    `　记忆 ${result.libraryMemory.length}　未决之事 ${result.openThreads.length}　创作稿 ${result.creations.length}`,
);
