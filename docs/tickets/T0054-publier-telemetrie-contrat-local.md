# T0054 — Publier la télémétrie bornée du bridge sur le contrat local

Status: Review
Owner: Andy
Branch: `feature/T0054-bridge-telemetry-contract`
Phase: 3
Risk: High
Security-sensitive: Yes

## Goal

Diffuser les échantillons validés d'`ISimConnectAdapter` sur le contrat local
versionné du bridge, avec un débit borné et une mémoire bornée, sans les relier au
serveur, à l'économie ni à un état de vol persistant.

## Context

T0011 fournit `ISimConnectAdapter`, `FlightSample` borné, l'adaptateur natif et un
replay JSONL déterministe, mais la télémétrie reste déconnectée de REST et de
SignalR : `BridgeHub` est un hub vide. T0010 fournit le contrat local
`GET /api/v1/health`, `/hubs/v1/bridge`, le jeton d'instance
`X-Thrustline-Instance` et la liaison `127.0.0.1`.

Le gate de l'alpha jouable exige « connexion MSFS, suivi déterministe des phases
et télémétrie bornée ». Ce ticket livre uniquement le transport borné : la
détection de phases et la reprise sont la vague suivante du flux 1. Il n'exige ni
MSFS, ni SDK installé, puisque le replay synthétique doit rester la source de
preuve automatisée.

## Dependencies

- T0010 — contrat local, jeton d'instance et liaison loopback ;
- T0011 — adaptateur, domaine `FlightSample` et trace synthétique ;
- T0015 — budgets de stabilité et de performance à ne pas dégrader.

## Allowed areas

- `apps/bridge/` pour le hub, le service de diffusion, les options et le contrat ;
- `tests/bridge/` pour les nouveaux scénarios ;
- `tests/traces/` uniquement pour ajouter une trace synthétique bornée si un
  scénario l'exige ;
- `docs/ARCHITECTURE.md`, `docs/SECURITY.md`, `docs/QUALITY.md`,
  `docs/CURRENT_STATE.md` ;
- `eng/authority-inventory.json` si la surface du bridge change de classification ;
- ce ticket et `docs/tickets/README.md`.

## Do not touch

- backend Supabase, migrations, Edge Functions et grand livre ;
- desktop React, Rust/Tauri, CSP et capabilities ;
- `eng/stability-performance-budgets.json` et les seuils existants ;
- SDK SimConnect officiel, installation MSFS et détection de phases ;
- workflows, manifests, lockfiles, cible distante et données réelles.

## Requirements

### 1. Contrat versionné

- Étendre le contrat local sans casser `GET /api/v1/health` ni la négociation
  existante : la diffusion utilise `/hubs/v1/bridge` et un nom de message
  versionné explicite.
- Exiger le jeton d'instance sur la négociation et refuser une connexion sans
  jeton, avec un jeton incorrect ou hors loopback.
- Publier uniquement les champs de `FlightSample`, sans type SDK dans les
  contrats publics et sans champ métier, identifiant de compagnie ou de vol.
- Exposer l'état de la source par le health check existant ou un champ additif
  borné, sans divulguer de chemin de fichier, de version SDK ni de jeton.

### 2. Débit, mémoire et cycle de vie

- Limiter la diffusion à un échantillon par seconde au plus et conserver au plus
  le dernier échantillon en attente : aucun tampon non borné.
- Ne jamais bloquer la boucle de lecture de l'adaptateur à cause d'un abonné lent
  ou déconnecté.
- Sélectionner la source par option explicite, `replay` par défaut ; la source
  native reste facultative, n'est jamais requise en CI et échoue proprement si le
  SDK est absent.
- Arrêter la diffusion et libérer l'adaptateur à l'annulation, sans processus ni
  tâche résiduels.

### 3. Preuves

- Le harnais bridge couvre négociation autorisée et refusée, diffusion
  déterministe de la trace synthétique jusqu'au dernier échantillon, respect de
  la cadence, abandon d'un abonné lent, échantillon hors bornes rejeté,
  annulation propre et absence de type SDK dans les contrats publics.
- Le build .NET reste sans avertissement et les budgets de publication du bridge
  restent respectés.
- Aucun jeton, chemin utilisateur, télémétrie brute ou donnée personnelle n'est
  journalisé.

## Non-goals

- détecter les phases de vol, décollage, atterrissage, pause, slew ou crash ;
- persister, reprendre ou rejouer un vol après coupure ;
- envoyer quoi que ce soit à Supabase ou au grand livre ;
- consommer la télémétrie depuis le desktop ou la WebView ;
- prouver MSFS 2024 réel, le SDK installé ou un canal Store/Steam.

## Acceptance criteria

- [x] Un abonné local authentifié par le jeton d'instance reçoit les échantillons
      validés du replay synthétique, dans l'ordre et jusqu'au dernier.
- [x] Une négociation sans jeton, avec un mauvais jeton ou hors loopback est
      refusée.
- [x] La cadence est bornée, la file d'attente est bornée et un abonné lent ne
      retarde ni la lecture ni les autres abonnés.
- [x] La source native est optionnelle et son absence n'échoue jamais un test
      automatisé.
- [x] L'annulation libère l'adaptateur sans tâche ni processus résiduel.
- [x] Le build sans avertissement, le harnais bridge et les budgets applicables
      passent avec leurs compteurs réellement observés.

## Security review

- actifs : canal local, jeton d'instance, télémétrie de vol ;
- frontière : bridge non fiable lié au loopback → abonné local authentifié ;
- abus : abonnement sans jeton, écoute depuis une autre interface, saturation
  mémoire par abonné lent, fuite de chemin ou de version SDK dans une erreur ;
- validation/autorisation : jeton exigé à la négociation, liaison
  `127.0.0.1` inchangée, domaine `FlightSample` validé avant diffusion ;
- atomicité/idempotence : sans objet, flux non persistant ;
- logs/vie privée : aucun jeton, aucune trace brute et aucun chemin utilisateur
  journalisés.

## Maintenance review

- problèmes applicables : `KI-009` absence de corpus de traces réelles,
  `KI-015` publication self-contained du SDK non prouvée, `KI-011` canaux MSFS non
  validés ;
- dette créée : la source native reste non prouvée tant qu'aucun essai MSFS réel
  n'est réalisé ; à consigner explicitement ;
- règle de sécurité : le canal local reste authentifié par jeton d'instance et
  jamais exposé à la WebView ;
- contrôle manuel à automatiser : la cadence et l'absence de fuite mémoire
  doivent être couvertes par le harnais, pas par une observation ;
- risque résiduel : la télémétrie n'est pas encore consommée ni reprise après
  coupure.

## Automated validation

```powershell
pnpm.cmd bridge:build
pnpm.cmd bridge:test
pnpm.cmd bridge:health
pnpm.cmd bridge:publish
pnpm.cmd performance:check:build
pnpm.cmd authority:check
pnpm.cmd maintenance:check
git diff --check
```

## Manual verification

1. Publier le bridge, le lancer avec la source replay et relever son port et son
   jeton depuis le processus parent.
2. Ouvrir un abonné local avec le jeton, observer la cadence et le dernier
   échantillon, puis sans jeton.
3. Déconnecter brutalement l'abonné, confirmer que le bridge continue sans
   croissance mémoire anormale.
4. Annuler le processus et confirmer l'absence de processus ou de tâche résiduels.

Temps cible : 10 minutes.

## Rollback

Avant fusion, abandonner la branche. Après fusion, désactiver la source par son
option et retirer la diffusion dans un ticket correctif, sans modifier le contrat
`health` ni le jeton d'instance.

## Completion Report

Branche : `feature/T0054-bridge-telemetry-contract`, créée depuis
`origin/main` au commit `6bfab7a` (merge de la PR #97). Aucune branche empilée.

### Summary

`TelemetryPublisher` devient l'unique autorité de publication du bridge. Il
n'ouvre la source qu'à l'arrivée du premier abonné, revalide chaque
`FlightSample` avant diffusion, borne la lecture à un échantillon par seconde au
plus et ne conserve qu'un seul échantillon en attente par abonné, dans un canal
`DropOldest` : un abonné lent perd les échantillons intermédiaires sans retarder
la lecture ni les autres abonnés, et un envoi qui dépasse le délai borné
abandonne l'abonné puis annule sa connexion.

`BridgeHub` inscrit chaque connexion authentifiée comme abonné et publie le
message versionné `telemetry.v1` sur `/hubs/v1/bridge`. Le health check garde
`contractVersion` et `status`, et ajoute `telemetrySource` et `telemetryState`
sans divulguer chemin de trace, version de SDK ni jeton. La source est choisie
par `--telemetry-source replay|native` avec `--telemetry-trace <fichier>` ;
`replay` reste le défaut et, sans trace, l'état reste `idle` sans rien publier,
ce qui laisse inchangé le lancement actuel par Tauri avec `--port` seul. La
cadence et le délai d'envoi ne sont pas configurables en ligne de commande.

### Files changed

- `apps/bridge/Telemetry/BridgeTelemetryOptions.cs` — source, état, options
  bornées et parsing des valeurs de source et de trace ;
- `apps/bridge/Telemetry/ITelemetrySink.cs` — frontière d'envoi par abonné ;
- `apps/bridge/Telemetry/TelemetryPublisher.cs` — cadence, validation, slot d'un
  échantillon par abonné, abandon d'un abonné bloqué et libération de la source ;
- `apps/bridge/Telemetry/TelemetryAdapterFactory.cs` — résolution de la source
  replay ou native, sans source par défaut ;
- `apps/bridge/Telemetry/SignalRTelemetrySink.cs` — envoi ciblé et annulation
  d'une connexion abandonnée ;
- `apps/bridge/Telemetry/TelemetryPublicationService.cs` — cycle de vie hôte ;
- `apps/bridge/BridgeHub.cs` — inscription et retrait d'un abonné ;
- `apps/bridge/BridgeContract.cs` — nom de message `telemetry.v1` ;
- `apps/bridge/BridgeServer.cs` — enregistrement du publieur, protocole JSON
  camelCase et champs additifs du health check ;
- `apps/bridge/BridgeOptions.cs`, `apps/bridge/BridgeApplication.cs` — arguments
  de télémétrie et usage ;
- `apps/bridge/SimConnect/FlightSample.cs` — `IsWithinDomain()` réutilisé par la
  fabrique et par la diffusion ;
- `tests/bridge/Program.cs` — 12 nouveaux scénarios, `TimeProvider` manuel,
  adaptateurs et puits de test, abonné WebSocket parlant le protocole JSON du hub ;
- `docs/ARCHITECTURE.md`, `docs/SECURITY.md`, `docs/QUALITY.md`,
  `docs/CURRENT_STATE.md` — architecture, contrôles, preuves et état ;
- `eng/authority-inventory.json` — limite `flight-runtime` rendue exacte, sans
  changement de classification ;
- ce ticket et `docs/tickets/README.md`.

### Commands and results

Le 4 août 2026, sous Windows 11 Pro 26200, .NET SDK 10.0.201, depuis la racine :

- `pnpm.cmd bridge:build` — réussi, 0 avertissement, 0 erreur ;
- `pnpm.cmd bridge:test` — réussi, `25/25 tests passed`, trois exécutions
  consécutives identiques ;
- `pnpm.cmd bridge:health` — réussi, sortie `Healthy` ;
- `pnpm.cmd bridge:publish` — réussi, publication self-contained `win-x64` ;
- `pnpm.cmd performance:check:build` — réussi, `built artifact sizes` ;
- `pnpm.cmd authority:check` — réussi, 10 étapes, 13 domaines, 3 surfaces,
  9 scénarios de mutation ;
- `pnpm.cmd maintenance:check` — réussi, registre, index, marqueurs de dette et
  8 scénarios de mutation ;
- `git diff --check` — aucune anomalie.

### Manual verification result

Terminée le 4 août 2026 sur cette machine, sans MSFS, avec le bridge publié
`apps/bridge/bin/Release/net10.0/win-x64/publish/Thrustline.Bridge.exe`, la
trace synthétique et un processus parent qui réserve le port, génère le jeton et
l'écrit sur stdin. Deux exécutions, la seconde lisant la trace entière :

1. `BRIDGE_READY 1 52413` puis health
   `{"contractVersion":"1","status":"healthy","telemetrySource":"replay","telemetryState":"idle"}` ;
2. abonné sans jeton refusé — `The server returned status code '401' when status
   code '101' was expected` ; abonné authentifié recevant les huit échantillons
   dans l'ordre `0` à `7`, intervalles observés de 990, 1003, 1012, 1011, 1014,
   1013 et 1013 ms, dernier échantillon au sol à 629 ft, état `completed` ;
3. déconnexion brutale sans trame de fermeture — bridge vivant, health toujours
   `healthy`, working set de 54 194 176 à 52 965 376 octets, et un nouvel abonné
   négocie encore ; la première exécution, coupée après trois échantillons,
   montre 53 055 488 à 53 350 400 octets pendant que la diffusion continue ;
4. `Ctrl+C` sur le groupe console — code de sortie `0`, `stderr` vide et zéro
   processus `Thrustline.Bridge` résiduel.

Le harnais de vérification est un utilitaire jetable hors dépôt ; il n'ajoute
aucun fichier au dépôt.

### Risks and limitations

- la source native reste non prouvée : aucun essai MSFS 2024 réel n'a été
  réalisé, `KI-009`, `KI-011` et `KI-015` restent ouverts ;
- la preuve de cadence automatisée repose sur un `TimeProvider` manuel ; la
  cadence réelle n'est observée qu'à la vérification manuelle ;
- l'absence de croissance mémoire est observée sur quelques secondes, pas sur la
  campagne de quatre heures encore `Not measured` de T0015 ;
- la télémétrie n'est ni persistée, ni reprise après coupure, ni consommée par le
  desktop ; aucun échantillon n'est relié à une compagnie, un vol ou le grand
  livre ;
- un abandon d'abonné n'est pas journalisé, par choix de confidentialité : il est
  seulement observable par la fermeture de la connexion ;
- la mémoire est bornée par abonné, mais le nombre d'abonnés simultanés n'est pas
  plafonné par une option : il reste borné par le jeton d'instance, la liaison
  loopback et les limites du serveur.

### Follow-ups

- détection déterministe des phases de vol et reprise après coupure, vague
  suivante du flux 1 ;
- consommation de `telemetry.v1` par le desktop, hors périmètre ici ;
- premier slice SimConnect réel et corpus de traces avec provenance, qui fermera
  `KI-009` et lèvera la dette de la source native.

### Documentation updated

`docs/ARCHITECTURE.md`, `docs/SECURITY.md`, `docs/QUALITY.md`,
`docs/CURRENT_STATE.md`, `eng/authority-inventory.json`, ce ticket et
`docs/tickets/README.md`.
