# T0008 — Créer le frontend React minimal

Status: Done
Owner: Andy
Branch: `foundation/t0008-react-frontend`
Phase: 1
Risk: Medium
Security-sensitive: Yes

## Réconciliation du suivi — 28 juillet 2026

L'implémentation a été fusionnée dans `main` par les PR #3 et #8. La baseline,
les tests de comportement et de sécurité ainsi que le build Tauri sont présents.

T0006 est `Done` depuis sa preuve clean-clone du 30 juillet 2026. Le présent
ticket reste `Verify` : T0007 n'est pas encore `Done` et la checklist interactive
focus, zoom 200 %, réduction des animations et inspection console/réseau n'a pas
été consignée intégralement.

## Goal

Remplacer la page HTML statique de T0007 par un frontend minimal :

- React 19 ;
- TypeScript strict ;
- Vite 8 ;
- Vitest 4 ;
- Testing Library ;
- Tailwind CSS 4 ;
- React Router 7 en mode SPA.

Le frontend doit :

- s'afficher dans le shell Tauri existant ;
- rester entièrement local et sans backend ;
- posséder une structure maintenable par fonctionnalités ;
- gérer les erreurs de rendu ;
- disposer de tests et commandes reproductibles ;
- mesurer le coût ajouté par rapport à la baseline T0007 ;
- n'implémenter aucune fonctionnalité métier.

## Context

ADR-0004 retient exactement :

- React/React DOM `19.2.8` ;
- React Router `7.18.1` en mode SPA ;
- TypeScript `6.0.3` ;
- Vite `8.1.5` ;
- Vitest et `@vitest/coverage-v8` `4.1.10` ;
- Testing Library React `16.3.2` ;
- `jest-dom` `6.9.1` ;
- `user-event` `14.6.1` ;
- Tailwind CSS et plugin Vite `4.3.3`.

T0007 a créé un shell Tauri sans framework, sans réseau, sans plugin et sans
commande IPC applicative. T0008 doit préserver ses frontières de sécurité. Il
mesure le delta frontend, pas l'empreinte finale de Thrustline.

## Dependencies

- T0001 à T0007 terminés.
- `docs/decisions/ADR-0004-stack-cible.md`
- `docs/STACK.md`
- baseline `docs/benchmarks/T0007-shell-baseline.md`
- source de versions et bootstrap T0006 ;
- shell et invariants T0007.

## Allowed areas

Dans le **nouveau dépôt uniquement** :

- source de versions pour les composants frontend validés ;
- manifests et lockfiles pnpm concernés ;
- scripts racine liés au frontend ;
- `apps/desktop/package.json` ;
- `apps/desktop/index.html` ;
- `apps/desktop/src/` ;
- configurations TypeScript, Vite, Vitest et Tailwind du desktop ;
- configuration Tauri strictement nécessaire pour `devUrl`, `frontendDist`,
  `beforeDevCommand` et `beforeBuildCommand` ;
- tests frontend et tests d'invariants ;
- `scripts/measure-frontend.ps1` ;
- `docs/ARCHITECTURE.md` ;
- `docs/QUALITY.md` ;
- `docs/SECURITY.md` ;
- `docs/SETUP.md` ;
- `docs/benchmarks/T0008-frontend-baseline.md` ;
- ce ticket et les fichiers d'état du nouveau dépôt.

Dans l'ancien dépôt de référence :

- ce ticket ;
- `docs/tickets/README.md` et `docs/CURRENT_STATE.md` uniquement pour le statut et
  le Completion Report après exécution.

## Do not touch

- code applicatif de l'ancien dépôt ;
- `legacy/` ;
- code Rust du shell, sauf correction indispensable de configuration explicitement
  justifiée ;
- capabilities Tauri ;
- plugins Tauri ;
- commandes IPC ;
- bridge .NET ;
- SimConnect ;
- Supabase, authentification ou données ;
- SignalR, HTTP ou WebSocket ;
- cartes, graphiques, icônes externes ou composants métier ;
- gestionnaire d'état global ;
- bibliothèque de formulaires ou de validation ;
- internationalisation ;
- updater, signature ou packaging final ;
- custom title bar, tray, single-instance ou Discord ;
- copie du CSS ou des composants de l'ancienne application.

## Target structure

Adapter les chemins à la structure validée par T0006/T0007, avec une cible
équivalente à :

```text
apps/desktop/
  index.html
  package.json
  src/
    app/
      App.tsx
      AppErrorBoundary.tsx
      routes.tsx
    pages/
      HomePage.tsx
      NotFoundPage.tsx
    shared/
      ui/
        StatusCard.tsx
    styles/
      index.css
    test/
      setup.ts
    main.tsx
    vite-env.d.ts
  tsconfig.json
  tsconfig.node.json
  vite.config.ts
  vitest.config.ts
```

Ne pas créer de dossiers `features/` vides. Ils apparaîtront avec les premières
tranches fonctionnelles.

## Requirements

### 1. Ajouter les versions exactes

Ajouter uniquement les dépendances validées par ADR-0004 :

Runtime :

- `react` ;
- `react-dom` ;
- `react-router-dom`.

Développement :

- `typescript` ;
- `vite` ;
- plugin React pour Vite à la version compatible validée ;
- `vitest` ;
- `@vitest/coverage-v8` ;
- `jsdom` ;
- Testing Library React ;
- `jest-dom` ;
- `user-event` ;
- Tailwind CSS ;
- plugin Tailwind pour Vite ;
- types React/React DOM compatibles avec React 19.

Règles :

- versions exactes, sans `^` ni `~` ;
- source de versions T0006 synchronisée ;
- lockfile pnpm figé ;
- aucun script d'installation non justifié ;
- aucune dépendance issue de l'ancien lockfile ;
- aucune dépendance réseau ou métier.

### 2. Configurer TypeScript strict

Activer au minimum :

- `strict` ;
- `noImplicitOverride` ;
- `noFallthroughCasesInSwitch` ;
- `noUncheckedIndexedAccess` ;
- `noUnusedLocals` ;
- `noUnusedParameters` ;
- `exactOptionalPropertyTypes` si compatible avec la stack retenue ;
- imports cohérents et alias interne documenté ;
- aucune émission pendant le typecheck.

Interdire :

- `any` explicite sans justification locale ;
- `@ts-ignore` ;
- assertions non nulles systématiques ;
- données non validées présentées comme typées.

Le ticket doit fournir une commande `frontend:typecheck`.

### 3. Configurer Vite pour Tauri

La configuration doit :

- utiliser le port de développement fixé par le projet ;
- échouer si ce port est occupé au lieu d'en choisir silencieusement un autre ;
- écouter uniquement sur loopback ;
- produire des chemins relatifs compatibles avec Tauri ;
- générer un dossier de sortie dédié et ignoré par Git ;
- ne pas publier de source map production contenant des chemins sensibles, sauf
  décision documentée ;
- ne pas injecter de variable d'environnement non explicitement autorisée ;
- refuser l'utilisation d'un secret avec préfixe public ;
- ne configurer aucun proxy réseau.

Mettre à jour Tauri pour :

- lancer Vite en développement ;
- utiliser le build Vite en production ;
- conserver la CSP production sans origine réseau ;
- limiter les exceptions de développement à loopback et au HMR.

### 4. Créer une composition React minimale

`main.tsx` doit :

- trouver explicitement la racine ;
- échouer avec un message clair si elle manque ;
- monter React en `StrictMode` ;
- ne créer aucun provider métier ;
- ne lancer aucun effet réseau.

`App.tsx` doit seulement assembler :

- l'error boundary ;
- le routeur SPA ;
- une structure de page minimale ;
- le contenu de démonstration local.

### 5. Ajouter un routage SPA minimal

Créer uniquement :

- `/` : page `HomePage` ;
- route inconnue : `NotFoundPage`.

La page d'accueil indique :

- nom Thrustline ;
- mention « Frontend baseline » ;
- stack frontend utilisée ;
- état local `Ready`.

Le routeur doit :

- fonctionner dans Tauri sans serveur ;
- ne pas activer SSR, Server Components ou fonctions serveur ;
- préserver le retour arrière/avant lorsque possible ;
- ne pas inventer les futures routes du produit.

Choisir `HashRouter` ou une autre stratégie compatible Tauri et documenter le
choix. Ne pas dépendre d'une réécriture serveur inexistante.

### 6. Créer un error boundary

`AppErrorBoundary` doit :

- intercepter une erreur de rendu enfant ;
- afficher un écran local et accessible ;
- proposer une action de rechargement ;
- ne pas afficher stack trace, chemin local ou donnée sensible ;
- permettre aux tests d'injecter une erreur ;
- ne pas envoyer de télémétrie.

Les erreurs de développement peuvent rester visibles dans la console locale, sans
secret.

### 7. Poser les fondations visuelles

Tailwind doit être compilé localement. Définir un petit ensemble de tokens :

- arrière-plan ;
- surface ;
- texte principal/secondaire ;
- accent ;
- succès ;
- avertissement ;
- erreur ;
- focus.

Exigences :

- contraste lisible ;
- focus clavier visible ;
- zoom 200 % sans perte du contenu principal ;
- respect de `prefers-reduced-motion` ;
- aucune police distante ;
- aucune animation décorative obligatoire ;
- aucun copier-coller du design historique.

Créer au maximum un composant partagé simple, par exemple `StatusCard`, afin de
prouver le pattern sans construire prématurément un design system complet.

### 8. Ajouter les scripts frontend

Exposer depuis la racine des commandes cohérentes :

- `pnpm frontend:dev` ;
- `pnpm frontend:typecheck` ;
- `pnpm frontend:test` ;
- `pnpm frontend:coverage` ;
- `pnpm frontend:build` ;
- `pnpm frontend:measure`.

Les commandes desktop T0007 doivent continuer à fonctionner. Éviter deux scripts
différents pour la même opération.

### 9. Ajouter les tests

Tester au minimum :

- montage de l'application ;
- contenu de la page d'accueil ;
- route inconnue ;
- navigation minimale ;
- error boundary ;
- action de rechargement via abstraction testable ;
- accessibilité de base : landmarks, titres et focus ;
- absence d'appel réseau pendant le rendu ;
- absence de ressource distante dans `index.html` et CSS ;
- cohérence CSP/capabilities conservée ;
- build sans secret public inattendu.

La couverture doit être mesurée, mais aucun pourcentage arbitraire ne doit être
utilisé pour masquer l'absence de scénarios utiles.

### 10. Mesurer le delta frontend

Créer `scripts/measure-frontend.ps1` ou étendre proprement le harness T0007 afin de
mesurer :

- temps du typecheck ;
- temps des tests ;
- temps du build Vite propre et incrémental ;
- taille brute et gzip du HTML/CSS/JS ;
- nombre de chunks ;
- taille de l'exécutable Tauri après intégration ;
- temps de démarrage froid/chaud ;
- mémoire après 30 et 60 secondes ;
- delta par rapport à T0007.

Protocole :

- même machine et mêmes conditions que T0007 si possible ;
- cinq démarrages froids et cinq chauds ;
- médiane, minimum et maximum ;
- aucune conclusion causale sans mesure comparable ;
- aucun budget définitif avant T0015.

### 11. Créer le rapport de baseline

`docs/benchmarks/T0008-frontend-baseline.md` doit contenir :

- date et commit ;
- versions exactes ;
- protocole ;
- métriques de build et bundle ;
- métriques de démarrage et mémoire ;
- delta T0007 → T0008 ;
- limites ;
- régressions constatées ;
- conclusion : continuer, investiguer ou bloquer.

### 12. Préserver la sécurité Tauri

Le ticket ne doit pas :

- ajouter un plugin ;
- ajouter une capability ;
- ajouter une commande IPC ;
- élargir la CSP production à Internet ;
- autoriser `unsafe-eval` ;
- charger une ressource distante ;
- ouvrir un lien externe ;
- exposer une variable secrète à Vite.

Ajouter un test d'invariant qui échoue si ces garanties changent.

### 13. Mettre à jour les sources de vérité

Dans le nouveau dépôt :

- documenter la structure frontend ;
- ajouter les commandes réelles au setup ;
- consigner la stratégie de routage ;
- documenter les erreurs et frontières ;
- définir le prochain ticket recommandé selon la roadmap.

Dans l'ancien dépôt :

- compléter le Completion Report T0008 ;
- mettre à jour le backlog et l'état courant sans recopier toute la baseline.

## Non-goals

- Authentification.
- Supabase.
- Bridge .NET ou SimConnect.
- SignalR ou réseau.
- État global métier.
- Pages dashboard, flotte, dispatch ou finances.
- Import de l'ancienne interface.
- Cartes, graphiques ou catalogues.
- Formulaires métier.
- Internationalisation.
- Updater, signature ou packaging final.
- Custom title bar.
- Fixer les budgets définitifs.

## Acceptance criteria

- [x] T0006 est `Done`.
- [ ] T0007 est `Done`.
- [x] Le travail se trouve sur `foundation/t0008-react-frontend`.
- [x] Le contrôle de toolchain T0006 reste vert.
- [x] Les commandes et la baseline T0007 restent vertes.
- [x] Les versions frontend correspondent exactement à ADR-0004.
- [x] TypeScript strict passe sans `any` ou ignore injustifié.
- [x] La page `/` et la route inconnue fonctionnent dans Tauri.
- [x] L'application possède un error boundary testé.
- [x] Le frontend n'effectue aucun appel réseau.
- [x] Aucun plugin, capability ou IPC Tauri n'est ajouté.
- [x] La CSP production ne contient aucune nouvelle origine réseau.
- [x] Les tests de comportement et d'invariants passent.
- [x] Le build frontend et le build Tauri sans bundle passent.
- [x] Le HTML/CSS/JS ne charge aucune ressource distante.
- [ ] Le focus clavier, le zoom 200 % et reduced motion sont vérifiés.
- [x] La baseline compare correctement T0007 et T0008.
- [x] Aucun budget non validé n'est présenté comme une obligation.
- [x] Aucun code frontend de l'ancien dépôt n'est copié.

## Security review

### Assets

- contenu WebView2 ;
- bundle frontend ;
- CSP ;
- variables Vite ;
- dépendances npm ;
- futures frontières IPC et réseau.

### Abuse and failure cases

- variable secrète intégrée au bundle ;
- XSS via contenu ou HTML non fiable ;
- ressource distante compromise ;
- CSP élargie pour faciliter le développement ;
- package npm compromis ou script d'installation ;
- route ouvrant une URL arbitraire ;
- stack trace/path local affiché à l'utilisateur ;
- ajout implicite d'une capability Tauri ;
- source map production exposant des détails inutiles ;
- test simulant le réseau sans détecter un vrai appel.

### Required controls

- aucune donnée non fiable dans ce ticket ;
- aucune utilisation de `dangerouslySetInnerHTML` ;
- dépendances exactes et lockfile figé ;
- scripts d'installation examinés ;
- CSP et capabilities testées ;
- seules variables explicitement publiques accessibles à Vite ;
- error boundary sans détail interne ;
- ressources locales ;
- revue du bundle et du diff ;
- PR gérée selon `AGENTS.md`.

## Automated validation

Adapter les chemins aux conventions réelles du nouveau dépôt :

```powershell
# Depuis la racine du nouveau dépôt
pwsh -NoProfile -File .\scripts\check-toolchain.ps1
pnpm install --frozen-lockfile

pnpm frontend:typecheck
pnpm frontend:test
pnpm frontend:coverage
pnpm frontend:build

# Vérifier l'intégration desktop
pnpm desktop:check
pnpm desktop:test
pnpm desktop:build

# Mesurer le delta
pnpm frontend:measure

# Vérifications générales
git diff --check
git status --short
```

Les tests ne doivent pas dépendre d'Internet, Supabase ou MSFS.

## Manual verification

1. Lancer le frontend seul et confirmer les deux routes.
2. Lancer l'application Tauri.
3. Vérifier le titre, le redimensionnement et le contenu.
4. Naviguer vers une route inconnue puis revenir.
5. Déclencher l'erreur de test prévue et vérifier l'écran sûr.
6. Vérifier le focus clavier et le zoom à 200 %.
7. Activer la réduction des animations.
8. Contrôler l'absence de requête réseau et d'erreur console inattendue.
9. Fermer l'application et vérifier l'absence de processus orphelin.
10. Relire le rapport de mesure et son delta par rapport à T0007.

Temps cible : 20 minutes hors compilation initiale.

## Rollback

Avant fusion :

- abandonner la branche T0008 ;
- revenir au dernier commit T0007 vert ;
- conserver la baseline T0007 ;
- ne modifier aucun cache ou outil global.

Après fusion :

- revenir au dernier commit T0007 si aucun ticket ne dépend encore de React ;
- sinon ouvrir un ticket de correction ;
- remplacer ADR-0004 uniquement si les mesures démontrent un défaut structurant.

## Completion Report

### Summary

Le frontend React minimal local a remplacé la page statique, avec routage SPA,
error boundary, tests d'invariants et baseline de coût.

### Repository and branch

`AndyD9/ThrustlineNG`, branche historique
`foundation/t0008-react-frontend`.

### Frontend versions

React `19.2.8`, React Router `7.18.1`, TypeScript `6.0.3`, Vite `8.1.5`,
Vitest `4.1.10` et Tailwind CSS `4.3.3`.

### Routing and error handling

`HashRouter`, routes `/` et inconnue, error boundary sûr avec rechargement
injectable dans les tests.

### Security invariants

Zéro réseau, plugin, capability ou commande IPC ; ressources locales et CSP
production inchangée.

### Files changed in the new repository

Commit `3f77984` : frontend, configurations, tests, mesure, baseline et
documentation.

### Files changed in the reference repository

Sans objet.

### Commands and results

- rejeu du 28 juillet : couverture et 8 tests frontend réussis ;
- typecheck, format Rust, Cargo check, Clippy et invariants réussis ;
- build Tauri Release sans bundle réussi.

### Bundle and performance delta

Voir `docs/benchmarks/T0008-frontend-baseline.md` : bundle brut `242 338 o`,
gzip `77 111 o`, delta mémoire privée médian d'environ `+0,53 Mio`, dix cycles
réussis sans processus orphelin.

### Manual verification result

Routes, error boundary, absence de réseau et landmarks sont couverts
automatiquement. Focus, zoom 200 %, reduced motion et inspection console/réseau
restent à confirmer manuellement.

### Risks and limitations

- T0007 reste `Verify`.
- Une seule machine a servi aux mesures.

### Follow-ups

- Exécuter et consigner la checklist interactive du ticket.

### Documentation updated

Ticket, backlog, baseline et `CURRENT_STATE.md`.

### Git and GitHub result

- commit : `3f77984` ;
- PR #3 fusionnée dans `main` le 28 juillet 2026 ;
- PR #8 a réintégré la branche après les merges empilés ;
- état final : présent dans `main`.

Indiquer séparément pour chaque dépôt :

- branche ;
- commit ;
- remote et branche cible ;
- fichiers inclus ;
- modifications préexistantes exclues ;
- résultats du push ;
- URL et statut Draft/Ready de la Pull Request ;
- validations GitHub ;
- blocages éventuels.

L'agent crée ou met à jour la PR de manière autonome, mais ne la merge jamais.

## Vérification interactive du 7 août 2026 (T0056)

Exécutée par la session agent sur instruction du passage de relais d'Andy, sur
la machine de validation (Windows 11 Pro 26200), commit `8e6bf8d`, build
Release, WebView pilotée par CDP. La confirmation finale appartient à Andy par
la revue et la fusion de la PR de T0056. Le frontend vérifié est celui
d'aujourd'hui (login, onboarding, achat, dispatch), qui a remplacé la baseline
deux-routes historique : la checklist est interprétée sur l'application
actuelle.

- **Campagne de mesure rejouée** (`pnpm frontend:measure`, rapports
  `artifacts/t0008/frontend-measurements.json` et
  `tauri-shell-measurements.json`) : typecheck 4,296 s, tests 11,265 s,
  bundle 304 769 o bruts / 89 206 o gzip (un chunk JS de 294 712 o), delta
  runtime vs T0007 consigné dans le rapport ; cinq lancements froids (médiane
  88,5 ms) et cinq chauds (94,7 ms), dix cycles propres, zéro orphelin.
- **Routes** : `#/route-inconnue` rend « Page introuvable » avec le lien
  « Retour à l'accueil » ; retour à la route connue vérifié.
- **Écran d'erreur sûr** : non exécuté interactivement — l'application
  actuelle n'expose plus de déclencheur d'erreur de test ; le comportement de
  `AppErrorBoundary` (écran sûr, aucune donnée envoyée, bouton Recharger)
  reste prouvé par `AppErrorBoundary.test.tsx`.
- **Focus clavier** : Tab parcourt email → mot de passe → bouton de connexion
  puis boucle ; `document.activeElement` relevé à chaque pas.
- **Zoom 200 %** : émulé par CDP (`visualViewport.scale` = 2), contenu rendu.
  Les raccourcis de zoom WebView2 restent désactivés par configuration.
- **Réduction des animations** : `prefers-reduced-motion: reduce` émulé par
  CDP, `matchMedia` le confirme côté page et le rendu reste intact.
- **Console et réseau** : zéro erreur/avertissement console et zéro requête
  hors origines internes de la WebView sur l'ensemble du parcours.
- **Fermeture** : par la fenêtre principale, zéro processus orphelin.
