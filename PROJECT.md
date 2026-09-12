# 时间之外 · Beyond Time — 项目主文档

> **本文件是项目唯一权威文档。** 每次修改代码前先读本文件；功能新增、删除、重命名、架构调整后必须同步更新本文件。
> 最后更新：2026-09-12

---

## 一、项目主旨（改功能前先对齐这个）

**一句话定位：** 一个纯黑极简风格的「魔女图书馆避难所」——不是生产力工具、不是助手、不是知识库，而是一个让用户从「效率、比较、规训和他人凝视」中暂时撤退的情感空间。

**核心原则（决策依据）：**
- 每个新功能都必须回答「它如何加深避难所体验」，而不是「它是否酷」
- 艾蕾塔更像一个**在同个空间里独立存在的人**，而不是问答接口
- **她应当记得来访者未了的事**，而不只是记得来访者的偏好
- 明确不做：多角色切换、数据统计、社交分享、积分成就、多语言初期支持
- 技术气质：零外部依赖优先，纯黑纯白视觉，极简文字 UI

---

## 二、当前功能清单

### 已完成

| 功能 | 说明 | 关键位置 |
|---|---|---|
| 流式对话 | DeepSeek API，打字机效果，thinking 开启 | `lib/services/chat_api_*.dart` |
| 回复完整性 | 用 `finish_reason` 判定截断，自动续写一次；上限 1000 tokens | `lib/services/reply_completer.dart`、`sse_parser.dart` |
| 心声快速选项 | 38 组轮换，进度持久化；可折叠（默认关闭） | `lib/data/quick_options.dart`、`lib/widgets/quick_options.dart` |
| 图书馆记忆 | LLM 自动提炼（上限 32 条），裁剪时**优先丢弃事实、永不丢书签** | `lib/services/memory_capture_service.dart`、`memory_book.dart` |
| **书架（书签）** | 选中她的句子收进独立书架，与「记忆」分栏展示 | `lib/widgets/shelf_panel.dart`、`bookmark_service.dart` |
| **未决之事** | 自动记下来访者提过、还没下文的牵挂；回来时她会问起 | `lib/models/open_thread.dart`、`thread_book.dart`、`return_arc.dart` |
| 塔罗占卜 | 「关于来访者的事实」≥5 条解锁（书签不计入），三张牌 + 记忆结合解读 | `lib/services/tarot_reading_service.dart` |
| 存档/恢复 | 对话+记忆+未决之事+心声进度 JSON 导入导出（v2） | `lib/services/archive_service_*.dart`、`lib/models/library_archive.dart` |
| 双布局 | classic（舞台）/ storybook（书卷），宽度 <640 自动降级 | `lib/pages/beyond_time_page.dart` |
| 用户个性化画像 | 话题/情绪/称呼/亲近度规则分析，注入 system prompt | `lib/models/user_profile.dart` |
| idle 微状态 | 无操作 5 分钟后随机环境台词（仅触发一次） | `lib/data/idle_lines.dart` |
| 回归情感弧 | 3h/1d/1w/1m 四档 + **未决之事感知**（见下） | `lib/data/return_lines.dart`、`return_arc.dart` |
| 环境音景 | 雨/炉火/风声（真实 OGG 录音），点击循环切换 | `lib/services/ambient_sound_web.dart` |
| 动态光影 | 魔女立像背后烛光呼吸动画 | `lib/widgets/candle_glow.dart` |
| 消息种类隔离 | 环境语/回执/报错只在界面存在，不入存档、不入上下文 | `lib/models/chat_message.dart` |
| 桌面版 | SEA 打包 exe，自动起服务+开浏览器 | `scripts/build-windows-bundle.js` |

### 待办/可探索方向（按优先级）

- **记忆相关性检索**：目前是最近 12 条倒序注入，其中常有大半是书签（2026-09-12 存档：21 条记忆里 14 条是书签）。应按当前话题打分取 Top-N，并给书签设注入配额
- **反谄媚**：2026-09-12 存档实测——35% 的回复以附和词开头，只有 10% 含转折/保留意见。「小恶魔、挑剔、取笑品味」在 101 条真实回复里只出现过一次
- **称呼一致性**：同一份存档里 84 条用「你」、9 条用「您」，且从某一轮开始整体切换且不再切回
- 角色状态（她当前在做什么）+ 时间段感知（深夜语调更轻）
- 响应前 0.5-1.5s 停顿，体现"她在想"
- 让来访者的原创（设定、故事名、片段）有地方留存与回访

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
  ├─ services/memory_book.dart      记忆上限与"永不丢书签"策略
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
                 library_archive(v2) / library_memory_item / tarot_card / user_profile
  pages/         beyond_time_page.dart（视图层，仅布局与对话框）
  services/      library_session.dart（会话状态机，编排中心）
                 chat_api* / sse_parser / reply_completer / conversation_context
                 memory_capture / memory_book / thread_book / return_arc
                 bookmark / archive_service* / local_store* / ambient_sound*
                 store_helper / error_helper / tarot_reading
  widgets/       17 个独立组件（dialogue_box / storybook_frame / shelf_panel /
                 thread_section / storybook_title / sound_control / candle_glow ...）
scripts/
  build-sites.mjs             Cloudflare 构建
  build-windows-bundle.js     exe 打包（SEA + resedit 图标）
  set-exe-icon.mjs            PE 图标替换（纯 JS，勿删）
  subset-fonts.js             中文字体子集化（改动标题/诗句文字后重跑）
  compress-portrait.js        魔女立像 WebP 压缩（sharp）
tool/
  profile_test.dart           用户画像单元测试
  reply_completer_test.dart   截断判定与 SSE 解析测试
  library_logic_test.dart     存档清洗/未决之事/回归弧/记忆上限/上下文（60 项断言）
  archive_report.mjs          真实存档体检（指标闭环，见下）
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
- **消息种类**（`MessageKind`）：`chat` 才入存档与上下文；`ambient`（环境语）、`notice`（书签回执、API Key 提示）、`error`（连接失败）只在界面显示，界面压暗以示不是她的话
- 环境语**页面同时至多一条**，且**不写入存档**
- `max_tokens` 默认 1000（`kDefaultMaxTokens`）。**不能调小**：同时开启 thinking 时思维链会吃掉预算，520 曾导致 101 条回复里有 4 条被切断在句子中间
- 截断判定用流式响应里的 `finish_reason == 'length'`（权威信号），缺失时才回落到"结尾无标点"启发式；命中后自动续写一次
- idle 定时器 5 分钟，仅触发一次（`_idleDone` 控制），用户发消息会重置计时
- **回归弧**（`ReturnArc`）：按 lastVisit 计算档位；离开 >1 天且存在新鲜的未决之事时，优先问起那件事（「上次你说的保研还是去海外——后来怎么样了？」）；刚离开 3 小时以内不问候
- 用户画像：消息 ≥3 条才注入；亲近度 = 天数/轮数四档
- 记忆整理**一次请求同时产出三样东西**：一条记忆、一件新未决之事、一件旧悬案的"已有下文"回填（拆成两次请求会让成本与延迟翻倍）
- 心声选项可折叠，默认关闭（`showQuickOptions` 默认 false）

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

- 总构建体积：99.7MB → **~48MB**
- 中文字体子集化：LXGWWenKai 25MB→12KB（诗句子集）、NotoSerifSC 24MB→4KB（标题子集）；魔女回复改系统宋体、用户消息系统黑体
- 魔女立像：PNG 3.5MB → **WebP 124KB**（sharp 压缩）
- 静态资源 gzip 预压缩（workflow 内自动做）
- 剩余大头：CanvasKit wasm ~29MB（Flutter 渲染引擎，浏览器缓存后可复用）

---

## 五、约定与规范

- 所有用户可见文本为简体中文；变量名英文；`const` 优先
- 颜色只用 `lib/theme.dart` 常量（kBlack/kWhite）或直接十六进制，黑底白字
- 平台差异代码走条件导出（新增平台能力时照 `chat_api` 模式建 stub/web/io 三件套）
- **会话状态只放 `LibrarySession`；页面不碰存储**。新增状态时先问"它属于会话还是视图"
- **新增消息类型必须用 `MessageKind`，不要再用字符串嗅探**。历史上靠匹配「书签」+「图书馆」来剔除回执，任何含这些词的真话都会被静默吞掉
- **单位/上限这类数字只写一处**：记忆 45 字、依据 60 字、记忆上限 32 条、未决之事上限 12 条，都定义在 `lib/config.dart` 或对应 model 里
- 纯逻辑优先放在不 import flutter 的支线文件里（`thread_book` / `memory_book` / `return_arc` / `reply_completer`），这样 `dart run` 就能测
- 需要 widget / ChangeNotifier 的测试放 `test/`，用 `flutter test`；**注入 `InMemoryStore`，不要碰真实数据目录**
- 大字文件（>800 行）优先拆分到 `lib/widgets/` 或 `lib/services/`
- 人设文件 `assets/prompts/ereta_persona.txt` 有备份版本，修改前先备份
- 测试：`tool/*_test.dart`（零依赖 `dart run`）+ `test/*_test.dart`（`flutter test`），新逻辑照此补充

### 指标闭环（改人设后怎么知道变好了）

`tool/archive_report.mjs` 把"感觉变好了"变成"数字变好了"。改动人设 / system prompt /
记忆策略后，导出一份真实存档再跑一遍，重点看：

| 指标 | 期望 | 2026-09-12 基线 |
|---|---|---|
| 环境语/回执混入对话流 | 0 条 | 55 条 |
| 结尾无标点（被截断） | 0 条 | 4/101 |
| 含转折 / 保留意见 | ≥25% | 10% |
| 以附和词开头 | ≤15% | 35% |
| 称呼混用 | 0 条 | 1 条（且整体漂移） |
| 书签占记忆比例 | 有自己的书架后应下降 | 67%（14/21） |

---

## 六、当前已知问题 / 注意

1. `beyond_time_page.dart` 已从 1021 行降到 ~615 行，剩余部分基本是纯布局（两套布局 + 标题绘制）。会话逻辑若再增长，请放进 `LibrarySession` 而不是页面
2. **记忆相关性检索与书签注入配额仍未做**（见第二节待办）。书架只解决了"归宿"，没解决"注入预算"
3. 桌面版定位是"附带产物"，主要形态建议走 Web/PWA
4. `assets/sounds/` 的 OGG 来自 GitHub Muges/ambientsounds（CC0/CC BY），fireplace 与 wind 听感曾相似，已换为当前版本
5. 中文字体是**子集化**的：改动标题/诗句文字后必须重跑 `node scripts/subset-fonts.js`，否则新字缺失会 fallback 到系统字体
6. `release/web` 每次打包会覆盖；手改 `release/web` 无效，改 `build/web` 来源
7. 本地构建**不要**带 `--base-href`（会覆盖本地产物为 GitHub Pages 路径）；GitHub Pages 的 base-href 由 CI 单独构建
8. 打包 exe 依赖 npm 包 `@yao-pkg/pkg` + `resedit`，若 `node_modules` 被清需先 `npm install`
9. 对话输入框当前为单行固定高度（58px）。曾尝试 `TextField maxLines: 4` 自动换行，但因外层 Column 给非弹性子项无限高度约束，Composer 被撑满整页，已回退；多行输入待另寻方案
10. `conversation_context.dart` 的 `cleanReply` 会删掉**所有**中英文括号内容与 `“”`。人设已要求不用括号动作描写，但这是把无差别手术刀——任何合法的括号信息（年份、英文原名）都会消失。若日后发现内容无故缺失，先查这里
11. 旧存档（v1）导入时会做一次精确匹配清洗：丢弃已知的 idle/离馆/回归台词、书签回执、API Key 提示，并折叠相邻完全相同的台词。只做精确匹配，不做模糊判断，以免误删她真的说过的话
12. 侧栏面板（设置/记忆/书架/存档）宽度固定 460/440；设置面板已改为「页眉固定 + 中段可滚动 + 底部按钮固定」，在 1280x600 这类矮窗口不会再溢出（有回归测试兜底）
13. `pubspec.yaml` 的 `dev_dependencies` 里有 `flutter_test`（SDK 自带，不是第三方依赖），README 的 "zero-dep" 徽章依然成立
