const String kDefaultApiUrl = 'https://api.deepseek.com/chat/completions';
const String kDefaultModel = 'deepseek-v4-flash';
const String kSettingsKey = 'beyondTimeFlutterSettings';
const String kHistoryKey = 'beyondTimeFlutterHistory';
const String kQuickCountKey = 'beyondTimeFlutterQuickChoiceCount';
const String kLibraryMemoryKey = 'beyondTimeFlutterLibraryMemory';
const String kOpenThreadsKey = 'beyondTimeFlutterOpenThreads';
const String kCreationsKey = 'beyondTimeCreations';
const String kLastVisitKey = 'beyondTimeLastVisit';
const String kUserProfileKey = 'beyondTimeUserProfile';

const String kPersonaAsset = 'assets/prompts/ereta_persona.txt';
const String kFallbackPersona = '角色：艾蕾塔 · 图书馆的魔女';

/// 图书馆记忆总条数上限。
const int kMaxLibraryMemory = 32;

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
