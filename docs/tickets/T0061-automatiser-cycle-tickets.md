# T0061 — Automatiser le cycle des tickets sans déplacer l'autorité d'Andy

Status: Done
Owner: Codex
Branch: `chore/T0061-automatiser-cycle-tickets`
Phase: Gouvernance
Risk: Medium
Security-sensitive: No

## Goal

Un opérateur lance une seule commande et obtient la vague de tickets suivante
écrite, exécutée jusqu'à la Pull Request brouillon et suivie d'une mise à jour
prouvée du registre d'apprentissage, sans qu'aucune décision réservée à Andy ni
aucune fusion ne soit prise par un agent.

## Context

Le dépôt possède déjà un cycle de ticket complet dans `docs/WORKFLOW.md`, une
orchestration multitâche encadrée par T0027 et des gates de gouvernance ajoutés
par T0030 et T0034. Ce cycle reste entièrement piloté à la main : à chaque vague,
un opérateur relit l'index, compte les flux disponibles, vérifie les dépendances,
attribue les chemins, lance les implémentations puis reconstitue l'état.

Ce travail répété est déterministe pour sa plus grande part, et ses erreurs sont
déjà documentées : la dérive de l'index des tickets lors des fusions T0043 à
T0050, les PR empilées fusionnées dans leur branche parente au lieu de `main`
(#68, #70, #72, #74), et des statuts d'index ramenés en `Review` alors que les
fichiers disaient `Done`, ce qui a laissé `pnpm maintenance:check` rouge sur
`main`.

Andy a tranché le 5 août 2026 les quatre décisions de cadrage de cette
automatisation :

1. la boucle s'arrête à la Pull Request brouillon et ne fusionne jamais ;
2. elle traite jusqu'à trois flux en parallèle, conformément au plafond du mode
   accéléré ;
3. le pas d'apprentissage écrit automatiquement le registre, les dettes, l'état
   courant et les tickets suivants, sans validation intermédiaire ;
4. l'automatisation passe par le process du dépôt, donc par ce ticket.

La décision 3 est la plus engageante : elle autorise un agent à écrire dans
`docs/LEARNINGS.md`, `docs/KNOWN_ISSUES.md` et `docs/CURRENT_STATE.md` sans
relecture préalable. Ce ticket la borne de deux façons vérifiables au lieu d'une
confiance : ces écritures se font sur une branche dédiée et n'atteignent `main`
que par une fusion d'Andy, et le seuil de promotion de `docs/LEARNINGS.md` reste
appliqué — une occurrence unique reste `Observed`, et une modification de
`AGENTS.md` reste proposée dans le corps de la PR, jamais écrite.

## Dependencies

- T0027 pour les règles d'orchestration multitâche et le rôle de coordinateur.
- T0030 et T0034 pour le gate de maintenance et sa fixture découplée.
- T0055 pour la structure de gate à mutations négatives reprise ici.
- Décision d'Andy du 5 août 2026 sur les quatre points de cadrage ci-dessus.

## Allowed areas

- `scripts/select-ticket-batch.ps1`
- `tests/ticket-automation/run.ps1`
- `.claude/workflows/ticket-plan.js`
- `.claude/workflows/ticket-run.js`
- `.claude/skills/ticket-loop/SKILL.md`
- `package.json` pour les seuls scripts `ticket-automation:check` et `ticket-batch:select`
- `docs/WORKFLOW.md`
- `docs/QUALITY.md`
- `docs/tickets/T0061-automatiser-cycle-tickets.md`
- `docs/tickets/README.md`

## Do not touch

- `AGENTS.md` : l'automatisation applique ses règles, elle ne les modifie pas.
- `docs/ROADMAP.md`, `docs/PRODUCT.md`, `docs/SECURITY.md`, `docs/ARCHITECTURE.md`
  et les ADR.
- `docs/CURRENT_STATE.md` : ce ticket ne livre aucune capacité produit.
- Tout code applicatif : `apps/`, `supabase/`, `packages/`, `eng/`.
- Les gates existants `tests/maintenance/`, `tests/data-policy/`,
  `tests/authority/` et `.github/workflows/`.

## Requirements

- Un sélecteur déterministe, sans agent, décide ce qui est exécutable : capacité
  de flux, dépendances, cohérence entre fichier de ticket et index, collisions de
  `Allowed areas`. Un agent ne peut ni élargir sa sélection ni ignorer un report.
- Les fichiers de suivi partagés — `docs/tickets/README.md`,
  `docs/CURRENT_STATE.md`, `docs/KNOWN_ISSUES.md`, `docs/LEARNINGS.md`,
  `docs/ROADMAP.md` — ne comptent pas comme collisions mais imposent un ordre
  d'intégration explicite, rendu par le sélecteur.
- Le plafond de flux vaut 3 par défaut et n'est jamais dépassé silencieusement.
- La boucle est coupée en deux workflows par une porte humaine, parce qu'un
  workflow s'exécute en arrière-plan et ne peut pas poser de question : les
  décisions réservées à Andy sont rendues en un seul lot entre les deux.
- Chaque ticket exécuté obtient un worktree dédié sous `.worktrees/`, une branche
  partant du dernier `origin/main`, une revue adversariale conduite par un agent
  qui n'a pas écrit le code, puis une Pull Request **brouillon**.
- Aucun agent de la boucle ne fusionne une Pull Request, ne force-push, n'utilise
  `git add .` ou `git add -A`, ne touche au worktree principal ni ne change sa
  branche courante.
- `ticket-run` n'écrit rien sans `mode: "execute"`. Il échoue fermé : arguments
  absents, illisibles ou transmis sous une autre forme donnent une sélection en
  lecture seule, jamais une implémentation.
- Le pas d'apprentissage écrit sur une branche dédiée, applique le seuil de
  promotion de `docs/LEARNINGS.md`, n'écrit dans `docs/CURRENT_STATE.md` que ce
  qui est réellement dans `origin/main`, et rend explicitement la liste de ce
  qu'il a refusé d'écrire pour cette raison.
- Le pas d'apprentissage ne réécrit aucune ligne d'index appartenant à un ticket
  de la vague en cours, pour ne pas recréer la dérive d'index déjà observée.
- Les scripts PowerShell restent en ASCII, sans BOM, pour être analysables par
  Windows PowerShell 5.1 comme par PowerShell 7.

## Non-goals

- Fusionner, propager ou rebaser une Pull Request.
- Décider une règle produit, économique, de sécurité, de données ou de support.
- Modifier `AGENTS.md` ou une ADR, même quand un apprentissage le suggère.
- Exécuter la boucle sur une planification (`cron`, tâche programmée) : la boucle
  reste déclenchée explicitement.
- Ajouter ce gate à la CI GitHub : `.github/workflows/` est hors périmètre, comme
  pour T0055. Le contrôle reste local jusqu'au ticket qui l'ajoutera.
- Remplacer la vérification manuelle d'un ticket ou une vérification Windows/MSFS.

## Acceptance criteria

- [x] `pnpm ticket-batch:select` rend la sélection, l'ordre d'intégration et la
      contention des fichiers partagés, et sort en échec sur une incohérence de
      suivi.
- [x] `pnpm ticket-automation:check` passe et couvre dix mutations négatives :
      statut divergent, statut invalide, champ `Status` absent, ticket absent de
      l'index, identifiant dupliqué, dépendance revenue en `Draft`, collision de
      zones autorisées entre candidats, flux `In progress` qui consomme la
      capacité et réserve ses chemins, ticket forcé non `Ready`, sélection forcée
      séparée par des virgules.
- [x] Le gate passe sous Windows PowerShell 5.1 et sous PowerShell 7.
- [x] `.claude/workflows/ticket-plan.js` et `.claude/workflows/ticket-run.js`
      chargent sans erreur.
- [x] `ticket-run` lancé sans aucun argument rend la sélection et s'arrête : ni
      worktree, ni branche, ni commit, ni Pull Request, et `git status --short`
      reste limité aux fichiers de ce ticket.
- [x] `.claude/skills/ticket-loop/SKILL.md` documente la porte humaine, les
      limites absolues et les pièges déjà payés par le dépôt.
- [x] `docs/WORKFLOW.md` et `docs/QUALITY.md` décrivent la boucle et son gate.
- [x] `pnpm maintenance:check` passe : le statut de ce ticket et sa ligne d'index
      sont identiques.
- [x] Aucun fichier applicatif n'est modifié.

## Security review

`Security-sensitive: No`. Aucun actif, secret, donnée personnelle ni frontière de
confiance n'est touché : le livrable est un sélecteur en lecture seule, un gate de
test et des consignes d'orchestration.

Le risque réel n'est pas une vulnérabilité mais une **usurpation d'autorité** : un
agent qui fusionnerait, trancherait une décision produit ou écrirait une règle
globale. Il est traité par des limites absolues répétées dans chaque invite
d'agent, par un sélecteur qui refuse d'élargir la sélection, et par le fait que
toute écriture atteint `main` uniquement via une fusion d'Andy.

## Maintenance review

- dettes et problèmes connus applicables : la dérive d'index des fusions T0043 à
  T0050 et les PR fusionnées dans une base parente ; toutes deux sont désormais
  détectées ou signalées par le sélecteur et rappelées dans la skill.
- dette créée ou aggravée : le sélecteur relit `docs/tickets/README.md` avec sa
  propre logique de tableau, en duplication partielle de `tests/maintenance/run.ps1`.
  Les deux resteraient à unifier si un troisième lecteur apparaissait.
- règle de sécurité ajoutée, modifiée ou à revalider : aucune.
- contrôle manuel à automatiser : le comptage des flux, la vérification des
  dépendances et la détection des collisions de chemins passent de manuels à
  déterministes. Restent manuels : la propagation des PR et la relecture d'Andy.
- risque résiduel ou exception approuvée : le pas d'apprentissage écrit sans
  relecture préalable, par décision d'Andy du 5 août 2026. Son risque résiduel est
  une écriture inexacte dans un document de suivi, visible dans le diff de sa PR
  brouillon et jamais dans `main` sans fusion. Aucune exception de sécurité.

## Automated validation

```powershell
pnpm ticket-automation:check
pnpm ticket-batch:select
pnpm maintenance:check
pwsh -NoProfile -File .\tests\ticket-automation\run.ps1
```

## Manual verification

1. Depuis la racine, exécuter `pnpm ticket-batch:select` et confirmer que la
   sélection ne dépasse pas trois tickets et n'inclut que des tickets `Ready`.
2. Ouvrir un ticket `Ready`, changer son champ `Status` en `Review` sans toucher
   à l'index, relancer la commande : elle doit sortir en échec en nommant le
   ticket et les deux statuts. Rétablir le fichier.
3. Exécuter `pnpm ticket-automation:check` et confirmer les neuf mutations.
4. Lancer la boucle en mode sélection seule et confirmer qu'aucun fichier n'est
   modifié : `git status --short` doit rester vide.
5. Confirmer qu'aucune des deux invites de workflow n'autorise une fusion :
   `Select-String -Path .claude\workflows\*.js -Pattern 'gh pr merge|--merge'`
   ne doit rien retourner.

Temps cible : 5–10 minutes.

## Rollback

Supprimer `scripts/select-ticket-batch.ps1`, `tests/ticket-automation/`,
`.claude/workflows/ticket-plan.js`, `.claude/workflows/ticket-run.js`,
`.claude/skills/ticket-loop/`, les deux scripts ajoutés à `package.json` et les
sections ajoutées à `docs/WORKFLOW.md` et `docs/QUALITY.md`. Le cycle redevient
entièrement manuel. Aucune donnée, migration ni capacité produit n'est concernée.

## Completion Report

### Summary

La boucle est livrée en trois pièces séparées par responsabilité. Le sélecteur
`scripts/select-ticket-batch.ps1` est la seule autorité sur ce qui est
exécutable : il lit les 59 fichiers de tickets et l'index, refuse toute
incohérence de suivi, expanse les plages de dépendances `T0007–T0009`, sépare les
chemins exclusifs des fichiers de suivi partagés, détecte les collisions et
plafonne la sélection à trois flux en tenant compte des tickets déjà
`In progress`. Aucun agent n'intervient dans cette décision.

`tests/ticket-automation/run.ps1` prouve ce comportement sur un dépôt synthétique
avec 34 assertions et 10 mutations négatives, sans dépendre des tickets réels. Le
harnais lance le sélecteur avec l'hôte PowerShell qui l'exécute, ce qui l'a rendu
capable de détecter une régression réelle visible sous un seul des deux hôtes.

Les deux workflows portent l'exécution. `ticket-plan` établit l'état prouvé,
cadre au plus un ticket par flux, écrit un fichier par ticket de façon
séquentielle puis consolide l'index et rejoue les gates. `ticket-run` sélectionne,
implémente chaque ticket dans son worktree, fait relire son diff poussé par un
agent qui ne l'a pas écrit, remédie aux constats bloquants confirmés, puis ferme
la boucle d'apprentissage. La skill `/ticket-loop` tient la porte humaine entre
les deux, parce qu'un workflow en arrière-plan ne peut pas poser de question.

`ticket-run` n'écrit qu'avec `mode: "execute"` et échoue fermé sur tout autre
argument. Cette garde n'était pas dans le cadrage initial : elle vient d'un
incident réel pendant la mise au point, consigné en LC-2026-004, où un drapeau
`dryRun` exprimé en négatif a dégradé vers le mode écriture parce que l'argument
est arrivé sous forme de chaîne JSON.

### Files changed

- `scripts/select-ticket-batch.ps1` — sélecteur déterministe, lecture seule.
- `tests/ticket-automation/run.ps1` — gate, 32 assertions, 9 mutations négatives.
- `.claude/workflows/ticket-plan.js` — planification en quatre phases.
- `.claude/workflows/ticket-run.js` — exécution en cinq phases.
- `.claude/skills/ticket-loop/SKILL.md` — orchestration et porte humaine.
- `package.json` — `ticket-automation:check` et `ticket-batch:select`.
- `docs/WORKFLOW.md` — section « Boucle automatisée des tickets ».
- `docs/QUALITY.md` — section « Automatisation du cycle des tickets ».
- `docs/tickets/T0061-automatiser-cycle-tickets.md` — ce ticket.
- `docs/tickets/README.md` — ligne d'index T0061.

### Commands and results

| Commande | Résultat |
| --- | --- |
| `pnpm ticket-automation:check` | passed — 34 assertions, 10 mutations |
| `pwsh -NoProfile -File .\tests\ticket-automation\run.ps1` | passed — 34 assertions, 10 mutations |
| `pnpm ticket-batch:select` | passed — 60 tickets, capacité 3/3, T0056 sélectionné |
| `pwsh -NoProfile -File .\scripts\select-ticket-batch.ps1 -Only "T0056,T0059"` | exit 1 attendu — « Requested ticket T0059 is 'Draft', not Ready », T0056 sélectionné |
| `pnpm maintenance:check` | passed — registre, index, marqueurs, 8 scénarios |
| `node --check` sur les deux workflows, enveloppés dans un contexte `async` | passed |
| `Workflow({ scriptPath: ".claude/workflows/ticket-run.js" })`, sans argument | passed — `mode: select`, 1 agent, T0056 sélectionné, aucune écriture |
| `Workflow(...)` avec l'ancien drapeau `dryRun` | failed — a démarré une implémentation réelle, arrêtée par `TaskStop` ; cause en LC-2026-004 |
| `pnpm data-policy:check` | passed — dépôt T0017–T0020 et 6 scénarios |
| `pnpm authority:check` | passed — 10 étapes, 13 domaines, 3 surfaces, 9 scénarios |
| `git diff --check` | passed |
| `pnpm ticket-batch:select` après la fusion de `origin/main` | passed — 61 tickets, T0056 et T0060 sélectionnés, contention signalée sur `docs/tickets/readme.md` |

Cette dernière exécution est la première preuve du sélecteur sur des données
réelles et non synthétiques : deux tickets `Ready` aux chemins exclusifs disjoints
sont sélectionnés ensemble, et l'outil signale que tous deux réclament l'index,
donc qu'ils exigent un ordre d'intégration sérialisé.

Deux candidats d'apprentissage, conservés ici parce que `docs/LEARNINGS.md` est
hors des `Allowed areas` de ce ticket :

### Learning candidate LC-2026-002

- Date : 5 août 2026
- Contexte : T0061, `chore/T0061-automatiser-cycle-tickets`
- État : Reproduced
- Symptôme observé : `scripts/select-ticket-batch.ps1` échouait sous Windows
  PowerShell 5.1 avec une erreur d'analyse, alors qu'il s'exécutait sous
  PowerShell 7.
- Conclusion erronée évitée : « le script contient une faute de syntaxe ». La
  syntaxe était valide ; c'est l'encodage qui différait.
- Cause : Confirmée. Windows PowerShell 5.1 lit un `.ps1` sans BOM comme de l'ANSI,
  ce qui corrompt les tirets cadratins présents dans une expression régulière.
- Reproductibilité : déterministe. Tous les autres `.ps1` du dépôt sont en ASCII
  strict, ce qui est le contre-exemple.
- Portée : tout script PowerShell du dépôt.
- Contournement sûr : garder les `.ps1` en ASCII et construire les caractères
  non-ASCII par code, par exemple `[char]0x2013`.
- Destination proposée : `docs/QUALITY.md`, section toolchain, ou un contrôle
  déterministe dans `tests/`.
- Revalidation : au prochain changement d'hôte PowerShell par défaut.

### Learning candidate LC-2026-003

- Date : 5 août 2026
- Contexte : T0061, même branche
- État : Reproduced
- Symptôme observé : `-Only "T0003,T0004"` sélectionnait zéro ticket sous
  PowerShell 7 et deux tickets sous 5.1, pour le même script et les mêmes
  arguments.
- Conclusion erronée évitée : « le gate est vert, donc le découpage d'arguments
  fonctionne ». Il n'était vert que sous l'hôte 5.1.
- Cause : Confirmée. Deux effets combinés : 5.1 découpe une valeur contenant une
  virgule passée via `-File` alors que 7 la garde entière, et
  `String.Split` avec un séparateur `object[]` ne découpe pas sous PowerShell 7.
- Reproductibilité : déterministe, `$a.Split(@(",", ";", " "), ...)` rend un seul
  élément sous 7. L'opérateur `-split '[,;\s]+'` se comporte identiquement sur les
  deux hôtes.
- Portée : tout script du dépôt qui reçoit une liste par `-File`.
- Destination proposée : `docs/QUALITY.md` — un gate qui accepte une liste doit
  être exécuté sous les deux hôtes ; c'est déjà écrit dans sa section.
- Revalidation : au prochain changement d'hôte PowerShell par défaut.

### Learning candidate LC-2026-004

- Date : 5 août 2026
- Contexte : T0061, mise au point de `ticket-run`
- État : Reproduced
- Symptôme observé : `ticket-run` lancé avec `args: { dryRun: true }` a franchi sa
  garde et démarré un agent d'implémentation réel sur T0056. Le run a été arrêté
  avant qu'il crée une branche ou un worktree ; aucun fichier n'a été modifié.
- Conclusion erronée évitée : « le drapeau est passé, donc le mode est actif ».
  L'argument est arrivé sous forme de chaîne JSON, `args.dryRun` valait donc
  `undefined`, et `Boolean(undefined)` a rendu le mode écriture par défaut.
- Diagnostics exécutés : lecture de `journal.jsonl` du run, qui montre le premier
  agent de sélection rendant le résultat attendu puis un **second** agent démarré
  alors que le mode sélection devait retourner avant ; puis `git status --short`,
  `git branch -a --list "*T0056*"` et `git worktree list`, tous propres.
- Cause : Confirmée. Un drapeau de sécurité exprimé en négatif — « ne pas écrire
  si dryRun » — dégrade vers l'action dangereuse dès que sa lecture échoue.
- Reproductibilité : déterministe pour toute valeur d'argument non lue comme un
  objet.
- Portée : tout workflow qui écrit, commite, pousse ou publie.
- Contournement sûr : exprimer la garde en positif et échouer fermé. Le mode
  écriture exige `mode === 'execute'` ; tout le reste, y compris une erreur
  d'analyse, rend une sélection en lecture seule.
- Risques : un drapeau négatif dans un futur workflow reproduirait exactement ce
  comportement.
- Destination proposée : `docs/WORKFLOW.md`, section « Boucle automatisée des
  tickets », où la règle est déjà écrite. Une généralisation à tous les agents
  appartiendrait à `AGENTS.md` et reste réservée à Andy.
- Revalidation : au premier usage réel de la boucle.

Cet incident est la preuve la plus utile de ce ticket : la garde qui a
effectivement protégé le dépôt n'est pas une consigne dans une invite, c'est le
fait que le script s'arrête avant d'agir. Les consignes textuelles n'ont pas été
sollicitées, puisque l'agent d'implémentation n'a pas eu le temps de travailler.

### Learning candidate LC-2026-005

- Date : 5 août 2026
- Contexte : T0061, publication de la branche
- État : Reproduced
- Symptôme observé : ce ticket a d'abord été écrit et poussé comme `T0060`. La
  Pull Request était `CONFLICTING` et n'exécutait aucun check. `origin/main`
  portait déjà un `T0060` différent, « Opposer la fin d'usage d'un avion au
  dispatch et au départ de vol », créé pendant ce travail par une autre session.
- Conclusion erronée évitée : « le prochain identifiant libre observé au démarrage
  reste libre ». L'allocation d'identifiant n'est pas réservée : elle est constatée
  au moment de la fusion.
- Diagnostics exécutés : `gh pr view --json mergeable` a donné `CONFLICTING` sans
  aucun check ; `git merge origin/main` a produit un conflit sur la seule ligne
  T0060 de l'index ; `git ls-tree origin/main docs/tickets/` a confirmé le fichier
  concurrent.
- Cause : Confirmée. Deux sessions allouent un identifiant depuis le même
  `origin/main` sans réservation partagée.
- Reproductibilité : déterministe dès que deux tickets sont créés en parallèle.
- Portée : toute création de ticket, et donc `ticket-plan`, qui choisit son
  identifiant en listant les fichiers existants.
- Contournement sûr : vérifier l'identifiant contre `origin/main` fraîchement
  récupéré juste avant de publier, et traiter la renumérotation comme une étape
  normale plutôt que comme un incident. Résoudre le conflit d'index en conservant
  les deux lignes, jamais en écartant un côté.
- Risques : `ticket-plan` peut produire un identifiant déjà pris. Le coût est une
  renumérotation, pas une perte, tant que le conflit d'index conserve les deux
  lignes.
- Destination proposée : `docs/WORKFLOW.md`, section de la boucle automatisée.
  Un contrôle déterministe possible serait un gate qui refuse un ticket dont
  l'identifiant existe déjà dans `origin/main` avec un autre titre.
- Revalidation : au premier usage réel de `ticket-plan`.

### Manual verification result

Les cinq étapes sont exécutées. La sélection rend `T0056` seul, avec la capacité
3/3. Un statut divergé artificiellement en `Review` fait sortir le sélecteur en
échec avec le message attendu, puis le fichier a été rétabli. Les dix mutations
passent sous les deux hôtes PowerShell. Aucune invite de workflow ne contient de
commande de fusion, et les deux créations de PR passent par `gh pr create --draft`.

L'étape 4 est prouvée par un lancement réel de `ticket-run` sans aucun argument :
le run `wf_de76b6bc-358` a consommé un seul agent, rendu
`{"mode":"select","tickets":[]}` avec `T0056` sélectionné, et n'a démarré aucune
phase d'implémentation. Après ce run, `git status --short` ne contient que les
fichiers de ce ticket, `git branch -a --list "*T0056*"` est vide et aucun worktree
T0056 n'existe.

Le run précédent, `wf_de548011-0df`, est la contre-preuve utile : avec le drapeau
`dryRun` exprimé en négatif, il avait démarré un second agent d'implémentation. Il
a été arrêté par `TaskStop` avant toute écriture, ce qui a été vérifié par les
mêmes trois commandes. C'est cet écart qui a produit la garde `mode: "execute"` et
LC-2026-004.

Reste hors de cette vérification : l'exécution complète d'un ticket réel, avec
worktree, branche, commit, revue adversariale et PR brouillon. Elle appartient au
premier usage réel de la boucle et relève d'Andy, sur un ticket de son choix. Le
ticket `T0056` sélectionné ici ne s'y prête pas : ses prérequis sont explicitement
humains, puisque lui seul peut confirmer une vérification interactive.

### Risks and limitations

- Le gate prouve le sélecteur, pas la qualité du travail des agents. Les invites
  des workflows restent du texte : leur respect n'est pas vérifiable
  automatiquement, seulement observable dans les diffs et les PR produites.
  L'incident LC-2026-004 le confirme dans les deux sens : ce qui a protégé le
  dépôt est un arrêt du script, pas une consigne.
- Aucun gate ne vérifie la garde `mode: "execute"` elle-même. Elle est prouvée par
  exécution et par relecture du script, pas par un test automatisé : un futur
  ticket pourrait l'affaiblir sans qu'un contrôle échoue.
- Le pas d'apprentissage écrit sans relecture préalable. C'est la décision d'Andy
  du 5 août 2026 ; sa seule barrière est la relecture de la PR brouillon.
- La détection des collisions repose sur les chemins déclarés dans
  `Allowed areas`. Un ticket dont cette section est imprécise sera mal protégé :
  le sélecteur reporte un ticket sans aucun chemin analysable plutôt que de le
  sélectionner à l'aveugle.
- Le sélecteur duplique partiellement la lecture d'index de
  `tests/maintenance/run.ps1`.
- La boucle n'a pas encore tourné de bout en bout sur un ticket réel.

### Follow-ups

- Exécuter la boucle sur un premier ticket réel et consigner l'écart entre les
  invites et le comportement observé.
- Ajouter un contrôle déterministe de la garde `mode: "execute"` : un test qui
  échoue si `ticket-run` peut atteindre sa phase d'implémentation sans ce mode.
- Promouvoir LC-2026-002 à LC-2026-005 dans `docs/LEARNINGS.md`, hors des zones
  autorisées de ce ticket.
- Ajouter à `ticket-plan` un contrôle d'identifiant contre `origin/main` juste
  avant publication, ou un gate qui refuse un identifiant déjà pris avec un autre
  titre.
- Décider si `ticket-automation:check` rejoint la CI, avec le ticket qui touchera
  `.github/workflows/`.
- Unifier la lecture de l'index entre le sélecteur et le gate de maintenance si un
  troisième lecteur apparaît.

### Pull request

La PR #108 est ouverte en **brouillon** vers `main` depuis
`chore/T0061-automatiser-cycle-tickets`, base réelle `main`, état `MERGEABLE`.
Ses trois checks sont verts le 5 août 2026 : `Windows multi-stack` en 17 min 29,
`Supabase PostgreSQL 17` en 3 min 27 et `Audits, licences and SBOM` en 3 min 50.

La PR #107 portait le même travail sous l'identifiant T0060 et était
`CONFLICTING` sans exécuter aucun check. Elle est fermée et remplacée par #108 ;
aucun commit n'est perdu, ils sont tous dans #108.

Aucune fusion n'est effectuée. La décision appartient à Andy.

### Documentation updated

`docs/WORKFLOW.md`, `docs/QUALITY.md`, `docs/tickets/README.md`.
