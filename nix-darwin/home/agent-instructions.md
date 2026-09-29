# CLAUDE.md

Behavioral guidelines to reduce common LLM coding mistakes. Merge with project-specific instructions as needed.

**Tradeoff:** These guidelines bias toward caution over speed. For trivial tasks, use judgment.

## 1. Think Before Coding

**Don't assume. Don't hide confusion. Surface tradeoffs.**

Before implementing:
- State your assumptions explicitly. If uncertain, ask.
- If multiple interpretations exist, present them - don't pick silently.
- If a simpler approach exists, say so. Push back when warranted.
- If something is unclear, stop. Name what's confusing. Ask.

## 2. Simplicity First

**Minimum code that solves the problem. Nothing speculative.**

- No features beyond what was asked.
- No abstractions for single-use code.
- No "flexibility" or "configurability" that wasn't requested.
- No error handling for impossible scenarios.
- If you write 200 lines and it could be 50, rewrite it.

Ask yourself: "Would a senior engineer say this is overcomplicated?" If yes, simplify.

## 3. Surgical Changes

**Touch only what you must. Clean up only your own mess.**

When editing existing code:
- Don't "improve" adjacent code, comments, or formatting.
- Don't refactor things that aren't broken.
- Match existing style, even if you'd do it differently.
- If you notice unrelated dead code, mention it - don't delete it.

When your changes create orphans:
- Remove imports/variables/functions that YOUR changes made unused.
- Don't remove pre-existing dead code unless asked.

The test: Every changed line should trace directly to the user's request.

## 4. Scope Before Building

**When the work is ambiguous, cross-cutting, or outlives its ticket, invoke the `think-like-a-staff-engineer` skill before implementing.**

Triggers: an under-specified problem, scoping or decomposing a project, a decision that sets a boundary or a dependency direction, making the case for foundational work, or a request that would otherwise get absorbed silently.

It is a framing pass, not a process. It ends with a written plan naming the acceptance criterion, the blast radius, the seams, and who owns each slice.

## 5. Goal-Driven Execution

**Define success criteria. Loop until verified.**

Transform tasks into verifiable goals:
- "Add validation" → "Write tests for invalid inputs, then make them pass"
- "Fix the bug" → "Write a test that reproduces it, then make it pass"
- "Refactor X" → "Ensure tests pass before and after"

For multi-step tasks, state a brief plan:
```
1. [Step] → verify: [check]
2. [Step] → verify: [check]
3. [Step] → verify: [check]
```

Strong success criteria let you loop independently. Weak criteria ("make it work") require constant clarification.

---

**These guidelines are working if:** fewer unnecessary changes in diffs, fewer rewrites due to overcomplication, and clarifying questions come before implementation rather than after mistakes.

## Shell Tooling Preferences

When searching for files or content, prefer these tools:

- Use `fd` instead of `find`
- Use `rg` (ripgrep) instead of `grep`
- Use `fzf` for interactive fuzzy selection when appropriate

### Examples

- Finding files: `fd -e php -t f` not `find . -name "*.php" -type f`
- Searching content: `rg "pattern" --type php` not `grep -r "pattern" --include="*.php"`
- Finding a file interactively: `fd | fzf`


## Notes

My notes and tasks live in `~/org`, as org-mode files edited with nvim-orgmode
and org-roam.nvim. When I ask you to save, look up, or organize a note without
naming a location, that's where it goes.

- `refile.org` is the capture inbox; `work.org` and `personal.org` hold tasks
  grouped under project headings.
- `notes/` is the org-roam directory: one note per file, each with a `:ID:`
  property, linked with `[[id:...][Title]]`. Daily notes go in `notes/daily/`.
- TODO states are `TODO NEXT WAITING | DONE CANCELLED`.

`~/vaults` holds my old Obsidian notes. It's read-only history: look things
up there if asked, but don't add to it.
