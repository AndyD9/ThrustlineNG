# T0050 — Démarrer un vol autoritaire depuis un brouillon de dispatch

Status: Done
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

- [x] Une nouvelle migration append-only ouvre l'état `active` sans réécrire
      T0047 et sans autoriser d'autre état.
- [x] Un brouillon possédé devient exactement un vol actif horodaté par le
      serveur, dans une seule transaction.
- [x] Le rejeu de la même clé rend la même réponse ; une collision, un dispatch
      étranger, un dispatch déjà actif ou un compte en suppression échouent
      fermés sans fuite.
- [x] Aucun rôle client ne peut exécuter la commande ni écrire l'état ou le
      temps ; la lecture reste limitée à la compagnie du sujet Auth.
- [x] Deux sessions concurrentes produisent un vol actif unique.
- [x] pgTAP, types générés et gates applicables passent avec leurs scénarios
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

### Summary

Une huitième migration append-only ouvre le domaine `flight-runtime` sans
réécrire T0047. La contrainte `flight_dispatches_draft_only` est remplacée par
une liste fermée de deux états connus, `draft` et `active`. Une colonne
`started_at` est ajoutée, liée par contrainte au seul état `active`, et un
trigger `before insert or update` la dérive de `clock_timestamp()` au passage à
`active`, la conserve ensuite et la remet à null pour un brouillon : aucun
appelant ne peut fournir, remplacer ni antidater ce temps, même par une écriture
directe sur la table. La contrainte d'unicité par avion couvre désormais les deux
états et le reste documenté comme tel.

`public.start_flight_from_dispatch`, `security definer`, `set search_path = ''`
et exécutable seulement par `service_role`, accepte exactement propriétaire
vérifié, clé d'idempotence et dispatch. Elle verrouille la compagnie du
propriétaire puis le dispatch, dérive compagnie et avion du serveur, refuse un
compte en suppression via `private.account_is_active` et n'autorise que la
transition `draft` → `active` dans une seule transaction. Un dispatch inconnu,
appartenant à une autre compagnie ou déjà actif rend le même message opaque. Le
registre `private.flight_start_commands` force RLS, n'accorde aucun privilège
API, lie `(owner_id, idempotency_key)` à l'empreinte SHA-256 du payload et
n'admet qu'un démarrage par dispatch ; un rejeu identique rend la même réponse
versionnée à cinq champs. Aucune valeur monétaire n'est écrite.

### Files changed

- `supabase/migrations/20260803000200_authoritative_flight_start.sql` (nouveau) ;
- `supabase/tests/database/flight_start_structure.test.sql` (nouveau, 18
  assertions) ;
- `supabase/tests/database/flight_start.test.sql` (nouveau, 24 assertions) ;
- `packages/database/src/database.types.ts` régénéré par le script existant ;
- `scripts/ci/test-backend.ps1` : deux fichiers pgTAP attendus en plus et une
  course intersession sur le même dispatch ;
- `tests/backend/run.ps1` : fichiers requis, 21 invariants de migration, garde
  append-only sur les sept migrations livrées, marqueurs pgTAP, marqueurs de
  types, marqueurs CI et quatre mutations négatives supplémentaires ;
- `eng/authority-inventory.json` : `flight-runtime` passe
  `server-authoritative`/`partial` et `start_flight_from_dispatch` rejoint les
  commandes réservées ;
- `docs/ARCHITECTURE.md`, `docs/SECURITY.md`, `docs/QUALITY.md`,
  `docs/CURRENT_STATE.md`, `docs/tickets/README.md` et ce ticket.

### Commands and results

Le 3 août 2026, sous Windows 11, Docker Desktop 29.6.2, Supabase CLI 2.109.1 et
PostgreSQL 17 :

- `pnpm.cmd backend:check` : `Backend checks passed (T0012-T0023, T0028-T0029,
  T0035, T0040 et T0047-T0050 repository plus 30 mutation scenarios).`
- `pnpm.cmd backend:start` : pile locale démarrée sur la loopback IPv4 dans le
  moteur Docker isolé ;
- `pnpm.cmd backend:reset` : les huit migrations append-only s'appliquent, dont
  `20260803000200_authoritative_flight_start.sql`;
- `pnpm.cmd backend:test` : `Files=16, Tests=312` puis `Result: PASS`;
- `pnpm.cmd backend:types:check` : `Database types match the local schema.`
- `pnpm.cmd backend:stop` : runtime arrêté, seul le cache d'images sans source
  est conservé ;
- `pnpm.cmd authority:check` : 10 étapes, 13 domaines, 3 surfaces, 9 mutations ;
- `pnpm.cmd data-policy:check` : 6 mutations ;
- `pnpm.cmd maintenance:check` : registre, index et 8 mutations ;
- `git diff --check` : aucun défaut d'espaces.

Les types régénérés n'ajoutent que `started_at: string | null` sur
`flight_dispatches` et `start_flight_from_dispatch` dans `Functions`.

Preuve CI du 3 août 2026 : la PR #89 est fusionnée dans `main` au merge
`6577125`, où le job Linux `Supabase PostgreSQL 17` passe. Il applique deux
resets, exécute 16 fichiers/312 assertions pgTAP avec `Result: PASS`, prouve
`Flight start concurrency passed: 2 sessions, 1 active flight, 1 command,
1 server time` et conclut par `Backend CI passed: 2 resets, 16 pgTAP files,
concurrent idempotence, purchase, dispatch and flight start, isolated restore
replay, authoritative onboarding, stable types, loopback ports.` La course
intersession du harnais CI, impossible à exécuter localement sous Windows, est
donc prouvée sur le runner Linux. Les runs antérieurs sur `3e798db` et `6418e12`
avaient été annulés par les poussées suivantes, sans jamais atteindre ce job.

Le job `Windows multi-stack` du même run échoue, non pas sur cette tranche, mais
sur `Validate maintenance governance` avec `Ticket T0049 status differs: index
'Review', file 'Done'.` Le merge `09565ee` de `main` dans la branche a résolu le
conflit de `docs/tickets/README.md` en écartant la PR #88 et en ramenant la ligne
d'index T0049 à `Review`. Le contenu de T0050 n'est pas affecté ; la correction
d'une ligne et la clôture de ce ticket sont livrées par la PR de
réconciliation `docs/T0050-record-merge`.

### Manual verification result

Sur la pile locale réinitialisée, deux identités `.invalid`, deux compagnies,
trois avions et trois brouillons sont créés par la commande T0047. Le démarrage
du brouillon possédé rend
`{"state": "active", "startedAt": "2026-08-03T15:21:05.001358+00:00",
"aircraftId": "a1300000-…", "dispatchId": "5161288e-…", "schemaVersion": 1}` et le
rejeu de la même clé rend exactement la même réponse, au même horodatage.

La seconde identité sur le dispatch de la compagnie A, le dispatch déjà actif et
un dispatch inconnu rendent tous `Dispatch is unavailable for flight start.`; la
même clé avec un autre dispatch rend `Idempotency key was already used with a
different payload.` L'état SQL rend `1|2|1|1` : un vol actif, deux brouillons
restants, une commande privée et un horodatage serveur. Aucune écriture
financière n'existe pour ces propriétaires et aucun type d'écriture inattendu
n'apparaît au grand livre. `authenticated` et `anon` reçoivent
`permission denied for function start_flight_from_dispatch`, et `authenticated`
reçoit `permission denied for table flight_dispatches` en tentant d'écrire l'état
et le temps. Le propriétaire A lit `active`/`draft` avec leur horodatage dérivé,
le propriétaire B ne lit que son propre brouillon.

Deux sessions concurrentes sur le même dispatch, la première tenue quatre
secondes, rendent les codes de sortie `0|1` : la seconde échoue avec le même
message opaque. L'état vérifié après la course est `1|1|0|1|0` — un vol actif,
une commande, aucun brouillon restant sur cet avion, un seul horodatage et aucune
ligne sans horodatage. Durée effective hors démarrage de la pile : environ
6 minutes.

### Risks and limitations

- Aucune frontière Auth, aucun endpoint et aucun appelant n'existent : la
  commande reste inatteignable hors `service_role`, donc aucune preuve Edge
  Runtime live n'est produite par ce ticket ;
- la course intersession est prouvée manuellement ici et automatisée dans
  `scripts/ci/test-backend.ps1`, qui exige le runner Linux et n'a donc pas été
  exécuté localement ;
- comme pour T0047, les pgTAP supposent une base fraîchement réinitialisée ;
- télémétrie, phases de vol, reprise, clôture, annulation, replanification,
  libération d'avion, impact financier ou de réputation restent absents ;
- aucune cible distante et aucune donnée réelle ne sont touchées.

### Follow-ups

- T0051 clôturera le vol une seule fois et réglera revenu et réputation ;
- l'endpoint authentifié du démarrage est un ticket distinct, hors périmètre ;
- `flight-runtime` reste `partial` jusqu'à la clôture et son endpoint.

### Documentation updated

`docs/ARCHITECTURE.md` (frontière serveur et modèle d'état),
`docs/SECURITY.md` (section « Démarrage de vol autoritaire T0050 »),
`docs/QUALITY.md` (preuve T0050 datée), `docs/CURRENT_STATE.md` (tranche livrée,
domaine `flight-runtime` et compte des domaines non implémentés),
`docs/tickets/README.md` (statut et narration) et ce ticket.
