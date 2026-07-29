# Préparer l'environnement ThrustlineNG

Pour T0010, `THRUSTLINE_BRIDGE_PATH` désigne en développement le bridge publié.
Le package T0014 place sa publication self-contained sous
`$RESOURCE/bridge/Thrustline.Bridge.exe`. Le jeton et le port sont générés à
chaque lancement par Tauri, jamais par variable d'environnement.

## Plateforme prise en charge

Le socle cible Windows 11 x64 avec Git pour Windows et PowerShell 7. N'utilisez
pas Git depuis WSL sur un chemin `/mnt/c` : le mélange des outils peut modifier
les permissions et les fins de ligne.

## Versions requises

| Outil | Version |
| --- | --- |
| Node.js | 24.18.0 |
| pnpm | 11.17.0 |
| Rust (`rustc` et `cargo`) | 1.97.1, cible `x86_64-pc-windows-msvc` |
| SDK .NET | 10.0.201 |
| Runtime .NET | 10.0 |
| PowerShell | 7.6.0 minimum |
| Git pour Windows | version maintenue |

La source canonique est `eng/versions.json`. Les installations doivent provenir
des sites officiels :

- [Node.js](https://nodejs.org/en/download)
- [pnpm](https://pnpm.io/installation)
- [Rust](https://rustup.rs/)
- [.NET](https://dotnet.microsoft.com/download/dotnet/10.0)
- [PowerShell](https://learn.microsoft.com/powershell/scripting/install/installing-powershell-on-windows)
- [Git pour Windows](https://gitforwindows.org/)

Les scripts du dépôt n'installent rien et ne demandent jamais de droits
administrateur.

## Depuis un clone propre

Dans PowerShell 7.6 ou une version compatible :

```powershell
git clone https://github.com/AndyD9/ThrustlineNG.git
Set-Location .\ThrustlineNG
pwsh -NoProfile -File .\scripts\check-toolchain.ps1
pwsh -NoProfile -File .\scripts\bootstrap.ps1 -CheckOnly
pwsh -NoProfile -File .\scripts\bootstrap.ps1
```

Le bootstrap vérifie d'abord tous les outils, puis exécute uniquement
`pnpm install --frozen-lockfile`. Il est idempotent et n'altère ni le profil
PowerShell, ni les outils globaux. Aucun secret n'est requis à ce stade.

Pour une sortie utilisable par un outil :

```powershell
pwsh -NoProfile -File .\scripts\check-toolchain.ps1 -Json
```

## Erreurs courantes

- `missing` : installez l'outil depuis le lien officiel ci-dessus.
- `wrong_version` : activez la version exacte indiquée. Aucune correction
  automatique n'est tentée.
- `unexpected_error` : vérifiez que le fichier de versions et le `PATH` sont
  lisibles, puis relancez sans profil.
- Corepack tente d'accéder au registre : activez explicitement pnpm 11.17.0
  selon sa documentation avant le bootstrap.
- Le SDK .NET dérive vers un autre patch : `global.json` utilise
  `rollForward: disable`; installez 10.0.201 côte à côte.

## Mettre les pins à jour

Une mise à jour n'est jamais automatique :

1. ouvrir un ticket dédié ;
2. vérifier les sources officielles, les avis de sécurité et les compatibilités ;
3. modifier `eng/versions.json` ;
4. synchroniser tous les pins natifs ;
5. restaurer les lockfiles avec l'ancienne puis la nouvelle version si requis ;
6. exécuter le contrôle, le bootstrap et les tests ;
7. mesurer et documenter les impacts ;
8. conserver comme rollback le commit précédent.

## Shell desktop Tauri

Le shell T0007 exige WebView2 Evergreen et les outils épinglés ci-dessus. Il
n'installe aucun runtime, plugin ou outil global.

```powershell
pnpm desktop:check
pnpm desktop:test
pnpm desktop:dev
pnpm desktop:build
pnpm desktop:measure
```

`desktop:measure` écrit uniquement dans `artifacts/t0007`. Pour choisir un autre
emplacement explicite :

```powershell
powershell -NoProfile -ExecutionPolicy Bypass `
  -File .\scripts\measure-tauri-shell.ps1 `
  -OutputDirectory .\artifacts\ma-mesure
```

WebView2 Evergreen est fourni avec Windows 11 et se met à jour séparément. S'il
manque, installer le runtime avec la procédure Microsoft officielle ; le shell
ne le télécharge et ne le répare jamais automatiquement.

## Frontend React

Le frontend utilise React 19, TypeScript strict, Vite, Vitest, Tailwind CSS et
React Router en mode SPA local. Aucun secret ni service distant n'est requis.

```powershell
pnpm frontend:dev
pnpm frontend:typecheck
pnpm frontend:test
pnpm frontend:coverage
pnpm frontend:build
pnpm frontend:measure
```

`frontend:dev` écoute uniquement sur `127.0.0.1:1420` et échoue si le port est
occupé. Le routeur utilise le fragment d'URL (`#/`) pour fonctionner sans
réécriture serveur. `frontend:measure` écrit dans `artifacts/t0008`, ignoré par
Git, et effectue cinq lancements froids, cinq chauds et dix cycles de fermeture.

## Bridge .NET

Le bridge T0009 ne requiert ni secret, ni service, ni package NuGet tiers :

```powershell
pnpm bridge:build
pnpm bridge:test
pnpm bridge:health
pnpm bridge:publish
```

La dernière commande produit le dossier autonome Windows x64 sous
`apps/bridge/bin/Release/net10.0/win-x64/publish`. Lancez
`Thrustline.Bridge.exe --health-check` pour un diagnostic ponctuel ou sans
argument pour observer son cycle de vie. Ctrl+C demande un arrêt propre.

## Package Windows non signé

T0014 produit une preuve NSIS x64 en mode utilisateur courant. Restaurer les
dépendances figées, puis exécuter :

```powershell
pnpm windows:package:check
pnpm windows:package
pnpm windows:package:test
```

Les sorties sont sous `artifacts/t0014/package`. Le premier build peut
télécharger les runtime packs Microsoft depuis NuGet et les outils NSIS gérés
par Tauri ; aucun script distant n'est exécuté. Le test installe temporairement
le package sous `artifacts/t0014/validation`, ouvre le desktop, vérifie le bridge
et désinstalle.

Le package est volontairement non signé. Ne le publier ni comme release ni
comme binaire recommandé : Windows peut afficher SmartScreen après un
téléchargement. WebView2 Evergreen est requis ; l'installateur utilise le
bootstrapper téléchargé si le runtime manque. MSI, signature, updater, upgrade
N-1 et rollback appartiennent à la phase de distribution sûre.

## Backend Supabase local

T0012 épingle Supabase CLI 2.109.1 comme dépendance du workspace. Installer et
démarrer Docker Desktop, Rancher Desktop ou un runtime compatible avec l'API
Docker avant la pile locale. Le runtime doit rester lié à la machine locale :
les services de développement n'ont ni TLS, ni durcissement de production.

Depuis la racine :

```powershell
pnpm install --frozen-lockfile
pnpm backend:check
pnpm backend:start
pnpm backend:reset
pnpm backend:test
pnpm backend:types:check
pnpm backend:stop
```

Ports locaux réservés par `supabase/config.toml` :

- API : `127.0.0.1:54321` ;
- PostgreSQL : `127.0.0.1:54322` ;
- Studio : `127.0.0.1:54323` ;
- base shadow : `127.0.0.1:54320`.

`backend:start` exclut les services hors périmètre T0012.
Il crée ou réutilise le réseau Docker `thrustline-local`, configuré pour publier
les ports sur `127.0.0.1` uniquement. Le script retrouve `docker.exe` dans le
`PATH` ou dans les emplacements utilisateur/système de Docker Desktop, puis
inspecte les ports réellement publiés. Si Docker utilise `0.0.0.0` ou `[::]`,
la pile est immédiatement arrêtée et la commande échoue : ne contournez pas ce
contrôle. Ce comportement a été observé avec Docker Desktop 29.6.2 ; utilisez un
runtime/configuration qui respecte la liaison loopback avant la vérification
Studio. La sortie de démarrage est masquée pour ne pas recopier les credentials
locaux dans les journaux.
`backend:reset` détruit uniquement la base locale puis rejoue migrations et
seed. Aucun script du dépôt ne lie ou ne pousse un projet distant. Le seed
contient deux utilisateurs sans mot de passe et deux compagnies entièrement
synthétiques ; aucun secret n'est requis.

Après une migration, démarrer la pile puis exécuter `pnpm backend:types` et
versionner le diff de `packages/database/src/database.types.ts`. Utiliser
`backend:types:check` pour détecter un fichier périmé. Une connexion Docker
absente produit un échec avant toute migration ; démarrer le runtime et relancer.

Après `backend:stop`, le réseau vide peut être conservé pour le prochain
démarrage. Sa suppression éventuelle reste une action Docker locale manuelle et
explicite.

La pile locale Supabase n'est pas strictement identique à la plateforme
managée. PostgreSQL 17, migrations et tests RLS devront être rejoués séparément
sur les futurs environnements dev/staging avant promotion.

## Vérifier la CI et la supply chain

Depuis la racine, après la restauration figée :

```powershell
$env:CI = 'true'
pnpm install --frozen-lockfile
pnpm ci:check
pnpm supply-chain:report
```

`ci:check` fonctionne sous Windows PowerShell et vérifie statiquement les
workflows, y compris deux mutations négatives. `supply-chain:report` exige
PowerShell 7, Cargo et .NET ; il écrit uniquement sous
`artifacts/supply-chain/`, ignoré par Git.

`pnpm ci:backend` est réservé au runner `ubuntu-24.04` disposant de Docker. Ne
pas le substituer au parcours local T0012 sous Windows : les deux scripts
vérifient la publication réelle des ports mais ciblent leur environnement
respectif.

Les workflows ne nécessitent aucun secret applicatif. Le dépôt appartient
actuellement à un compte GitHub personnel ; l'action Gitleaks n'exige donc pas de
licence d'organisation. Si le dépôt est transféré à une organisation, remplacer
ou configurer ce scanner par un ticket de sécurité avant de rendre le workflow
obligatoire, sans ajouter silencieusement un secret sur les PR externes.
