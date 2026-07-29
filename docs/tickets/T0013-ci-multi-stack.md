# T0013 — Consolider la CI multi-stack

Status: Verify
Owner: Andy
Branch: `foundation/t0013-multistack-ci`
Phase: 1
Risk: High
Security-sensitive: Yes

## Goal

Fournir une CI GitHub reproductible qui valide séparément les stacks Windows et
Supabase, contrôle la supply chain sans secret de dépôt et conserve pendant
30 jours les preuves non signées nécessaires à la revue.

## Context

Le dépôt cible épingle déjà Node, pnpm, Rust, .NET, Tauri et Supabase, mais ne
contient aucun workflow dans `.github/workflows/`. `CURRENT_STATE.md` mentionne
encore les workflows de l'ancien dépôt : cette affirmation doit être corrigée,
car une capacité historique non importée n'est pas une capacité du nouveau
socle.

T0012 est implémenté au commit `8b6df56` et fusionné dans `main` par la PR #14,
mais reste `Verify` : Docker Desktop 29.6.2 publie encore les ports Supabase hors
loopback sur la machine locale et le fail-safe arrête la pile. Andy a autorisé
le 29 juillet 2026 l'exécution de T0013 sans falsifier cette preuve. La PR T0013
cible désormais `main`.

ADR-0004 et `STACK.md` imposent un runner Windows explicite, des actions
épinglées par SHA, des permissions minimales, des caches dérivés uniquement des
lockfiles, les audits pnpm/NuGet/Rust, un contrôle de licences, un scan de
secrets, un SBOM et une rétention de 30 jours pour les artefacts de build.

## Dependencies

- implémentation T0006 présente dans `main` ;
- implémentations T0007–T0011 présentes dans `main` ;
- implémentation T0012 présente dans `main` au commit `8b6df56`, sans
  revendiquer sa vérification manuelle ;
- `docs/decisions/ADR-0004-stack-cible.md` ;
- `docs/STACK.md`, `docs/SECURITY.md` et `docs/QUALITY.md`.

## Allowed areas

- `.github/workflows/` ;
- `package.json` si des commandes CI racine sont nécessaires ;
- `scripts/ci/` ;
- `tests/ci/` ;
- `.gitignore` pour les sorties locales reproductibles ;
- `docs/ARCHITECTURE.md` ;
- `docs/SECURITY.md` ;
- `docs/QUALITY.md` ;
- `docs/SETUP.md` ;
- `docs/CURRENT_STATE.md` ;
- `docs/KNOWN_ISSUES.md` ;
- ce ticket et `docs/tickets/README.md`.

## Do not touch

- code runtime sous `apps/desktop/` et `apps/bridge/` ;
- contrats REST/SignalR, SimConnect et traces ;
- migrations, seed, politiques RLS et types générés T0012 ;
- versions ou lockfiles applicatifs, sauf nécessité prouvée d'une commande CI ;
- projet Supabase distant, secrets, environnements GitHub et règles de branche ;
- packaging installable, signature, updater, publication de release ou
  provenance signée ;
- seuils de performance T0015 ;
- fusion de T0012 ou T0013 dans `main`.

## Requirements

### 1. Définir les frontières de workflow

- Déclencher la CI sur les Pull Requests et les pushes vers `main`.
- Interdire `pull_request_target` et toute exécution de code de PR avec secret.
- Fixer `permissions: contents: read` au niveau workflow et ne demander aucune
  permission d'écriture.
- Annuler une exécution devenue obsolète par branche ou Pull Request.
- Utiliser des labels de runners versionnés, jamais `*-latest`.

### 2. Épingler les actions et restaurations

- Épingler chaque `uses:` à un SHA Git complet de 40 caractères avec le tag
  vérifié en commentaire.
- Désactiver la persistance des credentials Git après checkout.
- Installer les versions exactes depuis `.node-version`, `global.json`,
  `rust-toolchain.toml` et le champ `packageManager`.
- Utiliser `pnpm install --frozen-lockfile`.
- Tout cache activé doit utiliser un chemin de lockfile versionné comme clé ou
  source de dépendance.

### 3. Valider la stack Windows

- Utiliser un runner Windows explicite.
- Exécuter le contrôle de toolchain et son harnais.
- Exécuter typecheck, tests, couverture et build frontend.
- Exécuter format/check/Clippy, tests et build Tauri sans bundle.
- Exécuter build, tests, health check et publication self-contained du bridge.
- Conserver les preuves de couverture et les binaires non signés pendant
  30 jours, sans les présenter comme un installateur ou une release.

### 4. Valider le backend réel

- Utiliser un runner Linux explicite avec Docker.
- Exécuter le harnais statique T0012.
- Créer un réseau Docker demandant la liaison loopback, démarrer Supabase sans
  afficher ses credentials, puis inspecter les ports réellement publiés.
- Échouer et arrêter immédiatement si un port est publié sur toutes les
  interfaces.
- Exécuter deux resets locaux, les fichiers pgTAP avec un résultat PASS et le
  contrôle des types générés.
- Arrêter la pile dans une étape `always()`, même après échec.
- Ne jamais exposer de commande `link`, `db push`, `--linked` ou de projet
  distant.

### 5. Contrôler la supply chain

- Échouer sur une vulnérabilité pnpm de sévérité haute ou critique.
- Exécuter l'audit NuGet transitif et `cargo audit` sur les lockfiles.
- Scanner l'historique accessible à la CI pour les secrets sans injecter de
  secret applicatif.
- Produire un inventaire de licences pour pnpm, Cargo et NuGet ; les licences
  absentes ou explicitement interdites doivent échouer avec le nom du composant,
  jamais avec le contenu d'une variable d'environnement.
- Produire un SBOM SPDX JSON à partir du checkout restauré.
- Conserver rapports de licences, audits et SBOM pendant 30 jours.

### 6. Tester les invariants de CI hors GitHub

- Ajouter un harnais PowerShell déterministe vérifiant les événements,
  permissions, runners, pins SHA, credentials checkout, rétention, commandes,
  nettoyage backend, audits, licences, scan de secrets et SBOM.
- Le harnais doit injecter au moins deux mutations négatives : action remplacée
  par un tag mutable et permission d'écriture.
- Aucun contrôle ne doit déduire un succès d'un job GitHub non exécuté.

### 7. Documenter l'exploitation

- Documenter la matrice de jobs, les artefacts et les limites.
- Distinguer validation locale du workflow, exécution GitHub observée et future
  protection de branche.
- Documenter que les artefacts sont non signés et que T0014/Phase 6 restent
  responsables du packaging, de la signature, de l'updater et de la provenance.

## Non-goals

- Configurer des secrets, environnements protégés ou permissions d'écriture.
- Modifier les règles de branche GitHub.
- Déployer Supabase ou publier un artefact.
- Signer, attester ou distribuer les binaires.
- Ajouter Dependabot/Renovate ou automatiser les mises à jour.
- Corriger l'exposition Docker Desktop locale de T0012.
- Valider Windows 11 ou MSFS 2024 sur un runner GitHub.

## Acceptance criteria

- [x] Les workflows utilisent uniquement des runners explicites et des actions
      épinglées par SHA.
- [x] Les permissions sont en lecture seule et aucun secret applicatif n'est
      utilisé sur Pull Request.
- [x] La stack Windows exécute tous les gates frontend, desktop et bridge
      applicables depuis les lockfiles.
- [x] Le job backend exige reset, pgTAP, types et liaison loopback effective,
      avec arrêt garanti.
- [x] pnpm, NuGet, Cargo, licences, secrets et SBOM possèdent chacun un contrôle
      explicite.
- [x] Les artefacts non signés et rapports sont nommés sans ambiguïté et
      conservés 30 jours.
- [x] Le harnais CI passe sur le dépôt et échoue sur les deux mutations
      négatives.
- [x] Les validations locales applicables passent et les jobs GitHub non encore
      observés restent consignés comme tels.
- [x] La documentation et le Completion Report reflètent la branche empilée et
      le statut réel de T0012.

## Security review

- actifs/données : code source, lockfiles, artefacts de build, rapports de
  vulnérabilités, inventaire de dépendances et historique Git ;
- frontière : code de Pull Request non fiable vers runners GitHub et actions
  tierces ; aucun accès aux environnements ou secrets applicatifs ;
- abus : action mutable compromise, exfiltration de credentials checkout,
  permission d'écriture, cache empoisonné, commande distante Supabase, fuite de
  token, artefact trompeusement présenté comme signé ;
- validation/autorisation : SHA complets, permissions lecture seule, checkout
  sans credentials persistants, lockfiles figés, harnais à mutations négatives ;
- atomicité/idempotence : jobs reproductibles, backend jetable et nettoyage
  `always()` ; aucun état distant modifié ;
- logs/vie privée : rapports de dépendances publics uniquement ; aucune variable,
  JWT, clé Supabase, donnée personnelle ou sortie de démarrage contenant des
  credentials.

## Automated validation

```powershell
# Depuis la racine, PowerShell 7.6
$env:CI = 'true'
pnpm install --frozen-lockfile
pnpm ci:check
pnpm supply-chain:report
pnpm frontend:typecheck
pnpm frontend:test
pnpm frontend:coverage
pnpm frontend:build
pnpm desktop:check
pnpm desktop:test
pnpm desktop:build
pnpm bridge:build
pnpm bridge:test
pnpm bridge:health
pnpm bridge:publish
pnpm backend:check
git diff --check
```

Les audits réseau, le scan complet, le SBOM Syft et le backend Docker Linux sont
validés par leurs jobs GitHub. Une absence de résultat GitHub est `non exécuté`,
pas un succès.

## Manual verification

1. Ouvrir chaque workflow et confirmer événements, permissions et runners.
2. Vérifier que chaque `uses:` contient un SHA de 40 caractères et un tag en
   commentaire.
3. Vérifier qu'aucune référence `secrets.*`, commande Supabase distante ou
   permission d'écriture n'est présente.
4. Inspecter les noms, chemins et rétention des artefacts.
5. Après push, ouvrir l'exécution GitHub et confirmer que chaque job a réellement
   exécuté ses tests, audits et génération de rapports.
6. Télécharger les artefacts et confirmer qu'ils contiennent couverture,
   bridge non signé, licences et SBOM sans credential.

Temps cible : 10 minutes hors durée des jobs.

## Rollback

Abandonner la branche avant fusion. Après fusion, rétablir un workflow par une
PR corrective ; ne jamais désactiver une protection ou élargir les permissions
pour contourner un échec. Les artefacts GitHub expirent automatiquement après
30 jours et aucune release n'est créée.

## Completion Report

### Summary

Deux workflows en lecture seule couvrent maintenant la validation Windows et
Supabase Linux, puis les audits, licences, secrets et SBOM. Les actions sont
épinglées par SHA, les credentials checkout ne persistent pas et aucun cache de
dépendances n'est activé. Les rapports continuent à être produits après un
scanner en échec, puis un gate final agrège les résultats.

L'exécution GitHub `30437716790` valide les jobs Windows et Supabase. Le
workflow supply-chain `30437717487` produit tous ses rapports puis échoue
uniquement sur le gate pnpm, qui révèle la vulnérabilité haute préexistante
React Router suivie par `KI-018`. Le ticket passe donc `Verify`, pas `Done`.
T0012 reste `Verify` malgré son intégration dans `main`. La PR T0013 cible
désormais `main`.

### Files changed

- workflows : `.github/workflows/ci.yml` et
  `.github/workflows/security.yml` ;
- commandes : `package.json` ;
- exécution CI : `scripts/ci/test-backend.ps1` et
  `scripts/ci/write-license-report.ps1` ;
- preuve statique : `tests/ci/run.ps1` ;
- documentation : `CURRENT_STATE.md`, `QUALITY.md`, `SECURITY.md`, `SETUP.md`,
  `KNOWN_ISSUES.md`, ce ticket et l'index.

### Commands and results

- `pnpm install --frozen-lockfile` avec pnpm 11.17.0 : réussi ;
- `tests/ci/run.ps1` : réussi sur le dépôt et deux mutations négatives ;
- parsing PowerShell des trois nouveaux scripts : réussi, aucune erreur ;
- validation YAML locale par analyseur dédié : non exécutée, aucun `actionlint`
  ou module YAML n'est installé ; GitHub doit encore parser les workflows ;
- `pnpm frontend:typecheck` : réussi ;
- `pnpm frontend:test` : réussi, 3 fichiers et 8 tests ;
- `pnpm frontend:coverage` : réussi, 73,68 % statements et 77,77 % lines,
  sans seuil imposé ;
- `pnpm frontend:build` : réussi ;
- `pnpm desktop:check` : réussi, format, check et Clippy sans avertissement ;
- `pnpm desktop:test` : réussi, 8 tests frontend, 2 tests Rust et harnais shell ;
- `pnpm desktop:build` : réussi, binaire release non signé ;
- `dotnet build ThrustlineNG.slnx --configuration Release` : réussi hors bac à
  sable, 0 avertissement et 0 erreur ;
- harnais bridge : réussi, 13/13 tests ;
- health check bridge : réussi, `Healthy` ;
- publication bridge self-contained `win-x64` : réussie ;
- `pnpm backend:check` : réussi, dépôt et deux mutations T0012 ;
- `pnpm backend:start` : échec de sécurité identique à T0012 ; Docker Desktop
  publie hors loopback et la pile est arrêtée ;
- rapport de licences : réussi, 566 composants tiers acceptés ;
- audit NuGet transitif : réussi, aucun package vulnérable ;
- `cargo audit 0.22.2 --file apps/desktop/src-tauri/Cargo.lock --json` :
  réussi, 405 dépendances et 0 vulnérabilité ; avertissements informatifs
  consignés dans `KI-019` ;
- `pnpm audit --audit-level high` : échoué, une vulnérabilité haute
  `GHSA-qwww-vcr4-c8h2` dans `react-router` 7.18.1, consignée dans `KI-018` ;
- Gitleaks, Syft/SPDX et backend Docker Linux : non exécutés localement, réservés
  aux jobs GitHub ;
- GitHub CI `30437716790` : réussi ; Windows, bridge, artefact non signé,
  backend loopback, deux resets, deux fichiers pgTAP, types stables et arrêt
  Supabase sont tous réussis ;
- GitHub supply-chain `30437717487` : NuGet, Cargo, Gitleaks, licences, SBOM et
  upload réussis ; gate final échoué uniquement sur `KI-018`, comme attendu ;
- `git diff --check` : réussi.

Le premier lancement .NET en bac à sable a échoué avant compilation par refus
d'accès à la configuration NuGet utilisateur ; la même séquence a réussi hors
bac à sable. Le premier rapport de licences a révélé puis fait corriger la forme
JSON .NET 10 sans package tiers.

### Manual verification result

Terminée pour la CI. Les événements, permissions, runners, SHA d'actions,
credentials, commandes et rétention ont été inspectés. Les artefacts
supply-chain et Windows ont été téléchargés : les cinq rapports, la couverture,
le binaire desktop et le bridge self-contained sont présents. La recherche de
motifs de credentials n'a produit aucun résultat. Les artefacts restent
explicitement non signés.

### Risks and limitations

- Le workflow supply-chain doit rester rouge tant que `KI-018` n'est pas
  corrigé ; le seuil ne doit pas être abaissé.
- Le runner Windows nu ne contient pas les runtime packs self-contained
  `win-x64`. La CI les restaure en mode verrouillé depuis l'unique source
  officielle NuGet, sans modifier la configuration fermée du dépôt ni ajouter
  de dépendance tierce.
- `cargo audit` signale des chemins GTK3 non maintenus et `glib` unsound dans le
  lockfile multi-plateforme ; aucune vulnérabilité n'est signalée et la cible
  Windows n'emprunte pas ces dépendances, mais `KI-019` reste ouvert.
- Tout futur package NuGet tiers est conservativement classé `NOASSERTION` par
  le rapport local et bloquera jusqu'à l'ajout d'une source de licence fiable.
- Gitleaks v3 n'exige pas de licence pour le compte personnel actuel ; un
  transfert du dépôt à une organisation exige une décision avant activation.
- Les runners GitHub Windows Server ne prouvent ni Windows 11 ni MSFS 2024.
- Les artefacts sont non signés et ne constituent ni un installateur, ni une
  release, ni une provenance.

### Follow-ups

- Corriger `KI-018` dans un ticket sécurité borné avec mise à jour de
  `eng/versions.json`, du manifest desktop et du lockfile.
- Revoir `KI-019` lors de la maintenance Tauri/Cargo.
- Intégrer la correction T0016 de `KI-018`, puis confirmer que le workflow
  supply-chain devient vert avant de promouvoir T0013.
- T0014 reste dépendant d'une CI révisable et du traitement des blocages.

### Documentation updated

`CURRENT_STATE.md`, `QUALITY.md`, `SECURITY.md`, `SETUP.md`,
`KNOWN_ISSUES.md` et l'index distinguent l'implémentation locale, la preuve
GitHub observée, les artefacts non signés et les deux problèmes supply-chain
découverts.
