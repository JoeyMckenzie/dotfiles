# Agent harness facts

<!--
Template for a repo's `.ai/rules/agent-harness.md`. Copy it there, list it
in `.ai/rules/index.md`, fill every `<slot>`, and delete each slot or
section that does not apply (say "none" rather than leaving it out when an
agent would otherwise guess). Delete this comment.

The shared agents in `~/.claude/agents` and the `app-browser` skill read
this file for everything specific to the project. Each `##` heading below
is a name they point at; keep the headings exactly as written. Text under
an "Examples" heading shows the shape of an answer, from a real stack; it
is not a default.
-->

The shared agents in `~/.claude/agents` read this file for everything
specific to `<product>`. Each `##` heading is a name the agents point at;
keep the headings stable.

## Product and client

- What the product is, for whom, and Joey's role on it: `<one paragraph>`
- The customer and what the UI must favour for them: `<who uses it, how often, what beats what>`
- Mockups and handoff: `<where the client's own mockups and handoff live, or "none">`
- What the app outputs besides its UI: `<emails, exports, reports, or "UI only">`

## Linear

- Team: `<team name>`; ticket prefix: `<PREFIX>`. Commits read `[<PREFIX>-XXX] type(scope): summary`.
- Project: `<project name>`, which holds the scope, phases and open questions.
- Questions only the client can answer: `<who to route them to>`

## Default branch

`<main>`: the branch every stack is cut from, every feature merges into,
and every whole-stack review runs against.

## Guarded external systems

The client's ground rule for anything sent, submitted or written on their
behalf: `<rule>`. A feature that would cross it is a crossroads.

| System | Rule | Enforced by |
| --- | --- | --- |
| `<host or service>` | `<read-only / never written / ask Joey>` | `<hook name, or "prompt only">` |

Ingested sources: `<the external sources the app reads unattended, such as feeds, scraped pages or upstream APIs, and what a bad response from each looks like>`

## Standing acceptance criteria

Every ticket's AC covers: `<the cases every ticket must cover, such as empty, error, signed-out, no-permission, nothing sent without a person>`

## Threat model

- Attackers: `<a signed-out visitor, a stranger who registered, a user of another account, a poisoned upstream payload; keep the ones that apply>`
- Tenants: `<"none", or what a tenant is and how rows are scoped to one>`
- Run-as mechanism: `<how jobs and commands act as a tenant, or "none">`
- Credentials in scope: `<which tokens and secrets>`
- Long-form notes: `<CONTEXT.md paths to read>`

### Examples

In a Laravel and Inertia app: the props the server sends to the page are
Inertia props; IDs reach rows through route model binding; a scope bypass
looks like `withoutGlobalScopes()`, the query builder or raw SQL on a
scoped table.

## Research beat

- Sources, competitors, programs, regulations and upstream APIs: `<list>`
- How the client works and the vocabulary they use: `<list>`
- Where research lives: `<Linear documents, by name>`
- Out of bounds: `<gated content, anything behind a sign-in>`

## Browser and seed users

- Browser skill: `app-browser`.
- Host: `<https://<worktree>.<app>.test>`, where `<worktree>` is `<the worktree folder name, or "main" in the primary checkout>`.
- When the host does not answer: `<"You may start it: run <command> from the worktree root, wait for the host, stop it when done" or "Report it">`
- Seed users (every password `<password>`):

| Email | Role | Use it to check |
| --- | --- | --- |
| `<email>` | `<role>` | `<what>` |

- Checks that need a signed-out visitor, a refused user or a second account: `<who covers them, usually security-expert's probes>`

## Framework skills

`<the skills to load per layer, and the component libraries to check before inventing UI>`

### Examples

`laravel-best-practices`, `inertia-react-development`,
`wayfinder-development`, `tailwindcss-development`; components from shadcn
and Magic UI; a pulsing skeleton while deferred props load.

## Dev stack and test database

- Stack: `<languages, frameworks, database, dev environment>`
- Fixtures folder: `<where captured payloads from external systems live; they count as real rows>`
- Test database: `<its name per worktree, and the guard that stops a suite running on the dev database>`

## Probe tooling

- Probe command: `<the one-shot command that proves a finding against the test database>`
- Skill to load first: `<skill name, or "none">`
- Overlap check: `<how to tell another test run is using the test database right now>`

### Examples

`vendor/bin/pest --agent='<code>'` with the `pest-plugin-agent` skill;
`pgrep -fl pest` before trusting a suite, gate or mutation result. Never
point a probe at a runner or bootstrap of your own, such as
`--bootstrap=vendor/autoload.php`, while `DB_DATABASE` names the dev
database.

## Quality gates

| Command | Role |
| --- | --- |
| `<command>` | the builder's **layer gate**, run on each layer before the next |
| `<command>` | the **browser suite**, for UI work, or "none" |
| `<command>` | other suites: types, coverage, mutation, with their floors and baselines (agents never run a mutation sweep; Joey runs it) |

## Launcher and worktrees

- Launcher: `<what "feature <worktree> \"<brief>\"" opens, and whether it starts the app>`
- Worktree and stack names: `<ticket-named worktree, such as <prefix>-12-slug; layers <worktree-branch>-<layer>>`
- Seeding: `<how a fresh worktree gets its seed users>`

## Coordination

- Capacity: `<how many feature leads can run at once on this machine, and what counts as one>`
- Status file: `<the path, from each worktree's root, where its feature lead keeps its status; gitignored>`
- State file: `<the path, in the main checkout, where the chief of staff keeps its state; gitignored>`
- Merge settings: `<whether the host deletes a merged branch and retargets the PR above it, auto-merge, the merge method>`
- Words that trip a hook: `<each hook that reads a whole command, and the words in any argument, quoted prose included, that trip it>`
- Teardown: `<the command Joey runs once a stack merges, and the dry run an agent may run, or "by hand">`

## Anti-comment allow-list

The global anti-comment hook reads optional per-repo exclusions from
`.ai/rules/anti-comment-allow`. Only the user edits that file, by hand; the
hook blocks agents from writing to it. It applies to files below it up to
the first folder holding `.git`. Each line is either:

- `path:<glob>`: skip files whose path matches the glob, such as
  `path:*/resources/js/components/ui/*`
- `line:<prefix>`: allow comment lines that start with the prefix, after
  leading whitespace, such as `line:// Credit:`

Any other line is ignored. Empty entries and catch-alls (`line:` of `/`,
`//`, `/*`, `/**`, `#` or `*`; `path:` of `*`, `**`, `/*`, `/**`, `*/*` or
`**/*`) are ignored too, so one entry cannot switch the hook off.

`<"none", or the reason for each entry>`
