# T0066 — Prouver le motif de refus des courses concurrentes du harnais backend

Status: Draft
Owner: Unassigned
Branch: `fix/T0066-motif-refus-courses-backend`
Phase: Gouvernance
Risk: Medium
Security-sensitive: No

## Goal

Chaque course concurrente de `scripts/ci/test-backend.ps1` échoue lorsque le refus
observé n'est pas celui qu'elle prétend prouver, y compris sur un interblocage ou
une erreur étrangère.

## Context

`KI-025`. Dans `origin/main` au commit `c0f16dc`, les courses concurrentes du
harnais backend concluent au refus sur le seul code de sortie de `psql` :

- lignes 897, 1020, 1147 et 1300 — achat, dispatch, départ et clôture comparent la
  paire de codes de sortie à `0|1` puis un état de convergence ;
- ligne 821 — la course de location ne compare qu'un état de convergence ;
- aucun `-match` sur un message de refus n'existe dans le fichier.

Un interblocage `40P01`, un rôle manquant, un code ICAO absent du référentiel ou une
coupure de socket rendent le même code de sortie non nul. La session est alors
annulée, l'état de convergence est celui attendu puisque rien n'a été écrit, et le
harnais imprime sa ligne de réussite alors que la propriété visée n'a pas été
prouvée. Le contrôle reste correct dans l'autre sens : une garde absente laisse la
commande réussir et la course échoue.

Le constat vient de la revue adversariale de la Pull Request brouillon #112 du
5 août 2026, sur la sixième course ajoutée par T0060, mais il porte sur les cinq
courses déjà présentes dans `main`. C'est un risque de faux succès dans le seul
harnais qui prouve la concurrence réelle, non reproductible sous Windows.

## Dependencies

- T0013 — workflow CI et job backend Linux (`Done`) ;
- T0029, T0047, T0050, T0051 et T0032 — les cinq courses existantes et leurs
  messages de refus, tous présents dans `main` ;
- T0060 — sixième course ; si sa Pull Request #112 est fusionnée avant ce ticket,
  la nouvelle course entre dans le même périmètre, sinon elle reste traitée par son
  propre ticket. Le ticket relève la base réelle au moment de l'implémentation
  plutôt que de la déduire d'ici.

## Allowed areas

- `scripts/ci/test-backend.ps1` ;
- `tests/ci/run.ps1` si une mutation négative statique y est ajoutée ;
- `docs/QUALITY.md`, `docs/CURRENT_STATE.md`, `docs/KNOWN_ISSUES.md` ;
- ce ticket et `docs/tickets/README.md`.

## Do not touch

- migrations, fonctions SQL, pgTAP et types générés : aucun comportement produit ne
  change ;
- messages publics de refus des commandes : ils sont la référence attendue, pas une
  variable ;
- `.github/workflows/` sauf si le ticket le rouvre explicitement après relevé ;
- frontend, desktop, bridge, packaging, toolchain, lockfiles ;
- cible distante, projet Supabase distant, données réelles.

## Requirements

- Chaque course capture la sortie de la session refusée et exige le motif attendu :
  le message public de la commande concernée, et non un simple code de sortie.
- Un interblocage est un échec explicite : la course échoue si la sortie contient
  `40P01` ou `deadlock detected`, avec un message qui nomme la course.
- Une erreur étrangère au scénario est un échec explicite, jamais un refus admis.
- La sortie capturée reste exempte de secret, de JWT et d'identité : seul le motif
  attendu ou son absence est imprimé.
- Le décompte de courses annoncé par la ligne de résumé du harnais est mis à jour et
  consigné avec la valeur réellement observée.
- Au moins une preuve négative est produite : une exécution où le refus attendu est
  remplacé par une erreur étrangère doit faire échouer la course. Elle est obtenue
  dans un scénario jetable, jamais en affaiblissant une commande livrée.

## Non-goals

- ajouter une nouvelle course ou une nouvelle propriété de concurrence ;
- rendre les courses exécutables sous Windows ;
- changer l'ordonnancement temporel de 750 ms et de quatre secondes déjà en place ;
- corriger une garde, un message ou une migration ;
- toucher au workflow GitHub au-delà de ce que le harnais exige.

## Acceptance criteria

- [ ] Chacune des courses présentes dans la base réelle relevée compare le motif du
      refus au message public attendu.
- [ ] Un interblocage et une erreur étrangère font échouer la course concernée, avec
      un message qui la nomme.
- [ ] Une preuve négative est réellement exécutée et consignée, pas seulement
      décrite.
- [ ] `docs/QUALITY.md` décrit la nouvelle exigence et le décompte de courses
      réellement observé.
- [ ] `KI-025` passe `Resolved` en citant ce ticket.
- [ ] Le job Linux de la Pull Request passe et sa ligne de résumé est citée telle
      qu'elle est rendue.

## Security review

À remplir si `Security-sensitive: Yes`. Ce ticket n'ouvre aucune frontière, mais il
augmente la valeur de preuve d'un gate : un faux succès dans ce harnais masquerait
une régression d'atomicité, ce qui relève de la priorité 3 de `AGENTS.md`.

## Maintenance review

- dettes et problèmes connus applicables : `KI-025` ouvre ce ticket ;
- dette créée ou aggravée : le harnais devient plus verbeux et plus couplé aux
  messages publics des commandes ; tout changement de message devra le mettre à
  jour, ce qui est le comportement voulu ;
- règle de sécurité ajoutée, modifiée ou à revalider : une course concurrente ne
  conclut jamais depuis un seul code de sortie ; à consigner dans `docs/QUALITY.md`
  et à relier au registre `docs/LEARNINGS.md` ;
- contrôle manuel à automatiser : la preuve négative doit rester rejouable, sinon
  elle redevient une consigne de revue ;
- risque résiduel ou exception approuvée : l'ordonnancement temporel des courses
  reste une source de flakiness théorique partagée par tout le harnais ; ce ticket
  ne le corrige pas.

## Automated validation

```powershell
pnpm.cmd ci:check
pnpm.cmd maintenance:check
git diff --check
```

`pnpm ci:backend` refuse toute machine autre que le runner CI Linux : la preuve
réelle des courses est celle du job `Supabase PostgreSQL 17` de la Pull Request, et
non une exécution locale. Le contrôle local est déclaré `bloqué par
l'environnement`, jamais réussi.

## Manual verification

1. Relever la base réelle et le nombre de courses réellement présentes.
2. Exécuter les contrôles statiques locaux et consigner leur résultat.
3. Sur la Pull Request, relever la ligne de résumé du job Linux telle qu'elle est
   rendue, avec le décompte de courses.
4. Consigner la preuve négative exécutée et son message d'échec exact.

Temps cible : 5–10 minutes hors durée du job CI.

## Rollback

Avant fusion, abandonner la branche. Aucune donnée ni migration n'est concernée : le
retour en arrière est une révision du seul harnais.

## Completion Report

À remplir après implémentation.

### Summary

### Files changed

### Commands and results

### Manual verification result

### Risks and limitations

### Follow-ups

### Documentation updated
