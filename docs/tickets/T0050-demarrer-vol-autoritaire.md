# T0050 — Démarrer un vol autoritaire depuis un brouillon de dispatch

Status: Ready
Owner: Andy
Branch: `feature/T0050-authoritative-flight-start`
Phase: 2
Risk: High
Security-sensitive: Yes

## Goal

Faire passer côté serveur exactement un brouillon de dispatch vers un vol actif,
de façon transactionnelle, idempotente et exclusive par avion, avec un horodatage
de départ dérivé de PostgreSQL.

## Context

T0047 crée un brouillon `draft` et sa contrainte
`flight_dispatches_draft_only` interdit aujourd'hui tout autre état. Le gate de
l'alpha jouable exige la suite immédiate : un vol réellement démarré côté
serveur, avant toute télémétrie ou clôture. Aucun état de vol n'existe ailleurs
dans le schéma et `flight-runtime` est encore `not-implemented` dans
`eng/authority-inventory.json`.

Ce ticket appartient au flux 2 du mode accéléré et reste indépendant de la
télémétrie du bridge (flux 1) et de la composition desktop (flux 3). Il ne décide
aucune valeur économique : aucune écriture financière n'est créée.

## Dependencies

- T0020 — grand livre immuable, non modifié par ce ticket ;
- T0018 — cycle de compte, dont l'état de suppression bloque la commande ;
- T0024 — inventaire et gate d'autorité ;
- T0029 — propriété d'avion ;
- T0047 — brouillon de dispatch et son registre privé ;
- T0048 — frontière Auth de référence pour le futur endpoint.

## Allowed areas

- une nouvelle migration `supabase/migrations/` append-only ;
- `supabase/tests/database/` pour les nouveaux fichiers pgTAP ;
- `packages/database/src/database.types.ts` régénéré par le script existant ;
- `scripts/ci/test-backend.ps1` et `tests/backend/run.ps1` pour les nouveaux
  fichiers et mutations attendus ;
- `eng/authority-inventory.json` ;
- `docs/ARCHITECTURE.md`, `docs/SECURITY.md`, `docs/QUALITY.md`,
  `docs/CURRENT_STATE.md` ;
- ce ticket et `docs/tickets/README.md`.

## Do not touch

- migrations existantes, y compris T0047 : toute évolution passe par un nouveau
  fichier append-only ;
- grand livre, politique économique T0028 et location T0032 ;
- Edge Functions existantes et frontière Auth : l'endpoint du démarrage est un
  ticket distinct ;
- desktop, Rust/Tauri, bridge, SimConnect, SimBrief ;
- workflows, manifests, lockfiles, cible distante et données réelles.

## Requirements

### 1. Modèle d'état minimal

- Remplacer la contrainte `draft` unique par une liste fermée d'états connus
  limitée à `draft` et `active`, dans une nouvelle migration append-only.
- Conserver l'exclusivité d'un dispatch par avion déjà garantie par
  `flight_dispatches_one_draft_per_aircraft` et documenter que cette contrainte
  couvre désormais les deux états.
- Ajouter un horodatage de départ non nul uniquement à l'état `active`, dérivé de
  PostgreSQL, et interdire toute valeur fournie par un appelant.
- Ne créer aucun autre état, aucune annulation et aucune transition inverse.

### 2. Commande serveur

- Ajouter `public.start_flight_from_dispatch`, `security definer`,
  `set search_path = ''`, exécutable uniquement par `service_role`.
- Accepter exclusivement propriétaire vérifié, clé d'idempotence et dispatch.
- Verrouiller la compagnie du propriétaire puis le dispatch, dériver la
  compagnie et l'avion du serveur et refuser un dispatch appartenant à une autre
  compagnie sans révéler son existence.
- Refuser un compte en suppression via `private.account_is_active`.
- Lier la clé d'idempotence à l'empreinte du payload dans un registre privé sans
  privilège API, avec RLS activée et forcée ; un rejeu identique rend la même
  réponse, une collision échoue.
- Retourner un objet versionné minimal : dispatch, avion, état, horodatage de
  départ et `schemaVersion`.

### 3. Isolation et preuves SQL

- `authenticated` conserve une lecture seule filtrée par la compagnie du sujet
  Auth et ne reçoit aucun `execute` sur la nouvelle commande.
- Les pgTAP couvrent ACL/grants, RLS, isolation A/B/anonyme, dérivation de
  compagnie et d'avion, rejeu identique, collision de clé, deuxième démarrage du
  même dispatch, dispatch inexistant, compte en suppression et rollback injecté.
- Deux sessions concurrentes qui démarrent le même dispatch convergent vers un
  seul vol actif et une seule commande enregistrée.
- Les types générés restent stables après régénération.

## Non-goals

- exposer une frontière Auth, un appel desktop ou une lecture applicative ;
- télémétrie, phases de vol, reprise, SimConnect ou SimBrief ;
- clôturer un vol, produire un rapport ou écrire au grand livre ;
- annuler un vol, replanifier un dispatch ou libérer un avion ;
- toute valeur monétaire, durée facturée ou impact de réputation.

## Acceptance criteria

- [ ] Une nouvelle migration append-only ouvre l'état `active` sans réécrire
      T0047 et sans autoriser d'autre état.
- [ ] Un brouillon possédé devient exactement un vol actif horodaté par le
      serveur, dans une seule transaction.
- [ ] Le rejeu de la même clé rend la même réponse ; une collision, un dispatch
      étranger, un dispatch déjà actif ou un compte en suppression échouent
      fermés sans fuite.
- [ ] Aucun rôle client ne peut exécuter la commande ni écrire l'état ou le
      temps ; la lecture reste limitée à la compagnie du sujet Auth.
- [ ] Deux sessions concurrentes produisent un vol actif unique.
- [ ] pgTAP, types générés et gates applicables passent avec leurs scénarios
      réellement découverts et consignés.

## Security review

- actifs : propriété d'avion, état de vol, temps serveur, idempotence ;
- frontière : `service_role` uniquement, appelée plus tard par une frontière Auth ;
- abus : démarrage du dispatch d'un tiers, double démarrage, état ou horodatage
  forgés, rejeu divergent, contournement du cycle de suppression ;
- validation/autorisation : propriétaire vérifié en amont, compagnie et avion
  dérivés, verrous `for update`, liste fermée d'états ;
- atomicité/idempotence : un seul statement transactionnel, registre privé
  `(owner_id, idempotency_key)` avec empreinte de payload ;
- logs/vie privée : aucun identifiant Auth, message SQL ou donnée personnelle
  exposé à un appelant.

## Maintenance review

- problèmes applicables : `KI-021` interdit les données réelles ; `KI-005` reste
  hors périmètre côté frontend ;
- dette créée : le domaine `flight-runtime` reste partiel jusqu'à la clôture
  T0051 et l'endpoint associé ;
- règle de sécurité : l'état et le temps d'un vol ne viennent jamais d'un
  client ;
- contrôle manuel à automatiser : les deux sessions concurrentes doivent rester
  dans le harnais CI backend ;
- risque résiduel : aucun endpoint, aucun consommateur et aucune preuve runtime
  Edge tant que les tickets suivants ne sont pas livrés.

## Automated validation

```powershell
pnpm.cmd backend:check
pnpm.cmd backend:start
pnpm.cmd backend:reset
pnpm.cmd backend:test
pnpm.cmd backend:types:check
pnpm.cmd backend:stop
pnpm.cmd authority:check
pnpm.cmd data-policy:check
pnpm.cmd maintenance:check
git diff --check
```

## Manual verification

1. Réinitialiser la pile locale, créer une compagnie, un avion et un brouillon.
2. Démarrer le vol par la commande privilégiée puis rejouer la même clé.
3. Tenter le démarrage depuis une seconde identité, avec une clé collisionnée et
   sur un dispatch déjà actif.
4. Confirmer en SQL un vol actif unique, l'absence d'écriture financière et le
   refus de la commande pour `authenticated` et `anon`.

Temps cible : 10 minutes hors démarrage de la pile.

## Rollback

Avant fusion, abandonner la branche. Après fusion, neutraliser la commande dans
un ticket correctif append-only ; ne jamais supprimer une migration livrée ni
réécrire un dispatch existant.

## Completion Report

À remplir après implémentation.

### Summary

### Files changed

### Commands and results

### Manual verification result

### Risks and limitations

### Follow-ups

### Documentation updated
