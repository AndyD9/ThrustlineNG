# T0030 — Empêcher les dettes techniques silencieuses

Status: Review
Owner: Andy
Branch: `chore/T0030-technical-debt-guardrails`
Phase: Gouvernance
Risk: Medium
Security-sensitive: No

## Goal

Rendre l'inventaire des dettes et risques vérifiable automatiquement, puis
refuser en CI toute dette de code non reliée au registre ou toute divergence de
statut entre un ticket et son index.

## Context

Le workflow de maintenance exige déjà une preuve, une priorité et un ticket
borné. Ces règles restent toutefois manuelles : les réconciliations T0025 à
T0028 ont démontré que des statuts ou livraisons peuvent dériver, et aucun gate
ne contrôle les marqueurs `TODO`, `FIXME` ou `HACK` dans le code.

La demande d'Andy du 2 août 2026 vise une campagne complète de dette technique
et des règles empêchant sa réapparition. T0030 fournit le mécanisme de contrôle ;
les corrections produit, les validations MSFS/Supabase et la distribution
signée restent des tickets distincts.

### Baseline de campagne

L'inventaire distingue les natures avant planification :

| Nature | Entrées | Traitement |
| --- | --- | --- |
| Dette de structure, couverture ou mesure | KI-005, KI-008, KI-012, KI-019 | Refactor ou test borné avec preuve de non-régression |
| Capacité de sûreté encore absente | KI-003, KI-009, KI-021 | Ticket de phase avec gate négatif ; aucune fausse clôture anticipée |
| Validation d'environnement ou de compatibilité | KI-011, KI-013, KI-014, KI-015 | Preuve sur MSFS, matériel ou Supabase concerné |
| Risque explicitement accepté | KI-010 | Revalidation de l'ADR avant la bascule, sans résolution silencieuse |
| Dette de gouvernance créée par l'absence de gate | KI-022 | Corrigée par T0030 puis conservée comme historique `Resolved` |

Cette baseline couvre toutes les entrées non résolues au démarrage de T0030.
Elle priorise ensuite la stabilité et l'absence de perte, puis les risques `High`,
avant les dettes `Medium` lorsqu'une zone devient active.

## Workflow evidence

- 2 août 2026 — `Ready` : inventaire `KNOWN_ISSUES`, workflow de maintenance,
  roadmap et gates existantes relus ; aucune entrée `Critical` ; T0028 est en
  `Review` dans la PR brouillon #54 vers `main`.
- 2 août 2026 — `In progress` : worktree isolé `.worktrees/t0030`, branche
  empilée explicitement sur `docs/T0028-production-economy-policy`.
- 2 août 2026 — `Review` : gate, huit mutations négatives, branchement CI et
  documentation terminés ; validations ciblées réussies.
- 2 août 2026 — publication : commit `909f494`, PR brouillon #55, base
  `docs/T0028-production-economy-policy`, head
  `chore/T0030-technical-debt-guardrails`.

## Dependencies

- T0027 pour les règles d'orchestration, livré dans `main` ;
- T0028 comme base temporaire jusqu'à la fusion ou au changement de base de la
  PR #54.

## Allowed areas

- `AGENTS.md` ;
- `.github/workflows/ci.yml` ;
- `package.json` ;
- `tests/ci/run.ps1`, `tests/maintenance/` ;
- `docs/MAINTENANCE.md`, `docs/QUALITY.md`, `docs/KNOWN_ISSUES.md` ;
- ce ticket et `docs/tickets/README.md`.

## Do not touch

- code applicatif, migrations, Edge Functions et contrats ;
- lockfiles, versions, dépendances et scripts de runtime ;
- statut ou Completion Report d'un autre ticket ;
- décisions produit, architecture, sécurité, données ou support ;
- correction opportuniste d'une dette déjà enregistrée.

## Requirements

- Vérifier le schéma, les identifiants, les sévérités, les statuts, les preuves
  et les cibles du registre `KNOWN_ISSUES.md`.
- Vérifier qu'un risque accepté cite une décision vérifiable et qu'une entrée
  résolue pointe vers un ticket existant.
- Vérifier que chaque ticket détaillé apparaît une seule fois dans l'index et
  porte exactement le même statut.
- Refuser `TODO`, `FIXME`, `HACK` ou `XXX` dans le code sans référence à une
  entrée `KI-NNN` encore ouverte ou planifiée.
- Ajouter des mutations négatives prouvant que le gate détecte chaque famille
  de dérive.
- Exécuter le gate sur chaque Pull Request et push vers `main`.

## Non-goals

- résoudre dans ce ticket les entrées KI-003, KI-005, KI-008 à KI-015, KI-019
  ou KI-021 ;
- transformer une capacité future ou une validation environnementale en dette ;
- fermer une entrée faute de preuve ou modifier un risque accepté par Andy ;
- provisionner un service distant ou utiliser des données réelles.

## Acceptance criteria

- [x] Le registre et l'index courants passent le nouveau gate.
- [x] Une sévérité ou un statut invalide, un doublon, une preuve absente et une
      divergence ticket/index sont détectés.
- [x] Un marqueur de dette non suivi échoue et un marqueur relié à une entrée
      active est accepté.
- [x] La CI et son propre harnais exigent le nouveau gate.
- [x] Les règles documentaires donnent un chemin clair de découverte à
      résolution sans prétendre que tous les risques sont des dettes.

## Security review

Non applicable : ce ticket ne change aucune frontière produit. Le gate lit
uniquement des fichiers versionnés et travaille sur des copies temporaires sans
secret ni donnée personnelle.

## Maintenance review

- dettes et problèmes connus applicables : nouvelle entrée KI-022 sur l'absence
  de contrôle automatisé du registre et des statuts ;
- dette créée ou aggravée : aucune attendue ;
- règle de sécurité ajoutée, modifiée ou à revalider : aucune ;
- contrôle manuel à automatiser : intégrité du registre, synchronisation des
  statuts et marqueurs de dette dans le code ;
- risque résiduel : le gate prouve la traçabilité, pas la correction des dettes
  ni les validations qui nécessitent un environnement réel.

## Automated validation

```powershell
pnpm maintenance:check
pnpm ci:check
git diff --check
```

## Manual verification

1. Relire la classification des entrées ouvertes et acceptées.
2. Ajouter dans une copie un `TODO` sans KI et confirmer le refus.
3. Relier le marqueur à une KI active et confirmer son acceptation.
4. Diverger le statut d'un ticket et de l'index puis confirmer le refus.

Temps cible : 5–10 minutes.

## Rollback

Revenir uniquement sur le gate, son branchement CI et la documentation T0030.
Aucune donnée applicative ou persistante n'est modifiée.

## Completion Report

Implémentation terminée le 2 août 2026 dans le worktree `.worktrees/t0030`, sur
`chore/T0030-technical-debt-guardrails`. La branche reste empilée sur T0028 tant
que la PR brouillon #54 n'est pas fusionnée dans `main`.

### Summary

Un gate de maintenance contrôle désormais le registre, les statuts ticket/index
et les marqueurs de dette du code. La CI exige ce gate et son harnais injecte
huit dérives pour prouver qu'il échoue utilement. La baseline distingue les
dettes corrigeables des capacités futures, risques acceptés et validations
d'environnement.

### Files changed

- gate `tests/maintenance/run.ps1`, commande racine et branchement CI ;
- auto-contrôle du workflow CI ;
- règles globales et procédures maintenance/qualité ;
- KI-022, ticket T0030 et index des tickets.

### Commands and results

- `powershell -NoProfile -ExecutionPolicy Bypass -File .\tests\maintenance\run.ps1`
  — réussi : registre, index, marqueurs et 8 mutations ;
- première exécution `pnpm.cmd run maintenance:check` dans le sandbox — aucun
  gate exécuté, restauration automatique bloquée par `EACCES` réseau ;
- relance autorisée puis exécution finale `pnpm.cmd run maintenance:check` —
  dépendances exactes restaurées sans changement de lockfile, gate réussi ;
- `powershell -NoProfile -ExecutionPolicy Bypass -File .\tests\ci\run.ps1` —
  réussi : invariants CI et 2 mutations historiques ;
- `pnpm.cmd run ci:check` — non exécuté via son wrapper : `pwsh` absent du
  `PATH` sandboxé ;
- `C:\Users\andyd\AppData\Local\Microsoft\WindowsApps\pwsh.exe` — version
  7.6.4, puis `tests/ci/run.ps1` réussi avec ce chemin explicite ;
- `git diff --check` — réussi ; avertissement informatif de future normalisation
  LF vers CRLF pour `tests/ci/run.ps1`.

### Manual verification result

Réussie par relecture et copies temporaires : la baseline couvre les douze
entrées précédemment non résolues, un marqueur sans KI est refusé, un marqueur
lié à KI-022 est accepté, une divergence T0030/index est refusée et un second
marqueur non suivi sur une ligne déjà conforme reste détecté.

### Risks and limitations

- le contrôle garantit la traçabilité, pas la découverte automatique de toute
  dette architecturale ni sa correction ;
- le scan est borné aux sources versionnées `apps`, `eng`, `scripts` et
  `supabase/functions`, pour les extensions explicitement listées ;
- KI-022 reste `Scheduled` jusqu'à la livraison de T0030 dans `main` ;
- aucune preuve MSFS, Supabase distante, matérielle ou de signature n'est
  remplacée par ce gate ;
- T0030 dépend de T0028 et devra cibler `main` seulement après livraison de la
  PR #54 ou après une réconciliation explicite de sa base.

### Follow-ups

- faire relire et fusionner la PR #54, puis synchroniser T0030 sans réécriture ;
- traiter ensuite KI-008 par caractérisation du golden path, puis regrouper
  KI-009/KI-011/KI-015 dans la preuve réelle SimConnect ;
- planifier séparément KI-021 avant toute donnée réelle et KI-003 avant toute
  distribution bêta ;
- traiter les dettes `Medium` KI-005, KI-012–KI-014 et KI-019 lorsque leurs zones
  deviennent actives, sans les mélanger aux validations externes.

### Documentation updated

`AGENTS.md`, workflow de maintenance, qualité, registre des problèmes connus et
suivi des tickets.

### Git status

- branche : `chore/T0030-technical-debt-guardrails` ;
- commit d'implémentation : `909f494` ;
- PR #55 : brouillon, base T0028, head T0030 ;
- dépendance : livraison de la PR #54 puis rebase ou changement de base sans
  réécriture d'une branche partagée ;
- fusion finale réservée à Andy.
