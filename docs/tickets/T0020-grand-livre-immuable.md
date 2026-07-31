# T0020 — Ouvrir un grand livre financier immuable

Status: In progress
Owner: Andy
Branch: `feature/T0020-immutable-ledger`
Phase: 2
Risk: High
Security-sensitive: Yes

## Goal

Créer la première tranche du grand livre financier autoritaire : une commande
serveur ouvre une position initiale de compagnie de façon transactionnelle et
idempotente, chaque variation produit une écriture immuable, et aucun client ne
peut écrire directement dans le grand livre.

## Context

La phase 2 exige qu'aucune variation financière n'existe sans écriture de grand
livre et qu'aucune mutation sensible directe ne soit exposée à un client
distribué. T0012 fournit PostgreSQL 17 et l'isolation RLS. T0018 et T0019
fournissent le cycle de suppression et son replay sur deux branches encore
empilées.

Cette première tranche ne choisit pas encore toute l'économie du jeu. Elle
enregistre uniquement une ouverture de compagnie, dans une devise ISO 4217 et
un montant en unités mineures fournis par l'autorité serveur. La commande est
réservée à `service_role`; le desktop, le bridge, `anon` et `authenticated` ne
peuvent pas créer une variation. Le propriétaire peut seulement lire ses
écritures par une fonction bornée.

Le lien compagnie–grand livre est privé et pseudonyme. La suppression d'une
compagnie efface ce lien dans la même transaction sans modifier les écritures,
qui ne conservent ni identité Auth, ni nom de compagnie. La branche est empilée
sur `security/T0019-isolated-restore-replay` jusqu'à intégration de T0018 et
T0019.

Références :

- `docs/PRODUCT.md` ;
- `docs/ARCHITECTURE.md` ;
- `docs/SECURITY.md` ;
- `docs/DATA_POLICY.md` ;
- `docs/QUALITY.md` ;
- `docs/tickets/T0018-export-suppression-compte.md` ;
- `docs/tickets/T0019-restauration-isolee-replay-suppressions.md`.

## Dependencies

- T0012 — PostgreSQL 17 et RLS (`Verify`, implémentation dans `main`) ;
- T0017 — politique de données (`Done`) ;
- T0018–T0019 — suppression et replay (`Verify`, implémentations présentes dans
  l'ascendance empilée).

## Allowed areas

- `supabase/migrations/` — une nouvelle migration append-only uniquement ;
- `supabase/tests/database/` — pgTAP T0020 ;
- `tests/backend/` et `scripts/ci/test-backend.ps1` — invariants, concurrence et
  compte exact des preuves ;
- `packages/database/src/database.types.ts` — types régénérés ;
- `eng/data-policy.json` et `tests/data-policy/` — anonymisation réellement
  prouvée ;
- `docs/ARCHITECTURE.md`, `docs/SECURITY.md`, `docs/DATA_POLICY.md`,
  `docs/QUALITY.md`, `docs/CURRENT_STATE.md`, `docs/KNOWN_ISSUES.md` ;
- ce ticket et `docs/tickets/README.md`.

## Do not touch

- migrations T0012, T0018 et T0019 existantes ;
- `supabase/seed.sql` ;
- `apps/desktop/`, `apps/bridge/`, SimConnect et contrat local ;
- flotte, vols, maintenance, réputation, progression ou clôture de vol ;
- projet Supabase distant, staging, production, secrets ou données réelles ;
- définition complète des revenus, coûts, taxes, prix ou monnaies du jeu ;
- workflows GitHub et permissions CI.

## Requirements

### 1. Sujet financier pseudonyme

- Chaque compagnie reçoit un sujet financier UUID opaque, créé côté serveur.
- La correspondance compagnie–sujet reste dans `private`, avec RLS activée et
  forcée et sans privilège pour `anon` ou `authenticated`.
- Une suppression T0018 ou un replay T0019 détache la compagnie et date
  l'anonymisation dans la même transaction.
- Les écritures conservées ne contiennent ni identité Auth, ni identifiant ou
  nom de compagnie.

### 2. Écritures append-only

- Une écriture contient un identifiant, le sujet opaque, une séquence monotone
  par sujet, une clé d'idempotence, le type versionné `opening_balance`, un
  montant signé en unités mineures, une devise ISO 4217 et des dates serveur.
- Montant nul, dépassement borné, devise invalide et date future sont refusés.
- `update`, `delete` et `truncate` des écritures sont refusés, y compris au rôle
  serveur utilisé par l'application.
- Une contrainte garantit une seule ouverture par sujet.

### 3. Commande autoritaire et idempotente

- `post_company_opening_balance` est exécutable uniquement par `service_role`.
- La commande verrouille la compagnie, refuse un compte en suppression et crée
  sujet et écriture dans une transaction.
- Le rejeu de la même clé et du même payload rend le même résultat.
- La même clé avec un payload différent et une deuxième ouverture sont refusées
  sans écriture partielle.
- Deux appels concurrents identiques convergent vers une seule écriture.

### 4. Lecture isolée

- `get_company_ledger` est exécutable par `authenticated`, jamais par `anon`.
- L'identité vient de `auth.uid()` ; aucun identifiant de compagnie fourni par
  le client ne sélectionne les données.
- A lit seulement A, B seulement B, et un compte en suppression ne peut plus
  recevoir d'écriture.

## Non-goals

- solde matérialisé, conversion de devise ou comptabilité en partie double ;
- revenus de vol, dépenses, achats, salaires, taxes ou clôture de vol ;
- commande économique appelée depuis le desktop ou le bridge ;
- export financier T0018 version 2 ou interface d'export ;
- purge générique, sauvegarde managée, staging, production ou données réelles ;
- admission d'une devise ou d'un montant choisi par un client non fiable.

## Acceptance criteria

- [ ] Une migration append-only crée sujets privés, écritures immuables et
      fonctions à `search_path` vide.
- [ ] Seul `service_role` peut créer l'ouverture ; aucun rôle client ne peut
      muter directement le grand livre.
- [ ] Rejeu identique, collision de payload, deuxième ouverture, concurrence et
      rollback sont couverts.
- [ ] Les lectures A/B/anonyme et le blocage `deletion_pending` sont prouvés.
- [ ] La suppression et le replay détachent le lien personnel sans modifier ni
      supprimer les écritures.
- [ ] Deux resets, tous les pgTAP découverts et les types générés passent sur
      PostgreSQL 17 CI.
- [ ] La politique marque l'anonymisation du grand livre comme prouvée seulement
      en local/CI synthétique ; l'admission de données réelles reste bloquée.

## Security review

- actifs : écritures économiques, montant, devise, identité de compagnie et clé
  d'idempotence ;
- frontière : futur backend autoritaire vers commande `service_role`, puis
  propriétaire authentifié vers lecture bornée ;
- abus : écriture client, double crédit, collision de clé, lecture de B,
  modification/suppression rétroactive, lien personnel conservé après
  suppression ;
- validation : rôle serveur, compagnie verrouillée, compte actif, formats et
  bornes SQL, fonctions security-definer à `search_path` vide ;
- atomicité/idempotence : verrou par compagnie, contraintes uniques et retour du
  résultat existant seulement après comparaison exacte ;
- vie privée : sujet aléatoire sans identité directe dans l'écriture, lien privé
  détaché par le cycle de suppression.

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
pnpm ci:backend
```

## Manual verification

1. Créer A et B synthétiques sur PostgreSQL 17 local.
2. Poster l'ouverture de A avec `service_role`, la rejouer puis tenter une
   collision de payload et une deuxième ouverture.
3. Vérifier que A lit son écriture, B ne la lit pas et `anon` ne peut appeler la
   lecture.
4. Placer A en suppression puis vérifier qu'aucune nouvelle écriture n'est
   admise.
5. Finaliser ou rejouer la suppression et confirmer que l'écriture reste
   inchangée tandis que le lien personnel est détaché.

Temps cible : 10 minutes.

## Rollback

Avant fusion, abandonner la branche. Après application sur une pile jetable,
recréer la pile depuis zéro. Une migration fusionnée n'est jamais modifiée ni
supprimée ; toute correction utilise une migration append-only. Aucun rollback
destructif n'est autorisé sur une pile contenant des données réelles.

## Completion Report

### État intermédiaire du 31 juillet 2026

La migration, les deux fichiers pgTAP, la concurrence CI, les types et les
gates statiques sont implémentés sur `feature/T0020-immutable-ledger`. Le ticket
reste `In progress` jusqu'à la preuve PostgreSQL 17 CI.

- `pnpm backend:check` — réussi : dépôt T0012/T0018/T0019/T0020 et 5 mutations
  négatives ;
- `pnpm data-policy:check` — réussi : dépôt T0017–T0020 et 6 mutations
  négatives ;
- analyse syntaxique PowerShell de `scripts/ci/test-backend.ps1` — réussie ;
- `git diff --check` — réussi ;
- `pnpm backend:start` — arrêt fail-safe attendu : Docker Desktop publie les
  ports hors loopback (`KI-017`), donc aucun pgTAP local n'est revendiqué.
- premier run CI `30628297597` — les deux resets et migrations réussissent,
  puis le test T0020 échoue car une assertion interne conserve volontairement le
  rôle `service_role`, correctement privé d'accès direct à `private`; correction
  du contexte de rôle en cours, sans élargir aucun grant.

La vérification manuelle Windows n'est pas exécutée. Aucune donnée réelle,
staging ou production n'est utilisée et aucune mutation économique n'est
exposée au desktop.
