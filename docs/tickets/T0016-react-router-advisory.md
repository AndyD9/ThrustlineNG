# T0016 — Corriger l’avis de sécurité React Router

Status: Done
Owner: Andy
Branch: `security/t0016-react-router-advisory`
Phase: 1
Risk: High
Security-sensitive: Yes

## Goal

Retirer la version de React Router concernée par `GHSA-qwww-vcr4-c8h2` sans
affaiblir le gate supply-chain de T0013 ni régresser la navigation du frontend.

## Context

T0013 a ajouté un audit pnpm qui échoue correctement sur `react-router` 7.18.1.
L’avis GitHub classe la vulnérabilité haute et annonce une correction à partir
de React Router 8.3.0. React Router v8 supprime le paquet de réexport
`react-router-dom` ; les imports déclaratifs doivent donc utiliser
`react-router`.

La branche est empilée sur `foundation/t0013-multistack-ci` afin d’exécuter le
gate qui a découvert le problème. Sa Pull Request doit conserver cette branche
comme base jusqu’à intégration de la correction dans T0013.

## Dependencies

- implémentation T0013 présente sur la branche de base ;
- `GHSA-qwww-vcr4-c8h2` ;
- guide officiel de migration React Router v7 vers v8 ;
- Node 24.18.0, React 19.2.8 et Vite 8.1.5 déjà épinglés.

## Allowed areas

- `eng/versions.json` ;
- `apps/desktop/package.json` ;
- `apps/desktop/src/app/App.tsx` ;
- `apps/desktop/src/app/routes.tsx` ;
- `apps/desktop/src/pages/HomePage.tsx` ;
- `apps/desktop/src/pages/NotFoundPage.tsx` ;
- `pnpm-lock.yaml` ;
- `docs/CURRENT_STATE.md` ;
- `docs/KNOWN_ISSUES.md` ;
- `docs/QUALITY.md` ;
- `docs/STACK.md` ;
- ce ticket, `docs/tickets/T0013-ci-multi-stack.md` et
  `docs/tickets/README.md`.

## Do not touch

- workflows et scripts CI de T0013 ;
- autres dépendances frontend, Tauri, Rust, .NET ou Supabase ;
- logique des routes, pages ou design ;
- seuil du gate supply-chain ou configuration d’audit ;
- backend, bridge, SimConnect, migrations et contrats ;
- packaging, signature, updater et publication.

## Requirements

### 1. Mettre à jour la dépendance vulnérable

- Remplacer `react-router-dom` 7.18.1 par `react-router` 8.3.0 exact.
- Mettre à jour la source canonique de versions et le lockfile avec pnpm 11.17.0.
- Ne pas ajouter d’override, d’exception d’audit ou de dépendance non liée.

### 2. Préserver le routage déclaratif

- Importer `HashRouter`, `Routes`, `Route` et `Link` depuis `react-router`.
- Ne modifier ni la table des routes, ni les URL, ni le comportement de repli.
- Conserver le fonctionnement sous WebView2/Tauri sans introduire de mode
  framework ou serveur.

### 3. Prouver la correction

- `pnpm audit --audit-level high` ne doit plus signaler
  `GHSA-qwww-vcr4-c8h2`.
- Typecheck, tests frontend, couverture et build doivent réussir.
- Le harnais CI T0013 doit rester inchangé et réussir.
- La CI GitHub supply-chain doit devenir verte avant promotion du ticket.

## Non-goals

- Adopter les fonctionnalités framework, loaders, actions ou middleware.
- Refactorer la navigation ou ajouter des routes.
- Corriger les avertissements Cargo suivis par `KI-019`.
- Mettre à jour une autre dépendance.
- Modifier ou neutraliser le gate de T0013.

## Acceptance criteria

- [x] `react-router-dom` n’est plus une dépendance ni un import runtime.
- [x] `react-router` 8.3.0 est épinglé dans la source de versions, le manifeste
      et le lockfile.
- [x] `GHSA-qwww-vcr4-c8h2` n’est plus présent dans l’audit pnpm.
- [x] Typecheck, tests, couverture et build frontend réussissent.
- [x] Les routes et la page 404 restent couvertes et fonctionnelles.
- [x] Le harnais CI T0013 reste vert sans changement de seuil.
- [x] La documentation et `KI-018` reflètent les preuves réellement observées.

## Security review

- actifs/données : navigation cliente, état de session futur et intégrité des
  actions déclenchées depuis l’interface ;
- frontière : contenu WebView non fiable vers le routeur client ;
- abus : conservation d’une dépendance vulnérable, exception d’audit, migration
  majeure masquant une régression de navigation ;
- validation/autorisation : version exacte, audit haute sévérité, lockfile figé
  et tests de routes ; aucune autorité métier n’est ajoutée au client ;
- atomicité/idempotence : aucune mutation métier ou persistante dans ce ticket ;
- logs/vie privée : aucun secret, jeton, donnée personnelle ou nouveau log.

## Automated validation

```powershell
pnpm install --frozen-lockfile
pnpm audit --audit-level high
pnpm frontend:typecheck
pnpm frontend:test
pnpm frontend:coverage
pnpm frontend:build
pnpm ci:check
git diff --check
```

## Manual verification

1. Démarrer le frontend.
2. Ouvrir la route d’accueil et naviguer avec les liens disponibles.
3. Ouvrir une URL inconnue et confirmer la page 404.
4. Utiliser le lien de retour et confirmer le retour à l’accueil sans
   rechargement ni erreur console.

Temps cible : 5 minutes.

## Rollback

Abandonner la branche avant fusion. Après fusion, ouvrir un ticket correctif ;
ne pas réintroduire la version vulnérable ni ajouter une exception au gate.

## Completion Report

### Summary

React Router 7.18.1 et le paquet de réexport `react-router-dom` sont remplacés
par `react-router` 8.3.0 exact. Les imports déclaratifs, le libellé visible de
l’accueil, la source de versions et le lockfile sont alignés. L’audit local ne
trouve plus de vulnérabilité connue et la navigation SPA reste fonctionnelle.
Les workflows GitHub Windows, Supabase et supply-chain sont verts. Andy a
fusionné la PR #16 dans T0013 le 29 juillet 2026, puis la PR #15 a propagé la
correction dans `main`. Le ticket passe à `Done`.

### Files changed

- dépendance et lockfile : `apps/desktop/package.json`, `pnpm-lock.yaml` ;
- source canonique : `eng/versions.json` ;
- imports et libellé : `App.tsx`, `routes.tsx`, `HomePage.tsx` et
  `NotFoundPage.tsx` ;
- documentation : `CURRENT_STATE.md`, `KNOWN_ISSUES.md`, `QUALITY.md`,
  `STACK.md`, le suivi T0013, ce ticket et l’index.

### Commands and results

- `pnpm.cmd --version` : réussi, 11.17.0 ;
- `node --version` : réussi, 24.18.0 ;
- `pnpm.cmd install --lockfile-only` : réussi avec accès au registre ; le
  premier essai en bac à sable a échoué par `EACCES`, avant régénération ;
- `pnpm.cmd install --frozen-lockfile` : réussi ;
- `pnpm.cmd audit --audit-level high` : réussi, aucune vulnérabilité connue ;
- `pnpm.cmd frontend:typecheck` : réussi ;
- `pnpm.cmd frontend:test` : réussi, 3 fichiers et 8 tests ;
- `pnpm.cmd frontend:coverage` : réussi, 73,68 % statements et 77,77 % lines ;
- `pnpm.cmd frontend:build` : réussi, 79 modules transformés ;
- `pnpm.cmd ci:check` : bloqué par l’environnement, `pwsh` absent ;
- `tests/ci/run.ps1` sous Windows PowerShell 5.1 : réussi sur le dépôt et les
  deux mutations négatives ;
- `scripts/check-toolchain.ps1` et `tests/toolchain/run.ps1` sous Windows
  PowerShell 5.1 : non exécutés, les scripts exigent PowerShell 7.6 ;
- `git diff --check` : réussi, avec avertissements informatifs LF/CRLF ;
- GitHub CI `30440481257` : réussi ; Windows multi-stack en 8 min 55 s et
  Supabase PostgreSQL 17 en 2 min 30 s ;
- GitHub supply-chain `30440480513` : réussi en 3 min 48 s ; audits, licences,
  Gitleaks et SBOM sont verts, notamment le gate pnpm.

### Manual verification result

Réussie dans le navigateur intégré sur le serveur Vite local. L’accueil affiche
React Router 8, `#/route-inconnue` présente la page 404, le lien
`Retour à l’accueil` revient sur `#/` sans rechargement applicatif et aucun log
console de niveau erreur n’est observé. Le serveur local a ensuite été arrêté.

### Risks and limitations

- PowerShell 7.6 est absent localement ; les contrôles canoniques de toolchain
  ont toutefois réussi dans le job Windows GitHub.
- React Router 8 exige Node >=22.22 et React/React DOM >=19.2.7 ; les pins du
  dépôt, Node 24.18.0 et React 19.2.8, satisfont ces bornes.
- La correction est présente dans `main` via les PR #16 puis #15.

### Follow-ups

- Aucun follow-up pour `GHSA-qwww-vcr4-c8h2`.
- Conserver les mises à jour majeures du routeur dans des tickets sécurité
  bornés avec audit et tests de navigation.

### Documentation updated

`CURRENT_STATE.md`, `KNOWN_ISSUES.md`, `QUALITY.md`, `STACK.md`, le suivi T0013
et l’index reflètent la correction, les fusions et les preuves GitHub.
