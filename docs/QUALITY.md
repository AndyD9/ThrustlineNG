# Qualité du dépôt

## Toolchain et bootstrap

Depuis la racine, avec PowerShell 7.6 ou plus récent :

```powershell
pwsh -NoProfile -File .\scripts\check-toolchain.ps1
pwsh -NoProfile -File .\scripts\check-toolchain.ps1 -Json
pwsh -NoProfile -File .\tests\toolchain\run.ps1
pwsh -NoProfile -File .\scripts\bootstrap.ps1 -CheckOnly
```

Le harnais utilise un dépôt synthétique qui doit contenir tous les manifests lus
par `check-toolchain.ps1`. Toute extension du contrôle de pins doit mettre à jour
ce fixture et ajouter ou préserver un scénario d'échec associé.

## Backend Supabase

Le contrôle statique fonctionne sans Docker et couvre la version de CLI, la
configuration PostgreSQL 17, l'ordre migration/seed, les contraintes, les
politiques, les scénarios A/B/anonyme et l'absence de commande distante. Il
exécute aussi deux mutations négatives :

```powershell
pnpm backend:check
```

La preuve SQL réelle exige Docker Desktop ou un runtime Docker compatible
actif :

```powershell
pnpm backend:start
pnpm backend:reset
pnpm backend:test
pnpm backend:types:check
pnpm backend:stop
```

`backend:reset` inclut explicitement `--local`. `backend:test` doit découvrir
les deux fichiers pgTAP et conclure par `Result: PASS`; un code 0 sans test
découvert n'est pas une réussite. `backend:types:check` régénère les types en
mémoire et échoue si le fichier versionné diffère.

Preuve T0012 du 29 juillet 2026 sous Docker Desktop 29.6.2 : deux resets
successifs réussis, 2 fichiers pgTAP/21 tests avec résultat PASS, génération et
contrôle des types réussis. Le démarrage persistant reste en vérification :
Docker a publié les ports sur toutes les interfaces malgré le réseau loopback,
et le fail-safe de `backend:start` a arrêté la pile.

## Desktop et bridge

Le harnais bridge couvre le parsing strict, les jetons absents/incorrects, la
réponse REST versionnée et la négociation SignalR. Il couvre aussi les bornes des
échantillons, le replay synthétique, les offsets, les lignes surdimensionnées,
l'annulation, un faux adaptateur et l'absence de types SDK dans les contrats
publics. Les tests Rust vérifient les jetons et la sélection d'un port dynamique.

Depuis la racine :

```powershell
pnpm frontend:typecheck
pnpm frontend:test
pnpm frontend:coverage
pnpm frontend:build
pnpm desktop:check
pnpm desktop:test
pnpm desktop:build
pnpm frontend:measure
pnpm bridge:build
pnpm bridge:test
pnpm bridge:health
pnpm bridge:publish
```

Le typecheck active notamment `strict`, `noUncheckedIndexedAccess`,
`exactOptionalPropertyTypes`, les contrôles d'inutilisés et n'émet aucun
fichier. Vitest/jsdom couvre les routes, la navigation, l'error boundary,
l'action de rechargement, les landmarks, le focus, l'absence d'appel réseau et
les invariants HTML/CSS/Tauri. La couverture est une observation, sans seuil
arbitraire.

Le contrôle desktop combine le frontend, le format Rust, `cargo check --locked`,
Clippy avec les avertissements refusés, les tests Rust et les invariants Tauri.
Le build release est effectué sans bundle : packaging, signature et
installateur restent hors périmètre.

La mesure exige une fenêtre réellement visible, cinq lancements froids, cinq
lancements chauds et dix cycles de fermeture. Un échec de fenêtre ou un
processus orphelin rend le script non conforme.

Le bridge refuse les avertissements .NET et utilise nullable ainsi que les
analyseurs recommandés. Son harnais sans package tiers couvre les transitions de
santé, le diagnostic, les arguments invalides et l'annulation. La publication
produit un dossier self-contained `win-x64` ; single-file, trimming et AOT ne
sont pas activés sans mesure.

Une trace synthétique prouve le replay déterministe sans MSFS. Elle ne remplace
ni une trace enregistrée avec provenance, ni les fiches Store/Steam exigées par
ADR-0003.
