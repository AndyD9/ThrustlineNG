# T0040 — Activer et valider Auth locale email/mot de passe

Status: Done
Owner: Andy
Branch: `fix/T0040-enable-local-password-auth`
Phase: 4
Risk: High
Security-sensitive: Yes

## Goal

Rendre la connexion T0039 réellement utilisable sur Supabase local pour une
identité synthétique provisionnée, sans ouvrir l'inscription publique, puis
prouver l'acquisition et l'installation de la session avant destruction de la
pile sans backup.

## Context

T0039 fournit une commande locale bornée et sa PR #66 est désormais fusionnée
dans `main` au commit `47c8f341`, avec les trois checks verts. La
configuration héritée garde toutefois `auth.email.enable_signup = false`, ce
qui désactive le provider email dans le runtime : T0036 avait observé HTTP 422
avant toute connexion. T0040 est rebasé sur ce nouveau `origin/main` et sa PR
doit cibler `main`.

## Workflow evidence

- 2 août 2026 — `Ready` : la roadmap recommande la preuve runtime après T0039
  et l'écart de configuration est reproduit par la preuve T0036.
- 2 août 2026 — `In progress` : branche
  `fix/T0040-enable-local-password-auth` créée depuis T0039 au commit `09ef5d2`,
  worktree propre et dépendance empilée déclarée.
- 2 août 2026 — `Review` : provider local, gate à 20 mutations, deux scénarios
  runtime, refus du signup, nettoyage et documentation prêts pour revue.
- 2 août 2026 — dépendance livrée : Andy fusionne T0039/PR #66 dans `main` au
  commit `47c8f341` avec les trois checks verts ; T0040 est rebasé sur cette base.
- 2 août 2026 — publication : commit `61fd54e` poussé sur
  `fix/T0040-enable-local-password-auth`; PR #67 ouverte prête pour revue, base
  `main`. Les checks GitHub sont déclenchés mais pas encore attribués comme
  réussis dans cette preuve.
- 2 août 2026 — `Done` : PR #67 fusionnée dans `main` au commit `471c7c1` ; les
  jobs Windows multi-stack, PostgreSQL 17 et supply-chain du run observé sont
  tous réussis.

## Dependencies

- T0021 — pile locale isolée et arrêt sans backup ;
- T0038 — configuration et gestionnaire de session en mémoire ;
- T0039 / PR #66 — commande email/mot de passe fusionnée dans `main`.

## Allowed areas

- `supabase/config.toml` ;
- `tests/backend/run.ps1` ;
- test runtime auth sous `apps/desktop/src/features/auth/` ;
- inventaire d'autorité, T0039 pour réconciliation de livraison, documentation
  T0040, index, état, qualité et sécurité.

## Do not touch

- migrations, seed, fonctions, RPC, RLS, types et données persistantes ;
- inscription UI, récupération, OAuth, passkey, SMTP et fournisseur tiers ;
- routeur, onboarding, catalogue, achat, Rust/Tauri, bridge et lockfiles ;
- cible distante, staging, production, donnée réelle ou secret versionné ;
- persistance de mot de passe, bearer ou refresh token.

## Requirements

### 1. Provider local fermé

- Activer le provider email local requis par le grant password.
- Conserver l'inscription globale désactivée et prouver que `/signup` refuse.
- Ne pas activer SMTP, confirmation email, cible distante ou stockage.
- Ajouter un gate et des mutations négatives pour ces invariants.

### 2. Preuve runtime de T0039

- Démarrer/reset la pile T0021 et vérifier ses trois bindings loopback.
- Provisionner une identité `.invalid` via l'Admin API locale uniquement.
- Exécuter la vraie commande `signInWithPassword`, installer sa réponse dans
  `DesktopSessionManager` et confirmer le bearer local.
- Confirmer qu'un mauvais mot de passe échoue sans détail sensible.

### 3. Nettoyage et réconciliation

- Supprimer l'identité synthétique, arrêter avec `--no-backup`, redémarrer et
  confirmer son absence, puis arrêter définitivement.
- Documenter une preuve locale sans revendiquer route, UI live, persistance,
  cible distante ni livraison dans `main`.

## Non-goals

- inscription publique ou création de compte depuis le desktop ;
- persistance Windows, navigation, onboarding, catalogue ou achat composé ;
- modifier le contrat T0039 ou la politique de mot de passe ;
- parité cloud, staging, production ou donnée réelle.

## Acceptance criteria

- [x] Le provider email local accepte une identité provisionnée tandis que
      l'inscription publique reste refusée.
- [x] Le gate échoue si l'inscription globale s'ouvre ou si le provider est
      désactivé.
- [x] La commande T0039 acquiert et installe une session Auth locale réelle.
- [x] Un mauvais mot de passe échoue fermé et aucun credential n'est journalisé.
- [x] L'arrêt sans backup détruit l'identité synthétique et les limites de livraison
      sont documentées exactement.

## Security review

- actifs/données : email et mot de passe synthétiques, clés locales, JWT et
  refresh token éphémères ;
- frontière : test frontend → loopback T0021 → Supabase Auth local ;
- abus : inscription publique, fuite de credential, provider désactivé, réponse
  forgée, état de test conservé ;
- validation/autorisation : identité créée par Admin API locale, signup global
  fermé, commande T0039 et gestionnaire T0038 inchangés ;
- atomicité/idempotence : session installée seulement après validation complète ;
- logs/vie privée : valeurs exclusivement en mémoire, jamais affichées ni
  versionnées, identité `.invalid` détruite sans backup.

## Maintenance review

- dette applicable : configuration incompatible avec le flux T0039 ;
- dette créée : test runtime encore déclenché explicitement avec environnement
  local, pas dans la CI sans Docker ;
- règle de sécurité : provider local actif mais inscription globale fermée,
  synchronisée dans `SECURITY.md` et contrôlée par mutation ;
- risque résiduel : aucune protection contre une WebView compromise, aucune
  parité distante et aucune persistance sûre n'est prouvée.

## Automated validation

```powershell
pnpm.cmd backend:check
pnpm.cmd frontend:typecheck
pnpm.cmd frontend:test
pnpm.cmd frontend:coverage
pnpm.cmd frontend:build
pnpm.cmd authority:check
pnpm.cmd data-policy:check
pnpm.cmd maintenance:check
git diff --check
```

## Manual verification

1. Démarrer/reset la pile et confirmer 54321–54323 sur `127.0.0.1` seulement.
2. Créer une identité `.invalid` par Admin API, sans afficher les credentials.
3. Lancer le test runtime T0039 puis vérifier un refus avec mauvais mot de passe.
4. Vérifier que `/signup` est refusé, supprimer l'identité et arrêter sans backup.
5. Redémarrer, confirmer l'absence de l'identité puis arrêter définitivement.

Temps cible : 15 minutes hors téléchargement initial des images.

## Rollback

Remettre le provider email local à l'état précédent, retirer gate et test, puis
arrêter la pile sans backup. Aucune migration ni donnée durable n'est créée.

## Completion Report

### Summary

Le provider email de la pile locale accepte désormais les identités
provisionnées sans ouvrir le signup global. Un test runtime appelle la vraie
commande T0039, installe sa session T0038 et vérifie les refus attendus.

### Files changed

- configuration Auth locale et gate backend avec deux mutations négatives ;
- test runtime explicite sous `features/auth` ;
- inventaire d'autorité, sécurité, qualité, état courant, index et ce ticket.

Aucune migration, fonction, seed, route, persistance ou lockfile n'est modifié.

### Commands and results

- `pnpm.cmd backend:check` — PASS, 20 mutations après correction d'un premier
  invariant trop permissif puis d'une erreur de collection PowerShell ;
- `pnpm.cmd frontend:typecheck` — PASS ;
- `pnpm.cmd frontend:test` — PASS, 9 fichiers/78 tests et 1 fichier runtime
  ignoré sans environnement ;
- `pnpm.cmd frontend:coverage` — PASS, 92 % statements, 86,13 % branches,
  92,45 % fonctions et 92,56 % lignes ;
- `pnpm.cmd frontend:build` — PASS, bundle JS 233,02 kB / 74,72 kB gzip ;
- premier `pnpm.cmd backend:start` sandboxé — FAIL, `docker.exe` refusé ;
- démarrage autorisé — environnement préexistant détecté ; inspection en lecture
  seule `2|2` confirme deux identités `.invalid` et deux compagnies seedées ;
- `pnpm.cmd backend:stop`, puis `backend:start` — PASS, configuration T0040
  chargée sur les trois ports loopback ;
- premier bloc runtime — arrêté avant création car Windows PowerShell 5.1 traite
  le stderr informatif de `supabase status` comme exception ;
- bloc runtime corrigé — PASS, 1 fichier/2 tests réels ;
- inspection après suppression — PASS, bindings loopback et `2|2` identités
  `.invalid` uniquement ;
- arrêt sans backup, redémarrage et requête de contrôle — PASS, `2|2|0` ;
- arrêt final sans backup — PASS, seul le cache d'images sans source est conservé.
- `pnpm.cmd authority:check` — PASS, 5 mutations ;
- `pnpm.cmd data-policy:check` — PASS, 6 mutations ;
- `pnpm.cmd maintenance:check` — PASS, 8 mutations ;
- `git diff --check` — PASS, avertissement LF/CRLF seulement.

Les credentials éphémères ont été lus par la commande officielle
`supabase status -o env`, gardés en mémoire et jamais affichés ni écrits.

### Manual verification result

PASS sur Docker Desktop 29.6.2, Supabase CLI 2.109.1 et Auth local. Le login
email/mot de passe retourne une session validée et installable ; le mauvais mot
de passe et `/signup` sont refusés. Les ports 54321–54323 sont liés uniquement à
`127.0.0.1`. Après destruction et redémarrage, zéro identité T0040 subsiste.

### Risks and limitations

T0040 est livré dans `main`. Le test runtime exige Docker et des variables
éphémères explicites, donc il est ignoré dans le gate frontend normal.
Aucune route, persistance, inscription, cible distante ou donnée réelle n'est
validée ; une WebView compromise peut toujours lire les tokens en mémoire.

### Follow-ups

- après fusion de T0040, cadrer une route de connexion bornée ;
- traiter la persistance Windows dans un ticket de sécurité séparé ;
- ne composer catalogue et achat live qu'après ces frontières.

### Documentation updated

`CURRENT_STATE.md`, `QUALITY.md`, `SECURITY.md`, inventaire d'autorité, index,
T0039 et T0040. T0039 et T0040 sont réconciliés `Done`.

### Git status

- branche : `fix/T0040-enable-local-password-auth` ;
- base : `origin/main` au commit `47c8f341` ;
- commit d'implémentation rebasé : `61fd54e` ;
- PR #67 : fusionnée dans `main` au commit `471c7c1`, base `main`, head
  `fix/T0040-enable-local-password-auth` ;
- checks GitHub : Windows multi-stack, PostgreSQL 17 et supply-chain réussis ;
- fusion finale réservée à Andy.
