# T0012 — Créer Supabase local et les tests RLS

Status: Verify
Owner: Andy
Branch: `foundation/t0012-supabase-local-rls`
Phase: 1
Risk: High
Security-sensitive: Yes

## Goal

Fournir un backend Supabase local jetable, recréable depuis le dépôt et doté de
preuves automatisées que les données d'une compagnie ne sont accessibles qu'à
leur propriétaire pour les rôles authentifié et anonyme.

## Context

T0006 a livré la toolchain du nouveau dépôt et son implémentation est fusionnée
dans `main`. T0006 reste `Verify` uniquement parce que sa preuve humaine depuis
un clone Windows 11 vierge manque ; cette limite ne bloque pas la capacité
technique nécessaire à T0012. `docs/CURRENT_STATE.md` recommande explicitement
T0012 comme prochain ticket indépendant de la vérification MSFS de T0011.

ADR-0001 impose un MVP solo : un utilisateur possède au plus une compagnie et
une compagnie a exactement un propriétaire humain. ADR-0002 impose un schéma
Supabase neuf, sans copie de l'ancien backend ni migration des données de
développement. ADR-0004 retient Supabase CLI 2.109.1, PostgreSQL 17, des
migrations append-only, pgTAP et les scénarios A/B/anonyme.

La machine d'implémentation ne possède initialement ni Docker ni CLI Supabase.
L'implémentation doit donc distinguer les validations statiques exécutables des
preuves locales qui exigent le runtime Docker.

## Dependencies

- implémentation fusionnée de T0006 ;
- `docs/decisions/ADR-0001-modele-produit.md` ;
- `docs/decisions/ADR-0002-strategie-de-refonte.md` ;
- `docs/decisions/ADR-0004-stack-cible.md` ;
- Docker Desktop ou un runtime Docker compatible pour la vérification locale.

## Allowed areas

- `package.json` et `pnpm-lock.yaml` ;
- `.gitignore` ;
- `supabase/` ;
- `packages/database/` pour les types générés ;
- `scripts/` pour un contrôle statique borné au backend ;
- `tests/backend/` ;
- `docs/ARCHITECTURE.md` ;
- `docs/SECURITY.md` ;
- `docs/QUALITY.md` ;
- `docs/SETUP.md` ;
- `docs/CURRENT_STATE.md` ;
- `docs/KNOWN_ISSUES.md` ;
- ce ticket et `docs/tickets/README.md`.

## Do not touch

- `apps/desktop/` et ses capabilities/CSP ;
- `apps/bridge/`, SimConnect et le contrat local ;
- `tests/bridge/`, `tests/desktop-shell/` et `tests/traces/` ;
- économie, flotte, dispatch, vols, grand livre ou opérations passives ;
- projet Supabase distant, secrets, `.env` et identifiants réels ;
- Edge Functions, Realtime, Storage et client Supabase React ;
- workflows CI, packaging, signature et updater ;
- migrations ou données de l'ancien dépôt ;
- installation globale de Docker, de la CLI ou d'un autre outil.

## Requirements

### 1. Épingler la CLI et les commandes

- Ajouter `supabase` 2.109.1 comme dépendance de développement racine exacte.
- Exposer des scripts racine explicites pour démarrer, arrêter, réinitialiser,
  tester et générer les types depuis la pile locale.
- Les commandes destructrices doivent cibler explicitement l'instance locale ;
  aucune commande ne doit lier, pousser ou réinitialiser un projet distant.
- Le lockfile doit être généré par pnpm 11.17.0.

### 2. Configurer une pile locale jetable

- Versionner `supabase/config.toml` sans secret.
- Utiliser PostgreSQL major 17 fourni par la CLI Supabase.
- Publier les ports Docker sur `127.0.0.1` uniquement.
- Désactiver les services hors périmètre quand la configuration le permet, sans
  fabriquer une pile différente de celle requise par Auth/PostgREST/RLS.
- Versionner les chemins de migrations, seed et tests.
- Ignorer uniquement l'état local éphémère produit par la CLI.

### 3. Créer le schéma initial

- Ajouter une migration append-only créant `public.companies`.
- Une compagnie a un UUID, un `owner_id` non nul, un nom borné et des dates
  contrôlées.
- `owner_id` référence `auth.users(id)` et est unique afin d'imposer au plus une
  compagnie par utilisateur.
- Activer et forcer la RLS.
- Révoquer les privilèges inutiles puis accorder uniquement les opérations
  nécessaires aux rôles `authenticated`.
- Les politiques `select`, `insert`, `update` et `delete` reposent uniquement sur
  `auth.uid() = owner_id`.
- Aucun rôle client ne peut choisir ou contourner une autorité métier.

### 4. Fournir des données synthétiques

- Le seed ne contient que des identités et compagnies fictives stables.
- Il est rejouable après chaque reset et ne contient ni donnée personnelle, ni
  secret, ni donnée de l'ancien dépôt.
- Les identifiants de test sont réservés et documentés comme synthétiques.

### 5. Prouver la structure et la RLS

- Ajouter des tests pgTAP transactionnels et indépendants du seed.
- Prouver la présence de la table, des contraintes, de la RLS forcée et des
  politiques attendues.
- Prouver qu'A peut lire et modifier sa compagnie mais pas celle de B.
- Prouver que B ne peut ni lire, ni modifier, ni supprimer la compagnie d'A et
  ne peut pas créer une compagnie attribuée à A.
- Prouver que le rôle anonyme ne peut lire ni écrire.
- Prouver qu'un propriétaire ne peut posséder deux compagnies.
- Les tests doivent revenir en arrière et ne pas laisser d'état.

### 6. Contrôler le dépôt sans Docker

- Ajouter un harnais PowerShell déterministe qui vérifie version, chemins,
  absence de commande distante, ordre migration/seed, invariants de sécurité et
  présence des scénarios A/B/anonyme.
- Le harnais ne remplace pas `supabase db reset --local` ni
  `supabase test db`.
- Les erreurs ne doivent afficher ni contenu de ligne sensible, ni variable
  d'environnement.

### 7. Générer et contrôler les types

- Versionner les types TypeScript générés depuis le schéma local sous
  `packages/database/`.
- Documenter et scripter leur régénération.
- Une régénération doit permettre de détecter un diff non committé.

### 8. Documenter la frontière

- Documenter setup, commandes, ports locaux et prérequis Docker sans recopier
  de secret.
- Documenter que RLS est une défense serveur, que le client distribué est non
  fiable et que les futures mutations sensibles resteront transactionnelles et
  idempotentes côté serveur.
- Documenter l'écart possible entre pile locale et cloud PostgreSQL 17.

## Non-goals

- Implémenter l'onboarding complet.
- Ajouter un SDK Supabase au frontend.
- Définir le modèle économique ou un grand livre.
- Déployer ou lier un projet Supabase distant.
- Ajouter une CI backend ; T0013 en est responsable.
- Prouver la parité complète entre la pile locale et Supabase managé.
- Installer Docker sur la machine.

## Acceptance criteria

- [x] La CLI Supabase 2.109.1 est épinglée avec un lockfile figé.
- [ ] La pile locale PostgreSQL 17 est recréable depuis les fichiers versionnés.
- [x] La migration impose un propriétaire unique et une RLS forcée.
- [x] Le seed est synthétique et stable ; son rejeu réel reste à vérifier.
- [x] Les tests pgTAP couvrent structure, A, B, anonyme et unicité.
- [x] Le harnais statique échoue sur une politique manquante ou une commande
      distante.
- [ ] `supabase db reset --local` réussit depuis une pile vide.
- [ ] `supabase test db` réussit et découvre effectivement les tests.
- [ ] Les types TypeScript sont générés depuis le schéma local et sans diff.
- [x] Aucun secret, identifiant réel ou donnée de l'ancien dépôt n'est ajouté.
- [x] La documentation reflète les commandes et limites réellement vérifiées.
- [x] Le Completion Report distingue réussi, échoué et non exécuté.

## Security review

- actifs/données : identités, propriété de compagnie et futur accès aux données
  métier ;
- frontière : API Supabase publique vers PostgreSQL, rôles `anon` et
  `authenticated`, JWT transformé en `auth.uid()` ;
- abus : lecture croisée A/B, usurpation de `owner_id`, écriture anonyme,
  deuxième compagnie, privilège implicite, reset distant accidentel ;
- validation/autorisation : contraintes SQL, clé étrangère, unicité, RLS forcée,
  politiques par opération et tests négatifs ;
- atomicité/idempotence : le ticket ne crée qu'une table simple ; les futures
  commandes multi-écritures devront être des RPC transactionnelles et
  idempotentes ;
- logs/vie privée : uniquement des UUID et noms synthétiques ; aucun jeton,
  secret, JWT, contenu utilisateur ou variable d'environnement journalisé.

## Automated validation

```powershell
# Depuis la racine, PowerShell 7.6 et Docker actif
pnpm install --frozen-lockfile
pnpm backend:check
pnpm backend:start
pnpm backend:reset
pnpm backend:test
pnpm backend:types
git diff --exit-code -- packages/database/src/database.types.ts
pnpm backend:stop
git diff --check
```

`backend:test` doit exécuter au moins un fichier pgTAP et afficher un résultat
PASS. Un code 0 sans test découvert n'est pas une réussite.

## Manual verification

1. Démarrer Docker, puis `pnpm backend:start`.
2. Exécuter `pnpm backend:reset` deux fois et confirmer que le seed reste stable.
3. Exécuter `pnpm backend:test` et confirmer les scénarios A/B/anonyme.
4. Générer les types et confirmer l'absence de diff.
5. Vérifier dans Studio local que seules les identités synthétiques existent.
6. Arrêter avec `pnpm backend:stop`, puis redémarrer et rejouer le reset.

Temps cible : 10 minutes hors téléchargement initial des images Docker.

## Rollback

Abandonner la branche avant fusion. Après fusion, ouvrir un ticket de correction
avec une nouvelle migration append-only ; ne jamais modifier une migration déjà
appliquée sur un environnement partagé. La pile locale peut être arrêtée avec
`pnpm backend:stop`. Toute suppression de volumes reste une action locale,
explicite et séparée.

## Completion Report

### Summary

La fondation backend locale est implémentée : CLI épinglée, configuration
PostgreSQL 17, migration `companies`, seed synthétique, types TypeScript, deux
fichiers pgTAP et harnais statique avec mutations négatives. Le ticket reste
`Verify` parce que Docker est absent et que reset, pgTAP et régénération réelle
des types ne peuvent pas être prouvés sur cette machine.

### Files changed

- toolchain : `package.json`, `pnpm-lock.yaml` ;
- backend : `supabase/config.toml`, `.gitignore`, migration, seed et tests SQL ;
- contrat : `packages/database/` et script de génération ;
- qualité : `tests/backend/run.ps1` ;
- documentation : architecture, sécurité, qualité, setup, état actuel,
  problèmes connus, ticket et index.

### Commands and results

- `pnpm install --frozen-lockfile` : réussi avec pnpm 11.17.0, 231 entrées
  validées par les politiques supply-chain ;
- `pnpm supabase --version` : réussi, Supabase 2.109.1 ;
- `pnpm backend:check` : réussi ; dépôt réel et deux mutations détectées
  (politique de lecture supprimée, reset remplacé par `--linked`) ;
- `pnpm backend:start` : échoué proprement avant mutation, CLI Docker compatible
  absente ; un essai direct antérieur de la CLI Supabase avait également
  confirmé l'absence du pipe `docker_engine` après parsing de la configuration ;
- `pnpm backend:reset` : échoué, même prérequis Docker absent ;
- `pnpm backend:test` : échoué, aucune connexion PostgreSQL locale ; aucun test
  n'est annoncé comme exécuté ;
- `pnpm backend:types:check` : échoué, pile locale indisponible ;
- `pnpm frontend:typecheck` : réussi ;
- `pnpm frontend:test` : réussi, 3 fichiers et 8 tests ;
- `pnpm frontend:build` : réussi, build Vite ;
- `scripts/check-toolchain.ps1` et `tests/toolchain/run.ps1` : non exécutés,
  `pwsh` est un shim WindowsApps refusé et PowerShell 7 n'est pas installé sous
  `Program Files` dans cet environnement ;
- `git diff --check` : réussi.

### Manual verification result

Non exécutée. Docker Desktop, Rancher Desktop ou un runtime compatible n'est pas
installé/actif. Studio, le double reset, pgTAP et la stabilité des types restent
à vérifier.

### Risks and limitations

- Le SQL et les messages pgTAP exacts n'ont pas été exécutés par PostgreSQL.
- `database.types.ts` reflète le schéma attendu mais n'a pas encore été régénéré
  par la CLI ; `backend:types:check` doit en fournir la preuve.
- La pile locale ne prouve pas la parité avec un projet Supabase managé.
- T0006 reste `Verify` pour sa preuve clean-clone, sans bloquer la capacité
  technique utilisée ici.

### Follow-ups

- Démarrer un runtime Docker compatible.
- Exécuter deux fois `pnpm backend:reset`, puis `pnpm backend:test`.
- Exécuter `pnpm backend:types`, vérifier le diff, puis
  `pnpm backend:types:check`.
- Ne rendre T0012 `Done` qu'après ces preuves et la vérification manuelle.
- Garder T0013 en backlog jusque-là.

### Documentation updated

`ARCHITECTURE.md`, `SECURITY.md`, `QUALITY.md`, `SETUP.md`,
`CURRENT_STATE.md`, `KNOWN_ISSUES.md` et l'index des tickets décrivent la
capacité réellement livrée et ses limites.
