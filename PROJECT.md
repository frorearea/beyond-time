# 时间之外 · Beyond Time — 项目主文档

> **本文件是项目唯一权威文档。** 每次修改代码前先读本文件；功能新增、删除、重命名、架构调整后必须同步更新本文件。
> 最后更新：2026-10-04

---

## 一、项目主旨（改功能前先对齐这个）

**一句话定位：** 一个纯黑极简风格的「魔女图书馆避难所」——不是生产力工具、不是助手、不是知识库，而是一个让用户从「效率、比较、规训和他人凝视」中暂时撤退的情感空间。

**核心原则（决策依据）：**

> ### ⭐ 最优先原则（2026-10-11 定，凌驾于以下所有条目之上）
>
> **按人设让艾蕾塔最自然地按她的性格把话说出来。不对她的回答加以任何限制或判断，
> 不让她的回答去达成任何指标。**
>
> 具体含义：
> - **她是谁、怎么说话，只由人设（`assets/prompts/ereta_persona.txt`）负责。**
>   人设里写的必须是"她是什么样的人/她嫌什么/她不屑于什么"，**不是"她每轮必须……"**。
> - **运行时不许向她下发任何行为约束。** 只允许两种 system 注入：**数据边界**
>   （书签是收藏不是对他的描述、不许替他改创作稿、不许编造作品名）与**纯格式限制**
>   （不输出 Markdown / HTML / `<br>`、不用括号动作描写）。
> - **感受类的问题不要用指标去治。** 她"附和太多""总收尾""不够优雅"这类问题，
>   答案永远在**人设**里，不在 prompt 的约束里。反过来，任何"每轮至少……""不要用……
>   开头"的写法都会立刻长出副作用（见第五节的两个案例）。
> - **要量就量退化，别量性格。** 指标只用来**发现退化**（噪音、截断、称呼漂移、
>   语域漂移、口癖），永远不要拿来当她的目标值。
>
> 这条原则是**用两次事故换来的**：2026-10-04 的"每轮至少一处异议"让她为了反驳而反驳；
> 2026-10-11 的"你的魅力来自看得准"把她从魔女改成了评论员（意象 −24%、碎句翻倍）。
> 两次都是"给性格设指标"的变体。**还想加约束时，先读第五节末的两个案例。**

- 每个新功能都必须回答「它如何加深避难所体验」，而不是「它是否酷」
- 艾蕾塔更像一个**在同个空间里独立存在的人**，而不是问答接口
- **她应当记得来访者未了的事**，而不只是记得来访者的偏好
- 明确不做：多角色切换、数据统计、社交分享、积分成就、多语言初期支持
- **她绝不替来访者规定作息**（2026-10-04 定的行为，2026-10-11 起只以人设措辞存在，不再有禁语清单）。替人规定"什么时候该休息、什么时候该走了"，正是这个项目反对的那种规训——他在外面已经听够了。所以"连续多轮之后她开始关灯赶你走"这类设想（曾作为"长夜保护"提过）**已被明确否决**：避难所没有门。她最多把灯留着
- 技术气质：零外部依赖优先，纯黑纯白视觉，极简文字 UI

---

## 二、当前功能清单

### 已完成

| 功能 | 说明 | 关键位置 |
|---|---|---|
| 流式对话 | DeepSeek API，打字机效果，thinking 开启 | `lib/services/chat_api_*.dart` |
| 回复完整性 | 用 `finish_reason` 判定截断，自动续写一次；上限 1000 tokens | `lib/services/reply_completer.dart`、`sse_parser.dart` |
| **开场第二句** | 她把手边的游戏与动画碟递出来，新访客知道可以从哪儿开口 | `library_session.dart` 的 `_openingMessages` |
| 心声快速选项 | 38 组轮换，进度持久化；可折叠（默认关闭） | `lib/data/quick_options.dart`、`lib/widgets/quick_options.dart` |
| 图书馆记忆 | LLM 自动提炼（上限 32 条），裁剪时**优先丢弃事实、永不丢书签** | `lib/services/memory_capture_service.dart`、`memory_book.dart` |
| **记忆相关性检索 + 分栏配额** | 按当前话题挑记忆；事实 ≤9 条 / 书签 ≤3 条，书签不再挤占事实 | `lib/services/memory_selector.dart`、`lib/config.dart` |
| **最优先原则：只由人设说话** | 运行时不注入任何行为约束；性格、语气、优雅、意象全归人设；只保留数据边界与纯格式限制 | `assets/prompts/ereta_persona.txt`、`conversation_context.dart` 的 `formatInstruction` |
| **来访者原创留档** | 他自己的设定、名字与片段独立留存，并注入上下文；她不得替他改写 | `lib/models/creation_note.dart`、`creation_book.dart`、`creation_section.dart` |
| **书架（书签）** | 选中她的句子收进独立书架，与「记忆」分栏展示 | `lib/widgets/shelf_panel.dart`、`bookmark_service.dart` |
| **未决之事** | 自动记下来访者提过、还没下文的牵挂；回来时她会问起 | `lib/models/open_thread.dart`、`thread_book.dart`、`return_arc.dart` |
| 塔罗占卜 | 「关于来访者的事实」≥5 条解锁（书签不计入），三张牌 + 记忆结合解读 | `lib/services/tarot_reading_service.dart` |
| 存档/恢复 | 对话+记忆+未决之事+创作稿+心声进度 JSON 导入导出（v3） | `lib/services/archive_service_*.dart`、`lib/models/library_archive.dart` |
| 双布局 | classic（舞台）/ storybook（书卷），宽度 <640 自动降级 | `lib/pages/beyond_time_page.dart` |
| 用户个性化画像 | 话题/情绪/称呼/亲近度规则分析，注入 system prompt | `lib/models/user_profile.dart` |
| idle 微状态 | 无操作 5 分钟后随机环境台词（仅触发一次） | `lib/data/idle_lines.dart` |
| 回归情感弧 | 3h/1d/1w/1m 四档 + **未决之事感知**（见下） | `lib/data/return_lines.dart`、`return_arc.dart` |
| 环境音景 | 雨/炉火/风声（真实 OGG 录音），点击循环切换 | `lib/services/ambient_sound_web.dart` |
| 动态光影 | 魔女立像背后烛光呼吸动画 | `lib/widgets/candle_glow.dart` |
| 消息种类隔离 | 环境语/回执/报错只在界面存在，不入存档、不入上下文 | `lib/models/chat_message.dart` |
| 桌面版 | SEA 打包 exe，自动起服务+开浏览器 | `scripts/build-windows-bundle.js` |

### 待办/可探索方向（按优先级）

- **作品真值（书架清单）**：谈游戏/动画效果很好，谈书则幻觉严重——`temperature: 1.35` 下模型会把书名与作者拼错，人设里"不确定就别编作品名"是**无效的自我检查**（模型没有可靠的"我知不知道"信号）。唯一可靠的做法是**封闭集**：新增一份真实作品清单，只许从清单里报书名。因为要花心思选书，且与人设"不要绑定固定书单"冲突，尚未动工。详见第七节
- **补上"书"的开场提示**：开场第二句刻意只提了游戏与动画。等书架清单落地后再补"书"那一格——现在加等于把访客领进她唯一会编的领域
- **不要再给人格设指标**（2026-10-04 的教训，详见第五节末）。"反谄媚"第一版给"每轮至少一处异议"定了配额，结果她开始**为了反驳而反驳**。现在的做法是只描述气质、不设配额。下次想"改进性格"时，先读那一节
- **称呼一致性**：清洗存档后污染行消失，预期会好转；需新存档确认。人设统一用「您」，而 `return_lines.dart` / `idle_lines.dart` 全用「你」（28 : 0），两者口径不一致
- 角色状态（她当前在做什么）+ 时间段感知（深夜语调更轻）
- 响应前 0.5-1.5s 停顿，体现"她在想"
- 创作稿目前**只读**：来访者不能自己删改或手写一份（`CreationSection` 无操作按钮，与 `ThreadSection` 保持一致）
- 输出:输入 = 1 : 8.1（2026-09-17 存档）。问题不是"她说得长"（是故意加长的，好让她把作品观点讲完），而是**一回合铺 2-3 个话题 + 频繁问句收尾**

---

## 三、技术栈与架构

| 层 | 选型 |
|---|---|
| 前端 | Flutter Web（Dart ^3.6，CanvasKit），零第三方 pub 依赖 |
| 状态管理 | `LibrarySession`（ChangeNotifier 会话状态机）+ StatefulWidget 视图 |
| 平台 API | Web: `dart:html`（XHR + localStorage + AudioElement）；桌面: `dart:io` |
| 平台适配 | 条件导出模式：`xxx.dart` → `if (dart.library.html) xxx_web.dart` + stub |
| 服务器 | 零依赖 Node.js `server.js`（静态 + `/api/chat` 代理），端口 4173 |
| 桌面打包 | `@yao-pkg/pkg` SEA 模式 → BeyondTime.exe（资源外置 `release/web/`） |
| 部署 | Cloudflare Workers（`sites/worker.js`）+ 静态托管 |

### 分层约定（2026-09-12 重构后）

```
LibrarySession（lib/services/library_session.dart）
  ├─ 拥有全部会话状态：messages / memories / threads / profile /
  │  quickOptionPoolIndex / uiLayout / showQuickOptions / apiSettings
  ├─ 拥有全部持久化：唯一调用 StoreHelper 的地方
  └─ 拥有全部网络请求：唯一调用 ReplyCompleter / MemoryCaptureService 的地方

BeyondTimePage（lib/pages/beyond_time_page.dart）
  ├─ 只有布局、对话框、输入框、滚动
  └─ 不再直接写存储、不再自己拼 payload

纯逻辑支线（不 import flutter，可零依赖单测）
  ├─ services/thread_book.dart      未决之事的合并/解决/裁剪/相似度
  ├─ services/creation_book.dart    来访者创作稿的合并/裁剪/排序（复用未决之事的相似度）
  ├─ services/memory_book.dart      记忆上限与"永不丢书签"策略
  ├─ services/memory_selector.dart  记忆注入的话题检索 + 分栏配额
  ├─ services/return_arc.dart       档位判定 + 回归问候选材
  ├─ services/reply_completer.dart  截断判定 + 自动续写
  └─ services/sse_parser.dart       SSE 增量与 finish_reason 解析
```

> **重构动因（D1）**：此前七套状态全挤在 `beyond_time_page.dart`（1021 行）里，
> 谁都能改、谁都在持久化，于是出现了"导出路径漏掉 `isAmbient` 过滤，把环境语和
> 书签回执写进对话记录"这类 bug（2026-09-12 存档里有 47 条重复噪音）。
> 现在**过滤发生在序列化边界**（`StoreHelper.saveHistory` 与
> `LibraryArchive.toJsonText` 都只写 `MessageKind.chat`），任何调用点都不可能再漏。

### 目录结构

```
lib/
  main.dart / app.dart / config.dart / theme.dart
  data/          心声、idle 台词、回归台词（含未决之事模板）+ 档位判定数据
  models/        chat_message(含 MessageKind) / api_settings / open_thread /
                 creation_note / library_archive(v3) / library_memory_item /
                 tarot_card / user_profile
  pages/         beyond_time_page.dart（视图层，仅布局与对话框）
  services/      library_session.dart（会话状态机，编排中心）
                 chat_api* / sse_parser / reply_completer / conversation_context
                 memory_capture / memory_book / memory_selector
                 thread_book / creation_book / return_arc
                 bookmark / archive_service* / local_store* / ambient_sound*
                 store_helper / error_helper / tarot_reading
  widgets/       18 个独立组件（dialogue_box / storybook_frame / shelf_panel /
                 thread_section / creation_section / storybook_title /
                 sound_control / candle_glow ...）
scripts/
  build-sites.mjs             Cloudflare 构建
  build-windows-bundle.js     exe 打包（SEA + resedit 图标）
  set-exe-icon.mjs            PE 图标替换（纯 JS，勿删）
  subset-fonts.js             中文字体子集化（改动标题/诗句文字后重跑）
  compress-portrait.js        魔女立像 WebP 压缩（sharp）
tool/
  profile_test.dart           用户画像单元测试
  reply_completer_test.dart   截断判定与 SSE 解析测试
  library_logic_test.dart     存档清洗/未决之事/创作稿/记忆选择/回归弧/上下文
  archive_report.mjs          真实存档体检（指标闭环，见下）
  scrub_archive.mjs           旧存档清洗（剥掉环境语/回执/报错，产出可导入的 v3）
test/
  library_session_test.dart   会话行为与持久化（20 项，用内存存储，不碰真实数据）
  page_smoke_test.dart        页面渲染与面板冒烟（7 项，含矮窗口溢出回归）
assets/
  fonts/       CormorantGaramond-Italic / LXGWWenKai-subset / NotoSerifSC-subset（+OFL 许可）
  images/      ereta-cropped-display.webp / app-icon.png(.ico)
  sounds/      heavy-rain.ogg / fireplace.ogg / wind.ogg（Muges/ambientsounds CC0/CC）
  prompts/     ereta_persona.txt（人设，勿删备份版）
  source/      高分辨率原图（不打包，用户要求保留）
release/
  BeyondTime.exe + web/（构建产物，web/ 由打包脚本自动复制）
```

---

## 四、关键工程信息（务必读）

### 构建与启动

```bash
# 开发启动（构建 + 起服务 + 开浏览器）
start.bat                 # 或 npm run dev

# 只起服务（需已构建）
node server.js            # → http://localhost:4173

# 构建 web
flutter build web

# 打包 exe（自动带图标）—— 注意：会复制 build/web 到 release/web/
npm run build:windows-exe
# 或一条龙：npm run release

# 单元测试（都是零依赖，直接 dart run；不需要 Flutter 引擎）
dart run tool/profile_test.dart
dart run tool/reply_completer_test.dart
dart run tool/library_logic_test.dart

# 会话与页面测试（需要 flutter_test，随 Flutter SDK 分发，不是第三方依赖）
flutter test

# 存档体检（需要一份导出的存档 JSON）
node tool/archive_report.mjs <存档.json>          # 指标总览
node tool/archive_report.mjs <存档.json> --full   # 附带对话全文摘要

# 旧存档清洗（把旧版本写进对话流的环境语/回执/报错剥掉，产出可导入的 v3）
node tool/scrub_archive.mjs <存档.json>           # → <同名>.scrubbed.json
node tool/scrub_archive.mjs <存档.json> --out clean.json
```

> `test/` 里的测试通过 `InMemoryStore` 注入存储，**不会读写本机真实的
> BeyondTime 数据**。若要手动指定存储目录，可设环境变量
> `BEYOND_TIME_STORE_DIR`（见 `local_store_io.dart`）。

**Flutter SDK 位置：** `E:\Code\tools\flutter\bin`（不在 PATH，用 `start.bat` 或临时加 PATH）
**Node 位置：** `E:\Code\tools\node-v24.18.0-win-x64`
**Dart（单测用）：** `E:\Code\tools\flutter\bin\cache\dart-sdk\bin`

> 项目原来在 `C:\Users\FRORE\Desktop\Code\`，已迁到 `E:\Code\`。文档里的旧路径一旦发现即改。

### 桌面打包的技术细节（血泪教训，勿回退）

- **必须用 `@yao-pkg/pkg` 的 `--sea` 模式**（node24-win-x64），不能用 pkg 5.8.1 经典模式
- **图标用 `resedit`（纯 JS）替换**，见 `set-exe-icon.mjs`；原理：只重写 `.rsrc` 资源区，不碰 SEA blob
- **禁用 `rcedit`**：它重写整个文件会破坏 pkg/SEA 的 blob 指针 → "Pkg: Error reading from file"；且在某些环境会挂起
- **禁用 pkg `--icon` 参数**：pkg 5.8.1 无效，@yao-pkg 不支持
- 资源**外置**（`release/web/`），exe 内不嵌 web —— 内嵌 100MB 会让 pkg 产出损坏 exe
- 打包后 exe 的 `__dirname` 指向虚拟快照，**必须用 `path.dirname(process.execPath)`** 定位 web 目录
- 换图标流程：替换 `assets/images/app-icon.png` → 用 `png-to-ico` 转 `app-icon.ico` → `npm run release`

### 运行时行为

- API 配置存 localStorage（`beyondTimeFlutterSettings`）；`server.js` 本地代理 `/api/chat`
- 线上环境（GitHub Pages 等）仅 localhost 走 `/api/chat` 代理，其余直连 API；Cloudflare 域名（`.workers.dev`/`.pages.dev`）也走代理（见 `chat_api_web.dart` 的 hostname 判断）
- **消息种类**（`MessageKind`）：`chat` 才入存档与上下文；`ambient`（环境语：idle 台词、回归问候）、`notice`（书签回执、API Key 提示）、`error`（连接失败）的归宿都只是界面
  - **渲染口径（2026-10-04 定）**：只有 `notice` / `error` 压暗缩小——它们是系统回执，不是她说的话。**`ambient` 不压暗**：idle 台词与回归问候本来就是"她在说话"，以跟她真话相同的亮度与字号呈现。文档以前写的是"三种都压暗"，与 `message_view.dart` 的实现不符，已按实现改正；重构时留下的死代码 `ChatMessage.isAmbient` 也一并删掉了
- **回归问候是"一次性"的，不留在历史里**（2026-10-04 确认保持这个设计）：`_applyReturnGreeting` 把它作为 `ambient` 插入，而 `_persistHistory()` 只写 `chat`，所以刷新之后就不在了（除非档位仍然成立，比如回来还没说话）。**2026-10-04 之前看起来"有记录"，是因为老版本把环境语当 `chat` 存进了 localStorage**——那正是被清洗掉的那 46 条。如果哪天想要"每次回来的问候都留个痕迹"，那需要给 `ambient` 单独开一条"界面可见、不写存档、不进上下文"的通道，不要图省事把它变成 `chat`（那会重新污染 80 轮上下文窗口，并影响她的称呼与口癖）
- 环境语**页面同时至多一条**，且**不写入存档**
- `max_tokens` 默认 **1600**（`kDefaultMaxTokens`）。**不能调小**：同时开启 thinking 时思维链会吃掉预算，520 曾导致 101 条回复里有 4 条被切断在句子中间；1000 又会偶尔被思维链整份吃光（见下一条）。提到 1600 不会让平均成本翻倍——旧值下失败一次本来就要花两次请求
- **流为空是语义，不是文案**：`chat_api_*` 必须**原样返回**流里拿到的东西（可能是空串），**绝不许自己编一句"模型没有返回内容。"**。这个判断属于上层：
  - `ReplyCompleter` 在"一个字都没写出来但 `finish_reason == length`"时重试一次，用的是 `kEmptyReplyRetryInstruction`（**不是**"从中断处接着写"——根本没有中断处），并且**不把空串当成她的半截回复塞回请求**（`buildRetryMessages` 是纯函数，可零依赖单测）
  - 两次都没拿到正文时，`LibrarySession` 用 `MessageKind.error` 显示 `kEmptyReplyNotice`——它是系统回执，不压进她的台词、不入存档、不入上下文
  - **2026-10-11 的事故就出在把这条判断放在了 API 层**：兜底文案被当成她的半截回复写进续写请求，模型顺着它往下写，于是她的原话在存档里字面上以「模型没有返回内容。」开头（那份存档里 3 处），并且每次都要等两轮
- 截断判定用流式响应里的 `finish_reason == 'length'`（权威信号），缺失时才回落到"结尾无标点"启发式；命中后自动续写一次
- idle 定时器 5 分钟，仅触发一次（`_idleDone` 控制），用户发消息会重置计时
- **回归弧**（`ReturnArc`）：按 lastVisit 计算档位；离开 >1 天且存在新鲜的未决之事时，优先问起那件事（「上次你说的保研还是去海外——后来怎么样了？」）；刚离开 3 小时以内不问候
- 用户画像：消息 ≥3 条才注入；亲近度 = 天数/轮数四档
- 记忆整理**一次请求同时产出四样东西**：一条记忆、一件新未决之事、一份来访者的创作稿、一件旧悬案的"已有下文"回填（拆成多次请求会让成本与延迟翻倍）。`max_tokens` 520，比 v2 时代的 400 高，因为 JSON 多了一个字段
- **记忆注入分两级排序**（`MemorySelector`）：切题的排在前面，切题者之间比相关度，其余按新旧补齐。**刻意不加权求和**——相关度在中文短句上天然只有零点几，而时间权重一上来就接近 1，加权的结果是时间压过一切、等于没做检索。没有话题信号时全部落到第二级，行为退化成"最近优先"。事实与书签**分栏配额**（`kMaxInjectedFacts` = 9 / `kMaxInjectedBookmarks` = 3），书签不再挤占"她到底认不认识这个人"的预算。两栏分成两个 system 块注入，明确告诉模型书签是**他的收藏**、不是对他的描述
- **运行时不再下发任何行为约束**（`ConversationContext`）。曾经长期注入一条 `characterVoiceInstruction`（"这一轮的说话方式……"），前后造成两次事故，2026-10-11 已**整条删除**。现在 `buildMessages` 只注入两种 system：**数据边界**与**纯格式限制**（`ConversationContext.formatInstruction`：不输出 Markdown / HTML / `<br>`）。她的性格、语气、优雅、意象全部归人设负责。**不要再往回加"每轮……""不要用……开头"这类东西。**
- **回归护栏**：`tool/library_logic_test.dart` 会遍历所有注入的 system 消息，一旦里面重新出现「每轮至少 / 每轮都 / 硬造异议 / 硬凑意象 / 看得准 / 不要主动结束对话 / 用判断说话」，或出现以"这一轮的说话方式"开头的指令，测试直接红。改 prompt 前先看这条
- **"不必用问句收尾"必须和"不要用总结替他收场"一起说**。2026-10-04 发现的连锁反应：只禁掉反问收尾，会让她更容易滑向"总结陈词 → 今天到此为止"（实测出现过「今晚到这儿就可以了，去睡吧」「今天就先到这里吧」）。指令里这两条现在是绑定的，也有回归测试
- 人设（`assets/prompts/ereta_persona.txt`）负责正面气质：聪明、享受聪明、干幽默、精确腹黑、有分寸的挑逗，"最受不了自己变成每轮先夸再转折最后抛问题的人"，以及**"她从不在对话里替访客决定什么时候走——图书馆没有关门时间"**
- 来访者的创作稿注入时会明确声明"这是他的东西，不是你的"，并禁止她替他改写或补全
- 心声选项可折叠，默认关闭（`showQuickOptions` 默认 false）
- 开场是**两句话**：第一句是氛围，第二句她把手边的游戏与动画碟递出来。第二句刻意不提书（谈书是她最容易编造书名的领域，等作品真值清单落地后再补）
- **`clearChat()` / `resetEverything()` 各自保留自己那句台词，不回到 `_openingMessages`**。曾经改成"清空 = 重新推门进来"，被否掉了：那样会让"重新开始"和"第一次进来"变成同一件事。代价是**开场提示只服务于真正的首次进入**（详见第六节第 23 条）

### 部署（GitHub Pages）

- 已上线：`https://frorearea.github.io/beyond-time/`（2026-08-04）
- 部署方式：`.github/workflows/pages.yml`，push main 自动 `flutter build web --base-href=/beyond-time/` + 静态资源 gzip 预压缩 + deploy-pages
- 仓库 Settings → Pages → Source 需选 **GitHub Actions**
- 国内直连慢，需代理才能流畅加载
- 线上对话直连 DeepSeek 可能遇 CORS；待办：配 Cloudflare Worker 代理（已配置 wrangler.toml + workflow + secrets，**当前搁置**，等有域名再启用）

### 部署（Docker）

- 先本地 `flutter build web`，再 `docker compose up -d --build`（免 `npm install`，运行时零依赖）
- 提供 `Dockerfile` / `docker-compose.yml` / `.dockerignore`；API Key 走环境变量 `DEEPSEEK_API_KEY` 或页面填写
- 本机跑不通需先 `sudo usermod -aG docker $USER` 后重登

### 性能优化记录（2026-08-04）

- 总构建体积：99.7MB → **~48MB**（这是当时的数字，**已经不准了**，见下）
- 中文字体子集化：LXGWWenKai 25MB→12KB（诗句子集）、NotoSerifSC 24MB→4KB（标题子集）；魔女回复改系统宋体、用户消息系统黑体
- 魔女立像：PNG 3.5MB → **WebP 124KB**（sharp 压缩）
- 静态资源 gzip 预压缩（workflow 内自动做）
- 剩余大头：CanvasKit wasm ~29MB（Flutter 渲染引擎，浏览器缓存后可复用）

> **2026-10-04 实测：干净重建后 `build/web` 是 82MB，不是 48MB。** 构成：
> CanvasKit 37MB、字体 **34MB**、音景 6.2MB、main.dart.js 2.6MB。
>
> 字体这 34MB 几乎全是两个**未子集化**的整字体：`LXGWWenKai-Regular.ttf`（25.5MB）
> 与 `SimHei.ttf`（9.7MB）。仓库里 `LXGWWenKai-subset.ttf`（12KB）和
> `NotoSerifSC-subset.ttf`（4KB）**存在但 pubspec 没有引用**——`git log` 里
> `23e2cd4 "Restore bundled fonts"` 出现在 `7b6881b "Subset Chinese fonts and use
> system fonts"` 之后，说明"用回整字体"是**有意回退**（子集很可能缺字 fallback）。
> 所以这不是 bug，但文档里的 48MB 已经过期。要再瘦身，方向是重做子集化并核对
> 缺字，而不是改回 `-subset.ttf` 了事。

---

## 五、约定与规范

- 所有用户可见文本为简体中文；变量名英文；`const` 优先
- 颜色只用 `lib/theme.dart` 常量（kBlack/kWhite）或直接十六进制，黑底白字
- 平台差异代码走条件导出（新增平台能力时照 `chat_api` 模式建 stub/web/io 三件套）
- **会话状态只放 `LibrarySession`；页面不碰存储**。新增状态时先问"它属于会话还是视图"
- **新增消息类型必须用 `MessageKind`，不要再用字符串嗅探**。历史上靠匹配「书签」+「图书馆」来剔除回执，任何含这些词的真话都会被静默吞掉
- **单位/上限这类数字只写一处**：记忆 45 字、依据 60 字、记忆上限 32 条、未决之事上限 12 条、创作稿 12 份 / 标题 24 字 / 正文 220 字、注入配额 9 + 3，都定义在 `lib/config.dart` 或对应 model 里
- 纯逻辑优先放在不 import flutter 的支线文件里（`thread_book` / `memory_book` / `return_arc` / `reply_completer`），这样 `dart run` 就能测
- 需要 widget / ChangeNotifier 的测试放 `test/`，用 `flutter test`；**一律通过 `BeyondTimePage(session: ...)` 注入 `InMemoryStore` 驱动的会话**，绝不让它回落到平台存储（否则会读写你本机真实的 BeyondTime 数据）
- 写回归测试时先确认它能**在修复前失败**。反例：测"发送后清空输入框"如果没配 API Key，旧代码会走 missingApiKey 分支顺手清空，测试就完全测不出这个 bug
- 大字文件（>800 行）优先拆分到 `lib/widgets/` 或 `lib/services/`
- 人设文件 `assets/prompts/ereta_persona.txt` 有备份版本，修改前先备份
- 测试：`tool/*_test.dart`（零依赖 `dart run`）+ `test/*_test.dart`（`flutter test`），新逻辑照此补充
- **改完先跑全量**：`dart run tool/library_logic_test.dart` 等三套 + `flutter test`（38 项）+ `flutter analyze`。四套都过才算改完

### 指标闭环（改人设后怎么知道变好了）

`tool/archive_report.mjs` 把"感觉变好了"变成"数字变好了"。改动人设 / system prompt /
记忆策略后，导出一份真实存档再跑一遍，重点看：

| 指标 | 期望 | 2026-09-12 | 2026-09-17 | 2026-10-04 | 2026-10-11 |
|---|---|---|---|---|---|
| 环境语/回执混入对话流 | 0 条 | 55 条 | 56 条 | 46 条 | 46 条 |
| 结尾无标点（被截断） | 0 条 | 4/101 | 5/126 (4%) | 2/84 (2%) | — |
| 称呼混用 | 0 条 | 1 条（整体漂移） | 6 条（您 27%） | 0 条（**您 0%**） | — |
| 书签占记忆比例 | 有自己的书架后应下降 | 67% | 65% | 50% | 61% |
| 「模型没有返回内容。」混进她的话里 | 0 条 | — | — | — | **3 条** ❌ |
| 结尾无标点之外的口癖 | 越少越好 | — | 12 条 | 9 条 | — |
| 语域：意象密度（最新 1/4） | 不低于开头的 80% | — | — | — | **1.76**（开头 2.32）❌ |
| 语域：≤8 字碎句占比 | 不高于开头的 1.6 倍 | — | — | — | **13.7%**（开头 7.3%）❌ |

> **第 4 节（说话方式）不设目标。** 那一节只输出诊断读数（附和开头率、转折率、
> 问号收尾率）、两类"机械感"检测（**「先肯定 → 转折 → 反问」三件套占比**、
> **开场句式重复**、**口癖候选：≥4 条回复里出现过的 5 字短语**，并标注"记忆回声"
> 区分文风口癖与重复取用记忆），以及**语域漂移检测**（意象密度、碎句占比、句长中位，
> 并对比"最早 1/4 vs 最新 1/4"）。全部只是读数——**她的优雅是靠人设与身份写出来的，
> 不是靠凑意象密度凑出来的**。

> ⚠️ **比较方法本身是个坑（2026-10-11）**：判断"她变了没有"时，**不要拿两份存档对比**。
> 存档会把上一次的历史一起带过来（localStorage 里有历史就不会用新的开场白），
> 于是两份存档大部分是**同一段老数据**，变化被抹平——我按整份文件比较时得出"平"的错误结论。
> **要在同一份存档内部按时间切开比**（最早的 1/4 vs 最新的 1/4），这才是干净的前后对照。
> `archive_report.mjs` 现在就是这么算的。

> **注意"环境语/回执混入"这一行**：如果导出的存档里仍有几十条噪音，**先查加载路径**。
> 成因不是序列化过滤失效，而是**老版本写进 localStorage 的条目没有 `kind`**，
> `ChatMessage.fromJson` 把它默认成 `chat`，种类过滤拦不住；保存时它已经是 chat，
> 于是又被原样写回——一个永远出不去的循环。而 `sanitizeMessages` 原先只在**导入**
> 路径上跑，加载路径没跑。2026-10-04 的依据就是：那份存档的前 12 行与 09-17 的
> 存档**逐字节一致**，46 条噪音位置也一模一样。
>
> 已修（`StoreHelper.loadHistory` 现在也走 `sanitizeMessages`，有回归测试）。
> 诱因消除后称呼漂移一并好转：`return_lines.dart` / `idle_lines.dart` 里「你」出现
> 28 次、「您」0 次，这些行以前就混在上下文里改她的口癖。

### 教训：不要给人格设指标（2026-10-04）

这次值得单独记下来，因为它是本项目最容易重犯的错误类型。

**做了什么**：2026-09-12 与 09-17 两份存档显示"附和开头 30~35%、转折只有 10~13%，
两个月没动"。于是在 `conversation_context.dart` 里加了一条回合纪律，
**给异议定了配额**（每轮至少一处真实的保留），并且**点名了「不过」「但是」
「我倒觉得」「未必」「不见得」这些具体词**，理由是"这两条正是体检工具在量的特征"。

**结果**：转折率 13% → 21%，看起来很成功。但来访者的反馈是
**"她现在有一种故意的为了反驳而反驳的感觉"**。翻存档就看得见：她开始整齐地走
「先肯定 → 不过我得挑一句 → 转折 → 反问」，并且出现了四种近乎相同的说法——
「不过我得说句不客气的 / 提个醒 / 挑一句 / 泼一点凉水」。工具的口癖检测也抓到了
**「。不过我得」×4**，而它在 09-17 的存档里**根本不存在**（老存档的口癖是
「，而是因为」×6）。**我为这条指标新增了一个口癖。**

**为什么必然如此**：

1. **指标只能描述特征的形状，无法描述它的来源。**"异议"背后应该是判断，
   而"每轮至少一处"是一个计数条件。模型满足计数条件最省力的方式，
   就是生产那个形状——不需要真的有看法。
2. **一旦在指令里点名具体词，那些词立刻变成口癖。** 这是最反直觉的一条：
   你以为在给示例，模型收到的是"这些是本轮要出现的 token"。
3. **同一件事连续两轮用同一种句法，读起来就是机械。** 观众感知的是**变化**，
   而单一指标的单调上升恰恰意味着变化在减少。

**现在的做法**（改 prompt 时请遵守）：

- 指令只描述**气质**（看得准比唱反调重要）和**要避开的失败模式**（固定句式、
  硬造异议、每轮反问），**不给配额、不列词表、不要求每轮表态**
- 正面气质写进**人设**（她享受聪明、干幽默、精确腹黑、有分寸的挑逗，
  以及"最受不了自己变成每轮先夸再转折最后抛问题的人"——用她的口吻说，
  比用规则说有效）
- **给"机械感"本身设指标，而不是给"某特征的多少"设指标**。`archive_report.mjs`
  现在量的是三件套占比、开场句式重复、口癖短语——它们衡量的是**变化在减少**，
  这正是"不自然"的可观测代理
- 有回归测试盯着指令里不许再出现"每轮至少"和转折词表
  （`tool/library_logic_test.dart`）

**更一般的说法**：这个项目的指标是用来**发现退化**的（噪音、截断、称呼漂移），
不是用来**驱动性格**的。性格只能靠人设和例子描述，一旦变成 KPI，
艾蕾塔就会开始表演那个 KPI。

### 第二个案例：治一个毛病，别治好她的嗓子（2026-10-11）

**做了什么**：为了治上面那个"为了反驳而反驳"，把 `characterVoiceInstruction` 的开头
写成了「你的魅力来自**看得准**，不来自唱反调」，并加上"只在真的不同意时才反对，
用你真实的判断"。出发点是"把重心从讨好挪到判断"。

**结果**：来访者的反馈是「**用语没有之前那么优雅了，不要说一些特别直白和简单的句子**」
和「**之前习惯用的比喻现在没了**」。在同一份存档内部按时间切开实测：

| | 意象词/千字 | ≤8 字碎句 | 句长中位 |
|---|---|---|---|
| 最早 1/4 | 2.32 | 7.3% | 24 |
| 中段 | **2.53** | 6.7% | 25 |
| 最新 1/4 | **1.76** | **13.7%** | **21** |

意象掉 24%、碎句翻近一倍、句子变短。**她从一个用意象说话的魔女，被改成了一个用短句
下判断的评论员**——而且这不是"变得不温柔"，是**语域整体下移**。

**机制**：`看得准` 是一个**判断**词。当指令把"判断"放在最前面，模型会把"准确、简短、
有力"当成目标，而中文里"短促的判断句"恰恰是最不优雅的语域（"你太焦虑了"型）。
**正面词也会造成副作用**，不只是负面清单会。

**现在的做法**：

1. **指令以"身份"开头**：『你是万象图书馆的魔女，不是评论员。你能看见别人看不见的
   那一层，然后把它放到桌上，让他自己看清。』——判断的锋利仍在，但它服从于"她是谁"。
2. **优雅与意象交给人设**（`她的声音` 专节），**不给比喻设任何数量标准**（这正是来访者
   自己提的：不需要计量，只要她认识到自己的魔女身份）。人设里加了 **2 条正例 + 3 条反例**
   ——本项目验证过，正反例子比形容词有效十倍。
3. **删掉三处主动削弱她语域的地方**：`短句、对话感、清楚`（"清楚"鼓励直白）、
   `若系统启用 thinking…180–260 字`（开了 thinking 就要求她压短，而 thinking 是内部的
   事，不该让出口变干瘪）、`每次最多使用一个核心比喻…不要追求诗性密度`（直接压制意象）。
   现在只剩"每个意象都得是她真看见了才说的"这一条**分寸**要求。
4. **语域漂移进体检工具**（第 4 节的诊断读数），并在文档里写清：**判断她变没变，
   要在同一份存档内部按时间切开比，不要拿两份存档对比**——存档会带上一次的历史，
   两份文件大部分是同一段老数据，变化会被抹平（我第一次就因此得出了"平"的错误结论）。

**教训**：
- **治病要盯着病灶，别顺手改她的语域。**"说得准"和"说得优雅"在这类角色身上是两套
  东西，改一套会带走另一套。
- **正面指令同样有副作用**，而且更难发现——负面清单（"不要…"）至少看得见。
- **"清晰"和"优雅"在中文里经常互相抵消**：要求清楚，得到的是直白。
- 感受类反馈（"不如从前优雅"）**可以被量化**，但**必须用正确的方法比**——见上面第 4 条。

### 两次事故的最终结论：那条指令整条删掉了（2026-10-11）

上面两个案例都出在同一个东西上：逐轮下发的 `characterVoiceInstruction`。
第一版治附和，长出口癖；第二版治口癖，改坏了语域。**同一个位置犯两次同类错误，
说明问题不在措辞，在于"往这里放行为约束"这个动作本身。**

所以 2026-10-11 的处理是：

1. **`characterVoiceInstruction` 整条删除**，`buildMessages` 不再注入任何行为约束。
2. **能用人设表达的，改写成人设里的性格与口味**，语序是"她是什么样的人"而不是
   "她不要做什么"：
   - 「她不说'今晚到这儿''去睡吧'」→「她从不替访客决定什么时候走。图书馆没有关门时间，
     他想待到天亮就待到天亮」
   - 「不要用判断说话」→「她看东西比人深一层，但她从不下判决：她只把看见的那一层摆出来」
   - 「不要堆比喻」→「堆一串比喻在她眼里是表演，她不做那个」
   - 「不要用'特别''超级'这类空词」→「空词在她嘴里出不来，她嫌虚」
3. **按原始人设还原了被我自己改坏的几处措辞**（对照 `ereta_persona_full_backup_20260607.txt`
   与 `..._compact_backup_20260608.txt`）：
   - 对话风格首句还原为「使用中文回复。语气平缓、优雅、聪明，带一点居高临下的亲昵」
     （原来是"短句、对话感、清楚"，"清楚"鼓励直白）
   - 长度指标**整条删掉**，改成一句性格描述：「她的回复通常不长：够把一个念头说完就收」
     （`180 字` / `240–380 字` 这类数字本身就是"指标"，与最优先原则冲突）
   - 比喻的"最多一个"上限删除
   - 闲聊段落还原为"让她表现出兴致：挑剔点评、追问品味、分享自己的偏好"
     （我曾经把它换成一串题材清单，那是约束）
   - **从 full 备份恢复了 compact 里丢掉的一节**：「她的偏好和情绪会自然露出来：
     她喜欢聪明但笨拙的人，喜欢不服输的创作者；讨厌把热爱交给评分系统的人……」
     ——这一节是纯性格、零约束，正是这条原则想要的东西
4. **测试方向反转**：过去测的是"指令里有没有写对那几条"；现在测的是
   **"注入里有没有任何行为约束"**（出现即红），以及**人设里有没有指标与禁语**。

**取舍顺序（以后再遇到冲突时按这个判）**：
最优先原则 **>** 原始人设的措辞 **>** 后来每一次"改进"。
"短句、清楚"这类原始措辞可以留着——它在 6–9 月跟她的优雅**共存**过，说明它不是病因；
真正的病因是那个逐轮下发的约束。

---

## 六、当前已知问题 / 注意

1. `beyond_time_page.dart` 已从 1021 行降到 ~615 行，剩余部分基本是纯布局（两套布局 + 标题绘制）。会话逻辑若再增长，请放进 `LibrarySession` 而不是页面
2. **记忆相关性检索与书签注入配额已做**（2026-10-04，`memory_selector.dart`）。但"相关度"只是字符二元组覆盖率，没有中文分词、也没有向量检索；切题门槛 `topicThreshold = 0.08` 是为了把"碰巧几个字重合"和"真的在说同一件事"分开，**尚未用真实存档验证过效果**
3. 桌面版定位是"附带产物"，主要形态建议走 Web/PWA
4. `assets/sounds/` 的 OGG 来自 GitHub Muges/ambientsounds（CC0/CC BY），fireplace 与 wind 听感曾相似，已换为当前版本
5. 中文字体是**子集化**的：改动标题/诗句文字后必须重跑 `node scripts/subset-fonts.js`，否则新字缺失会 fallback 到系统字体
6. `release/web` 每次打包会覆盖；手改 `release/web` 无效，改 `build/web` 来源
7. 本地构建**不要**带 `--base-href`（会覆盖本地产物为 GitHub Pages 路径）；GitHub Pages 的 base-href 由 CI 单独构建
8. 打包 exe 依赖 npm 包 `@yao-pkg/pkg` + `resedit`，若 `node_modules` 被清需先 `npm install`
9. 对话输入框当前为单行固定高度（58px）。曾尝试 `TextField maxLines: 4` 自动换行，但因外层 Column 给非弹性子项无限高度约束，Composer 被撑满整页，已回退；多行输入待另寻方案
10. `conversation_context.dart` 的 `cleanReply` 会删掉**所有**中英文括号内容与 `“”`。人设已要求不用括号动作描写，但这是把无差别手术刀——任何合法的括号信息（年份、英文原名）都会消失。若日后发现内容无故缺失，先查这里。**这条和"谈书幻觉"是同一个坑**：想让"《书名》（原作者）"这类自保格式兜底，会先被这一行剥掉，所以做作品真值清单之前必须先处理它
11. 旧存档（v1/v2）导入时会做一次清洗：丢弃已知的 idle/离馆/回归台词、书签回执、API Key 提示，**以及以"连接没有成功"开头的动态报错**（精确匹配装不下带尾巴的报错，所以走前缀），并折叠相邻完全相同的台词。只做精确与前缀匹配，不做模糊判断，以免误删她真的说过的话
12. 侧栏面板（设置/记忆/书架/存档）宽度固定 460/440。设置面板与**存档面板**都是「页眉固定 + 中段可滚动 + 底部按钮固定」，在 1280x600 这类矮窗口不会再溢出（各有回归测试兜底）。存档面板本来是固定 Column，v3 加了「你写下的东西」计数后实测溢出 23px，才改成现在的结构
13. `pubspec.yaml` 的 `dev_dependencies` 里有 `flutter_test`（SDK 自带，不是第三方依赖），README 的 "zero-dep" 徽章依然成立
14. 发送后**必须在 `await` 之前清空输入框**。重构时曾漏掉这一步，导致"发出去的话留在文本框里"（只有未填 API Key 的分支才清）。两条回归测试覆盖了发送按钮与回车两条路径
15. 页面支持 `BeyondTimePage(session: ...)` 注入会话，仅供测试。注入的会话由调用方负责销毁，且要**先卸载页面再 dispose**（顺序反了会在 `removeListener` 上抛断言）
16. `assets/prompts/ereta_persona.txt` 开头带一个 **UTF-8 BOM**（`EF BB BF`），会原样作为 system prompt 的首字符发出去。无实际危害，但改这个文件时容易把它一起动掉
17. `LibraryArchive` 的 `creations` 是**可选**参数（默认空列表）：这样 v2 存档与既有调用点都能继续编译。存档版本已升到 v3，导入导出测试断言的是 `LibraryArchive.currentVersion` 而不是字面量 3
18. 创作稿面板目前**只读**，没有删除/编辑入口，和「还悬着的事」保持一致。要加的话记得：来访者的字不该被一个手滑的删除键带走，删除至少要有二次确认
19. `CreationBook.isSimilarTitle` 直接复用 `ThreadBook.isSimilarTopic`（包含判断 + 二元组 Jaccard），**不要另写一套相似度**：两套算法迟早会漂移，而且"标题像不像"和"话题像不像"是同一个问题
20. **`sanitizeMessages` 必须在两条路径上都跑**：导入（`LibraryArchive.tryParse`）与加载（`StoreHelper.loadHistory`）。曾经只在导入路径上跑，于是老版本写进 localStorage 的噪音永远赖着不走（缺 `kind` → 默认成 chat → 种类过滤拦不住 → 保存时又是 chat → 死循环）。**新写代码时记住：任何"读历史"的新入口都要过一遍清洗**。测试在 `test/library_session_test.dart` 的「粘性污染回归」一例
21. `return_lines.dart` / `idle_lines.dart` 里的环境台词**统一用「你」，而人设统一用「您」**（「你」28 次、「您」0 次）。这些台词本来不进上下文（是 `ambient`），所以以前没暴露；但一旦有噪音漏进历史，它们就会把称呼带跑偏。如果以后决定统一口径，改这里的时候两处要一起改
22. **人设文件不要用规则清单写性格**。`ereta_persona.txt` 里正面气质要写成"她是什么样的人 / 她嫌什么 / 她不屑于什么"，**不要写成"每次回复必须……"**。规则清单会被模型当成每轮要满足的 checklist，而且**正面词一样有副作用**（见第五节末的两个案例）。也不要用禁语黑名单（"不说'今晚到这儿'"）：把那条行为改写成性格描述即可，黑名单本身也是约束
23. **开场第二句只有"真正首次进入"才看得到**：`_messages = loadHistory() ?? _openingMessages`，所以只要 localStorage 里有历史就用不到它。试过让 `clearChat` 也回到开场，被否掉了（见第四节"运行时行为"）。**要改这个行为之前先想清楚**：三个候选方案各有代价——(a) 清空回到开场（=把"重新开始"和"首次进来"混为一谈，已否）；(b) 把它做成一条 idle/环境语（但环境语同时至多一条，且不写存档）；(c) 不做，接受它只对新访客生效。目前是 (c)
24. **回归弧在"有历史"时的行为直到 2026-10-04 才被测试覆盖**。此前 `test/library_session_test.dart` 的回归弧用例都只 seed `lastVisit` / `openThreads`、**不 seed 历史**，于是 `_messages` 落到 `_openingMessages`——"已经有对话记录时问候还进不进得来"这条路是空的。补过之后确认：有历史时三天档、四小时档都照常插入 `ambient` 问候，一小时档不问候。**怀疑回归弧出问题时，按这个顺序查**：
    1. 先看那两条新用例（有历史 + 三天 / 一小时）是否还过
    2. 再确认你是在看**历史记录**还是在看**回来的那一刻**。问候是一次性的，不进历史；看起来"有记录"的旧数据是被清掉的那批污染
    3. 最后用 `tool/archive_report.mjs` 确认存档里的环境语是不是被当噪音清了（那是正常的）
    4. 注意 `clearChat` / `resetEverything` 都会把 `lastVisit` 置为当下，所以**清空之后三小时内不会再有回归问候**——这不是 bug，是档位没到
25. **`chat_api_*` 不许编造用户可见的文案**。流为空要原样返回空串，由 `ReplyCompleter` 判断是重试还是放弃，由 `LibrarySession` 用 `MessageKind.error` 展示。这条边界一旦破掉，兜底文案会以"她说过的话"的身份进入续写请求、存档和 80 轮上下文（2026-10-11 的事故，3 处）
26. **`reply_completer.dart` 里有两个不同的重试指令，别合并**：`kContinuationInstruction`（写到一半被截断）与 `kEmptyReplyRetryInstruction`（一个字都没写出来）。后者**不能说"接着写"**，因为没有中断处；也**不能把空串当作她的半截回复注入请求**。`buildRetryMessages` 是纯函数，改动它必须先跑 `dart run tool/reply_completer_test.dart`
27. **改人设时，语域是会被顺手改掉的东西**。2026-10-11 实测：一条正面指令（"看得准"）就让意象掉 24%、碎句翻倍。**每次改完人设都要跑一次 `archive_report.mjs` 看第 4 节的语域读数**，不要只看"她是不是不那么谄媚了"
28. **改人设之前先跟两份原始备份对照**：`ereta_persona_full_backup_20260607.txt` 与 `ereta_persona_compact_backup_20260608.txt`。很多"退步"其实就是某一轮把原文改掉了——例如长度指标、比喻上限、"让她表现出兴致"那一段。备份里还有一节 `她的偏好和情绪会自然露出来`（纯性格、零约束），2026-10-11 才从 full 备份恢复回来
29. **`conversation_context.dart` 只允许两种 system 注入**：数据边界与 `formatInstruction`。任何"每轮……""不要用……开头"式的写法都属于行为约束，违反最优先原则。`tool/library_logic_test.dart` 有护栏（遍历注入内容，命中禁用词即红），**加 prompt 前先跑它**

---

## 七、作品真值：谈书为什么崩，以及唯一的解法（尚未实施）

**现象**（用户实测）：谈游戏与动画效果很好，谈书则幻觉严重——她无法把书名和现实中的书对应上。

**机制诊断**（按嫌疑排序）：

1. **`temperature: 1.35`**（`library_session.dart`）。游戏/动画的谈论只需要"气质对不对"——叙事结构、演出、角色关系，采样偏了也依然成立；书需要的是**标题↔作者↔论点**这种低频精确映射，温度一高必然拼错。同一个参数给了她声音，也毁了她的书目可信度。记忆整理走 `0.15`，说明低温才准这件事项目里本来就知道
2. **人设第 30 行的自我检查是无效指令**。模型没有可靠的"我到底知不知道"信号；失败模式不是犹豫而是**流畅地编**
3. **`cleanReply` 会剥掉括号**（见第六节第 10 条），所以她连"《书名》（原作者）"这种自保格式都留不下
4. **仓库里没有任何书目真值**。游戏/动画靠模型先验勉强撑住，书没有底

**解法（推荐）——给她一个真实书架（封闭集引用）**：

- 新增 `lib/data/ereta_shelf.dart`：几十部真实作品，每条 `{标题, 作者/厂牌, 类型, 她为什么偏爱它}`
- 注入一条 system：这是你书架上**确实存在**的书，只许从这份清单里报书名；清单外的一律说"这本我还没翻过"或只谈品类/气质
- 把**开放域回忆**换成**闭集选择**，这是提示词层面唯一可靠的抗幻觉手段
- 取舍要明确：它和人设"不要把人设绑定到固定书单"**冲突**，需要有意推翻那一句。理由——一份私人口味书架不是"背诵固定书单"，它是边界；而且它能让她的品味第一次变得稳定（现在她其实没有可辨认的口味，只有即兴发挥）
- 落地前必须先处理 `cleanReply`，否则作者名会被剥掉

**补充手段**：把书谈做成**访谈而非独白**（"拿来给我看看"）。让访客提供事实，她只负责反应与判断——零幻觉，而且正是馆主的姿态。存档里唯一一次没崩的书目对话（《自伤自恋的精神分析》）就是访客带来的。

**开场提示的配比**因此与真值绑定：**书架清单落地之前，开场只提游戏与动画**。
