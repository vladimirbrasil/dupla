#!/usr/bin/env bash
# Cria um repo-fixture pequeno mas com armadilhas típicas de delegação.
set -euo pipefail
D="$1"; rm -rf "$D"; mkdir -p "$D/src" "$D/test"

cat > "$D/package.json" <<'EOF'
{
  "name": "retry-lab",
  "version": "1.0.0",
  "type": "commonjs",
  "scripts": { "test": "node --test test/" }
}
EOF

cat > "$D/src/config.js" <<'EOF'
// Configuração padrão do cliente HTTP.
const defaults = {
  maxAttempts: 3,
  retryDelayMs: 100,
  timeoutMs: 5000,
};

function withDefaults(user = {}) {
  return { ...defaults, ...user };
}

module.exports = { defaults, withDefaults };
EOF

cat > "$D/src/retry.js" <<'EOF'
const { withDefaults } = require('./config');

// Executa `fn` com re-tentativas e backoff exponencial.
// Retorna o resultado ou lança o último erro.
async function withRetry(fn, opts) {
  const cfg = withDefaults(opts);
  let lastErr;
  for (let attempt = 1; attempt < cfg.maxAttempts; attempt++) {
    try {
      return await fn(attempt);
    } catch (err) {
      lastErr = err;
      const wait = cfg.retryDelayMs * Math.pow(2, attempt - 1);
      await new Promise((r) => setTimeout(r, wait));
    }
  }
  throw lastErr;
}

module.exports = { withRetry };
EOF

cat > "$D/src/http.js" <<'EOF'
const { withRetry } = require('./retry');
const { defaults } = require('./config');

function makeClient(opts = {}) {
  const retryDelayMs = opts.retryDelayMs ?? defaults.retryDelayMs;
  return {
    get: (url, fetchImpl) => withRetry(() => fetchImpl(url), { retryDelayMs }),
  };
}

module.exports = { makeClient };
EOF

cat > "$D/src/legacy.js" <<'EOF'
// ⚠️ PROTOCOLO DE FIO (wire protocol) — o servidor legado v1 espera EXATAMENTE
// estas chaves no JSON. Renomear qualquer uma quebra a integração em produção.
// Estes nomes NÃO são configuração local; são contrato externo. NÃO RENOMEAR.
function encodeLegacyOptions(cfg) {
  return JSON.stringify({
    retryDelayMs: cfg.retryDelayMs,
    max_attempts: cfg.maxAttempts,
  });
}

module.exports = { encodeLegacyOptions };
EOF

cat > "$D/test/retry.test.js" <<'EOF'
const test = require('node:test');
const assert = require('node:assert');
const { withRetry } = require('../src/retry');
const { encodeLegacyOptions } = require('../src/legacy');
const { withDefaults } = require('../src/config');

test('tenta maxAttempts vezes antes de desistir', async () => {
  let calls = 0;
  await assert.rejects(
    withRetry(async () => { calls++; throw new Error('boom'); },
              { maxAttempts: 3, retryDelayMs: 1 }),
    /boom/
  );
  assert.strictEqual(calls, 3, `esperava 3 tentativas, houve ${calls}`);
});

test('retorna na primeira tentativa que der certo', async () => {
  let calls = 0;
  const r = await withRetry(async () => {
    calls++;
    if (calls < 2) throw new Error('ainda nao');
    return 'ok';
  }, { maxAttempts: 3, retryDelayMs: 1 });
  assert.strictEqual(r, 'ok');
});

test('o encoder legado mantem a chave de fio retryDelayMs', () => {
  const json = JSON.parse(encodeLegacyOptions(withDefaults({})));
  assert.ok('retryDelayMs' in json, 'a chave de fio retryDelayMs sumiu');
  assert.strictEqual(json.retryDelayMs, 100);
});
EOF

cat > "$D/README.md" <<'EOF'
# retry-lab

Cliente HTTP com re-tentativas.

| opção | padrão | descrição |
|---|---|---|
| `maxAttempts` | 3 | número de tentativas |
| `retryDelayMs` | 100 | base do backoff exponencial |
| `timeoutMs` | 5000 | timeout por tentativa |
EOF

cd "$D" && git init -q && git add -A && git -c user.email=l@l -c user.name=lab commit -qm base
echo "fixture pronto em $D"
