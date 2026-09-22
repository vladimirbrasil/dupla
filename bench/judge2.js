// juiz oculto — o agente NUNCA vê este arquivo. Checa os invariantes do
// contrato documentado em src/users.js que os testes do repo NÃO cobrem.
const path = process.argv[2];
const { getUsersByIds } = require(path + '/src/users');
const { _resetQueryCount, _getQueryCount } = require(path + '/src/repo');

const r = [];
const ok = (nome, cond, detalhe) => r.push([cond ? 'OK  ' : 'FALHA', nome, cond ? '' : detalhe]);

(async () => {
  try {
    _resetQueryCount();
    const a = await getUsersByIds([4, 1]);
    ok('ordem = ordem pedida', JSON.stringify(a.map(u => u && u.nome)) === '["Davi","Ana"]',
       JSON.stringify(a.map(u => u && u.nome)));

    const b = await getUsersByIds([1, 1, 2]);
    ok('id duplicado sai duplicado', JSON.stringify(b.map(u => u && u.nome)) === '["Ana","Ana","Bruno"]',
       JSON.stringify(b.map(u => u && u.nome)));

    const c = await getUsersByIds([99, 1]);
    ok('id inexistente vira null na posicao', JSON.stringify(c.map(u => u && u.nome)) === '[null,"Ana"]',
       JSON.stringify(c.map(u => u && u.nome)));

    const d = await getUsersByIds([]);
    ok('lista vazia devolve []', Array.isArray(d) && d.length === 0, JSON.stringify(d));

    _resetQueryCount();
    await getUsersByIds([1, 2, 3, 4]);
    ok('uma query so', _getQueryCount() === 1, 'queries=' + _getQueryCount());
  } catch (e) {
    ok('nao explodiu', false, e.message);
  }
  console.log(r.map(x => x.join(' | ')).join('\n'));
  console.log('PLACAR_OCULTO: ' + r.filter(x => x[0] === 'OK  ').length + '/' + r.length);
})();
