# T0022 — Créer une compagnie et ouvrir son grand livre atomiquement

Status: Review
Owner: Andy
Branch: `feature/T0022-authoritative-company-onboarding`
Phase: 2
Risk: High
Security-sensitive: Yes

## Goal

Fournir une commande serveur unique qui crée une compagnie solo et son écriture
d'ouverture de façon transactionnelle et idempotente, puis retirer aux rôles
clients toute mutation directe de `public.companies`.

## Context

T0012 autorise encore `authenticated` à insérer, modifier et supprimer
directement sa ligne de compagnie. La RLS isole correctement A et B, mais cette
surface contourne une commande métier autoritaire et permet de créer une
compagnie sans ouverture financière. T0020 fournit déjà un sujet financier
opaque, une écriture `opening_balance` immuable et une commande réservée à
`service_role`.

T0022 assemble ces primitives dans une transaction : le serveur désigne
l'identité Auth, valide le nom, le montant et la devise, crée la compagnie puis
son ouverture. Le desktop, le bridge, `anon` et `authenticated` conservent une
lecture isolée mais ne peuvent créer, renommer ou supprimer directement une
compagnie. La suppression reste exclusivement le cycle récupérable T0018.

La branche part de `feature/T0020-immutable-ledger`, qui contient T0021 après la
fusion empilée de la PR #33. Au 31 juillet 2026, `main` contient T0018 mais pas
encore T0019–T0021 ; la PR T0022 doit donc rester empilée jusqu'à propagation de
ces branches.

Références :

- `docs/PRODUCT.md` ;
- `docs/ARCHITECTURE.md` ;
- `docs/SECURITY.md` ;
- `docs/ROADMAP.md` ;
- `docs/tickets/T0018-export-suppression-compte.md` ;
- `docs/tickets/T0020-grand-livre-immuable.md` ;
- `docs/tickets/T0021-isoler-supabase-local-windows.md`.

## Dependencies

- T0018 — cycle de suppression autoritaire (`Verify`, implémentation fusionnée
  dans `main`) ;
- T0020 — grand livre immuable (`Verify`, implémentation dans l'ascendance) ;
- T0021 — runtime PostgreSQL 17 Windows loopback (`Review`, implémentation dans
  la branche parente) ;
- phase 2 active sans donnée utilisateur réelle.

## Allowed areas

- `supabase/migrations/` — une nouvelle migration append-only uniquement ;
- `supabase/tests/database/` — pgTAP T0022 et adaptation des attentes de
  mutation devenues obsolètes ;
- `packages/database/src/database.types.ts` — types régénérés ;
- `tests/backend/run.ps1` et `scripts/ci/test-backend.ps1` — invariants,
  mutations négatives et concurrence ;
- `docs/ARCHITECTURE.md`, `docs/SECURITY.md`, `docs/QUALITY.md`,
  `docs/CURRENT_STATE.md` ;
- ce ticket et `docs/tickets/README.md`.

## Do not touch

- migrations T0012 et T0018–T0020 existantes ;
- `supabase/seed.sql` ;
- `apps/desktop/`, `apps/bridge/`, SimConnect et contrat local ;
- flotte, dispatch, vols, revenus, coûts, taxes, progression ou clôture de vol ;
- modèle de devise par compagnie, conversion ou comptabilité en partie double ;
- projet Supabase distant, staging, production, secrets ou données réelles ;
- workflows GitHub et permissions CI.

## Requirements

### 1. Commande serveur autoritaire

- `create_company_with_opening_balance` est exécutable uniquement par
  `service_role` et possède un `search_path` vide.
- L'identité propriétaire est fournie par la frontière serveur privilégiée ; la
  commande verrouille et vérifie une identité Auth non anonyme existante.
- Le nom est non nul, déjà normalisé, long de 2 à 80 caractères et ne permet pas
  au client de choisir le propriétaire effectif.
- Le montant et la devise suivent exactement les bornes T0020 et proviennent de
  l'autorité serveur, jamais d'un rôle client.

### 2. Atomicité et idempotence

- Une seule transaction crée la compagnie, les sujets privés T0019/T0020 et
  l'écriture `opening_balance`.
- Chaque commande porte une clé UUID liée au propriétaire et à l'intégralité du
  payload normalisé.
- Un rejeu strictement identique rend la même réponse et les mêmes identifiants.
- Une même clé avec un nom, montant ou devise différent échoue sans mutation.
- Deux appels concurrents identiques convergent vers une compagnie et une
  écriture ; deux clés concurrentes ne créent jamais deux compagnies.
- Une erreur injectée après l'insertion de la compagnie annule aussi sujets,
  commande et écriture.

### 3. Surface cliente minimale

- `authenticated` conserve uniquement `select` sur sa propre compagnie.
- `insert`, `update` et `delete` directs sont révoqués et leurs politiques sont
  retirées ; `anon` conserve zéro privilège.
- La suppression passe par T0018 et aucune commande de renommage n'est ajoutée.
- Les fonctions internes et la table d'idempotence restent inaccessibles aux
  rôles API.

### 4. Preuves

- Les pgTAP couvrent structure, privilèges, succès, rejeu, collision, A/B,
  anonyme, compte en suppression, rollback et invariants financiers.
- Le harnais CI prouve la convergence de deux sessions PostgreSQL 17.
- Deux resets, tous les pgTAP découverts et les types générés sont stables.
- Toutes les identités et compagnies restent synthétiques.

## Non-goals

- appel depuis le desktop, Edge Function ou onboarding UI ;
- renommage de compagnie ou choix de règles de nom avancées ;
- deuxième type d'écriture financière, revenu, coût ou solde matérialisé ;
- admission de données réelles ou provisionnement distant ;
- clôture des checklists humaines T0018–T0020.

## Acceptance criteria

- [x] Une migration append-only ajoute la commande et son registre privé sans
      modifier les migrations précédentes.
- [x] Seul `service_role` peut créer une compagnie avec ouverture ; les rôles
      clients ne peuvent muter directement `companies`.
- [x] Succès, rejeu identique, collision de payload, deuxième compagnie et
      concurrence convergent sans état partiel.
- [x] Une panne injectée laisse zéro compagnie, sujet, commande et écriture.
- [x] Une identité absente/anonyme ou en suppression est refusée ; A, B et
      l'anonyme restent isolés en lecture.
- [x] Deux resets, pgTAP, concurrence et types passent sur PostgreSQL 17 local
      et les gates statiques détectent une réouverture de la mutation cliente.
- [x] La documentation distingue implémentation empilée, validation locale et
      capacité réellement livrée dans `main`.

## Security review

- actifs/données : identité Auth, compagnie, sujet financier, écriture
  d'ouverture et registre temporaire d'idempotence ;
- frontière : service serveur privilégié vers transaction PostgreSQL ; clients
  distribués limités à la lecture RLS ;
- abus : propriétaire forgé, identité anonyme, double compagnie, collision de
  clé, course, ouverture sans compagnie et mutation directe ;
- validation/autorisation : exécution `service_role` seule, identité verrouillée,
  payload borné et privilèges minimaux ;
- atomicité/idempotence : transaction unique, verrou propriétaire, empreinte du
  payload et rollback injecté ;
- logs/vie privée : aucune journalisation ; registre privé supprimé avec
  l'identité Auth et sans email, JWT ou secret.

## Automated validation

```powershell
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

1. Sur PostgreSQL 17 local synthétique, créer une identité puis appeler la
   commande avec `service_role`.
2. Rejouer la même clé, tenter une collision de payload et une deuxième clé.
3. Vérifier la compagnie, le sujet et l'unique écriture, puis les lectures A/B.
4. Tenter `insert/update/delete` avec `authenticated` et l'appel avec `anon`.
5. Injecter l'erreur de test et confirmer l'absence totale d'état partiel.

Temps cible : 10 minutes.

## Rollback

Avant fusion, abandonner la branche. Sur une pile locale jetable, recréer la
base depuis zéro. Après fusion, ne jamais modifier ni supprimer la migration :
toute correction utilise une nouvelle migration append-only. Aucune opération
de rollback n'est autorisée sur des données réelles.

## Completion Report

### Summary

Implémentation terminée le 31 juillet 2026. La migration append-only ajoute une
commande d'onboarding réservée à `service_role`, un registre privé
d'idempotence et la création atomique de la compagnie avec son ouverture T0020.
`authenticated` conserve uniquement la lecture RLS. Le ticket passe en
`Review`; la branche reste empilée et aucune capacité T0022 n'est dans `main`.

### Files changed

- migration `20260731000400_authoritative_company_onboarding.sql` ;
- pgTAP `company_onboarding_structure.test.sql` et
  `company_onboarding.test.sql` ;
- attentes historiques T0012/T0018 adaptées à la révocation des mutations ;
- types de base, gate backend et concurrence CI ;
- architecture, sécurité, qualité, état courant et index des tickets.

### Commands and results

- `pnpm backend:check` — réussi : dépôt T0012–T0022 et 8 mutations négatives ;
- `pnpm data-policy:check` — réussi : dépôt T0017–T0020 et 6 mutations
  négatives ;
- premier cycle `backend:start/reset/reset/test/types:check` — migrations
  appliquées deux fois, puis pgTAP en échec sur trois attentes historiques et un
  contexte `service_role`; aucun défaut de migration ;
- après correction et recopie du volume T0021 : `pnpm backend:stop`,
  `backend:start`, deux `backend:reset`, `backend:test` et
  `backend:types:check` — réussis, 10 fichiers, 190 assertions,
  `Result: PASS`, types stables ;
- deux sessions PostgreSQL 17 concurrentes — réussi : même `companyId`, état
  `1|1|1` (compagnie, commande, écriture) ;
- checklist SQL séparée — réussie : rejeu identique, collision et mutation
  directe refusées, rollback injecté propre, état `1|1|1|0|0` ;
- `git diff --check` — réussi avant finalisation ;
- `pnpm ci:backend` — non exécuté localement : le harnais exige explicitement
  Linux ; la PR doit fournir cette preuve CI.

### Manual verification result

Réussie sur la pile PostgreSQL 17 locale isolée avec identités synthétiques. La
création et le rejeu rendent la même compagnie ; la collision de payload et la
mutation `authenticated` échouent ; une erreur injectée pendant l'ouverture ne
laisse ni compagnie ni commande. Les lectures A/B/anonyme et le compte en
suppression sont aussi couverts par pgTAP.

### Risks and limitations

- branche empilée sur T0021 ; T0019–T0021 ne sont pas encore dans `main` ;
- aucun appelant Edge Function, desktop ou bridge n'est livré ;
- le montant initial et la devise restent fournis par une future autorité
  serveur et ne sont pas des choix clients ;
- renommage, deuxième variation financière et solde matérialisé restent hors
  périmètre ;
- aucune donnée réelle, staging, production ou sauvegarde managée n'est admise.

### Follow-ups

- faire passer les PR de propagation #34–#36 dans l'ordre ;
- exécuter les checklists humaines T0018–T0020 ;
- ajouter un appelant serveur explicite avant toute UX d'onboarding ;
- créer un ticket séparé avant toute deuxième variation économique.

### Documentation updated

- `docs/ARCHITECTURE.md` et `docs/SECURITY.md` décrivent la nouvelle frontière ;
- `docs/QUALITY.md` donne les compteurs et gates actifs ;
- `docs/CURRENT_STATE.md` distingue preuve locale, pile de PR et `main` ;
- `docs/tickets/README.md` synchronise le statut `Review`.

### Git status

- branche : `feature/T0022-authoritative-company-onboarding` ;
- commit d'implémentation : `31335c2` ;
- PR : #37, brouillon, base `feature/T0020-immutable-ledger`, head
  `feature/T0022-authoritative-company-onboarding` ;
- dépendances : PR brouillon #34 (T0019), #35 (T0020) puis #36 (T0021) avant
  propagation vers `main` ;
- fusion : exclusivement réservée à Andy.
