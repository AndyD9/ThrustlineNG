# T0063 — Faire avancer la boucle de tickets sans déclenchement humain

Status: Review
Owner: Codex
Branch: `chore/T0063-boucle-tickets-planifiee`
Phase: Gouvernance
Risk: Medium
Security-sensitive: No
Autonomous: No

## Goal

La boucle de tickets avance une fois par jour ouvré sans qu'Andy la déclenche, et
n'exécute sans surveillance que des tickets dont le travail restant n'exige aucun
humain, cette frontière étant calculée par le sélecteur et non par un agent.

## Context

T0061 a livré la boucle dans `main` par la PR #108, au merge `c51f3fe` : sélecteur
déterministe, gate, deux workflows séparés par une porte humaine et la skill
`/ticket-loop`. Elle reste entièrement déclenchée à la main, et T0061 l'inscrivait
même en non-objectif.

Andy a tranché le 5 août 2026 que l'intérêt principal est justement d'automatiser
ce cycle. Ce ticket lève donc ce non-objectif, en le remplaçant par une frontière
vérifiable plutôt que par de la confiance.

Trois contraintes cadrent la solution :

1. les preuves du dépôt exigent PowerShell Windows, pnpm, les worktrees et parfois
   Docker. La planification doit donc tourner sur la machine d'Andy, pas dans un
   runner distant ;
2. un run non surveillé ne peut pas poser de question. Tout ce qui relève d'une
   décision d'Andy ou d'une vérification humaine doit être détecté et reporté, pas
   contourné ;
3. le worktree principal peut porter un travail humain en cours. Un run non
   surveillé ne doit jamais écrire sur sa branche courante.

Andy a également retenu la cadence d'un run par jour ouvré, silencieux tant
qu'aucune action ne lui revient.

## Dependencies

- T0061, fusionné dans `main` au merge `c51f3fe`.
- T0062, **non fusionné** : cette branche est empilée dessus parce que les deux
  modifient `tests/ticket-automation/run.ps1`. Condition de sortie : dès que T0062
  est dans `main`, recibler cette Pull Request sur `main` si l'ascendance le
  permet, sinon ouvrir une branche de propagation propre sans force-push.
- Décision d'Andy du 5 août 2026 sur la planification, la cadence et la frontière
  d'autonomie.

## Allowed areas

- `scripts/select-ticket-batch.ps1`
- `tests/ticket-automation/run.ps1`
- `.claude/workflows/ticket-plan.js`
- `.claude/workflows/ticket-run.js`
- `.claude/skills/ticket-loop/SKILL.md`
- `docs/templates/TICKET.md` pour le seul champ optionnel `Autonomous`
- `docs/WORKFLOW.md`
- `docs/QUALITY.md`
- `docs/tickets/T0063-boucle-tickets-planifiee.md`
- `docs/tickets/README.md`

## Do not touch

- `AGENTS.md` : la boucle applique ses règles, elle ne les modifie pas.
- `docs/tickets/T0061-automatiser-cycle-tickets.md` : ticket fusionné, son rapport
  historique n'est pas réécrit.
- `docs/tickets/T0062-reparer-gate-automatisation-tickets.md` et
  `.github/workflows/ci.yml` : ils appartiennent à T0062.
- `docs/ROADMAP.md`, `docs/PRODUCT.md`, `docs/SECURITY.md`, `docs/ARCHITECTURE.md`
  et les ADR.
- Tout code applicatif : `apps/`, `supabase/`, `packages/`, `eng/`.

## Requirements

- Le sélecteur classe chaque ticket `autonomous` ou `human required` en lisant le
  ticket lui-même. Sont des vetos : `Autonomous: No`, `Security-sensitive: Yes`,
  `Risk: High`, et toute dépendance nommant une décision d'Andy, MSFS, SimConnect,
  du matériel, une vérification humaine ou une revue de phase.
- `-AutonomousOnly` reporte tout candidat non `autonomous` avec sa raison exacte,
  et ne sélectionne jamais rien d'autre.
- La frontière est visible dans le ticket, donc relisible par Andy. Un agent ne
  peut ni l'élargir ni la contourner.
- `ticket-run` accepte `autonomousOnly` et le transmet au sélecteur. `mode:
  "execute"` reste obligatoire pour écrire quoi que ce soit.
- `ticket-plan` accepte `repoRoot` afin qu'un run non surveillé planifie dans un
  worktree dédié, jamais sur la branche courante du worktree principal.
- Une tâche planifiée locale exécute la boucle une fois par jour ouvré, tôt. Elle
  vit dans le profil utilisateur, hors du dépôt, et son invite est autonome : elle
  ne dépend d'aucune mémoire de conversation.
- Le run planifié applique l'ordre de priorité de `docs/WORKFLOW.md` : PR prête à
  intégrer, CI ou propagation bloquante, puis nouveau travail.
- Il ne prépare une vague que si aucune Pull Request de la boucle n'attend déjà
  Andy, pour ne pas empiler des planifications quasi identiques.
- Il ne notifie Andy que si une action lui revient : PR prête à fusionner, décision
  réservée, CI rouge, incohérence de suivi, découverte `Critical` ou `High`.
- Il ne fusionne jamais, ne force-push jamais, n'utilise jamais `git add .`.

## Non-goals

- Élargir la frontière d'autonomie. Exécuter sans surveillance un ticket sensible,
  `Risk: High` ou dépendant d'une décision humaine reste une décision d'Andy.
- Planifier la boucle ailleurs que sur la machine d'Andy, ou la faire tourner quand
  l'application est fermée.
- Versionner le fichier de la tâche planifiée : il appartient au profil
  utilisateur. Le dépôt en documente le comportement.
- Fusionner, propager ou rebaser une Pull Request.
- Automatiser la vérification manuelle d'un ticket ou une preuve Windows/MSFS.
- Créer le premier ticket réellement autonome : c'est un follow-up.

## Acceptance criteria

- [x] `pwsh -File .\scripts\select-ticket-batch.ps1 -AutonomousOnly` classe les
      tickets réels et reporte chacun avec son veto nommé.
- [x] `pnpm ticket-automation:check` passe et couvre les quatre vetos d'autonomie
      plus leur réciproque : le même veto ne bloque pas un run surveillé.
- [x] Le gate passe sous Windows PowerShell 5.1 et sous PowerShell 7.
- [x] `ticket-run` transmet `-AutonomousOnly` et continue d'exiger
      `mode: "execute"` pour écrire.
- [x] `ticket-plan` travaille dans le `repoRoot` fourni et refuse explicitement de
      toucher un autre worktree.
- [x] La tâche planifiée existe, à 07:38 du lundi au vendredi, avec une invite
      autonome qui porte les limites absolues.
- [x] `pnpm maintenance:check` passe : statut du ticket et ligne d'index identiques.
- [x] Aucun fichier applicatif n'est modifié, et le fichier de T0061 est inchangé.

## Security review

`Security-sensitive: No`. Aucun actif, secret, donnée personnelle ni frontière de
confiance n'est touché.

Le risque réel reste l'usurpation d'autorité, et il augmente avec l'absence de
surveillance : un run non surveillé pourrait démarrer un ticket qui exige un
jugement humain. Il est traité par une classification déterministe lue dans le
ticket, par `-AutonomousOnly` qui refuse d'élargir la sélection, par l'obligation
de `mode: "execute"`, et par le fait qu'aucune écriture n'atteint `main` sans une
fusion d'Andy.

Sur le backlog du 5 août 2026, cette frontière ne retient aucun ticket : les deux
candidats `Ready` sont reportés. C'est le comportement attendu d'une frontière qui
échoue fermé.

## Maintenance review

- dettes et problèmes connus applicables : la dérive d'index des fusions T0043 à
  T0050, déjà signalée par le sélecteur ; les PR fusionnées dans une base parente.
- dette créée ou aggravée : cette branche est empilée sur T0062 et devra être
  reciblée sur `main`. La frontière d'autonomie repose en partie sur la prose des
  `Dependencies` : un ticket qui aurait besoin d'une décision sans l'écrire serait
  classé autonome, et seul le champ `Autonomous: No` rattrape ce cas.
- règle de sécurité ajoutée, modifiée ou à revalider : aucune.
- contrôle manuel à automatiser : le déclenchement quotidien de la boucle et le
  tri entre tickets autonomes et tickets à humain passent de manuels à
  déterministes. Restent manuels : la relecture, le merge et les vérifications
  interactives.
- risque résiduel ou exception approuvée : la tâche planifiée n'a jamais tourné.
  Aucun gate ne vérifie qu'elle conserve `autonomousOnly` dans son invite. Aucune
  exception de sécurité.

## Automated validation

```powershell
pnpm ticket-automation:check
pwsh -NoProfile -File .\tests\ticket-automation\run.ps1
pwsh -NoProfile -File .\scripts\select-ticket-batch.ps1 -AutonomousOnly
pnpm maintenance:check
```

## Manual verification

1. Exécuter `pnpm ticket-batch:select` puis la même commande avec
   `-AutonomousOnly`, et confirmer que la seconde sélection est un sous-ensemble de
   la première, chaque report nommant son veto.
2. Ajouter temporairement `Autonomous: No` à un ticket `Ready` classé autonome,
   relancer `-AutonomousOnly`, confirmer qu'il est reporté, puis rétablir le
   fichier.
3. Confirmer que l'invite de la tâche planifiée contient `autonomousOnly: true` et
   `mode: "execute"`, et qu'elle n'autorise aucune fusion :
   `Select-String -Path "$env:USERPROFILE\.claude\scheduled-tasks\thrustlineng-ticket-loop\SKILL.md" -Pattern 'autonomousOnly|gh pr merge'`.
4. Lancer la tâche une fois manuellement depuis la section « Scheduled », confirmer
   qu'elle ne modifie pas la branche courante du worktree principal
   (`git status --short` inchangé) et qu'elle ne notifie que si une action revient
   à Andy.

Temps cible : 5–10 minutes, hors durée du run manuel.

## Rollback

Supprimer la tâche planifiée depuis la section « Scheduled », puis retirer
`-AutonomousOnly` du sélecteur, `autonomousOnly` de `ticket-run`, `repoRoot` de
`ticket-plan`, le champ `Autonomous` du template et les sections ajoutées à
`docs/WORKFLOW.md`, `docs/QUALITY.md` et la skill. La boucle T0061 redevient
entièrement déclenchée à la main. Aucune donnée, migration ni capacité produit
n'est concernée.

## Completion Report

### Summary

La frontière d'autonomie est calculée par `scripts/select-ticket-batch.ps1`, qui
lit maintenant `Risk`, `Security-sensitive` et le champ optionnel `Autonomous`, et
scanne les `Dependencies` à la recherche d'un besoin humain nommé. Chaque ticket
porte `autonomy` et `autonomyVetoes` dans le rapport JSON ; `-AutonomousOnly`
reporte tout ce qui n'est pas `autonomous`, avec la raison exacte.

`ticket-run` transmet ce mode et continue d'exiger `mode: "execute"` pour écrire.
`ticket-plan` accepte `repoRoot`, ce qui permet à un run non surveillé de planifier
dans un worktree dédié sans jamais toucher la branche courante du worktree
principal.

La tâche planifiée locale porte l'invite complète : ordre de priorité de
`docs/WORKFLOW.md`, limites absolues, obligation de `autonomousOnly: true`,
condition anti-empilement des PR de planification, et notification réservée aux cas
où une action revient à Andy.

### Files changed

- `scripts/select-ticket-batch.ps1` — classification d'autonomie et `-AutonomousOnly`.
- `tests/ticket-automation/run.ps1` — cinq scénarios supplémentaires.
- `.claude/workflows/ticket-run.js` — `autonomousOnly`, transmis au sélecteur.
- `.claude/workflows/ticket-plan.js` — `repoRoot` et interdiction des autres worktrees.
- `.claude/skills/ticket-loop/SKILL.md` — mode non surveillé et run planifié.
- `docs/templates/TICKET.md` — champ optionnel `Autonomous` et sa sémantique.
- `docs/WORKFLOW.md` — section du run planifié.
- `docs/QUALITY.md` — mutations d'autonomie et exigence des deux hôtes.
- `docs/tickets/T0063-boucle-tickets-planifiee.md` — ce ticket.
- `docs/tickets/README.md` — ligne d'index T0063.

Hors du dépôt, dans le profil utilisateur :
`~/.claude/scheduled-tasks/thrustlineng-ticket-loop/SKILL.md`.

### Commands and results

| Commande | Résultat |
| --- | --- |
| `pnpm ticket-automation:check` | passed — 50 assertions, 15 mutations |
| `pwsh -NoProfile -File .\tests\ticket-automation\run.ps1` | passed — 50 assertions, 15 mutations |
| `pwsh -NoProfile -File .\scripts\select-ticket-batch.ps1 -AutonomousOnly` | passed — aucun ticket autonome ; T0056 et T0060 reportés avec leur veto |
| `pnpm ticket-batch:select` | passed — T0056 et T0060 sélectionnés, contention signalée sur l'index |
| `pnpm maintenance:check` | passed |
| `pnpm data-policy:check` | passed |
| `pnpm authority:check` | passed |
| `node --check` sur les deux workflows, enveloppés dans un contexte `async` | passed |
| `git diff --check` | passed |

### Pull request

La PR #110 est ouverte en **brouillon**, base réelle
`fix/T0062-ticket-automation-gate-crlf`, état `MERGEABLE`. Ses trois checks sont
verts le 5 août 2026 : `Windows multi-stack` en 17 min 06, `Supabase PostgreSQL 17`
en 3 min 28 et `Audits, licences and SBOM` en 3 min 54.

Cette fois, la preuve ne s'arrête pas à la couleur des checks. Le log du job
`Windows multi-stack`, étape « Validate ticket automation governance », montre
`pnpm ticket-automation:check` puis
`Ticket batch selector invariants passed: 50 assertions, 15 negative mutations`.
C'est la confirmation la plus forte du correctif de fin de ligne de T0062 : le
runner récupère le harnais en CRLF, comme `.gitattributes` le prescrit, et les
quinze mutations mordent quand même. Elle vaut mieux que la simulation locale, qui
recopiait le fichier à la main.

Cette PR ne prouve aucune livraison dans `main` : elle est empilée sur T0062, elle
reste brouillon, et sa condition de sortie est le reciblage vers `main` après la
fusion de T0062. La fusion appartient à Andy.

### Manual verification result

Étapes 1, 2 et 3 exécutées. La sélection autonome est vide et strictement incluse
dans la sélection surveillée, qui retient T0056 et T0060 ; chaque report nomme son
veto. Le veto explicite `Autonomous: No` est prouvé par la mutation 11 du gate, sur
la fixture synthétique plutôt que sur un ticket réel, afin de ne pas modifier un
ticket appartenant à un autre travail. L'invite de la tâche planifiée contient bien
`autonomousOnly: true` et `mode: "execute"`, et aucune commande de fusion.

Étape 4 non exécutée : le premier run réel de la tâche appartient à Andy. Elle n'a
jamais tourné, et son premier run peut se bloquer sur des approbations d'outils —
un « Run now » manuel les pré-approuve.

### Risks and limitations

- La tâche planifiée n'a jamais tourné. Tout son comportement est prouvé par
  relecture de son invite et par les composants qu'elle appelle, pas par un run.
- Aucun gate ne vérifie que l'invite conserve `autonomousOnly` et `mode:
  "execute"`. Un futur changement pourrait les retirer sans qu'un contrôle échoue.
- La frontière lit la prose des `Dependencies`. Un ticket qui aurait réellement
  besoin d'une décision d'Andy sans l'écrire serait classé autonome ; le champ
  `Autonomous: No` est le rattrapage explicite, mais il faut penser à l'écrire.
- Sur le backlog actuel, aucun ticket ne qualifie : la boucle planifiée préparera et
  rapportera sans rien exécuter jusqu'à ce qu'un ticket qualifie.
- La tâche ne tourne que quand l'application est ouverte. Un jour sans ouverture est
  un jour sans run ; le run part au lancement suivant.
- Cette branche est empilée sur T0062, non fusionnée. Elle ne prouve donc aucune
  livraison dans `main`.

### Learning candidate LC-2026-007

- Date : 5 août 2026
- Contexte : T0063, worktree principal partagé
- État : Reproduced
- Symptôme observé : un commit destiné à une branche de ticket a été créé sur
  `main`. Le push a été refusé par le hook de protection de branche.
- Conclusion erronée évitée : « la branche courante est celle que j'ai créée ». Une
  autre session travaillant dans le même worktree avait fusionné la PR #108,
  basculé sur `main`, créé `fix/T0062-ticket-automation-gate-crlf`, puis laissé
  `HEAD` sur `main`.
- Diagnostics exécutés : `git reflog` montre `checkout: moving from
  fix/T0062-ticket-automation-gate-crlf to main` juste avant le commit ;
  `git rev-list --left-right --count origin/main...main` a confirmé un seul commit
  local en avance ; le commit a été sauvé sur une branche avant tout reset.
- Cause : Confirmée. Plusieurs acteurs partagent un worktree dont `HEAD` est un
  état global, et le contenu du répertoire de travail avait déjà changé sous cette
  session.
- Reproductibilité : déterministe dès que deux sessions opèrent sur le même
  worktree.
- Portée : toute session travaillant dans le worktree principal.
- Contournement sûr : relever la branche courante juste avant chaque `git commit`,
  pas seulement au début du travail. En cas d'erreur, sauver le commit sur une
  branche nommée avant tout `reset`, puis remettre `main` sur `origin/main`. Un
  worktree dédié par ticket évite entièrement le problème.
- Risques : sans la protection de branche, ce commit aurait été poussé sur `main`
  sans revue ni CI. La protection a été le seul garde-fou effectif.
- Destination proposée : `docs/WORKFLOW.md`, section du handoff Git, ou un contrôle
  déterministe qui refuse un commit sur `main` depuis le worktree principal.
- Revalidation : au prochain travail concurrent dans ce worktree.

### Follow-ups

- Recibler cette Pull Request sur `main` dès que T0062 y est fusionné.
- Créer un premier ticket réellement autonome — gouvernance ou lecture desktop à
  faible risque — pour que la boucle planifiée ait de quoi exécuter.
- Ajouter un contrôle déterministe des gardes d'autonomie de l'invite planifiée et
  de `mode: "execute"`.
- Promouvoir LC-2026-002 à LC-2026-007 dans `docs/LEARNINGS.md`.
- Étudier un garde-fou local qui refuse un commit sur `main` depuis le worktree
  principal, d'après LC-2026-007.

### Documentation updated

`docs/WORKFLOW.md`, `docs/QUALITY.md`, `docs/templates/TICKET.md`,
`docs/tickets/README.md`.
