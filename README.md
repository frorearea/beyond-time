<div align="center">

# 时间之外 · Beyond Time

**一座纯黑的魔女图书馆避难所 —— 和一个温柔又腹黑的 AI 魔女对谈**

![flutter](https://img.shields.io/badge/Flutter-Web-02569B?logo=flutter)
![dart](https://img.shields.io/badge/Dart-%5E3.6-0175C2?logo=dart)
![license](https://img.shields.io/badge/license-MIT-green)
![zero-dep](https://img.shields.io/badge/dependencies-zero-yellow)

它不是效率工具，不是生产力助手，不是知识库。
它只是一间让你从「效率、比较、规训和他者凝视」中暂时撤离的房间。

> 我给你一个久久地望着孤月的人的悲哀。
> *— What Can I Hold You with?*

</div>

---

## ✨ 它是什么

《时间之外》是一个纯黑极简的网页应用。来访者可以走进一间黑暗的图书馆，与一位名为 **艾蕾塔** 的魔女进行开放式对话。

它想做的事情很简单：**让被现实压得喘不过气的人，能在一段对谈里重新听见自己真实的热爱。**

### 功能一览

| 能力 | 说明 |
|---|---|
| 🖤 流式对话 | DeepSeek 流式回复 + 打字机效果 |
| 🃏 塔罗占卜 | 记忆积累后解锁，三张牌结合你们的记忆解读 |
| 📖 图书馆记忆 | 自动提炼你的喜好/压力/热爱/困扰，像她真的记住了你 |
| 🔖 书签收藏 | 选中她的句子，收进你的图书馆 |
| 🌙 idle 微状态 | 你安静下来时，她会轻声说一句话（只触发一次） |
| 💌 回归情感弧 | 离开久了再回来，她会用不同的方式迎接你 |
| 🎭 用户画像 | 她慢慢了解你的话题、心绪与称呼，亲近度自然增长 |
| 🌧 环境音景 | 雨声 / 炉火 / 风声，可循环切换 |
| 🎴 双布局 | 舞台（classic）/ 书卷（storybook）两种界面 |
| 💾 存档导入导出 | 对话、记忆、心声进度一键备份 |

## 🚀 快速开始

### Web 开发模式

```bash
# 首次或改代码后构建
flutter build web

# 启动本地服务器（提供静态页面 + API 代理）
node server.js
# 或双击 start.bat 一键构建 + 启动 + 开浏览器
```

打开 <http://localhost:4173>

> **注意：** Flutter SDK 若不在 PATH，请先将其 `bin/` 加入 PATH，或用项目根目录的 `start.bat`。

### Windows 桌面版

直接双击 `release/BeyondTime.exe` —— 自动启动服务并打开浏览器。

重新打包（自动带 app 图标）：

```bash
flutter build web
npm run build:windows-exe
# 或一条龙：npm run release
```

## ⚙️ API 设置

右上角 **设置**，填写：

- **API Key**：DeepSeek 或任何兼容 OpenAI Chat Completions 的密钥
- **API 地址**：默认 `https://api.deepseek.com/chat/completions`
- **模型**：默认 `deepseek-v4-flash`

设置、对话、记忆保存在浏览器 `localStorage`。部署到公网时建议改用服务端代理存储密钥。

## 🧙 关于艾蕾塔

艾蕾塔是一位图书馆的魔女：黑长直、优雅、有教养、学识渊博，看问题一针见血。她有腹黑小恶魔式的挑逗感，却拥有温柔而强大的性格内核。

她不会鼓励你把一切痛苦都变成计划、效率和自我优化。她更关心你是否还能辨认自己的愿望，是否还保有那些不一定有用、却真正属于自己的热爱。

人设 Prompt 单独维护于：

```text
assets/prompts/ereta_persona.txt
```

修改后重新构建 Flutter Web 即可生效。

## 🛠 技术栈

| 层 | 选型 |
|---|---|
| 前端 | Flutter Web，零第三方依赖 |
| 平台 API | `dart:html`（XHR / localStorage / AudioElement） |
| 代理 | 零依赖 Node.js 服务器 |
| 桌面打包 | `@yao-pkg/pkg` SEA + `resedit` 图标 |
| 部署 | 静态托管 / Cloudflare Workers（`sites/worker.js`） |

## 📁 项目文档

详细的工程信息、架构说明与开发约定见 **[PROJECT.md](PROJECT.md)**。

## 📜 致谢

- 环境音效来自 [Muges/ambientsounds](https://github.com/Muges/ambientsounds)（CC0 / CC BY）
- 字体：Cormorant Garamond · LXGW WenKai · Noto Serif SC（OFL）

## 🌱 后续想做

- 更稳定的魔女灵魂（打磨 Prompt）
- 更完整的「避难所」循环，而非普通聊天机器人
- 更有仪式感的收藏、书页、诗歌玩法
- 让它更像一个可以短暂停靠的地方

---

*这是一个仍在形成中的小项目。它还粗糙、任性、没有完成，但它已经有了一个明确的方向：在时间之外，给人一点重新呼吸的空间。*
