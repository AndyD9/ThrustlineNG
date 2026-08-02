# T0031 — Réconcilier l'index après les fusions T0029–T0030

Status: Done
Owner: Andy
Branch: `fix/T0031-reconcile-ticket-index`
Phase: Gouvernance
Risk: Low
Security-sensitive: No

## Goal

Rétablir une correspondance exacte entre les tickets détaillés et leur index
après la perte de l'entrée T0030 pendant les fusions croisées T0029–T0030.

## Context

La branche de livraison T0028 contient les implémentations fusionnées de T0029
et T0030. Le fichier `T0030-garde-fous-dette-technique.md` et son gate sont
présents, mais `docs/tickets/README.md` conserve T0029 et a perdu la ligne et le
résumé T0030. Le gate livré par T0030 échoue donc avec
`Ticket T0030 is missing from docs/tickets/README.md`.

La divergence doit être corrigée avant de détailler la location d'avion : le
suivi incohérent invalide précisément le contrôle que T0030 introduit.

## Workflow evidence

- 2 août 2026 — `Ready` : défaut reproduit sur le parent
  `origin/docs/T0028-production-economy-policy` au commit `2324b61` ; aucun
  changement préexistant dans le worktree T0031.
- 2 août 2026 — `In progress` : ticket et index synchronisés sur la branche
  isolée `fix/T0031-reconcile-ticket-index` ; correction limitée aux zones
  autorisées.
- 2 août 2026 — `Review` : T0030 restauré sans altérer T0029 ; gate de
  maintenance, harnais CI, cohérence des statuts et diff validés.
- 2 août 2026 — publication : commits `a545496`, `bc2d481` et `581f698`, PR
  brouillon #57, base `docs/T0028-production-economy-policy`, head
  `fix/T0031-reconcile-ticket-index`.

## Dependencies

- T0029 — fusionné dans la branche de livraison T0028 par la PR #56 ;
- T0030 — fusionné dans la même branche par la PR #55, mais son entrée d'index
  a été perdue lors de la combinaison des branches ;
- gate `tests/maintenance/run.ps1` présent et reproduisant la divergence.

## Allowed areas

- ce ticket ;
- `docs/tickets/README.md`.

## Do not touch

- statut ou Completion Report de T0029 ou T0030 ;
- code applicatif, migrations, tests, gates et workflows ;
- décisions produit, économie, architecture, sécurité, données ou support ;
- `CURRENT_STATE.md`, `KNOWN_ISSUES.md` et roadmap.

## Requirements

- Restaurer T0030 dans le tableau sans supprimer ni réécrire T0029.
- Restaurer le résumé T0030 perdu lors de la fusion.
- Indexer T0031 avec le même statut que son fichier détaillé.
- Prouver que le gate de maintenance et le harnais CI repassent.
- Conserver la location d'avion comme prochain ticket fonctionnel, sans en
  inventer la politique économique dans cette correction.

## Non-goals

- modifier le contenu, les preuves ou le statut de T0029 ou T0030 ;
- réconcilier leur livraison dans `main` ;
- concevoir ou implémenter la location d'avion ;
- corriger une autre dette ou divergence documentaire.

## Acceptance criteria

- [x] T0029, T0030 et T0031 apparaissent chacun une fois dans l'index.
- [x] Le statut T0031 est identique dans le ticket et l'index.
- [x] Le résumé T0030 reflète son ticket sans revendiquer de livraison dans
      `main`.
- [x] Le gate de maintenance, le harnais CI et `git diff --check` passent.
- [x] Le diff reste limité aux deux fichiers autorisés.

## Security review

Non applicable : correction documentaire sans changement de frontière, de
credential, de donnée ou d'autorité métier.

## Maintenance review

- dettes et problèmes connus applicables : divergence de suivi détectée par le
  gate T0030 ;
- dette créée ou aggravée : aucune attendue ;
- règle de sécurité ajoutée, modifiée ou à revalider : aucune ;
- contrôle manuel à automatiser : déjà automatisé par T0030 ;
- risque résiduel : la branche reste empilée tant que T0029 et T0030 ne sont pas
  propagés dans `main`.

## Automated validation

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tests\maintenance\run.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\tests\ci\run.ps1
git diff --check
```

## Manual verification

1. Rechercher T0029, T0030 et T0031 dans le tableau de l'index.
2. Comparer leur statut à leur fichier détaillé.
3. Vérifier que le résumé T0030 est présent et que T0029 reste inchangé.
4. Confirmer que seuls le ticket T0031 et l'index sont modifiés.

Temps cible : 5 minutes.

## Rollback

Revenir uniquement sur le ticket T0031 et les ajouts T0030/T0031 dans l'index.
Aucune donnée persistante ou migration n'est concernée.

## Completion Report

### Summary

L'entrée et le résumé T0030 perdus pendant les fusions croisées sont restaurés
sans modifier T0029. T0031 est lui-même indexé et le gate introduit par T0030
repasse sur le résultat combiné.

### Files changed

- `docs/tickets/T0031-reconcilier-index-t0030.md` — périmètre, preuves et
  rapport de la réconciliation ;
- `docs/tickets/README.md` — lignes T0030/T0031 et résumé T0030.

### Commands and results

- `powershell -NoProfile -ExecutionPolicy Bypass -File
  .\tests\maintenance\run.ps1` avant correction — échec attendu : T0030 absent
  de l'index ;
- `pnpm.cmd run maintenance:check` dans le nouveau worktree — bloqué par
  l'environnement : restauration des dépendances refusée par le réseau sandboxé,
  aucun gate exécuté et aucun fichier versionné modifié ;
- même script PowerShell après correction — PASS : registre, index, marqueurs
  et huit mutations ;
- `powershell -NoProfile -ExecutionPolicy Bypass -File .\tests\ci\run.ps1` —
  PASS : invariants CI et deux mutations ;
- recherche ciblée T0029–T0031 et statuts des trois tickets — une entrée par
  ticket, statuts `Review`, `Review`, `Review` ;
- `git diff --check` — PASS.
- push de `fix/T0031-reconcile-ticket-index` — PASS ; PR brouillon #57 créée
  vers la base empilée `docs/T0028-production-economy-policy`.

### Manual verification result

PASS le 2 août 2026 : T0029 reste intact, T0030 est de nouveau présent dans le
tableau et le texte, T0031 correspond à son index et le diff final est limité
aux deux fichiers autorisés.

### Risks and limitations

- La correction est empilée sur `origin/docs/T0028-production-economy-policy`
  au commit `2324b61`, qui contient T0029 et T0030 ; elle ne les rend pas
  présents dans `main`.
- Le gate empêche la divergence constatée, mais cette correction ne change pas
  le statut historique `Review` de T0029 ou T0030.
- Aucun test applicatif n'est nécessaire pour ce diff exclusivement
  documentaire ; les deux gates concernés ont été exécutés directement.

### Follow-ups

- Propager T0029, T0030 puis T0031 vers `main` sans présenter une branche
  empilée comme livrée.
- Créer ensuite le ticket fonctionnel de location d'avion après décision d'Andy
  sur durée, échéances, défaut et résiliation.

### Documentation updated

Ticket T0031 et index des tickets uniquement ; `CURRENT_STATE.md` reste
inchangé car aucune capacité produit ou livraison dans `main` n'a changé.

### Delivery reconciliation

Le 2 août 2026, T0033 confirme que le commit de correction `581f698` est dans
l'ascendance de `origin/main` par la chaîne de fusions empilées intégrée avec la
PR #54. Les gates et la vérification manuelle étant déjà consignés, T0031 passe
de `Review` à `Done`.
