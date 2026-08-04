const childProcess = require("child_process");
const fs = require("fs");
const path = require("path");

const projectRoot = path.resolve(__dirname, "..");
const webRoot = path.join(projectRoot, "build", "web");
const fallbackWebRoot = path.join(projectRoot, "release", "web");
const releaseRoot = path.join(projectRoot, "release");
const bundlePath = path.join(releaseRoot, "windows-bundled-server.js");
const exePath = path.join(releaseRoot, "BeyondTime.exe");
const iconPath = path.join(projectRoot, "assets", "images", "app-icon.ico");

// Prefer the fresh Flutter build; fall back to the last packaged web copy.
const sourceWebRoot = fs.existsSync(path.join(webRoot, "index.html"))
  ? webRoot
  : fs.existsSync(path.join(fallbackWebRoot, "index.html"))
    ? fallbackWebRoot
    : null;

if (!sourceWebRoot) {
  throw new Error("build/web/index.html not found. Run flutter build web first.");
}

fs.mkdirSync(releaseRoot, { recursive: true });

// 1. Copy the web build next to the exe so the server can serve it from disk.
const webDest = path.join(releaseRoot, "web");
fs.rmSync(webDest, { recursive: true, force: true });
fs.cpSync(sourceWebRoot, webDest, { recursive: true });

// 2. Generate a small server bundle that serves ./web relative to the exe.
const source = `const childProcess = require("child_process");
const http = require("http");
const fs = require("fs");
const path = require("path");

const root = path.join(path.dirname(process.execPath), "web");
const preferredPort = Number(process.env.PORT || 4173);

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
  ".ogg": "audio/ogg",
  ".mp3": "audio/mpeg",
  ".ttf": "font/ttf",
  ".otf": "font/otf",
  ".bin": "application/octet-stream",
};

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
    response.write(": stream\\n\\n");

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
  let safePath = decodeURIComponent(pathname);
  while (safePath.startsWith("/")) {
    safePath = safePath.slice(1);
  }
  if (!safePath) safePath = "index.html";
  const filePath = path.normalize(path.join(root, safePath));

  if (filePath !== root && !filePath.startsWith(root + path.sep)) {
    sendJson(response, 403, { error: "Forbidden" });
    return;
  }

  if (!fs.existsSync(filePath) || !fs.statSync(filePath).isFile()) {
    if (!path.extname(safePath)) {
      sendFile(path.join(root, "index.html"), response);
      return;
    }
    sendJson(response, 404, { error: "Not found." });
    return;
  }

  sendFile(filePath, response);
}

function sendFile(filePath, response) {
  fs.readFile(filePath, (error, data) => {
    if (error) {
      sendJson(response, 404, { error: "Not found." });
      return;
    }
    const ext = path.extname(filePath);
    response.writeHead(200, {
      "Content-Type": mimeTypes[ext] || "application/octet-stream",
      "Cache-Control": "no-store, no-cache, must-revalidate, proxy-revalidate",
      Pragma: "no-cache",
      Expires: "0",
    });
    response.end(data);
  });
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

// 3. Package the small server into an exe using Node SEA via @yao-pkg/pkg,
//    then set the app icon via a pure-JS PE resource edit (resedit).
//    (rcedit hangs in some environments and classic pkg payloads get corrupted;
//     resedit rewrites the PE resource section without touching the SEA blob.)
const pkgBin = path.join(projectRoot, "node_modules", "@yao-pkg", "pkg", "lib-es5", "bin.js");
childProcess.execSync(
  `node "${pkgBin}" "${bundlePath}" --sea --targets node24-win-x64 --output "${exePath}"`,
  { cwd: projectRoot, stdio: "inherit", shell: "cmd.exe" },
);

if (fs.existsSync(iconPath) && fs.existsSync(path.join(projectRoot, "node_modules", "resedit"))) {
  try {
    childProcess.execSync(
      `node "${path.join(projectRoot, "scripts", "set-exe-icon.mjs")}" "${exePath}" "${iconPath}"`,
      { cwd: projectRoot, stdio: "inherit", shell: "cmd.exe", timeout: 60000 },
    );
  } catch (error) {
    console.warn("Skipped icon: resedit failed.", error.message);
  }
}

console.log(exePath);
