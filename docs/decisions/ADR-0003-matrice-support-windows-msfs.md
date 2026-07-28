# ADR-0003 — Matrice de support Windows et Microsoft Flight Simulator

Status: Accepted
Date: 2026-07-24
Deciders: Andy (Product Owner)
Supersedes: —
Superseded by: —

## Context

Thrustline est une application desktop Windows qui utilise un bridge .NET hors
processus pour communiquer localement avec Microsoft Flight Simulator par
SimConnect. Avant de figer le socle de la réécriture, il faut distinguer la cible
produit de la compatibilité réellement prouvée.

Andy possède MSFS 2024 et souhaite couvrir ses canaux Microsoft Store/Xbox App et
Steam. Une seule machine de test est disponible : AMD Ryzen 7 5800X, 32 Go de RAM
et AMD Radeon RX 6070 XT, sous réserve de confirmer le modèle exact du GPU, la
version/build de Windows 11, l'écran/DPI et les installations MSFS présentes.

Andy décide :

- Windows 11 x64 uniquement ;
- MSFS 2024 uniquement, canaux Microsoft Store/Xbox App et Steam ;
- aucun support Windows ARM64, Windows Insider, MSFS Beta ou Sim Update Preview ;
- fonctionnement dans la session utilisateur courante même lorsque MSFS dépend
  d'un autre compte Windows/Microsoft, à valider sans contourner les permissions ;
- aucun engagement de délai après une mise à jour Windows ou MSFS ;
- aucun niveau `Experimental` faute de validation ;
- lancement autorisé avec avertissement sur une combinaison non supportée,
  sauf risque réel de corruption ou de sécurité.

Andy a confirmé le 24 juillet 2026 que le lancement reste autorisé avec
avertissement hors matrice, sous réserve du garde-fou corruption/sécurité.

## Official facts and inferences

Sources consultées le 24 juillet 2026 :

| Source officielle | Publication/version | Fait retenu |
| --- | --- | --- |
| [Windows 11 release information](https://learn.microsoft.com/en-us/windows/release-health/windows11-release-information) | état publié au 14 juillet 2026 | Windows 11 suit une cadence annuelle ; Home/Pro reçoivent 24 mois et Enterprise/Education 36 mois de support. Les versions actives et leurs builds changent dans le temps. |
| [Windows 11 Enterprise and Education lifecycle](https://learn.microsoft.com/en-us/lifecycle/products/windows-11-enterprise-and-education) | état consulté le 24 juillet 2026 | Les dates de fin de support diffèrent selon version et édition. |
| [MSFS 2024 SimConnect SDK](https://docs.flightsimulator.com/msfs2024/html/6_Programming_APIs/SimConnect/SimConnect_SDK.htm) | documentation SDK MSFS 2024 | Les clients hors processus peuvent être écrits en .NET ; la plateforme de build indiquée est x64 ; le hors-processus est recommandé pour la stabilité ; les clients SimConnect ne sont pas thread-safe. |
| [Upgrade SimConnect from MSFS 2020 to MSFS 2024](https://docs.flightsimulator.com/msfs2024/html/6_Programming_APIs/SimConnect/SimConnect_SDK.htm#upgrade-simconnect-from-msfs-2020-to-msfs-2024) | documentation SDK MSFS 2024 | Un module compilé avec le SDK 2020 peut rester reconnu comme module 2020, mais les structures et fonctionnalités 2024 comportent des différences. |
| [SimConnect INI Definition](https://docs.flightsimulator.com/msfs2024/html/6_Programming_APIs/SimConnect/SimConnect_INI_Definition.htm) | documentation SDK MSFS 2024 | Les chemins locaux diffèrent entre Microsoft Store et Steam ; ce mécanisme de diagnostic est hérité et déconseillé pour une dépendance produit. |
| [MSFS 2024 FAQ](https://www.flightsimulator.com/microsoft-flight-simulator-2024-faq/) | exigences PC officielles | MSFS 2024 requiert un environnement 64 bits, DirectX 12, une connexion réseau et au minimum 16 Go de RAM ; le profil recommandé du simulateur utilise 32 Go. |
| [MSFS 2024 on Steam](https://store.steampowered.com/app/2537590/Microsoft_Flight_Simulator_2024/) | fiche Steam consultée le 24 juillet 2026 | Steam publie les mêmes ordres de grandeur minimaux : processeur/OS 64 bits, 16 Go, DirectX 12, réseau haut débit et 50 Go pour MSFS. |
| [MSFS 2024 release notes — Sim Update 5.1](https://www.flightsimulator.com/category/releases/) | version stable 1.7.35.0, 29 juin 2026 | La version stable observée au moment de la décision est 1.7.35.0 ; elle n'est pas figée par l'ADR. |
| [MSFS Weekly Briefing — 16 juillet 2026](https://www.flightsimulator.com/july-16th-2026-msfs-weekly-briefing/) | SU6 bêta 1.8.8.0 | Les bêtas existent sur Store et Steam et évoluent séparément de la version publique ; elles sont exclues du support. |
| [WebView2 development best practices](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/developer-guide) | mise à jour 15 octobre 2025 | Microsoft recommande Evergreen pour la plupart des applications, la détection du runtime, la gestion de ses mises à jour et la récupération après défaillance de processus. |
| [Distribute WebView2 Runtime](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/distribution) | documentation consultée le 24 juillet 2026 | WebView2 Evergreen est inclus avec Windows 11, mais l'installateur doit vérifier sa présence ; le runtime s'actualise automatiquement. |
| [Tauri Windows Installer](https://v2.tauri.app/distribute/windows-installer/) | documentation consultée le 24 juillet 2026 | Tauri propose MSI/NSIS et installe par défaut WebView2 via bootstrapper s'il manque ; un runtime fixe alourdit et transfère la charge de maintenance. |
| [Latest supported Visual C++ Redistributable](https://learn.microsoft.com/en-us/cpp/windows/latest-supported-vc-redist) | famille v14, consultée le 24 juillet 2026 | Le redistribuable doit être au moins aussi récent que les outils MSVC employés et son architecture doit correspondre à l'application. |
| [.NET installation on Windows](https://learn.microsoft.com/en-us/dotnet/core/install/windows) | documentation consultée le 24 juillet 2026 | Une application .NET peut embarquer sa propre copie du runtime ; un runtime système global n'est donc pas une obligation produit. |

Inférences de conception, et non promesses Microsoft :

- limiter Thrustline à Windows 11 x64 réduit la matrice et permet de suivre le
  cycle de vie Windows réellement maintenu ;
- Store et Steam doivent être testés séparément même si SimConnect expose une API
  commune, car l'installation, les mises à jour et les données locales diffèrent ;
- le bridge doit être publié self-contained x64 afin de ne pas imposer un runtime
  .NET global ni des privilèges administrateur permanents ;
- Evergreen WebView2 est préférable au runtime fixe pour recevoir les correctifs
  de sécurité, avec vérification/réparation par l'installateur ;
- les exigences matérielles de MSFS ne prouvent pas les exigences propres à
  Thrustline ; ces dernières devront être mesurées sur le profil minimum.

## Support levels

- **Supported** : CI quand possible, test manuel réel sur la combinaison exacte,
  fiche de validation, documentation et prise en charge des incidents.
- **Compatible** : test réel concluant, sans garantie à chaque release.
- **Experimental** : compatibilité attendue mais preuve insuffisante. Ce niveau
  existe dans le vocabulaire du produit, mais Andy refuse son usage initial.
- **Unsupported** : volontairement exclu, incompatible, ou non validé alors que
  `Experimental` est interdit. Une plateforme non testée n'est jamais promue.

`Compatibility pending` est un état temporaire d'une ligne déjà `Supported`,
pas un cinquième niveau.

## Decision

### Windows

La cible officielle est Windows 11 x64, édition Home ou Pro, version publique
encore maintenue par Microsoft. Enterprise/Education peuvent être `Compatible`
après test, mais ne constituent pas le profil utilisateur principal.

| Windows | Édition/build | Architecture | Niveau initial | Preuve requise | Fréquence cible |
| --- | --- | --- | --- | --- | --- |
| Windows 11 | Home/Pro, version publique maintenue | x64 | Unsupported — validation requise | Fiche réelle sur la machine minimale et golden path | chaque release Thrustline + après feature update |
| Windows 11 | Enterprise/Education, version publique maintenue | x64 | Unsupported — validation requise | Test d'installation, WebView2 et golden path | release majeure |
| Windows 11 | Insider/Preview | x64 | Unsupported | Exclusion volontaire | aucune garantie |
| Windows 11 | toute édition | ARM64 | Unsupported | Exclusion volontaire | aucune |
| Windows 10 | toute édition | x64/ARM64 | Unsupported | Exclusion volontaire | aucune |
| Windows Server, Xbox console, Wine/Proton | toutes | toutes | Unsupported | Hors produit desktop Windows 11 | aucune |

Une version Windows quitte automatiquement la cible lorsqu'elle n'est plus
maintenue par Microsoft. Une ligne `Supported` passe alors `Compatibility
pending`, puis `Unsupported` à la prochaine release Thrustline sauf décision
documentée de transition.

### Microsoft Flight Simulator

| Simulateur | Canal | Version/build | Niveau initial | SimConnect testé | Dernier test |
| --- | --- | --- | --- | --- | --- |
| MSFS 2024 | Microsoft Store/Xbox App | stable publique courante | Unsupported — validation requise | Non dans T0004 | — |
| MSFS 2024 | Steam | stable publique courante | Unsupported — validation requise | Non dans T0004 | — |
| MSFS 2024 | Beta/Sim Update Preview | toute | Unsupported | Non requis | — |
| MSFS 2020 | Store ou Steam | toute | Unsupported | Non requis | — |
| MSFS sur Xbox/Cloud/PlayStation | tout | toute | Unsupported | SimConnect local desktop indisponible | — |

Les deux canaux MSFS 2024 sont des cibles de promotion vers `Supported`. Chacun
exige sa propre fiche. Si une seule installation réelle est disponible, l'autre
reste `Unsupported — validation requise`; une preuve sur un canal ne vaut pas
pour l'autre.

Le bridge ne dépend pas des fichiers privés de l'installation MSFS et n'exige
aucune modification du simulateur. Le compte ayant acheté/installé MSFS peut
différer du compte Windows courant uniquement si MSFS se lance normalement dans
la session courante et si SimConnect local fonctionne avec les permissions
standard. Thrustline ne contourne ni ACL, ni DRM, ni séparation de session.

### Hardware profiles

Les valeurs MSFS ci-dessous sont citées séparément des budgets Thrustline.

| Profil | CPU/architecture | RAM | Disque Thrustline | Windows | WebView2 | Réseau | Écran/DPI | MSFS |
| --- | --- | ---: | ---: | --- | --- | --- | --- | --- |
| Minimum supporté | x64, à mesurer ; cible provisoire 4 cœurs modernes | 16 Go provisoires | 2 Go provisoires hors données | Windows 11 Home/Pro maintenu | Evergreen présent/réparable | Internet requis pour fonctions cloud ; SimConnect reste local | 1280×720, 100–150 % à valider | MSFS 2024 doit satisfaire séparément ses exigences officielles |
| Recommandé | Ryzen 7 5800X ou équivalent x64 | 32 Go | 4 Go provisoires hors MSFS | Windows 11 Home/Pro maintenu | Evergreen à jour | haut débit stable | 1920×1080, 100–150 % | MSFS 2024 ; GPU selon exigences propres au simulateur |
| CI/test sans MSFS | x64, 4 vCPU | 8 Go | 10 Go pour sources, caches et artefacts | Windows 11 maintenu | présent pour E2E UI | Internet pour restauration/outils selon politique CI | écran virtuel 1920×1080, 100 % | absent ; replays déterministes obligatoires |

Le profil disponible d'Andy (Ryzen 7 5800X, 32 Go, RX 6070 XT confirmée par
Andy) est le profil recommandé de validation, pas la preuve du minimum.

### Runtime, installation and user data

- Application, bridge et installateur x64 uniquement.
- Bridge .NET publié self-contained ; aucun SDK .NET requis chez l'utilisateur.
- WebView2 Evergreen vérifié à l'installation et réparé par le mécanisme officiel
  si absent ; aucune désactivation de ses mises à jour.
- Redistribuable Visual C++ x64 inclus ou chaîné seulement si les binaires finaux
  l'exigent, dans une version compatible avec les outils de build.
- Installation par utilisateur privilégiée ; aucune exécution permanente en
  administrateur. Une élévation ponctuelle de l'installateur doit être justifiée.
- Exécutables dans le dossier d'installation ; configuration, caches, logs
  redigés, outbox et diagnostics dans les dossiers utilisateur Windows prévus à
  cet effet, jamais dans le dossier MSFS.
- Update signée, atomique et récupérable ; désinstallation sans suppression des
  données métier locales non synchronisées sans confirmation explicite.
- Aucun accès ou changement des fichiers MSFS sans consentement explicite.

## SimConnect validation protocol

Chaque scénario conserve une trace rejouable versionnée quand des événements
SimConnect sont reçus. Les logs autorisés contiennent versions, transitions,
codes d'erreur, compteurs et identifiants techniques aléatoires ; jamais JWT,
headers d'authentification, secret, nom réel, adresse courriel ou chemin utilisateur
complet. Les chemins sont redigés.

| # | État initial et action | Événements attendus | Dégradation et critère de réussite |
| ---: | --- | --- | --- |
| 1 | MSFS fermé ; lancer Thrustline | état `sim-unavailable`, tentatives bornées | UI utilisable pour la gestion, aucune boucle agressive ni crash ; trace d'absence conservée |
| 2 | Tester MSFS avant puis après Thrustline | `open`, version détectée, abonnement unique | connexion dans les deux ordres sans redémarrage obligatoire ; trace de handshake |
| 3 | Vol actif ; couper/relancer MSFS ou le bridge | perte détectée, backoff, reconnexion et resynchronisation | aucun double événement ni perte silencieuse ; reprise ou état actionnable |
| 4 | Menu, chargement, puis vol actif | états distincts menu/loading/active | aucune phase de vol créée au menu ; démarrage unique en vol |
| 5 | Cold-and-dark → taxi → décollage → croisière → atterrissage | transitions ordonnées et télémétrie bornée | rapport cohérent, une seule clôture candidate ; trace golden path |
| 6 | Go-around puis touch-and-go | atterrissage non final, remise de gaz, nouveau cycle | aucune clôture prématurée ; segments correctement distingués |
| 7 | Pause, active pause, accélération temporelle | événements/variables de pause et temps simulé séparé | aucun faux temps de vol réel ni consommation calculée silencieusement |
| 8 | Slew ou téléportation | anomalie/flow event détecté, segment marqué | économie non autorisée à partir du segment ambigu ; reprise explicitée |
| 9 | Retour menu puis changement d'appareil | fin de session, nouvel appareil et définitions réinitialisées | aucune donnée de l'ancien appareil ne contamine la nouvelle session |
| 10 | Crash ou fermeture forcée de MSFS | quit/perte de transport, vol local préservé | Thrustline reste stable ; reprise/revue possible sans clôture automatique |
| 11 | Couper Internet en gardant MSFS local | SimConnect reste connecté, cloud passe offline/pending | télémétrie locale continue ; outbox bornée et aucune perte silencieuse |
| 12 | Vol long représentatif, cible initiale 4 h | rythme stable, compteurs mémoire/CPU | absence de croissance mémoire non bornée et rapport final valide ; budget fixé par T0005 |
| 13 | Avion natif puis au moins un add-on représentatif | variables requises présentes ou capacités déclarées | avion natif passe ; add-on sans variable produit une limitation explicite, jamais une valeur inventée |
| 14 | Variable absente, invalide ou corrompue injectée/rejouée | validation rejette/isole la donnée | aucun crash, NaN ou transition autoritaire ; diagnostic redigé et état dégradé |

Pour chaque scénario : noter état initial, action exacte, version Windows,
version/canal MSFS, appareil, événements observés, comportement dégradé, résultat,
anomalies et chemin de la trace. Les scénarios 1–14 sont requis pour la première
promotion d'un canal vers `Supported`; un smoke subset 1–5, 9–11 et 14 est requis
après mise à jour.

## Evidence system

Les fiches futures résident dans `docs/validation/platforms/` et contiennent :

- version Thrustline et commit ;
- édition/version/build Windows et architecture ;
- version/build/canal MSFS ;
- version SimConnect/SDK utilisée par le bridge ;
- appareil natif ou add-on et version ;
- scénario, résultat, date et testeur ;
- anomalies liées et trace de replay ;
- signature ou checksum de l'artefact testé.

Une fiche n'est jamais précréée vide. `Supported` exige au moins une fiche valide
par combinaison et par release candidate. `Compatible` exige une fiche réelle
encore pertinente. Une déclaration orale ou une documentation fournisseur ne
remplace pas un test.

## Update and incident policy

1. Relever automatiquement quand possible les versions Thrustline, Windows,
   WebView2, bridge, MSFS et canal, sans lire de données personnelles.
2. Après une feature update Windows, Sim Update MSFS ou changement SimConnect,
   passer la ligne déjà `Supported` à `Compatibility pending`.
3. Ne prendre aucun engagement de délai ; publier l'état et les limitations dès
   qu'elles sont connues.
4. Exécuter d'abord le smoke subset, puis le golden path et les scénarios touchés.
5. Seul le mainteneur de release désigné, sur revue de la fiche de preuve, peut
   rétablir `Supported`.
6. Si le test échoue, conserver l'accès avec avertissement et désactiver seulement
   la fonction dangereuse. Ne jamais bloquer arbitrairement toute l'application.
7. Un kill switch signé et auditable est réservé à un risque avéré de corruption,
   de double clôture, de sécurité ou de perte de données. Il doit préserver
   lecture, export/récupération et diagnostic autant que possible.
8. Les builds Insider/Beta restent `Unsupported`, même si un test ponctuel passe.

Une mise à jour mensuelle Windows n'entraîne pas automatiquement
`Compatibility pending` sans signal de régression ; elle déclenche la CI et un
smoke test proportionné sur la prochaine release candidate.

## Consequences

### Positive

- Matrice réduite et testable autour du matériel et du simulateur réellement
  possédés.
- Aucun support déclaré sans preuve.
- Store et Steam sont traités comme deux risques de distribution distincts.
- Les mises à jour n'entraînent ni blocage arbitraire ni promesse de délai
  impossible à tenir.

### Negative

- Aucune combinaison n'est initialement `Supported`; des tests réels restent
  nécessaires.
- MSFS 2020, Windows 10 et ARM64 sont exclus même si une compatibilité technique
  partielle pourrait exister.
- Une seule machine ne prouve ni le minimum matériel ni la diversité Windows.
- Le refus de `Experimental` impose `Unsupported — validation requise` aux cibles
  encore non testées.

### Risks and mitigations

- **Un seul poste** : recruter un testeur ou une VM/hôte distinct par combinaison
  avant promotion ; conserver la preuve exacte.
- **Deux canaux non simultanément disponibles** : ne jamais transposer une preuve
  Store vers Steam ou inversement.
- **Mise à jour MSFS cassante** : `Compatibility pending`, smoke tests, limitation
  ciblée et communication sans délai promis.
- **Add-on atypique** : capacités explicites, variables validées et aucune donnée
  inventée.
- **Compte différent** : test standard dans la session courante ; aucun
  contournement des permissions ou de la licence.
- **GPU déclaré incertain** : corriger le modèle avant toute fiche matérielle.

## Validation and acceptance

Andy a accepté le 24 juillet 2026 :

1. le lancement avec avertissement hors matrice, sauf risque réel de corruption
   ou de sécurité ;
2. le modèle matériel déclaré `RX 6070 XT` ;
3. le statut initial `Unsupported — validation requise` des deux canaux, avec
   promotion vers `Supported` uniquement après preuve réelle.

La vérification manuelle de T0004 consiste à retrouver une combinaison, son
niveau, le scénario et la preuve nécessaires, puis à simuler une mise à jour
MSFS encore non validée.

## Follow-ups

1. Capturer les premières fiches Store et Steam sur la machine réelle.
2. Créer le moteur de replay et les tests .NET lors du premier vertical slice
   SimConnect.
3. Mesurer les profils minimum/recommandé dans T0005.
4. Choisir et tester l'installateur signé en phase 6.
5. Revoir cette ADR quand une nouvelle plateforme ou un nouveau simulateur est
   envisagé.
