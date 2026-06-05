const childProcess = require("child_process");
const fs = require("fs");
const path = require("path");

const projectRoot = path.resolve(__dirname, "..");
const webRoot = path.join(projectRoot, "build", "web");
const releaseRoot = path.join(projectRoot, "release");
const bundlePath = path.join(releaseRoot, "windows-bundled-server.js");
const exePath = path.join(releaseRoot, "BeyondTime.exe");

const mimeTypes = {
  ".html": "text/html; charset=utf-8",
  ".css": "text/css; charset=utf-8",
  ".js": "application/javascript; charset=utf-8",
  ".json": "application/json; charset=utf-8",
  ".wasm": "application/wasm",
  ".svg": "image/svg+xml",
  ".ico": "image/x-icon",
  ".jpg": "image/jpeg",
  ".jpeg": "image/jpeg",
  ".png": "image/png",
  ".ttf": "font/ttf",
  ".otf": "font/otf",
};

if (!fs.existsSync(path.join(webRoot, "index.html"))) {
  throw new Error("build/web/index.html not found. Run flutter build web first.");
}

fs.mkdirSync(releaseRoot, { recursive: true });

const assets = {};
for (const filePath of walk(webRoot)) {
  const relativePath = toWebPath(path.relative(webRoot, filePath));
  const ext = path.extname(filePath);
  assets[relativePath] = {
    mime: mimeTypes[ext] || "application/octet-stream",
    data: fs.readFileSync(filePath).toString("base64"),
  };
}

const source = `const childProcess = require("child_process");
const http = require("http");

const ASSETS = ${JSON.stringify(assets)};
const preferredPort = Number(process.env.PORT || 4173);

const server = http.createServer(async (request, response) => {
  try {
    const url = new URL(request.url, \`http://\${request.headers.host}\`);

    if (request.method === "POST" && url.pathname === "/api/chat") {
      await handleChat(request, response);
      return;
    }

    if (request.method !== "GET") {
      sendJson(response, 405, { error: "Method not allowed." });
      return;
    }

    serveAsset(url.pathname, response);
  } catch (error) {
    sendJson(response, 500, { error: error.message });
  }
});

listenOnAvailablePort(preferredPort);

function listenOnAvailablePort(port) {
  server.once("error", (error) => {
    if (error.code === "EADDRINUSE" && port < preferredPort + 20) {
      listenOnAvailablePort(port + 1);
      return;
    }
    console.error(error);
    process.exitCode = 1;
  });

  server.listen(port, "127.0.0.1", () => {
    const url = \`http://localhost:\${port}\`;
    console.log(\`Beyond Time is awake: \${url}\`);
    openBrowser(url);
  });
}

function openBrowser(url) {
  childProcess.spawn("cmd", ["/c", "start", "", url], {
    detached: true,
    stdio: "ignore",
    windowsHide: true,
  }).unref();
}

async function handleChat(request, response) {
  const body = await readJson(request);
  const apiUrl = body.apiUrl || "https://api.deepseek.com/chat/completions";
  const apiKey = body.apiKey || process.env.DEEPSEEK_API_KEY || "";
  const model = body.model || "deepseek-chat";
  const messages = Array.isArray(body.messages) ? body.messages : [];

  if (!apiKey) {
    sendJson(response, 400, { error: "API Key is required." });
    return;
  }

  if (!messages.length) {
    sendJson(response, 400, { error: "Messages are required." });
    return;
  }

  const upstream = await fetch(apiUrl, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Accept: body.stream ? "text/event-stream" : "application/json",
      Authorization: \`Bearer \${apiKey}\`,
    },
    body: JSON.stringify({
      model,
      messages,
      temperature: body.temperature ?? 0.86,
      max_tokens: body.max_tokens ?? 4096,
      stream: Boolean(body.stream),
      stream_options: body.stream_options,
      thinking: body.thinking,
    }),
  });

  if (body.stream) {
    response.socket?.setNoDelay(true);
    response.writeHead(upstream.status, {
      "Content-Type": upstream.headers.get("content-type") || "text/event-stream; charset=utf-8",
      "Cache-Control": "no-cache",
      Connection: "keep-alive",
      "X-Accel-Buffering": "no",
    });
    response.flushHeaders?.();
    response.write(": stream\\\\n\\\\n");

    if (!upstream.body) {
      response.end();
      return;
    }

    const reader = upstream.body.getReader();
    while (true) {
      const { value, done } = await reader.read();
      if (done) break;
      response.write(Buffer.from(value));
    }
    response.end();
    return;
  }

  const text = await upstream.text();
  response.writeHead(upstream.status, {
    "Content-Type": upstream.headers.get("content-type") || "application/json; charset=utf-8",
  });
  response.end(text);
}

function serveAsset(pathname, response) {
  let assetPath = decodeURIComponent(pathname);
  while (assetPath.startsWith("/")) {
    assetPath = assetPath.slice(1);
  }
  if (!assetPath) assetPath = "index.html";
  const asset = ASSETS[assetPath] || (!assetPath.includes(".") ? ASSETS["index.html"] : null);

  if (!asset) {
    sendJson(response, 404, { error: "Not found." });
    return;
  }

  response.writeHead(200, {
    "Content-Type": asset.mime,
    "Cache-Control": "no-store, no-cache, must-revalidate, proxy-revalidate",
    Pragma: "no-cache",
    Expires: "0",
  });
  response.end(Buffer.from(asset.data, "base64"));
}

function readJson(request) {
  return new Promise((resolve, reject) => {
    let raw = "";
    request.on("data", (chunk) => {
      raw += chunk;
      if (raw.length > 1_000_000) {
        request.destroy();
        reject(new Error("Request body is too large."));
      }
    });
    request.on("end", () => {
      try {
        resolve(raw ? JSON.parse(raw) : {});
      } catch {
        reject(new Error("Invalid JSON."));
      }
    });
    request.on("error", reject);
  });
}

function sendJson(response, statusCode, payload) {
  response.writeHead(statusCode, {
    "Content-Type": "application/json; charset=utf-8",
  });
  response.end(JSON.stringify(payload));
}
`;

fs.writeFileSync(bundlePath, source, "utf8");

childProcess.execSync(
  `npx --yes pkg@5.8.1 "${bundlePath}" --targets node18-win-x64 --output "${exePath}"`,
  { cwd: projectRoot, stdio: "inherit", shell: "cmd.exe" },
);

console.log(exePath);

function walk(dir) {
  const results = [];
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    const entryPath = path.join(dir, entry.name);
    if (entry.isDirectory()) {
      results.push(...walk(entryPath));
    } else if (entry.isFile()) {
      results.push(entryPath);
    }
  }
  return results;
}

function toWebPath(value) {
  return value.split(path.sep).join("/");
}
