# T0007 — Créer le shell Tauri minimal et mesurer son empreinte

Status: Done
Owner: Andy
Branch: `foundation/t0007-tauri-shell`
Phase: 1
Risk: High
Security-sensitive: Yes

## Réconciliation du suivi — 28 juillet 2026

L'implémentation a été fusionnée dans `main` par la PR #2 le 27 juillet 2026.
La baseline prouve une fenêtre visible, cinq lancements froids, cinq chauds et
dix fermetures sans processus orphelin.

T0006 est `Done` depuis sa preuve clean-clone du 30 juillet 2026. Le présent
ticket reste `Verify` : l'absence de WebView2 n'a pas été testée sur une VM
propre et la checklist interactive complète (titre, redimensionnement, zoom et
console/réseau) n'a pas été consignée.

## Goal

Créer dans le nouveau dépôt un shell desktop Tauri v2 minimal, sécurisé et
mesurable qui :

- ouvre une fenêtre Windows native contenant une page locale statique ;
- n'embarque encore ni React, ni logique métier, ni bridge .NET ;
- n'expose aucune commande IPC applicative ;
- n'active aucun plugin Tauri non nécessaire ;
- utilise une CSP et des capabilities minimales ;
- se construit de manière reproductible pour `x86_64-pc-windows-msvc` ;
- produit une baseline d'empreinte avant l'ajout du frontend et du sidecar.

Le ticket prouve la viabilité du choix Tauri/WebView2 retenu par ADR-0004. Il ne
prouve pas encore la performance finale de Thrustline.

## Context

ADR-0003 cible Windows 11 x64 et MSFS 2024 stable.

ADR-0004 retient :

- Tauri `2.11.5` ;
- Tauri CLI `2.11.4` ;
- Tauri API `2.11.1` lorsqu'elle deviendra nécessaire ;
- Rust `1.97.1` épinglé ;
- WebView2 Evergreen ;
- aucun plugin Tauri par défaut ;
- aucun `plugin-shell` générique ;
- capabilities minimales et CSP restrictive.

T0006 doit avoir créé la source de versions, le bootstrap et les contrôles de
dérive. T0007 adopte pour la première fois une partie de la stack applicative,
mais reste volontairement indépendant de React et du bridge.

## Dependencies

- T0001 à T0006 terminés.
- `docs/decisions/ADR-0003-matrice-support-windows-msfs.md`
- `docs/decisions/ADR-0004-stack-cible.md`
- `docs/STACK.md`
- `docs/SUPPORT.md`
- pins et scripts issus de T0006 dans le nouveau dépôt.

## Allowed areas

Dans le **nouveau dépôt uniquement** :

- source de versions si l'ajout des versions Tauri a été prévu par T0006 ;
- `package.json` racine pour les scripts du workspace ;
- `pnpm-workspace.yaml` ;
- lockfiles générés par les versions épinglées ;
- `apps/desktop/` ;
- `scripts/measure-tauri-shell.ps1` ;
- `tests/desktop-shell/` ;
- `docs/ARCHITECTURE.md` ;
- `docs/QUALITY.md` ;
- `docs/SECURITY.md` ;
- `docs/benchmarks/T0007-shell-baseline.md` ;
- README/setup strictement liés au lancement du shell ;
- ce ticket et les fichiers d'état du nouveau dépôt.

Dans l'ancien dépôt de référence :

- ce ticket ;
- `docs/tickets/README.md` et `docs/CURRENT_STATE.md` uniquement pour le statut et
  le Completion Report après exécution.

## Do not touch

- code applicatif de l'ancien dépôt ;
- `legacy/` ;
- React, React DOM, routeur, Vite, Vitest ou Tailwind ;
- bridge .NET ;
- SimConnect ;
- Supabase ;
- SignalR ;
- système de mise à jour ;
- signature et publication ;
- `plugin-shell` ;
- ouverture arbitraire d'URL ;
- accès fichiers, réseau, processus, presse-papiers ou notifications ;
- custom title bar ;
- analytics, Discord Rich Presence ou crash reporting ;
- installation ou réparation automatique de WebView2 ;
- modification globale de Git, Rust, Node ou Windows.

## Target structure

La structure cible minimale est :

```text
apps/
  desktop/
    package.json
    web/
      index.html
      styles.css
    src-tauri/
      Cargo.toml
      Cargo.lock
      build.rs
      tauri.conf.json
      capabilities/
        default.json
      src/
        lib.rs
        main.rs
scripts/
  measure-tauri-shell.ps1
docs/
  benchmarks/
    T0007-shell-baseline.md
```

Adapter uniquement si T0006 a défini une convention différente. Documenter toute
divergence plutôt que créer deux organisations concurrentes.

## Requirements

### 1. Ajouter les versions Tauri sans dérive

Ajouter les composants nécessaires avec les versions exactes d'ADR-0004 :

- crate `tauri` ;
- build dependency `tauri-build` ;
- CLI Tauri dans les devDependencies du package desktop ou à la racine selon la
  convention T0006.

Règles :

- versions exactes ;
- lockfiles générés par pnpm/Rust épinglés ;
- aucun plugin Tauri ;
- aucun script d'installation non justifié ;
- synchronisation avec la source de versions de T0006 ;
- contrôle de toolchain toujours vert.

`@tauri-apps/api` ne doit être ajouté que si le shell statique l'utilise réellement.

### 2. Créer une page locale sans framework

Créer une page HTML/CSS statique indiquant seulement :

- nom Thrustline ;
- mention « Shell baseline » ;
- version de développement non sensible ;
- état local « Ready ».

La page doit :

- fonctionner sans CDN ni ressource distante ;
- ne charger aucun script tiers ;
- ne contenir aucune logique métier ;
- ne faire aucune requête réseau ;
- respecter un thème simple lisible ;
- fonctionner au clavier et avec zoom WebView2 ;
- ne pas copier l'ancienne interface.

Le HTML/CSS sera remplacé par T0008. Il sert uniquement de contenu mesurable.

### 3. Configurer la fenêtre

Configuration minimale recommandée :

- titre `Thrustline` ;
- fenêtre unique ;
- dimensions initiales raisonnables pour 1920×1080 ;
- dimensions minimales compatibles avec la matrice de support ;
- décorations Windows natives ;
- redimensionnable ;
- pas de fullscreen au démarrage ;
- pas d'Always-on-top ;
- pas de fenêtre transparente ;
- pas de tray ;
- devtools désactivés dans la configuration de production ;
- fermeture native sans processus orphelin.

Ne pas recréer la barre de titre personnalisée de l'ancien dépôt.

### 4. Réduire les capabilities

`capabilities/default.json` doit :

- cibler uniquement la fenêtre principale ;
- autoriser uniquement les permissions core réellement nécessaires ;
- ne pas autoriser shell, processus, fichiers, HTTP, dialogue, presse-papiers,
  updater ou ouverture d'URL ;
- ne contenir aucun wildcard large ;
- être revu dans le Completion Report.

Le code Rust ne doit exposer aucune commande `#[tauri::command]` dans ce ticket.

### 5. Définir une CSP restrictive

La CSP de production doit au minimum imposer :

- `default-src 'self'` ;
- scripts locaux uniquement ;
- styles locaux, sans `'unsafe-inline'` si l'implémentation le permet ;
- images locales/data uniquement si nécessaire ;
- aucune connexion réseau ;
- `object-src 'none'` ;
- `frame-src 'none'` ;
- `frame-ancestors 'none'` ;
- `base-uri 'self'` ;
- `form-action 'self'`.

Toute exception doit être justifiée dans `docs/SECURITY.md`. Aucune exception
Supabase, SimBrief, météo, cartes ou localhost n'est nécessaire dans T0007.

### 6. Gérer le cycle de vie minimal

Le shell doit :

- démarrer une seule fenêtre ;
- quitter proprement lorsque cette fenêtre est fermée ;
- ne laisser aucun processus Thrustline orphelin ;
- supporter plusieurs séquences lancement/fermeture ;
- afficher un message actionnable si WebView2 ne peut pas démarrer ;
- ne pas masquer un panic ou une erreur de setup ;
- ne pas créer de fichier utilisateur inutile.

Ne pas implémenter de single-instance plugin dans ce ticket. Un double lancement
peut produire deux instances indépendantes tant que cela est documenté et sans
corruption.

### 7. Ajouter les scripts de développement

Exposer des commandes déterministes, par exemple :

- `pnpm desktop:dev` ;
- `pnpm desktop:check` ;
- `pnpm desktop:build`;
- `pnpm desktop:test`;
- `pnpm desktop:measure`.

Les noms exacts doivent suivre les conventions T0006. Chaque commande doit :

- utiliser les versions épinglées ;
- fonctionner depuis la racine ;
- retourner un code non nul en cas d'échec ;
- ne pas installer silencieusement un outil global.

### 8. Ajouter les validations Rust/Tauri

Exécuter au minimum :

- format check Rust ;
- `cargo check --locked` ;
- `cargo test --locked` même si la suite est encore minimale ;
- Clippy avec avertissements refusés pour le code du projet ;
- validation de la configuration/capabilities ;
- build Tauri release sans bundle si le packaging complet appartient à T0014.

Ajouter un test automatisé ou script qui échoue si :

- un plugin non autorisé apparaît ;
- une capability interdite est ajoutée ;
- la CSP autorise une origine réseau ;
- une commande Tauri applicative est exposée ;
- une ressource distante apparaît dans le HTML.

### 9. Mesurer l'empreinte

Créer `scripts/measure-tauri-shell.ps1` qui collecte sans privilège administrateur :

- commit et version des outils ;
- configuration Release/Debug ;
- durée de build propre et incrémental ;
- taille du frontend statique ;
- taille de l'exécutable ;
- taille totale des artefacts nécessaires au lancement ;
- temps jusqu'à l'affichage de la fenêtre ;
- working set privé du processus principal après 30 et 60 secondes ;
- nombre et mémoire des processus WebView2 associés ;
- nombre de handles si accessible sans élévation ;
- comportement après dix cycles lancement/fermeture.

Méthode :

- effectuer au moins cinq démarrages à froid et cinq démarrages chauds ;
- rapporter médiane, minimum et maximum ;
- indiquer clairement les limites de mesure ;
- ne pas inclure la mémoire globale de MSFS ;
- ne pas comparer à Electron ou au shell natif sans benchmark équivalent.

Le script doit accepter un dossier de sortie explicite et ne jamais écrire dans
un emplacement utilisateur imprévisible.

### 10. Créer le rapport de baseline

`docs/benchmarks/T0007-shell-baseline.md` doit contenir :

- date ;
- commit ;
- machine et version Windows ;
- versions Rust/Tauri/WebView2 ;
- build Debug/Release ;
- protocole ;
- mesures brutes résumées ;
- médianes ;
- anomalies ;
- comparaison avec aucun budget tant que T0015 ne les a pas fixés ;
- conclusion : acceptable pour continuer, investigation ou blocage.

La configuration matérielle ne doit contenir aucun identifiant personnel.

### 11. Vérifier WebView2

Le ticket doit :

- détecter/documenter la version WebView2 utilisée ;
- confirmer qu'aucun runtime Fixed Version n'est embarqué ;
- vérifier le lancement avec Evergreen présent ;
- documenter la procédure officielle lorsque le runtime manque ;
- ne pas télécharger ni réparer automatiquement WebView2 ;
- consigner l'impossibilité de tester un WebView2 absent si aucune VM propre
  n'est disponible.

### 12. Mettre à jour les sources de vérité

Dans le nouveau dépôt :

- documenter la frontière Tauri/WebView2 ;
- consigner les capabilities et la CSP ;
- ajouter les commandes réelles au setup ;
- définir T0008 comme prochain ticket si la baseline est acceptable.

Dans l'ancien dépôt :

- compléter le Completion Report T0007 ;
- actualiser le backlog et l'état courant sans recopier les mesures détaillées.

## Non-goals

- Ajouter React ou un bundler frontend.
- Créer l'interface finale.
- Ajouter une custom title bar.
- Lancer ou superviser le bridge .NET.
- Ajouter SimConnect ou SignalR.
- Ajouter Supabase, authentification ou réseau.
- Ouvrir SimBrief ou une URL externe.
- Ajouter updater, signature, installateur ou auto-launch.
- Implémenter single-instance, tray ou Discord.
- Fixer les budgets définitifs de performance.
- Promouvoir Windows/MSFS vers `Supported`.

## Acceptance criteria

- [x] T0006 est `Done`.
- [x] Le travail est réalisé sur `foundation/t0007-tauri-shell`.
- [x] Le contrôle de toolchain T0006 reste vert.
- [x] Les versions Tauri/Rust correspondent exactement à ADR-0004.
- [x] Le shell affiche une page locale statique sans framework.
- [x] Aucun plugin Tauri n'est activé.
- [x] Aucune commande IPC applicative n'est exposée.
- [x] Les capabilities n'autorisent que le core nécessaire.
- [x] La CSP ne permet aucune origine réseau.
- [x] Le shell compile et se lance sous Windows 11 x64.
- [x] Dix cycles lancement/fermeture ne laissent aucun processus Thrustline
      orphelin.
- [x] Les contrôles format, check, test et Clippy réussissent.
- [x] Le build Release sans bundle réussit.
- [x] Le rapport contient cinq mesures froides et cinq mesures chaudes.
- [x] Tailles, démarrage, mémoire et processus WebView2 sont consignés.
- [x] Aucune comparaison non mesurée n'est présentée comme un fait.
- [x] Le rapport conclut si T0008 peut commencer.
- [x] Aucun code de l'ancien dépôt n'est copié.

## Security review

### Assets

- processus desktop ;
- WebView2 ;
- capabilities Tauri ;
- CSP ;
- chaîne Rust/pnpm ;
- futurs canaux IPC et réseau.

### Abuse and failure cases

- contenu distant exécuté dans WebView2 ;
- capability trop large ajoutée par défaut ;
- plugin shell permettant l'exécution de processus ;
- devtools disponibles en production ;
- navigation vers une URL externe ;
- commande IPC non validée ;
- panic masqué ou processus orphelin ;
- dépendance Tauri non épinglée ;
- données personnelles présentes dans les benchmarks ;
- script de mesure exigeant une élévation.

### Required controls

- page locale et CSP restrictive ;
- zéro plugin et zéro commande applicative ;
- capabilities explicites ;
- versions et lockfiles exacts ;
- build Release avec devtools désactivés ;
- tests d'invariants ;
- aucune élévation ;
- rapport redigé ;
- revue du diff avant commit ;
- confirmation distincte avant push.

## Automated validation

Adapter les chemins aux conventions réellement créées par T0006 :

```powershell
# Depuis la racine du nouveau dépôt
pwsh -NoProfile -File .\scripts\check-toolchain.ps1
pnpm install --frozen-lockfile

# Contrôles du shell
pnpm desktop:check
pnpm desktop:test
pnpm desktop:build

# Mesures
pnpm desktop:measure

# Vérifications directes Rust si elles ne sont pas déjà encapsulées
Set-Location .\apps\desktop\src-tauri
cargo fmt --check
cargo check --locked
cargo test --locked
cargo clippy --locked -- -D warnings

# Retour à la racine
Set-Location ..\..\..
git diff --check
git status --short
```

Le build doit utiliser la toolchain épinglée. Ne pas déclarer une mesure réussie
si la fenêtre n'a pas réellement été affichée.

## Manual verification

1. Confirmer la branche et la propreté initiale.
2. Lancer `pnpm desktop:dev`.
3. Vérifier la fenêtre, le titre, le redimensionnement et le zoom.
4. Vérifier l'absence de requête réseau et d'erreur console.
5. Fermer puis relancer dix fois.
6. Contrôler l'absence de processus Thrustline orphelin.
7. Exécuter le build Release et lancer l'exécutable produit.
8. Relire le rapport de mesure et vérifier la configuration matérielle.
9. Inspecter la CSP, les capabilities et les dépendances Tauri.

Temps cible : 20 minutes hors compilation initiale.

## Rollback

Avant fusion :

- abandonner la branche T0007 ;
- revenir au dernier commit T0006 vert ;
- ne supprimer aucun cache global ni WebView2.

Après fusion :

- revenir au dernier commit T0006 si aucun ticket ne dépend encore du shell ;
- sinon ouvrir un ticket de correction ;
- conserver le rapport de baseline comme historique, même si Tauri est ensuite
  remplacé par une nouvelle ADR.

## Completion Report

### Summary

Un shell Tauri local, sans plugin ni commande IPC applicative, a été livré et
mesuré. Les invariants restent verts après l'intégration React et bridge.

### Repository and branch

`AndyD9/ThrustlineNG`, branche historique `foundation/t0007-tauri-shell`.

### Tauri/Rust versions

Tauri `2.11.5`, CLI `2.11.4`, `tauri-build` `2.6.3`, Rust `1.97.1`.

### Capabilities and CSP

Capability limitée à `main`, zéro permission applicative ; CSP production locale
sans origine réseau.

### Files changed in the new repository

Commit `34a233c` : shell, configuration Tauri, invariants, harness de mesure,
baseline et documentation spécialisée.

### Files changed in the reference repository

Sans objet.

### Commands and results

- baseline historique : cinq lancements froids, cinq chauds et dix cycles
  réussis ;
- rejeu du 28 juillet : `desktop:check`, `desktop:test` et `desktop:build`
  réussis ; 8 tests frontend, format/check/Clippy et invariants conformes ;
- build Release sans bundle réussi.

### Measurement protocol and results

Voir `docs/benchmarks/T0007-shell-baseline.md`. Médiane d'affichage froide
`89,4 ms`, chaude `92,5 ms`, zéro processus orphelin.

### Manual verification result

Fenêtre visible et cycles de fermeture prouvés par le harness. Restent la
checklist interactive complète et le scénario WebView2 absent sur VM propre.

### Security review result

Aucun plugin, IPC, accès réseau ou capability large détecté par les invariants.

### Risks and limitations

- Une seule machine Windows mesurée.
- WebView2 absent non testé.

### Follow-ups

- Exécuter la checklist interactive du ticket.
- Tester la procédure WebView2 absent sur une VM propre.

### Documentation updated

Ticket, backlog, baseline et `CURRENT_STATE.md`.

### Git handoff

- commit : `34a233c` ;
- PR : https://github.com/AndyD9/ThrustlineNG/pull/2 ;
- PR fusionnée dans `main` le 27 juillet 2026.

Indiquer séparément pour chaque dépôt :

- branche constatée ;
- remote et branche cible ;
- fichiers exacts du ticket ;
- modifications hors ticket à préserver ;
- message de commit proposé ;
- commandes PowerShell de vérification ;
- confirmation demandée avant commit/push ;
- résultat du push s'il est autorisé.

Ne jamais utiliser `git add .` ou `git add -A`.

## Vérification interactive du 7 août 2026 (T0056)

Exécutée par la session agent sur instruction du passage de relais d'Andy, sur
la machine de validation (Windows 11 Pro 26200), commit `8e6bf8d`, build
Release. La confirmation finale appartient à Andy par la revue et la fusion de
la PR de T0056.

- **Campagne de mesure T0015 rejouée** (`pnpm desktop:measure`, rapport
  `artifacts/t0007/tauri-shell-measurements.json`) : cinq lancements froids
  (min 85,3 / médiane 90,4 / max 102 ms d'affichage), cinq chauds (79,8 /
  86 / 91,3 ms), dix cycles lancement/fermeture tous `cleanExit` et
  `cleanBridgeExit`, **zéro orphelin** desktop et bridge, un seul processus
  bridge et un seul processus WebView2 par lancement, fenêtre réellement
  affichée (le protocole échoue sinon).
- **Fenêtre** : titre `Thrustline` ; redimensionnement réel appliqué
  (900 × 650 constaté par `GetWindowRect`). Limite de méthode : la contrainte
  de minimum 800 × 600 ne s'oppose pas à un `MoveWindow` programmatique —
  `WM_GETMINMAXINFO` ne borne que le redimensionnement interactif, que cette
  session ne peut pas simuler à la souris ; ce n'est pas un défaut produit.
- **Zoom 200 %** : émulé par CDP (`visualViewport.scale` = 2), contenu rendu
  et lisible. Les raccourcis de zoom WebView2 restent désactivés par
  configuration Tauri (défaut), le zoom d'accessibilité relève de l'OS.
- **Réseau et console** : sur tout le parcours CDP (login, route inconnue,
  focus), zéro requête hors origines internes de la WebView et zéro
  erreur/avertissement console.
- **Exécutable Release lancé réellement** (celui produit par la campagne),
  fermé par sa fenêtre principale, bridge éteint, zéro orphelin.
- **CSP, capabilities et dépendances** : CSP de production
  `connect-src 'none'` inchangée dans `tauri.conf.json` (et, depuis F0005 J1,
  épinglée par canal avec contrôle sur l'exécutable produit) ; unique
  capability `main-shell` à zéro permission sur la seule fenêtre `main` ;
  `devtools: false` ; versions Tauri 2.11.5 / CLI 2.11.4 conformes aux pins.
- **Non exécuté — bloqué par l'environnement** : le scénario WebView2 absent
  sur VM propre ; aucune VM propre n'est disponible sur la machine de
  validation. Ce point reste le seul différé, sans invalider la baseline
  (l'installateur T0014 documente le prérequis WebView2 Evergreen).
