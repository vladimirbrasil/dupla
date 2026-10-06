#!/usr/bin/env bash
# install.sh — fia o mecanismo "dupla" (Claude ↔ Antigravity) nos locais GLOBAIS
# da máquina, para valer em TODOS os projetos. Idempotente e com backups.
#
# Backend = Antigravity CLI (`agy`), na assinatura Google AI Pro (sem API paga).
# Rode quantas vezes quiser, de dentro do clone:  bash install.sh
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_DST="$HOME/.local/bin"
CLAUDE_MD="$HOME/.claude/CLAUDE.md"
CLAUDE_JSON="$HOME/.claude.json"
GIT_IGNORE="${XDG_CONFIG_HOME:-$HOME/.config}/git/ignore"
STAMP="$(date +%Y%m%d-%H%M%S)"

say() { printf '  %s\n' "$*"; }

echo "==> dupla/install.sh"

# 1) Symlinks dos executáveis no PATH ----------------------------------------
mkdir -p "$BIN_DST"
chmod +x "$DIR/bin/delegate" "$DIR/bin/claude-loop"
for f in delegate claude-loop; do
  ln -sf "$DIR/bin/$f" "$BIN_DST/$f"
  say "symlink: $BIN_DST/$f -> $DIR/bin/$f"
done

# 2) (sem config do gemini) ---------------------------------------------------
# O agy não precisa de alias em arquivo: o delegate escolhe o modelo via
# --model <slug> direto na linha de comando (ver 'agy models').

# 3) Import da doutrina no CLAUDE.md global -----------------------------------
mkdir -p "$(dirname "$CLAUDE_MD")"
touch "$CLAUDE_MD"
IMPORT_LINE="@$DIR/claude/doctrine.md"
if ! grep -qF "$IMPORT_LINE" "$CLAUDE_MD"; then
  { echo ""; echo "# Delegação Claude→Antigravity (dupla) — auto-incluído"; echo "$IMPORT_LINE"; } >> "$CLAUDE_MD"
  say "import da doutrina adicionado em $CLAUDE_MD"
else
  say "import da doutrina já presente em $CLAUDE_MD"
fi

# 4) Registro do MCP server 'dupla' em ~/.claude.json -------------------------
if [ -f "$CLAUDE_JSON" ]; then
  cp "$CLAUDE_JSON" "$CLAUDE_JSON.bak-$STAMP" && say "backup: $CLAUDE_JSON.bak-$STAMP"
fi
NODE_BIN="$(command -v node || true)"
if [ -z "$NODE_BIN" ]; then
  say "AVISO: node não encontrado — pulei o registro do MCP (instale node e rode de novo)."
else
  python3 - "$CLAUDE_JSON" "$NODE_BIN" "$DIR/mcp/delegate-mcp.js" <<'PY'
import json, sys, os
dst, node, server = sys.argv[1], sys.argv[2], sys.argv[3]
cfg = {}
if os.path.exists(dst):
    try: cfg = json.load(open(dst))
    except Exception: cfg = {}
cfg.setdefault("mcpServers", {})
cfg["mcpServers"].pop("gemini-delegate", None)   # remove chave antiga (migração)
cfg["mcpServers"]["dupla"] = {"command": node, "args": [server]}
json.dump(cfg, open(dst, "w"), indent=2, ensure_ascii=False)
PY
  say "MCP 'dupla' registrado em $CLAUDE_JSON (chave antiga 'gemini-delegate' removida)"
fi

# 4.5) Hook PreCompact: avisa quando o contexto está quase cheio --------------
CLAUDE_SETTINGS="$HOME/.claude/settings.json"
if ! command -v notify-send >/dev/null 2>&1; then
  say "AVISO: notify-send ausente — pulei o hook PreCompact (instale libnotify-bin)."
else
  [ -f "$CLAUDE_SETTINGS" ] && cp "$CLAUDE_SETTINGS" "$CLAUDE_SETTINGS.bak-$STAMP"
  python3 - "$CLAUDE_SETTINGS" "$DIR/claude/settings-hook-snippet.json" <<'PY'
import json, sys, os
dst, snip = sys.argv[1], sys.argv[2]
cfg = {}
if os.path.exists(dst):
    try: cfg = json.load(open(dst))
    except Exception: cfg = {}
add = json.load(open(snip))
hooks = cfg.setdefault("hooks", {})
for event, entries in add.items():
    bucket = hooks.setdefault(event, [])
    for entry in entries:
        cmds = [h.get("command") for e in bucket for h in e.get("hooks", [])]
        new_cmds = [h.get("command") for h in entry.get("hooks", [])]
        if any(c in cmds for c in new_cmds):  # idempotente: já presente
            continue
        bucket.append(entry)
json.dump(cfg, open(dst, "w"), indent=2, ensure_ascii=False)
PY
  say "hook PreCompact garantido em $CLAUDE_SETTINGS"
fi

# 5) gitignore global: .handoff/ ---------------------------------------------
EXC="$(git config --global core.excludesfile || true)"
if [ -z "$EXC" ]; then
  EXC="$GIT_IGNORE"
  mkdir -p "$(dirname "$EXC")"; touch "$EXC"
  git config --global core.excludesfile "$EXC"
  say "core.excludesfile global definido: $EXC"
fi
if ! grep -qxF ".handoff/" "$EXC" 2>/dev/null; then
  echo ".handoff/" >> "$EXC"; say ".handoff/ adicionado ao gitignore global ($EXC)"
else
  say ".handoff/ já no gitignore global"
fi

# 6) Checagem do Antigravity CLI (agy) ----------------------------------------
echo "==> próximos passos"
if command -v agy >/dev/null 2>&1; then
  say "agy detectado: $(command -v agy)  ($(agy --version 2>/dev/null | head -1))"
  say "Se ainda não logou: rode 'agy' uma vez e entre com a conta Google AI Pro."
else
  say "FALTA instalar o Antigravity CLI:"
  say "  curl -fsSL https://antigravity.google/cli/install.sh | bash"
  say "Depois rode 'agy' uma vez e logue na conta Google AI Pro (sem API paga)."
fi
echo "==> pronto. Abra um Claude novo para carregar a doutrina e o MCP."
