---
name: app-browser
description: Drive the project's running app in real Chrome through claude-in-chrome. Covers which host serves the current worktree, the seeded users and their roles, signing in, and whether you may start the app. Use before verifying or reviewing any UI in the browser.
---

# Driving the app in Chrome

## The project facts

The host, the seeded users and the start/stop policy are project facts, in
`.ai/rules/agent-harness.md` under **Browser and seed users**. Read that
section first. If the file or the section is missing, say so and stop:
never guess a host, a user or a password.

## The browser

Use the **claude-in-chrome** tools (`mcp__claude-in-chrome__*`). Load the ones
you need in a single ToolSearch call, call `tabs_context_mcp` first, and open
your own tab with `tabs_create_mcp` rather than reusing one of Joey's.

## The host

Each worktree usually serves itself on its own host, named in the facts with
a `<worktree>` placeholder. Unless the facts say otherwise, `<worktree>` is:

```bash
basename "$(git rev-parse --show-toplevel)"
```

The facts say whether the primary checkout uses a different name.

## When the host does not answer

Follow the facts' start/stop policy exactly. It takes one of two shapes:

- **You may start it**: run the start command the facts name from the
  worktree root as a background Bash command, wait until the host answers,
  and stop that process when your browser work is done. Never stop a server
  you did not start.
- **Report it**: say the host is down and stop. Starting servers belongs to
  whoever owns the worktree.

When the facts give no policy, report it.

## Signing in

The facts list the seeded users, their roles and their passwords, and which
check each user is for. When a page lands on the login page, sign in through
the form as the user the check needs. These are local seed users, so
entering their credentials is expected. Sign out before switching users.

Checks that need a signed-out visitor, a user who should be refused, or a
second account that is not seeded locally belong to `security-expert`'s
probes against the test database.
