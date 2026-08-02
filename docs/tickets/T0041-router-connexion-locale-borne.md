# T0041 — Rendre la connexion locale accessible par une route bornée

Status: Review
Owner: Andy
Branch: `feature/T0041-bounded-login-route`
Phase: 4
Risk: High
Security-sensitive: Yes

## Goal

Rendre la connexion email/mot de passe locale accessible dans le routeur du
desktop, protéger l'accueil tant que la session en mémoire est absente et
permettre une déconnexion explicite sans persister ni exposer les credentials.

## Context

T0038 fournit la configuration locale et le gestionnaire de session en mémoire.
T0039 fournit le panneau de connexion et T0040 prouve le grant password dans le
runtime local, mais aucun de ces éléments n'est encore relié au routeur. T0040
est en `Review` dans la PR #67 : T0041 est donc temporairement empilé sur cette
branche et ne doit pas être présenté comme livrable indépendamment.

## Workflow evidence

- 2 août 2026 — `Ready` : les dépendances fonctionnelles T0038–T0039 sont dans
  `main`; T0040 a terminé ses preuves et sa PR #67 est ouverte prête.
- 2 août 2026 — `In progress` : branche
  `feature/T0041-bounded-login-route` créée au-dessus de
  `fix/T0040-enable-local-password-auth` au commit `fc95f68`; dépendance empilée
  explicite jusqu'à la fusion de T0040.
- 2 août 2026 — `Review` : composition, gardes, déconnexion et preuves
  automatisées terminées ; la branche reste empilée et ne peut pas être rendue
  indépendante avant la fusion de T0040.

## Dependencies

- T0038 — configuration locale et session exclusivement en mémoire ;
- T0039 — commande et panneau email/mot de passe ;
- T0040 / PR #67 — provider local actif et preuve runtime, non encore fusionné.

## Allowed areas

- `apps/desktop/src/app/` et tests associés ;
- `apps/desktop/src/pages/` et tests associés ;
- `apps/desktop/src/features/auth/PasswordSignInPanel.tsx` et son test ;
- `apps/desktop/src/styles/index.css` pour les états de la route ;
- ce ticket, l'index, `CURRENT_STATE.md`, `QUALITY.md` et `SECURITY.md`.

## Do not touch

- backend, Auth config, migrations, fonctions, RLS, RPC et seed ;
- persistance Windows, stockage Web, cookie et gestionnaire de credentials ;
- onboarding, catalogue, achat, location, finance et données réelles ;
- CSP, cible distante, staging, production, Rust/Tauri, bridge et lockfiles ;
- contrat réseau, payload ou politique de mot de passe T0039.

## Requirements

### 1. Composition auth unique

- Lire la configuration publique bornée une seule fois au démarrage et créer un
  seul gestionnaire de session pour la durée de l'application.
- Réutiliser le panneau T0039 sans dupliquer le transport ou les tokens dans
  l'état React.
- Notifier le routeur seulement après installation complète de la session.

### 2. Navigation fermée

- Rediriger une session absente de `/` vers `/login`.
- Rediriger une session présente de `/login` vers `/`.
- Ne rendre l'accueil authentifié qu'après confirmation du gestionnaire.
- Conserver la route inconnue et ses affordances accessibles.

### 3. Déconnexion en mémoire

- Fournir une action explicite qui efface la session puis revient au login.
- Ne jamais rendre, journaliser ou persister bearer, refresh token ou mot de
  passe hors du champ de saisie ; effacer l'email de l'UI après succès.
- Ne déclencher aucun appel réseau au simple rendu, à la redirection ou à la
  déconnexion.

## Non-goals

- persister ou restaurer une session après redémarrage ;
- inscription, récupération de mot de passe, OAuth ou cible distante ;
- onboarding, catalogue, achat live ou golden path composé ;
- rafraîchir proactivement le token sans consommateur ;
- modifier le backend ou la CSP.

## Acceptance criteria

- [x] Sans session, `/` affiche le login et l'accueil protégé n'est pas rendu.
- [x] Une connexion réussie installe la session puis affiche l'accueil.
- [x] Une session déjà présente ne peut pas revenir au login.
- [x] La déconnexion efface la session et ramène au login sans réseau.
- [x] Tokens et credentials ne sont ni rendus, ni journalisés, ni persistés.
- [x] Tests ciblés, typecheck, couverture, build et gates applicables passent.
- [x] Documentation et statut reflètent la dépendance empilée sur T0040.

## Security review

- actifs/données : email, mot de passe, bearer et refresh token éphémères ;
- frontière : route WebView non fiable → commande Auth locale T0039 ;
- abus : contournement de garde, double gestionnaire, fuite au DOM/stockage,
  session conservée après déconnexion et appel réseau implicite ;
- validation/autorisation : Auth reste autoritaire, le routeur ne fait que
  refléter `DesktopSessionManager.hasSession()` ;
- atomicité/idempotence : navigation authentifiée seulement après `setSession` ;
- logs/vie privée : aucun log, stockage, cookie ou rendu de credential.

## Maintenance review

- dette applicable : `KI-005`; composition, page et transport restent séparés ;
- dette créée ou aggravée : aucune persistance ni onboarding anticipé ;
- règle de sécurité : cycle de route/session en mémoire, à synchroniser dans
  `SECURITY.md` et les tests ;
- contrôle manuel à automatiser : navigation, déconnexion et absence de réseau
  sont couvertes en DOM jsdom ;
- risque résiduel : une WebView compromise peut lire les tokens en mémoire et
  T0040 doit être fusionné avant que T0041 puisse cibler `main`.

## Automated validation

```powershell
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

1. Rendre `/` sans session et confirmer la redirection vers le formulaire.
2. Soumettre une commande injectée réussie et confirmer l'accueil protégé.
3. Tenter `/login` avec session puis déclencher la déconnexion.
4. Inspecter DOM, stockage et espions réseau pour confirmer l'absence de fuite et
   d'appel implicite.

Temps cible : 10 minutes.

## Rollback

Retirer la composition auth et restaurer les routes statiques. Le ticket ne
modifie aucune donnée, migration, cible réseau ou persistance.

## Completion Report

### Summary

Le desktop crée une seule composition de configuration/session au démarrage.
Les gardes React Router redirigent une session absente vers `/login` et une
session installée vers l'accueil ; la déconnexion efface la session en mémoire
avant le retour au formulaire.

### Files changed

- composition et gardes sous `apps/desktop/src/app/` ;
- page de connexion, accueil authentifié et styles bornés ;
- notification post-installation du panneau T0039 et tests associés ;
- invariant de non-persistance étendu à la composition et aux routes ;
- ticket, index, état courant, qualité et sécurité.

Aucun backend, CSP, manifeste, lockfile, stockage ou flux d'achat n'est modifié.

### Commands and results

- premier `pnpm.cmd frontend:typecheck` — FAIL : propriétés optionnelles passées
  explicitement à `undefined` incompatibles avec `exactOptionalPropertyTypes` ;
  contrats corrigés sans changement runtime ;
- première commande ciblée `pnpm.cmd --dir apps/desktop exec vitest ...` — non
  exécutée, forme de commande invalide après l'échec du typecheck ;
- `pnpm.cmd frontend:typecheck` — PASS ;
- `pnpm.cmd frontend:test` — PASS, 9 fichiers/80 tests ; 1 fichier/2 scénarios
  runtime T0040 ignorés sans environnement explicite ;
- `pnpm.cmd frontend:coverage` — PASS, 91,69 % statements, 86,17 % branches,
  91,66 % fonctions et 92,18 % lignes ;
- `pnpm.cmd frontend:build` — PASS, bundle JS 241,64 kB / 77,37 kB gzip ;
- `pnpm.cmd authority:check` — PASS, 5 mutations ;
- `pnpm.cmd data-policy:check` — PASS, 6 mutations ;
- `pnpm.cmd maintenance:check` — PASS, 8 mutations ;
- `git diff --check` — PASS, avertissements LF/CRLF seulement.

### Manual verification result

PASS le 2 août 2026 via DOM jsdom contrôlé : redirection `/` → `/login`,
installation avant navigation, refus de `/login` avec session, déconnexion et
retour au formulaire. Les espions `fetch`/XHR restent à zéro au rendu, pendant
les redirections et à la déconnexion. Après succès, le DOM ne contient ni email,
mot de passe ni tokens synthétiques.

### Security and maintenance review result

Le booléen de navigation ne devient vrai qu'après `setSession` et relit
`hasSession()` ; il ne contient aucun token. La déconnexion appelle `clear()`
avant le rendu du login. L'invariant de stockage/log couvre désormais auth,
composition, routes et page login. `KI-005` n'est pas aggravé : transport,
composition, route et page restent séparés. Aucune règle, exception ou dette
silencieuse n'est créée.

### Risks and limitations

T0041 reste empilé sur T0040/PR #67, non fusionné dans `main`. La preuve de
navigation utilise une commande injectée et jsdom : aucun login WebView live,
onboarding, catalogue, achat, persistance Windows, cible distante ou donnée
réelle n'est revendiqué. Une WebView compromise peut toujours lire les tokens
présents en mémoire.

### Follow-ups

- après fusion de T0040, rebaser T0041 sur `main` et changer la base de sa PR ;
- cadrer séparément la persistance Windows avant tout stockage de refresh token ;
- composer onboarding puis catalogue/achat dans des tickets distincts.

### Documentation updated

Ce ticket, l'index, `CURRENT_STATE.md`, `QUALITY.md` et `SECURITY.md`.

### Git status

- branche : `feature/T0041-bounded-login-route` ;
- base de développement : `fix/T0040-enable-local-password-auth` au commit
  `fc95f68` ;
- dépendance : T0040/PR #67 doit fusionner avant rebase/changement de base ;
- commit et Pull Request : à renseigner après publication.
