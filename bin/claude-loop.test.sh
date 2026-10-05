#!/usr/bin/env bash
# Testes do parse de argumentos do claude-loop. Bash puro, sem instalar nada.
#
# O 'claude' é trocado por um dublê (CLAUDE_BIN) que só GRAVA que foi chamado. O que estes
# testes provam é o lado negativo: pedir ajuda ou errar a linha de comando NÃO inicia agente.
#
# Uso: bin/claude-loop.test.sh [caminho-do-claude-loop]   (default: o do lado deste arquivo)
set -uo pipefail

AQUI="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ALVO="$(readlink -f "${1:-$AQUI/claude-loop}")"
RAIZ="$(mktemp -d)"
trap 'rm -rf "$RAIZ"' EXIT

DUBLE="$RAIZ/claude-duble"
cat >"$DUBLE" <<'EOF'
#!/usr/bin/env bash
echo chamado >>"$DUBLE_LOG"
if [ -n "${DUBLE_COMPLETA:-}" ]; then
  f="${HANDOFF_DIR:-.handoff}/state.md"
  printf 'TAREFA_COMPLETA\n%s\n' "$(cat "$f")" >"$f"
fi
EOF
chmod +x "$DUBLE"

FALHAS=0
N=0
# caso <nome> — cria uma pasta vazia e entra nela
caso() {
  N=$((N + 1)); NOME="$1"
  DIR="$RAIZ/caso-$N"; mkdir -p "$DIR"; cd "$DIR"
  export DUBLE_LOG="$DIR.chamadas"
}
# roda <args...> — executa o alvo com o dublê; guarda RC e SAIDA (stdout+stderr)
roda() {
  SAIDA="$(CLAUDE_BIN="$DUBLE" MAX_ITERS="${MAX_ITERS:-1}" bash "$ALVO" "$@" 2>&1)"
  RC=$?
}
falha() { FALHAS=$((FALHAS + 1)); echo "  ✗ $NOME: $1"; }
espera_rc() { [ "$RC" -eq "$1" ] || falha "exit $RC, esperado $1"; }
nao_chamou() { [ ! -e "$DUBLE_LOG" ] || falha "o dublê do claude FOI chamado"; }
chamou() { [ -e "$DUBLE_LOG" ] || falha "o dublê do claude não foi chamado"; }
contem() { case "$SAIDA" in *"$1"*) ;; *) falha "saída não contém '$1'" ;; esac; }
pasta_vazia() { [ -z "$(ls -A "$DIR")" ] || falha "criou arquivo/pasta: $(ls -A "$DIR" | tr '\n' ' ')"; }

for flag in --help -h help; do
  caso "ajuda ($flag)"
  roda "$flag"
  espera_rc 0; contem "USO"; nao_chamou; pasta_vazia
done

caso "ajuda não retoma state.md existente"
mkdir .handoff; echo "# OBJETIVO antigo" >.handoff/state.md
roda --help
espera_rc 0; contem "USO"; nao_chamou

caso "flag desconhecida"
roda --versao
espera_rc 2; nao_chamou; pasta_vazia

caso "dois argumentos posicionais"
roda a b
espera_rc 2; nao_chamou; pasta_vazia

caso "-- permite objetivo que começa com hífen"
roda -- "-x"
chamou
grep -qx -- "-x" .handoff/state.md 2>/dev/null || falha "state.md não contém o objetivo '-x'"

caso "objetivo em pasta vazia"
roda "obj novo"
espera_rc 0; chamou
grep -qx "obj novo" .handoff/state.md 2>/dev/null || falha "state.md não contém o objetivo"

caso "objetivo novo com state.md existente é recusado"
mkdir .handoff; printf '# OBJETIVO\ntarefa antiga\n' >.handoff/state.md
roda "tarefa nova"
espera_rc 2; nao_chamou; contem "tarefa antiga"; contem "HANDOFF_DIR="
[ "$(cat .handoff/state.md)" = "$(printf '# OBJETIVO\ntarefa antiga')" ] || falha "state.md antigo foi alterado"

caso "sem argumento retoma state.md existente"
mkdir .handoff; printf '# OBJETIVO\ntarefa antiga\n' >.handoff/state.md
roda
espera_rc 0; chamou

caso "HANDOFF_DIR próprio não toca no .handoff antigo"
mkdir .handoff; printf '# OBJETIVO\ntarefa antiga\n' >.handoff/state.md
HANDOFF_DIR=.handoff/outra roda "tarefa nova"
espera_rc 0; chamou
grep -qx "tarefa nova" .handoff/outra/state.md 2>/dev/null || falha "não criou .handoff/outra/state.md"
grep -qx "tarefa antiga" .handoff/state.md || falha "state.md antigo foi alterado"

caso "sem objetivo e sem state.md"
roda
espera_rc 2; nao_chamou; pasta_vazia

caso "TAREFA_COMPLETA encerra em 1 volta"
MAX_ITERS=5 DUBLE_COMPLETA=1 roda "obj"
espera_rc 0; contem "TAREFA_COMPLETA em 1"
[ "$(wc -l <"$DUBLE_LOG" 2>/dev/null)" = 1 ] || falha "o dublê não rodou exatamente 1 vez"

caso "--status sem state.md"
roda --status
espera_rc 0; nao_chamou; pasta_vazia

caso "--status com state.md"
mkdir .handoff; printf 'PRECISA_HUMANO: qual banco?\n# OBJETIVO\ntarefa antiga\n' >.handoff/state.md
roda --status
espera_rc 0; nao_chamou; contem "qual banco?"

echo
if [ "$FALHAS" -eq 0 ]; then
  echo "✓ $N casos, 0 falhas ($ALVO)"
else
  echo "✗ $N casos, $FALHAS verificações falharam ($ALVO)"
  exit 1
fi
