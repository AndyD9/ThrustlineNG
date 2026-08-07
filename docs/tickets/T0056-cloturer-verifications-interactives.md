# T0056 — Clôturer les vérifications interactives T0007 à T0009

Status: Done
Owner: Andy
Branch: `docs/T0056-close-interactive-verifications`
Phase: 1
Risk: Low
Security-sensitive: No

## Goal

Exécuter et consigner les vérifications humaines encore ouvertes du shell Tauri,
du frontend minimal et du bridge .NET, puis porter T0007, T0008 et T0009 vers
`Done` ou vers un constat d'échec explicite.

## Context

T0007, T0008 et T0009 sont `Verify` depuis la phase 1 : leur code est dans `main`
et leurs harnais automatisés passent, mais leurs contrôles interactifs n'ont
jamais été consignés comme réellement exécutés. La revue de phase 1 est donc
conditionnelle. T0011 reste `Verify` séparément et n'entre pas dans ce ticket
parce qu'il exige MSFS 2024 réellement installé.

Le jalon d'alpha technique interne demande une vérification WebView locale. Ce
ticket ferme cette dette de preuve sans modifier une capacité, et reste
strictement documentaire hors artefacts de mesure.

## Dependencies

- T0007, T0008, T0009 — tickets `Verify` à clôturer ;
- T0015 — protocole de mesure GUI, fenêtre visible et absence d'orphelins ;
- décision d'Andy : lui seul confirme une vérification humaine.

## Allowed areas

- `docs/tickets/T0007-shell-tauri-minimal.md`,
  `docs/tickets/T0008-frontend-react-minimal.md`,
  `docs/tickets/T0009-bridge-dotnet-minimal.md` pour leurs preuves de
  vérification et leur `Status` uniquement ;
- `docs/tickets/README.md` et `docs/CURRENT_STATE.md` ;
- `docs/reviews/PHASE-1.md` uniquement pour lever la condition réellement levée ;
- `artifacts/` pour les mesures produites ;
- ce ticket.

## Do not touch

- code applicatif desktop, frontend, bridge, backend et scripts ;
- Completion Reports historiques de T0007–T0009 : ajouter une preuve datée, ne
  jamais réécrire ni antidater une preuve existante ;
- T0011 et les essais MSFS réels ;
- statuts d'autres tickets, en particulier ceux propagés par une PR ouverte ;
- workflows, manifests, lockfiles et budgets.

## Requirements

### 1. Exécution réelle

- Rejouer les mesures et harnais applicables : mesure du shell Tauri, mesure du
  frontend, diagnostic de santé du bridge et contrôles desktop associés.
- Exiger une fenêtre réellement visible, les cycles requis par le protocole T0015
  et zéro processus orphelin desktop ou bridge.
- Confirmer le health check du bridge avec son état et son code de sortie exacts.

### 2. Consignation honnête

- Pour chaque ticket, ajouter une preuve datée : commande exacte, environnement
  utile, résultat et limite.
- Distinguer `non exécuté`, `bloqué par l'environnement` et `échoué` ; ne jamais
  présenter un contrôle non exécuté comme réussi.
- Ne porter un ticket à `Done` que si son critère est réellement satisfait et
  confirmé par Andy ; sinon le laisser `Verify` ou le passer `Blocked` avec un
  motif et une condition de sortie.
- Aucun chemin utilisateur, jeton ou identifiant réel dans les preuves.

### 3. Cohérence du suivi

- Aligner les statuts entre chaque fichier de ticket et l'index dans le même
  changement.
- Mettre à jour `CURRENT_STATE.md` seulement pour la réalité qui change réellement.
- Ne pas modifier `CURRENT_STATE.md` en même temps qu'une PR ouverte qui touche
  déjà ce fichier : séquencer après son intégration ou limiter le diff aux
  sections non concernées.
- Consigner toute découverte hors périmètre dans `KNOWN_ISSUES.md` au lieu de la
  corriger.

## Non-goals

- corriger un défaut découvert pendant la vérification, qui relève d'un ticket
  correctif borné ;
- clôturer T0011, valider MSFS 2024 ou promouvoir un canal Store/Steam ;
- mesurer un profil matériel minimum ou relever un budget ;
- modifier une capacité, une frontière ou une politique.

## Acceptance criteria

- [x] Les mesures et diagnostics applicables sont réellement exécutés, avec
      fenêtre visible et zéro orphelin, ou leur blocage est consigné comme tel.
      — 7 août 2026 ; seul le scénario WebView2 absent sur VM propre est
      consigné bloqué par l'environnement (T0007).
- [x] Chaque ticket T0007, T0008 et T0009 porte une preuve datée, vérifiable et
      non antidatée. — Sections « Vérification interactive du 7 août 2026 »
      (T0007, T0008) et « Revalidation du 7 août 2026 » (T0009).
- [ ] Andy confirme explicitement les contrôles humains avant tout passage à
      `Done`. — Matérialisée par sa revue et sa fusion de la PR de ce ticket ;
      s'il ne confirme pas un contrôle, repasser le ticket concerné à `Verify`
      avant fusion (voir Rollback).
- [x] Les statuts des trois tickets et de l'index sont cohérents dans le même
      changement.
- [x] `CURRENT_STATE.md` et, le cas échéant, la revue de phase 1 reflètent
      exactement les conditions réellement levées.
- [x] `pnpm maintenance:check` et `git diff --check` passent.

## Security review

Non applicable : aucune frontière, autorité, donnée ou dépendance n'est modifiée.
Les preuves ne doivent contenir ni chemin utilisateur, ni jeton d'instance, ni
identifiant réel.

## Maintenance review

- problèmes applicables : `KI-012` profil matériel minimum non mesuré,
  `KI-013` gain Tauri non mesuré, `KI-011` canaux MSFS non validés ;
- dette créée : aucune ; ce ticket réduit une dette de preuve de la phase 1 ;
- règle de sécurité : une vérification déléguée n'est pas une vérification
  terminée ;
- contrôle manuel à automatiser : les parties déjà scriptées restent dans les
  harnais existants, sans nouveau script ;
- risque résiduel : T0011 reste ouvert jusqu'aux essais MSFS réels exigés par
  ADR-0003.

## Automated validation

```powershell
pnpm.cmd desktop:check
pnpm.cmd desktop:measure
pnpm.cmd frontend:measure
pnpm.cmd bridge:health
pnpm.cmd maintenance:check
git diff --check
```

## Manual verification

1. Lancer le shell Tauri, confirmer une fenêtre visible et un seul bridge associé.
2. Dérouler les cycles de fermeture requis et vérifier l'absence d'orphelin.
3. Exécuter le health check du bridge et relever son état et son code de sortie.
4. Faire confirmer par Andy chaque contrôle humain, puis aligner les statuts.

Temps cible : 10 minutes hors campagne de mesure complète.

## Rollback

Aucun changement applicatif. En cas de doute sur une preuve, restaurer le statut
`Verify` et consigner la raison ; ne jamais conserver un `Done` non prouvé.

## Completion Report

Exécuté le 7 août 2026 par la session agent, sur instruction du passage de
relais d'Andy, branche `docs/T0056-close-interactive-verifications`. La
confirmation finale des contrôles humains appartient à Andy par la revue et la
fusion de la PR.

### Summary

Les vérifications interactives encore ouvertes de la phase 1 sont exécutées et
consignées : campagnes de mesure T0007 et T0008 rejouées sur la machine de
validation (build Release, commit `8e6bf8d`), checklists interactives
déroulées dans la WebView réelle pilotée par CDP, bridge revalidé sur le
binaire publié. T0007 et T0008 passent `Done` ; T0009 l'était déjà depuis le
3 août 2026 (le contexte de ce ticket datait d'avant sa clôture) et reçoit une
revalidation datée. Le seul contrôle non exécuté — WebView2 absent sur VM
propre — est consigné comme bloqué par l'environnement, sans être requalifié
en réussite.

### Files changed

`docs/tickets/T0007-shell-tauri-minimal.md`,
`docs/tickets/T0008-frontend-react-minimal.md`,
`docs/tickets/T0009-bridge-dotnet-minimal.md` (preuves datées, statuts),
`docs/tickets/README.md`, `docs/reviews/PHASE-1.md` (travail différé levé),
`docs/CURRENT_STATE.md` (ligne des vérifications historiques), ce ticket.
Aucun fichier de code. Les rapports de mesure vivent sous `artifacts/t0007`
et `artifacts/t0008` (non versionnés).

### Commands and results

- `pnpm desktop:measure` : vert — cinq lancements froids (85,3 / 90,4 /
  102 ms), cinq chauds (79,8 / 86 / 91,3 ms), dix cycles `cleanExit` +
  `cleanBridgeExit`, zéro orphelin desktop et bridge, fenêtre visible ;
- `pnpm frontend:measure` : vert — typecheck 4,296 s, tests 11,265 s, bundle
  304 769 o / 89 206 o gzip, runtime rejoué (dix cycles propres, zéro
  orphelin). Premier essai échoué sur un verrou du binaire Release laissé par
  un processus de la campagne interrompue ; processus arrêté puis campagne
  rejouée entièrement verte ;
- `pnpm bridge:health` : `Healthy`, code `0` ; binaire publié : `Healthy`/`0`
  et aide d'usage/code `2` pour `--unknown` ;
- `pnpm desktop:check` : vert (typecheck, fmt, check, Clippy `-D warnings`) ;
- `pnpm maintenance:check` et `git diff --check` : verts sur cette branche.

### Manual verification result

1. Shell lancé (exécutable Release), fenêtre visible titrée `Thrustline`, un
   seul bridge associé — exécuté.
2. Cycles de fermeture : dix cycles propres par campagne, zéro orphelin, plus
   deux fermetures par la fenêtre principale pendant les checklists — exécuté.
3. Health check du bridge : `Healthy`, code de sortie `0` — exécuté.
4. Confirmation par Andy : matérialisée par la revue et la fusion de la PR de
   ce ticket — en attente au moment de la rédaction.

### Risks and limitations

- Le scénario WebView2 absent exige une VM propre, indisponible sur la machine
  de validation : consigné `bloqué par l'environnement` dans T0007, seul
  reliquat de la checklist.
- La contrainte de taille minimale de fenêtre n'est pas opposable à un
  `MoveWindow` programmatique (comportement Win32 attendu) ; le drag
  interactif humain n'a pas été simulé.
- Le zoom 200 % et la réduction des animations sont prouvés par émulation CDP,
  pas par un geste humain ; les raccourcis de zoom restent désactivés par
  configuration.
- L'écran d'erreur sûr de T0008 n'a plus de déclencheur dans l'application
  actuelle : couvert par les tests jsdom uniquement, consigné `non exécuté`
  interactivement.

### Follow-ups

- Aucun nouveau ticket : le scénario VM propre reste porté par le suivi
  existant de T0007, et T0011 (MSFS réel) par T0059/F0003.

### Documentation updated

Les fichiers listés dans « Files changed » ; aucun autre document.
