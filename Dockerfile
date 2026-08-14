# 时间之外 · Beyond Time — NAS Docker 镜像
# 运行时零 npm 依赖：node 内置 http/fs/path + 全局 fetch（Node 18+）。
# 方式：先本地 `flutter build web`，再把 build/web 打进镜像。
FROM node:20-alpine
WORKDIR /app

COPY package.json server.js ./
COPY build ./build

ENV PORT=4173
EXPOSE 4173

CMD ["node", "server.js"]