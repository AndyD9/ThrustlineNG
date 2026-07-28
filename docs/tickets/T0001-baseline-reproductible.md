# T0001 — Baseline reproductible et inventaire

Status: Done
Owner: Unassigned
Branch: `foundation/t0001-baseline-reproductible`
Phase: 0
Risk: Low
Security-sensitive: No

## Goal

Produire une baseline vérifiée et reproductible de la version actuelle avant toute
refonte, sans changer son comportement.

## Context

Les documents historiques et le code ont divergé. La refonte ne doit pas partir
d'hypothèses sur les builds, tests, dépendances, fonctionnalités ou secrets requis.

## Dependencies

- Aucune.

## Allowed areas

- Documentation sous `docs/`.
- Scripts de diagnostic non destructifs sous `scripts/` si indispensable.
- Fichiers de configuration uniquement pour corriger une erreur de baseline
  explicitement séparée et approuvée.

## Do not touch

- Comportement produit.
- Schéma/migrations Supabase.
- `legacy/`.
- Modification utilisateur existante dans `app/src-tauri/Cargo.toml`.
- Mise à niveau de dépendances.

## Requirements

- Relever versions Node/npm, .NET, Rust et Supabase CLI.
- Installer/restaurer uniquement depuis les lockfiles.
- Exécuter tests et builds disponibles.
- Inventorier scripts, workflows, migrations, dépendances directes et variables
  d'environnement par leur nom seulement.
- Relever les parcours fonctionnels réellement présents.
- Relever les contrôles impossibles sans MSFS/Supabase/certificat.
- Actualiser `docs/CURRENT_STATE.md` avec preuves datées.

## Non-goals

- Corriger les échecs.
- Concevoir l'architecture finale.
- Mettre à jour les dépendances.
- Nettoyer ou déplacer le code.

## Acceptance criteria

- [x] Une machine neuve peut suivre les étapes documentées.
- [x] Chaque commande exécutée et son résultat sont consignés.
- [x] Les échecs sont classés code, environnement ou dépendance externe.
- [x] Aucun secret ni valeur de secret n'est affiché.
- [x] L'état Git utilisateur est préservé.
- [x] Le prochain ticket recommandé repose sur les preuves collectées.

## Automated validation

```powershell
Set-Location app
npm ci
npm test
npm run build

Set-Location ..\sim-bridge
dotnet restore
dotnet build --configuration Release
dotnet test --configuration Release

Set-Location ..\app\src-tauri
cargo check --locked

Set-Location ..\..
.\scripts\security-check.ps1
```

## Manual verification

1. Confirmer que seuls les noms des variables/secrets sont documentés.
2. Comparer les commandes README avec les commandes réellement réussies.
3. Vérifier que `git status` conserve la modification Cargo préexistante.
4. Relire `CURRENT_STATE.md` et retirer toute affirmation non prouvée.

## Rollback

Revenir uniquement aux changements documentaires/scripts du ticket. Ne toucher à
aucun fichier utilisateur préexistant.

## Completion Report

### Summary

Baseline exécutée sous Windows le 24 juillet 2026 sans changement de comportement
ni mise à niveau. Les restaurations lockées, tests/builds disponibles et
invariants ont été exécutés. L'inventaire des outils, dépendances directes,
scripts, workflows, migrations, variables par nom et parcours visibles est
consigné dans `docs/CURRENT_STATE.md`.

### Files changed

- `docs/CURRENT_STATE.md`
- `docs/tickets/T0001-baseline-reproductible.md`

Aucun script, code, manifeste, lockfile, migration ou fichier sous `legacy/` n'a
été modifié pour T0001.

### Commands and results

| Commande | Résultat | Classement |
| --- | --- | --- |
| `node --version` | `v24.14.1` | Réussi ; environnement inférieur au moteur `>=24.18.0 <25` |
| `npm --version` | Script `npm.ps1` bloqué par la politique PowerShell | Environnement |
| `npm.cmd --version` | `11.11.0` | Réussi |
| `dotnet --version` | `10.0.201` | Réussi ; projet ciblant .NET 8 |
| `rustc --version` | `1.94.1` | Réussi avec avertissement de canonicalisation du profil |
| `cargo --version` | `1.94.1` | Réussi avec avertissement de canonicalisation du profil |
| `supabase --version` | Commande introuvable | Dépendance externe/outillage absent |
| `npm.cmd ci` (initial) | `EPERM` sur le cache npm utilisateur | Environnement/bac à sable |
| `npm.cmd ci` (accès autorisé) | Réussi, 283 paquets ; avertissement `EBADENGINE`, 2 vulnérabilités modérées | Réussi avec risques connus |
| `npm.cmd test` | 4 fichiers, 11 tests réussis | Réussi |
| `npm.cmd run build` | TypeScript et Vite réussis | Réussi |
| `dotnet restore` (initial) | Accès refusé à `NuGet.Config` utilisateur | Environnement/bac à sable |
| `dotnet restore` (accès autorisé) | Réussi, projets à jour | Réussi |
| `dotnet build --configuration Release` | Réussi, 0 avertissement, 0 erreur | Réussi |
| `dotnet test --configuration Release` (initial) | Accès refusé à `NuGet.Config` utilisateur | Environnement/bac à sable |
| `dotnet test --configuration Release` (accès autorisé) | Code 0, aucun projet/test découvert | Réussi sans couverture de tests |
| `cargo check --locked` | Réussi ; avertissement de canonicalisation de `C:\Users\andyd` | Réussi avec limite environnement |
| `.\scripts\security-check.ps1` | Bloqué par la politique d'exécution PowerShell | Environnement |
| `powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\security-check.ps1` | `Security invariants passed.` | Réussi |

Les commandes de lecture `Get-Content`, `Get-ChildItem`, `Select-Xml`, `rg`,
`git status`, `git diff`, `Get-FileHash` et la lecture JSON PowerShell ont servi
à l'inventaire et aux vérifications manuelles. Elles ont réussi, sauf une tentative
de lecture globale de `package-lock.json` avec `ConvertFrom-Json` (erreur
PowerShell sur un nom de propriété) et les avertissements non bloquants de Git sur
l'accès au fichier d'exclusion global utilisateur. La restauration npm prouve
néanmoins que le lockfile est exploitable.

Résultat de l'inventaire en lecture seule :

- 25 migrations SQL ;
- workflows `.github/workflows/ci.yml` et `.github/workflows/security.yml` ;
- scripts `build-sidecar.ps1` et `security-check.ps1` ;
- 11 dépendances npm runtime, 12 npm développement, 2 NuGet, 6 Cargo
  runtime et 1 Cargo build ;
- variables/configurations, noms seuls :
  `VITE_SUPABASE_URL`, `VITE_SUPABASE_ANON_KEY`, `VITE_SIM_BRIDGE_URL`,
  `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `SUPABASE_SERVICE_ROLE_KEY`,
  `THRUSTLINE_BRIDGE_TOKEN`.

### Manual verification result

- Seuls des noms de variables/secrets sont présents dans la documentation ; aucune
  valeur n'a été copiée.
- Les README ont été comparés : la racine demande Node `24.18 LTS`,
  `app/README.md` demande Node `20+`, et les deux indiquent `npm install` alors
  que `npm ci` est la commande reproductible vérifiée. Ils n'ont pas été modifiés.
- Le statut Git conserve `app/src-tauri/Cargo.toml` comme modification
  préexistante. Son empreinte SHA-256 est identique avant et après :
  `94BF4E46145BC363B70BD3EEE5BBA578EF198718EBDADB7264C260FEAFAE2AFE`.
- `docs/CURRENT_STATE.md` a été relu et distingue présence dans le code,
  validation automatisée et contrôles externes non exécutés.

La validation manuelle fonctionnelle de l'interface, d'un vol réel et du cloud
est déléguée à un environnement équipé de MSFS, Supabase et des identifiants de
test appropriés.

### Risks and limitations

- Node `24.14.1` ne satisfait pas le moteur déclaré ; la CI emploie `24.18.0`.
- L'audit exécuté par `npm ci` signale 2 vulnérabilités modérées. Elles ne sont
  pas corrigées, conformément au non-goal d'absence de mise à jour.
- Aucun test .NET dédié et aucun test RLS automatisé ne sont disponibles.
- MSFS/SimConnect n'a pas été lancé et aucun replay de trace n'existe.
- Supabase CLI, projet de test et certificat de signature sont absents.
- Le build Tauri complet/installable n'a pas été exécuté ; `cargo check --locked`
  valide seulement le shell Rust et le build complet dépend du sidecar externe.
- Les restrictions du bac à sable ont nécessité un accès autorisé aux caches npm
  et NuGet ; la politique PowerShell a nécessité un bypass explicite.

### Follow-ups

- Créer le prochain ticket de phase 0 pour fixer la matrice Windows/MSFS
  supportée et un protocole de validation SimConnect reproductible.
- Conserver pour un ticket ultérieur l'alignement des prérequis README,
  `package.json` et CI.
- Traiter dans un ticket dédié les vulnérabilités npm après analyse, sans mise à
  niveau opportuniste dans T0001.
- Prévoir des tests .NET, des replays SimConnect et des tests RLS A/B/anonyme
  dans les phases prévues par la roadmap.

### Documentation updated

`docs/CURRENT_STATE.md` contient désormais la baseline datée, la procédure depuis
une machine neuve, l'inventaire, les résultats réels, les contrôles externes
impossibles, les écarts de documentation et le prochain ticket recommandé.
