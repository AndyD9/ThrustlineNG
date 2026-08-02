# T0031 — Réconcilier l'index après les fusions T0029–T0030

Status: Ready
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

- [ ] T0029, T0030 et T0031 apparaissent chacun une fois dans l'index.
- [ ] Le statut T0031 est identique dans le ticket et l'index.
- [ ] Le résumé T0030 reflète son ticket sans revendiquer de livraison dans
      `main`.
- [ ] Le gate de maintenance, le harnais CI et `git diff --check` passent.
- [ ] Le diff reste limité aux deux fichiers autorisés.

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

À remplir après implémentation.

