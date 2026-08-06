# T0059 — Prouver le premier slice SimConnect réel et capturer son corpus

Status: Draft
Owner: Andy
Branch: `feature/T0059-real-simconnect-slice`
Phase: 3
Risk: High
Security-sensitive: Yes

## Goal

Obtenir depuis le bridge réellement publié self-contained une connexion à MSFS
2024 installé, puis capturer un corpus de traces réelles versionné, borné et
rejouable à l'identique sans MSFS.

## Context

`KI-009`, `KI-011` et `KI-015` sont ouverts pour la même raison physique : la
connexion réelle MSFS/SimConnect n'a jamais été exécutée. Ce ticket a été ouvert en
tenant le prérequis pour absent ; **ce n'est plus exact, et ce paragraphe le
corrige.**

### Constat du 5 août 2026 sur la machine de validation

Relevé par inspection du système de fichiers, en réponse à une question d'Andy. Les
deux prérequis matériels sont **installés** :

- **MSFS 2024**, canal **Microsoft Store / Xbox App** : paquet
  `Microsoft.Limitless_1.7.35.0_x64__8wekyb3d8bbwe` sous
  `C:\Program Files\WindowsApps`, contenant `FlightSimulator2024.exe` et
  `gamelaunchhelper.exe`; dossier de paquet
  `%LOCALAPPDATA%\Packages\Microsoft.Limitless_8wekyb3d8bbwe` et données
  utilisateur `%APPDATA%\Microsoft Flight Simulator 2024`. **Aucune installation
  Steam** trouvée dans les trois chemins de bibliothèque standards.
- **SDK SimConnect officiel, version `1.5.7`** d'après
  `C:\MSFS2024SDK\version.txt`, avec la structure attendue :
  `SimConnect SDK\include\SimConnect.h`, `lib\SimConnect.dll`, `lib\SimConnect.lib`,
  `lib\managed\Microsoft.FlightSimulator.SimConnect.dll`, `lib\static\` et
  `installer\SimConnect.msi`. Le chemin racine n'est pas un chemin d'installation par
  défaut, ce qui explique probablement pourquoi la documentation le croyait absent.

Trois constats de ce relevé changent le travail attendu plutôt que le débloquer :

1. **Une deuxième `SimConnect.dll` existe sur la machine**, apportée par un add-on
   tiers : `C:\BeyondATC\BeyondATC_Data\Plugins\x86_64\SimConnect.dll` et
   `C:\BeyondATC\BeyondATC_Data\StreamingAssets\SimConnect.dll`. L'exigence §2 —
   « la DLL réelle est résolue uniquement à l'exécution depuis l'installation du
   SDK » — devient donc un contrôle à prouver, pas une évidence : un chargement naïf
   qui trouverait la copie d'un add-on produirait une preuve fausse tout en
   paraissant réussir. La capture doit consigner le chemin réellement chargé.
2. **Un dossier de paquet `Microsoft.FlightSimulator_8wekyb3d8bbwe` est aussi
   présent**, c'est-à-dire la lignée MSFS 2020, `Unsupported` par `ADR-0003`. La
   capture doit prouver à quelle version elle s'est connectée, et non supposer que
   la seule session ouverte est celle de 2024.
3. La version de fichier de `lib\SimConnect.dll` n'est pas renseignée : son
   `VersionInfo` est vide. La version `1.5.7` provient du SDK, pas de la DLL ; c'est
   le SDK qu'il faut citer comme référence de version.

Le prérequis restant n'est donc plus l'installation mais la **provenance**, au sens
de l'exigence §1 de ce ticket : « une déclaration orale ne vaut pas provenance ».
Un relevé de chemins prouve la présence, pas l'origine.

`T0011` fournit par ailleurs déjà tout l'amont : `docs/CURRENT_STATE.md` classait la
connexion réelle MSFS/SimConnect comme contrôle non exécutable dans la baseline, ce
que le même changement corrige.

T0011 fournit `ISimConnectAdapter`, le domaine `FlightSample`, l'adaptateur natif
confiné et `SimConnectTraceReader` avec une trace synthétique de huit points. Il
compile contre les signatures natives documentées et charge `SimConnect.dll`
uniquement à l'exécution, précisément parce que le SDK est absent ; valider une
vraie session MSFS était un non-goal. Aucun enregistreur n'existe : le format
`thrustline.simconnect.trace` schéma `1` est aujourd'hui lu, jamais écrit.

`KI-009` et `KI-011` désignent comme ticket cible un « premier vertical slice
SimConnect » qui n'a jamais reçu de numéro. Ce ticket est ce slice. Il reste
strictement en amont de la détection déterministe des phases et de la reprise,
qui restent au niveau roadmap de la phase 3.

T0054 est fusionné dans `main` par la PR #99 et publie déjà la télémétrie bornée
sur le contrat local depuis le replay synthétique. Ce ticket ne modifie pas cette
diffusion : il fournit la source réelle que T0054 ne pouvait pas exiger.

## Dependencies

- T0009, T0010 et T0011 — processus publiable, contrat local et adaptateur,
  domaine, format de trace et replay ;
- T0014 et T0015 — layout de publication et budget de fondation de 128 Mio à ne
  pas dégrader ;
- T0054 — diffusion bornée déjà présente dans `main`, à ne pas rouvrir ;
- `ADR-0003` — protocole de scénarios, fiches de validation et matrice de
  support ; `ADR-0004` — SDK officiel confiné derrière l'abstraction interne ;
- prérequis physique : **satisfait quant à l'installation** au 5 août 2026 — MSFS
  2024 Store/Xbox `1.7.35.0` et SDK SimConnect `1.5.7` sont présents, voir le constat
  daté du `Context`. Il reste **non satisfait quant à la provenance** : l'exigence §1
  demande une provenance consignée de l'installation du SDK, et un relevé de chemins
  ne l'établit pas. Aucune trace synthétique ne contourne ce ticket ;
- `F0003` — localisation de la bibliothèque cliente SimConnect et dégradation
  explicite en son absence. **Prérequis découvert le 5 août 2026** : l'exigence §2 de
  ce ticket suppose une résolution qui n'existe pas encore, et sur une machine
  d'utilisateur final il n'y a de toute façon rien à résoudre, puisque personne
  n'installe un SDK de développement. Voir le constat dans cette exigence ;
- décision d'Andy, en attente, désormais réduite à deux points :
  1. **la provenance du SDK** — d'où il vient et quand il a été installé, sous une
     forme consignable et vérifiable, pas une déclaration orale ;
  2. **l'appareil natif** retenu pour la capture de référence.
  Le canal n'est plus une question ouverte : seul Microsoft Store / Xbox App est
  installé, aucune installation Steam n'existe sur cette machine, et `ADR-0003`
  laisse Steam `Unsupported` faute de fiche par canal.

## Allowed areas

- `apps/bridge/SimConnect/` pour l'enregistreur de traces et la provenance
  d'en-tête ;
- `apps/bridge/BridgeApplication.cs` uniquement pour le nouveau mode de capture
  borné et sa ligne d'usage ;
- `tests/bridge/` pour les scénarios d'enregistrement et de rejeu ;
- `tests/traces/` pour le corpus réel versionné et borné ;
- `tests/simconnect-corpus/` pour le gate de corpus et ses mutations négatives ;
- `scripts/capture-simconnect-trace.ps1` et son entrée `package.json` ;
- `.github/workflows/ci.yml` et `tests/ci/run.ps1` uniquement pour brancher le
  gate de corpus ;
- `docs/validation/platforms/` pour la fiche réellement produite ;
- `docs/tickets/T0011-adaptateur-simconnect-replay.md` pour sa preuve datée et
  son `Status` ;
- `docs/KNOWN_ISSUES.md`, `docs/CURRENT_STATE.md`, `docs/tickets/README.md`,
  `docs/QUALITY.md` si un gate est ajouté, et ce ticket ;
- `artifacts/` pour les captures brutes non versionnées.

## Do not touch

- redistribution du SDK, de `SimConnect.dll` ou de tout binaire de l'ancien
  build : ni copie, ni publication, ni commit ;
- lignes de la matrice `ADR-0003` et statuts de canaux : aucune promotion vers
  `Supported` n'est décidée ici ;
- contrat local v1, `BridgeHub`, REST et SignalR : la diffusion bornée livrée par
  T0054 reste inchangée ;
- frontend React, Tauri, capabilities, CSP, Supabase, économie, état de vol et
  rapport de vol ;
- packaging, signature, updater et budgets eux-mêmes ;
- statuts d'autres tickets et fichiers déjà portés par une PR ouverte ;
- lockfiles et ajout d'un package NuGet ou d'un wrapper communautaire.

## Requirements

### 1. Provenance de l'environnement

- Relever et consigner, avant toute capture : édition, version et build Windows,
  version et build MSFS 2024, canal réellement installé, version du SDK
  SimConnect, appareil utilisé et commit Thrustline exact.
- Consigner la provenance de l'installation du SDK. Une déclaration orale ne
  vaut pas provenance.
- Ne consigner aucun chemin utilisateur complet, identité, adresse courriel,
  jeton d'instance ni JWT ; les chemins sont redigés.

### 2. Publication self-contained réellement exercée

- Exécuter `bridge:publish`, puis lancer l'exécutable publié, jamais
  `dotnet run`, pour toutes les preuves de connexion et de capture.
- Prouver que la publication ne contient ni `SimConnect.dll`, ni assembly du
  SDK, ni binaire hérité, et que la DLL réelle est résolue uniquement à
  l'exécution depuis l'installation du SDK.
  **Cette exigence suppose une résolution qui n'existe pas, constat du 5 août
  2026.** `NativeSimConnectAdapter` charge `SimConnect.dll` par
  `NativeLibrary.TryLoad(..., DllImportSearchPath.SafeDirectories)`, dont les
  répertoires sont celui de l'application, `System32` et ceux ajoutés
  explicitement — ni le `PATH`, ni un chemin d'installation du SDK. Or sur la
  machine de validation, `System32`, `SysWOW64` et `WinSxS` ne contiennent aucun
  `SimConnect.dll`, le SDK garde la sienne dans `C:\MSFS2024SDK\SimConnect SDK\lib`
  et le paquet MSFS 2024 n'expose qu'un `SimConnect_internal.dll` sous
  `WindowsApps`, protégé par ACL et de nom différent. Le chargement échouerait donc
  **même avec les deux prérequis installés**. La localisation est portée par la
  fonctionnalité `F0003`, dont la fusion devient un prérequis de ce ticket : sans
  elle, il n'y a pas de résolution à prouver.
- Consigner explicitement si l'assembly managé officiel a été nécessaire ou si
  le chemin natif de T0011 suffit sur .NET 10 self-contained. Ce constat est la
  preuve attendue par `KI-015`.
- Relever nombre de fichiers et octets de la publication, les comparer à la
  mesure T0015 de 334 fichiers et 110 477 582 octets, et vérifier que le budget
  de fondation de 128 Mio reste respecté.

### 3. Enregistreur de traces borné

- Ajouter un enregistreur qui écrit le format `thrustline.simconnect.trace`
  schéma `1` déjà lu par `SimConnectTraceReader`, sans modifier ce schéma ni
  casser la trace synthétique existante.
- Écrire un en-tête obligatoire portant la provenance du point 1, des offsets
  monotones et un séquencement strict.
- Borner la capture : durée maximale explicite, taille maximale de fichier,
  cadence d'une lecture par seconde héritée de T0011, et arrêt propre du handle
  même après annulation, déconnexion ou erreur.
- Ajouter un mode de capture au CLI du bridge sans casser le contrat existant :
  `--health-check` inchangé, arguments inconnus toujours refusés, ligne d'usage
  mise à jour.
- L'enregistreur n'ouvre aucun port, n'écrit aucun réseau et ne touche ni
  économie ni état de vol.

### 4. Corpus réel versionné

- Capturer au moins une trace réelle couvrant sol, décollage, montée, croisière,
  descente et retour au sol sur l'appareil natif retenu.
- Séparer explicitement le réel du synthétique dans `tests/traces/`, sans
  déplacer ni réécrire `synthetic-golden-flight.jsonl`.
- Borner le corpus versionné par une limite déclarée et vérifiée par fichier et
  au total ; conserver les captures brutes complètes dans `artifacts/`, non
  versionnées.
- Aucune donnée personnelle, aucun chemin utilisateur et aucun identifiant réel
  dans le corpus versionné.

### 5. Rejeu déterministe sans MSFS

- Le corpus réel doit se rejouer par le replay T0011, MSFS fermé, avec un
  résultat identique à chaque exécution.
- `bridge:test` couvre le synthétique et le réel ; l'écriture puis la relecture
  d'une trace forment un aller-retour testé.
- Ajouter un gate `tests/simconnect-corpus/` qui valide sans MSFS l'en-tête, la
  provenance obligatoire, la monotonie, les bornes et l'absence de motif
  sensible, échoue fermé, et est prouvé par des mutations négatives selon
  l'habitude des gates existants.
- Brancher ce gate dans le harnais CI et le job Windows.

### 6. Sous-ensemble `ADR-0003` réellement exécutable

- Exécuter et consigner les seuls scénarios que les capacités actuelles rendent
  observables : 1 MSFS fermé, 2 ordre de lancement et handshake, 13 limité à
  l'appareil natif, 14 variable absente, invalide ou corrompue par rejeu.
- Consigner pour chacun état initial, action exacte, événements observés,
  comportement dégradé, résultat, anomalies et chemin de trace redigé.
- Déclarer explicitement non exécutés les scénarios 3 à 12 : ils dépendent de la
  détection des phases, de la reconnexion, de l'outbox, du vol long et des
  add-ons, tous absents. Ne jamais présenter un scénario non exécuté comme
  réussi.

### 7. Fiche de validation sans promotion

- Créer `docs/validation/platforms/` et y déposer une fiche réelle pour le seul
  canal installé, avec tous les champs exigés par `ADR-0003` : version et commit
  Thrustline, Windows, MSFS et canal, version SDK, appareil, scénario, résultat,
  date, testeur, anomalies, trace de rejeu et empreinte de l'artefact testé.
- Ne pas précréer de fiche vide pour l'autre canal.
- Laisser les deux lignes MSFS 2024 en `Unsupported — validation requise` : les
  scénarios 1 à 14 ne sont pas complets et une preuve sur un canal ne vaut pas
  pour l'autre. Ce ticket ne promeut rien.

### 8. Registre, statuts et état

- Porter `KI-009` à `Resolved` avec la preuve du corpus réel rejouable, ou le
  laisser ouvert avec la raison exacte.
- Porter `KI-015` à `Resolved` avec le constat du point 2, ou le reclasser avec
  un motif précis et une condition de sortie si l'assembly managé bloque la
  publication self-contained.
- Laisser `KI-011` ouvert et mettre à jour sa preuve : canal réellement exercé,
  canal manquant, machine unique.
- Porter T0011 à `Done` seulement si sa checklist réelle est satisfaite et
  confirmée par Andy ; sinon le laisser `Verify` en nommant la condition
  restante.
- Mettre à jour `docs/CURRENT_STATE.md` pour la seule réalité qui change, dont
  la ligne « connexion réelle à MSFS/SimConnect : MSFS absent ».
- Aligner statuts de tickets et index dans le même changement et consigner toute
  découverte hors périmètre dans `KNOWN_ISSUES.md` au lieu de la corriger.

## Non-goals

- détection déterministe des phases de vol, reconnexion, backoff,
  resynchronisation et outbox de reprise ;
- pause, active pause, accélération temporelle, slew, go-around, touch-and-go et
  crash, soit les scénarios 3 à 12 ;
- vol long de quatre heures, profil matériel minimum et relèvement d'un budget ;
- add-ons tiers et couverture d'appareils au-delà du natif retenu ;
- validation du second canal MSFS et promotion vers `Supported` ;
- modification du contrat de diffusion livré par T0054 ;
- rapport de vol, économie, clôture, SimBrief et transitions métier ;
- packaging signé, updater, provenance et rollback ;
- redistribution du SDK ou d'une DLL SimConnect.

## Acceptance criteria

- [ ] MSFS 2024 et le SDK sont installés avec provenance consignée, ou le ticket
      est `Blocked` avec ce motif et sans preuve substituée.
      **Installation constatée le 5 août 2026** — MSFS 2024 Store/Xbox `1.7.35.0`,
      SDK SimConnect `1.5.7` — voir le constat daté du `Context`. La moitié
      « provenance consignée » reste ouverte, donc ce critère n'est pas coché.
- [ ] La `SimConnect.dll` réellement chargée à l'exécution est celle de
      l'installation du SDK ou du simulateur, et son chemin est consigné redigé.
      Une copie apportée par un add-on tiers existe sur la machine de validation :
      une preuve qui ne relève pas le chemin chargé ne vaut rien.
- [ ] La session à laquelle la capture s'est connectée est prouvée être MSFS 2024,
      la lignée MSFS 2020 étant aussi présente sur la machine et `Unsupported` par
      `ADR-0003`.
- [ ] Le bridge publié self-contained se connecte réellement à MSFS 2024 et la
      publication ne contient aucun binaire SimConnect.
- [ ] Le constat de publication du point 2 est consigné et tranche `KI-015`.
- [ ] Au moins une trace réelle couvre sol → décollage → montée → croisière →
      descente → sol, avec en-tête de provenance complet et bornes respectées.
- [ ] Le corpus réel se rejoue à l'identique MSFS fermé et l'aller-retour
      écriture/relecture est testé.
- [ ] Le gate de corpus échoue fermé, passe avec ses mutations négatives et est
      branché dans le harnais CI et le job Windows.
- [ ] Les scénarios 1, 2, 13 natif et 14 sont exécutés et consignés ; 3 à 12 sont
      déclarés non exécutés.
- [ ] Une fiche réelle existe pour le seul canal installé et aucune ligne de la
      matrice `ADR-0003` ne change.
- [ ] `KI-009`, `KI-011`, `KI-015` et le statut de T0011 reflètent exactement la
      preuve obtenue, index inclus.
- [ ] La publication respecte le budget de fondation et aucun budget n'est
      relevé.
- [ ] `pnpm maintenance:check`, `pnpm authority:check` et `git diff --check`
      passent.
- [ ] Aucun chemin utilisateur, secret, jeton ni donnée personnelle n'apparaît
      dans le code, le corpus, la fiche ou les journaux.

## Security review

- actifs/données : télémétrie de simulateur, provenance d'environnement, corpus
  versionné et emplacement d'installation du SDK ;
- frontière : interopérabilité native confinée dans l'adaptateur et boucle de
  messages dédiée ; aucun port, aucun réseau et aucune écriture serveur ajoutés ;
- abus : trace forgée ou altérée rejouée comme réelle, corpus utilisé pour
  exfiltrer un chemin local, capture non bornée saturant le disque, appel de
  l'API SimConnect depuis plusieurs threads ;
- validation/autorisation : en-tête et provenance obligatoires, rejet fermé de
  toute trace invalide sans recopier son contenu, bornes de durée et de taille
  appliquées à l'écriture comme à la lecture ;
- atomicité/idempotence : le rejeu d'une même trace est déterministe ; une
  capture interrompue ne laisse pas de fichier partiel présenté comme complet ;
  le handle est fermé sur toutes les sorties ;
- logs/vie privée : chemins redigés, aucun identifiant réel, aucun jeton
  d'instance et aucune donnée personnelle dans les traces, la fiche ou les
  artefacts.

## Maintenance review

- problèmes applicables : `KI-009` corpus réel absent, `KI-015` publication
  self-contained du SDK non prouvée, `KI-011` canaux MSFS non validés, `KI-012`
  profil matériel minimum non mesuré, `KI-008` comportements non caractérisés ;
- dette créée ou aggravée : un mode CLI de capture et un corpus versionné à
  maintenir ; le second canal MSFS et les scénarios 3 à 12 restent ouverts après
  ce ticket ;
- règle de sécurité ajoutée ou à revalider : une trace n'est admise que si son
  en-tête de provenance est complet et vérifié ; un SDK installé n'autorise
  jamais sa redistribution ;
- contrôle manuel à automatiser : la validation du corpus devient un gate ; la
  capture elle-même reste manuelle car elle exige MSFS ;
- risque résiduel ou exception approuvée : `KI-011` reste ouvert avec une seule
  machine et un seul canal ; aucune promotion de support n'est accordée.

## Automated validation

```powershell
pnpm.cmd bridge:build
pnpm.cmd bridge:test
pnpm.cmd bridge:publish
pnpm.cmd bridge:health
pnpm.cmd simconnect:corpus:check
pnpm.cmd performance:measure:bridge
pnpm.cmd performance:check:build
pnpm.cmd ci:check
pnpm.cmd authority:check
pnpm.cmd maintenance:check
git diff --check
```

## Manual verification

1. Consigner la provenance : Windows, MSFS 2024, canal, SDK, appareil et commit.
2. MSFS fermé, lancer l'exécutable publié et confirmer le scénario 1 : état
   indisponible, tentatives bornées, aucune boucle agressive ni crash.
3. Démarrer MSFS, confirmer le scénario 2 dans les deux ordres de lancement,
   avec version détectée et abonnement unique.
4. Capturer la trace de référence sur l'appareil natif, du sol au retour au sol,
   puis vérifier les bornes de durée et de taille.
5. Fermer MSFS, rejouer deux fois la trace capturée et confirmer un résultat
   identique.
6. Tester l'erreur : rejouer une trace tronquée, une trace sans en-tête et une
   variable corrompue ; confirmer un refus fermé, redigé, sans crash, NaN ni
   transition autoritaire.
7. Confirmer que la publication ne contient aucun binaire SimConnect et
   qu'aucun chemin utilisateur n'apparaît dans les preuves.
8. Remplir la fiche du canal installé sans modifier la matrice de support.

Temps cible : 45–60 minutes, dominées par la session de vol réelle.

## Rollback

Le ticket n'écrit aucune donnée serveur, ne migre rien et n'installe rien de
persistant. Abandonner consiste à supprimer la branche, l'enregistreur, le gate,
le corpus versionné et la fiche, puis à laisser `KI-009`, `KI-011` et `KI-015`
ouverts et T0011 en `Verify`. Les captures brutes d'`artifacts/` sont détruites.
Aucune ligne de la matrice `ADR-0003` n'a été promue, donc aucun engagement de
support n'est à retirer.

## Completion Report

À remplir après implémentation.

### Summary

### Files changed

### Commands and results

### Manual verification result

### Risks and limitations

### Follow-ups

### Documentation updated
