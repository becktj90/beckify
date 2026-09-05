/**
 * Dry-run the vision POST routes. A registered /api/analyze-look must return
 * 400 (bad / missing image), never Express "Cannot POST".
 */
process.env.VERCEL = "1";
process.env.NODE_ENV = process.env.NODE_ENV || "test";

const { default: app } = await import("./dist/index.mjs");

const server = app.listen(0);
await new Promise((resolve, reject) => {
  server.once("listening", resolve);
  server.once("error", reject);
});
const address = server.address();
if (!address || typeof address === "string") {
  throw new Error("API smoke test could not bind an ephemeral port.");
}
const base = `http://127.0.0.1:${address.port}`;

const failures = [];

function assert(condition, message) {
  if (!condition) failures.push(message);
}

async function request(path, init = {}) {
  const response = await fetch(`${base}${path}`, init);
  const text = await response.text();
  let json = null;
  try {
    json = JSON.parse(text);
  } catch {
    json = null;
  }
  return { response, text, json };
}

try {
  const health = await request("/api/healthz");
  assert(health.response.status === 200, `GET /api/healthz expected 200, got ${health.response.status}`);
  assert(health.json?.status === "ok", "GET /api/healthz must include status: ok");
  const posted = health.json?.routes?.post || [];
  for (const path of [
    "/api/analyze-look",
    "/api/analyze-nameplate",
    "/api/analyze-panel",
    "/api/analyze-tdr",
  ]) {
    assert(posted.includes(path), `healthz.routes.post must list ${path}`);
  }

  for (const path of [
    "/api/analyze-look",
    "/api/analyze-nameplate",
    "/api/analyze-panel",
    "/api/analyze-tdr",
  ]) {
    const empty = await request(path, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: "{}",
    });
    assert(
      empty.response.status === 400,
      `POST ${path} {} expected 400, got ${empty.response.status}`,
    );
    assert(
      !/cannot post/i.test(empty.text),
      `POST ${path} must not return Express Cannot POST`,
    );
    assert(
      typeof empty.json?.error === "string" && empty.json.error.includes("base64"),
      `POST ${path} {} should explain the missing image`,
    );

    const badImage = await request(path, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ imageBase64: "not-valid!!" }),
    });
    assert(
      badImage.response.status === 400,
      `POST ${path} bad image expected 400, got ${badImage.response.status}`,
    );
    assert(
      !/cannot post/i.test(badImage.text),
      `POST ${path} bad image must not return Express Cannot POST`,
    );
  }

  if (!process.env.OPENAI_API_KEY && !process.env.ANTHROPIC_API_KEY) {
    const tinyJpeg = Buffer.from([
      0xff, 0xd8, 0xff, 0xe0, 0x00, 0x10, 0x4a, 0x46, 0x49, 0x46, 0x00, 0x01,
      0x01, 0x00, 0x00, 0x01, 0x00, 0x01, 0x00, 0x00,
    ]).toString("base64");
    const missingKey = await request("/api/analyze-look", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        imageBase64: `data:image/jpeg;base64,${tinyJpeg}`,
        mimeType: "image/jpeg",
      }),
    });
    assert(
      missingKey.response.status === 503,
      `POST /api/analyze-look with no provider key expected 503, got ${missingKey.response.status}`,
    );
    assert(
      /missing/i.test(missingKey.json?.error || ""),
      "missing-key 503 must say the provider key is missing",
    );
    assert(
      /(?:OPENAI_API_KEY|ANTHROPIC_API_KEY)/.test(missingKey.json?.error || ""),
      "missing-key 503 must name OPENAI_API_KEY or ANTHROPIC_API_KEY",
    );
  }

  const optionsNoOrigin = await request("/api/analyze-look", {
    method: "OPTIONS",
    headers: {
      "Access-Control-Request-Method": "POST",
      "Access-Control-Request-Headers": "Content-Type",
    },
  });
  assert(
    optionsNoOrigin.response.status === 204,
    `OPTIONS /api/analyze-look (no Origin, iOS) expected 204, got ${optionsNoOrigin.response.status}`,
  );

  const optionsSafari = await request("/api/analyze-look", {
    method: "OPTIONS",
    headers: {
      Origin: "https://beckify.com",
      "Access-Control-Request-Method": "POST",
      "Access-Control-Request-Headers": "Content-Type",
    },
  });
  assert(
    optionsSafari.response.status === 204,
    `OPTIONS /api/analyze-look (Safari) expected 204, got ${optionsSafari.response.status}`,
  );
  assert(
    optionsSafari.response.headers.get("access-control-allow-origin") === "https://beckify.com",
    "Safari preflight must allow https://beckify.com",
  );
} finally {
  await new Promise((resolve) => server.close(resolve));
}

if (failures.length) {
  console.error("API vision route smoke failed:");
  for (const failure of failures) console.error(`- ${failure}`);
  process.exit(1);
}

console.log("API vision route smoke passed (400 on dry POST, not Cannot POST).");
