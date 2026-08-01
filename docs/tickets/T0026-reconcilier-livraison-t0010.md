# T0026 — Réconcilier la livraison de T0010

Status: Done
Owner: Andy
Branch: `docs/T0026-reconcile-t0010-delivery`
Phase: 1
Risk: Low
Security-sensitive: No

## Goal

Clore `KI-016` avec une preuve reproductible que les commits de T0010 sont
présents dans `main`, sans attribuer cette livraison à la mauvaise Pull Request.

## Context

La PR #7 a fusionné T0010 dans `foundation/t0009-dotnet-bridge`, une branche déjà
intégrée auparavant. Au 28 juillet 2026, cette fusion n'avait donc pas propagé
les commits T0010 dans `main` et `KI-016` a correctement enregistré l'écart.

La PR #10 a ensuite ciblé `main` et fusionné les commits T0010 `22f97d4` et
`41cc940` dans le merge commit `26cbcbf` le 28 juillet 2026. Le merge commit de
la PR #7, `5e9b6c5`, n'est pas lui-même ancêtre de `main`, ce qui est attendu :
la preuve porte sur les commits de contenu, pas sur la topologie de la première
fusion.

## Dependencies

- T0010 (`Done`) ;
- PR #7, constat d'origine de `KI-016` ;
- PR #10, propagation vers `main`.

## Allowed areas

- `docs/CURRENT_STATE.md` ;
- `docs/KNOWN_ISSUES.md` ;
- `docs/tickets/T0026-reconcilier-livraison-t0010.md` ;
- `docs/tickets/README.md`.

## Do not touch

- code, manifests, lockfiles, scripts, tests et workflows ;
- ticket T0010 et son Completion Report historique ;
- contrat local, frontière de confiance et règles de sécurité ;
- autres problèmes connus et statuts de tickets.

## Requirements

- vérifier séparément les deux commits T0010 et le merge commit de la PR #7 ;
- identifier la première fusion de la ligne principale qui contient T0010 ;
- rejouer les validations ciblées actuelles du bridge et du desktop ;
- conserver l'historique de `KI-016` et le passer à `Resolved` ;
- ne revendiquer aucune capacité supplémentaire.

## Non-goals

- réécrire l'historique Git ou le rapport T0010 ;
- modifier l'implémentation du bridge ou du desktop ;
- clore une autre dette ou une vérification MSFS.

## Acceptance criteria

- [x] `22f97d4` et `41cc940` sont ancêtres de `main`.
- [x] `5e9b6c5` n'est pas présenté comme ancêtre de `main`.
- [x] la PR #10 et son merge commit `26cbcbf` sont identifiés comme voie de
  propagation de T0010.
- [x] le build bridge, le harnais bridge et les tests desktop ciblés passent.
- [x] `KI-016`, le ticket, l'index et l'état courant sont cohérents.

## Automated validation

```powershell
git merge-base --is-ancestor 22f97d4b546d592d32771bf983d76bc9678ef753 main
git merge-base --is-ancestor 41cc94045d039d8e9264924bb47239179fecea15 main
git merge-base --is-ancestor 5e9b6c57442a522290c99458c27f766aeabc7d33 main
dotnet build ThrustlineNG.slnx --configuration Release
dotnet run --project tests\bridge\Thrustline.Bridge.Tests.csproj --configuration Release --no-build
pnpm desktop:test
git diff --check
```

Le troisième test d'ascendance est un contre-exemple attendu : il doit retourner
le code `1`, tandis que les deux premiers doivent retourner `0`.

## Manual verification

1. Comparer les bases, têtes, commits et dates des PR #7 et #10.
2. Trouver le premier commit de la ligne principale contenant `41cc940`.
3. Confirmer que le contrat T0010 reste décrit sans extension fonctionnelle.
4. Confirmer que seul `KI-016` change de statut.

Temps cible : 5 minutes.

## Rollback

Revenir uniquement sur les quatre fichiers documentaires du ticket. Aucun état
applicatif ou persistant n'est modifié.

## Completion Report

Clôturé le 1er août 2026 sur `docs/T0026-reconcile-t0010-delivery`.

### Summary

`KI-016` est résolu : les deux commits T0010 sont ancêtres de `main` depuis la
PR #10. La fusion initiale #7 reste correctement distinguée de cette livraison.

### Files changed

- `docs/CURRENT_STATE.md` ;
- `docs/KNOWN_ISSUES.md` ;
- ticket T0026 et index des tickets.

### Commands and results

- `gh pr view 7 ...` — PR fusionnée vers `foundation/t0009-dotnet-bridge`,
  commits `22f97d4` et `41cc940`, merge commit `5e9b6c5` ;
- `gh pr view 10 ...` — PR fusionnée vers `main`, merge commit `26cbcbf`, avec
  les deux commits T0010 ;
- tests d'ascendance — `22f97d4` et `41cc940` : code `0` ; `5e9b6c5` : code `1`
  attendu ;
- recherche du premier commit de première ligne contenant `41cc940` —
  `26cbcbf`, merge de la PR #10 ;
- `dotnet build ThrustlineNG.slnx --configuration Release` — réussi, zéro
  avertissement et zéro erreur ;
- harnais bridge Release `--no-build` — 13/13 tests réussis ;
- `pnpm desktop:test` — frontend 8/8, Rust 3/3 et invariants du shell conformes.

Le premier essai sandboxé de `pnpm bridge:build` n'a pas atteint la compilation :
la lecture de la configuration NuGet du profil était refusée. La commande .NET
explicite, relancée avec l'accès au profil Windows, a ensuite réussi.

### Manual verification result

La PR #7 n'a pas livré T0010 à `main`; la PR #10 l'a fait le même jour. Les
fichiers et validations actuels confirment que le contrat local reste présent.
Aucune règle produit ou de sécurité n'a été modifiée.

### Risks and limitations

- la topologie historique demeure non linéaire, mais la capacité et ses commits
  sont bien traçables dans `main` ;
- cette réconciliation ne remplace pas les vérifications MSFS encore ouvertes
  de T0011.

### Follow-ups

- poursuivre séparément les problèmes `High` ouverts selon la roadmap ;
- ne pas réutiliser une branche déjà fusionnée comme base de livraison.

### Documentation updated

État courant, problèmes connus et index des tickets.
