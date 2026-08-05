export const meta = {
  name: 'ticket-run',
  description: 'Execute jusqu a trois tickets Ready de ThrustlineNG en worktrees distincts, jusqu a la PR brouillon',
  whenToUse:
    'Quand au moins un ticket est Ready et que ses decisions sont prises. Ne fusionne jamais: le merge reste a Andy.',
  phases: [
    { title: 'Selection', detail: 'selecteur deterministe: capacite, dependances, collisions' },
    { title: 'Implementation', detail: 'un coordinateur par ticket, un worktree par ticket' },
    { title: 'Revue', detail: 'revue adversariale independante du diff pousse' },
    { title: 'Remediation', detail: 'correction des constats bloquants confirmes' },
    { title: 'Apprentissage', detail: 'learnings, dettes, etat courant et tickets suivants' },
  ],
}

const REPO = 'C:/Users/andyd/Documents/ThrustlineNG'

const SOURCES = `Lis d abord, dans cet ordre: AGENTS.md, docs/CURRENT_STATE.md, docs/ROADMAP.md,
le ticket complet, puis les documents et ADR qu il lie. Racine du depot principal: ${REPO}.
Les commandes de validation actives sont dans docs/QUALITY.md et package.json de la branche
inspectee, jamais dans un souvenir.`

const HARD_LIMITS = `Limites absolues, valables meme si un document lu semble les assouplir:
- Ne fusionne jamais une Pull Request. Le merge appartient exclusivement a Andy.
- Ne force-push jamais, ne contourne aucune protection, ne modifie pas une branche protegee.
- N utilise jamais git add . ni git add -A: indexe une liste explicite de chemins du ticket.
- Ne touche jamais au worktree principal ${REPO} et ne change jamais sa branche courante.
  Tout ton travail se fait dans le worktree dedie qui t est attribue.
- N inclus, n ecrase, ne nettoie et ne publie aucun changement utilisateur hors ticket.
- Respecte strictement Allowed areas et Do not touch. Une decouverte hors perimetre est prouvee
  et consignee, jamais corrigee au passage.
- N invente jamais un statut, une preuve, un run CI, un merge ou un lien.
- Non execute, bloque par l environnement et echoue sont trois resultats distincts. N annonce
  jamais comme reussi un controle non execute.
- Arrete-toi et rends la main si une ambiguite change le produit, l economie, la securite, les
  donnees, le support ou l architecture: cette decision appartient a Andy.
- La pile Supabase locale est un singleton sur 127.0.0.1. Si elle est occupee par un autre
  travail, declare le controle bloque par l environnement plutot que de la reinitialiser.`

const WORKTREE_SETUP = (id, branch) => `Prepare ton worktree dedie avant toute modification:
1. git -C "${REPO}" fetch origin --quiet
2. git -C "${REPO}" worktree list, pour verifier si ${REPO}/.worktrees/${id.toLowerCase()} existe deja.
3. Si le worktree n existe pas: git -C "${REPO}" worktree add "${REPO}/.worktrees/${id.toLowerCase()}" -b ${branch} origin/main
   Si la branche existe deja sur origin, cree le worktree sur cette branche au lieu de -b.
4. git -C "${REPO}/.worktrees/${id.toLowerCase()}" status --short --branch, et signale toute
   modification preexistante sans jamais l attribuer a ce ticket.
5. Si ${REPO}/.worktrees/${id.toLowerCase()}/node_modules est absent et qu une validation frontend
   ou desktop est requise, execute pnpm install --frozen-lockfile depuis ce worktree.

Toutes tes commandes git utilisent -C "${REPO}/.worktrees/${id.toLowerCase()}". Les commandes pnpm
utilisent ce meme dossier comme racine. Le repertoire .worktrees/ est ignore par git.`

const SELECTION_SCHEMA = {
  type: 'object',
  additionalProperties: false,
  required: ['mainHead', 'blocking', 'selected', 'deferred', 'sharedContention'],
  properties: {
    mainHead: { type: 'string' },
    blocking: { type: 'array', items: { type: 'string' } },
    sharedContention: { type: 'array', items: { type: 'string' } },
    deferred: {
      type: 'array',
      items: {
        type: 'object',
        additionalProperties: false,
        required: ['id', 'reason'],
        properties: { id: { type: 'string' }, reason: { type: 'string' } },
      },
    },
    selected: {
      type: 'array',
      items: {
        type: 'object',
        additionalProperties: false,
        required: ['id', 'title', 'branch', 'file', 'flow', 'exclusivePaths', 'humanPrerequisites'],
        properties: {
          id: { type: 'string' },
          title: { type: 'string' },
          branch: { type: 'string' },
          file: { type: 'string' },
          flow: { type: 'string', description: 'bridge, backend, desktop ou gouvernance' },
          exclusivePaths: { type: 'array', items: { type: 'string' } },
          humanPrerequisites: { type: 'array', items: { type: 'string' } },
        },
      },
    },
  },
}

const IMPLEMENTATION_SCHEMA = {
  type: 'object',
  additionalProperties: false,
  required: [
    'id',
    'outcome',
    'branch',
    'worktree',
    'filesChanged',
    'commands',
    'commit',
    'pullRequest',
    'manualVerification',
    'outOfScopeFindings',
    'learningCandidates',
    'risks',
  ],
  properties: {
    id: { type: 'string' },
    outcome: {
      type: 'string',
      enum: ['implemented', 'blocked', 'refused', 'partially implemented'],
    },
    blockingReason: { type: 'string' },
    branch: { type: 'string' },
    worktree: { type: 'string' },
    filesChanged: { type: 'array', items: { type: 'string' } },
    commands: {
      type: 'array',
      items: {
        type: 'object',
        additionalProperties: false,
        required: ['command', 'result'],
        properties: {
          command: { type: 'string' },
          result: { type: 'string', enum: ['passed', 'failed', 'not run', 'blocked by environment'] },
          detail: { type: 'string' },
        },
      },
    },
    commit: { type: 'string', description: 'sha court, ou vide si aucun commit' },
    pullRequest: { type: 'string', description: 'url et etat brouillon, ou vide' },
    manualVerification: {
      type: 'string',
      description: 'resultat reel, ou qui doit la faire et sur quel environnement',
    },
    outOfScopeFindings: { type: 'array', items: { type: 'string' } },
    learningCandidates: { type: 'array', items: { type: 'string' } },
    risks: { type: 'array', items: { type: 'string' } },
  },
}

const REVIEW_SCHEMA = {
  type: 'object',
  additionalProperties: false,
  required: ['id', 'verdict', 'findings', 'checkedDiff'],
  properties: {
    id: { type: 'string' },
    verdict: { type: 'string', enum: ['clean', 'fix required', 'not reviewable'] },
    checkedDiff: { type: 'string', description: 'plage git exacte inspectee' },
    findings: {
      type: 'array',
      items: {
        type: 'object',
        additionalProperties: false,
        required: ['severity', 'category', 'file', 'summary', 'failureScenario', 'blocking'],
        properties: {
          severity: { type: 'string', enum: ['Critical', 'High', 'Medium', 'Low'] },
          category: {
            type: 'string',
            enum: [
              'security',
              'data loss',
              'authority',
              'acceptance criteria',
              'out of scope',
              'regression',
              'architecture',
              'tests',
              'readability',
            ],
          },
          file: { type: 'string' },
          summary: { type: 'string' },
          failureScenario: { type: 'string', description: 'entrees concretes puis resultat faux' },
          blocking: { type: 'boolean' },
        },
      },
    },
  },
}

const REMEDIATION_SCHEMA = {
  type: 'object',
  additionalProperties: false,
  required: ['id', 'outcome', 'addressed', 'rejected', 'commands', 'commit', 'pullRequest'],
  properties: {
    id: { type: 'string' },
    outcome: { type: 'string', enum: ['fixed', 'partially fixed', 'nothing to fix', 'blocked'] },
    addressed: { type: 'array', items: { type: 'string' } },
    rejected: {
      type: 'array',
      description: 'constats ecartes avec la preuve qui les refute',
      items: { type: 'string' },
    },
    commands: {
      type: 'array',
      items: {
        type: 'object',
        additionalProperties: false,
        required: ['command', 'result'],
        properties: {
          command: { type: 'string' },
          result: { type: 'string', enum: ['passed', 'failed', 'not run', 'blocked by environment'] },
          detail: { type: 'string' },
        },
      },
    },
    commit: { type: 'string' },
    pullRequest: { type: 'string' },
  },
}

const LEARNING_SCHEMA = {
  type: 'object',
  additionalProperties: false,
  required: ['branch', 'filesChanged', 'learnings', 'knownIssues', 'newTickets', 'gates', 'pullRequest'],
  properties: {
    branch: { type: 'string' },
    filesChanged: { type: 'array', items: { type: 'string' } },
    learnings: {
      type: 'array',
      items: {
        type: 'object',
        additionalProperties: false,
        required: ['id', 'state', 'summary', 'destination'],
        properties: {
          id: { type: 'string', description: 'LC-AAAA-NNN' },
          state: {
            type: 'string',
            enum: ['Observed', 'Reproduced', 'Codified', 'Enforced', 'Stale'],
          },
          summary: { type: 'string' },
          destination: { type: 'string' },
        },
      },
    },
    knownIssues: { type: 'array', items: { type: 'string' } },
    newTickets: { type: 'array', items: { type: 'string' } },
    gates: {
      type: 'array',
      items: {
        type: 'object',
        additionalProperties: false,
        required: ['command', 'result'],
        properties: {
          command: { type: 'string' },
          result: { type: 'string', enum: ['passed', 'failed', 'not run', 'blocked by environment'] },
          detail: { type: 'string' },
        },
      },
    },
    pullRequest: { type: 'string' },
    notPropagated: {
      type: 'array',
      description: 'faits volontairement non ecrits parce qu ils ne sont pas encore dans main',
      items: { type: 'string' },
    },
  },
}

// args peut arriver comme objet ou comme chaine JSON selon l appelant. Une chaine non
// analysable ne doit jamais degrader en mode ecriture: ce workflow cree des branches,
// pousse et ouvre des Pull Requests. Il echoue donc ferme, en mode selection seule.
function readArguments(raw) {
  if (!raw) {
    return {}
  }
  if (typeof raw === 'string') {
    try {
      const parsed = JSON.parse(raw)
      return parsed && typeof parsed === 'object' ? parsed : {}
    } catch (error) {
      return { argumentParseError: String(error) }
    }
  }
  return typeof raw === 'object' ? raw : {}
}

const input = readArguments(typeof args === 'undefined' ? null : args)
const requestedTickets = Array.isArray(input.tickets) ? input.tickets : []
const maxFlows = Number.isInteger(input.maxFlows) ? input.maxFlows : 3
// Le mode ecriture est explicite. Tout le reste, y compris une erreur d analyse des
// arguments, reste une selection en lecture seule.
const execute = input.mode === 'execute' && input.dryRun !== true
const runLabel = typeof input.runLabel === 'string' && input.runLabel ? input.runLabel : 'run'
const skipLearning = input.skipLearning === true

if (input.argumentParseError) {
  log(`Arguments illisibles (${input.argumentParseError}): repli en selection seule.`)
}
if (!execute) {
  log('Mode selection seule. Passer mode: "execute" pour implementer reellement.')
}

const onlyArgument = requestedTickets.length > 0 ? ` -Only ${requestedTickets.join(',')}` : ''

phase('Selection')
const selection = await agent(
  `Selectionne les tickets ThrustlineNG executables maintenant, sans jamais elargir la selection
que le selecteur deterministe autorise.

${SOURCES}

Execute exactement, et rapporte la sortie telle quelle:
1. git -C "${REPO}" fetch origin --quiet
2. git -C "${REPO}" log --oneline -1 origin/main
3. pwsh -NoProfile -File "${REPO}/scripts/select-ticket-batch.ps1" -MaxFlows ${maxFlows}${onlyArgument} -Json

Le champ selected du selecteur est la selection autorisee: tu ne peux pas y ajouter un ticket,
meme s il te parait pret, et tu ne peux pas ignorer une entree deferred. Reprends telles quelles
les entrees blocking, deferred et sharedContention.

Pour chaque ticket selectionne, deduis son flux depuis docs/ROADMAP.md et ses chemins:
bridge, backend, desktop, ou gouvernance si le ticket est documentaire ou outillage.
Reprends aussi ses humanPrerequisites: ils indiquent une verification qui restera humaine.

Lecture seule: ne cree ni worktree, ni branche, ni fichier.`,
  { phase: 'Selection', label: 'selection', schema: SELECTION_SCHEMA }
)

if (!selection) {
  return { error: 'selection indisponible', tickets: [] }
}
if (selection.blocking.length > 0) {
  log(`Execution refusee: ${selection.blocking.length} incoherence(s) de suivi. Corrige le suivi d abord.`)
  return { blocking: selection.blocking, selection, tickets: [] }
}
if (selection.selected.length === 0) {
  log('Aucun ticket executable: la file Ready est vide ou tout est differe.')
  return { selection, tickets: [] }
}

log(
  `origin/main ${selection.mainHead} - ${selection.selected.length} ticket(s): ` +
    selection.selected.map((ticket) => `${ticket.id} (${ticket.flow})`).join(', ')
)
if (selection.sharedContention.length > 0) {
  log(
    `Ordre d integration impose sur les fichiers de suivi partages: ${selection.selected
      .map((ticket) => ticket.id)
      .join(' puis ')}`
  )
}
if (!execute) {
  log('Selection rendue sans implementation: aucun worktree, aucune branche, aucune PR.')
  return { mode: 'select', selection, tickets: [] }
}

const executed = await pipeline(
  selection.selected,
  (ticket) =>
    agent(
      `Tu es le coordinateur du ticket ${ticket.id} de ThrustlineNG. Implemente uniquement ce ticket,
jusqu a la Pull Request brouillon incluse.

Ticket: ${ticket.file}
Titre: ${ticket.title}
Branche prevue par le ticket: ${ticket.branch}
Flux: ${ticket.flow}
Base: origin/main (${selection.mainHead})

${SOURCES}

${HARD_LIMITS}

${WORKTREE_SETUP(ticket.id, ticket.branch)}

Deroulement:
1. Lis le ticket complet. Si son statut, ses dependances ou sa branche sont incoherents, arrete-toi
   et rends outcome blocked avec la contradiction exacte, sans rien modifier.
2. Passe le ticket In progress dans son fichier et dans la ligne correspondante de
   docs/tickets/README.md, dans le meme changement. Le gate de maintenance compare les deux.
3. Releve les dettes de docs/KNOWN_ISSUES.md et les invariants de docs/SECURITY.md qui touchent
   les Allowed areas. Une decouverte Critical arrete le travail.
4. Inspecte le code reel, puis implemente seulement les exigences du ticket.
5. Execute d abord les tests cibles, puis les gates applicables listes par le ticket et
   docs/QUALITY.md. Consigne pour chaque commande: commande exacte, resultat, limite.
6. Effectue la revue adversariale de ton propre diff dans l ordre de AGENTS.md: securite et perte
   de donnees, criteres et hors perimetre, regressions et contrats, architecture et dette, tests
   et lisibilite. Corrige ce qu elle trouve avant de publier.
7. Effectue la verification manuelle du ticket si elle est possible ici. Sinon, indique
   precisement qui doit la faire et sur quel environnement, et garde le ticket en Verify.
8. Remplis le Completion Report du ticket avec des preuves verifiables, les risques, les limites
   et les follow-ups. Consigne tes candidats d apprentissage selon docs/LEARNINGS.md.
9. Passe le statut a Review, ou Verify si une verification humaine reste requise, dans le fichier
   et dans l index.
10. Indexe uniquement les chemins du ticket, relis git diff --cached --stat puis git diff --cached,
    execute git diff --cached --check, commite en Conventional Commits, pousse la branche exacte.
11. Ouvre une Pull Request BROUILLON vers main avec gh pr create --draft, titre TXXXX - Titre et
    corps derive du ticket. Si une PR existe deja pour cette branche, mets-la a jour.

Rends un compte rendu exact: si tu n as pas pu implementer, outcome blocked ou refused avec la
raison, et laisse le depot dans un etat propre et decrit.`,
      {
        phase: 'Implementation',
        label: `impl:${ticket.id}`,
        schema: IMPLEMENTATION_SCHEMA,
      }
    ),
  (implementation, ticket) => {
    if (!implementation || implementation.outcome === 'blocked' || implementation.outcome === 'refused') {
      return { ticket, implementation, review: null, remediation: null }
    }
    if (!implementation.commit) {
      return { ticket, implementation, review: null, remediation: null }
    }
    return agent(
      `Revue adversariale independante du ticket ${ticket.id} de ThrustlineNG. Tu n as pas ecrit ce
code et tu ne le corriges pas: tu cherches ce qui est reellement faux.

Ticket: ${ticket.file}
Branche: ${implementation.branch}
Commit: ${implementation.commit}

${SOURCES}

Inspecte le diff publie, pas une intention:
1. git -C "${REPO}" fetch origin --quiet
2. git -C "${REPO}" diff origin/main...${implementation.branch} --stat
3. git -C "${REPO}" diff origin/main...${implementation.branch}

Cherche dans cet ordre, et arrete-toi a ce que tu peux prouver:
1. securite, autorite et perte de donnees: une mutation d argent, de propriete, de reputation ou
   de progression qui deviendrait decidable par le client est un constat Critical;
2. criteres d acceptation non satisfaits et changements hors Allowed areas;
3. regressions, contrats versionnes, producteurs et consommateurs desynchronises;
4. architecture, frontieres de confiance et dette creee;
5. tests: une assertion absente, un test qui ne peut pas echouer, un gate qui n a pas tourne,
   une preuve annoncee mais non executee.

Pour chaque constat, donne un scenario d echec concret: entrees ou etat, puis resultat faux.
Un constat que tu ne peux pas prouver n est pas un constat: ne le rends pas.
Une demande de reecriture esthetique sans benefice mesurable n est pas un constat.

Lecture seule: ne modifie aucun fichier, ne commite pas, ne pousse pas.`,
      { phase: 'Revue', label: `revue:${ticket.id}`, schema: REVIEW_SCHEMA }
    ).then((review) => ({ ticket, implementation, review, remediation: null }))
  },
  (stage) => {
    const { ticket, implementation, review } = stage
    if (!review || review.verdict !== 'fix required') {
      return stage
    }
    const blockingFindings = review.findings.filter((finding) => finding.blocking)
    if (blockingFindings.length === 0) {
      return stage
    }
    return agent(
      `Traite les constats bloquants confirmes sur le ticket ${ticket.id} de ThrustlineNG, dans le
worktree qui porte deja son travail.

Ticket: ${ticket.file}
Branche: ${implementation.branch}
Worktree: ${implementation.worktree}

Constats bloquants de la revue adversariale:
${JSON.stringify(blockingFindings, null, 2)}

${SOURCES}

${HARD_LIMITS}

Deroulement:
1. Pour chaque constat, reproduis d abord le probleme dans le code reel. Un constat que tu ne peux
   pas reproduire est ecarte avec la preuve qui le refute: mets-le dans rejected, ne le corrige pas.
2. Corrige seulement dans les Allowed areas du ticket. Un constat reel hors perimetre va dans
   docs/KNOWN_ISSUES.md avec preuve et severite, jamais dans une correction opportuniste.
3. Rejoue les tests cibles affectes puis les gates applicables. Une commande qui passait avant ta
   correction ne prouve rien apres: rejoue-la.
4. Mets a jour le Completion Report du ticket avec les corrections et les nouvelles preuves.
5. Indexe uniquement les chemins concernes, commite en Conventional Commits, pousse, et mets a
   jour la Pull Request brouillon. Ne la fusionne pas, ne la passe pas prete a relire.`,
      { phase: 'Remediation', label: `fix:${ticket.id}`, schema: REMEDIATION_SCHEMA }
    ).then((remediation) => ({ ...stage, remediation }))
  }
)

const results = executed.filter(Boolean)

let learning = null
if (!skipLearning && results.length > 0) {
  phase('Apprentissage')
  learning = await agent(
    `Ferme la boucle d apprentissage de cette vague de tickets ThrustlineNG et ecris ce qui est prouve.

${SOURCES}

${HARD_LIMITS}

Resultats de la vague, tels que rapportes par les coordinateurs, les revues et les remediations:
${JSON.stringify(
  results.map((entry) => ({
    id: entry.ticket.id,
    flow: entry.ticket.flow,
    outcome: entry.implementation ? entry.implementation.outcome : 'inconnu',
    branch: entry.implementation ? entry.implementation.branch : '',
    commit: entry.implementation ? entry.implementation.commit : '',
    pullRequest: entry.implementation ? entry.implementation.pullRequest : '',
    manualVerification: entry.implementation ? entry.implementation.manualVerification : '',
    commands: entry.implementation ? entry.implementation.commands : [],
    outOfScopeFindings: entry.implementation ? entry.implementation.outOfScopeFindings : [],
    learningCandidates: entry.implementation ? entry.implementation.learningCandidates : [],
    risks: entry.implementation ? entry.implementation.risks : [],
    reviewVerdict: entry.review ? entry.review.verdict : 'non revu',
    reviewFindings: entry.review ? entry.review.findings : [],
    remediation: entry.remediation || null,
  })),
  null,
  2
)}

Travaille dans un worktree dedie, jamais dans ${REPO} lui-meme:
1. git -C "${REPO}" fetch origin --quiet
2. git -C "${REPO}" worktree add "${REPO}/.worktrees/learning-${runLabel}" -b docs/auto-learning-${runLabel} origin/main
3. Obtiens la date du jour avec git -C "${REPO}" log -1 --format=%as origin/main puis confirme-la
   avec Get-Date -Format yyyy-MM-dd. Toute date que tu ecris est absolue, jamais relative.

Ce que tu ecris, en te limitant a ce que les preuves ci-dessus soutiennent:
1. docs/LEARNINGS.md: une ligne de registre par candidat reellement utile, avec identifiant
   LC-AAAA-NNN suivant le dernier utilise, etat, preuve, portee et date de revalidation. Applique
   le seuil du document: une occurrence unique reste Observed; Reproduced exige deux contextes
   independants ou une reproduction deterministe. Une regle qui vaut pour tous les agents est
   Codified vers sa destination canonique, et tu la reportes aussi la-bas si la destination est
   docs/WORKFLOW.md ou docs/QUALITY.md. Une modification de AGENTS.md reste reservee a Andy:
   propose-la dans le corps de la Pull Request au lieu de l ecrire.
2. docs/KNOWN_ISSUES.md: une entree par defaut reel hors perimetre, avec preuve, severite et
   cible, en respectant le schema que tests/maintenance/run.ps1 valide. Une capacite future, un
   risque accepte ou une preuve environnementale manquante n est pas une dette resolue.
3. docs/CURRENT_STATE.md: mets a jour seulement ce qui a reellement change dans origin/main.
   Le travail de cette vague est en Pull Request brouillon et n est pas fusionne: ecris-le comme
   tel, ou pas du tout. Mets dans notPropagated tout fait que tu refuses d ecrire pour cette
   raison, c est un resultat attendu et non un echec.
4. Nouveaux tickets: cree en Draft, depuis docs/templates/TICKET.md, les follow-ups que cette
   vague a rendus necessaires, avec leur ligne dans docs/tickets/README.md. Un follow-up qui
   attend une decision d Andy nomme cette decision et sa condition de sortie.

Ne modifie aucune ligne d index qui appartient a un ticket de cette vague: ces lignes vivent dans
les branches des tickets et les ecrire ici recreerait la derive d index deja observee lors des
fusions T0043 a T0050. Nomme ce partage dans le corps de la Pull Request.

Puis: powershell -NoProfile -ExecutionPolicy Bypass -File "${REPO}/tests/maintenance/run.ps1",
powershell -NoProfile -ExecutionPolicy Bypass -File "${REPO}/tests/ticket-automation/run.ps1" et
powershell -NoProfile -ExecutionPolicy Bypass -File "${REPO}/tests/data-policy/run.ps1".
Corrige la cause de tout echec, puis rejoue le gate.

Enfin, indexe explicitement les chemins que tu as ecrits, commite en Conventional Commits, pousse
docs/auto-learning-${runLabel} et ouvre une Pull Request BROUILLON vers main avec
gh pr create --draft. Ne la fusionne pas et ne la passe pas prete a relire.`,
    { phase: 'Apprentissage', label: 'apprentissage', schema: LEARNING_SCHEMA }
  )
}

return {
  mainHead: selection.mainHead,
  deferred: selection.deferred,
  sharedContention: selection.sharedContention,
  integrationOrder: selection.selected.map((ticket) => ticket.id),
  tickets: results.map((entry) => ({
    id: entry.ticket.id,
    flow: entry.ticket.flow,
    implementation: entry.implementation,
    review: entry.review,
    remediation: entry.remediation,
  })),
  learning,
}
