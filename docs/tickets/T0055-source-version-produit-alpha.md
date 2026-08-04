# T0055 — Fixer la source canonique de version produit et livrer l'alpha technique interne

Status: Ready
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

- [ ] Une source canonique unique porte `0.1.0-alpha.1` et aucune cible ne
      déclare plus `0.0.0`.
- [ ] L'installateur, le manifeste et l'affichage applicatif reprennent
      exactement cette version, sans valeur opaque ni chemin utilisateur.
- [ ] Le nouveau gate échoue sur au moins trois mutations négatives réellement
      exécutées et passe sur l'état livré.
- [ ] Le package NSIS non signé s'installe, permet le parcours d'alpha technique
      sur la pile locale et se désinstalle sans résidu.
- [ ] Les gates frontend, desktop, bridge, packaging et budgets applicables
      passent avec leurs compteurs réellement observés.
- [ ] La documentation nomme le jalon comme interne, non signé et sans donnée
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

À remplir après implémentation.

### Summary

### Files changed

### Commands and results

### Manual verification result

### Risks and limitations

### Follow-ups

### Documentation updated
