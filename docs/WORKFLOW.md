# Workflow de refonte

## Rôles

- **Andy — Product Owner** : tranche la vision, le périmètre et les compromis.
- **Agent planificateur** : analyse le dépôt, propose ADR, roadmap et tickets.
- **Codex implémenteur** : exécute un ticket borné et fournit les preuves.
- **Reviewer** : cherche régressions, failles, dérive architecturale et tests
  manquants avant validation.

Un même outil peut tenir plusieurs rôles, mais pas dans la même étape sans
effectuer une revue adversariale explicite.

Lorsqu'un ticket utilise plusieurs agents, l'un d'eux est désigné coordinateur.
Il reste responsable du ticket et distribue des sous-tâches bornées aux autres
agents ; la responsabilité du périmètre, de l'intégration et des preuves n'est
jamais déléguée implicitement.

## États d'un ticket

`Draft → Ready → In progress → Review → Verify → Done`

États alternatifs : `Blocked`, `Rejected`, `Superseded`.

## 1. Préparer la phase

1. Définir le résultat utilisateur.
2. Écrire/valider les ADR structurantes.
3. Identifier dépendances et risques.
4. Découper en vertical slices.
5. Créer seulement les 3–8 prochains tickets détaillés ; garder le reste au
   niveau roadmap pour éviter un plan périmé de 50 tickets.

### 1.1 Piloter le flux accéléré vers l'alpha

Pendant le mode accéléré défini dans `AGENTS.md`, la préparation maintient une
vue courte des trois flux indépendants suivants :

1. moteur de vol, SimConnect, reprise et rapport dans le bridge ;
2. dispatch, clôture et grand livre autoritaires côté backend ;
3. composition desktop et preuve E2E du golden path.

Chaque flux possède au plus un ticket `In progress`, un worktree, une branche et
un coordinateur. Les flux ne sont pas des branches permanentes : dès qu'un
ticket est intégré, son successeur repart du nouveau `origin/main`.

Avant de lancer la vague suivante :

1. cartographier les contrats et chemins partagés entre les 3–8 tickets détaillés ;
2. demander à Andy en un seul lot les décisions qui changent le produit,
   l'économie, la sécurité, les données, le support ou l'architecture ;
3. attribuer les chemins disjoints et l'ordre d'intégration ;
4. identifier la vérification Windows/MSFS requise et réserver son environnement ;
5. vérifier qu'aucune PR déjà validée n'attend seulement sa propagation vers
   `main`.

L'ordre quotidien de priorité est : PR prête à intégrer, CI ou propagation
bloquante, dépendance du golden path, puis nouveau ticket. La quantité de code
produite ou le nombre de branches ouvertes ne mesure pas l'avancement ; seule
une capacité prouvée et présente dans `main` réduit le reste à faire.

Les PR empilées servent uniquement à ne pas immobiliser un travail réellement
indépendant. Elles restent brouillon, déclarent leur base et leur condition de
sortie, et ne passent pas `Ready for review` tant qu'elles ne ciblent pas la
branche destinée à recevoir effectivement la capacité. Le coordinateur ne crée
pas une troisième couche si la première peut d'abord être propagée vers `main`.

## 2. Rendre un ticket Ready

Un ticket Ready contient :

- objectif unique ;
- dépendances satisfaites ;
- zones autorisées et interdites ;
- exigences et non-objectifs ;
- critères d'acceptation observables ;
- tests attendus ;
- vérification manuelle de 5–10 minutes ;
- revue sécurité si nécessaire.

Le reviewer challenge le ticket avant tout code : trop large, ambigu, mauvaise
frontière ou absence de preuve = retour en Draft.

## 3. Implémenter

1. Lire `AGENTS.md`, `CURRENT_STATE.md`, le ticket et les docs liées.
2. Vérifier l'état Git et préserver les changements existants.
3. Déterminer la branche `type/TXXXX-slug`, puis la créer ou y basculer après
   avoir préservé et signalé les changements préexistants. Si elle est déjà
   active, ne pas la recréer.
4. Inspecter le code réel.
5. Implémenter seulement le ticket.
6. Exécuter d'abord les tests ciblés, puis les gates applicables.
7. Ne pas corriger les découvertes hors scope ; les consigner.

### 3.1 Décider si le parallélisme est pertinent

Le coordinateur utilise plusieurs agents seulement si au moins deux sous-tâches
peuvent produire un résultat utile indépendamment. Le temps de coordination, le
risque de collision et la revalidation du résultat combiné doivent rester
proportionnés au ticket.

Usages adaptés :

- inspection indépendante de zones différentes ;
- recherche documentaire ou de précédents en lecture seule ;
- exécution de validations indépendantes qui ne partagent pas d'état mutable ;
- revue adversariale sécurité, conformité ou régression après implémentation ;
- modifications sur des chemins explicitement disjoints lorsque leur contrat est
  déjà stable.

Usages à garder séquentiels :

- sous-tâches dont l'une dépend du résultat encore inconnu de l'autre ;
- modifications concurrentes du même fichier ou du même état persistant ;
- changement d'un contrat avec ses producteurs ou consommateurs ;
- migration, génération de types et adaptation des appelants ;
- opérations Git ou publication depuis un worktree partagé.

### 3.2 Préparer une délégation

Avant de lancer un sous-agent, le coordinateur consigne dans sa demande :

1. le résultat attendu et la question précise à résoudre ;
2. les sources à lire et le contexte suffisant ;
3. les chemins autorisés et interdits ;
4. le mode `lecture seule` ou la liste exhaustive des chemins dont l'écriture est
   attribuée ;
5. les validations attendues et la forme du compte rendu ;
6. les conditions d'arrêt : contradiction, dépendance, secret, modification
   inattendue ou décision réservée à Andy.

Dans un worktree partagé, la lecture seule est la valeur par défaut. Si une
écriture est attribuée, le coordinateur vérifie d'abord les modifications
préexistantes et interdit tout chevauchement de propriété. Un sous-agent ne
bascule jamais la branche du worktree partagé.

### 3.3 Intégrer les résultats

Le coordinateur attend les sous-tâches nécessaires, puis :

1. distingue constats, hypothèses et modifications réellement présentes ;
2. inspecte chaque chemin modifié et refuse tout changement hors attribution ;
3. résout les interactions en série, sans demander deux corrections concurrentes
   sur la même zone ;
4. exécute la revue adversariale sur le diff combiné ;
5. rejoue les tests ciblés affectés puis les gates applicables ;
6. remplit le Completion Report avec les résultats intégrés et leurs limites.

Une commande réussie dans une sous-tâche ne prouve pas que le résultat intégré
passe. Seules les validations rejouées ou explicitement confirmées après la
dernière modification peuvent servir de preuve finale.

### 3.4 Exécuter plusieurs tickets en parallèle

Des tickets indépendants peuvent être `In progress` simultanément si chacun
dispose d'un worktree et d'une branche dédiés. Avant de les lancer, vérifier :

- que chaque ticket est `Ready` et que ses dépendances sont réellement
  satisfaites sur son parent ;
- que leurs `Allowed areas` ne se chevauchent pas, ou désigner un ordre
  d'intégration explicite ;
- que chaque branche part de la base réelle attendue ;
- qu'une éventuelle pile de branches est déclarée dans les tickets et les PR.

Chaque ticket conserve son propre coordinateur, ses validations et son handoff.
Une preuve issue d'un worktree ne clôt jamais implicitement un autre ticket.

En mode accéléré vers l'alpha, appliquer en plus la limite de trois tickets
produit simultanés et les trois flux définis en section 1.1. Toute dépendance de
contrat découverte entre deux flux les rend séquentiels jusqu'à stabilisation et
fusion du contrat dans `main`.

Types de branche : `foundation`, `feature`, `fix`, `security`, `refactor`,
`docs`, `chore`.

## 4. Revoir

La revue vérifie dans cet ordre :

1. sécurité et perte de données ;
2. conformité aux critères ;
3. régressions et compatibilité ;
4. architecture et dette créée ;
5. tests et observabilité ;
6. lisibilité et performance.

Une revue ne doit pas demander une réécriture esthétique sans bénéfice mesurable.

## 5. Vérifier

Effectuer la checklist manuelle du ticket. Si elle échoue, le ticket revient en
`In progress`. Si elle est impossible localement, indiquer précisément qui doit
la faire et sur quel environnement ; le ticket reste `Verify`.

## 6. Clore

1. Remplir le Completion Report dans le ticket.
2. Actualiser `CURRENT_STATE.md` si l'état réel a changé.
3. Ajouter les problèmes différés dans `KNOWN_ISSUES.md`.
4. Traiter les candidats d'apprentissage selon `LEARNINGS.md`, sans dépasser les
   zones autorisées du ticket.
5. Mettre à jour une ADR seulement par une nouvelle ADR qui la remplace.
6. Préparer le handoff Git avec les fichiers exacts du ticket.
7. Vérifier le diff indexé, committer, pousser et ouvrir ou mettre à jour la PR.
8. Faire relire la PR à Andy ; lui seul peut décider et effectuer le merge.
9. Choisir le prochain ticket Ready.

## Boucle automatisée des tickets

La skill `/ticket-loop` exécute ce workflow au lieu de le remplacer. Elle est
déclenchée explicitement, jamais planifiée, et se décompose en trois pièces aux
responsabilités séparées.

**Le sélecteur est la seule autorité sur ce qui est exécutable.** Aucun agent ne
décide de la sélection :

```powershell
pnpm ticket-batch:select
```

`scripts/select-ticket-batch.ps1` lit les fichiers de tickets et l'index, puis
rend la capacité de flux restante, les tickets sélectionnés, les tickets différés
avec leur raison, l'ordre d'intégration et la contention des fichiers de suivi
partagés. Il sort en échec sur une incohérence de suivi : statut divergent entre
un fichier et l'index, statut invalide, champ `Status` absent ou dupliqué, ticket
absent de l'index, dépendance introuvable. Une sortie non nulle interdit toute
planification comme toute exécution.

Il traite `docs/tickets/README.md`, `docs/CURRENT_STATE.md`,
`docs/KNOWN_ISSUES.md`, `docs/LEARNINGS.md` et `docs/ROADMAP.md` comme des
fichiers de suivi partagés : leur présence dans plusieurs `Allowed areas` n'est
pas une collision, mais elle impose un ordre d'intégration explicite. C'est la
dérive d'index observée lors des fusions T0043 à T0050.

**Deux workflows séparés par une porte humaine.** Un workflow s'exécute en
arrière-plan et ne peut pas poser de question ; les décisions réservées à Andy
sont donc rendues en un seul lot entre les deux :

1. `ticket-plan` établit l'état réellement présent dans `origin/main`, cadre au
   plus un ticket par flux, écrit un fichier de ticket par proposition puis
   consolide l'index et rejoue les gates. Il ne commite pas.
2. Andy répond au lot de décisions. Chaque réponse est reportée datée dans le
   ticket concerné, qui passe `Ready` seulement si plus aucune décision ne manque.
3. `ticket-run` sélectionne, implémente chaque ticket dans un worktree dédié sous
   `.worktrees/`, fait relire le diff poussé par un agent qui ne l'a pas écrit,
   remédie aux constats bloquants confirmés, puis ferme la boucle d'apprentissage
   sur une branche dédiée.

**La boucle tourne aussi sans déclenchement humain.** Une tâche planifiée locale
l'exécute une fois par jour ouvré, tôt le matin. Elle vit hors du dépôt, dans
`~/.claude/scheduled-tasks/thrustlineng-ticket-loop/`, et ne s'exécute que quand
l'application est ouverte ; si elle était fermée à l'heure prévue, le run part au
lancement suivant. Elle a besoin de PowerShell Windows, pnpm, les worktrees et
parfois Docker : elle tourne donc sur la machine d'Andy, jamais dans un runner
distant.

Un run non surveillé applique l'ordre de priorité ci-dessus, puis :

1. il n'exécute que des tickets **sans humain requis**. Cette frontière est
   déterministe et calculée par le sélecteur, pas par un agent : un ticket
   `Security-sensitive: Yes`, `Risk: High`, portant `Autonomous: No`, ou dont une
   dépendance nomme une décision d'Andy, MSFS, du matériel ou une vérification
   humaine, est reporté avec sa raison ;
2. s'il n'a rien à exécuter et qu'aucune Pull Request de la boucle n'attend déjà
   Andy, il prépare la vague suivante dans un worktree dédié et ouvre sa PR
   brouillon. La condition sur les PR en attente évite d'empiler des
   planifications quasi identiques jour après jour ;
3. il ne touche jamais à la branche courante du worktree principal, où un travail
   humain peut être en cours ;
4. il ne notifie Andy que si une action lui revient : PR prête à fusionner,
   décision réservée, CI rouge, incohérence de suivi, découverte `Critical` ou
   `High`. Un run silencieux est un run réussi.

**Le mode écriture est explicite.** `ticket-run` ne crée un worktree, une branche,
un commit ou une Pull Request que si son argument `mode` vaut exactement
`execute`. Sans cet argument, ou si ses arguments sont illisibles, il rend
seulement la sélection : il échoue fermé. Cette porte existe parce qu'une
transmission d'arguments défaillante a fait démarrer une implémentation réelle
pendant la mise au point de T0061.

**Limites que la boucle ne franchit pas.** Elle ne fusionne aucune Pull Request,
ne force-push pas, n'utilise jamais `git add .` ni `git add -A`, ne touche pas au
worktree principal et ne change pas sa branche. Elle ne tranche aucune ambiguïté
produit, économique, de sécurité, de données, de support ou d'architecture, et ne
modifie ni `AGENTS.md` ni une ADR acceptée : un apprentissage qui viserait
`AGENTS.md` est proposé dans le corps de la Pull Request. Le plafond de trois
tickets `In progress` reste appliqué par le sélecteur.

Toute Pull Request produite par la boucle reste **brouillon**. Une capacité n'est
livrée que lorsque Andy l'a fusionnée dans `main`.

## Boucle d'apprentissage

L'apprentissage du dépôt porte sur des faits observables, jamais sur une mémoire
implicite de l'agent. Une difficulté rencontrée pendant un ticket suit cette
boucle :

1. **Capturer** : décrire le symptôme, le contexte, la conclusion erronée à
   éviter et les diagnostics non destructifs exécutés.
2. **Qualifier** : séparer `Observed`, `Reproduced`, `Codified`, `Enforced` et
   `Stale` selon les définitions de `LEARNINGS.md`.
3. **Reproduire** : chercher un second contexte indépendant ou une reproduction
   déterministe, avec au moins un contre-exemple lorsque cela apporte une preuve.
4. **Classer** : choisir la destination la plus étroite : Completion Report,
   `KNOWN_ISSUES.md`, document spécialisé, script/test, puis seulement
   `AGENTS.md` pour un invariant global.
5. **Promouvoir** : relire la preuve, la portée, les risques et la date de
   revalidation. Une promotion ne permet jamais de contourner `Allowed areas`.
6. **Automatiser** : lorsqu'un contrôle déterministe est possible, créer un
   ticket borné pour le script ou le test au lieu de conserver durablement une
   consigne manuelle.
7. **Revalider** : lors de la date prévue ou d'un changement de version,
   confirmer, remplacer ou marquer `Stale` sans effacer l'historique.

La capture d'une première occurrence est immédiate. La promotion exige deux
occurrences indépendantes ou une reproduction déterministe. Une exception est
admise pour un risque élevé de sécurité, de perte de données ou de faux succès :
une occurrence reproductible peut alors être promue après revue explicite.

Un candidat n'est pas un problème connu par défaut. Il rejoint
`KNOWN_ISSUES.md` seulement s'il décrit un défaut réel hors périmètre nécessitant
un suivi produit ou technique.

## Boucle d'entretien technique et sécurité

Le workflow détaillé est défini dans `MAINTENANCE.md`. Il s'exécute à deux
moments de chaque ticket :

1. au démarrage, pour relever les dettes et règles de sécurité applicables aux
   zones autorisées et détecter un éventuel blocage `Critical` ou `High` ;
2. après l'implémentation, pour qualifier la dette créée ou aggravée, les
   invariants contournés ou périmés et les contrôles manuels automatisables.

Les découvertes hors périmètre sont prouvées et enregistrées, jamais corrigées
au passage. Leur remédiation utilise un ticket séparé dont l'acceptation inclut
un test négatif pertinent et un risque résiduel explicite. Une règle de sécurité
acceptée appartient à `SECURITY.md`; un défaut réel appartient à
`KNOWN_ISSUES.md`; une méthode d'outil appartient à `LEARNINGS.md`.

## Handoff Git de fin de ticket

Codex termine chaque ticket avec des commandes adaptées à l'état réel du dépôt.
Après revue du diff indexé, il exécute de manière autonome le commit, le push et
la création ou mise à jour de la Pull Request. Il annonce la branche, le remote,
la base réelle de la PR et le message de commit exacts. Il ne doit jamais
proposer ni exécuter une commande globale qui embarquerait des changements sans
rapport.

Exemple de structure à adapter :

```powershell
# À exécuter dans PowerShell Windows
Set-Location C:\Users\andyd\Documents\Thrustline

# 1. Vérifier la branche et les changements
git branch --show-current
git status --short

# 2. Ajouter uniquement les fichiers du ticket
git add -- path/to/file-a path/to/file-b

# 3. Relire exactement ce qui sera committé
git diff --cached --check
git diff --cached --stat
git diff --cached

# 4. Créer le commit
git commit -m "type(scope): description du ticket"

# 5. Publier la branche
git push -u origin nom-reel-de-la-branche

# 6. Ouvrir la PR si GitHub CLI est configuré
gh pr create --base branche-cible --head nom-reel-de-la-branche `
  --title "TXXXX — Titre" `
  --body-file docs/tickets/TXXXX-ticket.md
```

Avant de fournir ce bloc, Codex doit remplacer tous les exemples par les valeurs
réelles. S'il existe des fichiers modifiés hors ticket, il doit les lister
séparément et confirmer qu'ils ne figurent pas dans `git add`.

Codex inclut les résultats du commit, du push et de la Pull Request dans le
rapport final. Seule la fusion exige une confirmation explicite d'Andy et ne doit
jamais être exécutée par l'agent.

Avec plusieurs agents, seul le coordinateur du ticket effectue ce handoff dans
le worktree concerné. Il indexe les chemins après intégration, jamais pendant
qu'un sous-agent écrit encore, et vérifie qu'aucun résultat d'un autre ticket ou
worktree n'est inclus.

Si GitHub demande un mot de passe HTTPS, ne pas utiliser le mot de passe du
compte. Configurer GitHub CLI depuis PowerShell :

```powershell
gh auth login
gh auth setup-git
```

Pour éviter les erreurs `chmod ... .git/config.lock`, ne pas utiliser Git WSL
sur ce dépôt stocké sous `C:\Users\...`.

## Limites de taille

Un bon ticket :

- vise un résultat ;
- modifie idéalement une frontière principale ;
- produit un diff révisable ;
- se vérifie manuellement en 5–10 minutes ;
- peut être abandonné sans invalider plusieurs jours de travail.

Si le ticket combine migration, nouveau protocole, gros écran et pipeline release,
le diviser.

## Commande de démarrage recommandée

```text
Implémente uniquement le ticket TXXXX.

Lis AGENTS.md, docs/CURRENT_STATE.md et le ticket complet.
Respecte Allowed areas et Do not touch.
Avant de coder, signale toute contradiction bloquante.
Après le changement, exécute les validations du ticket et remplis son
Completion Report avec preuves, risques et follow-ups.
```

## Rétrospective

À la fin de chaque phase :

- quelles règles ont évité une erreur ?
- quels tickets étaient trop grands ou ambigus ?
- quels contrôles manquaient ?
- quels documents ont dérivé ?
- quelle automatisation répétée mérite un script ou une skill ?
- quelles dettes `Open`, exceptions de sécurité et règles à revalider doivent
  entrer dans les 3–8 prochains tickets ?

Enregistrer une première observation sans attendre sa répétition. Modifier le
workflow uniquement après avoir satisfait les seuils de promotion de
`LEARNINGS.md`.
