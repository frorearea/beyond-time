const DEFAULT_API_URL = "https://api.deepseek.com/chat/completions";
const DEFAULT_SEARCH_URL = "https://api.deepseek.com/v1/tools/search";

export default {
  async fetch(request, env) {
    const url = new URL(request.url);

    if (request.method === "POST" && url.pathname === "/api/chat") {
      return handleChat(request);
    }

    if (request.method === "POST" && url.pathname === "/api/search") {
      return handleSearch(request);
    }

    if (request.method !== "GET" && request.method !== "HEAD") {
      return json({ error: "Method not allowed" }, 405);
    }

    if (!env.ASSETS) {
      return json({ error: "Static asset service is unavailable" }, 503);
    }

    const assetResponse = await env.ASSETS.fetch(request);
    if (assetResponse.status !== 404 || url.pathname.includes(".")) {
      return assetResponse;
    }

    const indexUrl = new URL("/index.html", request.url);
    return env.ASSETS.fetch(new Request(indexUrl, request));
  },
};

async function handleChat(request) {
  let body;
  try {
    body = await request.json();
  } catch {
    return json({ error: "Invalid JSON." }, 400);
  }

  const apiKey = typeof body.apiKey === "string" ? body.apiKey.trim() : "";
  const model = typeof body.model === "string" && body.model.trim()
    ? body.model.trim()
    : "deepseek-chat";
  const messages = Array.isArray(body.messages) ? body.messages : [];

  if (!apiKey) return json({ error: "API Key is required." }, 400);
  if (!messages.length) return json({ error: "Messages are required." }, 400);

  let apiUrl;
  try {
    apiUrl = new URL(body.apiUrl || DEFAULT_API_URL);
    if (apiUrl.protocol !== "https:") throw new Error();
  } catch {
    return json({ error: "API address must be a valid HTTPS URL." }, 400);
  }

  const upstream = await fetch(apiUrl, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Accept: body.stream ? "text/event-stream" : "application/json",
      Authorization: `Bearer ${apiKey}`,
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

  const headers = new Headers(upstream.headers);
  headers.set("Cache-Control", "no-store");
  headers.delete("Content-Length");
  return new Response(upstream.body, {
    status: upstream.status,
    statusText: upstream.statusText,
    headers,
  });
}

function json(payload, status) {
  return Response.json(payload, {
    status,
    headers: { "Cache-Control": "no-store" },
  });
}

// 网页搜索代理。只允许转发到 api.deepseek.com，否则这个公开 Worker 会变成开放代理。
async function handleSearch(request) {
  let body;
  try {
    body = await request.json();
  } catch {
    return json({ error: "Invalid JSON." }, 400);
  }

  const apiKey = typeof body.apiKey === "string" ? body.apiKey.trim() : "";
  const query = typeof body.query === "string" ? body.query.trim().slice(0, 128) : "";
  const count = Math.min(50, Math.max(1, Number(body.count) || 10));

  if (!apiKey) return json({ error: "API Key is required." }, 400);
  if (!query) return json({ error: "Query is required." }, 400);

  let searchUrl;
  try {
    searchUrl = new URL(body.searchUrl || DEFAULT_SEARCH_URL);
    if (searchUrl.protocol !== "https:" || searchUrl.hostname !== "api.deepseek.com") {
      throw new Error();
    }
  } catch {
    return json({ error: "Search address is not allowed." }, 400);
  }

  const upstream = await fetch(searchUrl, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Accept: "application/json",
      Authorization: `Bearer ${apiKey}`,
    },
    body: JSON.stringify({ query, count, need_content: false }),
  });

  const headers = new Headers({
    "Content-Type": "application/json; charset=utf-8",
    "Cache-Control": "no-store",
  });
  return new Response(upstream.body, {
    status: upstream.status,
    statusText: upstream.statusText,
    headers,
  });
}
