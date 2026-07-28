# T0009 — Créer le bridge .NET minimal

Status: Done
Owner: Andy
Branch: `foundation/t0009-dotnet-bridge`
Phase: 1
Risk: Medium
Security-sensitive: Yes

## Goal

Fournir un processus bridge .NET 10 minimal, testable et publiable en
self-contained `win-x64`, avec diagnostic de santé local et arrêt propre, sans
ouvrir encore de frontière réseau ou Tauri.

## Context

ADR-0004 retient un bridge .NET 10 LTS self-contained. T0009 pose uniquement le
cycle de vie du processus. T0010 possédera le lancement par Tauri,
l'authentification d'instance et le contrat REST/SignalR.

Le « health check » de T0009 est donc un diagnostic de processus
`--health-check`, sans port, protocole, donnée ni compatibilité promise à un
consommateur externe.

## Dependencies

- T0006 — toolchains et source de versions.
- `docs/decisions/ADR-0004-stack-cible.md`.
- `global.json` et `eng/versions.json`.

## Allowed areas

- `apps/bridge/`.
- `tests/bridge/`.
- solution et configuration .NET à la racine.
- scripts npm racine liés au bridge.
- documentation d'architecture, qualité, sécurité, setup et état.
- ce ticket et `docs/tickets/README.md`.

## Do not touch

- `legacy/`.
- frontend ou code Rust/Tauri.
- capabilities, plugins ou commandes IPC Tauri.
- HTTP, SignalR, socket, port local ou authentification d'instance.
- SimConnect et logique de vol.
- Supabase, données métier ou secrets.
- packaging Tauri, signature ou updater.

## Requirements

- Cibler exactement `net10.0` avec le SDK épinglé par `global.json`.
- Refuser les avertissements, activer nullable et les analyseurs recommandés.
- N'ajouter aucun package NuGet tiers.
- Verrouiller la restauration et publier sans runtime .NET installé.
- Exposer `--health-check`, écrire `Healthy` et retourner le code `0`.
- Rejeter un argument inconnu avec une aide non sensible et le code `2`.
- Sans argument, annoncer l'état prêt puis attendre une annulation.
- Intercepter Ctrl+C et la sortie du processus, puis terminer avec le code `0`.
- Séparer la logique du point d'entrée pour tester santé, erreurs et arrêt.
- Ne jamais lire de configuration, secret, fichier utilisateur ou réseau.

## Non-goals

- Service Windows.
- Lancement ou supervision par Tauri.
- REST, SignalR, WebSocket ou authentification.
- Logs structurés et observabilité distante.
- SimConnect, replay ou rapport de vol.
- Mesure de performance et budget définitif.
- Exécutable unique, trimming ou Native AOT.

## Acceptance criteria

- [x] La branche est `foundation/t0009-dotnet-bridge`.
- [x] Le projet cible .NET 10 et compile en Release sans avertissement.
- [x] La restauration possède des lockfiles et aucun package tiers.
- [x] Le processus normal attend une annulation et s'arrête proprement.
- [x] Le diagnostic retourne `Healthy`/`0`.
- [x] Un argument inconnu retourne une aide sûre et le code `2`.
- [x] Les quatre scénarios unitaires passent.
- [x] La publication self-contained `win-x64` réussit.
- [x] Aucun réseau, IPC, SimConnect, secret ou donnée métier n'est introduit.
- [x] La documentation et l'état du dépôt sont synchronisés.

## Security review

- actifs/données : processus local uniquement, aucune donnée.
- frontière : ligne de commande locale ; aucune écoute réseau.
- abus : arguments inattendus refusés, aucune valeur recopiée dans la sortie.
- validation/autorisation : aucune opération privilégiée ou métier.
- atomicité/idempotence : le diagnostic est sans effet ; l'arrêt est répétable.
- logs/vie privée : deux messages constants, sans stack, chemin ou secret.

## Automated validation

```powershell
dotnet build .\ThrustlineNG.slnx --configuration Release
dotnet run --project .\tests\bridge\Thrustline.Bridge.Tests.csproj `
  --configuration Release --no-build
dotnet publish .\apps\bridge\Thrustline.Bridge.csproj `
  --configuration Release --runtime win-x64 --self-contained true
pnpm bridge:health
git diff --check
```

## Manual verification

1. Exécuter le binaire publié avec `--health-check` et confirmer `Healthy`/`0`.
2. L'exécuter avec `--unknown` et confirmer l'aide sur stderr/code `2`.
3. Lancer sans argument, confirmer le message prêt, puis envoyer Ctrl+C.
4. Confirmer le message d'arrêt et l'absence de processus restant.

Temps cible : 5 minutes.

## Rollback

Abandonner la branche avant fusion. Après fusion et avant T0010, revenir au
commit précédent ; aucune donnée ni configuration utilisateur n'est créée.

## Completion Report

### Summary

Un bridge console .NET 10 minimal est disponible. Il possède un état de santé
en mémoire, un diagnostic local, un cycle de vie annulable et une publication
self-contained Windows x64.

### Files changed

- `apps/bridge/` : application, santé et lockfile.
- `tests/bridge/` : harnais unitaire sans dépendance tierce et quatre scénarios.
- `Directory.Build.props`, `NuGet.Config`, `ThrustlineNG.slnx`, `package.json`.
- documentation d'architecture, sécurité, qualité, setup, état et backlog.

### Commands and results

- premier `dotnet build` : accès sandbox à NuGet.Config refusé avant compilation.
- build autorisé : deux erreurs détectées puis corrigées (`CA1068`,
  `NETSDK1151`).
- restauration verrouillée initiale : référence projet ajoutée avec
  `--force-evaluate`.
- `dotnet build ... Release` : réussi, 0 avertissement, 0 erreur.
- harnais unitaire : 4/4 réussis.
- `dotnet publish ... --self-contained true` : réussi.
- binaire publié `--health-check` : `Healthy`, code `0`.
- binaire publié `--unknown` : aide sûre, code `2`.
- gates frontend : typecheck, 8 tests et build Vite réussis.
- gates desktop : format/check/Clippy, tests/invariants et build Tauri Release
  réussis.

### Manual verification result

Les modes santé et erreur du binaire publié ont été exécutés réellement. Le
processus normal a aussi affiché son état prêt. Le terminal PTY utilisé n'a pas
converti l'injection de Ctrl+C en signal Windows ; l'instance précisément
identifiée a été arrêtée et l'absence de processus restant confirmée. Le chemin
d'annulation a été vérifié automatiquement avec un délai de deux secondes.
L'envoi Ctrl+C depuis une console Windows native est délégué à la revue.

### Risks and limitations

- Le bridge ne communique encore avec aucun consommateur.
- La publication contient 191 fichiers et environ 80,5 Mo ; aucun budget n'est
  fixé avant T0015.
- L'arrêt `ProcessExit` dépend du délai accordé par l'OS ; aucune persistance
  n'existe dans ce ticket.

### Follow-ups

- T0010 : contrat local authentifié, lancement/supervision et health check
  consommable par Tauri.
- T0011 : abstraction SimConnect et replays.

### Documentation updated

`ARCHITECTURE`, `SECURITY`, `QUALITY`, `SETUP`, `CURRENT_STATE` et le backlog.

### Git and GitHub result

À compléter après commit, push et création de la Pull Request.
