# T0036 — Valider l'achat d'avion sur le runtime local réel

Status: Done
Owner: Andy
Branch: `chore/T0036-validate-aircraft-purchase-runtime`
Phase: 2
Risk: High
Security-sensitive: Yes

## Goal

Prouver sur la pile Supabase locale isolée que l'Edge Function
`aircraft-purchase` livrée par T0035 charge dans le runtime Deno, vérifie une
session Auth synthétique et atteint la RPC T0029 sans exposer le credential
privilégié ni produire de double débit au rejeu.

## Context

T0035 est fusionné dans `main` par la PR #62 avec ses tests Node, ses gates
statiques et ses checks GitHub verts. Sa preuve restait toutefois simulée : le
runtime Deno, un JWT local complet et la chaîne Auth → Edge → RPC d'achat
n'avaient pas été exécutés ensemble. T0023 fournit déjà le précédent de
validation locale pour l'onboarding et T0021 borne la pile à trois sockets
IPv4 loopback.

Ce ticket est une validation environnementale. Il ne modifie ni le handler, ni
la transaction, ni le schéma et n'autorise aucune donnée réelle ou cible
distante.

## Workflow evidence

- 2 août 2026 — `Ready` : T0021, T0023, T0029 et T0035 sont fusionnés dans
  `origin/main`; la PR #62 est fusionnée au commit `76a47c9` avec Windows
  multi-stack, PostgreSQL 17 et supply-chain verts.
- 2 août 2026 — `In progress` : branche
  `chore/T0036-validate-aircraft-purchase-runtime` créée depuis `origin/main`
  au commit `76a47c9`, worktree propre.
- 2 août 2026 — `Review` : runtime, Auth, onboarding, achat, rejeu, refus,
  état PostgreSQL et nettoyage validés avec des données exclusivement
  synthétiques ; documentation et gates applicables prêts pour revue.
- 2 août 2026 — publication : commit `41b707c` poussé sur
  `chore/T0036-validate-aircraft-purchase-runtime`; PR #63 ouverte prête pour
  revue, base `main`, head T0036.
- 2 août 2026 — `Done` : PR #63 fusionnée dans `main` au commit `82e79ea` ;
  CI `30750492523` (Windows multi-stack et PostgreSQL 17) et supply-chain
  `30750492507` réussies.

## Dependencies

- T0021 — runtime Supabase local isolé et loopback livré dans `main` ;
- T0023 — précédent Auth → Edge → RPC local livré dans `main` ;
- T0029 — achat transactionnel et idempotent livré dans `main` ;
- T0035 / PR #62 — endpoint d'achat fusionné avec checks verts.

## Allowed areas

- ce ticket et `docs/tickets/README.md` ;
- T0035 pour sa seule réconciliation de livraison ;
- `docs/QUALITY.md` et `docs/CURRENT_STATE.md` pour consigner la preuve réelle ;
- exécution non persistante de la pile locale et création de données
  exclusivement synthétiques dans son volume jetable.

## Do not touch

- handlers, configuration Supabase, migrations, seed, types, tables, RLS et RPC ;
- scripts de runtime, gates, workflows et lockfiles ;
- desktop, UX, bridge, SimConnect ou appel réseau client ;
- location T0032, politique économique, catalogue ou autre devise ;
- projet Supabase distant, secret persistant ou donnée réelle ;
- autres tickets, problèmes connus et Completion Reports historiques.

## Requirements

### 1. Runtime et isolation

- Démarrer la pile T0021 et charger `aircraft-purchase` dans l'Edge Runtime réel.
- Confirmer que 54321, 54322 et 54323 sont les seuls ports publiés et qu'ils
  sont liés exclusivement à `127.0.0.1`.
- Ne conserver aucun fichier de secret, credential ou état synthétique après
  l'arrêt `--no-backup`.

### 2. Chaîne Auth → Edge → RPC

- Créer dans la pile jetable une identité non anonyme, une session et un JWT
  synthétiques sans réactiver l'inscription publique.
- Créer sa compagnie et son ouverture via `company-onboarding`, puis appeler
  `aircraft-purchase` avec seulement l'offre seedée et une clé d'idempotence.
- Confirmer que le propriétaire provient d'Auth et que la réponse publique
  contient exactement `aircraftId`, `ledgerEntryId`, `offerId`,
  `schemaVersion: 1` et `state: owned` avec `Cache-Control: no-store`.

### 3. Rejeu, refus et état

- Rejouer la même requête et obtenir les mêmes identifiants sans deuxième
  avion, commande ou débit.
- Confirmer en PostgreSQL une compagnie, une ouverture, un achat, un avion et
  un solde final de 330 000 EUR pour l'identité synthétique.
- Appeler sans JWT et avec un champ économique interdit ; confirmer un refus
  public sans détail SQL ni credential.

### 4. Réconciliation

- Passer T0035 à `Done` avec la fusion et les trois checks GitHub réellement
  observés, sans attribuer à T0035 la preuve runtime de T0036.
- Consigner commandes, environnement, résultats et limites dans ce ticket,
  `QUALITY.md`, `CURRENT_STATE.md` et l'index.

## Non-goals

- modifier ou corriger l'implémentation T0029/T0035 ;
- automatiser un parcours desktop ou une inscription utilisateur ;
- prouver le rate limiting, la parité cloud, staging ou production ;
- autoriser des données réelles ;
- implémenter la location T0032.

## Acceptance criteria

- [x] L'Edge Runtime réel charge les deux fonctions sur la pile loopback isolée.
- [x] Une session synthétique traverse Auth → Edge → RPC et achète l'offre
      seedée avec une réponse minimale `no-store`.
- [x] Le rejeu converge vers les mêmes identifiants et l'état SQL prouve un seul
      avion, une seule commande et un seul débit d'achat.
- [x] Les appels sans JWT et avec champ interdit échouent fermés sans détail
      sensible.
- [x] L'arrêt détruit l'état synthétique et la documentation réconcilie T0035
      sans revendiquer de déploiement distant ni de consommation desktop.

## Security review

- actifs : JWT synthétique, identité Auth, compagnie, offre, avion, écritures et
  credentials locaux éphémères ;
- frontière : poste Windows → runtime local loopback → Edge → Auth/RPC ;
- abus : fuite de clé, propriétaire ou prix forgé, rejeu divergent, double débit,
  persistance du volume de test et exposition réseau ;
- contrôles : valeurs synthétiques, payload fermé, sorties redigées, assertions
  d'identifiants/compteurs/solde, inspection des bindings et arrêt sans backup ;
- risque résiduel : aucune parité cloud, protection de plateforme ou charge
  distante n'est prouvée.

## Automated validation

```powershell
pnpm.cmd backend:functions:test
pnpm.cmd backend:check
pnpm.cmd authority:check
pnpm.cmd data-policy:check
pnpm.cmd maintenance:check
git diff --check
```

## Manual verification

1. Démarrer puis reset la pile locale isolée et relever le runtime chargé.
2. Créer une identité via l'API Admin locale, ajouter une session synthétique
   horodatée et signer son JWT local sans réactiver le provider email, puis
   faire vérifier ce JWT par Auth avant l'onboarding.
3. Appeler l'achat avec l'offre seedée, inspecter réponse et headers, puis rejouer.
4. Interroger PostgreSQL dans le daemon isolé pour vérifier compteurs, écritures
   et solde ; exécuter les deux refus attendus.
5. Arrêter sans backup, redémarrer et confirmer l'absence de l'identité de
   contrôle, puis arrêter définitivement.

Temps cible : 15 minutes hors démarrage initial de Docker Desktop.

## Rollback

Arrêter la pile avec `pnpm backend:stop`. Le ticket ne modifie aucun schéma ni
runtime ; abandonner ses seuls changements documentaires avant fusion suffit.

## Completion Report

### Summary

La pile Supabase locale isolée a chargé les deux Edge Functions. Une identité,
une session et un JWT synthétiques ont traversé Auth puis
`company-onboarding` et `aircraft-purchase`. L'achat de l'offre seedée a rendu
le contrat public minimal `no-store`; le rejeu a conservé les identifiants et
l'état PostgreSQL n'a qu'un avion, une commande et un débit d'achat.

### Files changed

- nouveau ticket T0036 et index synchronisé ;
- T0035 réconcilié `Done` après sa fusion #62 et ses checks verts ;
- `QUALITY.md` et `CURRENT_STATE.md` complétés avec la preuve runtime réelle.

Aucun handler, script, manifeste, schéma, seed, type ou code applicatif n'est
modifié.

### Commands and results

- `pnpm.cmd backend:functions:test` — PASS, 30/30 tests ;
- `pnpm.cmd backend:check` — PASS, 18 mutations ;
- `pnpm.cmd maintenance:check` — PASS avant exécution, 8 mutations ;
- premier `pnpm.cmd backend:start` dans le bac à sable — bloqué par refus
  d'exécution de `docker.exe`, puis PASS avec l'autorisation Docker ;
- `pnpm.cmd backend:reset` — PASS, six migrations et seed synthétique appliqués ;
- inspection `docker port thrustline-local-engine` — PASS, trois bindings
  seulement : 54321–54323 sur `127.0.0.1` ;
- premier bloc d'intégration PowerShell — arrêté avant création : stderr
  informatif de `supabase status` traité comme erreur par Windows PowerShell ;
- deuxième bloc — arrêté avant création : l'URL interne
  `thrustline-local-engine` annoncée par la CLI n'est pas résoluble depuis
  l'hôte ; l'URL loopback observée a été utilisée explicitement ;
- troisième bloc — identité créée, puis connexion refusée HTTP 422 parce que le
  provider email local est désactivé ; aucune configuration n'a été relâchée ;
- quatrième bloc — session synthétique créée mais `/auth/v1/user` a rendu HTTP
  500 ; le log Auth redigé a confirmé `created_at` absent ;
- bloc final Windows PowerShell 5.1 — PASS : session horodatée, JWT HS256 local,
  `/auth/v1/user`, onboarding, achat, rejeu, refus et inspection SQL ;
- `pnpm.cmd backend:stop` — PASS avec `--no-backup` ; redémarrage — PASS ;
  compteur `t0036` après redémarrage `0` ; arrêt final — PASS ;
- `pnpm.cmd backend:functions:test` final — PASS, 30/30 ;
- `pnpm.cmd backend:check` final — PASS, 18 mutations ;
- `pnpm.cmd authority:check` — PASS, 10 étapes, 13 domaines, 3 surfaces et
  5 mutations ;
- `pnpm.cmd data-policy:check` — PASS, 6 mutations ;
- `pnpm.cmd maintenance:check` final — PASS, 8 mutations ;
- `git diff --check` — PASS avant indexation.

Les credentials locaux ont été lus en mémoire depuis `supabase status -o env`,
n'ont jamais été affichés et n'ont été écrits dans aucun fichier.

### Manual verification result

PASS le 2 août 2026 sur Docker Desktop 29.6.2, Supabase CLI 2.109.1,
PostgreSQL 17 et Edge Runtime/Deno locaux. Résultat public : état onboarding
`active`, achat `owned`, champs `aircraftId,ledgerEntryId,offerId,schemaVersion,state`,
`Cache-Control: no-store`, rejeu avec les mêmes identifiants, absence de JWT
HTTP 401 et champ `priceMinor` interdit HTTP 400 sans détail interne.

PostgreSQL confirme pour le propriétaire synthétique : une compagnie, deux
écritures, solde `33000000`, un avion, une commande d'achat et offre `sold`.
Après arrêt sans backup et redémarrage, aucune identité T0036 ne subsiste.

### Risks and limitations

- la session/JWT ont été construits directement dans la pile jetable parce que
  le provider email est volontairement désactivé ; aucun parcours de connexion
  utilisateur ou refresh n'est prouvé ;
- la preuve est locale et synthétique : aucune parité cloud, cible distante,
  charge, rate limiting ou donnée réelle ;
- aucun appel desktop et aucune location ne sont livrés ;
- le scénario reste une vérification environnementale manuelle, pas un nouveau
  gate CI, conformément au périmètre documentaire de T0036.

### Follow-ups

- après fusion de T0036, cadrer séparément la consommation desktop de l'achat
  avec une session utilisateur et sans exposer `service_role` ;
- conserver T0032 en `Draft` jusqu'aux décisions économiques et temporelles
  explicites d'Andy ;
- valider staging avant toute donnée réelle ou usage distant.

### Documentation updated

T0035, ce ticket, l'index, `QUALITY.md` et `CURRENT_STATE.md`.

### Git status

- branche : `chore/T0036-validate-aircraft-purchase-runtime` ;
- base : `main` / `origin/main` au commit `76a47c9` ;
- commit de validation : `41b707c` ;
- PR #63 : fusionnée dans `main` au commit `82e79ea`, base `main`, head
  `chore/T0036-validate-aircraft-purchase-runtime` ;
- checks GitHub : CI `30750492523` et supply-chain `30750492507` réussies ;
- la fusion et la clôture ont été réconciliées par T0037 sans réécrire les
  preuves historiques ci-dessus.
