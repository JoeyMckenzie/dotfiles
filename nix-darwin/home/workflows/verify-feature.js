export const meta = {
  name: 'verify-feature',
  description: 'Review, attack and verify the current feature stack: code review per layer and security on the whole stack in parallel, each finding challenged, then QA every round, with Chrome and design review only once no finding stands',
  whenToUse: 'After product-builder hands back a green stack. Pass { ticket, layers?, ui?, base?, waived? }: ticket is the Linear ID plus its AC verbatim, layers the stack bottom to top as { branch, base }, base the default branch from the facts file (main when omitted), waived the findings the team settled as [{ file, title, reason }].',
  phases: [
    { title: 'Review', detail: 'code-reviewer on each layer, security-expert on the stack' },
    { title: 'Challenge', detail: 'one skeptic per serious finding' },
    { title: 'Verify', detail: 'qa-specialist every round, headless while findings stand; product-designer for UI work once none do' },
  ],
}

const ticket = args?.ticket
if (!ticket) throw new Error('verify-feature needs args.ticket: the Linear ID and its acceptance criteria verbatim')
const base = args?.base ?? 'main'
const layers = args?.layers ?? [{ branch: 'HEAD', base }]
const stack = { branch: layers.at(-1).branch, base }
const ui = args?.ui ?? false
const waived = args?.waived ?? []

const SERIOUS = ['critical', 'high', 'blocking']
const CHALLENGED = [...SERIOUS, 'medium', 'should-fix']
const SEVERITY_ORDER = ['blocking', 'critical', 'high', 'should-fix', 'medium', 'low', 'nit']
const bySeverity = (a, b) => SEVERITY_ORDER.indexOf(a.severity) - SEVERITY_ORDER.indexOf(b.severity)
const sameText = (a, b) => a.trim().toLowerCase() === b.trim().toLowerCase()
const isWaived = f => waived.some(w => w.file === f.file && sameText(w.title, f.title))
const MAX_CHALLENGES_PER_LENS = 3

const FINDINGS = {
  type: 'object',
  properties: {
    verdict: { type: 'string', description: 'approved / changes requested, or a one-line security verdict' },
    findings: {
      type: 'array',
      items: {
        type: 'object',
        properties: {
          severity: { type: 'string', enum: ['critical', 'high', 'medium', 'low', 'blocking', 'should-fix', 'nit'] },
          file: { type: 'string' },
          line: { type: 'integer' },
          title: { type: 'string' },
          detail: { type: 'string' },
          fix: { type: 'string' },
        },
        required: ['severity', 'file', 'title', 'detail'],
      },
    },
  },
  required: ['verdict', 'findings'],
}

const CHALLENGE = {
  type: 'object',
  properties: {
    refuted: { type: 'boolean' },
    reason: { type: 'string' },
  },
  required: ['refuted', 'reason'],
}

const range = ({ branch, base }) => `\`${branch}\` against \`${base}\``

const QA = {
  type: 'object',
  properties: {
    verdict: { type: 'string', enum: ['signed off', 'blocked'] },
    report: { type: 'string', description: 'The full sign-off report: the AC table with evidence, and each blocking bug with its repro' },
  },
  required: ['verdict', 'report'],
}

const DESIGN = {
  type: 'object',
  properties: {
    verdict: { type: 'string', enum: ['approved', 'changes requested'] },
    report: { type: 'string', description: 'The full design review: each deviation with its screenshot, the spec line it breaks, and the fix' },
  },
  required: ['verdict', 'report'],
}

const LENSES = [
  ...layers.map(layer => ({ agentType: 'code-reviewer', label: `review:${layer.branch}`, target: layer })),
  { agentType: 'security-expert', label: 'security', target: stack },
]

const ticketBrief = `Ticket and acceptance criteria:\n${ticket}`
const waivedBrief = waived.length === 0
  ? ''
  : `\n\nThe team settled these findings; do not re-raise them:\n${waived.map(w => `- ${w.file}: ${w.title} (${w.reason})`).join('\n')}`
const briefing = target => `${ticketBrief}\n\nReview ${range(target)}.${waivedBrief}`
const RUNNER_RULE =
  '\n\nOne test runner at a time in this worktree. The builder ran the layer gate green before this review, and the other reviewers and ' +
  'security-expert work in this worktree alongside you, so rely on that gate for the suite. Run a targeted test or probe only when a ' +
  "finding turns on it, after the facts' overlap check comes back empty. When another run is live, wait and retry once; if it is still " +
  'live, prove the finding from the code and say which run you could not make.'
const APP_RULE =
  '\n\nThe app is already running at the worktree\'s host, and the product manager owns it: work against it as you find it, and leave ' +
  "every process alone, this worktree's and every other worktree's, with their ports and databases. If the host stops answering, " +
  'stop and report that.'
const HEADLESS_RULE =
  '\n\nThis run is headless: no app is running and no browser is granted. Prove every criterion with tests and probes against the ' +
  "worktree's test database, and leave every process alone, this worktree's and every other worktree's, with their ports and databases. " +
  'An AC that only a browser can prove goes in your report as unverified, for the product manager.'
const QA_RULE = ui ? APP_RULE : HEADLESS_RULE

const lenses = await pipeline(
  LENSES,
  lens => agent(`${briefing(lens.target)}${RUNNER_RULE}`, { agentType: lens.agentType, label: lens.label, phase: 'Review', schema: FINDINGS }),
  async (report, lens) => {
    if (!report) return { lens: lens.label, verdict: 'agent failed', failed: true, confirmed: [], refuted: [], unchallenged: [] }
    const serious = report.findings.filter(f => CHALLENGED.includes(f.severity)).sort(bySeverity)
    const challenged = serious.slice(0, MAX_CHALLENGES_PER_LENS)
    const unchallenged = report.findings.filter(f => !challenged.includes(f))
    if (serious.length > challenged.length) {
      log(`${lens.label}: ${serious.length - challenged.length} serious findings passed through unchallenged`)
    }
    const verdicts = await parallel(challenged.map(f => () =>
      agent(
        `A ${lens.label} of ${range(lens.target)} reported this finding:\n\n` +
        `[${f.severity}] ${f.file}${f.line ? `:${f.line}` : ''} ${f.title}\n${f.detail}\n\n` +
        `Try to refute it from the code. It is refuted when the code, a test, or a guard elsewhere ` +
        `shows it cannot happen or does not matter. Keep it when you cannot point at the code that disproves it.`,
        { label: `challenge:${lens.label}`, phase: 'Challenge', schema: CHALLENGE },
      ).then(v => ({ ...f, challenge: v }))))
    return {
      lens: lens.label,
      verdict: report.verdict,
      confirmed: verdicts.filter(Boolean).filter(f => !f.challenge?.refuted),
      refuted: verdicts.filter(Boolean).filter(f => f.challenge?.refuted),
      unchallenged,
    }
  },
)

const failed = lenses.filter(l => !l || l.failed)

if (failed.length > 0) {
  log(`${failed.length} reviews did not run, so QA waits for a rerun`)
  return { status: 'review failed', lenses, qa: null, design: null }
}

const standing = lenses
  .flatMap(l => [...l.confirmed, ...l.unchallenged.filter(f => CHALLENGED.includes(f.severity))])
  .filter(f => !isWaived(f))

if (standing.length > 0) {
  log(`${standing.length} findings of medium, should-fix or worse stand, so QA runs headless and design review waits for the fixes`)
  phase('Verify')
  const standingBrief = standing.map(f => `- [${f.severity}] ${f.file}: ${f.title}`).join('\n')
  const qa = await agent(
    `${briefing(stack)}\n\nSign the feature off against every acceptance criterion. These findings stand, and the builder fixes them ` +
    `before the next round, so expect those areas to change:\n${standingBrief}${HEADLESS_RULE}`,
    { agentType: 'qa-specialist', label: 'qa', phase: 'Verify', schema: QA },
  )
  return { status: 'fix first', lenses, qa, design: null }
}

phase('Verify')
const qa = await agent(`${briefing(stack)}\n\nSign the feature off against every acceptance criterion.${QA_RULE}`, {
  agentType: 'qa-specialist',
  label: 'qa',
  phase: 'Verify',
  schema: QA,
})
const design = ui
  ? await agent(`${briefing(stack)}\n\nReview mode: compare the built UI against the design spec on the ticket.${APP_RULE}`, {
    agentType: 'product-designer',
    label: 'design review',
    phase: 'Verify',
    schema: DESIGN,
  })
  : null

if (qa?.verdict !== 'signed off') {
  log(`QA did not sign off: ${qa?.verdict ?? 'agent failed'}`)
  return { status: 'qa blocked', lenses, qa, design }
}

if (ui && !design) {
  log('Design review returned nothing')
  return { status: 'design review failed', lenses, qa, design }
}

if (ui && design.verdict !== 'approved') {
  log(`Design review did not approve: ${design.verdict}`)
  return { status: 'design changes requested', lenses, qa, design }
}

return { status: 'verified', lenses, qa, design }
