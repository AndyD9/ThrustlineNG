# T0062 — Réparer le gate d'automatisation des tickets et l'exécuter en CI

Status: Verify
Owner: Codex
Branch: `fix/T0062-ticket-automation-gate-crlf`
Phase: Gouvernance
Risk: Low
Security-sensitive: No

## Goal

`pnpm ticket-automation:check` passe réellement, ses dix mutations négatives
mutent réellement le fixture, et la CI exécute ce gate ainsi que
`pnpm product-version:check`.

## Context

T0061 a été fusionné par la PR #108 en déclarant `pnpm ticket-automation:check`
vert et « les dix mutations passent sous les deux hôtes PowerShell ». Sur
`origin/main` (`c51f3fe`), le gate échoue en réalité avec **10 assertions sur 34**.

La cause est une divergence de fins de ligne. Les tickets du dépôt sont en LF
(`.gitattributes` : `*.md text eol=lf`), mais le fixture de test est écrit à
l'exécution par `Set-Content`, qui produit du CRLF sous Windows. Or en .NET une
ancre `$` sous `(?m)` correspond avant `\n` et jamais avant `\r\n` : les quatre
mutations dont le motif est ancré ainsi ne modifiaient rien du tout.

- Mutations 1 et 2 (`^Status: Ready$`) : le fichier restait `Ready`, aucun blocage
  n'était produit et la sélection contenait `T0002` au lieu de l'exclure.
- Mutations 6 et 8 (`^Status: Done$`) : seul l'index était modifié, donc le
  sélecteur signalait une divergence de statut et sortait en `1` là où le scénario
  attendait `0`.

La vérification manuelle de T0061 a masqué le défaut : elle a diverge un statut
dans un **vrai** fichier de ticket, qui est en LF, où l'ancre correspond bien. Le
gate n'était par ailleurs exécuté par aucun workflow, donc les trois checks verts
de la PR #108 ne l'ont jamais lancé.

Le même motif fragile est déjà repris par du travail en cours qui ajoute
`-AutonomousOnly` au sélecteur, avec un scénario en `^Risk: Low$`.

## Dependencies

- T0061 fusionné.
- T0055 fusionné, pour `pnpm product-version:check`.

## Allowed areas

- `tests/ticket-automation/run.ps1`
- `.github/workflows/ci.yml`
- `docs/tickets/T0062-reparer-gate-automatisation-tickets.md`
- `docs/tickets/README.md`

## Do not touch

- `scripts/select-ticket-batch.ps1` : le sélecteur est déjà tolérant au CRLF, il
  lit ligne par ligne avec `\s*$`. Le défaut est dans le harnais de test.
- `.claude/workflows/` et `.claude/skills/` : travail en cours dans une autre
  session.
- Les statuts ou Completion Reports des autres tickets.

## Requirements

- Le fixture écrit ses fichiers en LF sans BOM, comme les tickets réels.
- Une mutation qui ne change rien échoue **bruyamment** et se signale comme un
  défaut de test, pas comme un défaut du sélecteur.
- Une mutation d'index qui ne trouve aucune ligne échoue de la même façon.
- L'échec d'une mutation n'interrompt pas les scénarios suivants.
- La CI exécute `pnpm ticket-automation:check` et `pnpm product-version:check`.

## Non-goals

- Ajouter des scénarios de sélection, dont `-AutonomousOnly`.
- Modifier le sélecteur ou les workflows d'orchestration.
- Reprendre le Completion Report de T0061.

## Acceptance criteria

- [x] `pnpm ticket-automation:check` passe : 34 assertions, 10 mutations.
- [x] Le gate passe sous Windows PowerShell 5.1 et sous PowerShell 7.
- [x] Un motif de mutation qui ne correspond à rien fait échouer le gate avec
      « the mutation itself failed », et non avec un écart de sélection.
- [x] `.github/workflows/ci.yml` exécute `ticket-automation:check` et
      `product-version:check`.
- [x] `pnpm ci:check`, `pnpm maintenance:check` et `pnpm product-version:check`
      passent.
- [x] Aucun fichier applicatif n'est modifié.

## Security review

`Security-sensitive: No`. Aucun actif, secret, donnée personnelle ni frontière de
confiance n'est touché : le livrable est un harnais de test et deux étapes de CI.

## Maintenance review

- dettes et problèmes connus applicables : aucune entrée `KI` existante ne couvre
  une mutation de test silencieusement inopérante.
- dette créée ou aggravée : aucune.
- règle de sécurité ajoutée, modifiée ou à revalider : aucune.
- contrôle manuel à automatiser : les deux gates passent de la vérification
  manuelle à la CI, ce qui est précisément l'objet de ce ticket.
- risque résiduel ou exception approuvée : d'autres tests du dépôt utilisent des
  ancres `(?m)…$` sur des fichiers LF (`tests/backend/run.ps1`,
  `tests/maintenance/run.ps1`, `tests/windows-package/run.ps1`). Ils sont corrects
  aujourd'hui parce que leurs cibles sont en LF ou parce que le motif absorbe le
  `\r` avec `\s*`. Un suivi est consigné.

## Automated validation

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File ./tests/ticket-automation/run.ps1
pwsh -NoProfile -ExecutionPolicy Bypass -File ./tests/ticket-automation/run.ps1
pnpm ci:check
pnpm maintenance:check
pnpm product-version:check
git diff --check
```

## Manual verification

1. Exécuter le gate sous les deux hôtes PowerShell et confirmer 34 assertions.
2. Remplacer un motif de mutation par un motif qui ne correspond à rien, et
   confirmer le message « the mutation itself failed ». Rétablir le fichier.
3. Confirmer que le fixture est écrit en LF sans BOM.
4. Confirmer que `ci.yml` exécute les deux gates dans le bloc de gouvernance.

Temps cible : 5 minutes.

## Rollback

Avant fusion, abandonner la branche. Après fusion, revenir par un nouveau commit :
le gate redeviendrait rouge, ce qui est l'état actuel de `main`, donc aucun risque
de perte de données.

## Completion Report

### Summary

Le fixture de `tests/ticket-automation/run.ps1` est désormais écrit en LF sans BOM
par un unique `Set-FixtureText`, qui normalise aussi les CRLF que ce script `.ps1`
porte dans ses here-strings. Les quatre mutations ancrées correspondent donc, et
le gate passe : 34 assertions, 10 mutations, sous les deux hôtes.

Deux garde-fous rendent la classe de défaut impossible à reproduire en silence :
`Set-TicketField` et `Set-IndexStatus` lèvent une erreur si leur mutation ne
change rien, et `Assert-Scenario` capture cette erreur pour la rapporter comme un
défaut de test tout en laissant tourner les scénarios suivants.

La CI exécute enfin `ticket-automation:check` et `product-version:check`, les deux
gates qui existaient sans être branchés. C'est ce défaut de câblage qui a laissé
un gate rouge atteindre `main` derrière trois checks verts.

### Files changed

- `tests/ticket-automation/run.ps1` : `Set-FixtureText`, écriture LF, garde-fous
  de mutation, capture par scénario.
- `.github/workflows/ci.yml` : deux étapes de gouvernance ajoutées.
- `docs/tickets/T0062-reparer-gate-automatisation-tickets.md` : ce ticket.
- `docs/tickets/README.md` : ligne d'index.

### Commands and results

Toutes réussies :

- `powershell -File ./tests/ticket-automation/run.ps1` : 34 assertions, 10
  mutations.
- `pwsh -File ./tests/ticket-automation/run.ps1` : identique.
- `pnpm ci:check` : dépôt plus 2 scénarios de mutation.
- `pnpm maintenance:check` : registre, index, marqueurs et 8 scénarios.
- `pnpm product-version:check` : invariants et 6 mutations, 5 cibles.
- `git diff --check` : aucun défaut d'espace.

Avant correction, sur `c51f3fe` : `10 of 34 assertions` en échec, mutations 1, 2,
6 et 8.

### Manual verification result

Les quatre étapes sont exécutées et réussies. L'étape 2 a produit exactement
`mutation 1 … : the mutation itself failed: Pattern '(?m)^Status: NeverMatches$'
changed nothing in T0002`, puis le fichier a été rétabli et le gate est repassé
vert.

### Risks and limitations

- Le gate ne valide toujours que le sélecteur. Les workflows d'orchestration
  `.claude/workflows/*.js` ne sont couverts par aucun test automatisé.
- La correction ne touche pas les autres tests qui utilisent des ancres `(?m)…$`.
  Ils sont corrects aujourd'hui, mais rien ne les protège d'un futur fixture CRLF.
- Le Completion Report de T0061 affirme que ses dix mutations passaient. Cette
  affirmation était fausse et reste consignée dans son fichier.

### Follow-ups

- Ajouter au harnais de test partagé une aide unique d'écriture de fixture, pour
  que `tests/backend`, `tests/maintenance` et `tests/windows-package` ne puissent
  pas réintroduire la même divergence de fins de ligne.
- Couvrir `.claude/workflows/ticket-plan.js` et `ticket-run.js` par un test de
  chargement et de contrat d'arguments.

### Documentation updated

- `docs/tickets/README.md`
