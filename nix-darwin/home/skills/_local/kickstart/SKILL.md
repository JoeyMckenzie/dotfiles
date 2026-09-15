---
name: kickstart
description: Compact this session into a handoff, then start a fresh Claude session in a new herdr pane with that handoff already loaded and close this pane.
argument-hint: "What will the next session be used for?"
disable-model-invocation: true
---

Hand this session off to a fresh Claude session in the user's herdr workspace, with the handoff document already loaded as its first prompt. Requires `HERDR_ENV=1`.

Run each step's commands one at a time and read the JSON results — do not predict IDs. If any step fails, stop, report the failure, and leave this pane alive with the handoff path so the user can fall back to copy/paste.

## 1. Preflight

```bash
test "${HERDR_ENV:-}" = 1
herdr pane current --current
```

If the first check fails, say this session is not running inside herdr and stop. If the second returns `protocol_mismatch`, the running herdr server is older than the `herdr` CLI: tell the user to run `herdr server stop` and relaunch herdr (this exits pane processes), then stop.

## 2. Write the handoff

Follow `~/.claude/skills/handoff/SKILL.md` exactly, treating this skill's arguments as that skill's arguments. Save to `/tmp/handoff-<YYYYMMDD-HHMMSS>.md` and keep the exact path — the next session is told to read it.

## 3. Start the next session

```bash
herdr pane split --current --direction right --cwd "$PWD" --no-focus
```

Take the new pane ID from `.result.pane.pane_id`, then:

```bash
herdr agent start kickstart-<HHMMSS> --kind claude --pane <new-pane-id>
herdr agent prompt <new-pane-id> "Read <handoff-path> — it is a handoff from the previous session in this repo. Follow it and continue the work."
```

Do not pass `--wait` to `agent prompt`; it would block until the new session finishes its first turn. If `agent start` returns `agent_not_ready`, wait for idle with `herdr agent wait <new-pane-id>` before prompting.

## 4. Hand over the pane

Only after step 3 succeeds. Focus the new session, then close this one so it fills the space:

```bash
herdr agent focus <new-pane-id>
herdr pane close "$HERDR_PANE_ID"
```

`pane close` kills this session mid-command, so it must be the final action of the skill and will return no output. That is expected — do not retry it or report it as an error.
