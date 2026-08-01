# T0020 — Ouvrir un grand livre financier immuable

Status: Done
Owner: Andy
Branch: `feature/T0020-immutable-ledger-verify`
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
fournissent le cycle de suppression et son replay ; ces trois tickets sont
désormais `Done` dans `main`.

Cette première tranche ne choisit pas encore toute l'économie du jeu. Elle
enregistre uniquement une ouverture de compagnie, dans une devise ISO 4217 et
un montant en unités mineures fournis par l'autorité serveur. La commande est
réservée à `service_role`; le desktop, le bridge, `anon` et `authenticated` ne
peuvent pas créer une variation. Le propriétaire peut seulement lire ses
écritures par une fonction bornée.

Le lien compagnie–grand livre est privé et pseudonyme. La suppression d'une
compagnie efface ce lien dans la même transaction sans modifier les écritures,
qui ne conservent ni identité Auth, ni nom de compagnie. L'implémentation a été
historiquement empilée sur T0019 ; la pile complète a été livrée dans `main` par
la PR #41.

Références :

- `docs/PRODUCT.md` ;
- `docs/ARCHITECTURE.md` ;
- `docs/SECURITY.md` ;
- `docs/DATA_POLICY.md` ;
- `docs/QUALITY.md` ;
- `docs/tickets/T0018-export-suppression-compte.md` ;
- `docs/tickets/T0019-restauration-isolee-replay-suppressions.md`.

## Dependencies

- T0012 — PostgreSQL 17 et RLS (`Done`, dans `main`) ;
- T0017 — politique de données (`Done`) ;
- T0018–T0019 — suppression et replay (`Done`, dans `main`).

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

- [x] Une migration append-only crée sujets privés, écritures immuables et
      fonctions à `search_path` vide.
- [x] Seul `service_role` peut créer l'ouverture ; aucun rôle client ne peut
      muter directement le grand livre.
- [x] Rejeu identique, collision de payload, deuxième ouverture, concurrence et
      rollback sont couverts.
- [x] Les lectures A/B/anonyme et le blocage `deletion_pending` sont prouvés.
- [x] La suppression et le replay détachent le lien personnel sans modifier ni
      supprimer les écritures.
- [x] Deux resets, tous les pgTAP découverts et les types générés passent sur
      PostgreSQL 17 CI.
- [x] La politique marque l'anonymisation du grand livre comme prouvée seulement
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

### Summary

Implémentation et validations automatisées terminées le 31 juillet 2026. Une
commande réservée à `service_role` ouvre le grand livre de façon
transactionnelle/idempotente ; les rôles clients ne peuvent pas écrire et le
propriétaire lit uniquement son historique. La suppression et son replay
détachent le lien personnel sans modifier les écritures.

Le ticket passe en `Verify` sur la PR brouillon empilée #32. La checklist
Windows reste impossible car `KI-017` déclenche correctement l'arrêt fail-safe
de la pile locale.

### Files changed

- migration append-only
  `supabase/migrations/20260731000300_immutable_financial_ledger.sql` ;
- pgTAP `financial_ledger_structure.test.sql` et
  `financial_ledger.test.sql` ;
- harnais backend, concurrence CI, types générés et politique de données ;
- documents architecture, sécurité, qualité, état et suivi.

### Commands and results

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
  rôle `service_role`, correctement privé d'accès direct à `private`; corrigé
  sans élargir aucun grant ;
- second run CI `30628549511` — 8 fichiers/148 assertions `PASS`, concurrence
  T0018 et T0020 réussie, restauration/replay réussi ; seul le contrôle des
  types signale l'ordre canonique des fonctions et `Args: never`; corrigé avec
  la sortie exacte du générateur ;
- run final CI `30628851680`, job `Supabase PostgreSQL 17` — réussi : 2 resets,
  8 fichiers pgTAP, 148 assertions, `Result: PASS`, deux sessions concurrentes
  vers une écriture immuable, restauration/replay T0019 et types stables ;
- exercice restauré du même run — réussi : dump 140 ms, restauration 254 ms,
  replay 66 ms, A absent, B préservé et données réelles absentes ; ces durées ne
  sont pas des objectifs RPO/RTO ;
- `pnpm frontend:typecheck` — réussi après synchronisation des types ;
- run `30628851680`, job `Windows multi-stack` — réussi : toolchain, politique,
  frontend, desktop, bridge, budgets et package Windows non signé ;
- run supply-chain `30628851756` — réussi : audits, licences et SBOM ;
- `git diff --check` et `git diff --cached --check` — réussis avant publication.

### Manual verification result

Non exécutée sur Windows. `pnpm backend:start` reproduit `KI-017` et arrête la
pile exposée ; les scénarios sont automatisés sur PostgreSQL 17 CI mais ne sont
pas requalifiés en vérification manuelle. Le ticket reste `Verify`.

### Risks and limitations

- la capacité est dans `main`, mais aucune politique économique de production
  n'est encore décidée ;
- une seule écriture `opening_balance`, sans partie double, revenus, coûts,
  achat, clôture de vol ou solde matérialisé ;
- montant et devise viennent d'une autorité serveur future, jamais d'un client
  distribué dans cette tranche ;
- l'export financier T0018 version 2 n'est pas implémenté ;
- aucune donnée réelle, staging, production ou sauvegarde managée n'est admise.

### Follow-ups

- créer un ticket séparé avant toute deuxième commande économique ou export
  financier version 2.

### Documentation updated

- `eng/data-policy.json` marque l'anonymisation du grand livre uniquement
  `enforced-local-ci` ;
- `docs/ARCHITECTURE.md`, `docs/SECURITY.md`, `docs/DATA_POLICY.md` et
  `docs/QUALITY.md` décrivent la frontière et ses limites ;
- `docs/CURRENT_STATE.md` et l'index distinguent branche, CI et vérification
  manuelle.

### Git and PR

- branche : `feature/T0020-immutable-ledger` ;
- PR #32 : fusionnée dans sa branche parente ; pile livrée dans `main` par la PR
  #41 ;
- checks publiés : PostgreSQL 17 et Windows multi-stack verts sur
  `30628851680`, supply-chain verte sur `30628851756`.

### Mise à jour T0021 — 31 juillet 2026

`KI-017` est résolu. Deux resets, les 8 fichiers/148 assertions incluant T0020
et le contrôle des types passent dans le runtime Windows isolé. Cette preuve
automatisée locale ne remplace pas la checklist humaine du grand livre ; T0020
reste `Verify`.

### Clôture — 1er août 2026

La checklist humaine est exécutée sur Windows 11 avec Docker Desktop 29.6.2 et
le runtime T0021 exclusivement lié à `127.0.0.1`. Le parcours utilise les deux
seeds et deux identités `.invalid` supplémentaires, toutes synthétiques.

Validations de référence :

- `pnpm.cmd backend:check` — réussi, T0012–T0023 et 11 mutations négatives ;
- `pnpm.cmd data-policy:check` — réussi, T0017–T0020 et 6 mutations négatives ;
- `pnpm.cmd backend:start` — réussi sur IPv4 loopback ;
- deux `pnpm.cmd backend:reset` — réussis, cinq migrations append-only rejouées ;
- `pnpm.cmd backend:test` — réussi, 10 fichiers, 190 assertions,
  `Result: PASS` ;
- `pnpm.cmd backend:types:check` — réussi, types identiques au schéma local ;
- `pnpm.cmd backend:stop` — réussi sans sauvegarde ; seul le cache d'images sans
  sources est conservé.

Résultat manuel :

- deux compagnies reçoivent chacune un sujet financier opaque ;
- ouverture A `100000|EUR`, rejeu stable sur la séquence `1`, collision de
  payload et deuxième ouverture refusées ;
- ouverture B `-5000|USD` ; exactement deux écritures sont créées ;
- `update`, `delete` et `truncate` sont tous refusés par la règle append-only ;
- A lit uniquement `100000|EUR`, B uniquement `-5000|USD`, et `anon` ne peut
  pas appeler la lecture ;
- après demande de suppression A, une nouvelle mutation financière est refusée ;
- après finalisation, A vaut `0|0|0|0` pour identité, compagnie, demande et
  commandes ; son sujet est détaché/daté et son écriture `100000|EUR` reste
  unique ; B reste `1|1`, les deux écritures subsistent et aucune colonne
  d'identité directe n'existe dans le grand livre.

Tous les critères T0020 sont satisfaits ; le ticket passe à `Done`. Cette preuve
n'autorise aucune valeur économique de production, deuxième variation, solde
matérialisé, export financier v2, donnée réelle ou environnement distant.
