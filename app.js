const DEFAULT_SETTINGS = {
  apiUrl: "https://api.deepseek.com/chat/completions",
  model: "deepseek-v4-flash",
  apiKey: "",
  persona: "",
};

const MAX_HISTORY_MESSAGES = 80;
const MAX_OUTPUT_TOKENS = 520;
const DEFAULT_PERSONA_VERSION = "ereta-dialogue-file-v1";
const DEFAULT_MODEL_VERSION = "deepseek-v4-2026";
const HISTORY_VERSION = "dialogue-only-v1";
const AGENT_STATE_VERSION = "agent-state-v2";

let DEFAULT_PERSONA = "";
const DEFAULT_PERSONA_PATH = "assets/prompts/ereta_persona.txt";

const storageKey = "witchShelterSettings";
const historyKey = "witchShelterHistory";
const musicModeKey = "witchShelterMusicMode";
const quickChoiceCountKey = "witchShelterQuickChoiceCount";

const elements = {
  messages: document.querySelector("#messages"),
  dialogueBox: document.querySelector("#dialogueBox"),
  chatForm: document.querySelector("#chatForm"),
  messageInput: document.querySelector("#messageInput"),
  quickOptions: document.querySelector("#quickOptions"),
  sendButton: document.querySelector("#sendButton"),
  clearButton: document.querySelector("#clearButton"),
  musicButton: document.querySelector("#musicButton"),
  musicModeButton: document.querySelector("#musicModeButton"),
  settingsButton: document.querySelector("#settingsButton"),
  closeSettingsButton: document.querySelector("#closeSettingsButton"),
  settingsDrawer: document.querySelector("#settingsDrawer"),
  settingsForm: document.querySelector("#settingsForm"),
  resetSettingsButton: document.querySelector("#resetSettingsButton"),
  secretPromptButton: document.querySelector("#secretPromptButton"),
  apiKeyInput: document.querySelector("#apiKeyInput"),
  apiUrlInput: document.querySelector("#apiUrlInput"),
  modelInput: document.querySelector("#modelInput"),
  personaInput: document.querySelector("#personaInput"),
};

const quickOptionPools = [
  [
    "我在人生的路上迷了路。",
    "我想做自己的游戏，但我害怕它没有意义。",
    "我好像把学历当成了存在许可证。",
  ],
  [
    "我需要的也许不是答案，而是被看见。",
    "我像一份没人打开的存档。",
    "我想从现实撤离，但我还想回来。",
  ],
  [
    "我想从现实撤离，但我还想回来。",
    "我不知道自己是在努力，还是在服从。",
    "如果我失败了，我还算存在过吗？",
  ],
  [
    "我想写一首不服务任何人的诗。",
    "我想做一个也许永远做不完的游戏。",
    "我不想再把热爱交给排名审判。",
  ],
  [
    "请你稍微坏心眼地骂醒我。",
    "请你温柔一点，但别骗我。",
    "我今天只想被允许没用一会儿。",
  ],
  [
    "世界像一个加载失败的菜单。",
    "我把自己活成了别人的任务列表。",
    "我想知道我的愿望是不是还活着。",
  ],
  [
    "我喜欢你。我有资格这样说吗？",
    "鼓励我一下，别太正经。",
    "骂醒我，求你了。",
  ],
  [
    "你喜欢什么游戏？",
    "你喜欢什么动画？",
    "你喜欢什么书？",
  ],
  [
    "效率是不是偷走了我的人生？",
    "我该怎么找回真正的自己？",
    "规训到底是怎么住进我心里的？",
  ],
  [
    "我喜欢你的头发。",
    "我喜欢你的温柔。",
    "我喜欢你的文字。",
  ],
  [
    "你会收藏实体书吗？",
    "你会收藏游戏卡带吗？",
    "你会收藏动画碟片吗？",
  ],
  [
    "我害怕自己只是很普通。",
    "我害怕热爱也会被我搞砸。",
    "我害怕没有人真的需要我。",
  ],
  [
    "如果我不再追赶别人，会发生什么？",
    "如果我慢一点，会被世界抛下吗？",
    "如果我只是喜欢，够不够？",
  ],
  [
    "亲爱的魔女，你会感到虚无吗？",
    "你为什么愿意听我说话？",
    "你也有放不下的故事吗？",
  ],
  [
    "我想写一个没有胜负的游戏。",
    "我想写一个允许失败的故事。",
    "我想写一个能让人回来休息的地方。",
  ],
  [
    "请给我一句小小的咒语。",
    "请给我一个今天能做的小任务。",
    "请给我一点重新开始的勇气。",
  ],
  [
    "我不想再把人生交给比较。",
    "我不想再用成绩证明自己。",
    "我不想再向别人的目光投降。",
  ],
  [
    "你会怎样评价我现在的迷茫？",
    "你会怎样看待我的逃避？",
    "你会怎样拆穿我的自欺欺人？",
  ],
  [
    "我们聊聊一个不存在的游戏吧。",
    "我们聊聊一个没有观众的舞台吧。",
    "我们聊聊一个只属于我的房间吧。",
  ],
  [
    "给我讲一个很短的故事。",
    "给我讲一个不说教的寓言。",
    "给我写一首只属于今晚的诗。",
  ],
  [
    "意义这种东西，是人自己点燃的吗？",
    "你能确认我的存在吗？",
    "我该怎样把自我从评价里赎回来？",
  ],
  [
    "游戏为什么能承载人的灵魂？",
    "故事能不能替我保存热爱？",
    "热爱变冷的时候，该怎么办？",
  ],
  [
    "从未被爱的人要如何学会爱？",
    "希望会不会只是漂亮的谎言？",
    "未来如果没有保证，我还要走吗？",
  ],
  [
    "我是不是把人生过成了一场考试？",
    "我是不是太习惯向世界交作业了？",
    "如果没人评分，我还知道怎么活吗？",
  ],
  [
    "我想逃离效率，但我又害怕停下来。",
    "我不想再把时间换成认可。",
    "我想把今天还给我自己。",
  ],
  [
    "我总觉得自己还不够好。",
    "我总觉得必须再证明一次。",
    "我什么时候才能被允许只是存在？",
  ],
  [
    "我想做点没用但美的东西。",
    "我想认真保护一个幼稚的愿望。",
    "我想把热爱从羞耻里救出来。",
  ],
  [
    "你今天读了什么书？",
    "你今天喝的是红茶还是咖啡？",
    "你今天有没有偷偷偷懒？",
  ],
  [
    "陪我聊聊你喜欢的反派吧。",
    "陪我聊聊你最喜欢的结局吧。",
    "陪我聊聊你舍不得删的存档吧。",
  ],
  [
    "你会给游戏角色起奇怪的名字吗？",
    "你会因为一首配乐记住一个作品吗？",
    "你会反复重看某一集动画吗？",
  ],
  [
    "如果今晚不谈人生，我们谈什么？",
    "如果今晚只浪费时间，你会陪我吗？",
    "如果今晚只听音乐，也可以吗？",
  ],
  [
    "我是不是有点太依赖你了？",
    "你会讨厌我总来找你吗？",
    "如果我今晚不想走呢？",
  ],
  [
    "你刚才那句话，是只对我说的吗？",
    "你是不是故意让我心动？",
    "你明明很温柔，为什么还要装坏？",
  ],
  [
    "我想离你近一点。",
    "我想被你稍微偏爱一点。",
    "我想成为你会记住的来访者。",
  ],
  [
    "如果我说想你，会不会太冒犯？",
    "如果我说需要你，你会笑我吗？",
    "如果我说不想只做来访者呢？",
  ],
  [
    "我们来发明一个没有结局的故事吧。",
    "我们来写一个失败者也能回家的故事吧。",
    "我们来做一个只奖励真心的游戏吧。",
  ],
  [
    "我想做一个能拥抱玩家的游戏。",
    "我想做一个不催促玩家的游戏。",
    "我想做一个让人慢慢呼吸的游戏。",
  ],
  [
    "为什么人一定要攀比？",
    "为什么我总生活在他人的目光中？",
    "我不想将他人踩在脚下，难道这也算软弱吗？",
  ],
];

const witchAffinityPoolIndexes = new Set([
  1, 4, 6, 7, 9, 10, 13, 15, 19, 20, 21, 22,
  27, 28, 29, 30, 31, 32, 35, 36,
]);
const witchAffinityPools = quickOptionPools
  .map((pool, index) => ({ pool, index }))
  .filter((entry) => witchAffinityPoolIndexes.has(entry.index));

clearLocalStateFromUrl();

let settings = null;
let chatHistory = [];
let isSending = false;
let music = null;
let musicMode = loadMusicMode();
let quickChoiceCount = loadQuickChoiceCount();

boot();

async function boot() {
  await loadDefaultPersona();
  settings = loadSettings();
  chatHistory = loadHistory();
  init();
}

async function loadDefaultPersona() {
  try {
    const response = await fetch(DEFAULT_PERSONA_PATH, { cache: "no-store" });
    if (!response.ok) throw new Error(`Failed to load ${DEFAULT_PERSONA_PATH}`);
    const text = (await response.text()).trim();
    DEFAULT_PERSONA = text || "角色：爱蕾塔 · 图书馆的魔女";
  } catch (error) {
    console.warn(error);
    DEFAULT_PERSONA = "角色：爱蕾塔 · 图书馆的魔女";
  }
}

function init() {
  syncSettingsForm();
  syncMusicControls();
  renderHistory();
  renderQuickOptions();

  elements.chatForm.addEventListener("submit", handleSend);
  elements.quickOptions.addEventListener("click", handleQuickOption);
  elements.clearButton.addEventListener("click", clearChat);
  elements.musicButton.addEventListener("click", toggleMusic);
  elements.musicModeButton.addEventListener("click", toggleMusicMode);
  elements.settingsButton.addEventListener("click", openSettings);
  elements.closeSettingsButton.addEventListener("click", closeSettings);
  elements.settingsDrawer.addEventListener("click", handleDrawerClick);
  elements.settingsForm.addEventListener("submit", saveSettings);
  elements.resetSettingsButton.addEventListener("click", resetSettings);
  elements.secretPromptButton.addEventListener("click", warnPromptSecret);
  elements.messageInput.addEventListener("keydown", handleComposerKeys);
}

function loadSettings() {
  const saved = localStorage.getItem(storageKey);
  if (!saved) {
    return {
      ...DEFAULT_SETTINGS,
      persona: DEFAULT_PERSONA,
      personaVersion: DEFAULT_PERSONA_VERSION,
      modelVersion: DEFAULT_MODEL_VERSION,
    };
  }

  try {
    const parsed = { ...DEFAULT_SETTINGS, ...JSON.parse(saved) };
    if (parsed.personaVersion !== DEFAULT_PERSONA_VERSION) {
      return {
        ...parsed,
        model: parsed.model === "deepseek-chat" ? DEFAULT_SETTINGS.model : parsed.model,
        persona: DEFAULT_PERSONA,
        personaVersion: DEFAULT_PERSONA_VERSION,
        modelVersion: DEFAULT_MODEL_VERSION,
      };
    }
    if (!parsed.modelVersion && parsed.model === "deepseek-chat") {
      return {
        ...parsed,
        model: DEFAULT_SETTINGS.model,
        modelVersion: DEFAULT_MODEL_VERSION,
      };
    }
    return parsed.persona.trim() ? parsed : { ...parsed, persona: DEFAULT_PERSONA };
  } catch {
    return {
      ...DEFAULT_SETTINGS,
      persona: DEFAULT_PERSONA,
      personaVersion: DEFAULT_PERSONA_VERSION,
      modelVersion: DEFAULT_MODEL_VERSION,
    };
  }
}

function clearLocalStateFromUrl() {
  const params = new URLSearchParams(window.location.search);
  if (!params.has("reset")) return;

  localStorage.removeItem(storageKey);
  localStorage.removeItem(historyKey);
  localStorage.removeItem(`${historyKey}:version`);
  localStorage.removeItem(musicModeKey);
  localStorage.removeItem(quickChoiceCountKey);
  sessionStorage.clear();

  params.delete("reset");
  params.set("fresh", "clean-start");
  const cleanUrl = `${window.location.pathname}?${params.toString()}`;
  window.history.replaceState(null, "", cleanUrl);
}

function saveSettingsToStorage() {
  localStorage.setItem(storageKey, JSON.stringify(settings));
}

function loadHistory() {
  if (localStorage.getItem(`${historyKey}:version`) !== HISTORY_VERSION) {
    localStorage.removeItem(historyKey);
    localStorage.setItem(`${historyKey}:version`, HISTORY_VERSION);
    return [];
  }

  const saved = localStorage.getItem(historyKey);
  if (!saved) return [];

  try {
    const parsed = JSON.parse(saved);
    return Array.isArray(parsed) ? parsed : [];
  } catch {
    return [];
  }
}

function loadMusicMode() {
  return localStorage.getItem(musicModeKey) === "16bit" ? "16bit" : "8bit";
}

function loadQuickChoiceCount() {
  const count = Number(localStorage.getItem(quickChoiceCountKey));
  return Number.isFinite(count) && count > 0 ? count : 0;
}

function saveHistory() {
  localStorage.setItem(historyKey, JSON.stringify(chatHistory.slice(-MAX_HISTORY_MESSAGES)));
  localStorage.setItem(`${historyKey}:version`, HISTORY_VERSION);
}

function syncMusicControls() {
  elements.musicModeButton.textContent = musicMode;
  elements.musicButton.textContent = music?.playing ? "静音" : "音乐";
  elements.musicButton.setAttribute("aria-pressed", music?.playing ? "true" : "false");
}

function syncSettingsForm() {
  elements.apiKeyInput.value = settings.apiKey;
  elements.apiUrlInput.value = settings.apiUrl;
  elements.modelInput.value = settings.model;
  elements.personaInput.value = settings.persona;
}

function renderHistory() {
  if (!chatHistory.length) return;
  elements.messages.innerHTML = "";
  chatHistory.forEach((entry) => {
    addMessage(entry.role === "user" ? "player" : "witch", entry.content, { save: false });
  });
}

async function handleSend(event) {
  event.preventDefault();
  if (isSending) return;

  const text = elements.messageInput.value.trim();
  if (!text) return;

  addMessage("player", text);
  elements.messageInput.value = "";
  renderQuickOptions();

  if (!settings.apiKey.trim()) {
    addMessage("error", "还没有填写 API Key。打开右上角设置，把 DeepSeek 或兼容接口的密钥放进去。");
    openSettings();
    return;
  }

  await requestWitchReply();
}

function renderQuickOptions() {
  const pool = chooseQuickOptionPool();
  elements.quickOptions.innerHTML = "";

  pool.forEach((text) => {
    const button = document.createElement("button");
    button.className = "choice-button";
    button.type = "button";
    button.textContent = text;
    button.dataset.choice = text;
    elements.quickOptions.append(button);
  });
}

function handleQuickOption(event) {
  const button = event.target.closest(".choice-button");
  if (!button || isSending) return;

  quickChoiceCount += 1;
  localStorage.setItem(quickChoiceCountKey, String(quickChoiceCount));
  elements.messageInput.value = button.dataset.choice;
  elements.chatForm.requestSubmit();
}

function chooseQuickOptionPool() {
  const affinityChance = Math.min(0.12 + quickChoiceCount * 0.055, 0.72);
  const shouldUseAffinityPool = quickChoiceCount > 0 && Math.random() < affinityChance;

  if (shouldUseAffinityPool) {
    const affinityIndex = (chatHistory.length + quickChoiceCount) % witchAffinityPools.length;
    return witchAffinityPools[affinityIndex].pool;
  }

  return quickOptionPools[(chatHistory.length + quickChoiceCount) % quickOptionPools.length];
}

async function createAgentState() {
  const fallback = createRuleAgentState();
  if (!settings.apiKey.trim()) return fallback;

  try {
    const requestConfig = getAgentStateRequestConfig(fallback);
    const response = await fetch(requestConfig.url, {
      method: "POST",
      headers: requestConfig.headers,
      body: JSON.stringify(requestConfig.body),
    });

    if (!response.ok) {
      throw new Error(await response.text());
    }

    const data = await response.json();
    const content = data?.choices?.[0]?.message?.content || "";
    const parsed = parseAgentStateJson(content);
    return normalizeAgentState(parsed, fallback);
  } catch (error) {
    console.warn("AgentState fallback:", error);
    return fallback;
  }
}

function createRuleAgentState() {
  const userMessages = chatHistory.filter((entry) => entry.role === "user");
  const latestUserMessage = userMessages[userMessages.length - 1]?.content || "";
  const recentUserText = userMessages
    .slice(-6)
    .map((entry) => entry.content)
    .join("\n");
  const topics = detectTopics(recentUserText);
  const mood = detectMood(latestUserMessage, recentUserText);
  const intent = detectIntent(latestUserMessage, topics);
  const energy = detectEnergy(latestUserMessage, mood);
  const relationship = quickChoiceCount >= 14 ? "close" : quickChoiceCount >= 6 ? "warming" : "distant";
  const conversationMode = detectConversationMode({ mood, intent, topics, latestUserMessage });
  const strategy = chooseDialogueStrategy({ mood, intent, topics, energy, latestUserMessage, conversationMode });

  return {
    version: AGENT_STATE_VERSION,
    source: "rules",
    conversationMode,
    mood,
    intent,
    needLevel: conversationMode === "support_request" ? "clear" : conversationMode === "casual_chat" ? "none" : "light",
    energy,
    topics,
    relationship,
    strategy,
    replyHint: chooseReplyHint({ conversationMode, strategy }),
    replyStyle: chooseReplyStyle({ energy, strategy, relationship, conversationMode }),
    ritualSuggestion: chooseRitualSuggestion({ intent, topics, latestUserMessage }),
    memoryCandidates: collectMemoryCandidates(userMessages),
  };
}

function getAgentStateRequestConfig(fallback) {
  const body = {
    model: settings.model,
    messages: buildAgentStateMessages(fallback),
    temperature: 0.1,
    max_tokens: 220,
    stream: false,
    thinking: { type: "disabled" },
  };

  if (window.location.protocol === "file:") {
    return {
      url: settings.apiUrl,
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${settings.apiKey}`,
      },
      body,
    };
  }

  return {
    url: "/api/chat",
    headers: {
      "Content-Type": "application/json",
    },
    body: {
      ...body,
      apiKey: settings.apiKey,
      apiUrl: settings.apiUrl,
    },
  };
}

function buildAgentStateMessages(fallback) {
  return [
    {
      role: "system",
      content:
        "你是 Character Agent 的隐藏状态分析器。只输出一行 JSON，不要 Markdown，不要解释。目标是判断用户是在闲聊/讨论喜好，还是有明确情绪诉求。输出必须简短。",
    },
    {
      role: "user",
      content: JSON.stringify({
        schema: {
          conversationMode:
            "casual_chat | preference_chat | support_request | creative_request | intimacy | ritual_request | risk",
          mood: "curious | playful | tired | anxious | intimate | creative | philosophical | crisis | uncertain",
          intent:
            "chat | know_witch | seek_comfort | seek_existence | deconstruct_pressure | explore_creation | seek_closeness | request_ritual",
          needLevel: "none | light | clear | urgent",
          strategy:
            "small_devil_chat | share_self | comfort | pierce_gently | creative_guide | tease_and_soften | ritual | ground_and_protect | listen_and_invite",
          topics: ["short topic tags"],
          replyHint: "24字以内，告诉魔女这轮怎么说",
          ritualSuggestion: "none | poem | story | task_card | spell | idea_card | bookmark",
          memoryCandidates: ["最多2条值得记住的用户信息"],
        },
        rules: [
          "如果用户在问爱蕾塔喜欢什么、聊动画游戏书籍音乐、分享喜好，优先 casual_chat 或 preference_chat。",
          "闲聊和喜好讨论不要判成 support_request，除非用户明显痛苦求助。",
          "闲聊/喜好时 strategy 优先 small_devil_chat 或 share_self，让爱蕾塔更挑剔、腹黑、可爱。",
          "用户说喜欢你、想你、需要你时用 intimacy。",
          "用户问意义、存在、自我、比较、规训时通常是 support_request 或 philosophical。",
        ],
        relationship: fallback.relationship,
        quickChoiceCount,
        recentConversation: compactConversationForAgent(),
        fallback,
      }),
    },
  ];
}

function compactConversationForAgent() {
  return chatHistory.slice(-8).map((entry) => ({
    role: entry.role,
    content: trimToCompleteSentence(entry.content, 160),
  }));
}

function parseAgentStateJson(content) {
  const cleanContent = content
    .replace(/```json/gi, "")
    .replace(/```/g, "")
    .trim();
  const start = cleanContent.indexOf("{");
  const end = cleanContent.lastIndexOf("}");
  if (start === -1 || end === -1 || end <= start) {
    throw new Error("AgentState JSON not found");
  }

  return JSON.parse(cleanContent.slice(start, end + 1));
}

function normalizeAgentState(parsed, fallback) {
  const conversationModes = new Set([
    "casual_chat",
    "preference_chat",
    "support_request",
    "creative_request",
    "intimacy",
    "ritual_request",
    "risk",
  ]);
  const strategies = new Set([
    "small_devil_chat",
    "share_self",
    "comfort",
    "pierce_gently",
    "creative_guide",
    "tease_and_soften",
    "ritual",
    "ground_and_protect",
    "listen_and_invite",
  ]);
  const mode = conversationModes.has(parsed.conversationMode) ? parsed.conversationMode : fallback.conversationMode;
  const strategy = strategies.has(parsed.strategy) ? parsed.strategy : fallback.strategy;

  return {
    ...fallback,
    ...parsed,
    version: AGENT_STATE_VERSION,
    source: "llm",
    conversationMode: mode,
    strategy,
    topics: normalizeStringArray(parsed.topics, fallback.topics).slice(0, 5),
    replyHint: typeof parsed.replyHint === "string" ? parsed.replyHint.slice(0, 48) : fallback.replyHint,
    ritualSuggestion: parsed.ritualSuggestion || fallback.ritualSuggestion,
    memoryCandidates: normalizeStringArray(parsed.memoryCandidates, fallback.memoryCandidates).slice(0, 2),
    replyStyle: chooseReplyStyle({
      energy: parsed.energy || fallback.energy,
      strategy,
      relationship: fallback.relationship,
      conversationMode: mode,
    }),
  };
}

function normalizeStringArray(value, fallback) {
  if (!Array.isArray(value)) return fallback;
  return value.filter((item) => typeof item === "string" && item.trim()).map((item) => item.trim());
}

function detectTopics(text) {
  const topicMatchers = [
    ["creation", ["游戏", "创作", "作品", "诗", "故事", "表达", "灵感"]],
    ["comparison", ["比较", "攀比", "评分", "排名", "成绩", "优秀", "证明", "目光"]],
    ["discipline", ["规训", "效率", "KPI", "任务", "生产力", "服从", "学历", "考试"]],
    ["self", ["存在", "自我", "意义", "价值", "普通", "需要我", "认可"]],
    ["intimacy", ["喜欢你", "想你", "需要你", "偏爱", "靠近", "不想走", "心动"]],
    ["witch", ["魔女", "你喜欢", "你的头发", "你的温柔", "你的文字", "你会"]],
    ["casual", ["动画", "书", "咖啡", "红茶", "音乐", "反派", "结局", "存档"]],
  ];

  return topicMatchers
    .filter(([, words]) => includesAny(text, words))
    .map(([topic]) => topic);
}

function detectMood(latestText, recentText) {
  if (includesAny(latestText, ["想死", "自杀", "伤害自己", "活不下去"])) return "crisis";
  if (includesAny(latestText, ["喜欢你", "心动", "想你", "需要你", "偏爱"])) return "intimate";
  if (includesAny(recentText, ["害怕", "焦虑", "担心", "怕", "没有勇气"])) return "anxious";
  if (includesAny(recentText, ["累", "疲惫", "没力气", "走不动", "喘不过气"])) return "tired";
  if (includesAny(recentText, ["虚无", "意义", "存在", "未来", "希望"])) return "philosophical";
  if (includesAny(recentText, ["游戏", "创作", "诗", "故事", "表达"])) return "creative";
  if (includesAny(recentText, ["聊聊", "喜欢什么", "动画", "书", "咖啡", "红茶"])) return "curious";
  return "uncertain";
}

function detectIntent(latestText, topics) {
  if (includesAny(latestText, ["讲一个", "寓言", "诗", "咒语", "任务"])) return "request_ritual";
  if (topics.includes("intimacy")) return "seek_closeness";
  if (topics.includes("witch") || topics.includes("casual")) return "know_witch";
  if (topics.includes("creation")) return "explore_creation";
  if (topics.includes("comparison") || topics.includes("discipline")) return "deconstruct_pressure";
  if (topics.includes("self")) return "seek_existence";
  if (includesAny(latestText, ["帮帮我", "怎么办", "鼓励", "骂醒"])) return "ask_for_guidance";
  return "continue_dialogue";
}

function detectConversationMode({ mood, intent, topics, latestUserMessage }) {
  if (mood === "crisis") return "risk";
  if (intent === "request_ritual") return "ritual_request";
  if (intent === "seek_closeness") return "intimacy";
  if (intent === "explore_creation") return "creative_request";
  if (intent === "know_witch" && topics.includes("casual")) return "preference_chat";
  if (intent === "know_witch" || includesAny(latestUserMessage, ["聊聊", "喜欢什么", "今天读了", "动画", "游戏", "书"])) {
    return "casual_chat";
  }
  if (["ask_for_guidance", "deconstruct_pressure", "seek_existence"].includes(intent)) return "support_request";
  return "casual_chat";
}

function detectEnergy(latestText, mood) {
  if (mood === "crisis" || mood === "tired") return "low";
  if (includesAny(latestText, ["啊啊", "！！！", "好想", "必须", "受不了"])) return "high";
  if (mood === "anxious") return "shaky";
  return "medium";
}

function chooseDialogueStrategy({ mood, intent, topics, energy, latestUserMessage, conversationMode }) {
  if (mood === "crisis") return "ground_and_protect";
  if (conversationMode === "casual_chat" || conversationMode === "preference_chat") return "small_devil_chat";
  if (intent === "request_ritual") return "ritual";
  if (intent === "seek_closeness") return "tease_and_soften";
  if (intent === "know_witch") return "share_self";
  if (intent === "explore_creation") return "creative_guide";
  if (topics.includes("comparison") || topics.includes("discipline")) return "pierce_gently";
  if (intent === "seek_existence") return "recognize_and_question";
  if (energy === "low") return "comfort";
  if (includesAny(latestUserMessage, ["逃避", "骗我", "骂醒"])) return "gentle_provocation";
  return "listen_and_invite";
}

function chooseReplyStyle({ energy, strategy, relationship, conversationMode }) {
  return {
    length: energy === "low" || strategy === "tease_and_soften" || strategy === "small_devil_chat" ? "short" : "compact",
    tone:
      strategy === "pierce_gently"
        ? "sharp_but_warm"
        : strategy === "tease_and_soften"
          ? "playful_intimate"
          : strategy === "small_devil_chat" || conversationMode === "preference_chat"
            ? "small_devil_playful"
            : "calm",
    witchEmotion: relationship === "close" ? "more_visible" : "subtle",
  };
}

function chooseReplyHint({ conversationMode, strategy }) {
  if (strategy === "small_devil_chat" || conversationMode === "preference_chat") {
    return "别心理分析，挑剔又愉快地闲聊。";
  }
  if (strategy === "tease_and_soften") return "小小得意，暧昧但别露骨。";
  if (strategy === "pierce_gently") return "戳破比较和规训，落点温柔。";
  if (strategy === "creative_guide") return "把话题引向具体创作火种。";
  return "短、准、像真实对话。";
}

function chooseRitualSuggestion({ intent, topics, latestUserMessage }) {
  if (intent === "request_ritual") {
    if (includesAny(latestUserMessage, ["诗"])) return "poem";
    if (includesAny(latestUserMessage, ["寓言", "故事"])) return "story";
    if (includesAny(latestUserMessage, ["任务"])) return "task_card";
    return "spell";
  }

  if (topics.includes("creation")) return "idea_card";
  if (topics.includes("self") || topics.includes("comparison")) return "bookmark";
  return "none";
}

function collectMemoryCandidates(userMessages) {
  return userMessages
    .slice(-8)
    .map((entry) => entry.content)
    .filter((text) => includesAny(text, ["我喜欢", "我想", "我害怕", "我不想", "我需要", "游戏", "创作", "学历", "比较", "规训"]))
    .slice(-3);
}

function includesAny(text, words) {
  return words.some((word) => text.includes(word));
}

async function requestWitchReply() {
  setSending(true);
  const replyNode = addStreamingMessage();
  const writer = createTypewriter(replyNode.paragraph);
  const streamFilter = createDialogueStreamFilter();

  try {
    const agentState = await createAgentState();
    const requestConfig = getChatRequestConfig(agentState);
    const response = await fetch(requestConfig.url, {
      method: "POST",
      headers: requestConfig.headers,
      body: JSON.stringify(requestConfig.body),
    });

    if (!response.ok) {
      const errorText = await response.text();
      throw new Error(readErrorMessage(errorText, response.statusText));
    }

    const reply = await readStreamingReply(response, (chunk) => writer.enqueue(streamFilter.push(chunk)));
    await writer.done();

    const finalReply = toDialogueOnly(writer.text || reply);
    if (!finalReply) {
      throw new Error("模型没有返回可显示的内容。");
    }

    writer.set(finalReply);
    chatHistory.push({ role: "assistant", content: finalReply });
    saveHistory();
  } catch (error) {
    replyNode.article.remove();
    addMessage("error", `连接没有成功：${error.message}`);
  } finally {
    setSending(false);
  }
}

function createDialogueStreamFilter() {
  let insideParen = false;
  let atStart = true;

  return {
    push(chunk) {
      let output = "";

      for (const char of chunk) {
        if (atStart && /\s/.test(char)) continue;

        if (atStart && (char === "（" || char === "(")) {
          insideParen = true;
          atStart = false;
          continue;
        }

        if (insideParen) {
          if (char === "）" || char === ")") insideParen = false;
          continue;
        }

        if (char === "（" || char === "(") {
          insideParen = true;
          atStart = false;
          continue;
        }

        if (char === "“" || char === "”" || char === "\"") {
          atStart = false;
          continue;
        }

        output += char;
        atStart = false;
      }

      return output;
    },
  };
}

function createTypewriter(target) {
  let queue = "";
  let text = "";
  let timer = null;
  let resolveIdle = null;

  const tick = () => {
    if (!queue) {
      timer = null;
      if (resolveIdle) {
        resolveIdle();
        resolveIdle = null;
      }
      return;
    }

    const take = queue.length > 80 ? 4 : 1;
    text += queue.slice(0, take);
    queue = queue.slice(take);
    target.textContent = formatWitchDisplayText(text);
    elements.messages.scrollTop = elements.messages.scrollHeight;
    timer = setTimeout(tick, 18);
  };

  return {
    get text() {
      return text;
    },
    enqueue(chunk) {
      if (!chunk) return;
      queue += chunk;
      if (!timer) tick();
    },
    set(value) {
      queue = "";
      text = value;
      target.textContent = formatWitchDisplayText(value);
      elements.messages.scrollTop = elements.messages.scrollHeight;
    },
    done() {
      if (!queue && !timer) return Promise.resolve();
      return new Promise((resolve) => {
        resolveIdle = resolve;
      });
    },
  };
}

function getChatRequestConfig(agentState) {
  const messages = buildMessages(agentState);
  const body = {
    model: settings.model,
    messages,
    temperature: 1.35,
    max_tokens: MAX_OUTPUT_TOKENS,
    stream: true,
    stream_options: { include_usage: false },
    thinking: { type: "enabled" },
  };

  if (window.location.protocol === "file:") {
    return {
      url: settings.apiUrl,
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${settings.apiKey}`,
      },
      body,
    };
  }

  return {
    url: "/api/chat",
    headers: {
      "Content-Type": "application/json",
    },
    body: {
      ...body,
      apiKey: settings.apiKey,
      apiUrl: settings.apiUrl,
    },
  };
}

function buildMessages(agentState) {
  const systemPrompt = settings.persona.trim() || DEFAULT_PERSONA;
  const recentHistory = chatHistory
    .slice(-MAX_HISTORY_MESSAGES)
    .map((entry) => ({
      role: entry.role,
      content: entry.role === "assistant" ? toDialogueOnly(entry.content) : entry.content,
    }));

  return [
    { role: "system", content: systemPrompt },
    {
      role: "system",
      content:
        "硬性输出格式：只输出爱蕾塔直接对用户说的话。禁止括号。禁止舞台说明。禁止第三人称叙述。禁止环境描写。不要写“她”。不要给对白加引号。总长度不超过180个中文字。若启用思考模式，最终回复尽量压缩到100个中文字以内，只保留最有力的判断、安慰和一个继续对话的入口。",
    },
    {
      role: "system",
      content: buildAgentStateInstruction(agentState),
    },
    ...recentHistory,
    {
      role: "system",
      content:
        "最后提醒：下一条回复必须是纯对话文本。第一个字符不得是“（”或“她”。不得出现水晶、星空穹顶、房间、脚步、转身、手势等场景描写。直接回答用户。thinking开启时尽量不超过100个中文字。宁可短，也不要把思考过程说出来。",
    },
  ];
}

function buildAgentStateInstruction(agentState) {
  return `隐藏 AgentState，仅供爱蕾塔决定这轮怎么回应，不要直接说出这些字段，不要输出 JSON。

${JSON.stringify(agentState, null, 2)}

使用方式：
- conversationMode 区分用户只是在闲聊/聊喜好，还是有明确诉求。
- mood 是来访者此刻的情绪底色。
- intent 是来访者这句话真正想要什么。
- strategy 是本轮优先对话策略。
- replyStyle 控制长度、锋利程度、魔女情绪显露程度。
- 如果 conversationMode 是 casual_chat 或 preference_chat，禁止强行心理疏导。优先小恶魔式闲聊、挑剔点评、分享爱蕾塔自己的喜好，允许轻轻取笑用户品味。
- 如果 conversationMode 是 support_request，再进入安慰、追问、拆解规训或创作引导。
- ritualSuggestion 不是命令，只是当自然合适时可生成小仪式，如诗、寓言、任务卡、书签或灵感卡。
- memoryCandidates 是值得之后记住的线索；本轮可以轻轻呼应，但不要像系统总结。`;
}

function toDialogueOnly(text) {
  return trimToCompleteSentence(
    text
    .replace(/（[^）]*）/g, "")
    .replace(/\([^)]*\)/g, "")
    .replace(/[“”]/g, "")
    .trim(),
    360,
  );
}

function trimToCompleteSentence(text, maxLength) {
  if (text.length <= maxLength) return text;

  const sliced = text.slice(0, maxLength);
  const lastPunctuation = Math.max(
    sliced.lastIndexOf("。"),
    sliced.lastIndexOf("！"),
    sliced.lastIndexOf("？"),
    sliced.lastIndexOf("!"),
    sliced.lastIndexOf("?"),
  );

  if (lastPunctuation > maxLength * 0.55) {
    return sliced.slice(0, lastPunctuation + 1).trim();
  }

  return sliced.trim();
}

function formatWitchDisplayText(text) {
  const cleanText = text.trim();
  if (!cleanText || cleanText.includes("\n")) return cleanText;

  const sentences = cleanText.match(/[^。！？!?]+[。！？!?]?/g) || [cleanText];
  const lines = [];
  let line = "";

  sentences.forEach((sentence) => {
    const part = sentence.trim();
    if (!part) return;

    const shouldBreak =
      line &&
      (line.length + part.length > 42 || /[？?]$/.test(line) || /^不过|^可是|^那么|^亲爱的/.test(part));

    if (shouldBreak) {
      lines.push(line);
      line = part;
      return;
    }

    line += part;
  });

  if (line) lines.push(line);
  return lines.join("\n");
}

async function readStreamingReply(response, onDelta) {
  const contentType = response.headers.get("content-type") || "";
  if (!contentType.includes("text/event-stream")) {
    const data = await response.json();
    const reply = data?.choices?.[0]?.message?.content || "";
    onDelta(reply);
    return reply;
  }

  const reader = response.body.getReader();
  const decoder = new TextDecoder("utf-8");
  let buffer = "";
  let fullText = "";

  while (true) {
    const { value, done } = await reader.read();
    if (done) break;

    buffer += decoder.decode(value, { stream: true }).replace(/\r\n/g, "\n");
    const events = buffer.split("\n\n");
    buffer = events.pop() || "";

    for (const event of events) {
      const delta = parseSseDelta(event);
      if (!delta) continue;
      fullText += delta;
      onDelta(delta);
    }
  }

  buffer += decoder.decode();
  const tail = parseSseDelta(buffer.replace(/\r\n/g, "\n"));
  if (tail) {
    fullText += tail;
    onDelta(tail);
  }

  return fullText;
}

function parseSseDelta(event) {
  return event
    .split("\n")
    .filter((line) => line.startsWith("data:"))
    .map((line) => line.slice(5).trim())
    .filter((line) => line && line !== "[DONE]")
    .map((line) => {
      try {
        return JSON.parse(line)?.choices?.[0]?.delta?.content || "";
      } catch {
        return "";
      }
    })
    .join("");
}

function readErrorMessage(errorText, fallback) {
  try {
    const data = JSON.parse(errorText);
    return data?.error?.message || data?.error || fallback || "请求失败";
  } catch {
    return errorText || fallback || "请求失败";
  }
}

function addMessage(type, content, options = {}) {
  const save = options.save !== false;
  const article = document.createElement("article");
  article.className = `message message-${type}`;

  const paragraph = document.createElement("p");
  paragraph.textContent = type === "player" ? `> ${content}` : formatWitchDisplayText(content);

  article.append(paragraph);
  elements.messages.append(article);
  elements.messages.scrollTop = elements.messages.scrollHeight;

  if (save && type !== "error") {
    chatHistory.push({
      role: type === "player" ? "user" : "assistant",
      content,
    });
    saveHistory();
  }

  return article;
}

function addStreamingMessage() {
  const article = document.createElement("article");
  article.className = "message message-witch";

  const paragraph = document.createElement("p");
  paragraph.textContent = "";

  article.append(paragraph);
  elements.messages.append(article);
  elements.messages.scrollTop = elements.messages.scrollHeight;

  return { article, paragraph };
}

function setSending(value) {
  isSending = value;
  elements.dialogueBox?.classList.toggle("is-thinking", value);
  elements.sendButton.disabled = value;
  elements.messageInput.disabled = value;
  elements.quickOptions.querySelectorAll("button").forEach((button) => {
    button.disabled = value;
  });
  elements.sendButton.textContent = value ? "等待" : "发送";
}

function clearChat() {
  chatHistory = [];
  localStorage.removeItem(historyKey);
  elements.messages.innerHTML = "";
  addMessage("witch", "房间重新安静下来了。您可以从任何一个句子重新开始，亲爱的。", { save: false });
}

async function toggleMusic() {
  if (!music) {
    music = createMusic();
  }

  if (music.playing) {
    music.stop();
    syncMusicControls();
    return;
  }

  await music.start();
  syncMusicControls();
}

async function toggleMusicMode() {
  const shouldResume = Boolean(music?.playing);
  if (music) {
    music.stop();
    music = null;
  }

  musicMode = musicMode === "8bit" ? "16bit" : "8bit";
  localStorage.setItem(musicModeKey, musicMode);
  syncMusicControls();

  if (shouldResume) {
    music = createMusic();
    await music.start();
    syncMusicControls();
  }
}

function createMusic() {
  return musicMode === "16bit" ? createSixteenBitMusic() : createEightBitMusic();
}

function createEightBitMusic() {
  const AudioContext = window.AudioContext || window.webkitAudioContext;
  const context = new AudioContext();
  const master = context.createGain();
  const melodyGain = context.createGain();
  const bassGain = context.createGain();
  const noiseGain = context.createGain();
  let interval = null;
  let step = 0;
  let playing = false;

  master.gain.value = 0.12;
  melodyGain.gain.value = 0.42;
  bassGain.gain.value = 0.28;
  noiseGain.gain.value = 0.045;

  melodyGain.connect(master);
  bassGain.connect(master);
  noiseGain.connect(master);
  master.connect(context.destination);

  const bpm = 72;
  const beat = 60 / bpm;
  const melody = [
    659.25, 0, 739.99, 783.99,
    987.77, 0, 783.99, 739.99,
    659.25, 587.33, 523.25, 0,
    587.33, 659.25, 0, 523.25,
  ];
  const bass = [164.81, 164.81, 196.0, 196.0, 220.0, 220.0, 196.0, 196.0];

  return {
    get playing() {
      return playing;
    },
    async start() {
      if (context.state === "suspended") {
        await context.resume();
      }

      playing = true;
      scheduleStep();
      interval = setInterval(scheduleStep, beat * 500);
    },
    stop() {
      playing = false;
      if (interval) {
        clearInterval(interval);
        interval = null;
      }
    },
  };

  function scheduleStep() {
    const now = context.currentTime;
    const note = melody[step % melody.length];
    const root = bass[Math.floor(step / 2) % bass.length];

    if (note) {
      playTone(note, now, beat * 0.42, "square", melodyGain, 0.001, 0.16);
      playTone(note * 2, now + 0.012, beat * 0.18, "triangle", melodyGain, 0.0005, 0.045);
    }

    if (step % 2 === 0) {
      playTone(root, now, beat * 0.82, "triangle", bassGain, 0.001, 0.12);
    }

    if (step % 8 === 0) {
      playNoise(now, beat * 1.6);
    }

    step += 1;
  }

  function playTone(frequency, start, duration, type, destination, attack, volume) {
    const oscillator = context.createOscillator();
    const gain = context.createGain();

    oscillator.type = type;
    oscillator.frequency.setValueAtTime(frequency, start);
    gain.gain.setValueAtTime(0, start);
    gain.gain.linearRampToValueAtTime(volume, start + attack);
    gain.gain.exponentialRampToValueAtTime(0.0001, start + duration);

    oscillator.connect(gain);
    gain.connect(destination);
    oscillator.start(start);
    oscillator.stop(start + duration + 0.02);
  }

  function playNoise(start, duration) {
    const length = Math.floor(context.sampleRate * duration);
    const buffer = context.createBuffer(1, length, context.sampleRate);
    const data = buffer.getChannelData(0);
    const source = context.createBufferSource();
    const filter = context.createBiquadFilter();
    const gain = context.createGain();

    for (let index = 0; index < length; index += 1) {
      data[index] = (Math.random() * 2 - 1) * (1 - index / length);
    }

    filter.type = "lowpass";
    filter.frequency.value = 900;
    gain.gain.setValueAtTime(0.16, start);
    gain.gain.exponentialRampToValueAtTime(0.0001, start + duration);

    source.buffer = buffer;
    source.connect(filter);
    filter.connect(gain);
    gain.connect(noiseGain);
    source.start(start);
    source.stop(start + duration);
  }
}

function createSixteenBitMusic() {
  const AudioContext = window.AudioContext || window.webkitAudioContext;
  const context = new AudioContext();
  const master = context.createGain();
  const melodyGain = context.createGain();
  const padGain = context.createGain();
  const bassGain = context.createGain();
  const filter = context.createBiquadFilter();
  const delay = context.createDelay();
  const feedback = context.createGain();
  let interval = null;
  let step = 0;
  let playing = false;

  master.gain.value = 0.16;
  melodyGain.gain.value = 0.32;
  padGain.gain.value = 0.18;
  bassGain.gain.value = 0.22;
  filter.type = "lowpass";
  filter.frequency.value = 2600;
  delay.delayTime.value = 0.34;
  feedback.gain.value = 0.18;

  melodyGain.connect(filter);
  padGain.connect(filter);
  bassGain.connect(filter);
  filter.connect(master);
  master.connect(context.destination);
  master.connect(delay);
  delay.connect(feedback);
  feedback.connect(delay);
  delay.connect(context.destination);

  const bpm = 56;
  const beat = 60 / bpm;
  const melody = [
    523.25, 0, 493.88, 392.0,
    440.0, 0, 392.0, 329.63,
    349.23, 392.0, 440.0, 0,
    392.0, 0, 329.63, 0,
  ];
  const bass = [130.81, 110.0, 98.0, 87.31];
  const chords = [
    [261.63, 329.63, 392.0],
    [220.0, 261.63, 329.63],
    [196.0, 246.94, 293.66],
    [174.61, 220.0, 261.63],
  ];

  return {
    get playing() {
      return playing;
    },
    async start() {
      if (context.state === "suspended") {
        await context.resume();
      }

      playing = true;
      scheduleStep();
      interval = setInterval(scheduleStep, beat * 500);
    },
    stop() {
      playing = false;
      if (interval) {
        clearInterval(interval);
        interval = null;
      }
    },
  };

  function scheduleStep() {
    const now = context.currentTime;
    const note = melody[step % melody.length];
    const chord = chords[Math.floor(step / 8) % chords.length];
    const root = bass[Math.floor(step / 8) % bass.length];

    if (step % 8 === 0) {
      chord.forEach((frequency, index) => {
        playTone(frequency, now + index * 0.018, beat * 5.4, "triangle", padGain, 0.08, 0.09);
      });
      playTone(root, now, beat * 5.8, "sine", bassGain, 0.05, 0.16);
    }

    if (note) {
      playTone(note, now, beat * 0.86, "triangle", melodyGain, 0.02, 0.13);
      playTone(note * 2, now + 0.01, beat * 0.42, "sine", melodyGain, 0.01, 0.035);
    }

    step += 1;
  }

  function playTone(frequency, start, duration, type, destination, attack, volume) {
    const oscillator = context.createOscillator();
    const gain = context.createGain();

    oscillator.type = type;
    oscillator.frequency.setValueAtTime(frequency, start);
    gain.gain.setValueAtTime(0.0001, start);
    gain.gain.linearRampToValueAtTime(volume, start + attack);
    gain.gain.exponentialRampToValueAtTime(0.0001, start + duration);

    oscillator.connect(gain);
    gain.connect(destination);
    oscillator.start(start);
    oscillator.stop(start + duration + 0.04);
  }
}

function openSettings() {
  elements.settingsDrawer.classList.add("is-open");
  elements.settingsDrawer.setAttribute("aria-hidden", "false");
  elements.apiKeyInput.focus();
}

function closeSettings() {
  elements.settingsDrawer.classList.remove("is-open");
  elements.settingsDrawer.setAttribute("aria-hidden", "true");
}

function handleDrawerClick(event) {
  if (event.target === elements.settingsDrawer) {
    closeSettings();
  }
}

function saveSettings(event) {
  event.preventDefault();
  settings = {
    apiKey: elements.apiKeyInput.value.trim(),
    apiUrl: elements.apiUrlInput.value.trim() || DEFAULT_SETTINGS.apiUrl,
    model: elements.modelInput.value.trim() || DEFAULT_SETTINGS.model,
    persona: elements.personaInput.value.trim() || DEFAULT_PERSONA,
    personaVersion: DEFAULT_PERSONA_VERSION,
    modelVersion: DEFAULT_MODEL_VERSION,
  };
  saveSettingsToStorage();
  closeSettings();
}

function resetSettings() {
  settings = {
    ...DEFAULT_SETTINGS,
    persona: DEFAULT_PERSONA,
    personaVersion: DEFAULT_PERSONA_VERSION,
    modelVersion: DEFAULT_MODEL_VERSION,
  };
  saveSettingsToStorage();
  syncSettingsForm();
}

function warnPromptSecret() {
  elements.secretPromptButton.classList.add("is-warning");
  elements.secretPromptButton.textContent = "不准偷窥魔女的秘密";
}

function handleComposerKeys(event) {
  if (event.key === "Enter" && !event.shiftKey) {
    event.preventDefault();
    elements.chatForm.requestSubmit();
  }
}
