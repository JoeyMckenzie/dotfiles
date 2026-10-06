export const meta = {
  name: 'verify-feature',
  description: 'Review, attack and verify the current feature stack: code review per layer and security on the whole stack in parallel, each finding challenged, then QA',
  whenToUse: 'After product-builder hands back a green stack. Pass { ticket, layers?, ui?, base? }: ticket is the Linear ID plus its AC verbatim, layers the stack bottom to top as { branch, base }, base the default branch from the facts file (main when omitted).',
  phases: [
    { title: 'Review', detail: 'code-reviewer on each layer, security-expert on the stack' },
    { title: 'Challenge', detail: 'one skeptic per serious finding' },
    { title: 'Verify', detail: 'qa-specialist, plus product-designer for UI work' },
  ],
}

const ticket = args?.ticket
if (!ticket) throw new Error('verify-feature needs args.ticket: the Linear ID and its acceptance criteria verbatim')
const base = args?.base ?? 'main'
const layers = args?.layers ?? [{ branch: 'HEAD', base }]
const stack = { branch: layers.at(-1).branch, base }
const ui = args?.ui ?? false

const SERIOUS = ['critical', 'high', 'blocking']
const CHALLENGED = [...SERIOUS, 'medium', 'should-fix']
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
const briefing = target => `${ticketBrief}\n\nReview ${range(target)}.`

const lenses = await pipeline(
  LENSES,
  lens => agent(briefing(lens.target), { agentType: lens.agentType, label: lens.label, phase: 'Review', schema: FINDINGS }),
  async (report, lens) => {
    if (!report) return { lens: lens.label, verdict: 'agent failed', failed: true, confirmed: [], refuted: [], unchallenged: [] }
    const serious = report.findings.filter(f => CHALLENGED.includes(f.severity))
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

const standing = lenses.flatMap(l => [...l.confirmed, ...l.unchallenged.filter(f => CHALLENGED.includes(f.severity))])

if (standing.length > 0) {
  log(`${standing.length} findings of medium, should-fix or worse stand, so QA waits for the fixes`)
  return { status: 'fix first', lenses, qa: null, design: null }
}

phase('Verify')
const [qa, design] = await parallel([
  () => agent(`${briefing(stack)}\n\nSign the feature off against every acceptance criterion.`, {
    agentType: 'qa-specialist',
    label: 'qa',
    phase: 'Verify',
    schema: QA,
  }),
  () => ui
    ? agent(`${briefing(stack)}\n\nReview mode: compare the built UI against the design spec on the ticket.`, {
      agentType: 'product-designer',
      label: 'design review',
      phase: 'Verify',
      schema: DESIGN,
    })
    : Promise.resolve(null),
])

if (qa?.verdict !== 'signed off') {
  log(`QA did not sign off: ${qa?.verdict ?? 'agent failed'}`)
  return { status: 'qa blocked', lenses, qa, design }
}

if (ui && design?.verdict !== 'approved') {
  log(`Design review did not approve: ${design?.verdict ?? 'agent failed'}`)
  return { status: 'design changes requested', lenses, qa, design }
}

return { status: 'verified', lenses, qa, design }
