# T0068 — Faire de la fonctionnalité l'unité de suivi, de branche et d'intégration

Status: Draft
Owner: Unassigned
Branch: `chore/T0068-unite-fonctionnalite`
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
- T0064 **non fusionné** (PR #113) : il modifie déjà `.claude/workflows/` sur les
  charges JSON de la boucle, donc les mêmes fichiers. Seule dépendance restante.
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

- [ ] `docs/templates/FEATURE.md` existe et impose un `Goal` unique, l'union des
      `Allowed areas`, et des jalons ordonnés portant chacun résultat, frontière,
      validations, `Autonomous`, `Security-sensitive`, `Risk` et Completion Report.
- [ ] `docs/features/README.md` existe avec un index vide et sa convention de
      nommage `F0001-slug.md`.
- [ ] `docs/tickets/README.md` déclare l'archive en tête, sans qu'aucune ligne ni
      aucun statut existant ne change.
- [ ] `docs/WORKFLOW.md` remplace les §1, §2 et « Limites de taille » par l'unité
      fonctionnalité, la revue par jalon et le plafond de deux.
- [ ] `AGENTS.md` remplace le plafond de trois flux par le plafond de deux
      fonctionnalités, sans modifier la liste de lecture obligatoire.
- [ ] `pnpm ticket-batch:select` sélectionne une fonctionnalité, rend ses jalons
      ordonnés, et rend le prochain jalon exécutable.
- [ ] Le sélecteur applique la frontière d'autonomie au jalon : un jalon
      `Security-sensitive: Yes`, `Risk: High`, `Autonomous: No`, ou dont une
      dépendance nomme une décision d'Andy, MSFS, du matériel ou une vérification
      humaine est reporté avec sa raison, sans reporter la fonctionnalité entière.
- [ ] Le sélecteur sort en échec fermé sur une incohérence de suivi au niveau
      fonctionnalité, et continue de traiter les tickets `TXXXX` en transition.
- [ ] Le sélecteur applique un plafond de deux fonctionnalités `In progress`.
- [ ] `pnpm ticket-automation:check` passe sous Windows PowerShell 5.1 et sous
      PowerShell 7, avec au moins une mutation négative par règle nouvelle.
- [ ] Une mutation qui ne change rien échoue bruyamment comme défaut de test.
- [ ] `ticket-plan` écrit une fonctionnalité et non plusieurs tickets ;
      `ticket-run` produit une branche, une Pull Request brouillon et un commit par
      jalon.
- [ ] `pnpm ci:check`, `pnpm maintenance:check` et `pnpm product-version:check`
      passent.
- [ ] Aucun fichier applicatif n'est modifié ; `git diff --check` est propre.

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

À remplir après implémentation.

### Summary

### Files changed

### Commands and results

### Manual verification result

### Risks and limitations

### Follow-ups

### Documentation updated
