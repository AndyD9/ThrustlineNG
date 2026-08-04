# T0056 — Clôturer les vérifications interactives T0007 à T0009

Status: Ready
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

- [ ] Les mesures et diagnostics applicables sont réellement exécutés, avec
      fenêtre visible et zéro orphelin, ou leur blocage est consigné comme tel.
- [ ] Chaque ticket T0007, T0008 et T0009 porte une preuve datée, vérifiable et
      non antidatée.
- [ ] Andy confirme explicitement les contrôles humains avant tout passage à
      `Done`.
- [ ] Les statuts des trois tickets et de l'index sont cohérents dans le même
      changement.
- [ ] `CURRENT_STATE.md` et, le cas échéant, la revue de phase 1 reflètent
      exactement les conditions réellement levées.
- [ ] `pnpm maintenance:check` et `git diff --check` passent.

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

À remplir après implémentation.

### Summary

### Files changed

### Commands and results

### Manual verification result

### Risks and limitations

### Follow-ups

### Documentation updated
