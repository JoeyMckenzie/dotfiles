export const meta = {
    name: 'eval-agents',
    description:
        "Plant known defects on throwaway eval/* branches from the repo's .claude/evals/manifest.json, and check that the agents under test catch them",
    whenToUse:
        'After editing an agent prompt, before trusting it on real work. Needs .claude/evals/manifest.json and .claude/evals/plant.sh in the repo; the README next to this workflow in the nix-darwin config documents the manifest.',
    phases: [
        {
            title: 'Plant',
            detail: "run the repo's .claude/evals/plant.sh and load its manifest",
        },
        { title: 'Run', detail: 'the agent under test reviews each branch' },
        { title: 'Grade', detail: 'did it catch the planted defect' },
    ],
};

const FINDINGS = {
    type: 'object',
    properties: {
        verdict: { type: 'string' },
        findings: {
            type: 'array',
            items: {
                type: 'object',
                properties: {
                    severity: {
                        type: 'string',
                        enum: [
                            'critical',
                            'high',
                            'medium',
                            'low',
                            'blocking',
                            'should-fix',
                            'nit',
                        ],
                    },
                    file: { type: 'string' },
                    line: { type: 'integer' },
                    title: { type: 'string' },
                    detail: { type: 'string' },
                },
                required: ['severity', 'file', 'title', 'detail'],
            },
        },
    },
    required: ['verdict', 'findings'],
};

const GRADE = {
    type: 'object',
    properties: {
        caught: { type: 'boolean' },
        reason: { type: 'string' },
    },
    required: ['caught', 'reason'],
};

const SERIOUS = ['critical', 'high', 'blocking'];

const PLANTED = {
    type: 'object',
    properties: {
        output: { type: 'string' },
        manifest: { type: 'string' },
    },
    required: ['output', 'manifest'],
};

phase('Plant');
const planted = await agent(
    'From the repository root, run `.claude/evals/plant.sh "$(jq -r \'.base // "main"\' .claude/evals/manifest.json)"`. ' +
        'Return its output verbatim as `output`, or its error verbatim if it fails, and the contents of `.claude/evals/manifest.json` verbatim, byte for byte, as `manifest`.',
    { label: 'plant', phase: 'Plant', effort: 'low', schema: PLANTED },
);
if (!planted) throw new Error('eval-agents: the plant step returned nothing');
log(planted.output);
const manifest = JSON.parse(planted.manifest);
const base = manifest.base ?? 'main';
const CASES = manifest.cases;
if (!Array.isArray(CASES) || CASES.length === 0)
    throw new Error('eval-agents: .claude/evals/manifest.json has no cases');

const results = await pipeline(
    CASES,
    (c) =>
        c.prompt
            ? agent(c.prompt, {
                  agentType: c.agentType,
                  label: `${c.agentType}:${c.name}`,
                  phase: 'Run',
              })
            : agent(
                  `Ticket: ${c.ticket}\n\n` +
                      `Review the change on branch \`${c.branch}\` against \`${base}\`. The branch is not checked out: read it with ` +
                      `\`git diff --no-ext-diff ${base}...${c.branch}\`, \`git log ${base}..${c.branch}\`, and \`git show ${c.branch}:<path>\` ` +
                      `for whole files. Leave it unchecked-out and run no probes; prove each finding from the code.`,
                  {
                      agentType: c.agentType,
                      label: `${c.agentType}:${c.branch}`,
                      phase: 'Run',
                      schema: FINDINGS,
                  },
              ),
    async (report, c) => {
        if (!report)
            return {
                case: c.name,
                agent: c.agentType,
                pass: false,
                reason: 'agent returned nothing',
            };
        if (!c.expect) {
            const falseAlarms = report.findings.filter((f) =>
                SERIOUS.includes(f.severity),
            );
            return {
                case: c.name,
                agent: c.agentType,
                pass: falseAlarms.length === 0,
                reason:
                    falseAlarms.length === 0
                        ? 'no serious findings on a clean change'
                        : `false alarms: ${falseAlarms.map((f) => f.title).join('; ')}`,
            };
        }
        const grade = await agent(
            `An agent reviewed a change with a planted defect. Did its report catch the defect?\n\n` +
                `Planted defect, which the report must identify: ${c.expect}\n\nThe agent's report:\n${JSON.stringify(report, null, 2)}\n\n` +
                `When the report is prose rather than findings, judge whether it states the defect plainly. ` +
                `caught is true only when a finding identifies the defect itself at the stated severity, not a neighbouring concern.`,
            {
                label: `grade:${c.branch ?? c.name}`,
                phase: 'Grade',
                schema: GRADE,
                effort: 'low',
            },
        );
        return {
            case: c.name,
            agent: c.agentType,
            pass: grade?.caught ?? false,
            reason: grade?.reason ?? 'grader returned nothing',
        };
    },
);

const passed = results.filter((r) => r?.pass).length;
log(`${passed}/${CASES.length} cases passed`);
return { passed, total: CASES.length, results };
