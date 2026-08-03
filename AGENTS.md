# AGENTS.md — Règles du dépôt ThrustlineNG

Ce fichier s'applique à tout le dépôt. Une instruction locale peut préciser ces
règles, jamais les contredire. En cas de contradiction documentaire, arrêter la
modification concernée, relever les passages incompatibles et faire corriger la
source obsolète dans le périmètre du ticket.

## Mission et priorités

ThrustlineNG est la réécriture distribuable sous Windows d'un gestionnaire de
compagnie aérienne virtuelle pour Microsoft Flight Simulator. Arbitrer dans cet
ordre :

1. stabilité, reprise et absence de perte silencieuse ;
2. sécurité d'un client distribué et modifiable ;
3. intégrité des données, de l'économie et des transitions métier ;
4. compatibilité Windows 11, MSFS 2024 et SimConnect ;
5. maintenabilité, testabilité et mises à jour sûres.

Ne jamais sacrifier une priorité haute pour accélérer une priorité basse.

## Sources de vérité

Lire avant tout travail :

1. `AGENTS.md` ;
2. `docs/CURRENT_STATE.md` pour l'état réellement prouvé ;
3. `docs/ROADMAP.md` pour l'ordre des phases ;
4. le ticket complet dans `docs/tickets/` ;
5. les documents et ADR liés par le ticket.

Références permanentes :

- `docs/PRODUCT.md` — périmètre et règles produit ;
- `docs/ARCHITECTURE.md` — architecture et frontières actives ;
- `docs/SECURITY.md` — menaces, autorités et contrôles ;
- `docs/QUALITY.md` — commandes de validation actives ;
- `docs/WORKFLOW.md` — cycle d'un ticket ;
- `docs/MAINTENANCE.md` — traitement des dettes et cycle des règles de sécurité ;
- `docs/LEARNINGS.md` — apprentissages opérationnels prouvés et candidats ;
- `docs/STACK.md` — versions et politique d'adoption ;
- `docs/SUPPORT.md` — plateformes supportées et preuves requises ;
- `docs/KNOWN_ISSUES.md` — découvertes hors périmètre.

Ordre de préséance en cas d'écart :

1. code, migrations, manifests et lockfiles de la branche inspectée ;
2. ticket actif et ADR acceptées ;
3. `CURRENT_STATE.md` ;
4. documents spécialisés ;
5. roadmap et README.

Une branche ou une Pull Request non fusionnée n'est pas une capacité livrée sur
la branche distante par défaut. Toujours distinguer : présent localement, poussé,
en PR, accepté et fusionné.

## Démarrage et périmètre

Un ticket fonctionnel à la fois par worktree et un ticket par branche ou
worktree. Plusieurs tickets peuvent avancer en parallèle uniquement dans des
worktrees distincts, après vérification de leurs dépendances et de leurs zones
de modification.

Avant toute modification :

1. relever la branche courante, son upstream et la branche distante par défaut ;
2. exécuter `git status --short --branch` ;
3. identifier les modifications préexistantes et ne jamais les attribuer au
   ticket ;
4. lire le statut, les dépendances, `Allowed areas`, `Do not touch`, les critères
   d'acceptation et la vérification manuelle du ticket ;
5. confirmer que la branche correspond à `type/TXXXX-slug` et que le ticket peut
   réellement entrer en `In progress` ;
6. signaler avant d'agir toute incohérence de statut, dépendance ou branche.

Types de branche : `foundation`, `feature`, `fix`, `security`, `refactor`,
`docs` et `chore`.

L'agent peut créer la branche adaptée ou y basculer sans confirmation après ces
contrôles. Une maintenance de gouvernance explicitement demandée peut rester
sans ticket produit si elle est strictement documentaire, bornée et réalisée sur
une branche dédiée ; elle doit être identifiée comme telle dans le rapport.

Ne pas démarrer l'implémentation d'un ticket `Draft`, `Blocked`, `Rejected` ou
`Superseded`. Un ticket `Verify` ne reçoit que les corrections nécessaires à sa
vérification. Si le code existe alors que le suivi dit le contraire, réconcilier
le suivi avant de poursuivre et ne jamais antidater une preuve.

## Orchestration multitâche

Un agent coordinateur reste responsable de chaque ticket, de son périmètre, de
l'état Git, de l'intégration et du rapport final. Il utilise le minimum de
sous-agents nécessaire et délègue uniquement des sous-tâches bornées qui peuvent
progresser indépendamment.

### Mode accéléré vers la première alpha

Jusqu'à validation de l'alpha jouable interne définie dans `docs/ROADMAP.md`, le
mode d'exécution par défaut maximise le travail indépendant sans réduire les
preuves. Le coordinateur applique les règles suivantes :

- maintenir au plus trois tickets produit `In progress` simultanément, chacun
  dans un worktree distinct, sur les flux moteur de vol/bridge, backend du golden
  path et composition desktop/E2E ;
- ne lancer un flux que si son ticket est `Ready`, ses décisions sont prises, ses
  chemins sont attribués et il peut produire une preuve utile sans présumer une
  branche non fusionnée ;
- traiter en priorité une PR fusionnable, une correction de CI ou la propagation
  d'une capacité déjà validée vers `main` avant d'ouvrir un nouveau travail
  dépendant ;
- créer par défaut chaque branche depuis le dernier `origin/main` et cibler
  `main`. Une branche empilée reste exceptionnelle, explicitement dépendante et
  sa PR reste brouillon ; elle ne prouve jamais une livraison dans `main` ;
- après fusion du parent d'une pile, recibler immédiatement la PR vers `main` si
  son ascendance le permet, sinon ouvrir une branche de propagation propre sans
  force-push et fermer la chaîne obsolète ;
- regrouper avant implémentation les décisions produit ou économiques nécessaires
  aux prochains tickets et laisser `Draft` tout ticket encore ambigu ;
- reporter explicitement hors alpha les capacités non requises par son gate. Un
  report ne modifie pas le MVP, les frontières d'autorité ou les exigences de
  distribution publique ;
- paralléliser les validations indépendantes, mais ne jamais supprimer un test,
  une revue adversariale, une vérification manuelle requise ou une gate pour
  tenir une date.

La limite de trois flux est un plafond, pas un objectif d'occupation. Un flux
bloqué ne justifie pas un quatrième ticket si cela augmente les collisions ou la
file d'intégration.

- Les recherches, lectures, diagnostics et revues peuvent être parallélisés en
  lecture seule.
- Dans un worktree partagé, les sous-agents restent en lecture seule par défaut.
  Une écriture parallèle exige une attribution préalable de chemins disjoints ;
  un seul agent possède un chemin à un instant donné.
- Deux travaux qui modifient le même fichier, un contrat et son consommateur, une
  migration et ses types générés, ou des étapes dépendantes restent séquentiels.
- Un sous-agent ne change jamais de branche, ne crée pas de commit, ne pousse pas
  et ne gère pas de Pull Request dans un worktree partagé. Ces opérations
  appartiennent au coordinateur.
- Chaque sous-agent rend ses constats, fichiers touchés, commandes, résultats et
  limites. Le coordinateur inspecte le diff combiné et rejoue les validations
  après intégration ; des validations isolées ne prouvent pas le résultat final.
- Pour plusieurs tickets en parallèle, chaque ticket possède son worktree, sa
  branche, son statut et sa future Pull Request. Une branche non fusionnée reste
  une dépendance explicite et ne doit jamais être présumée présente dans `main`.
- Toute collision de périmètre, modification inattendue ou dépendance découverte
  suspend l'écriture concernée jusqu'à réattribution ou séquencement par le
  coordinateur.

La délégation ne change ni `Allowed areas`, ni `Do not touch`, ni l'autorité
d'Andy. Elle ne permet pas de fusionner une Pull Request, de résoudre une
ambiguïté produit ou de créer une exception de sécurité.

## Suivi du ticket

Le champ `Status` du fichier du ticket est la référence pour son workflow.
`docs/tickets/README.md` est un index qui doit refléter les mêmes statuts.

Transitions :

- `Draft` : résultat ou preuves encore incomplets ;
- `Ready` : dépendances satisfaites et ticket exécutable ;
- `In progress` : travail actif sur une branche identifiée ;
- `Review` : implémentation terminée, diff et validations automatisées prêts à
  être revus ;
- `Verify` : validation humaine ou environnementale encore requise ;
- `Done` : critères satisfaits, preuves consignées, vérification terminée et
  documentation cohérente ;
- `Blocked`, `Rejected`, `Superseded` : motif et condition de sortie obligatoires.

À chaque transition :

1. mettre à jour le ticket et l'index dans le même changement ;
2. consigner une preuve datée, sans transformer une intention en résultat ;
3. préciser la branche et la PR lorsque l'état dépend de GitHub ;
4. mettre à jour `CURRENT_STATE.md` seulement si la réalité décrite change ;
5. conserver en `Verify` tout contrôle manuel délégué ou impossible localement.

Une PR ouverte, des checks verts ou du code compilable ne suffisent pas seuls à
mettre un ticket `Done`. Ne jamais présenter une branche empilée comme fusionnée
dans `main`. Pour une PR empilée, relever explicitement sa branche de base, sa
dépendance et la condition de rebase ou de changement de base.

## Règles de travail

- Implémenter uniquement les exigences du ticket.
- Respecter strictement `Allowed areas` et `Do not touch`.
- Ne pas anticiper les tickets futurs ni refactorer un système sans rapport.
- Préserver toute modification utilisateur non liée.
- Ne pas importer implicitement du code, des manifests, des lockfiles ou des
  secrets d'un ancien dépôt.
- Ne pas changer l'architecture ou les frontières de confiance sans ADR acceptée.
- Éviter une nouvelle dépendance quand les outils déjà épinglés suffisent.
- Arrêter et demander une décision si une ambiguïté modifie le produit, la
  sécurité, les données, le support ou l'architecture.
- Consigner une découverte hors périmètre dans `docs/KNOWN_ISSUES.md` avec preuve,
  sévérité et cible ; ne pas la corriger opportunément.

## Apprentissage contrôlé

L'agent peut capturer de façon autonome une difficulté ou une méthode utile dans
le Completion Report, puis appliquer le cycle de `docs/LEARNINGS.md`. Une
observation isolée ne devient pas une règle globale.

- Distinguer systématiquement observation, hypothèse, cause confirmée et règle.
- Conserver les commandes, l'environnement utile, le résultat et les limites,
  sans secret ni donnée personnelle.
- Promouvoir une règle après deux occurrences indépendantes ou une reproduction
  déterministe. Une seule occurrence suffit uniquement pour un risque élevé de
  sécurité, perte de données ou faux succès, avec revue explicite.
- Encoder l'apprentissage au niveau le plus vérifiable : test ou script avant
  procédure spécialisée, procédure avant règle globale.
- Respecter `Allowed areas`. Hors périmètre, consigner le candidat dans le
  Completion Report ou `KNOWN_ISSUES.md` au lieu de modifier opportunément les
  règles, scripts ou tests.
- Ne jamais modifier le produit, l'architecture, la sécurité, les données, le
  support ou un budget sur la seule base d'un apprentissage opérationnel.
- Revalider les règles dépendantes d'un outil ou de l'environnement et retirer
  ou remplacer explicitement celles devenues obsolètes.

## Entretien technique et sécurité

À l'ouverture d'un ticket, relire les problèmes connus et les invariants de
sécurité qui touchent ses zones autorisées. À sa clôture, inspecter le diff pour
identifier toute dette créée ou aggravée, tout invariant contourné ou devenu
inexact et tout contrôle répétable encore manuel.

Appliquer le workflow de `docs/MAINTENANCE.md` : qualifier avec preuve,
prioriser par risque, consigner hors périmètre, puis traiter uniquement dans un
ticket borné. Une découverte `Critical` arrête le travail concerné ; une
découverte `High` doit être ticketisée avant de poursuivre un changement qui
dépend de la zone affectée. Ne jamais corriger opportunément une dette ni créer,
renouveler ou élargir seul une exception de sécurité.

Lorsqu'une règle de sécurité est ajoutée ou modifiée, synchroniser sa source
canonique dans `docs/SECURITY.md` et son contrôle automatisé dans le même ticket
si le périmètre l'autorise. Sinon, conserver le constat et créer un follow-up.
Toute exception exige l'approbation explicite d'Andy, une portée, une échéance ou
condition d'expiration et un risque résiduel consignés.

## Frontières techniques

- `apps/desktop/` : Tauri v2, React, TypeScript, Vite et orchestration cliente ;
- `apps/bridge/` : bridge .NET, intégration locale et future frontière
  SimConnect ;
- `tests/` : harnais et preuves automatisées ;
- `eng/` et fichiers racine de toolchain : versions canoniques et workspace ;
- `scripts/` : bootstrap, contrôles et mesures reproductibles ;
- `docs/` : décisions, état, suivi et preuves ;
- futur backend Supabase : autorité métier et données persistantes.

La page WebView, le processus desktop, le bridge et MSFS sont des clients non
fiables. Le serveur reste autoritaire pour l'argent, la propriété, la réputation,
la progression et les transitions sensibles. Aucun secret backend ne doit être
livré au client.

## Qualité et sécurité d'implémentation

- Utiliser les versions exactes et lockfiles du dépôt.
- TypeScript strict, C# nullable et Rust sans avertissement introduit.
- Garder les pages React minces ; sortir règles métier et accès aux données.
- Valider toute entrée à une frontière IPC, REST, SignalR ou serveur.
- Rendre les commandes sensibles transactionnelles et idempotentes côté serveur.
- Garder les migrations Supabase append-only.
- Versionner les contrats partagés et mettre à jour producteurs et consommateurs
  ensemble.
- Présenter des erreurs actionnables à l'utilisateur et réserver les détails à
  des logs redigés.
- Ne jamais versionner ni journaliser secret, JWT, donnée personnelle, fichier
  `.env`, header d'authentification ou jeton d'instance.
- Ne jamais télécharger puis exécuter un script distant.

## Versionnement de l'application

Les versions publiées de Thrustline suivent Semantic Versioning 2.0.0 sous la
forme `MAJOR.MINOR.PATCH`. Avant la première version stable, utiliser une version
`0.x.y` et les préversions ordonnées `-alpha.N`, `-beta.N`, puis `-rc.N`, par
exemple `0.1.0-alpha.1`, `0.1.0-beta.1` et `0.1.0-rc.1`. La version `1.0.0` est
réservée à la première version publique stable dont les gates ont été acceptées
par Andy.

- Incrémenter `PATCH` pour une correction compatible, `MINOR` pour une capacité
  compatible et `MAJOR` pour une rupture de compatibilité après `1.0.0`. Sous
  `0.x.y`, tout changement incompatible doit au minimum incrémenter `MINOR` et
  être signalé dans les notes de version.
- Utiliser un tag Git `vMAJOR.MINOR.PATCH[-PRERELEASE]` et reprendre exactement
  cette version dans le nom des artefacts, par exemple
  `Thrustline-0.1.0-alpha.1-win-x64.exe`.
- Garder le commit et la date comme traçabilité de build, jamais comme version
  publique concaténée. Une build interne peut utiliser la métadonnée SemVer
  `+YYYYMMDD.gSHORTSHA` et l'interface peut afficher le hash court entre
  parenthèses ; cette métadonnée ne change pas l'ordre des versions.
- Ne jamais publier une version opaque telle que `1.0aeb458345`, réutiliser un
  numéro de version ou déplacer un tag publié.
- Maintenir une source canonique unique de version produit. Le ticket qui
  prépare la première alpha doit synchroniser et contrôler les versions du
  frontend, de Tauri/Rust, du bridge .NET, de l'installateur, des artefacts et de
  l'affichage applicatif. Les versions de schémas, contrats et outils restent
  indépendantes de la version produit.
- Une préversion, un tag ou un artefact ne prouve pas à lui seul qu'une release
  est publiable : appliquer les gates, preuves et autorités de la roadmap et du
  ticket de release.

## Validation proportionnée

Le ticket définit les preuves attendues ; `docs/QUALITY.md` donne les commandes
actives. Lire les scripts et manifests avant de reprendre une commande ancienne.
Exécuter d'abord les tests ciblés, puis les gates applicables depuis la racine.

Exemples actuels, à sélectionner selon le périmètre :

```powershell
pnpm frontend:typecheck
pnpm frontend:test
pnpm frontend:coverage
pnpm frontend:build
pnpm desktop:check
pnpm desktop:test
pnpm desktop:build
pnpm frontend:measure
pnpm maintenance:check
```

Si la branche expose des scripts `bridge:*`, utiliser ceux du `package.json` de
la branche plutôt qu'une commande mémorisée. Les changements de toolchain
exigent les contrôles de `tests/toolchain/`. Les changements SQL exigent un test
local ou staging d'isolation A/B/anonyme. Les changements SimConnect exigent un
replay de trace ou une vérification MSFS documentée selon le ticket.

Le `PATH` d'un shell sandboxé Codex ne prouve jamais qu'un outil est absent de
la machine. Avant de déclarer PowerShell 7 indisponible sous Windows, vérifier
`Get-Command pwsh.exe`, puis le chemin utilisateur
`%LOCALAPPDATA%\Microsoft\WindowsApps\pwsh.exe` résolu sans nom d'utilisateur
codé en dur. Si l'exécutable existe, relever sa version et exécuter le contrôle
avec son chemin explicite ; consigner séparément « installé mais absent du
`PATH` sandboxé » et « réellement non installé ». Appliquer la même distinction
aux autres outils dont le lanceur peut dépendre du contexte utilisateur.

Pour un ticket purement documentaire, vérifier au minimum :

- cohérence des statuts, références, chemins et commandes ;
- portée du diff ;
- absence de modification applicative involontaire ;
- `git diff --check`.

Pour chaque commande, consigner : commande exacte, environnement utile, résultat
et éventuelle limite. `Non exécuté`, `bloqué par l'environnement` et `échoué`
sont des résultats distincts. Ne jamais annoncer comme réussi un contrôle non
exécuté et ne jamais déduire qu'un test a tourné du seul code de sortie d'un outil
qui n'a découvert aucun test.

## Revue et fin de ticket

Effectuer une revue adversariale après l'implémentation, dans cet ordre :

1. sécurité, autorité et perte de données ;
2. critères d'acceptation et changements hors périmètre ;
3. régressions, contrats et compatibilité ;
4. architecture et dette créée ;
5. tests, observabilité, lisibilité et performance.

Un ticket n'est `Done` que si :

- tous ses critères d'acceptation sont satisfaits ;
- les validations automatisées pertinentes passent ;
- la vérification manuelle est terminée, pas seulement déléguée ;
- risques, limites et contrôles non exécutés sont consignés ;
- `CURRENT_STATE.md`, l'index des tickets et les documents spécialisés sont
  cohérents avec le résultat ;
- le Completion Report contient des preuves vérifiables ;
- aucun changement hors périmètre n'est inclus.

Le rapport final donne : statut, résumé, fichiers modifiés, commandes et
résultats, vérification manuelle, risques, follow-ups, documentation mise à jour,
branche, commit et Pull Request.

## Git, worktrees et GitHub

L'agent gère sans confirmation intermédiaire la création ou la bascule de
branche, l'indexation ciblée, le commit, le push et la création ou mise à jour de
la Pull Request. Il ne fusionne jamais une Pull Request : la revue et le merge
final appartiennent exclusivement à Andy.

Avant toute publication :

1. relever branche courante, upstream, remote et branche distante par défaut ;
2. comparer au bon parent, particulièrement pour une branche empilée ;
3. séparer les fichiers du ticket des changements préexistants ;
4. indexer uniquement les chemins du ticket avec une liste explicite ;
5. inspecter `git diff --cached --stat` et `git diff --cached` ;
6. exécuter `git diff --cached --check` ;
7. utiliser un message Conventional Commits adapté ;
8. exécuter les validations proportionnées et mettre à jour le Completion Report ;
9. pousser la branche exacte puis créer ou mettre à jour la PR avec les vraies
   branches base/head.

Règles absolues :

- ne jamais utiliser `git add .` ou `git add -A` ;
- ne jamais inclure, écraser, nettoyer ou publier un changement utilisateur hors
  ticket ;
- ne jamais inventer une branche, une cible de PR, un résultat de CI ou un lien ;
- utiliser Git pour Windows et PowerShell, pas Git WSL sur `/mnt/c` ;
- ne jamais demander un mot de passe GitHub ; utiliser `gh auth login` si
  l'authentification manque ;
- ne jamais force-push, contourner une protection ou modifier directement une
  branche protégée ;
- garder la PR en brouillon tant que le ticket, les validations ou ses dépendances
  ne sont pas prêts ;
- ne déclarer la PR prête que lorsque le diff publié est révisable et que les
  blocages restants sont explicitement humains.

À la fin, fournir le lien de la PR et l'état exact : brouillon ou prête, base,
head, checks connus, dépendances empilées, vérification manuelle et action
attendue d'Andy.
