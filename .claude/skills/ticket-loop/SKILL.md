---
name: ticket-loop
description: Boucle automatique des tickets ThrustlineNG — écrit la prochaine vague, la fait exécuter jusqu'à la PR brouillon, puis met à jour learnings, dettes et état courant. Utiliser quand Andy demande d'avancer les tickets, de préparer la vague suivante, ou lance /ticket-loop. Ne pas utiliser pour un ticket déjà en cours de discussion, ni pour fusionner une PR.
---

# Boucle de tickets ThrustlineNG

Cette skill orchestre deux workflows et une porte humaine. Elle ne remplace pas
`AGENTS.md` ni `docs/WORKFLOW.md` : elle les exécute.

**L'unité de travail est la fonctionnalité** depuis T0068 et la décision d'Andy du
5 août 2026 : une capacité utilisateur, un fichier dans `docs/features/`, une
branche, une Pull Request, et des jalons internes ordonnés — un commit et une revue
par jalon. `docs/tickets/` est l'archive gelée ; ses tickets encore ouverts vont
jusqu'à leur terme et le sélecteur les traite avec les mêmes règles.

## Ce que la boucle ne fait jamais

- fusionner une Pull Request : le merge appartient exclusivement à Andy ;
- trancher une ambiguïté produit, économique, de sécurité, de données, de support
  ou d'architecture ;
- modifier `AGENTS.md`, une ADR acceptée ou un budget ;
- dépasser **deux** unités de travail `In progress` simultanées ;
- ouvrir plus d'une Pull Request pour une même fonctionnalité ;
- présenter une branche non fusionnée comme livrée dans `main`.

Si l'une de ces limites est atteinte, s'arrêter et le dire à Andy.

## Arguments

`/ticket-loop` sans argument exécute le cycle complet. Sinon :

| Argument | Effet |
| --- | --- |
| `plan` | écrit ou met à jour la vague de fonctionnalités, puis s'arrête |
| `run` | exécute les unités déjà `Ready`, sans planifier |
| `dry` | affiche seulement la sélection déterministe, sans rien modifier (défaut de `ticket-run`) |
| `FXXXX [TYYYY]` | force la sélection sur ces unités, si elles sont réellement `Ready` |
| `--max N` | change le plafond d'unités (défaut 2, ne pas dépasser sans décision d'Andy) |
| `unattended` | n'exécute que les unités sans humain requis ; c'est le mode de la tâche planifiée |

## Run planifié

Une tâche planifiée locale exécute cette boucle une fois par jour ouvré à 07:38.
Elle vit dans `~/.claude/scheduled-tasks/thrustlineng-ticket-loop/SKILL.md`, hors
du dépôt, et ne tourne que quand l'application est ouverte.

Un run non surveillé n'exécute que des unités **sans humain requis**, frontière
calculée par le sélecteur :

```bash
pwsh -NoProfile -File ./scripts/select-ticket-batch.ps1 -AutonomousOnly
```

Sont reportés avec leur raison : `Autonomous: No`, `Security-sensitive: Yes`,
`Risk: High`, et toute dépendance nommant une décision d'Andy, MSFS, du matériel
ou une vérification humaine.

Pour une fonctionnalité, ces trois champs sont lus sur le **premier jalon qui n'est
pas `Done`**, pas sur l'en-tête : l'en-tête ne fournit que des valeurs par défaut.
C'est ce qui permet à un jalon de lecture seule d'avancer sans surveillance dans une
fonctionnalité dont un autre jalon touche à l'argent. Un `Autonomous: No` en en-tête
reste un veto global. Ne jamais retirer `autonomousOnly` d'un run non
surveillé, et ne jamais élargir la frontière pour « débloquer » la boucle : c'est
une décision d'Andy.

Le run planifié ne notifie que si une action revient à Andy. Un run silencieux est
un run réussi.

## 1. Vérifier l'état avant tout

Toujours commencer par la sélection déterministe : elle est la seule autorité sur
ce qui est exécutable.

```bash
pwsh -NoProfile -File ./scripts/select-ticket-batch.ps1
```

Sortie non nulle = incohérence de suivi (statut divergent, ticket absent de
l'index, dépendance introuvable). Dans ce cas, **ne rien planifier ni exécuter** :
proposer à Andy un ticket de réconciliation borné, puis s'arrêter.

Vérifier aussi qu'aucune PR déjà validée n'attend seulement sa propagation vers
`main` : l'ordre de priorité de `docs/WORKFLOW.md` est PR prête à intégrer, CI ou
propagation bloquante, dépendance du golden path, puis nouveau ticket.

## 2. Planifier (sauf en mode `run` ou `dry`)

Lancer le workflow `ticket-plan` :

- `Workflow({ scriptPath: ".claude/workflows/ticket-plan.js" })`
- arguments optionnels : `args: { flows: ["backend"], maxTickets: 1 }`

Toujours passer `scriptPath` plutôt que `name`. La résolution par nom dépend de la
découverte des workflows par la session : un fichier ajouté ou renommé en cours de
session peut ne pas être trouvé par son nom tant qu'il n'a pas été chargé une
première fois. Observé le 5 août 2026 : `name: "ticket-run"` a renvoyé
`Workflow not found` juste après création, alors que `scriptPath` a fonctionné.

Il produit des fichiers de ticket, leurs lignes d'index, les gates rejoués et un
lot de décisions réservées à Andy. Il ne commite pas.

## 3. Porte humaine : le lot de décisions

Si `ticket-plan` renvoie des `decisions`, les poser à Andy **en un seul lot** avec
`AskUserQuestion`, une question par décision, avec des options réelles issues du
cadrage. C'est la raison pour laquelle la boucle est coupée en deux : un workflow
tourne en arrière-plan et ne peut pas poser de question.

Après ses réponses :

1. reporter chaque décision datée dans la section `Context` de l'unité concernée ;
2. passer en `Ready` uniquement les unités dont plus aucune décision ne manque, dans
   le fichier **et** dans son index — `docs/features/README.md` pour une
   fonctionnalité, `docs/tickets/README.md` pour un ticket d'archive ;
3. rejouer `pnpm maintenance:check` et `pnpm ticket-automation:check` ;
4. committer la vague de cadrage sur une branche dédiée et ouvrir sa PR brouillon.

Un ticket dont une décision manque reste `Draft`. Ne jamais inventer la réponse.

## 4. Exécuter (sauf en mode `plan`)

Lancer le workflow `ticket-run` :

- exécution réelle :
  `Workflow({ scriptPath: ".claude/workflows/ticket-run.js", args: { mode: "execute", runLabel: "<AAAAMMJJ>" } })`
- sélection seule : mêmes arguments **sans** `mode`, ou avec `dryRun: true`
- tickets forcés : `args: { mode: "execute", tickets: ["T0061", "T0062"] }`

`mode: "execute"` est obligatoire pour que quoi que ce soit soit écrit. Le
workflow échoue **fermé** : sans ce mode, ou si ses arguments sont illisibles, il
rend seulement la sélection et ne crée ni worktree, ni branche, ni commit, ni
Pull Request. Ne jamais contourner cette porte en modifiant le script.

Vérifier dans la sortie la ligne `Mode selection seule` ou son absence avant de
conclure que la vague a réellement été exécutée.

Chaque ticket obtient un worktree dédié sous `.worktrees/`, une branche partant du
dernier `origin/main`, une revue adversariale indépendante de son diff poussé, une
remédiation si un constat bloquant est confirmé, puis une **PR brouillon**.

Le `runLabel` sert à nommer la branche d'apprentissage : utiliser la date du jour
au format `AAAAMMJJ`, obtenue avec `Get-Date -Format yyyyMMdd`.

## 5. Rendre compte à Andy

Le rapport final donne, par ticket : statut réel, branche, commit, PR et son état
brouillon, gates avec leur résultat exact, vérification manuelle restante et qui
doit la faire, constats de revue traités ou écartés, découvertes hors périmètre.

Puis, pour la vague : ordre d'intégration imposé par les fichiers de suivi
partagés, tickets différés avec leur raison, entrées d'apprentissage écrites, et
la liste explicite de ce qui attend **une action d'Andy** — d'abord les merges.

Ne jamais conclure qu'une capacité est livrée : elle l'est quand elle est dans
`main`.

## Pièges déjà payés dans ce dépôt

- **Dérive d'index.** Presque toutes les unités touchent leur index —
  `docs/features/README.md`, ou `docs/tickets/README.md` pour l'archive. Une fusion
  qui résout ce conflit en écartant un côté
  fait repasser des lignes en `Review` alors que les fichiers disent `Done`, et
  laisse `pnpm maintenance:check` rouge sur `main`. Le sélecteur signale cette
  contention et impose un ordre d'intégration : le respecter, et après chaque
  merge vérifier l'index plutôt que de le supposer.
- **PR empilée fusionnée dans la mauvaise base.** Plusieurs PR ont été fusionnées
  dans la branche parente au lieu de `main`, ce qui ne livre rien. Toujours
  vérifier la base réelle d'une PR avant de la déclarer livrée.
- **Pile Supabase locale.** C'est un singleton sur `127.0.0.1`. Deux tickets
  backend simultanés ne peuvent pas prouver leurs tests en parallèle : un seul
  ticket backend par vague, sinon déclarer `bloqué par l'environnement`.
- **Identifiant de ticket déjà pris.** Deux sessions allouent un numéro depuis le
  même `origin/main` sans réservation. Vérifier l'identifiant contre un
  `origin/main` fraîchement récupéré juste avant de publier. Si le conflit
  survient quand même, renuméroter est la réponse normale : résoudre le conflit
  d'index en **conservant les deux lignes**, jamais en écartant un côté.
- **`pwsh` absent du `PATH` sandboxé.** Ne pas conclure qu'il est absent de la
  machine : appliquer la procédure de `docs/LEARNINGS.md` (LC-2026-001).
