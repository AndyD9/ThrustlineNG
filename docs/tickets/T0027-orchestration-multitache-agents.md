# T0027 — Encadrer l'orchestration multitâche des agents

Status: Done
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

T0027 a d'abord été empilé sur T0026. La PR #50 a été fusionnée dans cette
branche de base après que T0026 avait déjà rejoint `main` par la PR #49 ; cette
fusion ne livrait donc pas T0027 dans la branche par défaut. La branche a ensuite
été synchronisée sans réécriture avec `origin/main` et la PR #51 cible
directement `main` pour réconcilier la livraison.

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
`docs/T0027-agent-multitasking-governance`. La PR #50 a livré le diff dans la
branche T0026, mais pas dans `main`; la PR brouillon #51 cible désormais `main`
après synchronisation non destructive de la branche.

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
  supply chain en attente au moment du contrôle ;
- contrôle du 2 août 2026 après synchronisation distante : PR #50 `MERGED`
  dans la branche T0026, T0027 absent de `origin/main`, puis fusion non
  destructive de `origin/main` dans la branche et ouverture de la PR brouillon
  #51 vers `main`.

### Manual verification result

Les quatre scénarios ont été relus : audit et recherche parallèles en lecture
seule, modifications d'un même fichier séquentielles, tickets simultanés isolés
par worktree et branche, publication et revalidation finales réservées au
coordinateur. Le ticket et l'index sont alignés sur `Review`.

### Risks and limitations

- les règles reposent sur leur application par le coordinateur ; aucun gate ne
  détecte automatiquement une collision d'agents ;
- T0027 reste absent de `origin/main` tant que la PR #51 n'est pas fusionnée ;
  la PR #50 seule ne constitue pas une livraison sur la branche par défaut ;
- aucune exécution réellement concurrente n'est nécessaire pour valider cette
  maintenance documentaire.

### Follow-ups

- faire relire puis fusionner la PR #51 dans `main` ;
- réévaluer l'intérêt d'un contrôle automatisé seulement après des collisions
  observées ou une reproduction déterministe.

### Documentation updated

Règles globales des agents, workflow d'implémentation et index des tickets.

### Delivery reconciliation

Le 2 août 2026, T0033 confirme que le commit d'implémentation `2ef9343` est dans
l'ascendance de `origin/main` via la PR #51 (`70a93a3`). Les validations et la
vérification manuelle consignées ci-dessus étant terminées, T0027 passe de
`Review` à `Done` sans réécriture de la preuve historique.
