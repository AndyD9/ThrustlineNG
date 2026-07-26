# Préparer l'environnement ThrustlineNG

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
