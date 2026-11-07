const String kDefaultApiUrl = 'https://api.deepseek.com/chat/completions';
// 2026-11-04 按官方文档改名：deepseek-v4-flash → deepseek-flash。
const String kDefaultModel = 'deepseek-flash';
const String kSettingsKey = 'beyondTimeFlutterSettings';
const String kHistoryKey = 'beyondTimeFlutterHistory';
const String kQuickCountKey = 'beyondTimeFlutterQuickChoiceCount';
const String kLibraryMemoryKey = 'beyondTimeFlutterLibraryMemory';
const String kOpenThreadsKey = 'beyondTimeFlutterOpenThreads';
const String kCreationsKey = 'beyondTimeCreations';
const String kLastVisitKey = 'beyondTimeLastVisit';
const String kUserProfileKey = 'beyondTimeUserProfile';

/// 网页版"刚更新过"的标记。
///
/// **写入方是 `web/index.html`**（直接用原生 localStorage，不经过 Dart），
/// 读取方是 `StoreHelper.takeJustTidied()`。两边必须用同一个字符串。
const String kJustTidiedKey = 'beyondTimeJustTidied';

/// DeepSeek Search API（网页搜索）。默认由 [kDefaultApiUrl] 推导，见 ApiSettings。
const String kDefaultSearchUrl = 'https://api.deepseek.com/v1/tools/search';

/// 一次注入几条搜索结果。summary 每条 600–800 字，多了会挤掉她的记忆预算。
const int kMaxSearchResults = 3;

/// 联网搜索默认开启（2026-11-04 定的）。
const bool kWebSearchDefault = true;

const String kPersonaAsset = 'assets/prompts/ereta_persona.txt';
const String kFallbackPersona = '角色：艾蕾塔 · 图书馆的魔女';

/// 记忆上限**按类分开**（2026-11-07 修）。
///
/// 以前共用一个 32 的总上限，淘汰规则是"先丢最旧的事实、绝不动书签"——
/// 结果 29 条书签把事实挤到只剩 3 个位置：每来一条新事实就淘汰一条旧事实，
/// 历史记忆被慢慢洗光，来访者看到的永远是"这一次对谈整理出来的东西"。
/// 现在两类各自封顶，谁也挤不掉谁。
const int kMaxKnowledgeMemory = 200;
const int kMaxBookmarks = 200;

/// 记忆整理模型单条记忆的字符上限（人设里写的也是 45，别只改一处）。
const int kMaxMemoryContentLength = 45;

/// 记忆依据原话的字符上限。
const int kMaxMemoryEvidenceLength = 60;

/// 注入上下文时「关于来访者的事实」的上限。
const int kMaxInjectedFacts = 9;

/// 注入上下文时书签的上限。
///
/// 书架给了书签自己的归宿，却让它们继续挤占"关于来访者的事实"的预算：
/// 2026-09-17 的存档里 23 条记忆有 15 条是书签，按"最近 12 条"注入时
/// 大半额度被金句吃掉，她反而越来越不认识来访者。现在两者分栏计量。
const int kMaxInjectedBookmarks = 3;
