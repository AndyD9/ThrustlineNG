# T0068 — Faire de la fonctionnalité l'unité de suivi, de branche et d'intégration

Status: Done
Owner: Codex
Branch: `chore/T0068-format-fonctionnalite`
Phase: Gouvernance
Risk: Medium
Security-sensitive: No
Autonomous: No

## Goal

Une capacité utilisateur se suit dans un seul fichier, avance sur une seule
branche et s'intègre par une seule Pull Request, découpée en jalons internes
ordonnés. Le sélecteur déterministe, ses gates et la boucle appliquent cette
unité sans perdre la frontière d'autonomie de T0063.

## Context

Le découpage actuel fait de la tranche de travail l'unité de suivi et
d'intégration. Chaque tranche de quelques centaines de lignes paie donc la
cérémonie complète d'un jalon produit : un fichier de ticket, une ligne d'index,
un paragraphe de narration, une branche, un worktree, une Pull Request, un jeu de
gates et un Completion Report.

État mesuré le 5 août 2026 sur `origin/main` :

- 63 fichiers de tickets, 19 296 lignes ; index de 439 lignes dont environ 350 de
  prose ; `docs/CURRENT_STATE.md` de 1 082 lignes ; 113 merges dans `main` ;
- 24 worktrees résiduels dans `.worktrees/` et `.claude/worktrees/` ;
- 11 tickets de phase `Gouvernance`, dont 4 de réconciliation d'index pure
  — T0025, T0026, T0031, T0033 — qui ne livrent aucune capacité produit.

Le coût n'est pas seulement additif. Une capacité coûte 4 à 6 tickets, donc 4 à 6
bases de branche à choisir :

- acheter un avion : T0029 (migration et RPC), T0035 (Edge), T0036 (runtime
  local), T0037 (commande desktop), T0043 (catalogue), T0045 (composition) ;
- se connecter : T0038, T0039, T0040, T0041 ;
- préparer un dispatch : T0047, T0048, T0049, T0052, T0053.

Ces bases multiples produisent des fusions sur une branche déjà intégrée
ailleurs, donc des PR correctives : #69, #73, #79 et #83, puis la dérive d'index
T0043–T0050 qui a justifié le sélecteur déterministe de 516 lignes et son gate.
Le motif est encore actif : la PR #110 est `MERGED` sur la base
`fix/T0062-ticket-automation-gate-crlf`, fusionnée dans `main` par #109 avant
elle, si bien que T0063 n'est pas dans `main`. Deux identifiants T0065 coexistent
entre `origin/main` et la PR #115.

Andy a tranché le 5 août 2026 les quatre décisions de forme reportées en
`Requirements`.

## Dependencies

- T0063 propagé dans `main` par la PR corrective #117 au merge `f4ea508`, avec ses
  trois checks verts : le sélecteur, son gate à 50 assertions et 15 mutations, et
  la boucle planifiée que ce ticket modifie sont désormais présents dans la branche
  par défaut. Dépendance satisfaite.
- T0064 : il modifie déjà `.claude/workflows/` sur les charges JSON de la boucle,
  donc les mêmes fichiers. Il n'est plus porté par la PR #113 mais par la Pull
  Request de consolidation #118, qui livre aussi ce cadrage. La dépendance est donc
  satisfaite dès la fusion de #118, et T0068 devient exécutable à ce moment-là.
- T0061 et T0062 fusionnés : acquis, PR #108 et #109.
- Décisions d'Andy du 5 août 2026 : acquises, reportées en `Requirements`.

## Allowed areas

- `docs/templates/FEATURE.md` (nouveau)
- `docs/features/README.md` (nouveau)
- `docs/WORKFLOW.md`
- `docs/tickets/README.md`
- `AGENTS.md`
- `scripts/select-ticket-batch.ps1`
- `tests/ticket-automation/run.ps1`
- `.claude/workflows/ticket-plan.js`
- `.claude/workflows/ticket-run.js`
- `.claude/skills/ticket-loop/SKILL.md`
- `package.json`
- `docs/tickets/T0068-unite-fonctionnalite.md`

## Do not touch

- Les 63 fichiers de tickets existants, leurs `Status` et leurs Completion
  Reports. Ils sont gelés comme historique ; aucun regroupement rétroactif.
- `docs/templates/TICKET.md` : le format ticket reste en service pour la
  gouvernance, les correctifs et les réconciliations d'un seul résultat.
- Les ADR acceptées, `docs/SECURITY.md`, `docs/DATA_POLICY.md`.
- Tout code applicatif : `apps/`, `packages/`, `supabase/`.
- Les statuts substantiels de `docs/CURRENT_STATE.md`.

## Requirements

Les quatre décisions d'Andy du 5 août 2026 :

1. **Périmètre** : une fonctionnalité est un slice vertical complet. Migration,
   RPC, frontière Edge, validation sur le runtime local et composition desktop
   vivent dans une branche et une Pull Request uniques, en un commit par jalon.
2. **Existant** : les 63 tickets et `docs/tickets/README.md` deviennent une
   archive figée, marquée comme telle. La nouvelle numérotation démarre en
   parallèle en `F0001` sous `docs/features/`, avec son propre index.
3. **Parallélisme** : au plus deux fonctionnalités `In progress` simultanément,
   chacune dans son worktree et sa branche. Le plafond de trois flux d'`AGENTS.md`
   est remplacé, pas cumulé.
4. **Autonomie** : `Autonomous`, `Security-sensitive` et `Risk` sont portés par
   chaque jalon, pas seulement par la fonctionnalité. La frontière calculée par le
   sélecteur pour un run non surveillé s'applique au jalon exécutable suivant.

Contraintes techniques :

- Le fichier de fonctionnalité porte un `Goal` unique, l'union de ses
  `Allowed areas`, ses `Do not touch`, et une liste ordonnée de jalons. Chaque
  jalon déclare son résultat observable, sa frontière principale, ses validations,
  ses trois champs d'autonomie et son propre bloc de Completion Report.
- Le sélecteur lit `docs/features/` **et** `docs/tickets/` pendant la transition :
  T0056, T0059, T0060 et T0065–T0067 restent des tickets au format actuel.
- La cohérence de suivi est vérifiée au niveau de la fonctionnalité contre
  `docs/features/README.md`, avec les mêmes échecs fermés qu'aujourd'hui : statut
  divergent, statut invalide, champ `Status` absent ou dupliqué, entrée absente de
  l'index, dépendance introuvable.
- La revue adversariale s'exécute **par jalon** sur le diff poussé, jamais en une
  seule passe finale. La vérification manuelle de 5–10 minutes devient une
  vérification par jalon.
- La modification d'`AGENTS.md` est réservée à une exécution surveillée : la
  boucle ne modifie pas `AGENTS.md`. Ce ticket porte donc `Autonomous: No`.
- Chaque règle nouvelle du sélecteur est prouvée par au moins une mutation
  négative dans `tests/ticket-automation/run.ps1`, écrite en LF sans BOM et
  bruyante si elle ne mute rien, conformément à T0062.

## Non-goals

- Regrouper rétroactivement les 63 tickets existants par fonctionnalité.
- Modifier la substance d'un gate existant : `maintenance:check`,
  `authority:check`, `data-policy:check`, `product-version:check`.
- Livrer une capacité produit ou écrire la première fonctionnalité `F0001`.
- Supprimer les worktrees résiduels ou l'historique de l'index.
- Changer les états d'un ticket : `Draft → Ready → In progress → Review → Verify →
  Done` reste inchangé, appliqué à la fonctionnalité.
- Fusionner une Pull Request.

## Acceptance criteria

- [x] `docs/templates/FEATURE.md` existe et impose un `Goal` unique, l'union des
      `Allowed areas`, et des jalons ordonnés portant chacun résultat, frontière,
      validations, `Autonomous`, `Security-sensitive`, `Risk` et Completion Report.
- [x] `docs/features/README.md` existe avec un index vide et sa convention de
      nommage `F0001-slug.md`.
- [x] `docs/tickets/README.md` déclare l'archive en tête, sans qu'aucune ligne ni
      aucun statut existant ne change.
- [x] `docs/WORKFLOW.md` remplace les §1, §2 et « Limites de taille » par l'unité
      fonctionnalité, la revue par jalon et le plafond de deux.
- [x] `AGENTS.md` remplace le plafond de trois flux par le plafond de deux
      fonctionnalités, sans modifier la liste de lecture obligatoire.
- [x] `pnpm ticket-batch:select` sélectionne une fonctionnalité, rend ses jalons
      ordonnés, et rend le prochain jalon exécutable.
- [x] Le sélecteur applique la frontière d'autonomie au jalon : un jalon
      `Security-sensitive: Yes`, `Risk: High`, `Autonomous: No`, ou dont une
      dépendance nomme une décision d'Andy, MSFS, du matériel ou une vérification
      humaine est reporté avec sa raison, sans reporter la fonctionnalité entière.
- [x] Le sélecteur sort en échec fermé sur une incohérence de suivi au niveau
      fonctionnalité, et continue de traiter les tickets `TXXXX` en transition.
- [x] Le sélecteur applique un plafond de deux fonctionnalités `In progress`.
- [x] `pnpm ticket-automation:check` passe sous Windows PowerShell 5.1 et sous
      PowerShell 7, avec au moins une mutation négative par règle nouvelle.
- [x] Une mutation qui ne change rien échoue bruyamment comme défaut de test.
- [x] `ticket-plan` écrit une fonctionnalité et non plusieurs tickets ;
      `ticket-run` produit une branche, une Pull Request brouillon et un commit par
      jalon.
- [x] `pnpm ci:check`, `pnpm maintenance:check` et `pnpm product-version:check`
      passent.
- [x] Aucun fichier applicatif n'est modifié ; `git diff --check` est propre.

## Security review

`Security-sensitive: No`. Le livrable est de la documentation de processus, un
sélecteur de planification, son harnais de test et trois définitions
d'orchestration. Aucun actif, secret, donnée personnelle ni frontière de confiance
applicative n'est touché.

Un risque indirect existe et est traité par les exigences : un slice vertical
regroupe une migration financière et une surface UI dans un même diff, ce qui
pourrait diluer la revue sécurité. La revue par jalon et le portage des trois
champs d'autonomie au jalon existent précisément pour que la frontière reste
évaluée au niveau où elle a un sens.

## Maintenance review

- dettes et problèmes connus applicables : la dérive d'index entre fichiers et
  `docs/tickets/README.md`, observée sur les fusions T0043–T0050 et encore
  aujourd'hui sur T0063 et la collision T0065.
- dette créée ou aggravée : deux formats de suivi coexistent pendant la
  transition, donc le sélecteur porte deux chemins de lecture. Cette dette est
  bornée par l'épuisement des tickets `TXXXX` encore ouverts.
- règle de sécurité ajoutée, modifiée ou à revalider : aucune règle de
  `docs/SECURITY.md`. La frontière d'autonomie de T0063 est déplacée du ticket au
  jalon et doit être revalidée par ses mutations négatives.
- contrôle manuel à automatiser : la vérification que la base d'une Pull Request
  est bien `main` n'est aujourd'hui prouvée par aucun contrôle, alors qu'elle a
  échoué pour #68, #70, #72, #74 et #110. Un suivi séparé est consigné.
- risque résiduel ou exception approuvée : une fonctionnalité abandonnée jette
  plusieurs jours de travail au lieu de quelques heures. Andy accepte ce coût le
  5 août 2026 contre la suppression de l'empilement de branches.

## Automated validation

```powershell
pnpm ticket-batch:select
powershell -NoProfile -ExecutionPolicy Bypass -File ./tests/ticket-automation/run.ps1
pwsh -NoProfile -ExecutionPolicy Bypass -File ./tests/ticket-automation/run.ps1
pnpm ci:check
pnpm maintenance:check
pnpm product-version:check
git diff --check
```

## Manual verification

1. Écrire une fonctionnalité factice à trois jalons, dont un seul non autonome,
   dans un dépôt jetable, puis confirmer que `pnpm ticket-batch:select` rend le
   premier jalon exécutable et reporte le jalon non autonome avec sa raison.
2. Diverger le statut de cette fonctionnalité entre son fichier et
   `docs/features/README.md`, puis confirmer une sortie non nulle.
3. Placer trois fonctionnalités `In progress` et confirmer que la troisième est
   reportée pour dépassement du plafond.
4. Confirmer qu'un ticket `TXXXX` encore ouvert — T0060 — reste sélectionnable au
   format actuel.
5. Rétablir le dépôt jetable et confirmer que le gate repasse vert.

Temps cible : 10 minutes.

## Rollback

Avant fusion, abandonner la branche et son worktree : aucun fichier de ticket
existant n'est modifié, donc l'archive et les statuts restent intacts. Après
fusion, revenir par un nouveau commit qui restaure `docs/WORKFLOW.md`, `AGENTS.md`
et le sélecteur ; `docs/features/` resterait présent mais inerte, sans perte de
données.

## Completion Report

### Summary

L'unité de suivi, de branche et d'intégration est désormais la fonctionnalité.
`docs/templates/FEATURE.md` impose un `Goal` unique, l'union des `Allowed areas` et
des jalons ordonnés `### J<n>` portant chacun `Status`, `Risk`, `Security-sensitive`,
`Autonomous` et son bloc de Completion Report. `docs/features/README.md` ouvre
l'index de la nouvelle numérotation ; `docs/tickets/README.md` déclare l'archive en
tête sans qu'aucune ligne ni aucun statut existant ne change.

Le sélecteur lit les deux répertoires avec les mêmes règles de cohérence, via une
table de deux « kinds » plutôt que deux chemins de code dupliqués. Les messages
existants sur les tickets sont conservés mot pour mot, ce qui a permis de prouver que
le refactor était neutre : après réécriture, les quinze mutations d'origine
n'échouaient plus que sur les attentes de capacité, aucune sur un message.

La frontière d'autonomie est le cœur du ticket. Elle est évaluée sur le **premier
jalon qui n'est pas `Done`** : ses trois champs l'emportent sur ceux de l'en-tête,
qui ne servent que de valeurs par défaut. Un `Autonomous: No` en en-tête reste un
veto global. C'est ce qui permet à un jalon de lecture seule d'avancer sans
surveillance dans une fonctionnalité dont un autre jalon touche à l'argent — sans
défaire la frontière que T0063 avait livrée.

Le plafond passe de trois flux à deux unités, appliqué par le sélecteur sur les
fonctionnalités comme sur les tickets d'archive. `-MaxConcurrent` remplace
`-MaxFlows`, conservé comme alias pour ne casser aucun appelant.

### Files changed

- `docs/templates/FEATURE.md` : nouveau format, jalons et Completion Report par jalon.
- `docs/features/README.md` : nouvel index, convention `F0001-slug.md`, transition.
- `docs/tickets/README.md` : en-tête d'archive et convention mise à jour.
- `docs/WORKFLOW.md` : nouvelle §0, §1, §1.1, §2, revue par jalon en §4, section du
  sélecteur, boucle automatisée, « Limites de taille » et rétrospective.
- `AGENTS.md` : unité de travail, plafond de deux, branche de fonctionnalité, suivi
  des jalons. La liste de lecture obligatoire est étendue à `docs/features/`, jamais
  réduite.
- `scripts/select-ticket-batch.ps1` : lecture des deux répertoires, `Get-Milestones`,
  `Get-HeaderValues` bornée au préambule, autonomie au jalon, `-MaxConcurrent`.
- `tests/ticket-automation/run.ps1` : fixture de fonctionnalités, `New-FeatureFile`,
  `Set-FeatureField`, `Set-IndexStatus -Directory`, douze mutations nouvelles.
- `.claude/workflows/ticket-plan.js` : propose des fonctionnalités avec leurs jalons,
  plafond de deux, écrit dans `docs/features/`.
- `.claude/workflows/ticket-run.js` : un commit et une revue par jalon, une seule
  Pull Request par fonctionnalité, `kind` et `nextMilestone` dans la sélection.
- `.claude/skills/ticket-loop/SKILL.md` : arguments, limites et frontière au jalon.
- `docs/tickets/T0068-unite-fonctionnalite.md` : ce rapport.

### Commands and results

Toutes réussies :

- `tests/ticket-automation/run.ps1` : **89 assertions, 27 mutations négatives**, sous
  PowerShell 7 et sous Windows PowerShell 5.1 — contre 50 et 15 avant le ticket.
- `scripts/select-ticket-batch.ps1` : sortie `0` sur le dépôt réel, 0 fonctionnalité,
  68 tickets, capacité 2 de 2.
- `pnpm maintenance:check`, `pnpm ci:check`, `pnpm product-version:check`,
  `pnpm authority:check`, `pnpm data-policy:check` : passent.
- `node --check` sur `ticket-plan.js` et `ticket-run.js`.
- `git diff --check` : propre.

Un défaut réel a été trouvé en cours de route par l'exécution sous les deux hôtes :
`Get-Milestones` rend une `List`, que PowerShell déroule à la sortie d'une fonction.
Une fonctionnalité à un seul jalon arrivait donc comme scalaire, et `.Count` n'existe
pas sur un scalaire sous Windows PowerShell 5.1 avec `StrictMode`. Le gate passait
sous PowerShell 7 et échouait sous 5.1. Corrigé par un `@()` explicite et commenté.

### Pull request et fusion

La **PR #119 est fusionnée par Andy dans `main` le 5 août 2026 à 18 h 05 UTC au merge
`17ad8a8`**, base `main`, head `chore/T0068-format-fonctionnalite`. Ses trois checks
sont verts : `Windows multi-stack` en 18 min 05, `Supabase PostgreSQL 17` en 3 min 37
et `Audits, licences and SBOM` en 3 min 12.

La couleur des checks ne suffit pas : le journal du job `Windows multi-stack`, étape
« Validate ticket automation governance », montre `pnpm ticket-automation:check` puis
son harnais. Le même gate rejoué le 5 août 2026 sur `origin/main` au merge `17ad8a8`
rend `Ticket batch selector invariants passed: 89 assertions, 27 negative mutations`,
et `scripts/select-ticket-batch.ps1` rend `Features: 0; tickets: 68; work capacity:
2 of 2` avec une sortie `0` : le nouveau format est donc exercé sur le dépôt réel avec
un index de fonctionnalités vide, ce qui était son premier risque d'échec.

Le ticket passe à `Done` par la maintenance documentaire du 5 août 2026 : critères
satisfaits, vérification manuelle terminée, gate prouvé en CI et sur `main`. Ses
quatre follow-ups restent ouverts et ne conditionnent pas ce statut.

### Manual verification result

Les cinq étapes sont exécutées sur un dépôt jetable, sous les deux hôtes, puis le
dépôt est détruit :

1. `-Only F0001 -AutonomousOnly` rend `Selected: none` et
   `F0001: human required: milestone J2 declares Autonomous: No`, alors que l'en-tête
   de `F0001` déclare `Autonomous: Yes`. C'est la précision apportée par le ticket.
2. Le même jalon est sélectionné en run surveillé, avec `next J2`.
3. Trois fonctionnalités `Ready` : deux sélectionnées, les autres différées avec
   `work capacity reached (2 max, 0 occupied)`.
4. Le ticket d'archive `T0060` reste sélectionnable au format précédent, aux côtés
   d'une fonctionnalité.
5. Une divergence de statut entre `F0002` et l'index rend
   `Feature F0002 status differs: index 'Done', file 'Ready'.` et une sortie `1` ;
   le rétablissement repasse à `0`.

### Risks and limitations

- Aucune fonctionnalité `F0001` n'est écrite : le ticket livre le format, pas une
  capacité. La première fonctionnalité réelle validera le format en usage.
- Les deux workflows d'orchestration ne sont couverts par aucun test automatisé
  au-delà de `node --check`. C'est un follow-up déjà consigné dans T0062, et il pèse
  plus lourd maintenant que leurs invites portent la boucle par jalon.
- Deux formats de suivi coexistent pendant la transition. La dette est bornée par
  l'épuisement des tickets `TXXXX` encore ouverts : T0007, T0008, T0011, T0032,
  T0055, T0056, T0059 à T0068.
- La revue par jalon est une consigne dans les invites, pas un contrôle
  déterministe : rien n'empêche techniquement une revue unique en fin de
  fonctionnalité.
- Une fonctionnalité abandonnée coûte plus qu'un ticket abandonné. Andy a accepté ce
  coût le 5 août 2026 contre la suppression de l'empilement de branches.

### Follow-ups

- Ajouter un contrôle déterministe qui refuse une Pull Request dont la base n'est pas
  `main`. Cinq occurrences : #68, #70, #72, #74 et #110. Ce ticket ne le livre pas.
- Couvrir `.claude/workflows/*.js` par un test de chargement et de contrat
  d'arguments, y compris la boucle par jalon.
- Nettoyer les 26 worktrees résiduels de `.worktrees/` et `.claude/worktrees/` dont
  la branche est fusionnée.
- Écrire la première fonctionnalité `F0001` et corriger le format sur ce qu'elle
  révèle.

### Documentation updated

`AGENTS.md`, `docs/WORKFLOW.md`, `docs/templates/FEATURE.md`,
`docs/features/README.md`, `docs/tickets/README.md`.
