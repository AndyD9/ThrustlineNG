export const meta = {
  name: 'ticket-plan',
  description: 'Ecrit ou met a jour la prochaine vague de tickets ThrustlineNG depuis l etat prouve',
  whenToUse:
    'Quand la file de tickets Ready est vide ou perimee, avant /ticket-run. Produit des tickets Draft/Ready et le lot de decisions reservees a Andy.',
  phases: [
    { title: 'Inventaire', detail: 'selecteur deterministe, etat prouve, roadmap, dettes' },
    { title: 'Cadrage', detail: 'un proposeur par flux: bridge, backend, desktop' },
    { title: 'Redaction', detail: 'un redacteur par ticket, fichier propre uniquement' },
    { title: 'Consolidation', detail: 'index, gates, lot de decisions pour Andy' },
  ],
}

const REPO = 'C:/Users/andyd/Documents/ThrustlineNG'

const SOURCES = `Lis d abord, dans cet ordre: AGENTS.md, docs/CURRENT_STATE.md, docs/ROADMAP.md,
docs/WORKFLOW.md, docs/tickets/README.md, docs/KNOWN_ISSUES.md et docs/templates/TICKET.md.
Racine du depot: ${REPO}. Travaille uniquement dans cette racine, sur la branche courante.
Ne change jamais de branche, ne commite pas, ne pousse pas, n ouvre aucune Pull Request.`

const NON_NEGOTIABLE = `Regles non negociables:
- Une branche ou une PR non fusionnee n est jamais une capacite livree dans main. Verifie avec
  git log origin/main, jamais avec un souvenir ou un rapport de ticket.
- Toute ambiguite qui change le produit, l economie, la securite, les donnees, le support ou
  l architecture appartient a Andy: elle devient une entree de decisionsNeeded, pas une invention.
- Un ticket dont une decision d Andy manque reste Draft. Seul un ticket entierement cadre devient Ready.
- N invente jamais un statut, une preuve, un run CI, un merge ou un lien.`

const STATE_SCHEMA = {
  type: 'object',
  additionalProperties: false,
  required: ['mainHead', 'selector', 'openTickets', 'flows', 'blocking'],
  properties: {
    mainHead: { type: 'string', description: 'sha court et sujet du HEAD de origin/main' },
    selector: {
      type: 'object',
      additionalProperties: true,
      description: 'rapport JSON brut de scripts/select-ticket-batch.ps1',
    },
    openTickets: {
      type: 'array',
      items: {
        type: 'object',
        additionalProperties: false,
        required: ['id', 'status', 'blockingReason'],
        properties: {
          id: { type: 'string' },
          status: { type: 'string' },
          blockingReason: { type: 'string', description: 'vide si rien ne bloque' },
        },
      },
    },
    flows: {
      type: 'array',
      description: 'etat des trois flux du mode accelere',
      items: {
        type: 'object',
        additionalProperties: false,
        required: ['flow', 'lastDelivered', 'nextOutcome', 'gapEvidence'],
        properties: {
          flow: { type: 'string', enum: ['bridge', 'backend', 'desktop'] },
          lastDelivered: { type: 'string', description: 'derniere capacite reellement dans main' },
          nextOutcome: { type: 'string', description: 'prochain resultat utilisateur manquant' },
          gapEvidence: { type: 'string', description: 'fichier, migration ou test qui prouve le manque' },
        },
      },
    },
    blocking: {
      type: 'array',
      description: 'incoherences a corriger avant toute planification',
      items: { type: 'string' },
    },
  },
}

const PROPOSAL_SCHEMA = {
  type: 'object',
  additionalProperties: false,
  required: [
    'flow',
    'proposed',
    'skipReason',
  ],
  properties: {
    flow: { type: 'string' },
    skipReason: {
      type: 'string',
      description: 'vide si un ticket est propose; sinon pourquoi ce flux n a rien a proposer',
    },
    proposed: {
      type: 'object',
      additionalProperties: false,
      required: [
        'title',
        'goal',
        'phase',
        'risk',
        'securitySensitive',
        'dependencies',
        'allowedAreas',
        'doNotTouch',
        'requirements',
        'nonGoals',
        'acceptanceCriteria',
        'automatedValidation',
        'manualVerification',
        'decisionsNeeded',
        'readyForImplementation',
      ],
      properties: {
        title: { type: 'string', description: 'titre oriente resultat, en francais' },
        goal: { type: 'string', description: 'un seul resultat observable' },
        phase: { type: 'string' },
        risk: { type: 'string', enum: ['Low', 'Medium', 'High'] },
        securitySensitive: { type: 'boolean' },
        dependencies: { type: 'array', items: { type: 'string' } },
        allowedAreas: {
          type: 'array',
          description: 'chemins exacts, disjoints des autres flux',
          items: { type: 'string' },
        },
        doNotTouch: { type: 'array', items: { type: 'string' } },
        requirements: { type: 'array', items: { type: 'string' } },
        nonGoals: { type: 'array', items: { type: 'string' } },
        acceptanceCriteria: { type: 'array', items: { type: 'string' } },
        automatedValidation: {
          type: 'array',
          description: 'commandes exactes existantes du package.json ou des scripts',
          items: { type: 'string' },
        },
        manualVerification: { type: 'array', items: { type: 'string' } },
        decisionsNeeded: {
          type: 'array',
          description: 'decisions reservees a Andy, vide si aucune',
          items: {
            type: 'object',
            additionalProperties: false,
            required: ['question', 'why', 'options'],
            properties: {
              question: { type: 'string' },
              why: { type: 'string', description: 'ce qui change dans le produit selon la reponse' },
              options: { type: 'array', items: { type: 'string' } },
            },
          },
        },
        readyForImplementation: {
          type: 'boolean',
          description: 'true seulement si aucune decision d Andy ne manque',
        },
      },
    },
  },
}

const WRITTEN_SCHEMA = {
  type: 'object',
  additionalProperties: false,
  required: ['id', 'file', 'status', 'title', 'branch', 'allowedAreas', 'notes'],
  properties: {
    id: { type: 'string' },
    file: { type: 'string' },
    status: { type: 'string', enum: ['Draft', 'Ready'] },
    title: { type: 'string' },
    branch: { type: 'string' },
    allowedAreas: { type: 'array', items: { type: 'string' } },
    notes: { type: 'string' },
  },
}

const CONSOLIDATION_SCHEMA = {
  type: 'object',
  additionalProperties: false,
  required: ['indexUpdated', 'gates', 'selectorAfter', 'decisions', 'residualRisks'],
  properties: {
    indexUpdated: { type: 'array', items: { type: 'string' } },
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
    selectorAfter: { type: 'string', description: 'sortie texte du selecteur apres ecriture' },
    decisions: {
      type: 'array',
      items: {
        type: 'object',
        additionalProperties: false,
        required: ['ticket', 'question', 'why', 'options'],
        properties: {
          ticket: { type: 'string' },
          question: { type: 'string' },
          why: { type: 'string' },
          options: { type: 'array', items: { type: 'string' } },
        },
      },
    },
    residualRisks: { type: 'array', items: { type: 'string' } },
  },
}

// args peut arriver comme objet ou comme chaine JSON selon l appelant: une chaine non
// analysable retombe sur les valeurs par defaut au lieu d elargir le perimetre.
function readArguments(raw) {
  if (!raw) {
    return {}
  }
  if (typeof raw === 'string') {
    try {
      const parsed = JSON.parse(raw)
      return parsed && typeof parsed === 'object' ? parsed : {}
    } catch (error) {
      return {}
    }
  }
  return typeof raw === 'object' ? raw : {}
}

const input = readArguments(typeof args === 'undefined' ? null : args)
const allFlows = ['bridge', 'backend', 'desktop']
const requestedFlows = Array.isArray(input.flows) && input.flows.length > 0 ? input.flows : allFlows
const maxTickets = Number.isInteger(input.maxTickets) ? Math.min(input.maxTickets, 3) : 3

phase('Inventaire')
const state = await agent(
  `Etablis l etat reellement prouve du depot ThrustlineNG avant de planifier des tickets.

${SOURCES}

${NON_NEGOTIABLE}

Execute exactement, depuis la racine, et rapporte les sorties telles quelles:
1. git -C "${REPO}" fetch origin --quiet
2. git -C "${REPO}" log --oneline -1 origin/main
3. pwsh -NoProfile -File "${REPO}/scripts/select-ticket-batch.ps1" -Json
4. pwsh -NoProfile -File "${REPO}/tests/ticket-automation/run.ps1"

Pour chaque flux du mode accelere (bridge, backend, desktop), etablis la derniere capacite
presente dans origin/main et le prochain resultat manquant. Prouve chaque manque par un chemin
de fichier, une migration absente ou un test absent, jamais par une intention de roadmap.

Si le selecteur sort en echec, mets ses entrees blocking dans blocking et n invente aucun plan.
Lecture seule: ne modifie aucun fichier.`,
  { phase: 'Inventaire', label: 'inventaire', schema: STATE_SCHEMA }
)

if (!state) {
  return { error: 'inventaire indisponible', tickets: [], decisions: [] }
}
if (state.blocking && state.blocking.length > 0) {
  log(`Planification refusee: ${state.blocking.length} incoherence(s) de suivi a corriger d abord.`)
  return { blocking: state.blocking, tickets: [], decisions: [], state }
}

const flowsToScope = state.flows
  .filter((flow) => requestedFlows.includes(flow.flow))
  .slice(0, maxTickets)

log(`Cadrage de ${flowsToScope.length} flux depuis origin/main ${state.mainHead}`)

phase('Cadrage')
const proposals = await parallel(
  flowsToScope.map((flow) => () =>
    agent(
      `Propose au plus un prochain ticket pour le flux ${flow.flow} de ThrustlineNG.

${SOURCES}

${NON_NEGOTIABLE}

Etat etabli pour ce flux:
- derniere capacite dans main: ${flow.lastDelivered}
- prochain resultat manquant: ${flow.nextOutcome}
- preuve du manque: ${flow.gapEvidence}

Contraintes de dimensionnement, tirees de docs/WORKFLOW.md:
- un seul resultat observable, une frontiere principale, un diff revisable;
- verifiable manuellement en 5 a 10 minutes;
- abandonnable sans invalider plusieurs jours de travail;
- si le ticket combine migration, nouveau protocole, gros ecran et pipeline release, reduis le.

Contraintes de chemins: allowedAreas doit etre disjoint des deux autres flux. Les fichiers de
suivi partages docs/tickets/README.md, docs/CURRENT_STATE.md et docs/KNOWN_ISSUES.md peuvent
apparaitre, mais aucun autre chemin ne doit pouvoir etre reclame par un autre flux.

automatedValidation ne contient que des commandes qui existent reellement: lis package.json et
scripts/ de la branche avant de les citer. N invente aucune commande.

Si ce flux n a rien de borne a proposer, renseigne skipReason et laisse proposed vide de sens.
Lecture seule: ne cree ni ne modifie aucun fichier.`,
      { phase: 'Cadrage', label: `cadrage:${flow.flow}`, schema: PROPOSAL_SCHEMA }
    )
  )
)

const usable = proposals
  .filter(Boolean)
  .filter((proposal) => !proposal.skipReason && proposal.proposed && proposal.proposed.title)

if (usable.length === 0) {
  log('Aucun ticket a rediger: chaque flux a renvoye un skipReason.')
  return {
    tickets: [],
    decisions: [],
    skipped: proposals.filter(Boolean).map((p) => ({ flow: p.flow, reason: p.skipReason })),
    state,
  }
}

log(`${usable.length} proposition(s) retenue(s), redaction sequentielle des fichiers de ticket.`)

phase('Redaction')
const written = []
for (let index = 0; index < usable.length; index++) {
  const proposal = usable[index]
  const result = await agent(
    `Ecris le fichier de ticket ThrustlineNG correspondant a cette proposition.

${SOURCES}

${NON_NEGOTIABLE}

Proposition pour le flux ${proposal.flow}:
${JSON.stringify(proposal.proposed, null, 2)}

Procedure:
1. Determine le prochain identifiant libre en listant docs/tickets/T????-*.md ET en verifiant
   git -C "${REPO}" ls-tree --name-only origin/main docs/tickets/ apres un fetch, puis prends le
   plus grand numero des deux listes plus un. Un identifiant libre localement peut avoir ete pris
   par une autre session: l allocation se constate sur origin/main, elle ne se reserve pas. ${index > 0 ? `Les tickets deja ecrits dans cette vague sont: ${written.map((w) => w.id).join(', ')}. N y touche pas et prends le numero suivant.` : ''}
2. Copie la structure exacte de docs/templates/TICKET.md, sans omettre une section.
3. Nomme le fichier docs/tickets/TXXXX-slug-en-francais-sans-accent.md.
4. Renseigne Status: ${proposal.proposed.readyForImplementation && proposal.proposed.decisionsNeeded.length === 0 ? 'Ready' : 'Draft'}.
   Un ticket avec une decision manquante reste Draft, et la section Context doit nommer la
   decision attendue ainsi que sa condition de sortie.
5. Renseigne Branch avec type/txxxx-slug en choisissant le type parmi foundation, feature, fix,
   security, refactor, docs, chore.
6. Remplis Security review si Security-sensitive vaut Yes, et Maintenance review dans tous les cas.
7. Laisse Completion Report vide, avec ses sous-titres.

Ecris exactement un fichier: le tien. Ne touche pas docs/tickets/README.md, ni un autre ticket,
ni un autre document. La consolidation de l index est faite ensuite par un autre agent.`,
    { phase: 'Redaction', label: `redaction:${proposal.flow}`, schema: WRITTEN_SCHEMA }
  )
  if (result) {
    written.push(result)
  }
}

if (written.length === 0) {
  return { tickets: [], decisions: [], error: 'aucun fichier de ticket ecrit', state }
}

phase('Consolidation')
const consolidation = await agent(
  `Consolide l index des tickets et prouve la coherence apres l ecriture de cette vague.

${SOURCES}

${NON_NEGOTIABLE}

Tickets ecrits par la vague:
${JSON.stringify(written, null, 2)}

Decisions relevees pendant le cadrage:
${JSON.stringify(
  usable.flatMap((proposal) =>
    (proposal.proposed.decisionsNeeded || []).map((decision) => ({
      flow: proposal.flow,
      ...decision,
    }))
  ),
  null,
  2
)}

Procedure:
1. Ajoute une ligne par nouveau ticket dans le tableau de docs/tickets/README.md, en respectant
   ses cinq colonnes et l ordre croissant des identifiants. Le statut de l index doit etre
   identique au champ Status du fichier: le gate de maintenance echoue sinon.
2. Ajoute, sous le tableau, un paragraphe date qui explique pourquoi ces tickets existent et
   quelles decisions manquent. Ne reecris aucun paragraphe historique existant.
3. Execute et rapporte, avec la commande exacte et le resultat:
   - powershell -NoProfile -ExecutionPolicy Bypass -File "${REPO}/tests/maintenance/run.ps1"
   - powershell -NoProfile -ExecutionPolicy Bypass -File "${REPO}/tests/ticket-automation/run.ps1"
   - pwsh -NoProfile -File "${REPO}/scripts/select-ticket-batch.ps1"
4. Si un gate echoue, corrige la cause dans l index ou le ticket concerne, puis rejoue le gate.
   Non execute, bloque par l environnement et echoue sont trois resultats distincts.
5. Rends le lot complet des decisions d Andy, deduplique et formule chaque question de facon
   qu une reponse courte suffise a passer le ticket en Ready.

Ne commite pas, ne pousse pas, n ouvre aucune Pull Request: la publication appartient a la
session principale.`,
  { phase: 'Consolidation', label: 'consolidation', schema: CONSOLIDATION_SCHEMA }
)

return {
  mainHead: state.mainHead,
  tickets: written,
  decisions: (consolidation && consolidation.decisions) || [],
  gates: (consolidation && consolidation.gates) || [],
  selectorAfter: (consolidation && consolidation.selectorAfter) || '',
  residualRisks: (consolidation && consolidation.residualRisks) || [],
  skipped: proposals
    .filter(Boolean)
    .filter((proposal) => proposal.skipReason)
    .map((proposal) => ({ flow: proposal.flow, reason: proposal.skipReason })),
}
