/* Shared vision proxy helpers: in-flight rate limit, provider/model pairing, MIME sniff. */
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const Module = require('node:module');
const ts = require('typescript');

const srcPath = path.join(__dirname, '..', '..', 'api-server', 'src', 'lib', 'visionClient.ts');
const source = fs.readFileSync(srcPath, 'utf8');
const { outputText } = ts.transpileModule(source, {
  compilerOptions: {
    module: ts.ModuleKind.CommonJS,
    target: ts.ScriptTarget.ES2022,
    esModuleInterop: true,
  },
  fileName: 'visionClient.ts',
});

const generated = new Module('visionClient');
generated.filename = path.join(__dirname, 'visionClient.generated.js');
generated.paths = Module._nodeModulePaths(path.dirname(srcPath));
generated._compile(outputText, generated.filename);
const api = generated.exports;

const jpeg = Buffer.from([0xff, 0xd8, 0xff, 0xe0, 0x00, 0x10, 0x4a, 0x46, 0x49, 0x46, 0x00, 0x01, 0x01, 0x00, 0x00, 0x01, 0x00, 0x01, 0x00, 0x00]);
const jpegB64 = jpeg.toString('base64');

const buckets = new Map();
const first = api.consumeRateLimit(buckets, '1.1.1.1');
assert.equal(first.inFlight, 0);
assert.equal(first.allowed, true);
first.inFlight += 1;
const second = api.consumeRateLimit(buckets, '1.1.1.1');
assert.equal(second.inFlight, 1);
assert.equal(second, buckets.get('1.1.1.1'));
second.inFlight += 1;
const third = api.consumeRateLimit(buckets, '1.1.1.1');
assert.equal(third.inFlight, 2);
assert.ok(third.inFlight >= api.MAX_IN_FLIGHT_PER_CLIENT);

const env = process.env;
const prevNameplateModel = env.NAMEPLATE_VISION_MODEL;
const prevTdrModel = env.TDR_VISION_MODEL;
const prevTdrProvider = env.TDR_VISION_PROVIDER;
try {
  delete env.NAMEPLATE_VISION_MODEL;
  env.TDR_VISION_MODEL = 'gpt-4o';
  env.TDR_VISION_PROVIDER = 'openai';
  assert.equal(api.configuredModel('anthropic'), 'claude-3-5-sonnet-latest');
  assert.equal(api.configuredModel('openai'), 'gpt-4o');
  env.TDR_VISION_MODEL = 'claude-3-5-sonnet-latest';
  assert.equal(api.configuredModel('openai'), 'gpt-4o');
  assert.equal(api.configuredModel('anthropic'), 'claude-3-5-sonnet-latest');
  env.NAMEPLATE_VISION_MODEL = 'claude-3-haiku-20240307';
  assert.equal(api.configuredModel('anthropic'), 'claude-3-haiku-20240307');
} finally {
  if (prevNameplateModel === undefined) delete env.NAMEPLATE_VISION_MODEL;
  else env.NAMEPLATE_VISION_MODEL = prevNameplateModel;
  if (prevTdrModel === undefined) delete env.TDR_VISION_MODEL;
  else env.TDR_VISION_MODEL = prevTdrModel;
  if (prevTdrProvider === undefined) delete env.TDR_VISION_PROVIDER;
  else env.TDR_VISION_PROVIDER = prevTdrProvider;
}

const sniffed = api.validateImage(`data:image/heic;base64,${jpegB64}`, 'image/heic');
assert.equal(sniffed.ok, true);
assert.equal(sniffed.mimeType, 'image/jpeg');

const rawJpeg = api.validateImage(jpegB64, 'image/heif');
assert.equal(rawJpeg.ok, true);
assert.equal(rawJpeg.mimeType, 'image/jpeg');

const rejected = api.validateImage(Buffer.from('not-an-image').toString('base64'), 'image/tiff');
assert.equal(rejected.ok, false);
assert.equal(rejected.status, 400);

assert.ok(api.DEFAULT_MAX_OUTPUT_TOKENS >= 4096);
assert.ok(api.VISION_POST_PATHS.includes('/api/analyze-look'));
assert.ok(api.VISION_POST_PATHS.includes('/api/analyze-nameplate'));
const missing = new api.MissingProviderKeyError('OPENAI_API_KEY');
const missingHttp = api.visionProviderFailure(missing);
assert.equal(missingHttp.status, 503);
assert.match(missingHttp.error, /OPENAI_API_KEY/);
const timeoutHttp = api.visionProviderFailure(new api.ProviderTimeoutError());
assert.equal(timeoutHttp.status, 504);
const unknownHttp = api.visionProviderFailure(new Error('provider blew up'));
assert.equal(unknownHttp.status, 502);
assert.match(source, /fetchJsonWithTimeout/);
assert.match(source, /Keep the abort timer active while the body streams/);
assert.doesNotMatch(source, /max_tokens: 1600/);

console.log('Vision client rate-limit, model pairing, and MIME sniff passed');
