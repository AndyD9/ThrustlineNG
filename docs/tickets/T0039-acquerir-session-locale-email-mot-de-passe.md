# T0039 — Acquérir une session locale par email et mot de passe

Status: Done
Owner: Andy
Branch: `feature/T0039-desktop-password-sign-in`
Phase: 4
Risk: High
Security-sensitive: Yes

## Goal

Permettre au desktop d'acquérir sur Supabase local une session email/mot de
passe, de la transmettre atomiquement au gestionnaire T0038 et de présenter des
états accessibles sans persister ni divulguer le mot de passe ou les tokens.

## Context

T0038 est fusionné dans `main` par la PR #65 au commit `e88bdef` avec ses trois
checks verts. Il renouvelle une session injectée mais ne choisit aucune méthode
de connexion. Andy retient le 2 août 2026 une première tranche email/mot de
passe, locale et en mémoire uniquement. Cette décision n'autorise aucune donnée
réelle ni cible distante.

## Workflow evidence

- 2 août 2026 — `Ready` : T0038 est fusionné et Andy choisit explicitement
  email/mot de passe avec session en mémoire pour la première tranche.
- 2 août 2026 — `In progress` : branche
  `feature/T0039-desktop-password-sign-in` créée depuis `origin/main` au commit
  `e88bdef`, worktree propre.
- 2 août 2026 — `Review` : commande, panneau injecté, invariants, documentation
  et validations automatisées sont prêts pour revue ; aucun login live ou
  stockage n'est revendiqué.
- 2 août 2026 — publication : commit `024613c` poussé sur
  `feature/T0039-desktop-password-sign-in`; PR #66 ouverte prête pour revue,
  base `main`. Windows multi-stack et supply-chain sont en cours, PostgreSQL 17
  est en file d'attente lors de cette mise à jour.
- 2 août 2026 — `Done` : Andy fusionne la PR #66 dans `main` au commit
  `47c8f341`; Windows multi-stack, PostgreSQL 17 et supply-chain sont réussis.

## Dependencies

- T0021 — Supabase local isolé sur loopback ;
- T0024 — WebView non fiable et autorité serveur ;
- T0038 / PR #65 — configuration locale et cycle de session en mémoire ;
- décision Andy du 2 août 2026 — email/mot de passe, sans persistance.

## Allowed areas

- `apps/desktop/src/features/auth/` et ses tests ;
- invariants frontend sous `apps/desktop/src/test/` si nécessaires ;
- `eng/authority-inventory.json` ;
- T0038, ce ticket, index, `CURRENT_STATE.md`, `QUALITY.md` et `SECURITY.md`.

## Do not touch

- backend, configuration Auth, migrations, RLS, RPC, fonctions et seed ;
- routeur, shell global, onboarding, catalogue et achat d'avion ;
- Rust/Tauri, bridge, SimConnect et lockfiles ;
- stockage Web, fichier, cookie, Credential Locker, DPAPI ou autre persistance ;
- inscription, récupération de mot de passe, OAuth, passkey et fournisseur tiers ;
- cible distante, staging, production, données réelles et `.env`.

## Requirements

### 1. Commande de connexion fermée

- Appeler uniquement `POST /auth/v1/token?grant_type=password` sur la cible
  locale validée par T0038.
- Envoyer exactement email et mot de passe dans un corps JSON borné, avec la clé
  anonyme publique ; ne jamais envoyer de credential privilégié.
- Borner email, mot de passe, requête à cinq secondes et réponse à 16 Kio.
- Valider strictement access token, refresh token, type bearer et expiration
  avant de retourner une session T0038.
- Classer les erreurs en identifiants refusés, réponse invalide ou service
  indisponible sans reprendre les détails Auth.

### 2. Session et interface en mémoire

- Fournir un formulaire accessible qui reçoit configuration et gestionnaire de
  session par injection ; ne pas créer de route ni de singleton global.
- Bloquer les soumissions concurrentes et permettre l'annulation au démontage.
- Installer la session seulement après validation complète de la réponse.
- Effacer le mot de passe du state après chaque tentative et les champs après
  succès ; ne jamais rendre ni journaliser mot de passe, clé ou token.
- Présenter les états prêt, connexion, authentifié, refusé et indisponible avec
  des messages actionnables mais non sensibles.

### 3. Réconciliation

- Passer T0038 à `Done` avec la fusion #65 et ses checks observés.
- Synchroniser autorité, sécurité, qualité, état courant et index sans
  revendiquer persistance, route, cible distante ou appel live.

## Non-goals

- inscrire un compte, vérifier un email ou récupérer/changer un mot de passe ;
- OAuth, PKCE, navigateur système, passkey ou fournisseur social ;
- persister email, mot de passe, access token ou refresh token ;
- connecter une route, l'onboarding, le catalogue ou le panneau d'achat ;
- exécuter un login réel depuis le WebView ou modifier Supabase Auth ;
- autoriser staging, production ou donnée utilisateur réelle.

## Acceptance criteria

- [x] La commande appelle seulement Auth local avec payload et headers fermés.
- [x] Toute session est validée avant installation atomique dans T0038.
- [x] Refus, timeout, panne, taille et réponse invalide échouent fermés sans fuite.
- [x] Le panneau bloque la concurrence, efface le mot de passe et rend les états
      accessibles sans afficher de credential.
- [x] Aucun stockage, cookie, log, route, backend, cible distante ou lockfile
      n'est ajouté.
- [x] T0038 et la documentation reflètent sa fusion réelle.

## Security review

- actifs/données : email, mot de passe, clé anonyme, bearer et refresh token ;
- frontière : saisie WebView non fiable → Supabase Auth local → session mémoire ;
- abus : exfiltration, stockage implicite, payload surdimensionné, double login,
  réponse forgée et détail Auth affiché ;
- validation/autorisation : cible exacte T0038, Auth reste seule autorité et la
  session n'est installée qu'après validation complète ;
- atomicité/idempotence : une soumission en vol, remplacement atomique via
  `DesktopSessionManager.setSession` ;
- logs/vie privée : aucun log ou rendu de l'email, du mot de passe ou des tokens.

## Maintenance review

- dette applicable : `KI-005`, contenue dans un module auth séparé ;
- dette créée : login non routé et session perdue au redémarrage, limites
  explicites de cette tranche ;
- règle de sécurité modifiée : méthode locale d'acquisition de session,
  synchronisée dans `SECURITY.md` et couverte par tests ;
- contrôle manuel : inspection du DOM et recherche de stockage/logs ;
- risque résiduel : une WebView compromise peut lire les secrets présents en
  mémoire pendant la connexion et la session.

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

1. Inspecter les tests de payload, session, concurrence, annulation et erreurs.
2. Inspecter le DOM de test pour les états et l'effacement du mot de passe.
3. Rechercher logs, stockage, cookie, token factice et cible distante dans le diff.
4. Confirmer qu'aucun appel live, fichier `.env` ou modification backend n'existe.

Temps cible : 10 minutes.

## Rollback

Retirer la commande et le panneau de connexion puis rétablir inventaire et
documentation. Aucune donnée serveur ou persistée n'est créée par le ticket.

## Completion Report

### Summary

Une commande frontend bornée acquiert une session email/mot de passe auprès
d'Auth local et réutilise la validation de tokens T0038. Un panneau injecté
bloque les doubles soumissions, installe la session après validation complète,
efface le mot de passe et présente des erreurs redigées.

### Files changed

- transport, panneau et tests sous `apps/desktop/src/features/auth/` ;
- validation de session T0038 rendue réutilisable sans changer son contrat ;
- invariant frontend contre stockage, cookie et logs de credentials ;
- inventaire d'autorité et documentation T0038–T0039 synchronisés.

Aucun backend, routeur, Rust/Tauri, bridge, lockfile, fichier `.env` ou cible
distante n'est modifié.

### Commands and results

- première commande ciblée `pnpm.cmd --dir apps/desktop exec vitest ...` — FAIL,
  binaire `vitest` non résolu par cette forme de commande ;
- premier `pnpm.cmd frontend:typecheck` — FAIL sur la signature non typée du
  mock `fetch`, puis PASS après correction ;
- `pnpm.cmd frontend:test` — PASS, 9 fichiers/78 tests ;
- `pnpm.cmd frontend:coverage` — PASS, 92 % statements, 86,13 % branches,
  92,45 % fonctions et 92,56 % lignes ;
- `pnpm.cmd frontend:build` — PASS, bundle JS 233,02 kB / 74,72 kB gzip ;
- `pnpm.cmd authority:check` — PASS, 5 mutations ;
- `pnpm.cmd data-policy:check` — PASS, 6 mutations ;
- `pnpm.cmd maintenance:check` — PASS, 8 mutations ;
- `git diff --check` — PASS, avertissements de normalisation LF/CRLF seulement ;
- inspection de portée et scan du bundle — PASS, aucun backend, Tauri, bridge,
  lockfile, credential de test, `service_role` ou accès Data API.

### Manual verification result

PASS par DOM jsdom et inspection du diff : états prêt, pending, authentifié,
refusé et indisponible couverts ; double soumission limitée à un appel ; session
absente avant réponse puis disponible après validation ; mot de passe effacé dès
la soumission ; annulation au démontage. Aucun stockage, cookie, log ou appel
live n'est ajouté.

### Risks and limitations

Le formulaire et le gestionnaire restent injectés et non routés. La session est
perdue au redémarrage ; aucun login réel, inscription, récupération, OAuth,
persistance Windows, catalogue, achat intégré, staging ou production n'est
prouvé. Une WebView compromise peut lire les secrets pendant leur présence en
mémoire.

### Follow-ups

- valider Auth local en runtime avec une identité synthétique et nettoyage sans
  backup ;
- cadrer séparément la persistance Windows du refresh token avant tout stockage ;
- exposer ensuite le catalogue puis composer login, session et achat dans une
  route bornée ;
- conserver T0032 en `Draft` jusqu'aux décisions de location d'Andy.

### Documentation updated

T0038, ce ticket, l'index, `CURRENT_STATE.md`, `QUALITY.md`, `SECURITY.md` et
l'inventaire d'autorité.

### Git status

- branche : `feature/T0039-desktop-password-sign-in` ;
- base de développement : `origin/main` au commit `e88bdef` ;
- commit d'implémentation : `024613c` ;
- PR #66 : fusionnée par Andy dans `main` au commit `47c8f341`, head
  `feature/T0039-desktop-password-sign-in` ;
- checks GitHub : Windows multi-stack, PostgreSQL 17 et audits/licences/SBOM
  réussis dans les runs `30759103827` et `30759103836`.
