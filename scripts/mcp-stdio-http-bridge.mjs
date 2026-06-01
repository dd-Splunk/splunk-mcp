import readline from "node:readline";

const MCP_URL = process.env.MCP_URL || "http://localhost:8090/mcp";

async function postJson(body) {
  const res = await fetch(MCP_URL, {
    method: "POST",
    headers: {
      "content-type": "application/json",
      accept: "application/json",
      "cache-control": "no-store",
    },
    body: JSON.stringify(body),
  });
  const text = await res.text();
  if (!res.ok) {
    // Return a JSON-RPC shaped error when possible.
    const id = body && Object.prototype.hasOwnProperty.call(body, "id") ? body.id : null;
    return {
      jsonrpc: "2.0",
      id,
      error: {
        code: -32000,
        message: `HTTP ${res.status} from MCP proxy`,
        data: text.slice(0, 500),
      },
    };
  }
  try {
    return JSON.parse(text);
  } catch {
    const id = body && Object.prototype.hasOwnProperty.call(body, "id") ? body.id : null;
    return {
      jsonrpc: "2.0",
      id,
      error: { code: -32700, message: "Invalid JSON from MCP proxy", data: text.slice(0, 500) },
    };
  }
}

const rl = readline.createInterface({ input: process.stdin, crlfDelay: Infinity });

rl.on("line", async (line) => {
  const trimmed = line.trim();
  if (!trimmed) return;
  let msg;
  try {
    msg = JSON.parse(trimmed);
  } catch {
    process.stdout.write(
      JSON.stringify({
        jsonrpc: "2.0",
        id: null,
        error: { code: -32700, message: "Invalid JSON from client" },
      }) + "\n"
    );
    return;
  }

  const resp = await postJson(msg);
  process.stdout.write(JSON.stringify(resp) + "\n");
});

