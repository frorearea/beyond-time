# 时间之外 · Beyond Time — 项目主文档

> **本文件是项目唯一权威文档。** 每次修改代码前先读本文件；功能新增、删除、重命名、架构调整后必须同步更新本文件。
> 最后更新：2026-08-04

---

## 一、项目主旨（改功能前先对齐这个）

**一句话定位：** 一个纯黑极简风格的「魔女图书馆避难所」——不是生产力工具、不是助手、不是知识库，而是一个让用户从「效率、比较、规训和他人凝视」中暂时撤退的情感空间。

**核心原则（决策依据）：**
- 每个新功能都必须回答「它如何加深避难所体验」，而不是「它是否酷」
- 艾蕾塔更像一个**在同个空间里独立存在的人**，而不是问答接口
- 明确不做：多角色切换、数据统计、社交分享、积分成就、多语言初期支持
- 技术气质：零外部依赖优先，纯黑纯白视觉，极简文字 UI

---

## 二、当前功能清单（2026-08-04 状态）

### 已完成
| 功能 | 说明 | 关键位置 |
|---|---|---|
| 流式对话 | DeepSeek API，打字机效果，thinking 开启 | `lib/services/chat_api_*.dart` |
| 心声快速选项 | 38 组轮换，进度持久化；可折叠（按钮在发送行「清空」右侧） | `lib/data/quick_options.dart`、`lib/widgets/quick_options.dart` |
| 图书馆记忆 | LLM 自动提炼（上限 32 条），书签手动收藏 | `lib/services/memory_capture_service.dart` |
| 塔罗占卜 | 记忆 ≥5 条解锁，三张牌 + 记忆结合解读 | `lib/services/tarot_reading_service.dart` |
| 存档/恢复 | 对话+记忆+心声进度 JSON 导入导出 | `lib/services/archive_service_*.dart` |
| 双布局 | classic（舞台）/ storybook（书卷），宽度 <640 自动降级 | `lib/pages/beyond_time_page.dart` |
| 用户个性化画像 | 话题/情绪/称呼/亲近度规则分析，注入 system prompt | `lib/models/user_profile.dart` |
| idle 微状态 | 无操作 3 分钟后艾蕾塔随机环境台词（可「离馆」暂停） | `lib/data/idle_lines.dart`、`_fireIdleLine` |
| 回归情感弧 | 3h/1d/1w/1m 四档回归台词（lastVisit 时间戳） | `lib/data/return_lines.dart`、`_checkReturnGreeting` |
| 环境音景 | 雨/炉火/风声（真实 OGG 录音），点击循环切换 | `lib/services/ambient_sound_web.dart` |
| 动态光影 | 魔女立像背后烛光呼吸动画 | `lib/widgets/candle_glow.dart` |
| 环境语隔离 | idle/离馆/回归台词标记 `isAmbient`：页面至多一条、不入存档 | `lib/models/chat_message.dart`、`_persistHistory` |
| 桌面版 | SEA 打包 exe，自动起服务+开浏览器 | `scripts/build-windows-bundle.js` |

### 待办/可探索方向（按优先级）
- 记忆相关性检索（目前是最近 12 条倒序注入，可升级为按话题打分取 Top-N）
- 主动回忆：对话中自然提及旧记忆，不标记来源
- 角色状态（她当前在做什么）+ 时间段感知（深夜语调更轻）
- 克制与边界：艾蕾塔偶尔不迎合（「你已经说了很久了。去睡吧。」）
- 响应前 0.5-1.5s 停顿，体现"她在想"

---

## 三、技术栈与架构

| 层 | 选型 |
|---|---|
| 前端 | Flutter Web（Dart ^3.6，CanvasKit），零第三方 pub 依赖 |
| 状态管理 | 纯 StatefulWidget + setState，无 BLoC/Riverpod |
| 平台 API | Web: `dart:html`（XHR + localStorage + AudioElement）；桌面: `dart:io` |
| 平台适配 | 条件导出模式：`xxx.dart` → `if (dart.library.html) xxx_web.dart` + stub |
| 服务器 | 零依赖 Node.js `server.js`（静态 + `/api/chat` 代理），端口 4173 |
| 桌面打包 | `@yao-pkg/pkg` SEA 模式 → BeyondTime.exe（资源外置 `release/web/`） |
| 部署 | Cloudflare Workers（`sites/worker.js`）+ 静态托管 |

### 目录结构
```
lib/
  main.dart / app.dart / config.dart / theme.dart
  data/          心声、idle 台词、回归台词
  models/        chat_message / library_archive / library_memory_item / tarot_card / user_profile
  pages/         beyond_time_page.dart（主页面，~1000 行，一切编排中心）
  services/      chat_api* / local_store* / archive_service* / ambient_sound*（条件导出组）
                 conversation_context / error_helper / store_helper / memory_capture / tarot_reading / bookmark
  widgets/       14 个独立组件（dialogue_box / storybook_frame / sound_control / candle_glow ...）
scripts/
  build-sites.mjs             Cloudflare 构建
  build-windows-bundle.js     exe 打包（SEA + resedit 图标）
  set-exe-icon.mjs            PE 图标替换（纯 JS，勿删）
  subset-fonts.js             中文字体子集化（改动标题/诗句文字后重跑）
  compress-portrait.js        魔女立像 WebP 压缩（sharp）
tool/profile_test.dart        用户画像单元测试（dart tool/profile_test.dart 运行）
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

# 用户画像单元测试
dart tool/profile_test.dart
```

**Flutter SDK 位置：** `C:\Users\FRORE\Desktop\Code\tools\flutter\bin`（不在 PATH，用 `start.bat` 或临时加 PATH）
**Node 位置：** `C:\Users\FRORE\Desktop\Code\tools\node-v24.18.0-win-x64`

### 桌面打包的技术细节（血泪教训，勿回退）
- **必须用 `@yao-pkg/pkg` 的 `--sea` 模式**（node24-win-x64），不能用 pkg 5.8.1 经典模式
- **图标用 `resedit`（纯 JS）替换**，见 `set-exe-icon.mjs`；原理：只重写 `.rsrc` 资源区，不碰 SEA blob
- **禁用 `rcedit`**：它重写整个文件会破坏 pkg/SEA 的 blob 指针 → "Pkg: Error reading from file"；且在某些环境会挂起
- **禁用 pkg `--icon` 参数**：pkg 5.8.1 无效，@yao-pkg 不支持
- 资源**外置**（`release/web/`），exe 内不嵌 web —— 内嵌 100MB 会让 pkg 产出损坏 exe
- 打包后 exe 的 `__dirname` 指向虚拟快照，**必须用 `path.dirname(process.execPath)`** 定位 web 目录
- 换图标流程：替换 `assets/images/app-icon.png` → 用 `png-to-ico` 转 `app-icon.ico` → `npm run release`

### 运行时行为
- API 配置存 localStorage（`beyondTimeFlutterSettings`）；`server.js` 本地代理 /api/chat
- 线上环境（GitHub Pages 等）仅 localhost 走 `/api/chat` 代理，其余直连 API；Cloudflare 域名（`.workers.dev`/`.pages.dev`）也走代理（见 `chat_api_web.dart` 的 hostname 判断）
- idle 定时器 3 分钟；「离馆」暂停 idle；用户发消息自动"回来"
- 环境语（idle/离馆/回归）标记 `isAmbient`：**页面同时至多一条，且不写入存档**
- 用户画像：消息 ≥3 条才注入；亲近度 = 天数/轮数四档
- 心声选项可折叠（Composer 行「清空」右侧小方块按钮）

### 部署（GitHub Pages）
- 已上线：`https://frorearea.github.io/beyond-time/`（2026-08-04）
- 部署方式：`.github/workflows/pages.yml`，push main 自动 `flutter build web --base-href=/beyond-time/` + 静态资源 gzip 预压缩 + deploy-pages
- 仓库 Settings → Pages → Source 需选 **GitHub Actions**
- 国内直连慢，需代理才能流畅加载
- 线上对话直连 DeepSeek 可能遇 CORS；待办：配 Cloudflare Worker 代理（已配置 wrangler.toml + workflow + secrets，**当前搁置**，等有域名再启用）

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
- 大字文件（>800 行）优先拆分到 `lib/widgets/` 或 `lib/services/`
- 人设文件 `assets/prompts/ereta_persona.txt` 有备份版本，修改前先备份
- 测试：`tool/profile_test.dart` 模式（零依赖直接 `dart run`），新逻辑照此补充

---

## 六、当前已知问题 / 注意

1. `beyond_time_page.dart` 已 ~1000 行，是唯一编排中心，改动小心回归
2. 桌面版定位是"附带产物"，主要形态建议走 Web/PWA
3. `assets/sounds/` 的 OGG 来自 GitHub Muges/ambientsounds（CC0/CC BY），fireplace 与 wind 听感曾相似，已换为当前版本
4. 中文字体是**子集化**的：改动标题/诗句文字后必须重跑 `node scripts/subset-fonts.js`，否则新字缺失会 fallback 到系统字体
5. `release/web` 每次打包会覆盖；手改 `release/web` 无效，改 `build/web` 来源
6. 本地构建**不要**带 `--base-href`（会覆盖本地产物为 GitHub Pages 路径）；GitHub Pages 的 base-href 由 CI 单独构建
7. 打包 exe 依赖 npm 包 `@yao-pkg/pkg` + `resedit`，若 `node_modules` 被清需先 `npm install`
