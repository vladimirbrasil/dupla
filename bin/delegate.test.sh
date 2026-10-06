#!/usr/bin/env bash
# Testes do parse de argumentos do delegate. Bash puro, sem instalar nada.
#
# O 'agy' é trocado por um dublê no PATH que só GRAVA com que argumentos foi chamado. O que
# estes testes provam é o lado negativo: pedir ajuda ou errar a flag NÃO manda tarefa ao agente.
#
# Uso: bin/delegate.test.sh [caminho-do-delegate]   (default: o do lado deste arquivo)
set -uo pipefail

AQUI="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ALVO="$(readlink -f "${1:-$AQUI/delegate}")"
RAIZ="$(mktemp -d)"
trap 'rm -rf "$RAIZ"' EXIT

mkdir "$RAIZ/bin"
cat >"$RAIZ/bin/agy" <<'EOF2'
#!/usr/bin/env bash
if [ "${1:-}" = "--version" ]; then echo "agy 9.9.9"; exit 0; fi
printf '%s\n' "$@" >>"$DUBLE_LOG"
# o agy às vezes sai com 0, sem resposta, e a causa só no stderr (503, login vencido)
if [ -n "${DUBLE_STDERR:-}" ]; then echo "$DUBLE_STDERR" >&2; exit 0; fi
echo "resumo do dublê"
EOF2
chmod +x "$RAIZ/bin/agy"

FALHAS=0
N=0
caso() {
  N=$((N + 1)); NOME="$1"
  DIR="$RAIZ/caso-$N"; mkdir -p "$DIR"; cd "$DIR"
  export DUBLE_LOG="$DIR.chamadas"
}
roda() {
  SAIDA="$(PATH="$RAIZ/bin:$PATH" bash "$ALVO" "$@" 2>&1 </dev/null)"
  RC=$?
}
falha() { FALHAS=$((FALHAS + 1)); echo "  ✗ $NOME: $1"; }
espera_rc() { [ "$RC" -eq "$1" ] || falha "exit $RC, esperado $1"; }
nao_chamou() { [ ! -e "$DUBLE_LOG" ] || falha "o dublê do agy FOI chamado com uma tarefa"; }
contem() { case "$SAIDA" in *"$1"*) ;; *) falha "saída não contém '$1'" ;; esac; }
pasta_vazia() { [ -z "$(ls -A "$DIR")" ] || falha "criou arquivo/pasta: $(ls -A "$DIR" | tr '\n' ' ')"; }
# recebeu <texto> — o prompt entregue ao agy começa com <texto>
recebeu() { grep -qx -- "$1" "$DUBLE_LOG" 2>/dev/null || falha "o agy não recebeu a tarefa '$1'"; }

for flag in --help -h; do
  caso "ajuda ($flag)"
  roda "$flag"
  espera_rc 0; contem "USO"; nao_chamou; pasta_vazia
done

for flag in --version --dry-run -v; do
  caso "flag desconhecida ($flag)"
  roda "$flag"
  espera_rc 2; nao_chamou; pasta_vazia
done

caso "flag desconhecida depois de flag válida"
roda --think low --versao
espera_rc 2; nao_chamou; pasta_vazia

caso "dois argumentos posicionais"
roda a b
espera_rc 2; nao_chamou; pasta_vazia

caso "sem briefing"
roda
espera_rc 2; nao_chamou

caso "briefing simples"
roda "renomeie foo para bar"
espera_rc 0; recebeu "renomeie foo para bar"; contem "resumo do dublê"

caso "-- permite briefing que começa com hífen"
roda -- "- item um"
espera_rc 0; recebeu "- item um"

caso "--think e --redo continuam valendo"
roda --think low --redo "corrija X"
espera_rc 0; recebeu "corrija X"; recebeu "--continue"; recebeu "gemini-3.7-flash-low"

caso "resposta vazia com exit 0: falha e mostra o stderr do agy"
DUBLE_STDERR="Error: Eligibility check failed: UNAVAILABLE (code 503)" roda "tarefa"
espera_rc 1; contem "DELEGATE_FAILED"; contem "UNAVAILABLE (code 503)"

echo
if [ "$FALHAS" -eq 0 ]; then
  echo "✓ $N casos, 0 falhas ($ALVO)"
else
  echo "✗ $N casos, $FALHAS verificações falharam ($ALVO)"
  exit 1
fi
