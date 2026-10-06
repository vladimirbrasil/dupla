# dupla — one AI thinks, another one types

`dupla` ("pair" in Portuguese) lets [Claude Code](https://claude.com/claude-code) hand heavy,
mechanical work to a cheaper agent — Google's Antigravity CLI (`agy`, Gemini Flash) — and get
back **only a short summary**, while the full diff lands on disk for review.

The expensive model stays the brain and the reviewer. The cheap one does the typing.

```
Claude Code ── briefing ──▶ delegate ──▶ agy (Gemini Flash, auto mode)
     ▲                                        │ edits files, runs tests, iterates
     └──────── 10-line summary ◀──────────────┘ raw output → .handoff/
```

## Why

Every turn of a long agent session re-reads the whole context. A 2,000-line file opened at the
start is paid for again on every turn after it. Delegating the bulk work — and keeping the main
context small — saves more than any other token optimisation. Measured on a real project: a
six-slice session cost ~6% of a weekly Claude limit.

## What's inside

| Piece | What it does |
|---|---|
| `bin/delegate` | Runs `agy` in print mode on the current project with a built-in method (ground in reality, write a deterministic script instead of editing by eye, be surgical, skip what is ambiguous, **verify by running** tests and `git diff`). Returns a short summary. `--redo` continues the same conversation to fix a bad delivery without re-briefing. `--think low\|med\|high\|pro` picks reasoning effort. |
| `bin/claude-loop` | Long multi-phase tasks: each iteration is a fresh `claude -p` reading `.handoff/state.md`. Clean context per slice; stops on `TAREFA_COMPLETA` or when it writes `PRECISA_HUMANO: …` ("needs a human"). |
| `mcp/delegate-mcp.js` | Exposes `delegate` as a native MCP tool inside Claude Code, enforcing the short-summary contract server-side. |
| `claude/doctrine.md` | The rules Claude follows: when to delegate, how to brief, and why the diff is always reviewed line by line — "the summary lies by omission". |
| `bench/` | The benchmark that picks the default model. |
| `install.sh` | Idempotent wiring: PATH symlinks, the doctrine import in `~/.claude/CLAUDE.md`, the MCP server, a global gitignore for `.handoff/`. |
| `.claude-plugin/`, `skills/` | The same pieces packaged as a Claude Code plugin — an alternative to `install.sh` that touches no global file. |

## How the default model is chosen

Not by marketing benchmarks. `bench/run.sh` runs two **trap fixtures** against every candidate:

1. **Rename with an untouchable key** — a refactor where one identically-named key is part of a
   wire protocol and must *not* be renamed.
2. **N+1 → batch** — a performance refactor with five invariants that **no test in the repo
   covers**, checked by a hidden judge (`judge2.js`). Green tests are not enough to pass.

Among models that deliver the same diff, the fastest wins. The September 2026 run
(`bench/RESULTADOS.md`): Gemini 3.6, 3.7 and 3.8 Flash all passed with equivalent diffs; 3.7 did
it in ~100 s against 345–441 s for 3.8 — which, in one run, also left two stale calls in `test/`
that stayed green because a config default covered for them ("the green that hides").
Same capability, a quarter of the wall clock: 3.7 became the default.

## Install

```bash
curl -fsSL https://antigravity.google/cli/install.sh | bash   # installs agy
agy                                                            # log in once
```

Then wire dupla into Claude Code **one** of two ways (not both — you would get the MCP tool twice):

**As a plugin** — nothing outside Claude Code's plugin directory is touched, and
`claude plugin uninstall dupla@dupla` removes it:

```bash
claude plugin marketplace add vladimirbrasil/dupla
claude plugin install dupla@dupla
```

`delegate` and `claude-loop` are then on the PATH of Claude's Bash tool (not of your own
shell), the MCP tool is registered (needs `node`), and the rules load as a skill when a task
looks delegable (~140 tokens per session until then).

**With `install.sh`** — the rules are imported into `~/.claude/CLAUDE.md`, so they are in
context in every session, and the commands are on your own PATH too:

```bash
git clone https://github.com/vladimirbrasil/dupla.git && bash dupla/install.sh   # idempotent
```

It also adds `.handoff/` to your global gitignore and a desktop notification before
auto-compact. With the plugin, add `.handoff/` to your gitignore yourself.

Everything runs auto-approved (`agy --dangerously-skip-permissions`, `claude
--dangerously-skip-permissions`). Use it on repositories you trust, with git as your undo.

## Usage

```bash
delegate "migrate the components in src/ui/ to the new useToast hook; run the tests"
delegate --redo "you missed case X; fix it and run the tests again"
claude-loop "migrate the whole project from CommonJS to ESM, phase by phase"
```

Read `claude-loop --help` and `delegate --help` first: both answer without starting an agent,
and anything else that starts with `-` is rejected instead of being sent as the task (use `--`
for a task that really begins with a hyphen). Two things the help spells out:

- `claude-loop` with no argument **resumes** the existing `.handoff/state.md`. Passing a goal
  while one exists is refused, so the loop never silently works on the old task. Give each new
  task its own folder: `HANDOFF_DIR=.handoff/esm claude-loop "…"`. `claude-loop --status` shows
  what is there.
- Exit code 0 does not mean "done" for either tool: check the top of `state.md`, or the diff.

Tests for the argument parsing (plain bash, a stub stands in for `claude`/`agy`):
`bin/claude-loop.test.sh && bin/delegate.test.sh`.

## Notes

- Comments, doctrine and benchmark notes are in Portuguese; `README.pt-BR.md` is the original
  README. The scripts are small — read them before running them.
- This is a personal tool published as-is. It tracks whatever `agy` and Claude Code do this
  month; expect to adapt it.

## License

MIT
