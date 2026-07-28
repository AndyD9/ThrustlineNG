# T0010 — Établir le contrat local et le health check

Status: Done
Owner: Andy
Branch: `foundation/t0010-local-contract`
Phase: 1
Risk: High
Security-sensitive: Yes

## Goal

Lancer et superviser le bridge depuis Tauri et fournir un contrat local
REST/SignalR versionné, limité à loopback et authentifié par instance.

## Context

T0009 fournit le cycle de vie .NET sans réseau. T0010 ouvre la première frontière
inter-processus ; elle doit rester inaccessible sans le jeton créé par Tauri.

## Dependencies

- T0007 à T0009.
- ADR-0004, architecture et sécurité du dépôt.

## Allowed areas

- `apps/bridge/`, `tests/bridge/`, `apps/desktop/src-tauri/`.
- manifests, lockfiles et documentation concernés.

## Do not touch

- frontend React et capabilities WebView.
- SimConnect, Supabase, logique métier et packaging final.
- écoute autre que loopback ou stockage du jeton.

## Requirements

- Contrat `v1` : `GET /api/v1/health` et `/hubs/v1/bridge`.
- Liaison à `127.0.0.1` sur un port dynamique 49152–65535.
- Jeton aléatoire de 256 bits transmis par pipe stdin anonyme, exigé via
  `X-Thrustline-Instance`, comparé en temps constant et jamais journalisé.
- Refus des arguments, ports et jetons invalides avant écoute.
- Tauri lance un enfant et le termine avec la fenêtre.
- `THRUSTLINE_BRIDGE_PATH` est permis uniquement en développement.
- Aucune commande WebView et aucune origine CSP ajoutée.

## Non-goals

- Client frontend, reconnexion avancée, SimConnect, données et packaging final.

## Acceptance criteria

- [x] REST et négociation SignalR sont disponibles sur loopback.
- [x] Le health check retourne le contrat `1` et `healthy`.
- [x] Les jetons absents ou incorrects retournent `401`.
- [x] Ports privilégiés, jetons faibles et arguments inconnus sont refusés.
- [x] Tauri génère un jeton de 256 bits et supervise l'enfant.
- [x] Le jeton n'est exposé ni au frontend ni aux logs.
- [x] Toutes les validations automatisées passent.
- [x] Le parcours Tauri réel est vérifié.
- [x] Documentation et Completion Report sont synchronisés.

## Security review

- actifs : jeton d'instance et disponibilité ; aucune donnée métier.
- frontière : Tauri vers HTTP loopback.
- abus : scan de port, processus local hostile et fuite log.
- contrôle : jeton 256 bits sur chaque requête et négociation.
- logs : providers ASP.NET supprimés et messages constants.

## Automated validation

```powershell
dotnet build .\ThrustlineNG.slnx --configuration Release
dotnet run --project .\tests\bridge\Thrustline.Bridge.Tests.csproj --configuration Release --no-build
dotnet publish .\apps\bridge\Thrustline.Bridge.csproj --configuration Release --runtime win-x64 --self-contained true
pnpm frontend:typecheck
pnpm frontend:test
pnpm desktop:check
pnpm desktop:test
pnpm desktop:build
git diff --check
```

## Manual verification

1. Publier le bridge et fournir son chemin au desktop de développement.
2. Lancer Tauri et confirmer l'écoute loopback et le health check.
3. Fermer la fenêtre et confirmer l'absence de processus restant.

## Rollback

Abandonner la branche ; aucune donnée persistante n'est créée.

## Completion Report

### Summary

Le bridge expose un contrat local v1 REST/SignalR authentifié. Tauri génère le
jeton d'instance, sélectionne le port, lance le processus et le récolte à la
fermeture.

### Files changed

- bridge : options strictes, contrat, serveur ASP.NET Core et hub vide ;
- desktop Rust : génération du jeton et supervision ;
- tests bridge et documentation du contrat.

### Commands and results

- `dotnet build ... Release` : réussi, 0 avertissement/erreur ;
- harnais bridge : 5/5 réussis ;
- publication self-contained `win-x64` : réussie ;
- `cargo fmt --check`, `cargo check --locked`, Clippy `-D warnings` : réussis ;
- tests Rust : 2/2 réussis ;
- restauration figée avec Node `24.18.0` et pnpm `11.17.0` : réussie ;
- frontend : typecheck, 8/8 tests, couverture et build Vite réussis ;
- desktop : check, Clippy, 2/2 tests Rust, invariants et build Release réussis.

### Manual verification result

REST, authentification et négociation SignalR ont été exercés sur un vrai port
loopback par le harnais. Le desktop Release a ensuite été lancé avec le bridge
publié comme binaire frère : un unique processus bridge a démarré, puis la
fermeture de la fenêtre a arrêté les deux processus sans orphelin.

### Risks and limitations

- La réservation puis réutilisation du port comporte une courte course locale ;
  le jeton empêche toutefois l'accès non authentifié.
- Le processus n'est pas encore relancé après crash.
- Le packaging du binaire frère reste à T0014.

### Follow-ups

- T0011 : adaptateur SimConnect et replays.
- Ajouter la récupération bornée du bridge dans un ticket dédié si le vertical
  slice démontre le besoin avant T0011.

### Documentation updated

`ARCHITECTURE`, `SECURITY`, `QUALITY`, `SETUP`, `CURRENT_STATE`, backlog et ticket.
