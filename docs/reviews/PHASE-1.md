# Revue de phase — Phase 1

Date: 30 juillet 2026
Participants: Codex (collecte et revue adversariale), Andy (décision par revue et
fusion de la Pull Request)
Result: Conditional

## Outcomes delivered

- Le nouveau dépôt possède un historique neuf, une branche `main` et un workflow
  de branches courtes avec revue obligatoire.
- Node, pnpm, Rust, .NET et PowerShell sont épinglés depuis
  `eng/versions.json`, avec des pins natifs cohérents et un bootstrap
  idempotent.
- Le shell Tauri, le frontend React, le bridge .NET et leur contrat local
  authentifié sont construits et testés depuis les lockfiles.
- Supabase CLI et PostgreSQL 17 sont configurés avec migration append-only,
  seeds synthétiques, RLS forcée, pgTAP et types versionnés.
- La CI Windows/Linux, les audits de dépendances, le scan de secrets, les
  licences et le SBOM sont obligatoires et utilisent des actions épinglées.
- Les budgets de fondation, la politique de données et le packaging Windows non
  signé possèdent des gates reproductibles.

## Gate evidence

Le gate de sortie est :

```text
clone propre → setup → tests/build sans étape secrète non documentée
```

Preuves :

- T0006 a cloné la branche distante `main` au commit `c9966e2` sur Windows 11
  x64, vérifié 17 contrôles de versions, exécuté `CheckOnly`, puis deux
  bootstraps idempotents ; le clone est resté sans diff.
- Le même clone a réussi les 15 assertions toolchain, le typecheck, 8 tests et
  le build frontend, le check, 3 tests Rust et le build Tauri Release, ainsi que
  le build, 13 tests et le health check du bridge.
- Les contrôles statiques backend, politique de données, CI, budgets et
  packaging ont réussi avec leurs mutations négatives.
- T0013 a prouvé sur GitHub le backend réel PostgreSQL 17 sous Linux : liaison
  loopback effective, deux resets, 2 fichiers pgTAP et 21 tests, types stables
  et arrêt garanti, sans secret applicatif.
- Les runs de la PR #28 sur l'état final de phase 1 sont verts : Windows
  multi-stack `30573555986` en 14 min 29 s, Supabase PostgreSQL 17 dans le même
  run en 2 min 34 s et supply chain `30573555980` en 3 min 46 s.

Conclusion : le parcours du gate est démontré par la combinaison du clone propre
Windows et de la CI backend Linux. Aucun secret applicatif ni étape manuelle
cachée n'est nécessaire aux tests et builds automatisés.

## Stability and security

- Le desktop ne donne aucun secret à la WebView et lance le bridge avec un jeton
  éphémère de 256 bits.
- Le bridge écoute uniquement sur `127.0.0.1`, exige le jeton et valide ses
  entrées REST/SignalR.
- Le démarrage Supabase Windows inspecte les ports réels, masque les credentials,
  arrête la pile et échoue si Docker publie hors loopback.
- La CI restaure depuis les lockfiles, ne conserve pas les credentials checkout,
  possède uniquement `contents: read` et n'effectue aucune release.
- L'admission de données utilisateur réelles reste bloquée. Local et CI
  n'utilisent que des données synthétiques.

## Deferred work

Ces éléments restent ouverts sans invalider le gate de reproductibilité :

- T0007 : checklist interactive complète et scénario WebView2 absent sur VM ;
- T0008 : focus, zoom 200 %, réduction des animations et inspection
  console/réseau ;
- T0009 : Ctrl+C depuis une console Windows native ;
- T0011 : essais MSFS 2024 réels Store/Xbox App et Steam, attendus pour la
  phase 3 et la promotion des canaux ;
- T0012 / `KI-017` : Docker Desktop 29.6.2 publie Supabase hors loopback sur la
  machine Windows ; le fail-safe reste obligatoire et le ticket reste
  `Verify` ;
- `KI-019` : dépendances GTK3 non maintenues dans le lockfile Cargo
  multi-plateforme ;
- signature, provenance, updater, upgrade N-1 et rollback, prévus en phase 6.

Aucun de ces écarts ne doit être requalifié en réussite. Ils conservent leur
ticket et leur statut actuels.

## Metrics

- Toolchain : 17 contrôles conformes et 15 assertions de harnais.
- Frontend : 3 fichiers, 8 tests.
- Desktop : 3 tests Rust et invariants Tauri conformes.
- Bridge : 13 tests, build sans avertissement et health check `Healthy`.
- Backend : 2 fichiers pgTAP, 21 tests, deux resets et types stables en CI.
- Packaging : 4 cycles manuels complets sans processus ni résidu.
- Supply chain : audit pnpm vert, aucun package NuGet vulnérable, aucune
  vulnérabilité Cargo connue, scan de secrets vert et SBOM produit.

## What worked

- Les pins et lockfiles ont rendu le clone propre reproductible.
- Les mutations négatives ont détecté de vrais défauts de CI, packaging et
  politique de données avant promotion.
- Les contrôles fail-closed ont empêché de présenter une pile Supabase exposée
  comme sûre.
- La séparation entre preuve locale, preuve GitHub et vérification humaine a
  évité plusieurs faux succès.

## What caused friction

- PowerShell 7 était installé sous `WindowsApps` mais absent du `PATH` sandboxé.
- Les caches utilisateur NuGet/Cargo/pnpm ont nécessité un accès explicitement
  autorisé sans modifier les pins.
- Windows PowerShell 5.1 ne pouvait pas charger certaines commandes
  Authenticode/hash dans le runner ; les scripts utilisent désormais les API
  .NET correspondantes.
- Docker Desktop n'a pas respecté la liaison loopback demandée sous Windows.
- Les branches initialement empilées ont nécessité une réconciliation
  d'ascendance avant de distinguer code fusionné et statut documentaire.

## Workflow changes justified

Aucune nouvelle règle globale n'est ajoutée par cette revue. Les apprentissages
reproductibles concernant PowerShell, les faux succès de test, les branches
empilées et les preuves environnementales sont déjà encodés dans `AGENTS.md`,
`WORKFLOW.md`, `QUALITY.md` ou `LEARNINGS.md`.

## Decision for next phase

La phase 1 obtient un **passage conditionnel**. La phase 2 peut démarrer après
fusion de cette revue, sous les conditions suivantes :

1. aucune donnée utilisateur réelle n'est admise ;
2. T0012 reste `Verify` et son fail-safe loopback n'est jamais contourné ;
3. toute migration ou commande SQL de phase 2 possède des tests
   A/B/anonyme/idempotence exécutés sur la pile locale CI PostgreSQL 17 ;
4. les vérifications T0007–T0011 continuent séparément et ne sont pas fermées
   par cette décision ;
5. le premier ticket détaillé de phase 2 traite l'export et la suppression de
   compte transactionnels/idempotents avant toute admission de données réelles.

Cette décision n'active ni production, ni staging, ni support MSFS, ni
distribution publique.
