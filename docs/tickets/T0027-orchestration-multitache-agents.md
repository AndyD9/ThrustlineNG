# T0027 — Encadrer l'orchestration multitâche des agents

Status: Review
Owner: Andy
Branch: `docs/T0027-agent-multitasking-governance`
Phase: Gouvernance
Risk: Medium
Security-sensitive: No

## Goal

Permettre aux agents d'exécuter des sous-tâches indépendantes en parallèle sans
mélanger les tickets, branches, fichiers, validations ou responsabilités.

## Context

Le dépôt définit déjà les rôles de planification, d'implémentation et de revue,
ainsi que la règle d'un ticket par branche ou worktree. Il ne précise toutefois
pas comment plusieurs agents peuvent collaborer sur un ticket ni comment
plusieurs tickets indépendants peuvent progresser simultanément.

Sans protocole, le parallélisme peut produire des changements concurrents, des
preuves périmées, un basculement de branche dans un worktree partagé ou une PR
contenant le travail d'un autre ticket.

Cette maintenance de gouvernance est explicitement demandée par Andy le
2 août 2026. Elle est strictement documentaire et ne modifie aucune décision
produit, architecture, sécurité, donnée ou support.

T0027 est empilé sur T0026, dont le commit `7d46afc` n'est pas encore dans
`origin/main`. Sa Pull Request doit cibler la branche T0026 jusqu'à la fusion de
celle-ci, puis être rebasée ou re-ciblée vers `main`.

## Dependencies

- T0026, pour préserver l'ordre de l'index tant que sa livraison est en attente ;
- règles de périmètre et de worktree dans `AGENTS.md` ;
- rôles et cycle de ticket dans `docs/WORKFLOW.md`.

## Allowed areas

- `AGENTS.md` ;
- `docs/WORKFLOW.md` ;
- `docs/tickets/README.md` ;
- `docs/tickets/T0027-orchestration-multitache-agents.md`.

## Do not touch

- code, scripts, tests, manifests, lockfiles et workflows CI ;
- documents produit, architecture, sécurité, données, support et roadmap ;
- statuts ou Completion Reports des autres tickets ;
- branches, commits ou Pull Requests des autres tickets.

## Requirements

- désigner un coordinateur responsable par ticket ;
- privilégier les sous-tâches parallèles en lecture seule ;
- exiger des chemins disjoints et une propriété explicite avant toute écriture
  parallèle dans un worktree partagé ;
- conserver séquentiels les travaux dépendants ou portant sur une même zone ;
- réserver au coordinateur les changements de branche, commits, push et PR dans
  un worktree partagé ;
- isoler chaque ticket parallèle dans son propre worktree et sa propre branche ;
- rejouer les validations pertinentes après intégration ;
- conserver l'autorité d'Andy et toutes les limites existantes du ticket.

## Non-goals

- imposer un nombre fixe d'agents ou un outil d'orchestration ;
- autoriser plusieurs tickets dans une branche ou un worktree ;
- automatiser la création de worktrees ;
- modifier le produit ou ses frontières de confiance ;
- autoriser un agent à fusionner une Pull Request.

## Acceptance criteria

- [x] `AGENTS.md` définit les invariants du multitâche et l'isolation par
  worktree.
- [x] `docs/WORKFLOW.md` explique quand paralléliser, comment déléguer et comment
  intégrer.
- [x] Les écritures concurrentes sur un même chemin et les opérations Git
  concurrentes dans un worktree partagé sont explicitement interdites.
- [x] Les validations finales portent sur le diff intégré, pas seulement sur les
  résultats isolés des sous-agents.
- [x] Le ticket et l'index portent le même statut.
- [x] Le diff reste strictement documentaire et passe `git diff --check`.

## Security review

Non applicable : aucune frontière de confiance ou règle de sécurité produit
n'est modifiée. Le protocole conserve explicitement les décisions réservées à
Andy et les conditions d'arrêt existantes.

## Maintenance review

- dettes et problèmes connus applicables : aucun problème ouvert ne cible ces
  quatre fichiers ;
- dette créée ou aggravée : aucune constatée dans le diff final ;
- règle de sécurité ajoutée, modifiée ou à revalider : aucune ;
- contrôle manuel à automatiser : aucun contrôle déterministe justifiant un
  script pour cette première version documentaire ;
- risque résiduel : le protocole dépend de sa bonne application par le
  coordinateur et ne détecte pas automatiquement les collisions.

## Automated validation

```powershell
git diff --check
git diff --name-only docs/T0026-reconcile-t0010-delivery...HEAD
Select-String -Path AGENTS.md,docs/WORKFLOW.md -Pattern `
  'coordinateur','lecture seule','worktree','diff combiné'
```

## Manual verification

1. Vérifier qu'un audit sécurité et une recherche documentaire peuvent être
   lancés en parallèle en lecture seule.
2. Vérifier que deux modifications du même fichier restent séquentielles.
3. Vérifier que deux tickets simultanés exigent deux worktrees et deux branches.
4. Vérifier que seul le coordinateur publie le ticket et rejoue ses validations
   après intégration.

Temps cible : 5 minutes.

## Rollback

Revenir uniquement sur les quatre fichiers documentaires du ticket. Aucun état
applicatif ou persistant n'est modifié.

## Completion Report

Implémentation terminée le 2 août 2026 sur
`docs/T0027-agent-multitasking-governance`, empilée sur
`docs/T0026-reconcile-t0010-delivery`. La PR brouillon #50 cible cette branche de
base jusqu'à la fusion de T0026.

### Summary

Le dépôt autorise désormais une orchestration multitâche bornée. Un coordinateur
reste responsable du ticket ; les sous-tâches indépendantes peuvent être
parallélisées, tandis que les écritures qui se chevauchent, les dépendances et
l'intégration restent séquentielles.

### Files changed

- `AGENTS.md` ;
- `docs/WORKFLOW.md` ;
- `docs/tickets/README.md` ;
- ticket T0027.

### Commands and results

- `git status --short --branch` — branche T0027 confirmée ; aucune modification
  préexistante avant le ticket ;
- `git diff --check` — réussi, aucune erreur d'espacement ;
- contrôle des chemins modifiés et non suivis — exactement les quatre chemins
  autorisés ;
- deux premières assertions de chemins ont échoué avant la comparaison du diff :
  la première supposait un ordre de tri culturel fixe, la seconde construisait
  un tableau PowerShell imbriqué ; la comparaison d'ensembles corrigée a réussi
  sur les quatre chemins attendus ;
- `Select-String` sur `coordinateur`, `lecture seule`, `worktree` et
  `diff combiné` — les invariants sont présents dans `AGENTS.md` et leur
  procédure dans `docs/WORKFLOW.md` ;
- `gh pr view 50` — PR `OPEN`, brouillon, base
  `docs/T0026-reconcile-t0010-delivery`, head
  `docs/T0027-agent-multitasking-governance` ; CI Windows et PostgreSQL en cours,
  supply chain en attente au moment du contrôle.

### Manual verification result

Les quatre scénarios ont été relus : audit et recherche parallèles en lecture
seule, modifications d'un même fichier séquentielles, tickets simultanés isolés
par worktree et branche, publication et revalidation finales réservées au
coordinateur. Le ticket et l'index sont alignés sur `Review`.

### Risks and limitations

- les règles reposent sur leur application par le coordinateur ; aucun gate ne
  détecte automatiquement une collision d'agents ;
- T0027 est empilé sur T0026, encore absent de `origin/main` au démarrage du
  ticket ; sa PR ne doit pas être fusionnée avant T0026 sans rebase ou changement
  de base ;
- aucune exécution réellement concurrente n'est nécessaire pour valider cette
  maintenance documentaire.

### Follow-ups

- après fusion de T0026, rebaser T0027 ou changer la base de sa PR vers `main` ;
- réévaluer l'intérêt d'un contrôle automatisé seulement après des collisions
  observées ou une reproduction déterministe.

### Documentation updated

Règles globales des agents, workflow d'implémentation et index des tickets.
