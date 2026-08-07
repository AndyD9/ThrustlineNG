# F0003 — Trouver SimConnect nous-mêmes, ou le dire proprement

Status: In progress
Owner: Agent (session du 7 août 2026)
Branch: `feature/f0003-trouver-simconnect-ou-degrader-proprement`
Avancement: J1 `Done` le 7 août 2026 ; J2 `Done` le 7 août 2026 sur son
périmètre restant — sa moitié bridge (champs de santé additifs) est livrée avec
J1, sa moitié desktop est **portée dans F0007** sur décision d'Andy du 7 août
2026 (voir la note du jalon J2) ; J3 `Draft`, inchangé, en attente de la
décision de fourniture de la DLL et de la lecture de l'EULA.
Phase: 3
Risk: Medium
Security-sensitive: Yes
Autonomous: No

## Goal

L'application trouve elle-même la bibliothèque cliente SimConnect quand la machine
en possède une digne de confiance, et quand elle n'en possède aucune elle le dit
clairement au lieu d'échouer sans explication — sans jamais charger une bibliothèque
d'origine inconnue.

## Context

Constat du 5 août 2026 sur la machine de validation, en réponse à une question
d'Andy : « il faut qu'on le trouve nous-même, dans l'hypothèse où la personne n'a
rien de tout ça ».

`NativeSimConnectAdapter` charge la bibliothèque par
`NativeLibrary.TryLoad("SimConnect.dll", assembly, DllImportSearchPath.SafeDirectories)`
(`apps/bridge/SimConnect/NativeSimConnectAdapter.cs:157`). `SafeDirectories` couvre
le répertoire de l'application, `System32` et les répertoires ajoutés explicitement —
ni le `PATH`, ni un chemin d'installation du SDK. Or :

- `System32`, `SysWOW64` et `WinSxS` ne contiennent **aucun** `SimConnect.dll` ;
- le SDK, installé en version `1.5.7`, garde la sienne dans
  `C:\MSFS2024SDK\SimConnect SDK\lib`, hors de tout répertoire cherché ;
- le paquet MSFS 2024 Store n'expose qu'un `SimConnect_internal.dll` sous
  `C:\Program Files\WindowsApps`, de nom différent et protégé par ACL. Ce n'est pas
  la bibliothèque cliente ;
- une copie tierce existe pourtant bien sur cette machine, apportée par un add-on :
  `C:\BeyondATC\BeyondATC_Data\Plugins\x86_64\SimConnect.dll`.

Deux conséquences, et la seconde est la vraie raison de cette fonctionnalité.

**Le chargement échouerait même ici**, avec MSFS 2024 et le SDK installés : la DLL
existe sur le disque, dans un répertoire que le chargeur ne regarde jamais. T0059 ne
peut donc pas prouver son exigence §2 avant cette fonctionnalité.

**Et une machine d'utilisateur final n'a rien à trouver.** Personne n'installe un SDK
de développement pour jouer. La découverte est donc nécessaire mais insuffisante : sur
une machine avec MSFS et sans SDK, il n'existe aucune bibliothèque cliente à
découvrir. C'est ce que J3 tranche, et c'est la décision d'Andy ci-dessous.

Le comportement dégradé n'est pas une invention de cette fonctionnalité : `ADR-0003`
exige déjà le scénario 14 — « variable absente, invalide ou corrompue » — avec
« aucun crash, NaN ou transition autoritaire ; diagnostic redigé et état dégradé », et
`docs/SUPPORT.md` demande que la lecture et la récupération des données restent
disponibles autant que possible. Une bibliothèque introuvable est le même cas, un
cran plus tôt.

## Décision attendue d'Andy — J3 seulement

J1 et J2 sont exécutables sans elle. **J3 ne l'est pas.**

**Comment une machine sans SDK obtient-elle la bibliothèque cliente ?**

- **A — Thrustline la livre avec l'application.** C'est ce que fait à peu près tout
  add-on, BeyondATC compris. Le chargeur actuel la trouverait sans aucune découverte,
  le répertoire de l'application étant déjà dans `SafeDirectories`. Coût : c'est
  aujourd'hui **interdit** par le `Do not touch` de T0059 — « redistribution du SDK,
  de `SimConnect.dll` ou de tout binaire : ni copie, ni publication, ni commit » — et
  par la règle d'`AGENTS.md` contre l'import implicite de binaires. Cette interdiction
  a été écrite pour empêcher de récupérer des binaires de l'ancien dépôt, pas pour
  trancher une redistribution officielle ; c'est à toi de dire si elle s'applique ici.
- **B — l'installateur exécute le redistribuable `SimConnect.msi`** du SDK, qui existe
  précisément pour ça (`C:\MSFS2024SDK\SimConnect SDK\installer\SimConnect.msi`).
  Coût : l'installateur transporte quand même le `.msi`, donc la même question de
  licence ; il faut une étape élevée ; et l'état devient partagé avec toute la machine
  au lieu de rester dans le dossier de l'application.
- **C — ne rien fournir.** L'application reste pleinement utilisable, mais la
  télémétrie live n'existe que pour qui a installé le SDK. Coût : la capacité centrale
  du produit ne marche pour presque aucun utilisateur.

**Ce que je ne peux pas trancher, et toi non plus sans le lire** : l'EULA du SDK se
trouve dans `C:\MSFS2024SDK\Licenses\MSFS SDK EULA.pdf` (164 Ko, 8 janvier 2025).
Aucun extracteur PDF n'est disponible sur cette machine — ni poppler, ni Word, ni
Python — donc ses termes de redistribution ne sont **pas** consignés ici, et ne
doivent pas être devinés. C'est la première pièce à lire : elle détermine si A ou B
est même permis. Tant qu'elle n'est pas lue et citée, J3 reste `Draft`.

Condition de sortie de J3 : les termes de redistribution cités depuis l'EULA, puis
l'option retenue, reportées datées dans cette section.

## Dependencies

- T0011 — `ISimConnectAdapter`, l'adaptateur natif et son chargement actuel
  (`Verify`, présent dans `main`) ;
- T0054 — diffusion bornée de la télémétrie et champs `telemetrySource` /
  `telemetryState` du health check, déjà dans `main`, à étendre sans rouvrir ;
- `ADR-0003` scénario 14 et `docs/SUPPORT.md` pour la forme du comportement dégradé ;
- `ADR-0004` — le SDK officiel reste derrière l'abstraction interne ;
- pour J3 seulement : la décision d'Andy ci-dessus, et la lecture de l'EULA.

## Allowed areas

- `apps/bridge/SimConnect/` — sonde de localisation et chargement ;
- `apps/bridge/BridgeHealth.cs` et `apps/bridge/BridgeOptions.cs` — état et option de
  chemin explicite ;
- `tests/bridge/` — scénarios de localisation, de refus et de dégradation ;
- ~~`apps/desktop/src/` — restitution de l'état indisponible, en J2 seulement~~ —
  **retiré le 7 août 2026** : la restitution desktop est portée dans F0007, qui
  possède déjà le superviseur et le gate du shell dont elle dépend ;
- `docs/SECURITY.md`, `docs/ARCHITECTURE.md`, `docs/QUALITY.md`, `docs/SUPPORT.md`,
  `docs/CURRENT_STATE.md`, `docs/KNOWN_ISSUES.md` ;
- ce fichier et `docs/features/README.md` ;
- pour J3 uniquement et selon l'option retenue : le layout de publication et
  l'installateur.

## Do not touch

- le contrat local v1, `BridgeHub`, REST et SignalR : la diffusion T0054 reste
  inchangée, seuls des champs additifs sont permis ;
- le format de trace `thrustline.simconnect.trace` et le replay T0011 ;
- la matrice `ADR-0003` : aucune promotion de canal ici ;
- **aucun binaire committé**, quelle que soit l'option retenue en J3 : une
  redistribution éventuelle passe par le layout de publication, jamais par le dépôt ;
- les budgets T0015, à ne pas dégrader.

## Non-goals

- capturer un corpus réel, prouver une session MSFS, détecter les phases : T0059 et la
  suite du flux moteur de vol ;
- relier la télémétrie au cycle de vol ou à un rapport de clôture : F0002 et la suite ;
- promouvoir un canal vers `Supported`.

## Jalons

### J1 — La bibliothèque est localisée par une sonde bornée, ou déclarée absente

Status: Done
Risk: Medium
Security-sensitive: Yes
Autonomous: No

- résultat : le bridge cherche la bibliothèque cliente dans une **liste ordonnée et
  fermée** de sources dignes de confiance, dans cet ordre : un chemin explicite passé
  en ligne de commande, le répertoire de l'application, puis l'installation du SDK
  telle que déclarée par le système. Aucune recherche par `PATH`, par répertoire
  courant, ni par balayage du disque. Une copie trouvée ailleurs — celle d'un add-on
  tiers, par exemple — n'est **jamais** chargée implicitement. Quand rien n'est
  trouvé, le processus ne plante pas : il reste démarré, la source native rend un
  état `unavailable` distinct de `idle`, et le diagnostic dit quoi installer sans
  divulguer de chemin utilisateur complet.
- frontière : chargement de bibliothèque native dans le bridge.
- validations : `pnpm bridge:build`, `pnpm bridge:test` avec les scénarios de
  localisation, de refus d'une source non listée et de dégradation sans MSFS,
  `pnpm bridge:health`, `pnpm performance:check:build`.
- revue : **c'est un vecteur de détournement de DLL.** Chercher tout chemin par
  lequel une bibliothèque non listée pourrait être chargée : répertoire courant,
  `PATH`, variable d'environnement non validée, chemin relatif, lien symbolique,
  chemin fourni par la WebView. Le chemin explicite en ligne de commande doit être
  validé comme un fichier réel et absolu, et ne doit pas venir d'un client non fiable.
  Vérifier aussi qu'aucun message ne divulgue un chemin utilisateur complet.

### J2 — L'état indisponible est visible et actionnable

Status: Done

**Décision d'Andy du 7 août 2026 — la moitié desktop est portée dans F0007.**
La moitié bridge de ce jalon est livrée avec J1 : le health check versionné
expose `nativeLibrary` et `nativeLibraryOrigin` en champs additifs, sans chemin
ni version de SDK. La moitié desktop était **inexécutable dans les `Allowed
areas` de cette unité** : la WebView n'a aucun accès au health check du bridge
(le superviseur ne le consomme pas), la seule surface IPC est `flight_summary`
dont le vocabulaire d'états est fermé des deux côtés, et l'étendre relève de
`apps/desktop/src-tauri/` et du gate `tests/desktop-shell/run.ps1` — tous deux
hors des zones autorisées ici.

Andy a tranché : ce câblage va dans **F0007**, plutôt que d'étendre l'unité.
Raisons consignées : F0007 porte déjà `apps/desktop/src-tauri/src/bridge.rs`,
le superviseur, `tests/desktop-shell/run.ps1` et `apps/desktop/src/test/` dans
ses `Allowed areas`, et sa décision 2 pose exactement la même question — qui
parle au bridge, le superviseur ou la WebView ; étendre F0003 dupliquerait ce
travail IPC et l'évolution du gate du shell sur les mêmes fichiers, avec
conflit probable ; et l'affichage n'est de toute façon pas vérifiable tant que
l'application assemblée ne sélectionne aucune source de télémétrie, ce qui est
précisément l'objet de F0007. Rien n'est affiché de trompeur en attendant :
l'application assemblée n'utilise jamais la source `native`.

Ce jalon est donc `Done` sur son périmètre restant, et F0007 gagne le critère
d'acceptation correspondant.
Risk: Low
Security-sensitive: No
Autonomous: Yes

- résultat : le health check versionné expose l'état de localisation en champs
  additifs, sans divulguer chemin, version de SDK ni jeton. L'affichage desktop
  « télémétrie indisponible » et la vérification que compagnie, catalogue, achat,
  dispatch et flotte restent utilisables sans télémétrie — conformément à
  `docs/SUPPORT.md` — sont **portés dans F0007** (décision du 7 août 2026).
- frontière : health check du bridge.
- validations : `pnpm bridge:test`, `pnpm bridge:health`. Les gates frontend de la
  moitié desktop partent avec elle dans F0007.
- revue : vérifier qu'aucun état dégradé ne se présente comme une réussite, et qu'un
  kill switch n'est pas introduit là où `SUPPORT.md` l'interdit.

### J3 — Une machine sans SDK obtient sa bibliothèque cliente

Status: Draft
Risk: High
Security-sensitive: Yes
Autonomous: No

- résultat : dépend entièrement de la décision d'Andy ci-dessus, et **ne doit pas
  être commencé avant qu'elle soit reportée datée**, EULA citée. Quelle que soit
  l'option, l'invariant tient : aucun binaire n'entre dans le dépôt, l'origine de la
  bibliothèque chargée est consignée, et une bibliothèque d'origine inconnue n'est
  jamais chargée.
- frontière : layout de publication ou installateur.
- validations : à définir avec l'option ; au minimum les gates de packaging et le
  budget de fondation de 128 Mio.
- revue : provenance de la bibliothèque livrée, licence citée, et absence de
  dégradation du budget comme de la surface d'attaque.

## Acceptance criteria

- [x] Sur une machine avec le SDK installé hors chemin par défaut, le bridge trouve
      la bibliothèque et s'y connecte — ce qui est impossible aujourd'hui. — J1,
      7 août 2026 : `located/sdk` sur la machine de validation via la
      déclaration `MSFS_SDK`, et le chargement réel (exports résolus) est
      prouvé par le harnais sur la DLL du SDK ; la session MSFS réelle reste
      T0059.
- [x] Sur une machine sans MSFS et sans SDK, le bridge démarre, reste sain, rend un
      état `unavailable` explicite et un diagnostic actionnable, et ne plante pas.
      — J1 : prouvé au harnais et sur le bridge publié (processus sans
      déclaration SDK).
- [x] Une copie de la bibliothèque présente ailleurs que dans les sources listées
      n'est jamais chargée implicitement, et ce refus est prouvé par un test.
      — J1 : test « a library outside the closed list is never located »
      (copie exposée par `PATH` et répertoire courant), rejoué en manuel sur le
      bridge publié.
- [x] Aucune recherche par `PATH`, répertoire courant ou balayage de disque n'existe
      dans le code livré. — J1 : `DllImportSearchPath.SafeDirectories` retiré,
      chargement par chemin absolu seul.
- [x] Aucun message, journal ou champ de health check ne divulgue un chemin
      utilisateur complet, une version de SDK ou un jeton. — J1 : assertions
      dédiées du harnais sur la santé et le diagnostic.
- [x] `docs/SUPPORT.md` et `docs/SECURITY.md` décrivent la sonde, son ordre et son
      refus. — J1. **Décision d'Andy du 7 août 2026 : le volet « scénario 14
      d'`ADR-0003` » est retiré de ce critère.** Trois raisons consignées :
      `docs/decisions/` est hors des `Allowed areas` de cette unité ; le README
      des ADR pose qu'une ADR acceptée ne se réécrit pas, seule une ADR nouvelle
      la remplace ; et une bibliothèque absente n'est pas le cas « variable
      absente, invalide ou corrompue » du scénario 14 — c'est un cran plus tôt,
      au niveau du prérequis, pas de la donnée. Les scénarios 1–14 étant la barre
      de promotion d'un canal vers `Supported`, y toucher ici contredirait le
      `Do not touch` de cette unité. Suivi en `Follow-ups`.
- [x] J3 n'est pas commencé sans la décision d'Andy et les termes de l'EULA cités.
      — Respecté : J3 est intact, aucun binaire n'entre dans le dépôt.

**Critère porté hors de cette unité, décision d'Andy du 7 août 2026 :** « les
capacités déjà livrées restent utilisables sans télémétrie » quitte cette liste
pour celle de **F0007**, avec la moitié desktop de J2. Sa vérification exige une
application assemblée qui sélectionne une source de télémétrie — ce qu'aucune
version de l'alpha ne fait aujourd'hui, et ce que F0007 livre. Cette unité ne
gate donc plus dessus.

## Security review

Jalons concernés : **J1** et **J3**.

- actifs/données : intégrité du processus bridge, chemins locaux, provenance d'une
  bibliothèque native exécutée dans le processus ;
- frontière : chargement d'un binaire natif, c'est-à-dire exécution de code ;
- abus : **détournement de DLL** — déposer une `SimConnect.dll` dans un répertoire
  cherché, ou faire passer un chemin arbitraire par une option, une variable
  d'environnement ou la WebView, pour faire exécuter du code dans le bridge ; faire
  divulguer un chemin utilisateur par un message d'erreur ;
- validation/autorisation : liste ordonnée et fermée de sources, chemin explicite
  validé comme fichier absolu réel et jamais accepté d'un client non fiable, aucune
  recherche par `PATH` ni par répertoire courant ;
- atomicité/idempotence : sans objet ; le chargement est une opération locale sans
  état persistant ;
- logs/vie privée : chemins redigés, aucune version de SDK ni jeton exposés.

## Maintenance review

- dettes et problèmes connus applicables : `KI-009`, `KI-011` et `KI-015` restent
  ouverts et ne sont pas fermés par cette fonctionnalité ; elle en retire seulement
  l'obstacle mécanique. Une entrée `KNOWN_ISSUES` doit consigner que le chargement
  actuel ne peut réussir sur aucune machine où le SDK n'est pas dans un répertoire
  cherché ;
- dette créée ou aggravée : une liste de sources est une liste à tenir à jour quand
  MSFS ou le SDK changent d'emplacement. Consignée en `KI-032`, **acceptée par Andy
  le 7 août 2026** (statut `Accepted`) avec sa condition de revalidation : rejouer
  la vérification manuelle J1 à chaque mise à jour majeure du SDK MSFS ou changement
  de canal MSFS. L'alternative — découverte élargie ou lecture de registre —
  rouvrirait le vecteur de détournement de DLL que J1 ferme, et n'est donc pas
  ouverte en échange ;
- règle de sécurité ajoutée : l'ordre de localisation et le refus d'une source non
  listée deviennent une règle de `docs/SECURITY.md` ;
- contrôle manuel à automatiser : la dégradation sans MSFS doit être un test, pas une
  vérification manuelle, puisqu'elle est reproductible sans simulateur ;
- risque résiduel : sur une machine sans aucune bibliothèque cliente, la télémétrie
  reste indisponible jusqu'à J3. C'est un état honnête, pas une panne.

## Automated validation

```powershell
pnpm bridge:build
pnpm bridge:test
pnpm bridge:health
pnpm performance:check:build
pnpm frontend:typecheck
pnpm frontend:test
pnpm frontend:coverage
pnpm frontend:build
pnpm authority:check
pnpm maintenance:check
```

## Manual verification

1. J1 : lancer le bridge publié sur cette machine, SDK présent hors chemin par
   défaut, et confirmer que la bibliothèque est trouvée et le chemin consigné redigé ;
   puis renommer temporairement le répertoire du SDK et confirmer l'état
   `unavailable`, le processus toujours sain et le diagnostic actionnable.
2. J1 : déposer une `SimConnect.dll` factice dans un répertoire non listé et
   confirmer qu'elle **n'est pas** chargée.
3. ~~J2 : dans l'application, confirmer l'état « télémétrie indisponible » et que
   compagnie, catalogue, achat, dispatch et flotte restent utilisables.~~ —
   **portée dans F0007** le 7 août 2026 avec la moitié desktop de J2.
4. J3 : selon l'option retenue.

## Rollback

Avant fusion, abandonner la branche. Après fusion de J1 et J2, revenir au chargement
actuel rétablirait un échec sans explication : le rollback utile est de corriger la
sonde, pas de la retirer. J3 est rétractable indépendamment, en retirant la
bibliothèque du layout de publication ou l'étape d'installation.

## Completion Report

Un bloc par jalon, rempli au moment de son commit, puis une synthèse.

### J1

- résultat obtenu : la bibliothèque cliente est localisée par
  `SimConnectLibraryLocator`, une sonde à liste ordonnée et fermée — chemin
  explicite `--simconnect-library` (absolu, borné, nommant exactement
  `SimConnect.dll`, fichier réel sans point de réanalyse, fourni-mais-invalide
  ne retombe sur rien), répertoire de l'application, puis installation du SDK
  déclarée par le système (`MSFS2024_SDK` puis `MSFS_SDK`, déclaration pendante
  ignorée). Le chargement se fait par chemin absolu, sans
  `DllImportSearchPath.SafeDirectories`, sans `PATH` ni répertoire courant.
  Sans bibliothèque, le processus reste démarré : la source native rend
  `unavailable` dès le démarrage — distinct de `idle`, visible sans abonné,
  jamais requalifié par un réarmement — et un diagnostic actionnable sans
  chemin est écrit. La moitié bridge de J2 est livrée ici : le health check
  gagne `nativeLibrary` et `nativeLibraryOrigin` en champs additifs.
- fichiers modifiés : `apps/bridge/SimConnect/SimConnectLibraryLocator.cs`
  (nouveau), `NativeSimConnectAdapter.cs`, `BridgeOptions.cs`,
  `BridgeApplication.cs` (usage), `BridgeServer.cs`,
  `Telemetry/BridgeTelemetryOptions.cs`, `Telemetry/TelemetryAdapterFactory.cs`,
  `Telemetry/TelemetryPublisher.cs`, `tests/bridge/Program.cs`,
  `docs/SECURITY.md`, `docs/SUPPORT.md`, `docs/ARCHITECTURE.md`,
  `docs/KNOWN_ISSUES.md` (KI-031 résolue, KI-032 acceptée), ce fichier,
  `docs/features/README.md`, `docs/CURRENT_STATE.md`.
- commandes et résultats : `pnpm bridge:build` 0 avertissement, 0 erreur ;
  `pnpm bridge:test` **44/44**, dont sept scénarios nouveaux (ordre de la
  liste fermée ; chemin explicite sans repli ; déclaration SDK pendante
  ignorée au profit de la suivante ; copie exposée par `PATH` et répertoire
  courant jamais localisée ; option refusée hors source native, en relatif ou
  sur un autre nom de binaire ; source native sans bibliothèque `unavailable`
  avant tout abonné et après réarmement ; champs de santé additifs sans
  divulgation de chemin) ; `pnpm bridge:health` `Healthy`/`0` ;
  `pnpm performance:check:build` vert (frontend et desktop Release
  reconstruits dans ce worktree) ; `pnpm maintenance:check` vert.
- vérification manuelle : exécutée le 7 août 2026 sur le bridge **publié**,
  trois scénarios. 1) Machine réelle : le SDK 1.5.7 est déclaré par `MSFS_SDK`
  (hors de tout répertoire cherché par l'ancien chargeur) et la déclaration
  machine `MSFS2024_SDK` pend vers un répertoire disparu — santé
  `nativeLibrary=located`, `nativeLibraryOrigin=sdk`, `telemetryState=idle` :
  exactement le cas que l'ancien chargeur ne pouvait pas réussir, avec la
  déclaration pendante correctement ignorée. 2) Processus sans déclaration SDK
  (équivalent du répertoire renommé, sans mutation du disque) plus une copie
  factice de `SimConnect.dll` exposée par `PATH` : santé
  `unavailable`/`none`, diagnostic `SIMCONNECT_LIBRARY unavailable: install
  the MSFS 2024 SDK or pass --simconnect-library...` sans aucun chemin, la
  copie hors liste jamais chargée. 3) Chemin explicite vers la DLL du SDK :
  `located`/`explicit`. Le chargement réel de la DLL (exports résolus) est
  prouvé par le harnais sur ce poste via l'adaptateur natif.
- revue et constats traités : le vecteur de détournement de DLL a guidé
  chaque choix — pas de repli depuis un chemin explicite invalide, nom de
  fichier imposé, refus des points de réanalyse, chemin uniquement par la
  ligne de commande du superviseur (la WebView n'a aucun accès), aucun chemin
  dans la santé, le diagnostic ou les erreurs (assertions dédiées). La règle
  T0011 « répertoires Windows sûrs » de `docs/SECURITY.md` est remplacée par
  la liste fermée, explicitement datée. Constat consigné plutôt que corrigé :
  le critère « ADR-0003 scénario 14 » était hors `Allowed areas` — **tranché par
  Andy le 7 août 2026, retiré du critère et suivi en `Follow-ups`** (voir
  critères).

### J2

- résultat obtenu : **la moitié bridge est livrée, la moitié desktop est portée
  dans F0007.** Le health check expose l'état de localisation en champs additifs
  (`nativeLibrary`, `nativeLibraryOrigin`) sans chemin, version de SDK ni jeton
  — livré avec J1 et prouvé au harnais. L'affichage desktop « télémétrie
  indisponible » n'avait aucun chemin vers la WebView sans toucher
  `apps/desktop/src-tauri/` et le gate du shell, hors `Allowed areas` :
  **décision d'Andy du 7 août 2026 — porter ce câblage dans F0007** plutôt
  qu'étendre l'unité, F0007 possédant déjà ces fichiers et posant la même
  question dans sa décision 2. Ce jalon est `Done` sur son périmètre restant.
- fichiers modifiés : aucun fichier frontend — rien n'est affiché de trompeur
  en attendant, l'application assemblée n'utilisant jamais la source `native`.
- commandes et résultats : la moitié bridge est couverte par les preuves J1 ;
  les gates frontend n'ont pas été exécutés, aucun code frontend n'ayant changé,
  et ils partent avec la moitié desktop dans F0007.
- vérification manuelle : portée dans F0007 (état « télémétrie indisponible »
  dans l'application, capacités livrées intactes).
- revue et constats traités : aucun état dégradé ne se présente comme une
  réussite — `unavailable` est distinct de `idle` jusque dans la santé, et un
  réarmement ne le requalifie pas ; aucun kill switch introduit.

### J3

- résultat obtenu :
- fichiers modifiés :
- commandes et résultats :
- vérification manuelle :
- revue et constats traités :

### Synthèse

### Risks and limitations

### Follow-ups

- **Matrice de validation d'`ADR-0003`** — le cas « bibliothèque cliente
  SimConnect absente » n'entre pas dans le scénario 14 (« variable absente,
  invalide ou corrompue ») : il se situe un cran plus tôt, au niveau du
  prérequis. Décision d'Andy du 7 août 2026 : **aucune modification d'`ADR-0003`
  ici**, ni depuis cette unité ni par réécriture. L'extension de la matrice
  passera par une **ADR nouvelle**, au moment de la première promotion d'un canal
  vers `Supported` (T0059, puis F0003 J3 selon l'option retenue) — écrire cette
  ADR maintenant fixerait une barre de promotion pour une capacité qu'aucune
  machine utilisateur ne peut atteindre tant que J3 n'est pas tranché.
- **Moitié desktop de J2** — portée dans **F0007** le 7 août 2026 : affichage
  « télémétrie indisponible » et vérification que les capacités livrées restent
  utilisables sans télémétrie. Elle dépend du câblage superviseur ↔ bridge que
  F0007 J2 livre déjà.
- **KI-032** — acceptée par Andy le 7 août 2026 (statut `Accepted`) : la liste
  fermée de sources reste une dette d'entretien assumée, revalidée par la
  vérification manuelle J1 à chaque mise à jour majeure du SDK ou changement de
  canal MSFS. Aucune découverte élargie n'est ouverte en échange — elle rouvrirait
  le vecteur de détournement de DLL que J1 ferme.

### Documentation updated
