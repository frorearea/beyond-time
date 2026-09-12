const String kDefaultApiUrl = 'https://api.deepseek.com/chat/completions';
const String kDefaultModel = 'deepseek-v4-flash';
const String kSettingsKey = 'beyondTimeFlutterSettings';
const String kHistoryKey = 'beyondTimeFlutterHistory';
const String kQuickCountKey = 'beyondTimeFlutterQuickChoiceCount';
const String kLibraryMemoryKey = 'beyondTimeFlutterLibraryMemory';
const String kOpenThreadsKey = 'beyondTimeFlutterOpenThreads';
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
