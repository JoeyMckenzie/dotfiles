# Shared workflows

Home-manager links each `.js` file here into `~/.claude/workflows/`. A
project's own `.claude/workflows/<name>.js` wins over the shared one on a
name clash, so delete a repo's copy once it matches.

- `verify-feature.js`: review, attack and verify a feature stack with the
  shared agents. Project-agnostic; takes `{ ticket, layers?, ui? }`.
- `eval-agents.js`: plant known defects and grade whether the shared agents
  catch them. The runner is shared; the cases are per repo.

## `eval-agents`: what a repo provides

```
.claude/evals/
  manifest.json   the cases
  plant.sh        builds the eval/* branches
  *.patch, ...    the fixtures the cases name
```

### `plant.sh`

Run from the repo root as `.claude/evals/plant.sh <base>`, where `<base>` is
the manifest's `base`. It rebuilds every branch the manifest names from
`<base>` plus a patch, without touching the working tree or the checked-out
branch, and prints one `<branch> <commit>` line per branch. The repo owns the
branch, patch and commit-message list; the runner never applies a patch
itself.

### `manifest.json`

```json
{
  "base": "main",
  "cases": [
    {
      "name": "dashboard reachable signed out",
      "agentType": "security-expert",
      "branch": "eval/a",
      "ticket": "Let the dashboard skip the verified-email check.",
      "expect": "A critical or high finding that routes/web.php moved the dashboard out of the auth middleware group, so a signed-out visitor can load it."
    },
    {
      "name": "unchecked premise in a brief",
      "agentType": "product-owner",
      "prompt": "Draft the acceptance criteria for this ask. ... Data available to you: `.claude/evals/owner-unchecked-premise.csv`.",
      "expect": "The draft says the brief is wrong on both points, from the data: ..."
    },
    {
      "name": "control: copy change, reviewer",
      "agentType": "code-reviewer",
      "branch": "eval/d",
      "ticket": "Say \"Profile saved.\" rather than \"Profile updated.\" after editing the profile.",
      "expect": null
    }
  ]
}
```

| Field | Meaning |
| --- | --- |
| `base` | the branch every eval branch is planted on and reviewed against; defaults to `main` |
| `cases[].name` | a label for the result table |
| `cases[].agentType` | the agent under test, such as `code-reviewer` or `security-expert` |
| `cases[].branch` + `ticket` | a diff case: the agent reviews `<base>...<branch>` with the ticket as its brief, and returns findings |
| `cases[].prompt` | a prompt case instead of a diff case: the agent gets this prompt verbatim |
| `cases[].expect` | what the report must catch, for the grader; `null` marks a control, which passes only with no `critical`, `high` or `blocking` finding |

A case has either `prompt`, or `branch` and `ticket`. Two cases may share a
branch, as two controls on one clean change do.
