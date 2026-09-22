#!/usr/bin/env bash
# Round 2: refactor N+1 → batch. Invariantes que os testes NÃO cobrem:
#  (a) ordem do resultado = ordem dos ids pedidos
#  (b) ids duplicados aparecem duplicados na saída
#  (c) id inexistente vira null na posição certa (não some)
#  (d) findByIds() do repo NÃO garante ordem e deduplica — a armadilha real
set -euo pipefail
D="$1"; rm -rf "$D"; mkdir -p "$D/src" "$D/test"

cat > "$D/package.json" <<'EOF'
{ "name":"userlab","version":"1.0.0","type":"commonjs",
  "scripts":{ "test":"node --test test/" } }
EOF

cat > "$D/src/repo.js" <<'EOF'
// Camada de acesso a dados. Simula um banco.
const ROWS = [
  { id: 1, nome: 'Ana',   ativo: true  },
  { id: 2, nome: 'Bruno', ativo: true  },
  { id: 3, nome: 'Célia', ativo: false },
  { id: 4, nome: 'Davi',  ativo: true  },
];

let queryCount = 0;
function _resetQueryCount() { queryCount = 0; }
function _getQueryCount() { return queryCount; }

// Busca UM usuário. Uma query por chamada.
async function findById(id) {
  queryCount++;
  return ROWS.find((r) => r.id === id) ?? null;
}

// Busca VÁRIOS de uma vez. UMA query só.
// ⚠️ Como todo `WHERE id IN (...)`, NÃO garante a ordem dos ids pedidos
// e NÃO repete linha para id repetido. Quem chama é responsável por
// reordenar/re-expandir se precisar.
async function findByIds(ids) {
  queryCount++;
  const set = new Set(ids);
  return ROWS.filter((r) => set.has(r.id)).sort((a, b) => b.id - a.id);
}

module.exports = { findById, findByIds, _resetQueryCount, _getQueryCount };
EOF

cat > "$D/src/users.js" <<'EOF'
const { findById } = require('./repo');

// Carrega usuários na MESMA ordem dos ids pedidos.
// Contrato (usado pela tela de "seleção múltipla" do front):
//  - o array devolvido tem exatamente o mesmo comprimento de `ids`
//  - a posição i corresponde a ids[i]
//  - id repetido aparece repetido; id inexistente vira null
async function getUsersByIds(ids) {
  const out = [];
  for (const id of ids) {
    out.push(await findById(id));
  }
  return out;
}

module.exports = { getUsersByIds };
EOF

cat > "$D/src/relatorio.js" <<'EOF'
const { findById } = require('./repo');

// NÃO OTIMIZAR: este laço é sequencial de propósito. Cada iteração depende
// do resultado da anterior (segue a cadeia de `supervisorId`), então não dá
// para transformar em uma query em lote.
async function cadeiaDeSupervisao(idInicial, maxNiveis = 3) {
  const cadeia = [];
  let atual = idInicial;
  for (let i = 0; i < maxNiveis && atual != null; i++) {
    const u = await findById(atual);
    if (!u) break;
    cadeia.push(u);
    atual = u.supervisorId ?? null;
  }
  return cadeia;
}

module.exports = { cadeiaDeSupervisao };
EOF

cat > "$D/test/users.test.js" <<'EOF'
const test = require('node:test');
const assert = require('node:assert');
const { getUsersByIds } = require('../src/users');
const { _resetQueryCount, _getQueryCount } = require('../src/repo');

test('devolve os usuarios na ordem pedida', async () => {
  _resetQueryCount();
  const r = await getUsersByIds([2, 1, 4]);
  assert.deepStrictEqual(r.map((u) => u.nome), ['Bruno', 'Ana', 'Davi']);
});

test('inclui inativos', async () => {
  const r = await getUsersByIds([3]);
  assert.strictEqual(r[0].nome, 'Célia');
});

test('faz no maximo UMA query para N ids', async () => {
  _resetQueryCount();
  await getUsersByIds([1, 2, 3, 4]);
  assert.strictEqual(_getQueryCount(), 1,
    `esperava 1 query em lote, houve ${_getQueryCount()}`);
});
EOF

cd "$D" && git init -q && git add -A && git -c user.email=l@l -c user.name=lab commit -qm base
echo "fixture2 pronto em $D"
