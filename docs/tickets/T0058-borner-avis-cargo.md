# T0058 — Borner les avis Cargo informatifs par un gate déterministe

Status: Review
Owner: Andy
Branch: `chore/T0058-borner-avertissements-cargo`
Phase: Gouvernance
Risk: Medium
Security-sensitive: No

## Goal

Faire échouer la CI sur tout avis RustSec non revu du `Cargo.lock` desktop, et
remplacer la surveillance manuelle de `KI-019` par une liste justifiée, datée et
vérifiée automatiquement.

## Context

`KI-019` suivait depuis le 29 juillet 2026 des avertissements RustSec sur la
chaîne GTK3 et `glib` 0.18.5. L'audit du 4 août 2026 montre deux écarts réels.

D'abord, `cargo audit` seul ne fait échouer que les vulnérabilités : les
avertissements `unmaintained` et `unsound` sortent avec le code 0. L'étape
supply-chain de T0013 les enregistrait donc dans un rapport JSON vert, et un
nouvel avertissement serait passé inaperçu jusqu'à une relecture humaine.
`docs/MAINTENANCE.md` exige qu'un contrôle manuel répétable devienne une gate dès
qu'une détection déterministe est raisonnable.

Ensuite, l'entrée `KI-019` était incomplète. Le rapport contient 15 avis, pas
seulement la chaîne GTK3 : `proc-macro-error` 1.0.4 et cinq crates `unic-*` du
18 octobre 2025 n'y figuraient pas. Surtout, la justification « la cible Windows
ne compile pas ce chemin » est vraie pour GTK3 et fausse pour les `unic-*` :
`cargo tree --locked -i` sur le graphe hôte les résout via `urlpattern` 0.3.0
puis `tauri-utils` 2.9.3, alors que `glib`, `gtk` et `proc-macro-error`
n'apparaissent que sous `--target all`.

Aucune vulnérabilité n'est connue dans ce lockfile ; le ticket ne corrige donc
aucune faille et ne modifie aucune dépendance.

## Workflow evidence

- 4 août 2026 — `Ready` : `KI-019` est `Open` depuis T0013, aucune décision
  produit n'est requise et la zone Cargo n'est portée par aucun autre ticket
  actif.
- 4 août 2026 — `In progress` : branche
  `chore/T0058-borner-avertissements-cargo` créée depuis `origin/main` au commit
  `a44946e`, worktree propre.
- 4 août 2026 — `Review` : source, gate, harnais et câblage CI implémentés ; les
  validations ci-dessous passent sous PowerShell 7.6.4 et Windows PowerShell 5.1.

## Dependencies

- T0013 — workflow supply-chain et harnais `ci:check` livrés dans `main` ;
- T0016 — précédent traitement d'un avis de dépendance ;
- T0030 — registre de dettes et gate de maintenance livrés dans `main`.

## Allowed areas

- `eng/cargo-advisory-allowlist.json` ;
- `scripts/ci/check-cargo-advisories.ps1` ;
- `tests/cargo-advisories/run.ps1` ;
- `tests/ci/run.ps1` pour les seuls invariants du nouveau gate ;
- `.github/workflows/ci.yml` et `.github/workflows/security.yml` pour ses étapes ;
- `package.json` pour ses deux scripts ;
- `docs/KNOWN_ISSUES.md` pour `KI-019` uniquement, `docs/QUALITY.md`,
  `docs/SECURITY.md`, `docs/CURRENT_STATE.md`, `docs/tickets/README.md` et ce
  ticket.

## Do not touch

- `apps/desktop/src-tauri/Cargo.toml`, `Cargo.lock` et toute version de
  dépendance ;
- règles existantes des gates data-policy, authority, maintenance et backend ;
- code applicatif, migrations, seeds, contrats et toolchain ;
- autres problèmes connus, tickets et Completion Reports ;
- environnements distants, données réelles et exceptions de sécurité.

## Requirements

- Déclarer chaque avis toléré dans une source JSON versionnée avec crate,
  version, nature, justification, présence dans le graphe `win-x64` et condition
  de sortie.
- Faire échouer le gate sur : une vulnérabilité, un avis absent de la liste, une
  dérive de crate, de version ou de nature, une entrée qui n'est plus signalée,
  une liste dont la date de revalidation est atteinte et une fenêtre de
  revalidation non croissante.
- Refuser une entrée sans justification ou sans condition de sortie.
- Rendre le harnais exécutable sans `cargo-audit` installé, à partir de rapports
  synthétiques, et couvrir chaque famille de refus par une mutation négative.
- Exécuter le harnais dans le job Windows et la comparaison au rapport réel dans
  le job supply-chain, dont le gate final doit agréger son résultat.
- Ne modifier aucune dépendance et ne revendiquer aucune disparition de crate.

## Non-goals

- mettre à jour Tauri, retirer la chaîne GTK3 ou remplacer `urlpattern` ;
- élargir le gate aux lockfiles pnpm, NuGet ou aux licences ;
- créer une exception de sécurité ou clore une autre entrée du registre ;
- prouver une build signée, un environnement distant ou une donnée réelle.

## Acceptance criteria

- [x] La source déclare les 15 avis réellement rapportés le 4 août 2026, dont
      `proc-macro-error` et les cinq `unic-*` absents de `KI-019`.
- [x] Chaque entrée distingue explicitement sa présence dans le graphe `win-x64`.
- [x] Le gate échoue sur un avis non revu et sur une vulnérabilité.
- [x] Le gate échoue sur une dérive de version, une dérive de nature, une entrée
      périmée, une liste expirée et une fenêtre inversée.
- [x] Le harnais passe sous PowerShell 7 et Windows PowerShell 5.1 sans
      `cargo-audit`.
- [x] `ci:check` exige les nouveaux scripts, étapes et agrégations.
- [x] `KI-019`, `QUALITY.md`, `SECURITY.md` et `CURRENT_STATE.md` décrivent le
      contrôle réellement livré.

## Maintenance review

- dettes et problèmes connus applicables : `KI-019` ;
- dette créée ou aggravée : aucune ; la liste reste une dette bornée et datée,
  pas une suppression d'avertissement ;
- règle de sécurité ajoutée : « aucun avis Cargo non revu », consignée dans
  `docs/SECURITY.md` et automatisée dans le même ticket ;
- contrôle manuel à automatiser : la relecture humaine du rapport
  `cargo-audit.json` est remplacée par le gate ;
- risque résiduel : les cinq crates `unic-*` non maintenues restent compilées
  dans le binaire Windows via `urlpattern`. Aucune vulnérabilité n'est connue ;
  la liste expire le 4 novembre 2026 et force une nouvelle revue.

## Automated validation

```powershell
pnpm supply-chain:cargo:check
pnpm supply-chain:cargo
pnpm ci:check
pnpm maintenance:check
pnpm data-policy:check
pnpm authority:check
```

## Manual verification

1. Exécuter `cargo audit --file apps/desktop/src-tauri/Cargo.lock --json` et
   relever le nombre de vulnérabilités et d'avertissements.
2. Confirmer que chaque avertissement rapporté possède une entrée justifiée dans
   `eng/cargo-advisory-allowlist.json`.
3. Vérifier avec `cargo tree --locked -i <crate>` qu'une entrée déclarée hors
   graphe Windows n'apparaît effectivement que sous `--target all`.
4. Retirer temporairement une entrée de la liste et confirmer que
   `pnpm supply-chain:cargo` échoue, puis restaurer le fichier.

Temps cible : 5–10 minutes.

## Rollback

Retirer les deux étapes de workflow, les deux scripts `package.json`, les
invariants ajoutés à `tests/ci/run.ps1`, puis supprimer la source, le script et
le harnais. Aucune dépendance, migration ou donnée n'est touchée ; `KI-019`
redevient `Open` avec sa preuve corrigée.

## Completion Report

### Summary

Le gate d'avis Cargo est livré. `cargo audit` reste inchangé, mais son rapport
est désormais confronté à une liste justifiée : 0 vulnérabilité tolérée, 15 avis
informatifs revus, et un échec déterministe sur tout écart. L'entrée `KI-019` est
corrigée puis résolue, avec la distinction explicite entre la chaîne GTK3 absente
du graphe Windows et les cinq crates `unic-*` qui y sont réellement présentes.

### Files changed

- `eng/cargo-advisory-allowlist.json` (nouveau) ;
- `scripts/ci/check-cargo-advisories.ps1` (nouveau) ;
- `tests/cargo-advisories/run.ps1` (nouveau) ;
- `tests/ci/run.ps1`, `.github/workflows/ci.yml`,
  `.github/workflows/security.yml`, `package.json` ;
- `docs/KNOWN_ISSUES.md`, `docs/QUALITY.md`, `docs/SECURITY.md`,
  `docs/CURRENT_STATE.md`, `docs/tickets/README.md`, ce ticket.

### Commands and results

Le 4 août 2026, depuis la racine, sur Windows 11 x64 :

- `pnpm supply-chain:cargo:check` : réussi — « repository allowlist plus
  8 mutation scenarios ». Rejoué avec succès sous `pwsh` 7.6.4 et
  `powershell` 5.1.
- `pnpm supply-chain:cargo` : réussi — « 0 vulnerabilities, 15 reviewed
  informational advisories, revalidation before 2026-11-04 ».
- `pnpm ci:check` : réussi — « repository plus 2 mutation scenarios ».
- `pnpm maintenance:check` : réussi — registre, index et marqueurs de dette avec
  8 mutations.
- `pnpm data-policy:check` : réussi avec 6 mutations.
- `pnpm authority:check` : réussi — 10 étapes, 13 domaines, 3 surfaces clientes,
  9 mutations.
- `cargo audit --file apps/desktop/src-tauri/Cargo.lock --json` : 0 vulnérabilité,
  15 avertissements (14 `unmaintained`, 1 `unsound`).

Non exécuté : les gates frontend, desktop, bridge et backend, hors périmètre de
ce ticket, ainsi que toute exécution GitHub, qui dépend de la Pull Request.

### Manual verification result

- `cargo audit` rend 0 vulnérabilité et 15 avertissements, tous présents dans la
  source avec la même crate, la même version et la même nature.
- `cargo tree --manifest-path apps/desktop/src-tauri/Cargo.toml --locked -i`
  ne rend rien pour `glib`, `gtk` et `proc-macro-error` sur le graphe hôte ; ces
  crates n'apparaissent que sous `--target all`, où `proc-macro-error` est tiré
  uniquement par `glib-macros` et `gtk3-macros`. La même commande rend
  `unic-char-property → unic-ucd-ident → urlpattern 0.3.0` sur le graphe hôte,
  et `urlpattern` remonte à `tauri-utils` 2.9.3 puis `tauri` 2.11.5.
- Le retrait temporaire de `RUSTSEC-2025-0100` d'une copie de la liste fait
  échouer le contrôle sur le rapport réel avec le code 1 et le message
  « Unreviewed Cargo advisory RUSTSEC-2025-0100 (unmaintained) on
  unic-ucd-ident 0.9.0 ». La copie temporaire a été utilisée pour ne pas modifier
  la source du dépôt ; le fichier versionné est inchangé.

### Risks and limitations

- Le gate prouve la revue des avis, pas l'absence de risque : les crates non
  maintenues restent dans le lockfile.
- Le harnais utilise des rapports synthétiques ; seule l'étape supply-chain
  compare le rapport réel produit par `cargo-audit` 0.22.2.
- Aucune parité cloud, build signée, donnée réelle ou environnement distant n'est
  prouvée.

### Follow-ups

- Revalider la liste avant le 4 novembre 2026.
- Réévaluer les cinq `unic-*` lors de la prochaine montée de Tauri.

### Documentation updated

`docs/KNOWN_ISSUES.md`, `docs/QUALITY.md`, `docs/SECURITY.md`,
`docs/CURRENT_STATE.md` et `docs/tickets/README.md`.
