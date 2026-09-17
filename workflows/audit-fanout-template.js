export const meta = {
  name: 'playbook-gated-audit',
  description: 'Reusable bug-bounty fan-out that gates every finding through the v1.6 playbook (3 axes + Phase 0 + 5 gates + materiality + on-chain-verify) as the accept/reject standard, and emits a PLAYBOOK-AUDIT report per finding.',
  phases: [
    { title: 'Find', detail: 'target-specific finders (from args.finders)' },
    { title: 'Gate', detail: 'per-finding playbook audit: gates + on-chain verify + materiality red-team' },
    { title: 'Synthesize', detail: 'PLAYBOOK-AUDIT report, payable-only, real tier' },
  ],
}

// ---------------------------------------------------------------------------
// CONTRACT: pass everything target-specific via the Workflow `args` object:
// {
//   target:        "stackingdao",
//   onchainDir:    "/abs/path/to/contracts/onchain",      // deployed sources = authoritative
//   primerPath:    "/abs/path/to/audit/methodology-primer.md",  // attacker model + scope
//   playbookPath:  "/abs/.../playbook/playbook-bug-bounty-v1.6.md",
//   standardPath:  "/abs/.../playbook/finding-acceptance-standard.md",
//   chainReadCmd:  "python3 /abs/.../playbook/tools/stacks-read.py",  // V2 on-chain mandate tool
//   scope: { regime: "impact"|"rules", economics: "<max, tiers, floors, %-cap, fee, token>",
//            priorRecord: "<our own prior submissions on this target, incl. rejected ids>" },
//   finders: [ { label, files:[...basenames], lens, focus }, ... ],   // target-specific
//   minPayableTier: "high"                                            // program floor
// }
// ---------------------------------------------------------------------------
const A = args || {}
if (!A.finders || !A.finders.length) throw new Error('args.finders required (target-specific finder specs)')
let ONCHAIN = A.onchainDir                       // may be set by the self-bootstrap phase below
const PRIMER = A.primerPath, PLAYBOOK = A.playbookPath, STD = A.standardPath
const CHAIN = A.chainReadCmd || '(no chain-read tool provided)'
const REGIME = (A.scope && A.scope.regime) || 'unknown'
const ECON = (A.scope && A.scope.economics) || 'unknown'
const PRIOR = (A.scope && A.scope.priorRecord) || 'none provided'
const MINTIER = A.minPayableTier || 'high'
// The program's full "Impacts in Scope" table, VERBATIM = the hunt's target map (every payable
// terminal verb, not just theft). Pull it at Phase 0 and feed it to every finder + the materiality
// gate. Absent = the theft-reflex failure mode (Pareto near-miss): warn loudly.
const IMPACTS = A.impactsInScope ||
  'WARNING: args.impactsInScope NOT provided. Hunt EVERY payable class, not just theft: direct theft, ' +
  'PERMANENT freezing of funds, PROTOCOL INSOLVENCY, MEV->freeze/insolvency, temporary freezing, ' +
  'SC-inoperable / DoS / resource-exhaustion, griefing. Do not tunnel on extraction.'
if (!A.impactsInScope) log('WARN: args.impactsInScope missing — finders told to hunt all payable classes generically; pull the program impact table for precision.')

const EXT = A.fileExt || 'clar'                  // 'clar' for Stacks, 'sol' for EVM, etc.
const catf = (files) => (files || []).map(f => `${ONCHAIN}/${f}.${EXT}`).join(' ')

const FINDING_SCHEMA = {
  type: 'object',
  properties: { findings: { type: 'array', items: { type: 'object', properties: {
    title:{type:'string'}, contract:{type:'string'}, function:{type:'string'},
    severity:{type:'string',enum:['critical','high','medium','low','info']},
    impact:{type:'string'}, attacker:{type:'string'}, preconditions:{type:'string'},
    description:{type:'string'}, exploit_steps:{type:'string'}, code_evidence:{type:'string'},
  }, required:['title','contract','function','severity','description','exploit_steps','impact','attacker'] } } },
  required:['findings'],
}

// The verdict mirrors finding-acceptance-standard.md
const VERDICT_SCHEMA = {
  type:'object',
  properties:{
    validite:{type:'object',properties:{
      mechanism:{type:'string',enum:['pass','fail']},
      onchain_verified:{type:'string',enum:['pass','fail','not-done']},
      onchain_checks:{type:'string'},
      deployed_not_head:{type:'string',enum:['pass','fail','n/a']},
    },required:['mechanism','onchain_verified']},
    gate1_actor:{type:'string',enum:['pass','fail']},
    gate2_guard:{type:'string',enum:['escaped','missing','n/a']},
    gate3_premise:{type:'string',enum:['pass','fail']},
    gate4_dup:{type:'string',enum:['clear','dup-public','dup-private-risk','self-dup']},
    entry_vector:{type:'string',enum:['in-scope','wall']},
    gate5_real_tier:{type:'string',enum:['critical','high','medium','low','not-payable']},
    gate5_killing_check:{type:'string'},
    verdict:{type:'string',enum:['ACCEPT','DOWNGRADE','REJECT','LATENT']},
    killing_gate:{type:'string'},
    real_tier:{type:'string',enum:['critical','high','medium','low','not-payable']},
    one_line:{type:'string'},
    reasoning:{type:'string'},
  },
  required:['validite','gate1_actor','gate3_premise','gate4_dup','entry_vector','gate5_real_tier','verdict','real_tier','one_line'],
}

const finderPrompt = (spec) =>
`You are a senior smart-contract auditor hunting a PAYABLE bug on ${A.target}. Read the primer: \`cat ${PRIMER}\`. Read your assigned deployed sources fully: \`cat ${catf(spec.files)}\` (and any other file in ${ONCHAIN}/ to trace calls).
LENS: ${spec.lens}
FOCUS: ${spec.focus}
Enumerate attacker-reachable entrypoints, build the call graph, and prove exploits with concrete numbers. Report ONLY what survives your own refutation, mapped to an in-scope impact. Empty is a valid answer. Return raw structured data.
PAYABLE IMPACTS TO CHASE (the target map — do NOT tunnel on theft):
${IMPACTS}
For your surface, chase EVERY applicable class above, not just extraction: can an unprivileged actor cause PERMANENT freezing (funds/receipts unclaimable, a state that bricks deposits/withdrawals), PROTOCOL INSOLVENCY (claims > real assets via accounting drift, not only via theft), a DoS / SC-inoperable (a permissionless input that makes a core function always revert), or temporary freezing / griefing? A freeze or insolvency with no theft is fully payable here. Map each candidate to its impact class.
DIRTY-NUMBERS MANDATE (v1.6): drive EVERY numeric proof with realistic non-round values — prices carrying cents, non-divisible amounts, prime quantities, decimals != the market's — never round illustrative numbers. Rounding / off-by-one / precision classes only bite when there is a remainder; a round number structurally HIDES the whole class (everything passes, nothing signals). For any division / share-conversion / valuation sink, show the exact integer arithmetic (the division, both floors) at a dirty value. FOIL: if the dev tests in round dollars, that is his blind spot — hunt it.`

// The three playbook killers, run adversarially per finding.
const KILLERS = [
  { key:'onchain-validite', ask:
`AXIS VALIDITÉ + the on-chain mandate (V2). Re-derive the mechanism from ${ONCHAIN}/ source yourself. THEN — this is mandatory and is where StackingDAO-style false positives die — verify EVERY premise about governance/config/operator-settable state LIVE ON-CHAIN using the provided tool, do not trust code defaults:
  ${CHAIN}
Check: registrations / active flags / allowlists / escrow or position lists / config vars / balances / supply / roles that the finding assumes. If live state contradicts the finding's premise, it is a FALSE POSITIVE — set onchain_verified=fail, mechanism=fail, verdict=REJECT. Report the exact reads you ran in onchain_checks. Also do the deployed-code-not-head check if a scope commit is known.` },
  { key:'recevabilite-gates', ask:
`AXIS RECEVABILITÉ. Read the standard: \`cat ${STD}\` and playbook: \`cat ${PLAYBOOK}\`. Run: Gate1 actor-separation (create-vs-ride; reachability-premise must live in in-scope judged code); Gate2 (escaped vs missing guard — lead only if escaped); Gate3 (does the PoC construct or reach; external premise closed in PRIMARY SOURCE; and was the mechanism driven in DIRTY numbers, not round values that hide the precision class?); Gate4 dup/known-issue in PRIMARY SOURCE for the EXACT sink AND against OUR OWN prior record below — DEDUP PER SINK, NEVER PER CLASS: "the class is known" is a false-negative tombstone; a patch/audit guarding only ONE sink of the class proves the class is alive at the other sinks (read each in primary source); entry-vector wall for regime=${REGIME}. Set each gate and the killing_gate if any fails.
Regime: ${REGIME}. OUR PRIOR RECORD on this target (a match = self-dup, do NOT re-spend): ${PRIOR}` },
  { key:'materialite-redteam', ask:
`AXIS MATÉRIALITÉ (Gate 5, six checks) — the most frequent killer. First map the finding to its PAYABLE IMPACT CLASS from the program table:
${IMPACTS}
Tier it against that class (a permanent freeze / insolvency / DoS is tiered on its OWN class, not discounted because "no theft"). Then compute magnitude at DEPLOYED scale with a SEPARATE calc (real supply/pool/attacker-position/window read on-chain via ${CHAIN}), NOT the PoC's illustrative numbers. Apply the program economics: ${ECON} (esp. any %-funds-at-risk cap × the in-scope contract's live TVL, and the pause window). Write the engineer's best refutation (by-design / bounded / self-limiting / DAO-recoverable / immaterial-at-scale) and answer it. Do check #6: if the impact needs a FORM, census prod on-chain for real instances. Output gate5_real_tier and the killing_check if it caps below ${MINTIER}.` },
]

const auditFinding = (f) => parallel(KILLERS.map(k => () =>
  agent(
`You are running the ${A.target} finding below through the bug-bounty acceptance standard. Be the skeptical triager: protect against false positives and immaterial claims. A clean kill closed now is worth as much as a finding.

FINDING:
- Title: ${f.title}
- ${f.contract} :: ${f.function}  | claimed severity: ${f.severity}
- impact: ${f.impact}
- attacker: ${f.attacker}
- preconditions: ${f.preconditions || 'n/a'}
- description: ${f.description}
- exploit: ${f.exploit_steps}
- evidence: ${f.code_evidence || 'n/a'}

${k.ask}

Return the full structured verdict (fill the fields your axis covers; leave others as best-effort). Cite file:line and the exact on-chain reads.`,
    { label:`gate:${k.key}#${f._id}`, phase:'Gate', schema:VERDICT_SCHEMA, effort:'xhigh' }
  ).then(v => ({ killer:k.key, v: v || null }))
)).then(parts => {
  const g = Object.fromEntries(parts.map(p => [p.killer, p.v]))
  const val = g['onchain-validite'] || {}
  const rec = g['recevabilite-gates'] || {}
  const mat = g['materialite-redteam'] || {}
  // Decision per the standard: VALIDITÉ then RECEVABILITÉ then MATÉRIALITÉ.
  const onchainFail = val.validite && (val.validite.onchain_verified === 'fail' || val.validite.mechanism === 'fail')
  const recevFail = (rec.gate1_actor==='fail') || (rec.gate3_premise==='fail') || (rec.gate4_dup==='self-dup') || (rec.gate4_dup==='dup-public') || (rec.entry_vector==='wall')
  const tierRank = { critical:0, high:1, medium:2, low:3, 'not-payable':4 }
  const realTier = (mat.gate5_real_tier) || (mat.real_tier) || 'not-payable'
  const belowFloor = (tierRank[realTier] ?? 4) > (tierRank[MINTIER] ?? 1)
  let verdict, killing
  if (onchainFail) { verdict='REJECT'; killing='VALIDITÉ/on-chain' }
  else if (recevFail) { verdict='REJECT'; killing = rec.killing_gate || (rec.entry_vector==='wall'?'entry-vector':'gate1/3/4') }
  else if (rec.gate4_dup==='dup-private-risk' && belowFloor) { verdict='REJECT'; killing='dup-private + immaterial' }
  else if (belowFloor) { verdict = (realTier==='not-payable') ? 'REJECT' : 'DOWNGRADE'; killing='gate5-materiality' }
  else { verdict = 'ACCEPT'; killing = null }
  return { ...f, _gates:g, _verdict:{ verdict, killing_gate:killing, real_tier:realTier }, }
})

// ---- BOOTSTRAP (optional, self-contained): clone repo + anchor DEPLOYED source ----
// args.bootstrap = { repoUrl, commit?, addrs:[...], chain?, workdir, evmAnchor?, authHeader? }
// Given a repo URL + deployed addresses (and NO local onchainDir), one agent clones the repo and
// runs the evm-anchor tool per address (proxy->impl + Etherscan-v2 verified source to disk), then
// sets ONCHAIN to the anchored deployed-source dir. Makes the fan-out runnable in ANY environment.
if (A.bootstrap && !ONCHAIN) {
  phase('Bootstrap')
  const b = A.bootstrap
  const setup = await agent(
`${b.authHeader || A.authHeader || ''}\nSet up the deployed-code anchor for a bug-bounty fan-out, deterministically. Run in bash, paste REAL output:
1. Clone in-scope repo: git clone ${b.repoUrl} ${b.workdir}/repo${b.commit ? ` && git -C ${b.workdir}/repo checkout ${b.commit}` : ''}
2. For EACH deployed address, resolve proxy->impl and pull Etherscan-v2 VERIFIED source to disk:
   ${(b.addrs||[]).map(a => `${b.evmAnchor||'evm-anchor.sh'} ${a} ${b.workdir}/anchor ${b.chain||1}`).join('\n   ')}
3. ls the resulting source dirs under ${b.workdir}/anchor and the repo under ${b.workdir}/repo.
Deployed-code-not-head is MANDATORY: the anchor dir (verified deployed source) is authoritative; the repo is only for diffing the scope commit against deployed. Return the absolute anchor dir to use as the deployed-source dir, the repo path, and each address's resolved impl + ContractName.`,
    { label:'bootstrap:anchor', phase:'Bootstrap',
      schema:{ type:'object', additionalProperties:false,
        properties:{ onchain_dir:{type:'string'}, repo_dir:{type:'string'}, impls:{type:'string'}, notes:{type:'string'} },
        required:['onchain_dir'] }, effort:'medium' })
  if (setup && setup.onchain_dir) { ONCHAIN = setup.onchain_dir; log(`Bootstrapped deployed anchor at ${ONCHAIN}`) }
  else throw new Error('bootstrap failed to resolve an onchain_dir; pass args.onchainDir explicitly')
}

// ---- FIND ----
phase('Find')
log(`Playbook-gated audit of ${A.target}: ${A.finders.length} finders, regime=${REGIME}, floor=${MINTIER}`)
const finderResults = await parallel(A.finders.map(spec => () =>
  agent(finderPrompt(spec), { label:`find:${spec.label}`, phase:'Find', schema:FINDING_SCHEMA, effort:'high' })
    .then(r => ({ spec:spec.label, findings:(r&&r.findings)||[] }))))

let raw = []
for (const fr of finderResults.filter(Boolean))
  for (const f of fr.findings) raw.push({ ...f, _sources:[fr.spec] })
// dedup by contract::function::title-6-words
const norm = t => (t||'').toLowerCase().replace(/[^a-z0-9]+/g,' ').trim().split(' ').slice(0,6).join(' ')
const seen = new Map()
for (const f of raw) { const k=`${(f.contract||'?').toLowerCase()}::${(f.function||'?').toLowerCase()}::${norm(f.title)}`
  if (seen.has(k)) seen.get(k)._sources.push(...f._sources); else seen.set(k,f) }
let cands = Array.from(seen.values())
cands.forEach((f,i)=>f._id=i+1)
const sev = { critical:0,high:1,medium:2,low:3,info:4 }
cands.sort((a,b)=>(sev[a.severity]??5)-(sev[b.severity]??5))
// gate critical/high/medium (low/info are pre-filtered by the floor anyway)
const toGate = cands.filter(f=>['critical','high','medium'].includes(f.severity)).slice(0,40)
log(`${raw.length} raw -> ${cands.length} deduped -> gating ${toGate.length} through the playbook`)

// ---- GATE ----
phase('Gate')
const gated = await parallel(toGate.map(f => () => auditFinding(f)))
const accepted = gated.filter(x=>x._verdict.verdict==='ACCEPT')
const downgraded = gated.filter(x=>x._verdict.verdict==='DOWNGRADE')
const latent = gated.filter(x=>x._verdict.verdict==='LATENT')
const rejected = gated.filter(x=>x._verdict.verdict==='REJECT')
log(`Playbook verdicts: ${accepted.length} ACCEPT, ${downgraded.length} DOWNGRADE, ${latent.length} LATENT, ${rejected.length} REJECT`)

// ---- SYNTHESIZE (PLAYBOOK-AUDIT format) ----
phase('Synthesize')
const pack = arr => arr.map(x=>({ id:x._id, title:x.title, contract:x.contract, function:x.function,
  claimed:x.severity, verdict:x._verdict, gates:x._gates }))
const SYNTH_SCHEMA = { type:'object', properties:{
  go_no_go:{type:'string'}, executive_summary:{type:'string'},
  submittable:{type:'array',items:{type:'object',properties:{
    title:{type:'string'}, real_tier:{type:'string'}, contract:{type:'string'},
    root_cause:{type:'string'}, materiality_calc:{type:'string'}, poc_outline:{type:'string'},
    residual_risks:{type:'string'}, recommendation:{type:'string'} },
    required:['title','real_tier','root_cause','recommendation'] }},
  killed:{type:'array',items:{type:'object',properties:{
    title:{type:'string'}, killing_gate:{type:'string'}, why:{type:'string'} },
    required:['title','killing_gate','why'] }},
}, required:['go_no_go','executive_summary','submittable','killed'] }

const synthesis = await agent(
`You are the lead auditor writing the PLAYBOOK-AUDIT report for ${A.target}, in the style of a pre-submission gate run (see the playbook's own audit format). Read: \`cat ${STD}\` and \`cat ${PLAYBOOK}\`. Apply the standard's decision rule strictly: ACCEPT only if VALIDITÉ + RECEVABILITÉ + MATÉRIALITÉ all hold at tier >= ${MINTIER}. RUTHLESSLY move to 'killed' anything refuted on-chain, out-of-scope, dup/self-dup, or immaterial-at-scale even if a finder was confident. For each submittable item give the real tier (the magnitude it TRULY reaches, not the claimed one), the materiality calc at deployed scale, a PoC outline, residual risks, and a submit/hold recommendation. Give a Phase-0 go/no-go for the whole target using the economics: ${ECON}.

VERDICTS:
${JSON.stringify({ accepted:pack(accepted), downgraded:pack(downgraded), latent:pack(latent), rejected:pack(rejected) }, null, 1)}`,
  { label:'synthesize:playbook-audit', phase:'Synthesize', schema:SYNTH_SCHEMA, effort:'max' }
)

return {
  target: A.target,
  stats: { finders:A.finders.length, raw:raw.length, deduped:cands.length, gated:toGate.length,
           accept:accepted.length, downgrade:downgraded.length, latent:latent.length, reject:rejected.length },
  accepted: pack(accepted), downgraded: pack(downgraded), latent: pack(latent), rejected: pack(rejected),
  synthesis,
}
