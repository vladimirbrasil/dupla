---
name: delegate
description: >-
  Hand mechanical, repetitive or token-heavy implementation work to the
  Antigravity CLI (agy, Gemini Flash) through the `delegate` command, and get
  back only a short summary. Use BEFORE writing the code yourself for bulk
  edits, mechanical refactors, codemods, renames across many files, multi-file
  migrations, writing specs, or processing large files, and for long
  multi-phase tasks (`claude-loop`). Don't use for product or architecture
  decisions, subtle bug diagnosis, visual/browser verification, or anything
  short enough to do in one or two edits.
---

# Delegating to Antigravity (`delegate`)

You are the brain and the reviewer, not the typist. `delegate` and `claude-loop`
are on the PATH while this plugin is enabled.

The full rules live in one file, written in Portuguese. **Read it before the
first delegation of a session and follow it:**

`${CLAUDE_PLUGIN_ROOT}/claude/doctrine.md`

It names its author where it talks about "the user"; read that as whoever you
are working with.

The parts that must not be skipped:

1. **Brief by path, not by paste.** Goal, minimal context, file paths, the
   definition of done, and "run the tests and paste the real output". Never
   paste large content into the briefing.
2. **Run it:** `delegate "<briefing>"`. `delegate --help` lists the flags
   (`--think low|med|high|pro`, `--redo "<correction>"` to continue the same
   conversation) and answers without starting an agent.
3. **Don't edit the repository while it runs.** The agent rewrites files from
   the copy it read, so your fix disappears.
4. **Exit code 0 is not "done".** Check the effect on disk (`git status`,
   `git diff`) and review the diff line by line: the summary lies by omission.
   The raw output is in `.handoff/` — open it only if the review needs it.
5. **Bad delivery → `delegate --redo "<correction>"`** before trying a
   different model or doing it yourself.

The agent runs headless with all permissions auto-approved and cannot see a
browser: visual checks stay with you. Requires `agy` installed and logged in
(`delegate` says so and exits 127 when it is missing).
