# T0015 — Fixer les budgets stabilité et performance

Status: Verify
Owner: Codex
Branch: `foundation/t0015-stability-performance-budgets`
Phase: 0–1
Risk: Medium
Security-sensitive: No

## Goal

Transformer les mesures T0007 à T0011 en garde-fous versionnés et reproductibles
pour que toute régression d'empreinte, de démarrage ou de cycle de vie soit
détectée avant d'être présentée comme acceptable.

## Context

T0007 et T0008 ont mesuré le shell puis le frontend sur une seule machine
Windows 11. T0009 a publié un bridge .NET self-contained d'environ 80,5 Mio.
T0010 et T0011 ont ajouté le contrat local, les tests de cycle de vie et le
replay synthétique. Aucun budget n'est encore appliqué.

Les implémentations T0007 à T0011 sont présentes dans `main`. T0007, T0008,
T0009 et T0011 restent cependant `Verify` pour des contrôles humains ou
plateforme qui ne sont pas des prérequis aux garde-fous locaux de ce ticket.
Leurs limites restent applicables : une seule machine, aucun vol réel MSFS,
aucun essai de quatre heures et aucune mesure du profil matériel minimum.

Ce ticket fixe des budgets initiaux. Il ne transforme pas une baseline courte en
SLO de production et ne promeut aucune plateforme vers `Supported`.

## Dependencies

- Implémentations fusionnées de T0007 à T0011.
- `docs/benchmarks/T0007-shell-baseline.md`.
- `docs/benchmarks/T0008-frontend-baseline.md`.
- `ADR-0003`, `ADR-0004`, `docs/PRODUCT.md` et `docs/SUPPORT.md`.

Les validations humaines encore ouvertes dans T0007/T0008/T0009/T0011 limitent
la portée des seuils, mais ne bloquent pas leur définition provisoire.

## Allowed areas

- `eng/stability-performance-budgets.json`.
- `scripts/check-performance-budgets.ps1`.
- `scripts/measure-bridge.ps1`.
- `scripts/measure-tauri-shell.ps1` uniquement pour fiabiliser les métriques
  consommées par T0015.
- `tests/performance-budgets/`.
- `package.json`.
- `.github/workflows/ci.yml`.
- `docs/benchmarks/T0015-stability-performance-budgets.md`.
- `docs/QUALITY.md`.
- `docs/CURRENT_STATE.md`.
- `docs/KNOWN_ISSUES.md`.
- ce ticket et `docs/tickets/README.md`.

## Do not touch

- logique applicative frontend, Tauri ou bridge ;
- contrats REST/SignalR et adaptateur SimConnect ;
- Supabase, migrations ou données ;
- dépendances et lockfiles ;
- packaging, signature ou updater ;
- collecte de télémétrie ou crash reporting ;
- matrice de support et statut `Supported` ;
- budgets économiques ou règles métier ;
- ancienne application.

## Requirements

### 1. Source de vérité versionnée

Créer un JSON strict contenant :

- sa version de schéma ;
- les budgets du frontend, du desktop et du bridge ;
- les unités dans les noms de champs ;
- un objectif de cycles sans processus orphelin ;
- un budget de croissance mémoire entre 30 et 60 secondes ;
- les objectifs de release qui ne sont pas encore automatisables ;
- le contexte et la date de révision.

Les scripts lisent cette source ; aucun seuil ne doit être dupliqué dans leur
code.

### 2. Budgets de fondation automatisables

Appliquer aux mesures Release Windows :

- bundle frontend gzip ≤ 256 Kio ;
- artefacts de lancement desktop ≤ 16 Mio ;
- affichage froid médian ≤ 500 ms et maximum ≤ 1 000 ms ;
- affichage chaud médian ≤ 350 ms et maximum ≤ 750 ms ;
- mémoire privée desktop médiane à 60 s ≤ 64 Mio ;
- working set WebView2 associé médian à 60 s ≤ 192 Mio ;
- croissance médiane de mémoire privée entre 30 s et 60 s ≤ 16 Mio ;
- au moins dix cycles propres et zéro processus orphelin ;
- publication bridge self-contained ≤ 128 Mio ;
- health check bridge médian ≤ 1 000 ms et maximum ≤ 2 000 ms sur dix
  lancements.

Ces seuils incluent une marge importante par rapport aux baselines et servent de
détecteurs de régression grossière, pas de preuve du MVP complet.

### 3. Objectifs de release non encore prouvés

Documenter sans les présenter comme atteints :

- démarrage jusqu'à l'état utilisable : p50 ≤ 2 s, p95 ≤ 4 s ;
- mémoire au repos desktop + WebView2 + bridge : p50 ≤ 512 Mio ;
- croissance sur un scénario de quatre heures : ≤ 128 Mio après warm-up ;
- installation complète : ≤ 350 Mio hors caches et données utilisateur ;
- sessions sans crash non géré : ≥ 99,5 % sur 30 jours et au moins
  1 000 sessions ;
- zéro processus orphelin, double clôture, perte silencieuse ou mutation
  financière hors grand livre dans les tests de release.

Les métriques nécessitant télémétrie, MSFS, packaging ou moteur métier restent
`Not measured`.

### 4. Validation déterministe

Le validateur doit :

- refuser un schéma inconnu, un fichier absent ou une mesure mal formée ;
- comparer des entiers dans les unités déclarées ;
- échouer avec la liste des budgets dépassés ;
- réussir avec un résumé sans secret ni chemin utilisateur ;
- accepter séparément les résultats desktop/frontend et bridge ;
- ne jamais lancer l'application, installer un outil ou accéder au réseau.

### 5. Mesure bridge

Ajouter un script Windows sans privilège administrateur qui :

- exige une publication self-contained déjà construite ou la produit via le
  script du dépôt ;
- mesure la taille totale du dossier publié ;
- exécute dix health checks du binaire publié ;
- exige la sortie exacte `Healthy`, un code 0 et aucun timeout ;
- rapporte minimum, médiane et maximum dans un JSON versionné par schéma ;
- écrit uniquement dans un dossier de sortie explicite.

### 6. Tests et CI

Créer un harnais PowerShell avec au minimum :

- une mesure conforme ;
- un dépassement frontend/desktop ;
- un dépassement bridge ;
- un schéma inconnu ;
- une mesure incomplète.

La CI Windows exécute ce harnais et valide les tailles réellement construites.
Les timings desktop avec fenêtre visible restent une campagne locale dédiée :
ils ne doivent pas devenir un test CI bruité.

### 7. Documentation et suivi

Documenter :

- la justification des marges ;
- le protocole et les commandes exactes ;
- les résultats T0007/T0008 et la nouvelle mesure bridge ;
- ce qui est automatiquement bloquant ;
- ce qui reste une cible de release ;
- le mode de révision des budgets.

Un budget ne peut être relevé que dans une PR motivée par une mesure et une
revue ; il ne doit pas être augmenté automatiquement après un échec.

## Non-goals

- Optimiser le code ou réduire les artefacts.
- Mesurer un vol MSFS réel ou un scénario de quatre heures.
- Ajouter de la télémétrie, un SLO backend ou du crash reporting.
- Valider le profil matériel minimum.
- Comparer Tauri à Electron ou à un shell .NET natif.
- Rendre le build Tauri GUI obligatoire sur chaque runner.
- Modifier une frontière de confiance ou une règle produit.

## Acceptance criteria

- [x] Le ticket et la branche dédiée existent, avec limites et dépendances
      explicites.
- [x] Une source JSON unique contient les budgets et objectifs.
- [x] Le validateur refuse chaque dépassement et toute entrée mal formée.
- [x] Le harnais couvre les scénarios positifs et négatifs requis.
- [x] Le bridge est mesuré sur dix lancements depuis sa publication
      self-contained.
- [x] Les baselines T0007/T0008 sont comparées sans réécrire leurs preuves.
- [x] La CI bloque les régressions de taille sur les artefacts construits.
- [x] Les mesures GUI locales passent ou leur blocage environnemental est
      consigné distinctement.
- [x] Les objectifs non mesurés restent explicitement `Not measured`.
- [x] Aucun statut de support plateforme n'est promu.
- [x] Documentation, index, état et Completion Report sont synchronisés.

## Automated validation

```powershell
pwsh -NoProfile -File .\tests\performance-budgets\run.ps1
pnpm performance:measure:bridge
pnpm performance:check -- `
  -FrontendMeasurementsPath .\artifacts\t0015\frontend-measurements.json `
  -DesktopMeasurementsPath .\artifacts\t0015\tauri-shell-measurements.json `
  -BridgeMeasurementsPath .\artifacts\t0015\bridge-measurements.json
pnpm frontend:typecheck
pnpm frontend:test
pnpm frontend:build
pnpm desktop:check
pnpm desktop:test
pnpm desktop:build
pnpm bridge:build
pnpm bridge:test
pnpm bridge:publish
pnpm ci:check
git diff --check
```

La campagne GUI complète utilise `pnpm frontend:measure` avant
`performance:check`. Un code 0 sans dix health checks ou sans les fichiers de
mesure attendus n'est pas une réussite.

## Manual verification

1. Relire les seuils et vérifier leurs unités.
2. Lancer la campagne frontend/desktop avec une fenêtre visible.
3. Lancer la mesure bridge puis le validateur global.
4. Abaisser temporairement un seuil dans une copie du JSON et confirmer l'échec.
5. Vérifier que le rapport distingue budgets automatisés et objectifs non
   mesurés.
6. Vérifier l'absence de processus Thrustline orphelin.

Temps cible : 20 minutes hors build propre et campagne GUI.

## Rollback

Abandonner la branche avant fusion. Après fusion, revenir par une PR ciblée qui
retire les scripts, la configuration et le gate CI. Ne jamais masquer une
régression en relevant un seuil pendant le rollback.

## Completion Report

### Summary

Une source JSON versionnée fixe les garde-fous de fondation. Un validateur
fail-closed contrôle les mesures et les artefacts construits ; un harnais couvre
un succès et quatre échecs attendus. La CI Windows applique les tailles après
build. Le bridge a été mesuré sur dix lancements.

### Files changed

- budgets : `eng/stability-performance-budgets.json` ;
- scripts : validateur, mesure bridge et durcissement du harness Tauri ;
- tests/CI : harnais T0015, invariants T0013 et workflow Windows ;
- documentation : benchmark, qualité, état, problèmes connus, index et ticket.

### Commands and results

- harnais T0015 : 1 scénario conforme et 4 mutations négatives réussis ;
- mesure bridge finale sous PowerShell 7.6.4 : 10/10, médiane 63,65 ms,
  maximum 73,5 ms ;
- publication bridge : 110 477 582 octets, 334 fichiers, sous 128 Mio ;
- gate artefacts : frontend 76 526 octets gzip, desktop 5 559 905 octets,
  bridge 110 477 582 octets, tous conformes ;
- frontend : typecheck, 8/8 tests et build réussis ;
- desktop : format, check, Clippy, 2/2 tests Rust, invariants, build Release
  réussis ;
- bridge : build sans avertissement, 13/13 tests et publication réussis ;
- harnais CI T0013 : dépôt et 2 mutations réussis ;
- `git diff --check` : réussi, avec avertissements LF/CRLF informatifs sur deux
  scripts existants.

Les premiers appels .NET ont échoué car le bac à sable refusait la lecture de
`NuGet.Config`; les mêmes commandes ont réussi avec cet accès autorisé. Le
lanceur PowerShell 7 WindowsApps a d'abord été refusé avant exécution dans le
bac à sable ; sa version 7.6.4 a ensuite été relevée et les contrôles T0015 ont
réussi avec son chemin explicite autorisé.

### Manual verification result

Les unités, marges et cibles `Not measured` ont été relues. Les scénarios
négatifs prouvent qu'un seuil abaissé échoue. Aucun processus Thrustline n'est
resté après les essais.

La campagne GUI complète n'est pas validée : un premier essai a été bloqué par
WMI, puis le binaire est sorti avec `-1073740791` dans la session d'outil avant
la mesure longue. Le harness refuse désormais une sortie avant 30/60 secondes
et l'absence de WebView2. `KI-020` conserve le constat sans trancher entre cause
produit et environnement ; une session Windows interactive stable est requise.

### Risks and limitations

- une seule machine et une seule famille d'environnement ;
- pas de profil minimum, MSFS réel, vol de quatre heures ou télémétrie bêta ;
- les timings GUI T0015 ne sont pas prouvés ; T0008 reste la dernière campagne
  complète ;
- les budgets détectent les régressions grossières mais ne prouvent pas
  l'expérience du MVP complet.

### Follow-ups

- relancer `pnpm frontend:measure` dans une session Windows interactive stable,
  puis le validateur avec les deux JSON ;
- mesurer le profil minimum et quatre heures lors du vertical slice ;
- remplacer les cibles `Not measured` avant bêta avec des preuves ;
- ne relever aucun seuil sans PR et mesure comparable.

### Documentation updated

`QUALITY`, `CURRENT_STATE`, `KNOWN_ISSUES`, benchmark T0015, index et ticket.

### Git and GitHub result

- branche : `foundation/t0015-stability-performance-budgets` ;
- base/head : `main` à `0817dfb` /
  `foundation/t0015-stability-performance-budgets` ;
- commit d'implémentation : `fd123cc` ;
- push : réussi, upstream
  `origin/foundation/t0015-stability-performance-budgets` ;
- PR brouillon : https://github.com/AndyD9/ThrustlineNG/pull/22 ;
- vérification restante : reproduire `KI-020` dans une session Windows
  interactive stable avant de demander la revue finale.
