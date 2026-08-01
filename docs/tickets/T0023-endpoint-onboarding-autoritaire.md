# T0023 — Exposer l’onboarding derrière une frontière serveur authentifiée

Status: Review
Owner: Andy
Branch: `feature/T0023-authoritative-onboarding-endpoint`
Phase: 2
Risk: High
Security-sensitive: Yes

## Goal

Fournir un endpoint serveur authentifié qui dérive le propriétaire de la session,
garde montant et devise hors du payload client, puis appelle atomiquement la
commande T0022 sans exposer `service_role`.

## Context

T0022 crée la compagnie et son ouverture dans une RPC transactionnelle et
idempotente réservée à `service_role`, mais ne fournit aucun appelant. Un client
distribué ne peut pas recevoir ce credential ni choisir l’identité, le montant
initial ou la devise. T0023 ajoute une Edge Function mince : le client fournit
uniquement un nom normalisé et une clé d’idempotence ; la fonction vérifie le JWT
auprès de Supabase Auth, prend la politique économique dans son environnement et
appelle T0022 avec l’identité Auth vérifiée.

La branche est empilée sur T0022. Au 1er août 2026, `origin/main` contient T0019
mais pas T0020–T0022 ; les PR #35–#37 sont fusionnées dans leurs bases empilées,
pas propagées jusqu’à `main`.

Références :

- `docs/PRODUCT.md` ;
- `docs/ARCHITECTURE.md` ;
- `docs/SECURITY.md` ;
- `docs/STACK.md` ;
- `docs/tickets/T0022-onboarding-compagnie-autoritaire.md`.

## Dependencies

- T0022 — RPC autoritaire implémentée, validée et présente dans l’ascendance ;
- T0021 — runtime local loopback présent dans l’ascendance ;
- phase 2 active sans donnée utilisateur réelle ni projet distant.

## Allowed areas

- `supabase/functions/company-onboarding/` ;
- `supabase/config.toml` ;
- `package.json` ;
- `scripts/start-supabase-local.ps1`, `scripts/invoke-supabase-local.ps1`,
  `scripts/supabase-local-runtime.ps1` et `scripts/ci/test-backend.ps1` ;
- `tests/backend/run.ps1` ;
- `docs/ARCHITECTURE.md`, `docs/SECURITY.md`, `docs/QUALITY.md`, `docs/SETUP.md`,
  `docs/CURRENT_STATE.md` ;
- ce ticket et `docs/tickets/README.md`.

## Do not touch

- migrations et seeds existants ;
- tables, RPC et types de base T0012–T0022 ;
- `apps/desktop/`, `apps/bridge/`, Tauri, SimConnect et contrat local ;
- valeur économique de production, UX d’onboarding ou inscription Auth ;
- deuxième écriture financière, flotte, dispatch, vol ou clôture ;
- projet Supabase distant, déploiement, secret ou donnée réelle ;
- workflows GitHub et permissions CI.

## Requirements

### 1. Frontière authentifiée

- `company-onboarding` accepte uniquement `POST` et conserve le gate JWT de la
  plateforme.
- La fonction vérifie le bearer token auprès de Supabase Auth et exige un
  utilisateur UUID explicitement non anonyme.
- Le propriétaire envoyé à T0022 provient uniquement de cette réponse Auth.
- Le payload client contient exactement `companyName` et `idempotencyKey` ; tout
  champ propriétaire, montant, devise ou inconnu est refusé.

### 2. Autorité et validation

- Le nom doit être NFC, déjà trimé et contenir 2 à 80 caractères.
- La clé doit être un UUID canonique ; le corps est borné à 4 Kio.
- Montant et devise proviennent exclusivement de
  `COMPANY_OPENING_BALANCE_MINOR` et `COMPANY_OPENING_CURRENCY`, validés selon
  les bornes T0020.
- `SUPABASE_SERVICE_ROLE_KEY` sert uniquement à l’appel RPC interne et n’est ni
  renvoyée, ni journalisée, ni acceptée depuis la requête.

### 3. Réponses et reprise

- Un succès restitue la réponse versionnée T0022 ; un rejeu rend les mêmes
  identifiants.
- Les réponses sont JSON et `no-store`.
- Les erreurs Auth, configuration, transport, métier ou réponse privilégiée
  invalide échouent fermées avec un message public borné, sans détail SQL.

### 4. Runtime et preuves

- L’Edge Runtime local est chargé dans le daemon isolé T0021 sans nouveau port
  hôte ; API, PostgreSQL et Studio restent les trois seules publications, sur
  `127.0.0.1`.
- Les valeurs locales `43000000`/`EUR` sont des fixtures synthétiques injectées
  côté serveur, pas une décision produit ou une valeur de production.
- Les tests Node sans dépendance tierce couvrent succès, rejeu contractuel,
  validation, Auth, autorité, redaction et fail-closed.
- Le gate backend détecte une dérive du propriétaire Auth ou du credential RPC.

## Non-goals

- appel depuis le desktop, CORS applicatif ou écran d’onboarding ;
- choix du montant/devise par le client ou fixation de leur valeur de production ;
- inscription, connexion, refresh, MFA ou gestion de session ;
- déploiement Edge distant, staging ou production ;
- modification de la transaction T0022 ou nouvelle variation économique ;
- clôture des checklists humaines T0018–T0020.

## Acceptance criteria

- [x] L’endpoint vérifie une session non anonyme et dérive le propriétaire de
      Supabase Auth.
- [x] Le client ne peut fournir que le nom et la clé d’idempotence ; la politique
      économique et `service_role` restent côté serveur.
- [x] Succès et rejeu rendent la même réponse T0022 ; un refus backend ou une
      réponse privilégiée invalide échoue sans détail interne.
- [x] Treize tests de handler et onze mutations statiques backend passent.
- [x] Deux resets, 10 fichiers/190 assertions et les types passent avec l’Edge
      Runtime chargé sur PostgreSQL 17 local.
- [x] Une intégration réelle Auth → Edge → RPC crée `1|1|1`, rejoue les mêmes
      identifiants et refuse une requête sans JWT.
- [x] La documentation distingue branche empilée, fixture locale et capacité
      livrée dans `main`.

## Security review

- actifs/données : JWT utilisateur, UUID Auth, nom de compagnie, clé
  d’idempotence, politique d’ouverture et credential `service_role` ;
- frontière : client non fiable → gate JWT/Edge Function → Auth → RPC T0022 ;
- abus : propriétaire/montant/devise forgés, JWT anonyme/invalide, corps géant,
  collision, rejeu, credential exposé et erreur SQL divulguée ;
- validation/autorisation : payload exact, 4 Kio, Auth distante, UUID canonique,
  configuration serveur bornée et RPC privilégiée ;
- atomicité/idempotence : la fonction ne fractionne pas T0022 et transmet la
  même clé à sa transaction ;
- logs/vie privée : aucun log applicatif, réponse `no-store`, aucune clé, JWT,
  adresse email ou erreur SQL dans les réponses.

## Automated validation

```powershell
pnpm backend:functions:test
pnpm backend:check
pnpm data-policy:check
pnpm backend:start
pnpm backend:reset
pnpm backend:reset
pnpm backend:test
pnpm backend:types:check
pnpm backend:stop
git diff --check
```

## Manual verification

1. Démarrer la pile isolée et confirmer trois publications `127.0.0.1`.
2. Créer une identité/session synthétique et appeler l’Edge Function avec un JWT
   local, un nom et une clé UUID.
3. Rejouer la même requête et confirmer les mêmes identifiants ainsi que l’état
   `1|1|1` en base.
4. Appeler sans JWT et confirmer HTTP 401 sans détail interne.
5. Arrêter la pile et confirmer le nettoyage borné du runtime.

Temps cible : 10 minutes hors téléchargement initial de l’image Edge Runtime.

## Rollback

Avant fusion, abandonner la branche. La pile locale est jetable et se ferme avec
`pnpm backend:stop`; aucun fichier `.env`, secret ou état utilisateur réel ne doit
être conservé. Après fusion, retirer l’endpoint par un ticket dédié sans rouvrir
la mutation directe de `companies` ni modifier les migrations append-only.

## Completion Report

### Summary

Implémentation terminée le 1er août 2026. L’Edge Function authentifie la session,
borne strictement le payload et appelle T0022 avec un propriétaire dérivé d’Auth
et une politique économique exclusivement serveur. Le ticket passe en `Review`
sur une branche empilée ; rien de T0020–T0023 n’est revendiqué dans `main`.

### Files changed

- handler Edge, point d’entrée Deno, package ESM local et 13 tests ;
- configuration Edge Runtime et fixtures synthétiques locales/CI ;
- scripts de runtime/CI et gate backend étendu à T0023/11 mutations ;
- architecture, sécurité, qualité, état courant, ticket et index.

### Commands and results

- premier `node --test` — échec utile : propriété de paramètre TypeScript non
  supportée par le mode strip-only Node ; corrigée sans dépendance ;
- second test — 10/11, fixture UUID uniquement numérique ne testant pas la casse ;
  fixture corrigée ;
- `pnpm.cmd backend:functions:test` — réussi, 13/13 ;
- `pnpm.cmd backend:check` — réussi, T0012–T0023 et 11 mutations ;
- `pnpm.cmd data-policy:check` — réussi, 6 mutations ;
- premier `backend:start` — bloqué : Docker Desktop installé mais arrêté ;
  `docker desktop start` a démarré le moteur ;
- `backend:start`, deux `backend:reset`, `backend:test`,
  `backend:types:check` — réussis, Edge Runtime chargé, 10 fichiers/190
  assertions, `Result: PASS`, types stables ;
- intégration loopback avec JWT/session synthétiques — réussie : réponse v1
  active, rejeu avec mêmes IDs et état `1|1|1` ;
- appel sans JWT — HTTP 401 ; trois bindings externes IPv4 loopback ;
- premier redémarrage de contrôle — a révélé que `supabase stop` conservait par
  défaut la base synthétique dans le volume annoncé comme cache d'images ; cause
  confirmée et arrêt corrigé avec `--no-backup` ;
- mutation statique et arrêt/redémarrage après correction — réussis : l'identité
  et la compagnie synthétiques sont absentes (`0|0`) tandis que le cache d'images
  reste réutilisable ;
- `git diff --check` — réussi avant finalisation ;
- `pnpm ci:backend` — non exécuté localement, car le script exige Linux ; preuve
  GitHub attendue sur la PR.

### Manual verification result

Réussie sur Docker Desktop 29.6.2 et PostgreSQL 17 locaux, avec identité, session,
JWT, compagnie et écriture exclusivement synthétiques. Le runtime Edge réel a
servi la fonction, Auth a validé la session, le rejeu a conservé les mêmes IDs et
la base contient exactement une compagnie, une commande et une ouverture. Après
l'arrêt `--no-backup` et un redémarrage, l'identité et la compagnie de contrôle
sont toutes deux absentes.

### Risks and limitations

- branche empilée sur T0022 ; `origin/main` ne contient pas T0020–T0023 ;
- fixtures locales `43000000`/`EUR` sans valeur normative pour la production ;
- aucun CORS/appel desktop, déploiement distant ou parcours Auth utilisateur ;
- le runtime fourni par Supabase CLI 2.109.1 utilise Deno 2.1.4/Edge Runtime
  1.74.2 localement ; aucune parité cloud n’est prouvée ;
- aucune donnée réelle n’est admise.

### Follow-ups

- propager T0020–T0022 jusqu’à `main`, puis T0023 après revue ;
- exécuter séparément les checklists humaines T0018–T0020 ;
- décider la politique économique de production avant tout déploiement ;
- créer un ticket desktop/auth séparé avant de consommer l’endpoint.

### Documentation updated

- `ARCHITECTURE.md`, `SECURITY.md`, `QUALITY.md` et `SETUP.md` décrivent la
  frontière, le runtime et ses preuves ;
- `CURRENT_STATE.md` distingue branche empilée, runtime local et `main` ;
- `docs/tickets/README.md` synchronise T0023 en `Review`.

### Git status

- branche : `feature/T0023-authoritative-onboarding-endpoint` ;
- base : `feature/T0022-authoritative-company-onboarding` ;
- commit d'implémentation : `fd2b3fc` ;
- PR : #38, brouillon, base `feature/T0022-authoritative-company-onboarding`,
  head `feature/T0023-authoritative-onboarding-endpoint` ;
- dépendance : T0020–T0022 doivent encore être propagés jusqu'à `main` ;
- fusion : exclusivement réservée à Andy.
