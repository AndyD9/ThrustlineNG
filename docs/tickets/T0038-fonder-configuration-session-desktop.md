# T0038 — Fonder la configuration et la session authentifiée du desktop

Status: Review
Owner: Andy
Branch: `feature/T0038-desktop-session-foundation`
Phase: 2–4
Risk: High
Security-sensitive: Yes

## Goal

Fournir au desktop une configuration Supabase publique strictement bornée à la
cible locale et un gestionnaire de session en mémoire capable de renouveler un
bearer sans concurrence, fuite de credential ou élargissement réseau distant.

## Context

T0037 livre la commande d’achat avec session injectée mais laisse volontairement
absents la source de configuration, le cycle de refresh et la connectivité live.
Sa PR #64 est fusionnée dans `main` au commit `47cd50c` avec ses trois checks
verts. Aucune cible staging n’est identifiée et la production reste interdite aux
données réelles : T0038 sélectionne donc exclusivement Supabase local
`http://127.0.0.1:54321` et conserve la CSP de production fermée.

## Workflow evidence

- 2 août 2026 — `Ready` : T0037 est fusionné dans `origin/main` par la PR #64 ;
  Windows multi-stack, PostgreSQL 17 et supply-chain sont réussis.
- 2 août 2026 — `In progress` : branche
  `feature/T0038-desktop-session-foundation` créée depuis `origin/main` au
  commit `47cd50c`, worktree propre.
- 2 août 2026 — `Review` : configuration, refresh en mémoire, CSP locale,
  documentation et validations automatisées sont prêts pour revue.

## Dependencies

- T0021 — Supabase local isolé sur loopback ;
- T0024 — WebView non fiable et autorité serveur ;
- T0035–T0036 — Auth et Edge Runtime locaux validés ;
- T0037 / PR #64 — commande desktop fusionnée.

## Allowed areas

- `apps/desktop/src/features/auth/` et ses tests ;
- `apps/desktop/src/vite-env.d.ts`, `apps/desktop/vite.config.ts` ;
- CSP et invariants sous `apps/desktop/src-tauri/tauri.conf.json` et
  `apps/desktop/src/test/` ;
- `eng/authority-inventory.json` ;
- ce ticket, T0037, index, `CURRENT_STATE.md`, `QUALITY.md` et `SECURITY.md`.

## Do not touch

- backend, Auth config, migrations, fonctions, RLS, RPC et seed ;
- routeur, écran de connexion, fournisseur d’identité et catalogue ;
- stockage disque, credential manager, cookie ou persistance de session ;
- CSP de production, cible distante, staging, données réelles et `.env` ;
- Tauri/Rust, bridge, SimConnect, location T0032 et lockfiles.

## Requirements

### 1. Configuration publique fermée

- Exposer au bundle exactement l’URL et la clé anonyme sous deux noms dédiés.
- Accepter uniquement `http://127.0.0.1:54321` dans cette tranche.
- Refuser valeur absente, cible divergente et clé impropre à un header.
- Ne jamais exposer `service_role`, secret ou préfixe environnement générique.

### 2. Cycle de session en mémoire

- Recevoir une session initiale injectée ; ne pas choisir de méthode de login.
- Conserver bearer et refresh token uniquement en mémoire et permettre
  l’effacement explicite.
- Retourner le bearer valide ou le renouveler 30 secondes avant expiration via
  Supabase Auth, avec timeout de cinq secondes et réponse bornée.
- Faire converger les demandes concurrentes vers un seul refresh et remplacer
  atomiquement les deux tokens après succès.
- Effacer la session sur refus Auth ; la conserver après panne transitoire afin
  de permettre un retry.

### 3. Réseau et erreurs

- Ouvrir la CSP de développement uniquement vers `127.0.0.1:54321`, en plus de
  Vite/HMR, et garder la CSP de production à `connect-src 'none'`.
- Classer les erreurs en authentification requise, réponse invalide ou service
  indisponible sans lire ni propager les détails sensibles des refus.

### 4. Réconciliation

- Passer T0037 à `Done` avec la fusion #64 et ses checks réellement observés.
- Synchroniser autorité, sécurité, qualité, état courant et index.

## Non-goals

- créer ou connecter un compte, choisir email/OAuth/passkey ou persister une session ;
- brancher le panneau T0037, un catalogue ou une route ;
- appeler réellement Auth depuis la WebView ou prouver CORS/E2E ;
- autoriser HTTPS distant, staging, production ou données réelles ;
- modifier le serveur ou implémenter la location.

## Acceptance criteria

- [x] Seuls URL locale et clé anonyme publiques peuvent être injectées au bundle.
- [x] La session reste en mémoire, se renouvelle avant expiration et s’efface
      explicitement ou après refus Auth.
- [x] Deux consommateurs concurrents partagent un seul refresh et le token
      rotatif remplace l’ancien uniquement après validation.
- [x] Timeout, tailles, statuts et réponses invalides échouent fermés sans fuite.
- [x] La CSP de développement ajoute seulement Supabase loopback et la CSP de
      production reste fermée.
- [x] T0037 et la documentation reflètent sa fusion sans revendiquer login,
      persistance, cible distante ou appel live.

## Security review

- actifs/données : URL publique, clé anonyme, bearer et refresh token ;
- frontière : environnement de build public → WebView non fiable → Auth locale ;
- abus : secret embarqué, cible détournée, token persisté, refresh concurrent,
  réponse surdimensionnée et détail Auth exposé ;
- validation/autorisation : cible locale exacte, valeurs de header bornées,
  Auth reste autoritaire et aucun `service_role` client ;
- atomicité/idempotence : un seul refresh en vol, rotation appliquée après
  validation complète ;
- logs/vie privée : aucun log, rendu, fichier, stockage Web ou message d’erreur
  contenant les tokens.

## Maintenance review

- dette applicable : `KI-005`, sans mélange UI grâce à un module auth séparé ;
- dette créée : acquisition et persistance de session restent explicitement absentes ;
- règle de sécurité modifiée : CSP de développement, synchronisée avec
  `SECURITY.md` et un invariant automatisé ;
- contrôle manuel : aucun appel live autorisé dans ce ticket ;
- risque résiduel : un bearer présent dans une WebView compromise peut être lu ;
  la tranche ne prétend pas protéger un client modifiable contre lui-même.

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

1. Inspecter les tests de configuration, refresh, concurrence et erreurs.
2. Inspecter la CSP et la production Vite sans variables de credential réelles.
3. Rechercher persistance, logs, `service_role` et accès Data API dans le diff.
4. Confirmer qu’aucun appel réseau live ni fichier `.env` n’est créé.

Temps cible : 10 minutes.

## Rollback

Retirer le module auth, ses tests et l’ouverture CSP loopback, puis rétablir
l’inventaire et la documentation. Aucun état serveur ou utilisateur n’est modifié.

## Completion Report

### Summary

Deux paramètres publics exactement nommés alimentent une configuration limitée à
Supabase local. Le gestionnaire conserve la session en mémoire, rend un bearer
valide, renouvelle avant expiration avec convergence concurrente et redige les
erreurs. La CSP de production reste fermée.

### Files changed

- configuration, session et tests sous `apps/desktop/src/features/auth/` ;
- types Vite, exposition exacte des deux paramètres publics et CSP/invariant ;
- inventaire d’autorité et documentation T0037–T0038 synchronisés.

### Commands and results

- `pnpm.cmd frontend:typecheck` — PASS après correction de types détectée lors
  de la première passe ;
- `pnpm.cmd frontend:test` — PASS, 7 fichiers/58 tests ;
- `pnpm.cmd frontend:coverage` — PASS, 89,80 % statements, 84,79 % branches,
  90 % fonctions et 90,68 % lignes ;
- `pnpm.cmd frontend:build` — PASS, bundle JS 233,02 kB / 74,72 kB gzip ;
- `pnpm.cmd authority:check` — PASS, 5 mutations ;
- `pnpm.cmd data-policy:check` — PASS, 6 mutations ;
- `pnpm.cmd maintenance:check` — PASS, 8 mutations ;
- `git diff --check` — PASS, avertissements de normalisation LF/CRLF seulement.

### Manual verification result

PASS par inspection du diff : aucun token réel, secret, stockage, log, appel
live, cible distante, backend ou lockfile ajouté. La CSP de production reste
`connect-src 'none'`.

### Risks and limitations

La session initiale reste injectée et disparaît au redémarrage. Aucun login,
logout serveur, persistance sécurisée, catalogue, route, CORS live, staging ou
production n’est prouvé. La clé anonyme est publique et ne confère aucune
autorité serveur.

### Follow-ups

- choisir explicitement la méthode d’acquisition de session et son stockage
  Windows avant d’implémenter login/persistance ;
- identifier une cible staging synthétique et son origine CSP avant tout HTTPS
  distant ;
- brancher ensuite session, catalogue et panneau dans un ticket E2E borné ;
- conserver T0032 en `Draft` jusqu’aux décisions de location d’Andy.

### Documentation updated

T0037, ce ticket, l’index, `CURRENT_STATE.md`, `QUALITY.md`, `SECURITY.md` et
l’inventaire d’autorité.

### Git status

- branche : `feature/T0038-desktop-session-foundation` ;
- base : `origin/main` au commit `47cd50c` ;
- commit et Pull Request : à consigner après publication ;
- fusion finale réservée à Andy.
