# T0055 — Fixer la source canonique de version produit et livrer l'alpha technique interne

Status: Verify
Owner: Andy
Branch: `chore/T0055-product-version-source`
Phase: 1–6
Risk: Medium
Security-sensitive: No

## Goal

Créer une source canonique unique de version produit `0.1.0-alpha.1`, la
propager de façon contrôlée au frontend, au shell Tauri, au bridge, à
l'installateur, aux artefacts et à l'affichage applicatif, puis produire l'alpha
technique interne non signée.

## Context

`apps/desktop/package.json`, `tauri.conf.json`, `Cargo.toml` et
`packages/database/package.json` déclarent tous `0.0.0`, et l'installateur T0014
ne porte aucune version produit. La politique de versionnement d'`AGENTS.md`
exige explicitement que le ticket préparant la première alpha synchronise et
contrôle ces versions, sans version opaque ni tag déplacé.

Le jalon « alpha technique interne » de `docs/ROADMAP.md` demande un build
installable interne, des tests automatisés et une vérification WebView locale sur
le parcours login → compagnie → catalogue → achat, déjà présent dans `main`. Ce
ticket rend ce jalon nommable et vérifiable ; il n'ajoute aucune capacité
fonctionnelle.

## Dependencies

- T0006 — source canonique des versions de toolchain, à ne pas mélanger ;
- T0014 — packaging NSIS x64 non signé et son manifeste de hashes ;
- T0015 — budgets de taille des artefacts construits ;
- T0043–T0048 — parcours réellement présent dans `main`.

## Allowed areas

- une nouvelle source canonique `eng/product-version.json` ;
- `apps/desktop/package.json`, `apps/desktop/src-tauri/tauri.conf.json`,
  `apps/desktop/src-tauri/Cargo.toml` et `Cargo.lock` régénéré par cargo ;
- `Directory.Build.props` pour la version du bridge ;
- `scripts/build-windows-package.ps1` et
  `scripts/test-windows-package.ps1` pour le nom d'artefact et le manifeste ;
- un nouveau contrôle `tests/product-version/run.ps1` et son script racine dans
  `package.json` ;
- `apps/desktop/src/` uniquement pour l'affichage de la version et son test ;
- `docs/QUALITY.md`, `docs/SUPPORT.md`, `docs/CURRENT_STATE.md` ;
- ce ticket et `docs/tickets/README.md`.

## Do not touch

- `eng/versions.json` et les pins de toolchain, qui restent indépendants de la
  version produit ;
- signature Authenticode, updater, canaux de release et rollback, gouvernés par
  la phase 6 ;
- backend, migrations, Edge Functions, autorité et politique économique ;
- bridge SimConnect, télémétrie et cycle de vol ;
- budgets de `eng/stability-performance-budgets.json` ;
- création ou publication d'un tag Git, réservée à Andy.

## Requirements

### 1. Source canonique unique

- Déclarer dans `eng/product-version.json` une version SemVer 2.0.0 unique
  `0.1.0-alpha.1`, avec `schemaVersion` et le canal d'alpha interne.
- Interdire toute version opaque, toute concaténation de commit dans la version
  publique et toute réutilisation d'un numéro déjà publié.
- Autoriser une métadonnée de build `+YYYYMMDD.gSHORTSHA` uniquement pour une
  build interne, sans changer l'ordre des versions.

### 2. Propagation contrôlée

- Aligner exactement frontend, shell Tauri, crate Rust et bridge .NET sur la
  version produit, en conservant les versions de schéma, de contrat et d'outils
  indépendantes.
- Nommer l'artefact d'installation `Thrustline-0.1.0-alpha.1-win-x64.exe` et
  reprendre la version telle quelle dans le manifeste de hashes, sans chemin
  utilisateur.
- Afficher la version produit dans l'interface, avec le hash court entre
  parenthèses au plus, sans exposer de chemin, de jeton ou de secret.

### 3. Gate de cohérence

- Ajouter un contrôle exécutable depuis la racine qui échoue si une des cibles
  diverge de la source canonique, si la version n'est pas une préversion SemVer
  valide, ou si le nom d'artefact ne reprend pas exactement la version.
- Couvrir au moins trois mutations négatives : divergence d'une cible, version
  non SemVer et nom d'artefact désynchronisé.

### 4. Preuve du jalon

- Produire localement le package NSIS non signé, vérifier les trois hashes du
  manifeste et les trois statuts `NotSigned`.
- Exécuter un cycle installation, lancement, parcours login → compagnie →
  catalogue → achat sur la pile locale, fermeture et désinstallation, sans
  résidu.
- Consigner le jalon comme alpha technique interne et non comme release
  publique.

## Non-goals

- signer, publier, distribuer ou déposer un tag ;
- créer un updater, un canal bêta, une provenance ou un rollback N-1 ;
- modifier une capacité fonctionnelle, une frontière d'autorité ou un budget ;
- promouvoir un canal Windows/MSFS vers `Supported`.

## Acceptance criteria

- [x] Une source canonique unique porte `0.1.0-alpha.1` et aucune cible ne
      déclare plus `0.0.0`.
- [x] L'installateur, le manifeste et l'affichage applicatif reprennent
      exactement cette version, sans valeur opaque ni chemin utilisateur.
- [x] Le nouveau gate échoue sur au moins trois mutations négatives réellement
      exécutées et passe sur l'état livré.
- [ ] Le package NSIS non signé s'installe, permet le parcours d'alpha technique
      sur la pile locale et se désinstalle sans résidu. Installation, lancement,
      bridge `Healthy`/`0`, fermeture et désinstallation sans résidu sont prouvés
      le 4 août 2026 ; le parcours interactif login → compagnie → catalogue →
      achat dans l'application installée reste à exécuter par Andy.
- [x] Les gates frontend, desktop, bridge, packaging et budgets applicables
      passent avec leurs compteurs réellement observés.
- [x] La documentation nomme le jalon comme interne, non signé et sans donnée
      réelle, sans créer de tag.

## Security review

Non applicable au sens produit, mais deux invariants restent contrôlés : aucun
secret, jeton, chemin utilisateur ou credential n'entre dans la version,
l'artefact, le manifeste ou l'affichage ; aucune signature ni distribution
publique n'est simulée.

## Maintenance review

- problèmes applicables : `KI-003` absence de pipeline signé, `KI-011` canaux MSFS
  non validés, `KI-012` profil matériel minimum non mesuré ;
- dette créée : la version produit reste manuelle jusqu'à un ticket de release
  automatisé ; le gate doit empêcher la dérive silencieuse ;
- règle de sécurité : ne jamais publier une version opaque ni déplacer un tag ;
- contrôle manuel à automatiser : le cycle d'installation reste local et
  volontairement hors CI ;
- risque résiduel : un artefact non signé déclenche SmartScreen et ne doit pas
  être distribué hors validation interne.

## Automated validation

```powershell
pnpm.cmd frontend:typecheck
pnpm.cmd frontend:test
pnpm.cmd frontend:build
pnpm.cmd desktop:check
pnpm.cmd bridge:build
pnpm.cmd bridge:test
pnpm.cmd windows:package:check
pnpm.cmd performance:check:build
pnpm.cmd maintenance:check
git diff --check
```

## Manual verification

1. Exécuter le nouveau gate de version, puis ses mutations négatives.
2. Construire le package, comparer les hashes au manifeste et confirmer les trois
   statuts `NotSigned`.
3. Installer, démarrer la pile locale, dérouler login → compagnie → catalogue →
   achat et relever la version affichée.
4. Désinstaller et confirmer l'absence de processus, fichier, raccourci et
   enregistrement résiduels.

Temps cible : 15 minutes, dont le build et le cycle d'installation.

## Rollback

Avant fusion, abandonner la branche. Après fusion, revenir à la version
précédente par un nouveau commit et un nouveau numéro : ne jamais réutiliser ni
déplacer une version déjà produite.

## Completion Report

Status : `Verify` le 4 août 2026, branche `chore/T0055-product-version-source`
partie du dernier `origin/main` (`c1bbfbe`), commit `6b89181`, PR #104 ouverte
vers `main` sans dépendance empilée. Ses trois checks sont verts : `Windows
multi-stack` (run `30925080313`, 17 min 39 s), `Supabase PostgreSQL 17` (même
run, 3 min 9 s) et `Audits, licences and SBOM` (run `30925079857`, 4 min 24 s).
La PR n'est pas fusionnée : ni elle, ni ses checks ne suffisent à passer le
ticket `Done`.

### Summary

`eng/product-version.json` devient la source canonique unique de version produit :
`0.1.0-alpha.1`, canal `internal-alpha`, non signé et non public, avec le modèle
de nom d'installateur et le motif de métadonnée de build interne
`+YYYYMMDD.gSHORTSHA`. Cinq cibles la reprennent exactement — frontend, shell
Tauri, crate Rust avec son `Cargo.lock`, bridge .NET et module d'affichage
desktop — et l'en-tête applicatif affiche `Version 0.1.0-alpha.1`.

Le nouveau gate `pnpm product-version:check` refuse toute divergence, toute
version non SemVer 2.0.0, toute préversion non ordonnée, toute métadonnée de
build dans la source canonique et tout nom d'artefact désynchronisé. Le packaging
nomme désormais l'artefact `Thrustline-0.1.0-alpha.1-win-x64.exe` et inscrit
`productVersion` et `channel` dans le manifeste de hashes ; `windows:package`
exécute le gate avant de construire et refuse un bundle NSIS qui ne porte pas la
version produit.

Le workspace racine et `packages/database/package.json` restent délibérément hors
propagation : ce sont des versions de workspace et de schéma, indépendantes de la
version produit selon `AGENTS.md`, et hors des zones autorisées de ce ticket. Ils
sont déclarés explicitement dans `independentVersions`, et le gate refuse qu'un
chemin soit à la fois cible et indépendant.

Une découverte réelle a été traitée dans le périmètre : la build .NET
déterministe concaténait le SHA complet du commit dans sa version
informationnelle (`0.1.0-alpha.1+c1bbfbed6f09…`), c'est-à-dire exactement la
version opaque interdite par la politique de versionnement.
`IncludeSourceRevisionInInformationalVersion` est désactivé et un sixième
scénario négatif verrouille ce comportement.

### Files changed

- `eng/product-version.json` — nouvelle source canonique ;
- `tests/product-version/run.ps1` — nouveau gate et ses six mutations négatives ;
- `package.json` — script racine `product-version:check` ;
- `apps/desktop/package.json`, `apps/desktop/src-tauri/tauri.conf.json`,
  `apps/desktop/src-tauri/Cargo.toml`, `apps/desktop/src-tauri/Cargo.lock` —
  propagation de la version ;
- `Directory.Build.props` — version du bridge et refus de la concaténation du
  commit ;
- `apps/desktop/src/shared/product/productVersion.ts` et son test —
  affichage et comparaison à la source canonique ;
- `apps/desktop/src/app/App.tsx`, `apps/desktop/src/app/App.test.tsx` —
  affichage dans l'en-tête, connecté ou non ;
- `scripts/build-windows-package.ps1`, `scripts/test-windows-package.ps1` — nom
  d'artefact, manifeste versionné et contrôle croisé ;
- `docs/QUALITY.md`, `docs/SUPPORT.md`, `docs/CURRENT_STATE.md`,
  `docs/tickets/README.md`, ce ticket.

### Commands and results

Windows 11 Pro 26200, PowerShell 7.6.4 et Windows PowerShell 5.1, Node 24.18.0,
pnpm 11.17.0, Rust 1.97.1, .NET SDK 10.0.201.

| Commande | Résultat |
| --- | --- |
| `pnpm product-version:check` | réussi, invariants et 6 mutations négatives, 5 cibles ; identique sous `pwsh 7.6.4` |
| divergence réelle injectée dans `Directory.Build.props` | échec attendu, code de sortie `1`, fichier restauré |
| `pnpm frontend:typecheck` | réussi, deux passes `tsc --noEmit` |
| `pnpm frontend:test` | réussi, 25 fichiers passés / 1 ignoré, 301 assertions passées / 2 ignorées, dont 4 nouvelles |
| `pnpm frontend:build` | réussi, `index-CJocjIa7.js` 279,67 kB (84,04 kB gzip) |
| `pnpm desktop:check` | réussi, `cargo check --locked` et Clippy `-D warnings` sur `thrustline-desktop v0.1.0-alpha.1` |
| `pnpm desktop:test` | réussi, 301 assertions frontend, 3 tests Rust, invariants du shell conformes |
| `pnpm desktop:build` | réussi, Release en 2 min 44 s |
| `pnpm bridge:build` | réussi, 0 avertissement, 0 erreur |
| `pnpm bridge:test` | réussi, 25/25 |
| `pnpm bridge:publish` | réussi, publication self-contained `win-x64` |
| `pnpm windows:package:check` | réussi, invariants T0014 et 2 mutations négatives |
| `pnpm windows:package` | réussi, `Thrustline-0.1.0-alpha.1-win-x64.exe`, 334 fichiers de bridge |
| `pnpm windows:package:test` | réussi, installation, lancement, `Healthy`/`0`, désinstallation |
| `pnpm performance:check:build` | réussi, tailles d'artefacts construits dans les budgets |
| `pnpm maintenance:check` | réussi, registre, index et 8 scénarios de mutation |
| `git diff --check` | aucun problème d'espaces |

Versions réellement observées sur les binaires construits :

- `apps/bridge/bin/Release/net10.0/Thrustline.Bridge.dll` : `ProductVersion`
  `0.1.0-alpha.1`, `FileVersion` `0.1.0.0` ;
- `thrustline-desktop.exe` (`x86_64-pc-windows-msvc/release`) :
  `ProductVersion` et `FileVersion` `0.1.0-alpha.1`, `ProductName` `Thrustline` ;
- bundle NSIS produit par Tauri : `Thrustline_0.1.0-alpha.1_x64-setup.exe`, copié
  sous le nom canonique.

Manifeste du package du 4 août 2026, `schemaVersion` `2` : `productVersion`
`0.1.0-alpha.1`, `channel` `internal-alpha`, `signed: false`, installateur
`Thrustline-0.1.0-alpha.1-win-x64.exe` de 35 415 126 octets, SHA-256
`FEE35D18A20510D5314CEC75C939F4678EBEEFFE95EA26A2F6BAD23134D62718`, sortie de
build desktop `B98EC5667FF42AB82C57B544CC5101910AE36A1B56ACC28A1A137F08B5F23786`,
bridge `FD4CEBC67ED9DFFB3BE717FC72BE76B1623F110069B6649BBF2F6432A25FFA39`, trois
statuts `NotSigned`, aucun chemin utilisateur.

Le manifeste passe de `schemaVersion` `1` à `2` : il gagne `productVersion` et
`channel`, désormais exigés par `scripts/test-windows-package.ps1`, qui refuse
toute autre version de schéma. Producteur et consommateur changent dans le même
commit ; aucun autre lecteur n'existe dans le dépôt.

Le cycle `windows:package` puis `windows:package:test` a été exécuté deux fois,
avant et après ce passage à `schemaVersion` `2`. Les deux exécutions passent ; les
valeurs ci-dessus sont celles de la seconde.

### Manual verification result

1. Gate de version et mutations négatives : exécuté, réussi, plus une divergence
   réelle sur disque qui échoue avec le code `1`.
2. Package, hashes et statuts `NotSigned` : exécuté, les trois hashes du
   manifeste correspondent aux fichiers et les trois statuts sont `NotSigned`.
3. Installation, pile locale, parcours login → compagnie → catalogue → achat et
   relevé de la version affichée : **non exécuté**. Installation, lancement,
   fenêtre `Thrustline`, bridge unique, `Healthy`/`0` et fermeture sont prouvés
   par `windows:package:test`, mais le parcours dans la WebView exige une session
   humaine avec la pile Supabase locale démarrée. Cette étape appartient à Andy.
4. Désinstallation sans résidu : exécuté, la cible d'installation disparaît et
   aucun processus, fichier ou enregistrement Thrustline ne subsiste.

Le ticket reste donc `Verify` : seule l'étape 3 manque pour le passer `Done`.

### Risks and limitations

- La version produit reste déclarée manuellement dans cinq cibles ; le gate
  empêche la dérive silencieuse mais ne synchronise rien automatiquement.
- Le gate n'est pas exécuté par la CI : `.github/workflows/ci.yml` et
  `tests/ci/run.ps1` sont hors des zones autorisées de ce ticket. Une divergence
  poussée sans exécution locale ne serait donc pas détectée par un check GitHub.
- L'artefact reste non signé et déclenche SmartScreen ; il ne doit pas être
  distribué hors validation interne (`KI-003`).
- Deux builds successifs de la même arborescence produisent des hashes différents
  pour l'installateur et pour la sortie de build desktop, alors que le binaire du
  bridge .NET déterministe reste identique. Le manifeste prouve donc l'intégrité
  d'un artefact donné, pas la reproductibilité bit à bit d'une version ; toute
  provenance vérifiable relève du ticket de release.
- `KI-011` et `KI-012` restent ouverts : aucune promotion de canal MSFS ni
  mesure de profil matériel minimum n'est revendiquée ici.
- Aucun tag Git n'est créé ; la création d'un tag reste réservée à Andy.
- Le cycle d'installation modifie temporairement le profil utilisateur via NSIS
  et reste volontairement hors CI.

### Follow-ups

- Ajouter `pnpm product-version:check` au workflow `CI` et à son harnais
  `tests/ci/run.ps1` dans un ticket qui possède ces chemins, pour supprimer la
  dépendance à une exécution locale.
- Ticket de release automatisé : dérivation du tag, métadonnée de build interne
  `+YYYYMMDD.gSHORTSHA` réellement injectée, signature Authenticode, canaux et
  rollback N-1, tous hors périmètre ici.

### Documentation updated

- `docs/QUALITY.md` — section « Version produit », commande et couverture du
  gate, y compris son absence en CI ;
- `docs/SUPPORT.md` — section « Alpha technique interne » et date de mise à jour ;
- `docs/CURRENT_STATE.md` — section « Version produit et alpha technique
  interne », en-tête de statut et prochain ticket recommandé ;
- `docs/tickets/README.md` — statut `Verify` et preuve datée.
