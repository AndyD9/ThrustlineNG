# F0005 — Rendre l'alpha installée cliquable

Status: Done
Owner: Agent (session du 7 août 2026)
Branch: `feature/f0005-rendre-l-alpha-installee-cliquable`
PR: [#133](https://github.com/AndyD9/ThrustlineNG/pull/133) et
[#134](https://github.com/AndyD9/ThrustlineNG/pull/134), **fusionnées** par
Andy le 7 août 2026 — J1 livré dans `main` : CSP par canal, contrôle sur
l'exécutable produit. J2 — le parcours dans l'application installée — a été
exécuté le 7 août 2026 par la session agent, sur instruction du passage de
relais d'Andy, et est consigné par la branche
`feature/f0005-j2-parcours-installe` ; la revue finale et la fusion
appartiennent à Andy.
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

Status: Done
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

- [x] Un package `internal-alpha` installé déroule le golden path sur la pile
      locale. — J2, le 7 août 2026 : login → compagnie → achat → dispatch →
      départ « En vol · 16:40 UTC », piloté par CDP dans la WebView2 installée,
      s'arrêtant au départ (KI-027 : ni mesure ni clôture sans harnais externe).
- [x] Un package du canal public embarque `connect-src 'none'`, prouvé par un
      contrôle à mutation négative. — J1 : sept mutations négatives dans
      `windows:package:check`, plus un contrôle manuel sur le binaire compilé.
      Revalidé sur le package NSIS réel en J2.
- [x] Aucune origine autre que `http://127.0.0.1:54321` n'est autorisée par le
      canal alpha. — J1 : égalité exacte avec la CSP publique au seul
      `connect-src` près, et refus de `localhost`, `[::1]` ou tout autre schéma.
- [x] T0055 est clos par le parcours installé, consigné dans son fichier. — J2,
      le 7 août 2026.
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

- résultat obtenu : le package `internal-alpha` construit localement le 7 août
  2026 (`Thrustline-0.1.0-alpha.1-win-x64.exe`, 35 432 953 octets, manifeste
  `schemaVersion` 3, `csp` avec `connect-src http://127.0.0.1:54321`, trois
  `NotSigned`) s'installe, déroule le golden path complet sur la pile Supabase
  locale et se désinstalle sans résidu au sens du contrat de packaging. Le
  package a été construit **localement** depuis la branche de la PR #138 avec
  un `apps/desktop/.env` valide : le package CI embarque des valeurs Supabase
  vides et ne peut joindre aucune pile (consigné en KI-029).
- fichiers modifiés : aucun fichier de code — ce jalon est une vérification.
  Documents : ce fichier, `docs/features/README.md`, le fichier de T0055,
  `docs/tickets/README.md`, `docs/CURRENT_STATE.md`, `docs/KNOWN_ISSUES.md`
  (KI-029, KI-030).
- commandes et résultats : hash SHA-256 de l'installateur conforme au manifeste
  avant installation ; installation silencieuse NSIS (`/S /D=...`, code 0) ;
  `pnpm windows:package:check` vert (« per-channel CSP and 10 negative
  mutations passed ») ; `pnpm windows:package:test` vert (« installation,
  launch and removal passed » : installation, un seul bridge, fermeture,
  `Healthy`/`0`, désinstallation, répertoire disparu), tous deux exécutés
  depuis la branche de la PR #138 dont le correctif `Select-Object -First 1`
  est nécessaire sur cette machine.
- vérification manuelle : exécutée le 7 août 2026 par la session agent sur
  instruction du passage de relais d'Andy, dans la WebView2 de l'application
  **installée** pilotée par CDP (`WEBVIEW2_ADDITIONAL_BROWSER_ARGUMENTS`
  `--remote-debugging-port`) : version `0.1.0-alpha.1` affichée dans
  l'en-tête ; login avec une identité synthétique jetable ; création de la
  compagnie ; achat d'un Synthetic Cessna 172 (100 000,00 €) ; brouillon
  LFPG → LFBO ; départ du vol « En vol · 07/08/2026 16:40 UTC · départ
  07/08/2026 16:40 UTC ». Le parcours s'arrête au départ : KI-027 rend toute
  mesure ou clôture impossible dans l'application installée (le superviseur ne
  passe que `--port` au bridge, et `THRUSTLINE_BRIDGE_PATH` n'existe qu'en
  `debug_assertions`). Preuve réseau relevée pendant le parcours : aucune
  requête hors `http://127.0.0.1:54321` et des origines internes de la WebView
  (`tauri.localhost`, `ipc.localhost`) — la CSP du canal s'applique bien dans
  l'artefact réel. Après fermeture propre (fenêtre principale), le bridge
  s'éteint ; la désinstallation silencieuse retire le répertoire, la clé de
  registre `HKCU\...\Uninstall\Thrustline`, les raccourcis Menu Démarrer et
  Bureau, sans processus résiduel.
- revue et constats traités : le manifeste et les hashes reflètent le canal
  (`internal-alpha`, CSP loopback, hash de l'installateur revérifié) et rien
  d'autre ne diffère du package public que la CSP, conformément à la revue
  demandée. Deux constats hors périmètre consignés au lieu d'être corrigés au
  passage : KI-029 — le contrat `.env` du frontend (deux variables
  `VITE_THRUSTLINE_SUPABASE_*` cuites au build, URL loopback exigée à
  l'identique par `connectionConfig.ts`) n'est documenté nulle part et le
  package CI est inutilisable sur pile locale ; KI-030 — la désinstallation ne
  supprime pas les données WebView2 de
  `%LOCALAPPDATA%\com.thrustline.desktop` (localStorage, donc session locale).

### Synthèse

F0005 est complète : la CSP suit le canal produit (J1, PR #133 et #134,
fusionnées) et le package `internal-alpha` installé déroule réellement le
golden path jusqu'au départ sur la pile locale (J2, ce changement). T0055 est
clos par ce parcours. L'application installée est cliquable ; ce qui manque
encore à l'alpha cliquable — replay mesuré et clôture dans l'application
installée — relève de KI-027, porté par F0007.

### Risks and limitations

- Le parcours installé s'arrête au départ : mesure et clôture restent
  impossibles dans l'artefact assemblé tant que KI-027 n'est pas levé (F0007).
- Le package vérifié est construit localement avec un `.env` valide ; le
  package produit par la CI ne peut pas joindre la pile locale (KI-029), et le
  contrat `.env` n'est documenté que par KI-029 en attendant une unité qui
  possède `docs/SETUP.md`.
- La construction et le test du package sur cette machine dépendent du
  correctif de la PR #138 (ambiguïté `pwsh.exe`), non fusionné au moment de ce
  jalon.
- Les données WebView2 survivent à la désinstallation (KI-030) — acceptable
  sans donnée réelle (KI-021), à traiter avant distribution réelle (phase 6).

### Follow-ups

- F0007 (KI-027) : mesurer un vol sans harnais externe dans l'alpha assemblée.
- KI-029 : documenter le contrat `.env` du frontend dans `docs/SETUP.md` via
  une unité qui possède ce fichier.
- KI-030 : purge des données WebView2 à la désinstallation, phase 6.

### Documentation updated

- ce fichier — statuts, critères d'acceptation, compte rendu J2 et synthèse ;
- `docs/features/README.md` — F0005 `Done` et récit aligné ;
- `docs/tickets/T0055-source-version-produit-alpha.md` — clôture par le
  parcours installé ;
- `docs/tickets/README.md` — T0055 `Done` ;
- `docs/CURRENT_STATE.md` — distribution prouvée installée, « Ce qui manque »
  resserré sur F0006 et F0007 ;
- `docs/KNOWN_ISSUES.md` — KI-029 et KI-030.
