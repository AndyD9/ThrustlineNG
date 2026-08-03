# T0049 — Valider le brouillon de dispatch sur le runtime local réel

Status: Review
Owner: Andy
Branch: `chore/T0049-validate-dispatch-runtime`
Phase: 2
Risk: Medium
Security-sensitive: Yes

## Goal

Prouver sur la pile locale réelle qu'une session Supabase Auth traverse l'Edge
Function `dispatch-draft` puis la commande `create_dispatch_draft`, avec une
identité, une compagnie, un avion et un brouillon exclusivement synthétiques.

## Context

T0047 prouve la transaction sur PostgreSQL 17 et T0048 prouve le handler avec un
`fetch` injecté. Aucun des deux ne charge la fonction dans l'Edge Runtime réel :
le contrat Deno, la lecture des variables serveur et le chaînage Auth → Edge →
RPC restent non exécutés. T0036 a fourni exactement cette preuve pour l'achat
d'avion ; ce ticket applique le même protocole au dispatch.

Le flux concerné est le flux 2 du mode accéléré (`docs/ROADMAP.md`). La capacité
est déjà présente dans `main` depuis la PR #83 ; ce ticket n'ajoute aucune
capacité produit et ne modifie ni la migration, ni le handler.

## Workflow evidence

- 3 août 2026 — `Ready` : T0047 et T0048 sont fusionnés dans `main` par la PR
  #83 au merge `d117690`; leurs fichiers de tickets sont `Done`.
- 3 août 2026 — `In progress` : branche `chore/T0049-validate-dispatch-runtime`
  créée depuis `origin/main` au commit `b57a2c5`, worktree propre.
- 3 août 2026 — écart relevé avant toute écriture : la fusion #86 a ramené les
  six lignes d'index T0043–T0048 à `Review` alors que leurs fichiers sont `Done`,
  ce qui rend `pnpm maintenance:check` rouge sur `origin/main`. La correction
  reste dans `docs/tickets/README.md`, une zone autorisée de ce ticket.
- 3 août 2026 — `Review` : 48 contrôles runtime passent sans échec, la pile est
  détruite sans backup, le redémarrage prouve zéro identité T0049 et les gates
  applicables passent ; le diff est prêt pour revue.
- 3 août 2026 — publication : commit `4e60c70` poussé sur
  `chore/T0049-validate-dispatch-runtime`; PR #87 ouverte prête pour revue, base
  `main`, head T0049, `OPEN` et `MERGEABLE`. Ses trois checks sont démarrés mais
  encore `pending` lors de cette observation ; aucun n'est revendiqué comme
  réussi.
- 3 août 2026 — checks verts sur le commit `2685a2a` : Windows multi-stack
  (`30825221051`, 15 min 36 s), Supabase PostgreSQL 17 (`30825221051`,
  3 min 13 s) et audits/licences/SBOM (`30825220958`, 4 min 14 s) réussissent.
  Le ticket reste `Review` : seule la fusion par Andy manque.

## Dependencies

- T0021 — pile Supabase locale isolée sur `127.0.0.1` ;
- T0040 — provider email local et provisionnement d'identité par l'Admin API ;
- T0036 — protocole de preuve runtime Edge de référence ;
- T0047, T0048 — commande et frontière à valider, présentes dans `main`.

## Allowed areas

- `scripts/` pour un script de validation runtime borné, si nécessaire ;
- `docs/QUALITY.md` et `docs/CURRENT_STATE.md` ;
- ce ticket et `docs/tickets/README.md`.

## Do not touch

- migration, tables, RLS et commande SQL T0047 ;
- handler, contrat et tests de `supabase/functions/dispatch-draft/` ;
- onboarding, achat, politique économique ou location T0032 ;
- desktop, Rust/Tauri, bridge, SimConnect et SimBrief ;
- workflows, manifests, lockfiles, cible distante et données réelles.

## Requirements

### 1. Environnement

- Démarrer la pile via `backend:start` et confirmer que 54321–54323 écoutent
  uniquement sur `127.0.0.1` avant tout appel.
- Provisionner une identité `.invalid` par l'Admin API locale, sans ouvrir
  `auth.enable_signup`.
- Créer la compagnie par `company-onboarding` et l'avion par
  `aircraft-purchase`, afin que le dispatch porte sur un avion réellement
  possédé.

### 2. Parcours nominal

- Appeler `POST /functions/v1/dispatch-draft` avec le bearer de la session, un
  avion possédé, deux ICAO distincts et une clé d'idempotence.
- Vérifier que la réponse contient exactement les sept champs publics, avec
  `state: draft`, `schemaVersion: 1` et `Cache-Control: no-store`.
- Rejouer la même intention et exiger le même `dispatchId`.
- Confirmer en SQL exactement un brouillon, une commande d'idempotence, l'état
  `draft` et l'appartenance à la compagnie du sujet Auth.

### 3. Refus

- Appel sans bearer : HTTP 401 sans détail interne.
- Champ supplémentaire, ICAO invalides ou identiques : HTTP 400 redigé.
- Avion appartenant à une seconde identité synthétique : rejet redigé sans
  divulguer l'existence, la compagnie ou le propriétaire de cet avion.
- Deuxième brouillon sur le même avion avec une nouvelle clé : rejet redigé.

### 4. Nettoyage et preuves

- Supprimer les identités synthétiques, arrêter la pile avec `--no-backup` puis
  redémarrer et prouver zéro identité T0049 persistée.
- Consigner chaque commande, son environnement, son résultat et ses limites ;
  distinguer `non exécuté`, `bloqué par l'environnement` et `échoué`.
- Aucun JWT, credential, email ou détail SQL dans le ticket ou les artefacts.

## Non-goals

- modifier le contrat, la transaction, l'idempotence ou les RLS existantes ;
- consommer l'endpoint depuis le desktop ;
- démarrer, reprendre, annuler ou clôturer un vol ;
- préparer SimBrief, déployer ou valider un projet Supabase distant.

## Acceptance criteria

- [x] L'Edge Runtime local réel charge `dispatch-draft` sans nouveau port hôte.
- [x] Une session non anonyme obtient un brouillon minimal pour un avion possédé
      et le rejeu rend le même identifiant.
- [x] Absence de JWT, champ interdit, ICAO invalides, avion d'un autre
      propriétaire et deuxième brouillon échouent fermés et redigés.
- [x] L'état PostgreSQL final est exactement un brouillon et une commande.
- [x] L'arrêt sans backup puis le redémarrage prouvent zéro persistance des
      identités synthétiques.
- [x] `QUALITY.md` et `CURRENT_STATE.md` consignent la preuve datée avec ses
      limites, sans revendiquer de cible distante ou de donnée réelle.

## Security review

- actifs : identité Auth, propriété d'avion, credential `service_role` ;
- frontière : client local non fiable → Auth → Edge Function → RPC T0047 ;
- abus : dispatch sur un avion non possédé, rejeu divergent, fuite d'erreur,
  persistance involontaire d'une identité de test ;
- contrôles : provisionnement Admin API sans signup public, bindings loopback
  vérifiés, refus redigés, destruction sans backup ;
- logs : aucun secret, JWT, email ou détail SQL consigné.

## Maintenance review

- problèmes applicables : `KI-014` parité locale/cloud non prouvée, `KI-021`
  interdiction des données réelles ;
- dette attendue : aucune ; la consommation desktop reste T0052 ;
- règle de sécurité : une preuve runtime locale ne vaut jamais parité managée ;
- contrôle répétable : script de validation runtime si le parcours est
  reproductible sans intervention manuelle ;
- risque résiduel : aucun environnement distant, staging ou production validé.

## Automated validation

```powershell
pnpm.cmd backend:check
pnpm.cmd backend:functions:test
pnpm.cmd backend:start
pnpm.cmd backend:reset
pwsh -NoProfile -File ./scripts/validate-dispatch-draft-runtime.ps1
pnpm.cmd backend:reset
pnpm.cmd backend:test
pnpm.cmd backend:types:check
pnpm.cmd backend:stop
pnpm.cmd maintenance:check
git diff --check
```

## Manual verification

1. Démarrer la pile, relever les trois bindings et provisionner l'identité.
2. Créer compagnie et avion, puis appeler `dispatch-draft` et rejouer l'appel.
3. Tester les quatre refus et confirmer l'absence de détail privilégié.
4. Interroger PostgreSQL, supprimer l'identité, arrêter sans backup, redémarrer
   et confirmer l'absence de résidu.

Temps cible : 10 minutes hors démarrage de la pile.

## Rollback

Aucun changement applicatif n'est requis. En cas d'échec, arrêter la pile sans
backup, consigner l'échec et ouvrir un ticket correctif ciblant la cause réelle.

## Completion Report

### Summary

La pile Supabase locale isolée a chargé `dispatch-draft` dans l'Edge Runtime
Deno réel. Deux identités `.invalid` provisionnées par l'Admin API locale ont
ouvert leur compagnie par `company-onboarding`; la première a acheté l'offre
seedée abordable par `aircraft-purchase`, puis a obtenu un brouillon de dispatch
par `POST /functions/v1/dispatch-draft`. Le script
`scripts/validate-dispatch-draft-runtime.ps1` exécute 48 contrôles et tous
passent : contrat public, rejeu, cinq refus, état SQL et bindings loopback.

Aucune migration, aucun handler et aucun contrat n'est modifié. Le ticket ajoute
un seul script de validation et de la documentation.

### Files changed

- nouveau `scripts/validate-dispatch-draft-runtime.ps1` ;
- ce ticket, l'index des tickets, `docs/QUALITY.md` et `docs/CURRENT_STATE.md`.

L'index reçoit en plus la réconciliation des six lignes T0043–T0048, ramenées à
`Review` par la fusion #86 alors que leurs fichiers sont `Done`.

### Commands and results

- `pnpm.cmd maintenance:check` sur `origin/main` avant toute écriture — FAIL,
  six écarts d'index T0043–T0048 ; régression de la fusion #86, corrigée ici ;
- `pnpm.cmd backend:start` — d'abord bloqué par une pile résiduelle du même jour
  ne contenant que du seed (`2|2|0|0|0`), puis PASS après `pnpm.cmd backend:stop` ;
- `pnpm.cmd backend:reset` — PASS, sept migrations et le seed appliqués ;
- `docker port thrustline-local-engine` via `Assert-SupabaseOuterBindings` —
  PASS, trois bindings `127.0.0.1` seulement, avant et après le parcours ;
- `pwsh -NoProfile -File ./scripts/validate-dispatch-draft-runtime.ps1` — PASS,
  48 contrôles, 0 échec ;
- trois itérations antérieures du même script sont des échecs corrigés dans le
  script, pas dans le produit : indexation d'une chaîne psql prise pour une
  ligne, suppression d'identité propriétaire refusée par
  `companies_owner_id_fkey`, et refus Admin API anonyme observé en HTTP 403 au
  lieu de 401 ;
- `pnpm.cmd backend:check` — PASS, 26 scénarios de mutation ;
- `pnpm.cmd backend:functions:test` — PASS, 46/46 tests ;
- `pnpm.cmd backend:test` — d'abord FAIL sur la base portant les lignes
  synthétiques du parcours, puis PASS après `backend:reset` avec 14
  fichiers/270 tests ;
- `pnpm.cmd backend:types:check` — PASS, les types correspondent au schéma local ;
- `pnpm.cmd backend:stop` — PASS ; le conteneur et le volume projet disparaissent
  et seul le cache d'images source-free est conservé ;
- `pnpm.cmd backend:start` puis inspection SQL — PASS, `2|0|0|0|0` : deux
  identités seed, zéro identité T0049, zéro brouillon, zéro commande, zéro avion ;
- `pnpm.cmd backend:stop` final — PASS ;
- `pnpm.cmd authority:check`, `pnpm.cmd data-policy:check`,
  `pnpm.cmd maintenance:check` et `git diff --check` — PASS après correction de
  l'index.

Les credentials locaux sont lus en mémoire depuis `supabase status -o env`, ne
sont jamais affichés et ne sont écrits dans aucun fichier. Le script n'imprime
aucun JWT, mot de passe, email, identifiant ni détail SQL.

### Manual verification result

PASS le 3 août 2026 sur Docker Desktop 29.6.2, Supabase CLI 2.109.1,
PostgreSQL 17 et Edge Runtime/Deno locaux, via le script reproductible :

1. bindings : seuls 54321–54323 sur `127.0.0.1`, avant et après le parcours ;
2. nominal : HTTP 200, exactement `aircraftId, arrivalIcao, createdAt,
   departureIcao, dispatchId, schemaVersion, state`, `state: draft`,
   `schemaVersion: 1`, `Cache-Control: no-store`, aérodromes et avion conformes
   à la requête, horodatage analysable ;
3. rejeu : même `dispatchId` et même `createdAt` ;
4. refus : sans bearer HTTP 401 et corps borné sans valeur privilégiée ; champ
   `state` supplémentaire HTTP 400 `invalid_request` ; ICAO `LF1` HTTP 400
   `invalid_airports` ; ICAO identiques HTTP 400 `invalid_airports` ; avion d'un
   autre propriétaire HTTP 409 `dispatch_rejected` sans divulguer compagnie,
   propriétaire ou email ; avion inconnu HTTP 409 ; deuxième brouillon sur le
   même avion avec une nouvelle clé HTTP 409 ;
5. chaque refus ne contient que `error.code` et `error.message` ;
6. le refus propriétaire testé avant toute création prouve que la liaison
   avion/compagnie seule le motive, et l'état SQL reste à zéro brouillon ;
7. SQL final `1|1|1|1` : un brouillon, une commande d'idempotence, l'état
   `draft` et l'appartenance à la compagnie du sujet Auth ;
8. destruction : arrêt `--no-backup`, redémarrage et inspection SQL `2|0|0|0|0`.

### Risks and limitations

- la preuve est locale et synthétique : aucune parité cloud, cible distante,
  staging, charge, rate limiting, donnée réelle ni consommation desktop ;
- le refus « avion d'un autre propriétaire » est exercé dans le sens appelant B
  vers l'avion de A. Le seed ne contient qu'une offre inférieure à l'ouverture
  de 430 000 EUR, donc une seule acquisition est possible sans injecter de
  données dans le catalogue ; le chemin de code vérifié est identique ;
- la suppression des identités synthétiques par l'Admin API est refusée par
  `companies_owner_id_fkey` : c'est l'invariant voulu, le retrait de compte
  passant par le cycle de vie T0018. Le nettoyage effectif vient donc de la
  destruction de la pile jetable, prouvée par le redémarrage ;
- l'Admin API locale renvoie le détail PostgreSQL brut de ce refus. Cette
  surface exige le credential `service_role` et reste hors du client ; le script
  vérifie qu'une clé anonyme ne l'atteint pas ;
- `pnpm backend:test` échoue sur une base portant des lignes synthétiques
  résiduelles : la suite pgTAP suppose une base fraîchement réinitialisée ;
- le script reste une vérification environnementale sur demande, pas un gate CI :
  il exige Docker et la pile locale.

### Follow-ups

- candidat de maintenance hors périmètre : isoler la suite pgTAP des lignes
  préexistantes ou documenter formellement le prérequis `backend:reset` ;
- apprentissage candidat pour T0050 et T0051 : une identité déjà propriétaire ne
  se supprime pas par l'Admin API ; prévoir la destruction de la pile comme seul
  nettoyage des parcours runtime ;
- garder la consommation desktop du dispatch dans T0052 et le cycle de vol dans
  T0050–T0051 ;
- valider staging avant toute donnée réelle ou usage distant.

### Documentation updated

Ce ticket, `docs/tickets/README.md`, `docs/QUALITY.md` et
`docs/CURRENT_STATE.md`.

### Git status

- branche : `chore/T0049-validate-dispatch-runtime` ;
- base : `main` / `origin/main` au commit `b57a2c5` ;
- commit de validation : `4e60c70` ;
- PR #87 : `OPEN` et `MERGEABLE`, base `main`, head
  `chore/T0049-validate-dispatch-runtime`, prête pour revue ;
- checks GitHub : Windows multi-stack et Supabase PostgreSQL 17 du run
  `30825221051` et audits/licences/SBOM du run `30825220958` sont réussis sur le
  commit `2685a2a` ;
- fusion : réservée à Andy.
