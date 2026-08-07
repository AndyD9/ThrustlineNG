# Plateformes prises en charge

Dernière mise à jour : 4 août 2026 (jalon d'alpha technique interne T0055 ; la
matrice de support reste inchangée depuis le 24 juillet 2026)
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

## Alpha technique interne

T0055 fixe la version produit canonique `0.1.0-alpha.1`, canal `internal-alpha`,
dans `eng/product-version.json`. Le jalon correspondant est une **alpha technique
interne** :

- l'installateur `Thrustline-0.1.0-alpha.1-win-x64.exe` est **non signé** et
  déclenche SmartScreen ; il ne doit pas être distribué hors validation interne ;
- il n'existe ni tag Git publié, ni canal de release, ni updater, ni rollback
  N-1 ; ces capacités relèvent de la phase 6 ;
- aucune donnée réelle n'est admise : le parcours d'alpha s'exécute sur la pile
  Supabase locale et des données synthétiques ;
- cette version ne promeut aucune ligne de la matrice ci-dessus vers
  `Supported` et ne prouve aucun vol MSFS réel.

L'interface affiche cette version produit ; ni chemin utilisateur, ni jeton, ni
secret n'y apparaissent.

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

Une bibliothèque cliente SimConnect introuvable suit la même règle (F0003 J1) :
le bridge démarre, reste sain, rend l'état `unavailable` — distinct de `idle` —
et son diagnostic dit quoi installer (le SDK MSFS 2024, ou un chemin explicite
`--simconnect-library`) sans divulguer de chemin utilisateur. La sonde ne
consulte que des sources dignes de confiance, dans l'ordre : chemin explicite,
répertoire de l'application, installation du SDK déclarée par le système
(`MSFS2024_SDK` puis `MSFS_SDK`) ; une copie apportée par un tiers hors de ces
sources n'est jamais chargée. Compagnie, catalogue, achat, dispatch et flotte
restent utilisables sans télémétrie.

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
