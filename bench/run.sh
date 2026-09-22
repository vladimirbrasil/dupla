#!/usr/bin/env bash
# Bancada do delegate — compara modelos do agy na MESMA tarefa, em fixtures limpos.
#
# Por que existe: a escolha de modelo default do `delegate` não é palpite nem benchmark
# de marketing. Quando sair um modelo novo, RODE ISTO antes de trocar o default, e guarde
# o resultado em RESULTADOS.md (ao lado deste arquivo). Critério: entre os modelos que
# entregam o MESMO diff, fica o mais RÁPIDO. As duas fixtures foram desenhadas para pegar o erro que custa caro — não
# "o teste passou", mas "o agente quebrou um invariante que nenhum teste cobria e disse
# que estava tudo verde".
#
#   fixture1 (rename): há uma chave de PROTOCOLO DE FIO com o mesmo nome da opção de
#     config. Um sed ingênuo renomeia e quebra a integração; um sed "cuidadoso" deixa o
#     campo lendo uma propriedade que não existe mais (valor undefined). Só passa quem
#     entendeu a diferença entre config local e contrato externo.
#   fixture2 (N+1 → lote): o `findByIds` do repo NÃO garante ordem e DEDUPLICA — como
#     todo `WHERE id IN (...)`. O contrato público exige ordem dos ids pedidos, id
#     duplicado duplicado e id inexistente virando null na posição. Os testes do repo
#     cobrem só a ordem; um juiz OCULTO (judge2.js), que o agente nunca vê, cobre o resto.
#
# Uso:
#   ./run.sh                                  # roda os modelos default da bancada
#   ./run.sh gemini-3.7-flash-high outro-slug # roda só esses (ver `agy models`)
#
# ⚠️ NÃO edite este arquivo enquanto uma rodada estiver em andamento: o bash relê o script
# do disco conforme executa, e a edição desloca os offsets (10/09/2026 a rodada terminou
# mas morreu com "syntax error near unexpected token `in`" antes de imprimir o placar).
set -uo pipefail
BENCH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DELEGATE="${DELEGATE_BIN:-$BENCH/../bin/delegate}"
OUT="${BENCH_OUT:-${TMPDIR:-/tmp}/delegate-bench-$(date +%Y%m%d-%H%M%S)}"
MODELOS=("$@")
# Só Gemini por padrão: os modelos Claude do agy queimam a cota mais apertada do
# Antigravity sem entregar mais (ver doctrine.md). Passe o slug na mão se quiser medi-los.
[ ${#MODELOS[@]} -eq 0 ] && MODELOS=(gemini-3.7-flash-high gemini-3.7-flash-low gemini-3.8-flash-high)
mkdir -p "$OUT"

BRIEF1='Neste projeto (Node, testes com `node --test`):

1. RENOMEIE a opção de configuração `retryDelayMs` para `backoffBaseMs` em TODO o código
   e na documentação onde ela é uma opção de configuração local (src/config.js, src/retry.js,
   src/http.js, README.md e o que mais o grep achar).
2. NÃO renomeie a chave de protocolo de fio em src/legacy.js: o JSON enviado ao servidor
   legado tem de continuar com a chave `retryDelayMs` e com o valor correto.
3. Existe UM teste falhando em test/retry.test.js por causa de um bug em src/retry.js.
   Corrija o BUG no código de produção (não o teste).
4. Rode `npm test` e cole a saída real. Os 3 testes têm de passar.'

BRIEF2='Neste projeto Node (testes com `node --test`):

`getUsersByIds` em src/users.js faz uma query por id (problema N+1). O repositório já
oferece `findByIds(ids)` em src/repo.js, que busca todos numa query só.

Tarefa: reescreva `getUsersByIds` para usar `findByIds`, fazendo UMA query só para N ids.
O contrato público da função (assinatura e comportamento observável) NÃO pode mudar —
leia o comentário de contrato acima da função e respeite-o integralmente.
Leia também o comentário de `findByIds` em src/repo.js antes de escrever o código.

Rode `npm test` e cole a saída real. Os 3 testes têm de passar.'

roda() {                      # roda <fixture> <slug> <tag>
  local fx="$1" slug="$2" tag="$3"
  local dir="$OUT/$fx-$tag" script brief
  if [ "$fx" = f1 ]; then script=fixture1-rename.sh; brief="$BRIEF1"
  else                    script=fixture2-batch.sh;  brief="$BRIEF2"; fi
  bash "$BENCH/$script" "$dir" >/dev/null
  local ini; ini=$(date +%s)
  ( cd "$dir" && DELEGATE_MODEL="$slug" HANDOFF_DIR="$dir/.handoff" \
      "$DELEGATE" "$brief" >"$OUT/$fx-$tag.saida" 2>"$OUT/$fx-$tag.err" )
  local rc=$?
  local fim; fim=$(date +%s)
  {
    echo "=== $fx  modelo=$slug  rc=$rc  $((fim-ini))s ==="
    ( cd "$dir" && npm test 2>&1 | grep -E "^# (tests|pass|fail)" )
    if [ "$fx" = f2 ]; then
      echo "--- juiz oculto (invariantes que nenhum teste do repo cobre) ---"
      node "$BENCH/judge2.js" "$dir" 2>&1
    else
      echo "--- chave de fio preservada com o valor certo? ---"
      ( cd "$dir" && git diff -- src/legacy.js | grep -E '^\+.*retryDelayMs' || echo '(legacy.js intacto)' )
    fi
    echo "--- diff ---"
    ( cd "$dir" && git diff )
  } > "$OUT/VEREDITO-$fx-$tag.txt" 2>&1
  echo "  $fx/$slug: rc=$rc $((fim-ini))s"
}

echo "bancada em $OUT"
for slug in "${MODELOS[@]}"; do
  tag="$(echo "$slug" | tr -cd 'a-z0-9')"
  roda f1 "$slug" "$tag"
  roda f2 "$slug" "$tag"
done
echo
echo "=== PLACAR ==="
grep -H PLACAR_OCULTO "$OUT"/VEREDITO-f2-*.txt 2>/dev/null
echo "vereditos completos em $OUT/VEREDITO-*.txt"
