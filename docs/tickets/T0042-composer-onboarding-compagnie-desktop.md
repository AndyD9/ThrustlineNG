# T0042 — Composer l'onboarding de compagnie depuis le desktop

Status: Done
Owner: Andy
Branch: `feature/T0042-desktop-company-onboarding`
Phase: 4
Risk: High
Security-sensitive: Yes

## Goal

Permettre à une session desktop authentifiée en mémoire de créer sa compagnie
via la frontière serveur T0023, avec une intention idempotente et des erreurs
actionnables, sans donner d'autorité métier au client.

## Context

T0022 crée atomiquement compagnie, sujets privés et ouverture financière. T0023
expose cette transaction derrière `company-onboarding`, mais aucun appelant
desktop ne la consomme. T0038–T0041 fournissent la configuration locale, la
session en mémoire et la route protégée. T0041 est livré dans `main` par la PR
corrective #69. La fusion empilée #70 n'avait pas livré T0042 dans `main`; la PR
corrective #73 l'y a finalement propagé.

## Workflow evidence

- 2 août 2026 — `Ready` : T0022–T0023 et T0038–T0040 sont livrés ; T0041 est
  implémenté, validé et republié vers `main` dans la PR corrective #69.
- 2 août 2026 — `In progress` : branche
  `feature/T0042-desktop-company-onboarding` créée au-dessus de
  `feature/T0041-bounded-login-route` au commit `4f023df`; dépendance empilée
  explicite jusqu'à la fusion de T0041.
- 2 août 2026 — `Review` : commande, intention, composition, revue adversariale
  et validations automatisées terminées ; la branche reste empilée sur
  T0041/PR #69 et ne peut pas cibler `main` indépendamment.
- 2 août 2026 — publication : commit `c2e1c32` poussé ; PR #70 ouverte en
  brouillon avec base `feature/T0041-bounded-login-route` et head
  `feature/T0042-desktop-company-onboarding`.
- 2 août 2026 — réconciliation de livraison : PR #69 fusionnée dans `main` au
  commit `cb179e9`, puis PR #70 fusionnée dans la branche T0041 déjà intégrée ;
  les commits T0042 restent absents de `main`. `origin/main` est fusionné sans
  réécriture dans la branche T0042 pour permettre une PR corrective.
- 2 août 2026 — republication : branche réconciliée poussée au commit `7a5b95b` ;
  PR corrective #71 ouverte prête, base `main`, head
  `feature/T0042-desktop-company-onboarding`.
- 3 août 2026 — `Done` : PR corrective #73 fusionnée dans `main` au commit
  `a4047a5`, avec Windows multi-stack, PostgreSQL 17 et supply-chain réussis.

## Dependencies

- T0022 — création de compagnie et ouverture financière atomiques ;
- T0023 — Edge Function authentifiée `company-onboarding` ;
- T0038–T0040 — configuration locale, session et Auth password active ;
- T0041 / PR #69 — route protégée et déconnexion, non encore fusionnée.

## Allowed areas

- nouveau module sous `apps/desktop/src/features/company-onboarding/` et tests ;
- composition sous `apps/desktop/src/app/` et tests associés ;
- `apps/desktop/src/pages/HomePage.tsx` et tests associés ;
- `apps/desktop/src/styles/index.css` ;
- invariant frontend sous `apps/desktop/src/test/` ;
- ce ticket, l'index, `CURRENT_STATE.md`, `QUALITY.md` et `SECURITY.md`.

## Do not touch

- migrations, fonctions Edge, RPC, RLS, seed, types et politique économique ;
- catalogue, achat, location, flotte, finance et données réelles ;
- persistance Windows ou Web, cookies et gestionnaire de credentials ;
- inscription, récupération, OAuth et contrat de session T0038–T0040 ;
- CSP, cible distante, staging, production, Rust/Tauri, bridge et lockfiles.

## Requirements

### 1. Commande desktop fermée

- Envoyer exactement `companyName` normalisé et `idempotencyKey` à
  `/functions/v1/company-onboarding`.
- Fournir uniquement la clé anonyme publique et le bearer obtenu du gestionnaire
  de session ; ne jamais accepter propriétaire, montant ou devise côté UI.
- Borner nom, headers, cible, délai et réponse ; valider strictement la réponse
  allowlistée de T0023 et rediger tout détail amont.

### 2. Intention idempotente

- Générer une clé UUID par intention de création.
- Réutiliser cette clé après panne transitoire ou réponse perdue pour le même nom.
- Créer une nouvelle intention si le nom change avant un nouvel essai.
- Bloquer les soumissions concurrentes et annuler la requête au démontage.

### 3. Composition authentifiée

- Rendre le formulaire uniquement derrière la garde T0041.
- Obtenir un bearer valide via le gestionnaire T0038 au moment de la soumission,
  sans copier les tokens dans l'état React.
- En cas d'expiration Auth, effacer la session puis revenir au login ; conserver
  les refus métier et indisponibilités comme états actionnables.
- Ne rendre ni nom soumis après succès, ni identifiant, token ou détail backend.

## Non-goals

- détecter ou charger une compagnie existante avant rendu ;
- persister l'intention ou reprendre après redémarrage/reconnexion ;
- catalogue, achat, location, flotte ou golden path composé ;
- modifier T0022, T0023, la politique d'ouverture ou le backend ;
- preuve WebView live, cible distante, staging, production ou donnée réelle.

## Acceptance criteria

- [x] Une session protégée peut soumettre un nom valide et afficher le succès.
- [x] Le payload client contient uniquement nom et idempotence ; propriétaire,
      montant et devise ne sont jamais dérivés ou envoyés par le desktop.
- [x] Un retry transitoire réutilise la clé ; un changement de nom la renouvelle.
- [x] Double soumission, démontage, expiration Auth et réponse invalide sont
      couverts sans fuite de credential ou de détail amont.
- [x] Aucun appel réseau n'a lieu au rendu ; aucune persistance n'est ajoutée.
- [x] Tests ciblés, typecheck, couverture, build et gates applicables passent.
- [x] Documentation et statut reflètent la dépendance empilée sur T0041.

## Security review

- actifs/données : bearer/refresh token en mémoire, nom de compagnie, intention
  UUID et résultat de création ;
- frontière : WebView non fiable → Edge Function T0023 → RPC T0022 ;
- abus : propriétaire/prix/devise injectés, rejeu divergent, double clic, fuite
  de bearer, réponse forgée et contournement de la garde ;
- validation/autorisation : T0023 vérifie Auth et dérive le propriétaire ; le
  desktop ferme payload, cible et réponse sans calcul métier ;
- atomicité/idempotence : T0022 reste transactionnel ; le client conserve une
  clé par intention tant que le panneau reste monté ;
- logs/vie privée : aucun log, stockage, cookie ou rendu de credential, nom ou
  identifiant après succès.

## Maintenance review

- dettes applicables : `KI-005`; transport, état de feature, page et composition
  doivent rester séparés ;
- dette créée ou aggravée : aucune lecture de compagnie existante ni reprise
  après redémarrage n'est anticipée ;
- règle de sécurité : la composition onboarding doit être synchronisée dans
  `SECURITY.md` et contrôlée par tests ;
- contrôle manuel à automatiser : payload, retry, expiration et absence de fuite
  sont vérifiables avec fetch/DOM injectés ;
- risque résiduel : WebView compromise, CSP de production fermée, T0041 non
  fusionné et absence de preuve runtime live.

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

1. Rendre l'accueil avec une session synthétique et confirmer zéro réseau.
2. Soumettre un nom valide avec commande injectée et inspecter le payload fermé.
3. Simuler indisponibilité puis retry et confirmer la même clé d'idempotence.
4. Simuler expiration Auth et confirmer effacement puis retour au login.
5. Inspecter DOM, stockage et logs pour confirmer l'absence de secret et de nom
   après succès.

Temps cible : 10 minutes.

## Rollback

Retirer le module onboarding et sa composition de l'accueil. Aucune donnée,
migration, cible, persistance ou politique serveur n'est modifiée.

## Completion Report

### Summary

L'accueil protégé compose désormais la session T0038 avec une commande
`company-onboarding` fermée. Le panneau normalise le nom, conserve un UUID par
intention, obtient le bearer seulement à la soumission et revient au login si
Auth refuse la session.

### Files changed

- nouveau transport et panneau sous `features/company-onboarding/`, avec tests ;
- composition `App`/routes/accueil et styles du formulaire ;
- invariant frontend contre persistance, logs et champs métier interdits ;
- ticket, index, état courant, qualité et sécurité.

Aucun backend, CSP, manifeste, lockfile, catalogue, achat ou stockage n'est
modifié.

### Commands and results

- première commande combinée `pnpm.cmd frontend:typecheck` — FAIL : le mock
  `fetch` du nouveau test était inféré sans arguments ; annotation ajoutée ;
- tentative ciblée `pnpm.cmd --dir apps/desktop exec vitest ...` — FAIL avant
  exécution des tests, forme de commande invalide sous ce shell ;
- `pnpm.cmd frontend:typecheck` — PASS ;
- premier `pnpm.cmd frontend:test` — FAIL, 103 tests passent et un test T0042
  échoue car l'UUID numérique choisi ne changeait pas avec `ToUpperCase()` ;
  fixture remplacée par un UUID contenant des lettres majuscules ;
- `pnpm.cmd frontend:test` — PASS, 11 fichiers/104 tests ; 1 fichier/2 scénarios
  runtime T0040 ignorés sans environnement explicite ;
- `pnpm.cmd frontend:coverage` — PASS, 91,78 % statements, 85,55 % branches,
  93,50 % fonctions et 92,07 % lignes ;
- `pnpm.cmd frontend:build` — PASS, bundle JS 246,92 kB / 78,48 kB gzip ;
- `pnpm.cmd authority:check` — PASS, 5 mutations ;
- `pnpm.cmd data-policy:check` — PASS, 6 mutations ;
- `pnpm.cmd maintenance:check` — PASS, 8 mutations ;
- `git diff --check` — PASS, avertissements LF/CRLF seulement.

### Manual verification result

PASS le 2 août 2026 via fetch et DOM jsdom injectés : zéro réseau au rendu,
payload exact, normalisation, succès sans nom/identifiant/token rendu, retry avec
la même clé, renouvellement après changement de nom, double clic borné, annulation
au démontage et retour au login après effacement d'une session refusée.

### Security and maintenance review result

La WebView ne fournit que nom et idempotence ; T0023 conserve la vérification
Auth et la dérivation du propriétaire, montant et devise restent absents des
sources runtime. Le bearer est obtenu au dernier moment depuis le gestionnaire,
jamais copié dans l'état React. Transport, panneau, page et composition restent
séparés ; `KI-005` n'est pas aggravé. Aucune règle, exception ou dette silencieuse
n'est créée.

### Risks and limitations

T0042 est livré dans `main` par la PR corrective #73. La CSP de
production reste `connect-src 'none'` et la preuve utilise jsdom/fetch injecté :
aucun parcours WebView live, déploiement distant ou donnée réelle n'est
revendiqué. La présence d'une compagnie existante n'est pas chargée avant rendu,
l'intention n'est pas reprise après redémarrage/reconnexion et une WebView
compromise peut lire le bearer en mémoire.

### Follow-ups

- livrer T0042 par une PR corrective vers `main`, sans présenter #70 comme une
  livraison sur la branche par défaut ;
- cadrer une lecture serveur du catalogue avant de composer l'achat T0037 ;
- traiter la persistance Windows dans un ticket de sécurité séparé.

### Documentation updated

Ce ticket, l'index, `CURRENT_STATE.md`, `QUALITY.md` et `SECURITY.md`.

### Git status

- branche : `feature/T0042-desktop-company-onboarding` ;
- base initiale : `feature/T0041-bounded-login-route` au commit `4f023df`, puis
  fusion non destructive de `origin/main` (`cb179e9`) ;
- dépendance T0041 : livrée par la PR #69 ;
- commit d'implémentation : `c2e1c32` ;
- PR #70 : fusionnée avec trois checks verts dans
  `feature/T0041-bounded-login-route`, mais cette base avait déjà fusionné dans
  `main` ;
- PR corrective #73 : fusionnée dans `main` au commit `a4047a5`, head
  `feature/T0042-desktop-company-onboarding`, avec ses trois checks verts ;
  fusion finale réalisée par Andy.
