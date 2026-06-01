import https from "node:https";
import express from "express";

function requiredEnv(name) {
  const v = process.env[name];
  if (!v) throw new Error(`Missing required env var: ${name}`);
  return v;
}

const SPLUNK_HOST = process.env.SPLUNK_HOST || "so1";
const SPLUNK_PORT = process.env.SPLUNK_PORT || "8089";
const SPLUNK_REST_USER = process.env.SPLUNK_REST_USER || "admin";
const SPLUNK_PASSWORD = requiredEnv("SPLUNK_PASSWORD");
const SPLUNK_MCP_USER = process.env.SPLUNK_MCP_USER || "splunker";
const MCP_PROXY_PORT = Number(process.env.MCP_PROXY_PORT || "8090");

const tlsInsecure =
  String(process.env.SPLUNK_TLS_INSECURE || "").toLowerCase() === "1" ||
  String(process.env.SPLUNK_TLS_INSECURE || "").toLowerCase() === "true" ||
  String(process.env.SPLUNK_TLS_INSECURE || "").toLowerCase() === "yes";

const upstreamBase = `https://${SPLUNK_HOST}:${SPLUNK_PORT}`;
const upstreamMcpPath = "/services/mcp";
const tokenUrl = `${upstreamBase}/servicesNS/${encodeURIComponent(
  SPLUNK_REST_USER
)}/Splunk_MCP_Server/mcp_token?username=${encodeURIComponent(
  SPLUNK_MCP_USER
)}&output_mode=json`;

const httpsAgent = new https.Agent({ rejectUnauthorized: !tlsInsecure });

function httpsGet(url, { headers = {} } = {}) {
  return new Promise((resolve, reject) => {
    const u = new URL(url);
    const req = https.request(
      {
        protocol: u.protocol,
        hostname: u.hostname,
        port: u.port,
        path: `${u.pathname}${u.search}`,
        method: "GET",
        headers,
        agent: httpsAgent,
      },
      (res) => {
        let data = "";
        res.setEncoding("utf8");
        res.on("data", (chunk) => {
          data += chunk;
        });
        res.on("end", () => {
          resolve({ status: res.statusCode || 0, statusText: res.statusMessage || "", body: data });
        });
      }
    );
    req.on("error", reject);
    req.end();
  });
}

async function mintToken() {
  const basic = Buffer.from(`${SPLUNK_REST_USER}:${SPLUNK_PASSWORD}`).toString(
    "base64"
  );
  const res = await httpsGet(tokenUrl, {
    headers: {
      Authorization: `Basic ${basic}`,
      Accept: "application/json",
    },
  });
  const body = res.body;
  if (res.status < 200 || res.status >= 300) {
    throw new Error(
      `Token mint failed: HTTP ${res.status} ${res.statusText}: ${body.slice(
        0,
        300
      )}`
    );
  }
  let parsed;
  try {
    parsed = JSON.parse(body);
  } catch {
    throw new Error(`Token mint failed: non-JSON response: ${body.slice(0, 300)}`);
  }
  const token = parsed?.token;
  if (!token || typeof token !== "string") {
    throw new Error("Token mint failed: JSON response missing .token");
  }
  return token;
}

let bearerToken = "";
let minting = null;

async function ensureToken() {
  if (bearerToken) return bearerToken;
  if (!minting) {
    minting = mintToken()
      .then((t) => {
        bearerToken = t;
        return t;
      })
      .finally(() => {
        minting = null;
      });
  }
  return await minting;
}

function clearToken() {
  bearerToken = "";
}

async function forwardMcp(bodyText, token, req) {
  const upstreamUrl = `${upstreamBase}${upstreamMcpPath}`;
  return await new Promise((resolve, reject) => {
    const u = new URL(upstreamUrl);
    const r = https.request(
      {
        protocol: u.protocol,
        hostname: u.hostname,
        port: u.port,
        path: `${u.pathname}${u.search}`,
        method: "POST",
        headers: {
          Authorization: `Bearer ${token}`,
          "Content-Type": req.headers["content-type"] || "application/json",
          Accept: req.headers["accept"] || "application/json",
          "Cache-Control": "no-store",
          Pragma: "no-cache",
        },
        agent: httpsAgent,
      },
      (up) => {
        let data = "";
        up.setEncoding("utf8");
        up.on("data", (chunk) => (data += chunk));
        up.on("end", () =>
          resolve({
            status: up.statusCode || 0,
            contentType: up.headers["content-type"] || "application/json",
            body: data,
          })
        );
      }
    );
    r.on("error", reject);
    r.end(bodyText || "");
  });
}

const app = express();

// Some MCP HTTP clients probe OAuth endpoints by default. This proxy does not implement OAuth;
// return JSON (not HTML) so the client can safely fall back to non-OAuth modes.
app.get("/.well-known/oauth-authorization-server", (_req, res) => {
  res.status(404).json({ error: "oauth_not_supported" });
});
app.post("/register", (_req, res) => {
  res.status(404).json({ error: "oauth_not_supported" });
});

app.get("/healthz", async (_req, res) => {
  try {
    await ensureToken();
    res.status(200).json({ ok: true });
  } catch (e) {
    res.status(503).json({ ok: false, error: String(e?.message || e) });
  }
});

app.get("/debugz", async (_req, res) => {
  try {
    const t = await ensureToken();
    res.status(200).json({ ok: true, token_loaded: true, token_length: t.length });
  } catch (e) {
    res.status(503).json({ ok: false, token_loaded: false, error: String(e?.message || e) });
  }
});

app.get("/debugz/upstream-authz", async (_req, res) => {
  try {
    const t = await ensureToken();
    const upstreamRes = await httpsGet(`${upstreamBase}${upstreamMcpPath}`, {
      headers: { Authorization: `Bearer ${t}`, Accept: "application/json" },
    });
    res.status(200).json({ ok: true, status: upstreamRes.status });
  } catch (e) {
    res.status(503).json({ ok: false, error: String(e?.message || e) });
  }
});

app.post(
  "/mcp",
  express.text({ type: "*/*", limit: "2mb" }),
  async (req, res) => {
    const bodyText = req.body || "";

    // First attempt with cached (or newly minted) token.
    let t = await ensureToken();
    let upstreamRes = await forwardMcp(bodyText, t, req);

    // If token is stale/invalid, clear and retry once.
    if (upstreamRes.status === 401 || upstreamRes.status === 403) {
      clearToken();
      t = await ensureToken();
      upstreamRes = await forwardMcp(bodyText, t, req);
    }

    res
      .status(upstreamRes.status || 502)
      .set("Content-Type", String(upstreamRes.contentType))
      .set("Cache-Control", "no-store")
      .send(upstreamRes.body);
  }
);

app.all("/mcp", (_req, res) => {
  res.status(405).json({ message: "Method not allowed" });
});

app.use((err, _req, res, _next) => {
  res.status(500).json({ message: "internal error", error: String(err?.message || err) });
});

app.listen(MCP_PROXY_PORT, "0.0.0.0", () => {
  console.log(`mcp-proxy listening on :${MCP_PROXY_PORT}`);
  console.log(`upstream: ${upstreamBase}${upstreamMcpPath}`);
});

