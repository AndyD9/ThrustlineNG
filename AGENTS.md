# AGENTS.md — Brief du dépôt ThrustlineNG

Ce fichier est volontairement court : il porte les invariants et le pilotage
courant. Le détail vit dans les documents cités, à lire seulement quand la tâche
les concerne. En cas de contradiction documentaire, s'arrêter, relever les
passages incompatibles et faire corriger la source obsolète.

ThrustlineNG est la réécriture distribuable sous Windows d'un gestionnaire de
compagnie aérienne virtuelle pour Microsoft Flight Simulator. Priorités, dans
l'ordre : stabilité et absence de perte silencieuse ; sécurité d'un client
distribué et modifiable ; intégrité des données, de l'économie et des
transitions métier ; compatibilité Windows 11, MSFS 2024 et SimConnect ;
maintenabilité. Ne jamais sacrifier une priorité haute pour accélérer une
priorité basse.

## Pilotage courant — décision d'Andy du 6 août 2026

- **Jalon : l'alpha cliquable.** Un parcours complet dans la vraie application
  installée, sur la pile Supabase locale : login → compagnie → achat → dispatch
  → vol en replay → clôture visible au grand livre. Tout travail doit
  visiblement s'en rapprocher ; ce qui ne s'en rapproche pas attend.
- **Mode de travail : la session interactive avec Andy est le défaut.** La
  boucle planifiée est en pause ; `/ticket-loop` reste utilisable sur demande
  explicite d'Andy uniquement.
- **Rigueur à deux vitesses.** Preuve maximale (migrations append-only, pgTAP,
  gates à mutations négatives, checklist manuelle) pour tout ce qui touche
  l'argent, les données, l'autorité serveur ou la sécurité. Pour l'UI et la
  composition cliente : typecheck, tests, build — et la vérification manuelle
  est le parcours réel dans l'application, pas une checklist dédiée.
- **Pas de travail sur le processus lui-même** (workflow, boucle, gates de
  gouvernance) sans demande explicite d'Andy.

## Lecture avant travail

1. ce fichier ;
2. `docs/CURRENT_STATE.md` — l'état prouvé, tenu court ;
3. l'unité de travail complète : fonctionnalité `docs/features/` ou ticket
   encore ouvert de l'archive `docs/tickets/` ;
4. seulement ensuite, les documents et ADR que l'unité lie.

Préséance en cas d'écart : code, migrations et lockfiles de la branche > unité
active et ADR acceptées > `CURRENT_STATE.md` > documents spécialisés >
roadmap/README. Une branche ou PR non fusionnée n'est jamais une capacité
livrée : toujours distinguer local, poussé, en PR, fusionné dans `main`.

Références à la demande, sous `docs/` : PRODUCT (périmètre), ARCHITECTURE
(frontières), SECURITY (menaces et contrôles), QUALITY (commandes de
validation), WORKFLOW (cycle, jalons, délégation, handoff Git), MAINTENANCE
(dettes), LEARNINGS, STACK, SUPPORT, KNOWN_ISSUES.

## Invariants non négociables

- Le serveur est autoritaire pour l'argent, la propriété, la réputation, la
  progression et toute transition sensible. WebView, desktop, bridge et MSFS
  sont des clients non fiables. Aucun secret backend ne part côté client.
- Migrations Supabase append-only ; commandes sensibles transactionnelles et
  idempotentes ; tout changement SQL prouve l'isolation RLS A/B/anonyme.
- Jamais de secret, JWT, donnée personnelle, `.env` ou jeton versionné ou
  journalisé. Jamais télécharger puis exécuter un script distant.
- Valider toute entrée aux frontières IPC, REST, SignalR et serveur.
- TypeScript strict, C# nullable, Rust sans nouvel avertissement ; pages React
  minces (règles métier et accès aux données à l'extérieur) ; versions et
  lockfiles exacts du dépôt ; pas de nouvelle dépendance quand l'outillage
  épinglé suffit.
- Aucune donnée utilisateur réelle tant que `KI-021` n'est pas levé.
- Pas de changement d'architecture ou de frontière de confiance sans ADR ; une
  ADR ne se modifie que par une ADR qui la remplace.
- Versions produit en SemVer 2.0.0 (`0.x.y`, préversions `-alpha.N`, `-beta.N`,
  `-rc.N`) depuis la source unique `eng/product-version.json` ; jamais de
  version opaque, de numéro réutilisé ni de tag déplacé.

## Périmètre et unités de travail

Une unité (fonctionnalité ou ticket d'archive) = une branche = un worktree.
Deux unités `In progress` au maximum ; `pnpm ticket-batch:select` applique ce
plafond et reste la seule autorité de sélection. Une fonctionnalité avance
jalon par jalon — cycle détaillé dans `docs/WORKFLOW.md`.

- Implémenter uniquement l'unité ; respecter `Allowed areas` et `Do not touch`.
- Consigner toute découverte hors périmètre dans `docs/KNOWN_ISSUES.md` avec
  preuve et sévérité, sans la corriger au passage.
- S'arrêter et demander à Andy dès qu'une ambiguïté touche le produit,
  l'économie, la sécurité, les données, le support ou l'architecture.
- Le champ `Status` du fichier de l'unité fait foi ; son index
  (`docs/features/README.md` ou `docs/tickets/README.md`) doit refléter le même
  statut dans le même changement.

## Validation

`docs/QUALITY.md` liste les commandes actives ; exécuter d'abord les tests
ciblés, puis les gates du périmètre, en appliquant la rigueur à deux vitesses
du pilotage. Ne jamais annoncer réussi un contrôle non exécuté : `non exécuté`,
`bloqué par l'environnement` et `échoué` sont trois résultats distincts, et un
outil qui sort `0` sans avoir découvert de test ne prouve rien.

## Git et GitHub

- Relever la branche courante juste avant chaque commit : le worktree principal
  est partagé entre plusieurs sessions et son `HEAD` peut avoir changé.
- Indexer par liste explicite de chemins ; jamais `git add .` ni `git add -A` ;
  relire `git diff --cached` et `git diff --cached --check` avant de committer ;
  messages Conventional Commits.
- Jamais de force-push ni de contournement de protection ; Git pour Windows,
  pas Git WSL ; `gh auth login` si l'authentification manque, jamais de mot de
  passe.
- PR en brouillon tant que les validations ou dépendances ne sont pas prêtes ;
  ne jamais inventer une branche, une base ou un résultat de CI.
- **La revue finale et le merge appartiennent exclusivement à Andy.**

Le rapport de fin d'unité donne : statut, fichiers modifiés, commandes et
résultats réels, risques et limites, branche, commit et Pull Request.
