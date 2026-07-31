# T0021 — Isoler Supabase local sur Windows

Status: Review
Owner: Codex
Branch: `fix/T0021-windows-supabase-loopback`
Phase: 1–2
Risk: High
Security-sensitive: Yes

## Goal

Permettre l'exécution locale de Supabase sur Docker Desktop 29.6.2 sans publier
API, PostgreSQL ou Studio au-delà de `127.0.0.1`, puis fermer `KI-017` avec une
preuve Windows reproductible.

## Context

Le démarrage T0012 crée un réseau dont
`com.docker.network.bridge.host_binding_ipv4=127.0.0.1`, puis arrête correctement
la pile si Docker publie malgré tout sur une adresse wildcard. Le 31 juillet
2026, Docker Desktop 29.6.2 a reproduit cet écart sur les trois ports Supabase et
sur un conteneur témoin indépendant. `HostConfig.PortBindings` contient un
`HostIp` vide, conformément à la CLI Supabase 2.109.1, et le moteur publie alors
sur `0.0.0.0` et `[::]` même avec l'option du réseau et l'option daemon par
défaut.

La correction confine la pile dans un moteur Docker-in-Docker dédié. Les ports
wildcard de la pile interne restent dans ce moteur ; le moteur externe ne
publie vers Windows que des liaisons explicites `127.0.0.1`. La CLI isolée ne
reçoit ni socket Docker hôte ni montage du dépôt complet : seuls les fichiers
`supabase/` synthétiques sont copiés dans un volume dédié.

## Dependencies

- T0012 — pile locale, commandes et contrôle fail-safe (`Verify`) ;
- T0018–T0020 — scénarios backend empilés à revalider localement (`Verify`) ;
- Docker Desktop 29.6.2 actif sur Windows 11.

## Allowed areas

- `scripts/start-supabase-local.ps1`, `scripts/invoke-supabase-local.ps1`,
  `scripts/generate-database-types.ps1` et nouveaux helpers/Containerfile du
  runtime local ;
- `tests/backend/run.ps1` ;
- `docs/QUALITY.md`, `docs/SETUP.md`, `docs/SECURITY.md`,
  `docs/CURRENT_STATE.md`, `docs/KNOWN_ISSUES.md` ;
- tickets T0012, T0018, T0019 et T0020 uniquement pour consigner les nouvelles
  preuves sans antidater leur vérification manuelle ;
- ce ticket et `docs/tickets/README.md`.

## Do not touch

- `supabase/migrations/`, `supabase/tests/`, `supabase/seed.sql` et types
  versionnés hors régénération de contrôle ;
- `apps/desktop/`, `apps/bridge/`, SimConnect et contrat local ;
- workflows GitHub, toolchain applicative, lockfile et dépendances du produit ;
- projet Supabase distant, staging, production, secrets ou données réelles ;
- configuration globale Docker Desktop, pare-feu Windows ou réseau de la
  machine.

## Requirements

- Publier 54321, 54322 et 54323 sur l'IPv4 loopback explicite, sans wildcard
  IPv4 ou IPv6 sur Windows.
- Isoler le daemon de la pile du socket Docker hôte et ne pas publier son API.
- Désactiver explicitement la télémétrie de la CLI isolée.
- Exposer à la CLI conteneurisée uniquement une copie des sources `supabase/`
  dans un volume local dédié.
- Épingler les images par version et digest, et vérifier l'intégrité du binaire
  Supabase Linux contre le lockfile existant.
- Conserver les commandes `backend:start/reset/test/types/stop`, leurs cibles
  locales explicites et l'arrêt fail-safe.
- Nettoyer les conteneurs et réseaux partiels après un échec sans toucher aux
  autres ressources Docker ; un arrêt normal peut conserver uniquement un
  volume de cache d'images sans source ni donnée de projet.

## Non-goals

- corriger Docker Desktop ou Supabase CLI en amont ;
- modifier une configuration Docker ou pare-feu globale ;
- admettre des données réelles ou prouver la parité Supabase managée ;
- modifier les migrations, règles RLS ou capacités métier T0018–T0020 ;
- fermer une checklist humaine qui n'a pas été réellement exécutée.

## Acceptance criteria

- [x] `backend:start` laisse une pile accessible sur `127.0.0.1` et aucune
      publication `0.0.0.0`, `[::]` ou adresse non-loopback.
- [x] Le daemon isolé n'expose ni socket hôte ni port Docker API sur Windows.
- [x] Deux resets, tous les pgTAP découverts et le contrôle des types passent
      sur PostgreSQL 17 local.
- [x] `backend:stop` retire uniquement les ressources actives T0021 et aucun
      conteneur Supabase ne reste actif ; seul le cache d'images dédié subsiste.
- [x] Le harnais détecte la suppression d'une liaison loopback ou l'ajout d'un
      montage du dépôt complet/socket Docker hôte.
- [x] KI-017 et les documents de setup/qualité reflètent les preuves réelles.

## Security review

- actifs/données : sources SQL synthétiques, base locale jetable et ports
  PostgreSQL/API/Studio ;
- frontière : Windows vers moteur Docker externe, puis daemon DinD et pile
  Supabase interne ;
- abus : accès LAN, exposition de l'API Docker, montage du dépôt complet,
  persistance d'une pile partielle ou confusion avec un projet distant ;
- validation/autorisation : liaisons `127.0.0.1` explicites, noms/labels dédiés,
  commandes `--local`, inventaire des ports et arrêt fail-safe ;
- atomicité/idempotence : création convergente des ressources dédiées et
  nettoyage borné après échec ;
- logs/vie privée : sortie de démarrage masquée, aucune clé locale, variable
  d'environnement ou donnée réelle consignée.

## Automated validation

```powershell
pnpm backend:check
pnpm backend:start
pnpm backend:reset
pnpm backend:reset
pnpm backend:test
pnpm backend:types:check
pnpm backend:stop
git diff --check
```

## Manual verification

1. Inspecter les publications Docker et les écouteurs Windows des ports
   54321–54323.
2. Ouvrir Studio sur `http://127.0.0.1:54323` et confirmer que seules les
   identités synthétiques existent.
3. Exécuter les checklists backend T0012 et T0020 sans requalifier les preuves
   automatisées en contrôle humain.
4. Arrêter, confirmer l'absence de ressources résiduelles, redémarrer puis
   rejouer un reset.

Temps cible : 15 minutes hors premier téléchargement des images isolées.

## Rollback

Avant fusion, abandonner la branche. Pour une pile T0021 active, exécuter
`pnpm backend:stop`; le nettoyage reste borné aux conteneurs, réseau et volumes
nommés par le runtime Thrustline local. Ne supprimer aucune ressource Docker
étrangère au ticket.

## Completion Report

### Summary

Implémentation et preuve réseau terminées le 31 juillet 2026. Supabase s'exécute
dans un daemon Docker-in-Docker dédié ; Docker externe republie API, PostgreSQL
et Studio uniquement sur `127.0.0.1`. La CLI ne reçoit ni socket Docker hôte ni
dépôt complet. `KI-017` passe à `Resolved`. Andy confirme l'inspection visuelle
de Studio le 31 juillet 2026 ; le ticket passe à `Review` sur sa PR empilée.

### Files changed

- nouveau Containerfile CLI et helper de runtime isolé sous `scripts/` ;
- commandes start/reset/test/types/stop adaptées au daemon dédié ;
- harnais backend renforcé avec sept mutations négatives ;
- documentation setup, sécurité, qualité, état, problème connu et suivi.

### Commands and results

- diagnostic Docker Desktop 29.6.2 — l'option réseau et l'option daemon
  loopback sont ignorées pour un `HostIp` vide ; reproduction Supabase et
  conteneur témoin réussie, puis nettoyage à zéro conteneur ;
- construction de `thrustline/supabase-cli:2.109.1-t0021.2` — réussie depuis un
  contexte vide ; binaire Linux vérifié contre le SHA-512 du lockfile ;
- `pnpm backend:start` — réussi, premier remplissage du cache en 204,2 s ;
- inspection `docker port`, `docker inspect` et `Get-NetTCPConnection` — trois
  liaisons et trois sockets `127.0.0.1:54321–54323`, aucun wildcard Windows ;
- deux `pnpm backend:reset` — réussis, quatre migrations et seed rejoués ;
- `pnpm backend:test` — réussi, 8 fichiers/148 assertions, `Result: PASS` ;
- `pnpm backend:types:check` — réussi, types conformes ;
- `pnpm backend:check` — réussi, dépôt T0012–T0021 et 7 mutations ;
- `pnpm backend:stop`, puis redémarrage — réussis ; aucune ressource active
  résiduelle et redémarrage avec cache en 45,5 s ;
- requêtes locales — API joignable, Studio HTTP 200, deux identités
  `pilot-*@thrustline.invalid` et deux compagnies uniquement.

### Manual verification result

Réussie. Les publications Docker, les sockets Windows, l'arrêt/redémarrage et
les identités synthétiques ont été inspectés directement. Andy confirme le
31 juillet 2026 l'inspection visuelle de Studio local et des deux identités
synthétiques. Cette preuve clôt la vérification humaine T0021 ; elle ne rend pas
la branche fusionnée dans `main`.

### Risks and limitations

- le daemon DinD est privilégié dans la VM Docker Desktop ; il n'accède toutefois
  ni au socket Docker hôte, ni au dépôt complet, ni à un secret ;
- le volume `thrustline-local-engine-cache` persiste après l'arrêt et consomme de
  l'espace disque, sans contenir le volume de sources du projet ;
- aucune parité Supabase managée, donnée réelle, staging ou production n'est
  prouvée ;
- la branche reste empilée sur T0020/T0019/T0018 et aucune capacité n'est
  présente dans `main` avant fusion.

### Follow-ups

- exécuter séparément les checklists humaines T0018, T0019 et T0020 ;
- après fusion des branches parentes, rebaser ou changer la base de la PR sans
  force-push.

### Documentation updated

`docs/SETUP.md`, `docs/SECURITY.md`, `docs/QUALITY.md`,
`docs/CURRENT_STATE.md`, `docs/KNOWN_ISSUES.md` et l'index des tickets.

### Git and PR

- branche : `fix/T0021-windows-supabase-loopback` ;
- commit d'implémentation : `14f9a45` ;
- PR : #33, brouillon, base `feature/T0020-immutable-ledger`, head
  `fix/T0021-windows-supabase-loopback` ;
- dépendance : PR #32 et ses propres branches parentes ; aucun merge n'est
  revendiqué.
