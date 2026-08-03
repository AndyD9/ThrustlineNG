# T0054 — Publier la télémétrie bornée du bridge sur le contrat local

Status: Ready
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

- [ ] Un abonné local authentifié par le jeton d'instance reçoit les échantillons
      validés du replay synthétique, dans l'ordre et jusqu'au dernier.
- [ ] Une négociation sans jeton, avec un mauvais jeton ou hors loopback est
      refusée.
- [ ] La cadence est bornée, la file d'attente est bornée et un abonné lent ne
      retarde ni la lecture ni les autres abonnés.
- [ ] La source native est optionnelle et son absence n'échoue jamais un test
      automatisé.
- [ ] L'annulation libère l'adaptateur sans tâche ni processus résiduel.
- [ ] Le build sans avertissement, le harnais bridge et les budgets applicables
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

À remplir après implémentation.

### Summary

### Files changed

### Commands and results

### Manual verification result

### Risks and limitations

### Follow-ups

### Documentation updated
