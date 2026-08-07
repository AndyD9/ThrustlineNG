# F0005 — Rendre l'alpha installée cliquable

Status: In progress
Owner: Agent (session du 7 août 2026)
Branch: `feature/f0005-rendre-l-alpha-installee-cliquable`
PR: [#133](https://github.com/AndyD9/ThrustlineNG/pull/133) **fusionnée** par
Andy le 7 août 2026 — J1 livré dans `main`. Le contrôle de CSP sur l'exécutable
produit et la correction du compte rendu ci-dessous sont arrivés après cette
fusion : ils suivent dans une PR distincte, depuis la branche
`fix/f0005-j1-csp-embarquee-artefact`. Reste J2 — le package installé et le
parcours humain — qui appartient à Andy.
Phase: 4
Risk: High
Security-sensitive: Yes
Autonomous: No

## Goal

La personne qui installe le package `internal-alpha` peut dérouler le golden
path dans l'application installée — la même chose qu'en mode dev aujourd'hui —
sans que la CSP du canal public ne s'ouvre d'un pouce.

## Context

Découvert le 6 août 2026 pendant la vérification live de F0001 : la CSP de
production est `connect-src 'none'` (T0037/T0038), donc l'application
**installée** ne peut pas joindre l'API Supabase locale — le parcours
interactif exigé par T0055 est impossible par conception, et T0055 reste
`Verify`. Andy a tranché le 6 août 2026 : le canal `internal-alpha`
(`eng/product-version.json`, T0055) reçoit une CSP qui autorise **uniquement**
`http://127.0.0.1:54321`, et la CSP publique reste `'none'`.

## Dependencies

- T0014/T0055 — packaging NSIS non signé et canal produit (`Done`) ;
- T0038 — configuration publique bornée et CSP existantes (`Done`) ;
- décision d'Andy du 6 août 2026 : **prise** (build `internal-alpha` avec CSP
  loopback seule) ;
- la vérification finale installée appartient à Andy (vérification humaine).

## Allowed areas

- `apps/desktop/src-tauri/tauri.conf.json` et la mécanique de CSP par canal,
  dont les surcouches `tauri.channel.<canal>.conf.json` ;
- `tests/desktop-shell/run.ps1` et `apps/desktop/src/test/security-invariants.test.ts`
  — les deux harnais qui épinglent déjà la CSP (ajouté aux `Allowed areas` le
  7 août 2026 : l'unité qui change la CSP fait évoluer les gates qui la
  gardent) ;
- `scripts/test-windows-package.ps1` — consommateur du manifeste de packaging ;
- `apps/desktop/` configuration de build strictement nécessaire ;
- `scripts/build-windows-package.ps1` et le gate de packaging si le canal
  change la CSP embarquée ;
- `tests/` — la preuve qu'un package public garde `connect-src 'none'` ;
- `docs/SECURITY.md`, `docs/ARCHITECTURE.md`, `docs/QUALITY.md`,
  `docs/CURRENT_STATE.md`, le fichier de T0055 pour sa clôture ;
- ce fichier et `docs/features/README.md`.

## Do not touch

- La CSP du canal public : `connect-src 'none'` ne bouge pas ;
- l'allowlist de configuration T0038 (une seule cible loopback) ;
- signature, updater, distribution publique : phase 6.

## Non-goals

- Ouvrir la CSP à toute autre origine que `http://127.0.0.1:54321` ;
- staging, cloud, ou cible distante ;
- clore les vérifications MSFS (T0059/F0003).

## Jalons

### J1 — La CSP suit le canal produit, prouvée fermée pour le public

Status: Done
Risk: High
Security-sensitive: Yes
Autonomous: No

- résultat : le build `internal-alpha` embarque une CSP dont `connect-src` est
  exactement `http://127.0.0.1:54321` ; tout autre canal garde `'none'`. Un
  contrôle déterministe échoue si un package public embarque autre chose que
  `'none'`, avec mutation négative.
- frontière : CSP Tauri, gate de packaging.
- validations : `pnpm desktop:check`, `pnpm desktop:test`, gate de packaging,
  `pnpm maintenance:check`.
- revue : chercher tout chemin par lequel la CSP élargie fuirait vers le canal
  public, et toute origine au-delà du loopback exact.

### J2 — Le parcours installé, vérifié par Andy

Status: Draft
Risk: Medium
Security-sensitive: No
Autonomous: No

- résultat : un package `internal-alpha` est produit, installé, et le golden
  path y est déroulé sur la pile locale (login → compagnie → achat → dispatch →
  départ). Ce parcours clôt la vérification interactive de T0055.
- frontière : packaging Windows + vérification humaine.
- validations : `packaging:check`, cycle installation/désinstallation sans
  résidu, parcours humain consigné.
- revue : vérifier que le manifeste et les hashes reflètent le canal, et que
  rien d'autre ne diffère du package public.

## Acceptance criteria

- [ ] Un package `internal-alpha` installé déroule le golden path sur la pile
      locale. — J2.
- [x] Un package du canal public embarque `connect-src 'none'`, prouvé par un
      contrôle à mutation négative. — J1 : sept mutations négatives dans
      `windows:package:check`, plus un contrôle manuel sur le binaire compilé.
      Revalidé sur le package NSIS réel en J2.
- [x] Aucune origine autre que `http://127.0.0.1:54321` n'est autorisée par le
      canal alpha. — J1 : égalité exacte avec la CSP publique au seul
      `connect-src` près, et refus de `localhost`, `[::1]` ou tout autre schéma.
- [ ] T0055 est clos par le parcours installé, consigné dans son fichier. — J2.
- [x] `SECURITY.md` décrit la CSP par canal et son risque résiduel. — J1,
      section « CSP par canal produit F0005 J1 ».

## Security review

Jalons concernés : **J1**, revalidé en J2 sur l'artefact réel.

- actifs/données : CSP de l'application distribuée, frontière réseau du client ;
- frontière : WebView ↔ réseau ;
- abus : élargissement silencieux de la CSP publique, canal alpha distribué
  au-delà de l'interne, origine non loopback glissée dans l'allowlist ;
- validation/autorisation : contrôle déterministe par canal, mutation négative ;
- atomicité/idempotence : sans objet (configuration) ;
- logs/vie privée : aucun changement.

## Maintenance review

- dettes et problèmes connus applicables : T0055 `Verify` (clos par J2) ;
- dette créée ou aggravée : deux CSP à maintenir ; le gate de packaging en
  devient le garde-fou ;
- règle de sécurité ajoutée : CSP par canal dans `SECURITY.md` ;
- contrôle manuel à automatiser : la comparaison de CSP embarquée par canal —
  **automatisé en J1**, dans `windows:package`, sur l'exécutable produit ;
- risque résiduel : un package alpha qui fuirait hors de l'interne expose une
  CSP loopback — sans donnée réelle ni cible distante, risque accepté à
  documenter.

## Automated validation

```powershell
pnpm desktop:check
pnpm desktop:test
pnpm frontend:build
pnpm packaging:check
pnpm maintenance:check
```

## Manual verification

1. J1 : inspecter la CSP embarquée des deux canaux dans les artefacts de build.
2. J2 : installer le package alpha, dérouler le golden path sur la pile locale,
   désinstaller, vérifier zéro résidu — appartient à Andy.

## Rollback

Retirer la CSP conditionnelle rend tous les canaux à `connect-src 'none'`,
l'état actuel. Aucune donnée concernée.

## Completion Report

Un bloc par jalon, rempli au moment de son commit, puis une synthèse.

### J1

- résultat obtenu : la CSP suit le canal produit. Le canal `internal-alpha`
  reçoit une surcouche de configuration Tauri dont la CSP est exactement la CSP
  publique avec `connect-src http://127.0.0.1:54321` ; tout autre canal —
  connu, inconnu, renommé ou vide — garde `connect-src 'none'`. Le mécanisme
  est une allowlist, pas un drapeau négatif : la surcouche n'est appliquée que
  sous une égalité explicite de nom de canal, et le script de packaging
  recalcule la CSP attendue **depuis la CSP publique**, jamais depuis la
  surcouche qu'il valide, puis refuse de construire en cas d'écart. La CSP
  résolue est inscrite dans `package-manifest.json` (`schemaVersion` 3, champ
  `csp`) et recomparée au canal par le test de package. Enfin, le script relit
  la CSP **réellement embarquée dans l'exécutable produit** et refuse un binaire
  dont le jeu de `connect-src` n'est pas exactement celui du canal plus la CSP
  de développement : la configuration prouve l'intention, le binaire prouve le
  résultat.
- fichiers modifiés :
  `apps/desktop/src-tauri/tauri.channel.internal-alpha.conf.json` (nouveau),
  `scripts/build-windows-package.ps1`, `scripts/test-windows-package.ps1`,
  `tests/windows-package/run.ps1`, `tests/desktop-shell/run.ps1`,
  `apps/desktop/src/test/security-invariants.test.ts`, `docs/SECURITY.md`,
  `docs/QUALITY.md`, `docs/CURRENT_STATE.md`, `docs/features/README.md`, ce
  fichier. `apps/desktop/src-tauri/tauri.conf.json` n'a **pas** changé : la CSP
  publique est intacte.
- commandes et résultats : `pnpm windows:package:check` vert (« per-channel CSP
  and 10 negative mutations passed ») ; `pnpm desktop:check` vert (typecheck,
  `cargo fmt --check`, `cargo check --locked`, Clippy `-D warnings`) ;
  `pnpm desktop:test` vert (496 tests frontend passés, 2 ignorés ; 21 tests
  Rust ; invariants du shell) ; `pnpm frontend:build` vert ;
  `pnpm maintenance:check`, `pnpm authority:check`, `pnpm data-policy:check`
  verts. Tous réexécutés **après** le rapatriement de `main` (fusions de F0002,
  PR #131, et de F0006, PR #132). `pnpm windows:package` n'est pas exécutable
  sur le poste de développement de cette session, mais **la CI l'exécute** : le
  job « Windows multi-stack » du run 31188664501 a produit
  `Thrustline-0.1.0-alpha.1-win-x64.exe (internal-alpha)` avec
  `Embedded connect-src: http://127.0.0.1:54321`. Le package et son manifeste
  sont dans l'artefact `t0014-windows-unsigned-<sha>`, rétention 30 jours.
- vérification manuelle : contrôle sur l'artefact, sur des binaires Release
  réels. Un binaire compilé avec la surcouche embarque
  `connect-src http://127.0.0.1:54321` ; sans elle, `connect-src 'none'`. Un
  constat non anticipé au passage : un binaire Release embarque **deux**
  `connect-src`, celui du canal et celui de la CSP de développement, que Tauri
  n'applique qu'en `tauri dev` — un contrôle « une seule occurrence » aurait
  été rouge à tort. Le contrôle automatisé épingle donc le jeu exact des deux,
  ce qui interdit aussi un élargissement silencieux de la CSP de développement.
  Vérifié dans les deux sens sur le binaire réel : l'attendu du canal alpha est
  refusé sur un binaire public, et l'attendu public est refusé sur un binaire
  alpha. Mécanisme de fusion confirmé dans la source `tauri-utils` 2.9.3 :
  JSON Merge Patch (RFC 7396), donc la surcouche remplace `app.security.csp`
  sans effacer `freezePrototype`.
- revue et constats traités : relecture de la source Tauri 2.11.5 sur un risque
  non listé au départ — une CSP fermée casse-t-elle l'IPC ? Non :
  `scripts/ipc-protocol.js` retombe sur `window.ipc.postMessage` quand le
  protocole custom est bloqué, donc les deux commandes fermées restent
  joignables sur les deux canaux. Le garde de canal du script de build est
  lui-même sous mutation négative (surcouche appliquée inconditionnellement,
  puis garde retiré), parce qu'une CSP correcte dans un fichier ne prouve rien
  si le script l'applique au mauvais canal. Le contrôle manuel que la
  « Maintenance review » de cette unité désignait comme à automatiser — la
  comparaison de CSP embarquée par canal — a été automatisé dans le même jalon
  plutôt que laissé en dette, et il est lui-même sous mutation négative.
  Reste non couvert : la CSP telle qu'elle s'applique dans la WebView
  **installée**, qui relève du parcours humain de J2.

### J2

- résultat obtenu :
- fichiers modifiés :
- commandes et résultats :
- vérification manuelle :
- revue et constats traités :

### Synthèse

### Risks and limitations

### Follow-ups

### Documentation updated
