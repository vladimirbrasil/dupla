# dupla — Claude (cérebro) ↔ Antigravity (operário)

Mecanismo **global** para o Claude Code delegar tarefas braçais/pesadas ao
**Antigravity CLI (`agy`)** — Flash, thinking LOW —, revisar o resultado e
seguir, **sem você servir de leva-e-traz**. Instala uma vez, vale em **todos**
os projetos.

> **Backend (2026-06-24): Antigravity CLI, não mais gemini-cli.** A Google cortou
> o gemini-cli dos tiers individual / Google AI Pro / Ultra em 18/06/2026
> ("migrate to Antigravity"; só Code Assist Enterprise + API key sobrevivem). O
> `agy` é o substituto oficial e **roda na assinatura Google AI Pro (sem API
> paga)**. Bônus: ao contrário do gemini-cli (one-shot), o `agy` é um **agente**
> — planeja, usa ferramentas de arquivo/shell, executa de verdade e itera.

## Princípio

- **Mecanismo** (este módulo) = scripts + MCP + doutrina. Mora aqui, instalado em
  locais globais da máquina.
- **Estado** = pasta `.handoff/` dentro de cada projeto (gitignored, efêmera,
  isolada por projeto). Nada de config por projeto.

## Instalação

```bash
curl -fsSL https://antigravity.google/cli/install.sh | bash   # instala o 'agy'
agy                                                            # logar 1x (Google AI Pro)
```

Depois, ligue a dupla ao Claude Code de **um** dos dois jeitos (não os dois — a ferramenta MCP
apareceria duas vezes):

**Como plugin** — não toca em nada fora do diretório de plugins do Claude Code, e
`claude plugin uninstall dupla@dupla` desfaz:

```bash
claude plugin marketplace add vladimirbrasil/dupla
claude plugin install dupla@dupla
```

O `delegate` e o `claude-loop` ficam no PATH da ferramenta Bash do Claude (não no do seu
shell), a ferramenta MCP é registrada (precisa de `node`) e as regras entram como skill quando
a tarefa parece delegável (~140 tokens por sessão até lá). Com o plugin, ponha `.handoff/` no
seu gitignore você mesmo.

**Com o `install.sh`** — as regras são importadas no `~/.claude/CLAUDE.md` (ficam no contexto
em toda sessão) e os comandos entram também no seu PATH:

```bash
git clone https://github.com/vladimirbrasil/dupla.git && bash dupla/install.sh   # idempotente
```

O `install.sh` fia, nos locais globais:
| Alvo | O quê |
|------|-------|
| `~/.local/bin/{delegate,claude-loop}` | symlinks (PATH) |
| `~/.claude/CLAUDE.md` | `@import` da doutrina de delegação |
| `~/.claude.json` → `mcpServers` | server `dupla` (tool `delegate`) |
| gitignore global | `.handoff/` |

(O `agy` não precisa de config em arquivo: o `delegate` escolhe o modelo via
`--model <slug>` (ver `agy models`; default `gemini-3.7-flash-high`) direto na linha de comando.)

## Uso

**Delegação pontual** (o Claude faz sozinho quando a doutrina manda, ou você):
```bash
delegate "refatore os componentes em src/ui/ para o novo hook useToast; resuma"
```
O agente trabalha no disco, devolve só um resumo; cru fica em `.handoff/`.

**Re-delegação barata** (corrigir sem re-briefar — continua a MESMA conversa):
```bash
delegate --redo "faltou tratar o caso X; corrija e rode os testes de novo"
```

**Tarefa longa multi-fase** (contexto limpo por fatia — o "clear+handoff" automático):
```bash
claude-loop --help      # leia antes: responde sem iniciar agente (idem `delegate --help`)
claude-loop --status    # já existe tarefa nesta pasta?
claude-loop "migrar todo o projeto de CommonJS para ESM, fase a fase"
claude-loop             # retoma o .handoff/state.md existente

# Tarefa NOVA com um state.md antigo na pasta: dê a ela uma pasta própria. Passar objetivo
# com state.md existente é recusado (exit 2) — o loop não troca de tarefa em silêncio.
HANDOFF_DIR=.handoff/esm claude-loop "migrar para ESM"

# Rodar numa OUTRA CONTA Claude (ex.: a conta "Fable"), e/ou com outro modelo:
CLAUDE_CONFIG_DIR="$HOME/.claude-fable" CLAUDE_MODEL=opus claude-loop "objetivo"
#   ⚠️ o alias `claude-fable` do .bashrc NÃO funciona aqui: alias só existe em shell
#      interativo. O que troca a conta é a variável CLAUDE_CONFIG_DIR (a credencial, o
#      settings.json, os MCPs e o CLAUDE.md global vivem todos nessa pasta).
#   ⚠️ CLAUDE_MODEL evita a pegadinha de a conta estar em `"model": "haiku"` no
#      settings.json e o loop inteiro rodar num modelo fraco sem ninguém perceber.
```
Cada volta é um `claude -p` novo lendo `.handoff/state.md`. Para no
`TAREFA_COMPLETA` ou quando o Claude escreve `PRECISA_HUMANO: ...`.

**Via MCP**: dentro do Claude, a tool `delegate(task)` (server `dupla`) aparece
como ferramenta nativa — o contrato "resumo enxuto" fica garantido no servidor.

## Tudo é auto-aprovado

- `delegate` → `agy --print --dangerously-skip-permissions --add-dir "$PWD"`
- `claude-loop` → `claude --dangerously-skip-permissions`

Única interação manual: o **login inicial** do `agy` (OAuth, uma vez).

> `--add-dir "$PWD"` é obrigatório: sem ele o `agy` roda num sandbox próprio e
> editaria arquivos no scratch dele, não no seu projeto. O `delegate` já passa.

## Nível de raciocínio

`delegate` escolhe o thinking do Flash por tipo de tarefa:
```bash
delegate "<tarefa>"                             # 3.7 Flash HIGH (default)
delegate --think med  "<refac c/ julgamento>"   # MEDIUM (escopo, casos-limite)
delegate --think high "<arquitetural>"          # HIGH
```
O `delegate` injeta a **doutrina de casa** (aterrar na realidade, script
determinístico idempotente, cirúrgico, pular-e-reportar, **verificar RODANDO**
testes/build + `git diff`) — mas agora o `agy` *executa de verdade* esses passos
(roda comandos, observa, itera), não simula. Mesmo assim: **revise o diff real**,
o resumo do Flash mente bem. Limites que o `delegate` NÃO cobre: verificação
visual (roda headless, não enxerga render) e julgamento de design — use você.

## Overrides

- `DELEGATE_MODEL` (default `gemini-3.7-flash-high`) — ignorado se usar `--think`
- `DELEGATE_TIMEOUT` (default `30m`) — timeout do print mode do `agy`
- `HANDOFF_DIR` (default `.handoff`)
- `MAX_ITERS` (default `20`) — teto do `claude-loop`

A lista completa (com o valor em uso) e os códigos de saída estão em `claude-loop --help` e
`delegate --help`. Nos dois, argumento desconhecido começando com `-` é erro (exit 2), nunca
tarefa; `--` libera um objetivo/briefing que começa com hífen. **Exit 0 não quer dizer
"pronto"**: olhe o topo do `state.md` (loop) ou o `git diff` (delegate).

Testes do parse de argumentos (bash puro, com dublê no lugar do `claude`/`agy`):
`bin/claude-loop.test.sh && bin/delegate.test.sh`.
