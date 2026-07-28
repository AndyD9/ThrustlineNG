# Plateformes prises en charge

Dernière mise à jour : 24 juillet 2026
Décision acceptée : `ADR-0003`

Thrustline cible une application desktop **Windows 11 x64** connectée localement
à **Microsoft Flight Simulator 2024**. Le support Xbox console, Cloud Gaming et
PlayStation n'est pas possible : l'application et son client SimConnect doivent
fonctionner sur le même PC Windows.

## Signification des niveaux

- **Supported** : combinaison testée réellement pour la release, documentée et
  prise en charge en cas d'incident.
- **Compatible** : test réel concluant, sans garantie à chaque release.
- **Experimental** : fonctionnement attendu mais couverture insuffisante. Ce
  niveau n'est pas utilisé actuellement sur décision produit.
- **Unsupported** : combinaison exclue ou pas encore validée.

`Compatibility pending` signifie qu'une combinaison auparavant `Supported` est
en cours de revalidation après une mise à jour.

## Matrice actuelle

### Windows

| Système | Architecture | Niveau |
| --- | --- | --- |
| Windows 11 Home/Pro, version publique encore maintenue par Microsoft | x64 | **Unsupported — validation requise**, cible `Supported` |
| Windows 11 Enterprise/Education maintenu | x64 | **Unsupported — validation requise**, cible `Compatible` |
| Windows 11 Insider/Preview | x64 | **Unsupported** |
| Windows 11 ARM64 | ARM64 | **Unsupported** |
| Windows 10 | toute | **Unsupported** |
| Windows Server, Wine/Proton | toute | **Unsupported** |

Une version Windows arrivée en fin de support Microsoft n'est pas supportée par
Thrustline.

### Microsoft Flight Simulator

| Simulateur | Canal | Niveau |
| --- | --- | --- |
| MSFS 2024 stable | Microsoft Store/Xbox App | **Unsupported — validation requise**, cible `Supported` |
| MSFS 2024 stable | Steam | **Unsupported — validation requise**, cible `Supported` |
| MSFS 2024 Beta/Sim Update Preview | Store ou Steam | **Unsupported** |
| MSFS 2020 | Store ou Steam | **Unsupported** |
| MSFS sur console/cloud | tout | **Unsupported** |

Aucune ligne n'est encore `Supported`, car T0004 est documentaire et n'a exécuté
aucun vol réel. Les canaux Store et Steam doivent chacun réussir leur propre
validation ; le résultat de l'un ne prouve pas l'autre.

## Prérequis

- Windows 11 x64 maintenu et à jour.
- Session utilisateur standard ; aucun droit administrateur permanent.
- WebView2 Evergreen présent et maintenu. L'installateur doit le vérifier et
  proposer sa réparation officielle s'il manque.
- Connexion Internet pour l'authentification et les fonctions cloud.
- MSFS 2024 lancé dans la même session Windows que Thrustline.
- Le compte ayant acheté ou installé MSFS peut être différent si le simulateur
  démarre normalement dans cette session et si SimConnect local fonctionne sans
  contourner les permissions.

Le bridge .NET doit être livré avec son runtime. L'utilisateur ne doit installer
ni SDK .NET, ni outils de développement, ni SDK MSFS.

## Profils matériels

Les exigences propres à Thrustline restent provisoires jusqu'aux mesures T0005.
Les exigences officielles de MSFS 2024 s'ajoutent séparément.

| Profil | Configuration Thrustline |
| --- | --- |
| Minimum supporté, à valider | CPU x64 moderne 4 cœurs, 16 Go de RAM, 2 Go libres hors MSFS, Windows 11 maintenu, écran 1280×720 à 100–150 % |
| Recommandé | Ryzen 7 5800X ou équivalent, 32 Go, 4 Go libres hors MSFS, écran 1920×1080 à 100–150 % |
| CI/replay sans MSFS | 4 vCPU x64, 8 Go, 10 Go pour sources/caches/artefacts, Windows 11, écran virtuel 1920×1080 |

La machine de validation disponible possède un Ryzen 7 5800X, 32 Go de RAM et
un GPU RX 6070 XT confirmé par le propriétaire de la machine.

## Quand une mise à jour arrive

Après une feature update Windows ou une Sim Update MSFS, une combinaison déjà
supportée peut passer temporairement `Compatibility pending`. Thrustline :

1. relève les versions sans collecter de donnée personnelle ;
2. exécute les smoke tests, puis le golden path ;
3. publie les limitations connues sans promettre un délai de confirmation ;
4. rétablit `Supported` uniquement après une nouvelle fiche de preuve ;
5. laisse l'application démarrer avec un avertissement lorsque c'est sûr.

Un blocage ou kill switch n'est autorisé qu'en cas de risque réel de corruption,
double clôture, perte de données ou sécurité. La lecture et la récupération des
données doivent rester disponibles autant que possible.

## Ce qui est testé

La première promotion d'un canal vers `Supported` exige les 14 scénarios :
MSFS fermé ; ordres de lancement ; reconnexion ; menu/chargement/vol ; vol normal ;
go-around/touch-and-go ; pauses/accélération ; slew/téléportation ; retour menu et
changement d'appareil ; crash MSFS ; perte Internet ; vol long ; avion natif et
add-on ; variable SimConnect absente ou invalide.

Chaque preuve indique la version Thrustline, le commit, Windows/build, MSFS/build
et canal, l'appareil, le scénario, le résultat, la date, le testeur, les anomalies
et la trace de replay. Les futures fiches seront conservées dans
`docs/validation/platforms/`.

Le protocole détaillé et les sources officielles sont dans
`docs/decisions/ADR-0003-matrice-support-windows-msfs.md`.
