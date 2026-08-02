# T0037 — Consommer l’achat d’avion depuis le desktop sans autorité client

Status: Done
Owner: Andy
Branch: `feature/T0037-desktop-aircraft-purchase`
Phase: 2–4
Risk: High
Security-sensitive: Yes

## Goal

Livrer dans le frontend desktop une commande et un panneau d’achat bornés qui
appellent l’Edge Function `aircraft-purchase` avec une session utilisateur,
présentent explicitement les états `pending`, `owned`, `rejected` et
`unavailable`, et réutilisent la même clé d’idempotence lors d’un retry sans
jamais exposer de credential privilégié au client.

## Context

T0029 livre l’achat transactionnel et idempotent. T0035 l’expose derrière une
frontière serveur authentifiée et T0036 prouve la chaîne Auth → Edge → RPC dans
le runtime local réel. Ces trois capacités sont fusionnées dans `main`.

Le desktop reste une baseline sans authentification, catalogue ni couche de
commandes. Ce ticket crée uniquement la frontière cliente et son état UI. Il
reçoit la session et l’offre de futurs appelants afin de ne pas inventer un
stockage de token, un parcours de connexion ou une offre codée en dur.

## Workflow evidence

- 2 août 2026 — `Ready` : la PR #63 fusionne T0036 dans `origin/main` au commit
  `82e79ea`; T0029, T0035 et la preuve runtime T0036 sont donc livrés.
- 2 août 2026 — `In progress` : branche
  `feature/T0037-desktop-aircraft-purchase` créée depuis `origin/main` au commit
  `82e79ea`, dans un worktree dédié et propre.
- 2 août 2026 — `Review` : commande, panneau et preuves automatisées terminés ;
  aucun branchement réseau live ni élargissement CSP n'est revendiqué.
- 2 août 2026 — publication : commit `3220394` poussé sur
  `feature/T0037-desktop-aircraft-purchase`; PR #64 ouverte prête pour revue,
  base `main`, avec les trois checks GitHub en cours.
- 2 août 2026 — `Done` : PR #64 fusionnée dans `main` au commit `47cd50c` ;
  Windows multi-stack, PostgreSQL 17 et supply-chain réussis.

## Dependencies

- T0029 — achat atomique et idempotent ;
- T0035 — Edge Function authentifiée ;
- T0036 / PR #63 — validation du runtime local réel ;
- T0024 — clients non fiables et commandes sensibles côté serveur.

## Allowed areas

- `apps/desktop/src/features/aircraft-purchase/` ;
- tests frontend associés sous ce même dossier ;
- `apps/desktop/src/vite-env.d.ts` si le contrat de configuration publique doit
  être typé ;
- `eng/authority-inventory.json` et son gate uniquement pour refléter la nouvelle
  consommation sans relâcher les interdictions ;
- ce ticket, T0036 pour sa réconciliation de livraison,
  `docs/tickets/README.md`, `docs/CURRENT_STATE.md`, `docs/QUALITY.md` et
  `docs/SECURITY.md` si leurs affirmations changent réellement.

## Do not touch

- `supabase/`, migrations, RLS, RPC, Edge Functions et seed ;
- `apps/desktop/src-tauri/`, bridge, SimConnect et contrat local ;
- routeur, shell global, authentification, onboarding et stockage de session ;
- catalogue, requête d’offres, prix, devise et politique économique ;
- location T0032, maintenance, dispatch ou autre mutation ;
- projet Supabase distant, données réelles, secrets et fichiers `.env` ;
- nouvelle dépendance runtime ou modification du lockfile.

## Requirements

### 1. Commande cliente fermée

- Accepter uniquement URL Supabase publique, clé anonyme publique, token de
  session, `offerId`, clé d’idempotence et signal d’annulation.
- Appeler uniquement `POST /functions/v1/aircraft-purchase` avec le bearer de la
  session et la clé anonyme ; ne jamais appeler une table ou RPC directement.
- Envoyer exactement `offerId` et `idempotencyKey`.
- Refuser localement URL, UUID ou réponse non conformes.
- Borner la requête à cinq secondes et classer les erreurs sans exposer corps
  interne, SQL, token, URL sensible ou header.
- Accepter HTTP sur loopback pour le développement local et exiger HTTPS pour
  toute autre cible.

### 2. État UI idempotent

- Recevoir une session et une offre depuis l’appelant ; ne pas les persister.
- Générer une clé UUID au premier clic et la conserver pour tous les retries de
  la même intention tant que l’offre ne change pas.
- Désactiver l’action pendant `pending` et empêcher un double appel concurrent.
- Annoncer les états accessibles : prêt, achat en cours, avion acquis, achat
  refusé et service indisponible.
- Afficher des erreurs actionnables sans détail technique et permettre le retry
  avec la même intention après indisponibilité.
- Ne jamais rendre ni journaliser le token ou la clé anonyme.

### 3. Tests et autorité

- Tester payload et headers exacts, validation de cible/réponse, timeout ou
  panne réseau et classification 401/409/5xx.
- Tester double clic, retry avec clé stable, changement d’offre avec nouvelle
  clé, succès et erreurs accessibles.
- Étendre la preuve d’autorité pour reconnaître l’Edge Function comme frontière
  cliente autorisée tout en continuant à refuser `service_role`, `/rest/v1/`,
  RPC et mutations directes dans toutes les surfaces clientes.

### 4. Réconciliation

- Passer T0036 à `Done` avec sa fusion #63 sans modifier ses preuves historiques.
- Synchroniser l’index, l’état courant et les commandes de qualité réellement
  applicables.

## Non-goals

- implémenter connexion, refresh, déconnexion ou stockage de session ;
- créer une page routée ou un marché d’avions ;
- lire ou choisir une offre depuis Supabase ;
- modifier le prix, la devise, le propriétaire ou le solde côté client ;
- exécuter un achat réel ou synthétique depuis le desktop contre une cible ;
- modifier le backend ou ajouter le SDK JavaScript Supabase ;
- implémenter la location.

## Acceptance criteria

- [x] La commande appelle exclusivement l’Edge Function avec bearer utilisateur
      et clé anonyme, payload fermé et timeout borné.
- [x] Les entrées et le contrat de réponse v1 sont validés avant exposition à
      l’UI.
- [x] Le panneau rend les états prêt/pending/owned/rejected/unavailable de façon
      accessible et bloque les doubles soumissions.
- [x] Un retry de la même intention réutilise la clé d’idempotence ; un changement
      d’offre en crée une nouvelle.
- [x] Aucun token, credential privilégié, prix, devise ou propriétaire n’est
      persisté, rendu, journalisé ou envoyé comme autorité.
- [x] Les tests ciblés et les gates frontend, autorité, données et maintenance
      passent.
- [x] T0036, l’index et l’état courant reflètent la livraison réelle sans
      revendiquer auth, catalogue, cible distante ou parcours E2E.

## Security review

- actifs/données : bearer de session, clé anonyme publique, offre, clé
  d’idempotence et identifiants de résultat ;
- frontière : WebView non fiable → Edge Function authentifiée → RPC service ;
- abus : clé privilégiée embarquée, appel direct RPC/Data API, payload forgé,
  double soumission, retry avec nouvelle intention, fuite de token et cible HTTP
  distante ;
- validation/autorisation : validation locale défensive, Auth et propriétaire
  restent validés/dérivés côté serveur ;
- atomicité/idempotence : une clé stable par intention UI, transaction T0029
  autoritaire ;
- logs/vie privée : aucun log de requête, token, header ou réponse interne.

## Maintenance review

- dettes applicables : `KI-005` sur le mélange UI/orchestration/données ; la
  fonctionnalité est découpée entre transport, modèle et UI ;
- dette créée ou aggravée : aucune attendue ; auth, catalogue et intégration de
  route restent des capacités futures explicites, pas des contournements ;
- règle de sécurité : aucune règle nouvelle, application des invariants T0024 ;
- contrôle manuel à automatiser : aucun appel réel desktop n’est admis dans ce
  ticket ; le contrat est testé par fetch injecté ;
- risque résiduel : absence de parcours auth/offre intégré et de cible distante.

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

1. Exécuter les tests du panneau avec une commande injectée contrôlable.
2. Confirmer visuellement dans le DOM de test les états prêt, pending, owned et
   les deux familles d’erreur.
3. Déclencher deux clics puis un retry et confirmer le nombre d’appels et la clé
   stable.
4. Inspecter le diff et les bundles texte pour confirmer l’absence de
   `service_role`, token factice, `/rest/v1/` et mutation directe.

Temps cible : 10 minutes.

## Rollback

Supprimer la fonctionnalité frontend et rétablir l’inventaire/documentation. Le
ticket ne modifie aucune donnée, cible distante, migration ou configuration de
session.

## Completion Report

### Summary

Une commande frontend ferme la requête à l'Edge Function d'achat, valide cible,
UUID, statut et contrat v1, expire après cinq secondes et redige toute erreur.
Le panneau React reçoit session et offre par injection, bloque la concurrence et
conserve une clé d'idempotence stable pour les retries.

### Files changed

- transport, panneau et deux fichiers de tests sous
  `apps/desktop/src/features/aircraft-purchase/` ;
- inventaire d'autorité synchronisé sans relâcher le scan client ;
- nouveau ticket, index, T0036, qualité et état courant réconciliés.

Aucun manifeste, lockfile, backend, CSP, configuration Tauri, route, auth,
catalogue ou donnée n'est modifié.

### Commands and results

- première restauration `pnpm.cmd install --frozen-lockfile` dans le bac à sable
  — bloquée par `EACCES` réseau, puis PASS avec accès autorisé, 160 paquets
  réutilisés depuis le store et lockfile inchangé ;
- `pnpm.cmd frontend:typecheck` — PASS ;
- `pnpm.cmd frontend:test` — PASS, 5 fichiers/38 tests ;
- `pnpm.cmd frontend:coverage` — PASS, 91,52 % statements, 88,78 % branches,
  91,30 % fonctions et 93,10 % lignes ;
- `pnpm.cmd frontend:build` — PASS, bundle JS 233,02 kB / 74,72 kB gzip ;
- `pnpm.cmd authority:check` — PASS, 5 mutations ;
- `pnpm.cmd data-policy:check` — PASS, 6 mutations ;
- `pnpm.cmd maintenance:check` — PASS, 8 mutations ;
- `git diff --check` — PASS.

### Manual verification result

PASS le 2 août 2026 via DOM jsdom contrôlé : états prêt, pending, owned,
rejected et unavailable inspectés ; double clic limité à un appel ; retry avec
la même clé ; changement d'offre avec nouvelle clé ; démontage avec annulation.
L'inspection du bundle ne trouve ni token/clé factices, ni `service_role`, ni
accès `/rest/v1/`. Aucun appel réseau live n'a été exécuté ou revendiqué.

### Security and maintenance review result

Le client n'envoie que l'offre et l'idempotence comme payload métier. Bearer et
clé anonyme restent des headers injectés et ne sont ni persistés, ni rendus, ni
journalisés. Les cibles HTTP distantes et réponses non allowlistées échouent
fermées. `KI-005` n'est pas aggravé : transport et UI restent séparés. Aucune
dette, règle, exception de sécurité ou dépendance nouvelle n'est créée.

### Risks and limitations

La CSP de production reste `connect-src 'none'` et aucune configuration Vite
n'est exposée. Le panneau n'est donc pas routé ni branché à une cible réelle ;
il attend un futur fournisseur de session et d'offre. Auth, refresh, catalogue,
staging/cloud, rate limiting et parcours E2E restent non prouvés. Aucun credential
privilégié n'est nécessaire ou admis.

### Follow-ups

- cadrer séparément la configuration de connexion, le cycle de session desktop
  et l'ouverture CSP minimale avec une cible locale/staging identifiée ;
- intégrer ensuite auth, requête d'offres et route sans déplacer l'autorité du
  serveur ;
- conserver T0032 en `Draft` jusqu'aux décisions de location d'Andy.

### Documentation updated

Ce ticket, T0036, l'index, `CURRENT_STATE.md`, `QUALITY.md` et l'inventaire
d'autorité.

### Git status

- branche : `feature/T0037-desktop-aircraft-purchase` ;
- base : `origin/main` au commit `82e79ea` ;
- commit d'implémentation : `3220394` ;
- PR #64 : fusionnée dans `main` au commit `47cd50c`, base `main`, head
  `feature/T0037-desktop-aircraft-purchase` ;
- checks GitHub : Windows multi-stack, PostgreSQL 17 et supply-chain réussis ;
- fusion finale réalisée par Andy.
