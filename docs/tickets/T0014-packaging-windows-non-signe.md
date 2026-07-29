# T0014 — Valider le packaging Windows non signé

Status: Review
Owner: Andy
Branch: `foundation/t0014-windows-unsigned-packaging`
Phase: 1
Risk: High
Security-sensitive: Yes

## Workflow evidence — 29 juillet 2026

Le ticket entre en `In progress` sur une branche dédiée, empilée sur
`docs/t0013-t0016-merge-reconciliation` au commit `f3350c6`. Cette base corrige
les statuts contradictoires de T0007–T0009 et borne les dépendances de T0014 aux
implémentations desktop/bridge T0007–T0010 présentes dans `main`, ainsi qu'à la
CI T0013 terminée. La branche devra être rebasée sur `main`, ou sa base de Pull
Request changée, après fusion de cette réconciliation.

T0007–T0009 restent `Verify` pour des contrôles humains sans rapport avec la
fabrication d'un installateur. T0011 et T0012 ne sont pas des dépendances :
aucune session MSFS, DLL SimConnect, pile Docker ou instance Supabase n'est
nécessaire au packaging local.

## Goal

Produire et valider sur Windows x64 un installateur NSIS Tauri non signé qui :

- installe le desktop et le bridge .NET 10 self-contained ;
- lance réellement l'application installée et son bridge ;
- se désinstalle sans laisser de processus ou de fichier dans le dossier choisi ;
- est construit de manière déterministe par une commande racine ;
- reste explicitement une preuve interne, jamais une release distribuable.

## Context

T0007 construit uniquement l'exécutable Tauri avec `--no-bundle`. T0009 publie
le bridge self-contained dans un dossier de 191 fichiers. T0010 lance en Release
un `Thrustline.Bridge.exe` attendu près du desktop, mais aucun installateur ne
réunit encore ces artefacts.

Tauri 2 propose sous Windows des bundles MSI/WiX ou NSIS. Ce ticket retient
uniquement NSIS en mode utilisateur courant :

- il couvre le premier chemin installable sans exiger la fonctionnalité Windows
  VBSCRIPT nécessaire au MSI ;
- il n'exige pas de privilège administrateur ;
- il permet une installation silencieuse dans un dossier de validation explicite.

Sources officielles consultées le 29 juillet 2026 :

- https://v2.tauri.app/distribute/windows-installer/
- https://v2.tauri.app/reference/config/#bundleconfig
- https://v2.tauri.app/develop/resources/
- https://v2.tauri.app/distribute/sign/windows/

La documentation Tauri précise qu'un package Windows peut être exécuté sans
signature, avec un avertissement SmartScreen possible après téléchargement.
T0014 ne contourne pas cet avertissement et ne prétend pas produire une release.

## Dependencies

- implémentations T0007–T0010 présentes dans `main` ;
- T0013 `Done` et ses workflows en lecture seule ;
- `docs/decisions/ADR-0003-matrice-support-windows-msfs.md` ;
- `docs/decisions/ADR-0004-stack-cible.md` ;
- `docs/STACK.md`, `docs/ARCHITECTURE.md`, `docs/SECURITY.md` et
  `docs/QUALITY.md` ;
- Windows x64, Rust/.NET/Node/pnpm épinglés et WebView2 Evergreen.

## Allowed areas

- `package.json` pour les commandes de packaging ;
- `apps/desktop/src-tauri/tauri.package.conf.json` ;
- `apps/desktop/src-tauri/src/bridge.rs` et son appel depuis `lib.rs`, uniquement
  pour résoudre le bridge installé ;
- `scripts/build-windows-package.ps1` ;
- `scripts/test-windows-package.ps1` ;
- `tests/windows-package/` ;
- `.github/workflows/ci.yml` ;
- `.gitignore` si une sortie générée supplémentaire doit être ignorée ;
- `docs/ARCHITECTURE.md` ;
- `docs/SECURITY.md` ;
- `docs/QUALITY.md` ;
- `docs/SETUP.md` ;
- `docs/CURRENT_STATE.md` ;
- `docs/KNOWN_ISSUES.md` uniquement pour une découverte hors périmètre ;
- ce ticket et `docs/tickets/README.md`.

## Do not touch

- frontend React, routes, styles et comportements utilisateur ;
- contrats REST/SignalR et logique du bridge ;
- adaptateur SimConnect, traces et SDK ;
- Supabase, migrations, seed, RLS et types générés ;
- capabilities Tauri, CSP ou plugins ;
- version des dépendances et lockfiles, sauf nécessité prouvée et documentée ;
- MSI/WiX, MSIX, Microsoft Store ou installation machine-wide ;
- Authenticode, certificat, secret, timestamp, provenance signée ou updater ;
- création d'une release, d'un tag ou d'un canal de distribution ;
- association de fichiers, protocole URL, auto-start, service ou tâche planifiée ;
- téléchargement puis exécution d'un script distant ;
- fusion de Pull Request.

## Requirements

### 1. Définir un bundle Windows borné

- Ajouter une configuration Windows dédiée fusionnée avec la configuration Tauri
  commune.
- Activer uniquement la cible `nsis`.
- Cibler `x86_64-pc-windows-msvc`.
- Utiliser le mode d'installation NSIS `currentUser`.
- Conserver WebView2 Evergreen avec le mode Tauri `downloadBootstrapper` ; ne pas
  embarquer de runtime fixe ou offline dans ce ticket.
- Conserver la CSP, les capabilities et l'absence de plugin existantes.
- Ne produire aucun artefact updater.

### 2. Publier et embarquer le bridge

- Publier `apps/bridge/Thrustline.Bridge.csproj` en Release, `win-x64`,
  self-contained et depuis les fichiers verrouillés.
- Placer la publication dans un dossier de staging explicite sous
  `artifacts/t0014/`.
- Inclure l'intégralité du dossier publié comme ressource `bridge/` du bundle ;
  ne jamais dépendre du SDK .NET installé sur la machine cible.
- Résoudre le bridge Release depuis les ressources installées.
- Conserver `THRUSTLINE_BRIDGE_PATH` uniquement pour le développement Debug.
- Échouer avant le bundle si l'exécutable ou un fichier attendu du runtime manque.
- Ne pas exposer le chemin du bridge, le port ou le jeton à la WebView.

### 3. Fournir une commande reproductible

`pnpm windows:package` doit :

1. refuser un hôte non Windows ou une architecture non x64 ;
2. vérifier les outils épinglés ;
3. créer uniquement `artifacts/t0014/` et les sorties Tauri ignorées ;
4. publier le bridge ;
5. construire le frontend et le desktop ;
6. produire exactement un installateur NSIS attendu ;
7. vérifier que desktop et bridge sont non signés ;
8. écrire un manifeste JSON de fichiers, tailles et SHA-256 sans chemin
   utilisateur ni secret ;
9. retourner un code non nul sur artefact manquant, multiple ou signé.

Le script doit accepter un dossier de sortie explicite pour les tests. Tout
nettoyage récursif doit vérifier que la cible résolue reste sous ce dossier.

### 4. Ajouter des invariants automatisés

Le harnais statique doit échouer si :

- le bundle active une cible autre que NSIS ;
- l'installation devient machine-wide ou demande une élévation ;
- un runtime WebView2 fixe/offline est embarqué ;
- une configuration de signature ou d'updater apparaît ;
- le bridge complet n'est pas inclus ;
- une capability, un plugin ou une origine réseau de production est ajouté ;
- le workflow publie une release, un tag ou utilise une permission d'écriture ;
- la rétention de l'artefact dépasse 30 jours ;
- le nom de l'artefact ne contient pas explicitement `unsigned`.

Ajouter au moins deux mutations négatives au harnais.

### 5. Valider installation, lancement et désinstallation

`pnpm windows:package:test` doit utiliser un dossier temporaire explicite sous
`artifacts/t0014/validation/` et :

1. installer silencieusement le package sans élévation ;
2. confirmer la présence du desktop, du bridge et de ses dépendances ;
3. confirmer l'absence de signature Authenticode ;
4. lancer le desktop installé avec WebView2 Evergreen présent ;
5. confirmer que le processus desktop et le bridge démarrent ;
6. fermer le desktop et confirmer l'arrêt du bridge ;
7. lancer le diagnostic publié du bridge et obtenir `Healthy`/`0` ;
8. désinstaller silencieusement ;
9. confirmer l'absence de processus et de fichier dans le dossier de validation.

Le script ne doit supprimer aucun dossier utilisateur générique. Si NSIS ne
respecte pas le dossier explicite ou si le désinstalleur manque, le test échoue
sans nettoyer une autre cible.

### 6. Étendre la CI sans publier

Sur le job Windows T0013 :

- exécuter le harnais de packaging ;
- construire le package après les gates existants ;
- valider le manifeste et les signatures absentes ;
- téléverser l'installateur et le manifeste comme artefact
  `t0014-windows-unsigned-<sha>` pendant 30 jours ;
- conserver `contents: read`, `persist-credentials: false` et zéro secret ;
- ne pas créer de release ni exécuter l'installateur sur le runner si cette
  mutation du poste n'est pas suffisamment isolée.

### 7. Documenter les limites

- Distinguer build, installation locale et distribution publique.
- Documenter l'avertissement attendu pour un binaire non signé.
- Documenter la dépendance à WebView2 Evergreen et à Internet si le runtime doit
  être récupéré par l'installateur.
- Consigner taille, SHA-256, contenu bridge et résultat installation/lancement/
  désinstallation.
- Laisser signature, provenance, updater, upgrade N-1 et rollback de version à la
  phase 6.

## Non-goals

- Produire un package publiable ou recommandé à des utilisateurs.
- Signer ou supprimer l'avertissement SmartScreen.
- Tester MSI, MSIX, Microsoft Store, Steam ou winget.
- Installer ou réparer WebView2 automatiquement hors du comportement Tauri.
- Prouver une mise à jour, un rollback de version ou une restauration de données.
- Tester MSFS/SimConnect ou Supabase.
- Réduire la taille du bridge avec single-file, trimming ou Native AOT.
- Fixer les budgets T0015.

## Acceptance criteria

- [x] La branche dédiée est basée sur la réconciliation `f3350c6`.
- [x] La configuration produit uniquement un NSIS `currentUser` Windows x64.
- [x] Le bridge .NET 10 self-contained complet est inclus et résolu après
      installation.
- [x] `pnpm windows:package` produit un installateur, un manifeste SHA-256 et
      échoue sur un artefact absent, multiple ou signé.
- [x] Desktop, bridge et installateur sont confirmés `NotSigned`.
- [x] Le harnais statique passe et détecte au moins deux mutations négatives.
- [x] L'installation silencieuse dans le dossier explicite réussit sans
      élévation.
- [x] Le desktop installé lance le bridge, puis leur fermeture ne laisse aucun
      processus.
- [x] Le bridge installé répond `Healthy`/`0`.
- [x] La désinstallation réussit et ne laisse aucun fichier dans la cible.
- [x] Frontend, desktop, bridge et harnais CI existants restent verts.
- [ ] La CI construit et conserve uniquement une preuve non signée pendant
      30 jours, sans permission d'écriture ni release.
- [x] Les limites SmartScreen, WebView2, signature, updater et distribution sont
      documentées.
- [x] Aucun secret, donnée personnelle, chemin utilisateur ou binaire généré
      n'est versionné.

## Security review

- actifs : intégrité de l'installateur, exécutable desktop, bridge, jeton local et
  machine de validation ;
- frontières : archive/installer non fiable vers le système de fichiers local,
  desktop vers bridge enfant et code de PR vers runner CI ;
- abus : remplacement du bridge, ressource omise, installation privilégiée,
  signature trompeuse, chemin de suppression élargi, persistence après
  désinstallation, release involontaire et fuite de secret ;
- contrôles : staging borné, hashes SHA-256, Authenticode `NotSigned`, install
  `currentUser`, cible explicite vérifiée, ressources complètes, CI en lecture
  seule et absence de publication ;
- atomicité/idempotence : deux builds doivent produire le même inventaire logique
  hors métadonnées propres au format NSIS ; installation et désinstallation
  doivent être répétables ;
- logs/vie privée : noms relatifs, tailles, hashes et codes de sortie uniquement ;
  aucun chemin personnel, jeton, header, variable d'environnement ou contenu
  utilisateur.

## Automated validation

```powershell
# Depuis la racine
pwsh -NoProfile -File .\scripts\check-toolchain.ps1
pwsh -NoProfile -File .\tests\toolchain\run.ps1
pnpm install --frozen-lockfile

pnpm frontend:typecheck
pnpm frontend:test
pnpm frontend:coverage
pnpm frontend:build
pnpm desktop:check
pnpm desktop:test
pnpm bridge:build
pnpm bridge:test
pnpm bridge:health

pnpm windows:package:check
pnpm windows:package
pnpm windows:package:test
pnpm ci:check

git diff --check
git status --short
```

## Manual verification

1. Confirmer Windows x64, WebView2 Evergreen et l'absence de processus
   Thrustline.
2. Construire le package depuis une restauration figée.
3. Inspecter le manifeste, les trois statuts Authenticode et le contenu bridge.
4. Installer silencieusement dans la cible explicite sans élévation.
5. Ouvrir le desktop installé et confirmer la fenêtre, le titre et le bridge.
6. Fermer l'application et confirmer l'absence de processus.
7. Exécuter `Thrustline.Bridge.exe --health-check`.
8. Désinstaller, puis confirmer que la cible est vide ou absente.
9. Répéter une seconde fois le parcours installation/désinstallation.
10. Vérifier qu'aucune release, clé de registre hors installateur, tâche, service
    ou règle pare-feu n'a été ajouté.

Temps cible : 20 minutes hors compilation et premier téléchargement des outils
NSIS gérés par Tauri.

## Rollback

Avant fusion, abandonner la branche et supprimer uniquement le dossier
`artifacts/t0014/` après vérification de son chemin absolu. Si une validation a
installé le package, exécuter son désinstalleur depuis la cible enregistrée avant
d'abandonner la branche.

Après fusion, ouvrir un ticket de correction et revenir à la commande
`desktop:build --no-bundle`. Ne jamais supprimer un dossier d'installation
calculé sans avoir confirmé qu'il correspond exactement à la cible T0014.

## Completion Report

### Summary

Un installateur NSIS Windows x64 non signé est construit depuis la racine. Il
embarque le desktop et les 334 fichiers de la publication .NET 10 self-contained
du bridge. Le desktop Release résout le bridge sous `$RESOURCE/bridge`, tandis
que le développement Debug conserve l'override explicite.

Deux cycles finaux installation/lancement/health check/fermeture/désinstallation
ont réussi. Le ticket passe en `Review`, pas `Done` : le workflow GitHub est
configuré et ses invariants passent localement, mais son exécution sur la branche
publiée n'est pas encore observée.

### Files changed

- configuration et runtime : `tauri.package.conf.json`, résolution Rust du
  bridge, scripts racine `package.json` ;
- build/validation : `scripts/build-windows-package.ps1`,
  `scripts/test-windows-package.ps1`, `tests/windows-package/run.ps1` ;
- CI : job Windows étendu et artefact `t0014-windows-unsigned-<sha>` ;
- documentation : architecture, sécurité, qualité, setup, état, index et ticket.

### Commands and results

- versions directes : Node `24.18.0`, pnpm `11.17.0`, .NET SDK `10.0.201`,
  Rust/Cargo `1.97.1`, conformes ;
- `pnpm windows:package:check` : réussi, dépôt réel et deux mutations négatives
  détectées (`perMachine` et cible MSI supplémentaire) ;
- `pnpm windows:package` : réussi après autorisation d'accès au NuGet.Config
  utilisateur et au réseau pour les runtime packs/outils Tauri ;
- installateur final : `Thrustline_0.0.0_x64-setup.exe`, 35 398 356 octets,
  SHA-256
  `F89EACAFB35EBAAC5C0859ED8D32564F14DDB91F6AC090E40737C709868E9F5B` ;
- bridge embarqué : 334 fichiers, 110 477 582 octets avant compression ;
  `Thrustline.Bridge.exe` SHA-256
  `9FF19B29CD16CB4E400A7251D0337FAECE150E59C4BD3969FE4C59843E2DCF01` ;
- Authenticode : installateur, desktop et bridge `NotSigned` ;
- frontend : typecheck, 8/8 tests, couverture et build réussis ;
- desktop : check/Clippy, 8/8 tests frontend, 3/3 tests Rust, invariants et builds
  Release avec/sans bundle réussis ;
- bridge : build sans avertissement, 13/13 tests et `Healthy` réussis ;
- harnais CI T0013 : réussi directement avec Windows PowerShell, dépôt et deux
  mutations ;
- harnais toolchain : non exécuté, car `pwsh` 7.6 n'est pas disponible dans le
  `PATH` et le script refuse correctement Windows PowerShell 5.1.

Le premier rejeu renforcé a détecté deux affirmations erronées du manifeste :
nom desktop puis hash du payload. Le nom a été corrigé. Tauri applique des
métadonnées PE de bundle, de sorte que le fichier installé diffère du fichier
de build à taille égale ; le manifeste distingue désormais honnêtement le hash
du build, et le hash de l'installateur couvre le payload distribué. Le nettoyage
d'échec exécute maintenant le désinstalleur de la cible contrôlée.

### Manual verification result

Deux cycles finaux ont confirmé une fenêtre native intitulée `Thrustline`, un
seul bridge, l'arrêt des deux processus, `Healthy`/`0` depuis le bridge installé
et la disparition du dossier après désinstallation. Les recherches finales ne
trouvent aucun processus, fichier, raccourci Menu Démarrer, enregistrement de
désinstallation, service, tâche planifiée ou règle pare-feu Thrustline.

### Security review result

Conforme au périmètre : installation `currentUser`, suppressions bornées,
signatures absentes vérifiées, hashes relatifs, aucune capability/plugin/origine
réseau ajouté, CI `contents: read`, aucun secret et aucune release.

### Risks and limitations

- package non signé susceptible de déclencher SmartScreen après téléchargement ;
- WebView2 Evergreen requis ; le mode `downloadBootstrapper` exige Internet si
  le runtime manque ;
- version applicative de fondation `0.0.0`, sans politique de release ;
- MSI, signature, provenance, updater, upgrade N-1 et rollback non testés ;
- le bundle NSIS contient des métadonnées de build : deux fabrications ont le
  même inventaire logique, mais pas un SHA-256 binaire identique ;
- exécution GitHub T0014 pas encore observée ;
- PowerShell 7.6 absent du `PATH` local ;
- les preuves humaines encore ouvertes dans T0007–T0009 ne sont pas closes par
  ce ticket.

### Follow-ups

- observer les jobs et télécharger l'artefact de la Pull Request T0014 ;
- après fusion de la réconciliation documentaire, rebaser la branche sur `main`
  ou changer la base de la Pull Request ;
- traiter signature, provenance, updater et scénarios upgrade/rollback en phase
  6 ;
- fixer les budgets de taille et de temps dans T0015.

### Documentation updated

`ARCHITECTURE`, `SECURITY`, `QUALITY`, `SETUP`, `CURRENT_STATE`, index et ticket.

### Git handoff

- branche : `foundation/t0014-windows-unsigned-packaging` ;
- base empilée : `docs/t0013-t0016-merge-reconciliation` au commit `f3350c6` ;
- commit d'implémentation : `9b19283` ;
- PR brouillon : https://github.com/AndyD9/ThrustlineNG/pull/18 ;
- base/head : `docs/t0013-t0016-merge-reconciliation` /
  `foundation/t0014-windows-unsigned-packaging` ;
- jobs Windows, Supabase et supply chain en cours lors de l'ouverture ;
- après fusion de la base, rebaser sur `main` ou changer la base de la PR avant
  revue finale.
