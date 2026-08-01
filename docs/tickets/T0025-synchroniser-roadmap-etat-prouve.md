# T0025 — Synchroniser la roadmap avec l'état prouvé

Status: Done
Owner: Andy
Branch: `docs/T0025-sync-roadmap-state`
Phase: 1–2
Risk: Low
Security-sensitive: No

## Goal

Retirer de la roadmap courante les statuts T0012 devenus faux et aligner l'état
du dépôt après la fusion de T0024, sans réécrire les rapports historiques.

## Context

`KI-006` constate que `ROADMAP.md` annonce encore T0012 en `Verify` après sa
clôture et sa livraison par la PR #41. La PR #46 a depuis livré T0024 et son gate
d'autorité dans `main`, alors que `CURRENT_STATE.md` le décrit encore comme non
fusionné.

Les mentions équivalentes dans les Completion Reports T0012/T0013 et dans la
revue de phase du 30 juillet sont historiquement exactes à leur date. Elles ne
doivent pas être maquillées rétroactivement.

## Dependencies

- T0012 et T0021 (`Done`, PR #41 dans `main`) ;
- T0024 (`Done`, PR #46 dans `main`).

## Allowed areas

- `docs/ROADMAP.md` ;
- `docs/CURRENT_STATE.md` ;
- `docs/KNOWN_ISSUES.md` ;
- `docs/tickets/T0025-synchroniser-roadmap-etat-prouve.md` ;
- `docs/tickets/README.md`.

## Do not touch

- code, manifests, migrations, scripts, tests et workflows ;
- anciens Completion Reports et revue de phase datée ;
- priorités produit, gates de support et interdiction des données réelles.

## Requirements

- présenter T0012 comme `Done` grâce à T0021 et la PR #41 ;
- présenter T0024 comme livré dans `main` par la PR #46 avec ses vrais runs ;
- conserver la phase 2 active et conditionnelle, sans capacité future inventée ;
- distinguer documents courants et preuves historiques datées ;
- fermer `KI-006` avec une preuve reproductible.

## Non-goals

- clore T0007–T0009 ou T0011 ;
- modifier la roadmap fonctionnelle ou choisir la prochaine règle économique ;
- corriger un autre problème connu.

## Acceptance criteria

- [x] `ROADMAP.md` ne dit plus que T0012 reste `Verify` ou différé.
- [x] La phase 2 cite les capacités T0018–T0024 sans les sur-déclarer.
- [x] `CURRENT_STATE.md` reflète la fusion réelle de T0024.
- [x] `KI-006` est résolu et le ticket/index ne conservent aucun statut courant
  obsolète pour T0012 ou T0024.
- [x] Les instantanés historiques restent inchangés.

## Automated validation

```powershell
rg -n -i 'T0012.{0,80}(Verify|différé)|(?:Verify|différé).{0,80}T0012' docs/ROADMAP.md
git diff --check
```

## Manual verification

1. Relire les statuts de phase 1 et phase 2 dans la roadmap.
2. Comparer T0012/T0024 à leurs tickets et aux fusions #41/#46.
3. Confirmer que T0007–T0009 et T0011 restent ouverts.
4. Confirmer que l'interdiction des données réelles reste explicite.

Temps cible : 5 minutes.

## Rollback

Revenir uniquement sur les cinq fichiers documentaires du ticket.

## Completion Report

Clôturé le 1er août 2026 sur `docs/T0025-sync-roadmap-state`.

### Summary

La roadmap et l'état courant sont alignés sur les fusions #41 et #46. Les
instantanés historiques sont conservés et KI-006 est résolu.

### Files changed

- `docs/ROADMAP.md` ;
- `docs/CURRENT_STATE.md` ;
- `docs/KNOWN_ISSUES.md` ;
- ticket T0025 et index des tickets.

### Commands and results

- recherche ciblée T0012 dans `ROADMAP.md` — aucun statut `Verify` ou différé ;
- recherche ciblée dans les documents courants — aucune attente de fusion T0024
  ni vérification runtime T0012 restante ;
- cohérence ticket/index T0025 — `Done` des deux côtés ;
- `git diff --check` — réussi.

### Manual verification result

T0012 est `Done` via T0021/#41, T0024 est livré via #46 et la phase 2 reste
active sous interdiction de données réelles. T0007–T0009 et T0011 restent
explicitement ouverts.

### Risks and limitations

- les rapports historiques conservent leurs anciens statuts, exacts à leur date ;
- aucun gate fonctionnel, support distant ou politique économique ne change.

### Follow-ups

- maintenir les documents courants lors de chaque future fusion ;
- traiter séparément les autres entrées ouvertes de `KNOWN_ISSUES.md`.

### Documentation updated

Roadmap, état courant, problèmes connus et index des tickets.
