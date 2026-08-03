# T0047 — Créer un brouillon de dispatch autoritaire et idempotent

Status: Review
Owner: Andy
Branch: `feature/T0047-authoritative-dispatch-draft`
Phase: 2–4
Risk: High
Security-sensitive: Yes

## Goal

Permettre de créer côté serveur un premier brouillon de dispatch pour un avion
possédé, entre deux aérodromes distincts, sans qu'un client puisse forger la
compagnie, utiliser l'avion d'un tiers ou créer deux brouillons actifs pour le
même avion.

## Context

T0024 classe encore le dispatch `not-implemented`. T0029 fournit une flotte
possédée et isolée par compagnie ; T0046 permet de la relire depuis le desktop.
Le prochain ticket recommandé dans `CURRENT_STATE.md` est le premier slice
dispatch autoritaire de phase 4, tandis que la location T0032 reste `Draft`.

Cette première tranche ne prépare pas encore un plan SimBrief et ne démarre pas
un vol. Elle persiste uniquement l'intention minimale nécessaire au prochain
slice : avion possédé, départ ICAO, arrivée ICAO et état serveur `draft`.
T0043–T0046 ne sont pas encore livrés dans `main` ; T0047 reste donc explicitement
empilé sur T0046 et ne présente pas la pile comme livrée.

## Workflow evidence

- 3 août 2026 — `Ready` : T0029 est livré dans `main`, la branche parente T0046
  contient la lecture de flotte validée et le slice minimal n'exige aucune règle
  économique, temporelle ou SimBrief nouvelle.
- 3 août 2026 — `In progress` : branche
  `feature/T0047-authoritative-dispatch-draft` créée depuis T0046 au commit
  `0ed21b1`; dépendance empilée explicite sur T0043–T0046.
- 3 août 2026 — `Review` : migration, ACL/RLS, commande idempotente, types,
  tests, course intersession, revue adversariale et documentation terminés ;
  publication encore à effectuer sur la branche T0046.
- 3 août 2026 — publication : commit `0559a8e` poussé ; PR prête #81 ouverte,
  base `feature/T0046-desktop-aircraft-fleet`, head T0047, état `OPEN` et
  `MERGEABLE` ; les trois checks GitHub sont en cours lors de l'observation.

## Dependencies

- T0012 — RLS A/B/anonyme et runtime Supabase local ;
- T0018 — blocage des nouvelles commandes pendant une suppression ;
- T0024 — inventaire canonique des autorités du golden path ;
- T0029 — propriété d'avion et isolation de compagnie autoritaires ;
- T0046 — lecture desktop de flotte, branche parente empilée.

## Allowed areas

- `supabase/migrations/` — une migration append-only T0047 ;
- `supabase/seed.sql` — brouillons synthétiques uniquement si nécessaires ;
- `supabase/tests/database/` — pgTAP T0047 ;
- `tests/backend/` et `scripts/ci/test-backend.ps1` ;
- `packages/database/src/database.types.ts` — types régénérés ;
- `eng/authority-inventory.json` et son gate ;
- `docs/PRODUCT.md`, `docs/ARCHITECTURE.md`, `docs/SECURITY.md`,
  `docs/QUALITY.md`, `docs/CURRENT_STATE.md` ;
- ce ticket et `docs/tickets/README.md`.

## Do not touch

- migrations existantes, achat T0029, grand livre et politique économique ;
- Edge Functions, appel desktop, UX, Rust/Tauri, bridge ou SimConnect ;
- location T0032, maintenance, disponibilité technique ou affectation équipage ;
- appel SimBrief, OFP, météo, route détaillée, passagers, fret ou horaires ;
- démarrage, reprise, annulation, clôture ou impacts financiers d'un vol ;
- cible distante, données réelles, secrets, workflows, manifests et lockfiles ;
- statuts ou Completion Reports des autres tickets.

## Requirements

### 1. Brouillon minimal et fermé

- Créer une table publique de dispatchs versionnés contenant la compagnie,
  l'avion, le départ ICAO, l'arrivée ICAO, l'état `draft` et les timestamps
  serveur nécessaires.
- Accepter uniquement `owner_id`, clé d'idempotence, avion et deux codes ICAO ;
  dériver la compagnie du propriétaire serveur et ne jamais accepter de
  compagnie, horaire, prix, revenu, statut ou résultat SimBrief du client.
- Normaliser les codes ICAO en majuscules, exiger exactement quatre caractères
  ASCII alphanumériques et refuser un départ identique à l'arrivée.

### 2. Propriété et exclusivité

- Réserver la commande de création à `service_role` et vérifier que le compte est
  actif, que l'avion existe et appartient à la compagnie dérivée.
- Verrouiller l'avion avant la création et garantir au plus un brouillon actif
  par avion sous appels séquentiels ou concurrents.
- Refuser l'avion d'une autre compagnie, un avion absent et tout état partiel
  après une panne injectée.

### 3. Idempotence et lecture propriétaire

- Lier la clé UUID au propriétaire et au payload normalisé
  avion/départ/arrivée ; un rejeu identique rend exactement le même résultat et
  une collision de payload échoue fermée.
- Conserver le registre de commande dans `private`, sans privilège Data API.
- Autoriser `authenticated` à lire uniquement les dispatchs de sa compagnie sous
  RLS forcée ; `anon` ne lit ni ne mute rien et aucun rôle client ne mute.

### 4. Preuves et inventaire

- Couvrir structure, ACL/RLS, succès, normalisation, validation, rejeu,
  collision, propriété A/B, suppression en attente, exclusivité, concurrence et
  rollback par pgTAP ou harnais PostgreSQL réel.
- Passer le domaine dispatch de `not-implemented` à
  `server-authoritative`/`partial` uniquement avec la commande et ces preuves.
- Étendre le gate backend pour refuser une commande dispatch exécutable par un
  client ou une compagnie/un statut/une heure acceptés comme autorité cliente.

## Non-goals

- endpoint authentifié, formulaire desktop ou lecture Data API desktop ;
- catalogue de routes, géocodage ou validation contre une base d'aérodromes ;
- préparation/import/export SimBrief ou stockage d'un OFP ;
- disponibilité opérationnelle de l'avion hors exclusivité du brouillon ;
- changement d'état du dispatch, annulation, démarrage ou clôture de vol ;
- argent, réputation, maintenance, passagers, fret ou revenus ;
- données réelles, staging, production ou déploiement distant.

## Acceptance criteria

- [x] Une commande serveur crée un brouillon minimal pour un avion possédé avec
      départ et arrivée ICAO valides et distincts.
- [x] Compagnie, état et timestamps sont exclusivement dérivés côté serveur.
- [x] Rejeu, collision, concurrence et exclusivité ne créent ni doublon ni état
      partiel.
- [x] A ne peut pas utiliser ou lire l'avion/dispatch de B ; `anon` et les rôles
      clients ne peuvent rien muter.
- [x] Suppression en attente, avion absent, payload invalide et panne injectée
      échouent fermés.
- [x] Deux resets, tous les pgTAP, les types et les gates applicables passent
      avec un nombre de tests réellement découvert et consigné.
- [x] La documentation borne la tranche au brouillon et distingue la branche
      empilée d'une capacité livrée dans `main`.

## Security review

- actifs/données : propriété d'avion, intention de trajet, état du dispatch et
  clé d'idempotence ;
- frontière : futur endpoint authentifié → commande `service_role` → PostgreSQL,
  avec clients distribués limités aux lectures RLS ;
- abus : compagnie ou avion forgés, utilisation croisée A/B, double brouillon,
  état/temps client, rejeu divergent et état partiel ;
- validation/autorisation : propriétaire vérifié par la future frontière,
  compagnie dérivée, avion verrouillé, ICAO fermé, ACL et RLS forcées ;
- atomicité/idempotence : transaction unique, registre privé, empreinte du
  payload normalisé, unicité et verrous ordonnés ;
- logs/vie privée : aucune donnée réelle, credential ou détail SQL journalisé ;
  les preuves utilisent des identifiants et aérodromes synthétiques.

## Maintenance review

- dettes et problèmes connus applicables : `KI-005` pour les futurs écrans et
  `KI-021` qui interdit les données réelles ;
- dette créée ou aggravée : aucune attendue ; la validation contre un référentiel
  d'aérodromes et les transitions restent explicitement différées ;
- règle de sécurité ajoutée, modifiée ou à revalider : un dispatch appartient à
  la compagnie serveur de l'avion et son état initial ne vient jamais du client ;
- contrôle manuel à automatiser : course sur deux créations du même avion ;
- risque résiduel : aucun endpoint, SimBrief ou cycle de vol n'est encore livré.

## Automated validation

```powershell
pnpm.cmd backend:check
pnpm.cmd backend:start
pnpm.cmd backend:reset
pnpm.cmd backend:reset
pnpm.cmd backend:test
pnpm.cmd backend:types
pnpm.cmd backend:types:check
pnpm.cmd authority:check
pnpm.cmd data-policy:check
pnpm.cmd maintenance:check
pnpm.cmd backend:stop
git diff --check
```

## Manual verification

1. Créer deux compagnies et acheter un avion synthétique pour chacune.
2. Créer puis rejouer un brouillon normalisé pour A et confirmer un seul résultat.
3. Tenter l'avion de B, une collision de clé et deux créations concurrentes pour
   le même avion ; confirmer l'isolation et l'unicité.
4. Tester ICAO invalides/identiques, suppression en attente et panne injectée ;
   confirmer l'absence d'état partiel.

Temps cible : 10–15 minutes.

## Rollback

Avant fusion, abandonner la branche et recréer la base locale jetable. Après
fusion, ajouter une migration corrective append-only ; ne jamais modifier ou
supprimer la migration, un dispatch ou une commande déjà appliqués. Aucune
donnée réelle n'est autorisée.

## Completion Report

### Summary

Une migration append-only crée `flight_dispatches`, son registre privé et la
commande `create_dispatch_draft`. La commande dérive la compagnie, verrouille
l'avion possédé, normalise les ICAO et persiste un unique brouillon `draft`
horodaté par PostgreSQL. Rejeu identique, collision, isolation et course sur le
même avion sont couverts sans endpoint ni mutation financière.

### Files changed

- migration et deux fichiers pgTAP T0047 ;
- types de base régénérés, harnais backend Windows/CI et inventaire d'autorité ;
- produit, architecture, sécurité, qualité, état courant, ticket et index.

Aucun fichier desktop, Edge Function, migration existante, seed, grand livre,
SimConnect, manifeste, lockfile, workflow ou secret n'est modifié.

### Commands and results

- `pnpm.cmd backend:check` — PASS, 22 mutations ;
- `pnpm.cmd authority:check` — PASS, 10 étapes, 13 domaines, 3 surfaces et 9
  mutations ;
- `pnpm.cmd data-policy:check` — PASS, 6 mutations ;
- `pnpm.cmd maintenance:check` — PASS, 8 mutations ;
- `pnpm.cmd backend:start` — premier essai bloqué car Docker Desktop était
  arrêté ; après lancement de Docker Desktop 29.6.2, PASS avec pile isolée sur
  IPv4 loopback ;
- `pnpm.cmd backend:reset` deux fois — PASS, sept migrations appliquées ;
- `pnpm.cmd backend:test` — PASS, 14 fichiers/270 assertions, `Result: PASS` ;
- `pnpm.cmd backend:types` puis `pnpm.cmd backend:types:check` — PASS, types
  générés et stables ;
- course PostgreSQL à deux sessions, clés et destinations différentes sur le
  même avion — PASS, codes `0|1`, état `1|1|0|1` ;
- contrôle final des types et des quatre gates — PASS ;
- `git diff --check` — PASS, avertissements LF/CRLF seulement.

### Manual verification result

PASS le 3 août 2026 sur PostgreSQL 17 local synthétique : création normalisée,
rejeu, collision, propriété A/B, anonyme, deuxième brouillon, suppression en
attente et rollback injecté sont couverts par pgTAP. La course réelle confirme
une création réussie, une refusée, un brouillon et une commande. Le premier
nettoyage de la fixture de course a tenté l'identité avant la compagnie et a été
refusé sans suppression partielle par la FK ; le nettoyage ciblé a ensuite été
rejoué dans l'ordre compagnie, offre, identité et a réussi.

### Risks and limitations

T0047 reste empilé sur T0046 et T0043–T0047 sont absents de `main`. Aucun
endpoint authentifié, appel desktop, SimBrief, référentiel d'aérodromes,
transition, runtime ou clôture de vol n'est fourni. Les ICAO sont seulement
validés syntaxiquement. La preuve reste locale, synthétique, sans cible distante
ni donnée réelle.

### Follow-ups

- publier T0047 sur T0046 puis propager la pile vers `main` dans l'ordre ;
- exposer `create_dispatch_draft` derrière une Edge Function authentifiée,
  bornée et redigée ;
- traiter lecture desktop, SimBrief et transitions de vol dans des tickets
  séparés ; T0032 reste `Draft`.

### Documentation updated

`PRODUCT.md`, `ARCHITECTURE.md`, `SECURITY.md`, `QUALITY.md`,
`CURRENT_STATE.md`, l'inventaire d'autorité, ce ticket et son index.

### Git status

- branche : `feature/T0047-authoritative-dispatch-draft` ;
- base : T0046 au commit `0ed21b1` ;
- dépendances empilées : T0043–T0046 restent absents de `main` ;
- commit d'implémentation : `0559a8e` ;
- branche poussée avec upstream exact ;
- PR prête #81 : https://github.com/AndyD9/ThrustlineNG/pull/81, base T0046,
  head T0047, état `OPEN` et `MERGEABLE` ; Windows multi-stack, PostgreSQL 17 et
  supply-chain sont en cours lors de l'observation initiale.
