# F0003 — Trouver SimConnect nous-mêmes, ou le dire proprement

Status: Done
Owner: Agent (session du 7 août 2026)
Branch: `feature/f0003-trouver-simconnect-ou-degrader-proprement`
Avancement: les trois jalons sont `Done` le 7 août 2026. J1 : sonde bornée,
chargement par chemin absolu, état `unavailable` explicite, champs de santé
additifs. J2 : moitié bridge livrée avec J1, moitié desktop **portée dans F0007**
sur décision d'Andy. J3 : EULA du SDK lu et cité le même jour — la redistribution
n'est pas permise, donc **option C**, Thrustline ne fournit pas la bibliothèque et
le dit. Aucun binaire, aucun changement de layout ni d'installateur.
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

## Décision d'Andy — J3, prise le 7 août 2026

**Comment une machine sans SDK obtient-elle la bibliothèque cliente ?** Les trois
options étudiées, puis les termes de l'EULA qui les tranchent.

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

### EULA lu et cité — 7 août 2026 : A et B ne sont pas permises, C est retenue

L'EULA du SDK (`C:\MSFS2024SDK\Licenses\MSFS SDK EULA.pdf`, 164 Ko, 8 janvier
2025) a été fourni par Andy en texte le 7 août 2026 et lu. Les termes qui
tranchent, cités :

- **« Software » désigne le SDK entier, composants compris.** §1(g) parle de
  « the Software, **including any of its components** » — `SimConnect.dll` comme
  `SimConnect.msi` sont donc du Software.
- **§2(e) interdit la distribution** : « share, publish, distribute, or lend the
  Software (**except for any distributable code, subject to the terms above**), or
  provide the Software as a stand-alone hosted solution for others to use, or
  transfer the Software or this agreement to any third party ».
- **Le carve-out est vide, et c'est le point décisif.** « except for any
  distributable code, subject to the terms above » renvoie au §1 ; or les huit
  alinéas du §1 — (a) General, (b) Sample Content, (c) Your MSFS Add-Ons,
  (d) Changes, (e) Trademark Usage, (f) Open Source Software, (g) Competition,
  (h) Disqualification — **ne désignent rien comme « distributable code »** et
  n'accordent aucun droit de redistribution. Dans le gabarit Microsoft habituel une
  section « DISTRIBUTABLE CODE » figure au §1 ; elle est absente ici. L'exception
  n'a donc rien à quoi se rattacher.
- **Trois éléments confirment la lecture** : §1(a) n'accorde que « install and use
  the Software solely for the Purpose » — un droit d'usage, pas de distribution ;
  §1(b) interdit explicitement la distribution externe du sample content, donc la
  licence sait accorder ou refuser une distribution quand elle le veut ; et §2
  ouvre par « The Software is licensed, not sold. Microsoft reserves all other
  rights. »

**Vérification disque du même jour** : `C:\MSFS2024SDK\Licenses\MSFS SDK EULA.pdf`
est la seule licence couvrant le SDK. Les autres fichiers de licence présents
(`Tools\`, `WASM\` : Newtonsoft.Json, BabylonJS, NanoVG, rapidjson, LibGdiPlus,
OFL) couvrent des composants tiers sans rapport. Et
`SimConnect SDK\installer\SimConnect.msi` (1,94 Mo) comme `lib\SimConnect.dll`
(79 Ko) n'ont **aucune licence distincte, aucune notice de redistribution, aucun
dossier `redist`** à côté d'eux — donc le §7 (« any other terms Microsoft may
provide for supplements ») ne fournit rien ici, dans le SDK 1.5.7 tel qu'installé.

**Verdicts.** **A — non permise** : livrer `SimConnect.dll` c'est distribuer un
composant du Software (§2(e)). **B — non permise, même clause** : le `.msi` est un
composant du Software, l'embarquer dans un installateur c'est « share, publish,
distribute » ; qu'un fichier porte un nom de redistribuable ne crée aucun droit, et
le texte n'en accorde aucun. **C — retenue.**

### Précision du 7 août 2026 : la clause porte sur la distribution, pas sur le prix

Andy a soulevé que Thrustline n'est pas distribué contre paiement. Le texte ne
retient pas ce critère : §2(e) interdit « **share**, publish, distribute, or
**lend** the Software » — « share » et « lend » sont précisément des transferts sans
contrepartie, nommés à côté de « distribute » — et §1(b) interdit « any external
distribution » du sample content sans réserve commerciale. **Gratuit ne crée donc
aucune permission.**

Mais le critère qui compte est ailleurs, et il change la portée réelle : **distribué
contre non distribué.** §2(e) suppose un transfert vers un tiers. Or l'alpha n'est
pas distribuée : `docs/SUPPORT.md` pose que l'installateur non signé « ne doit pas
être distribué hors validation interne ». Donc :

- **usage interne, sur des machines qu'Andy contrôle : §2(e) n'est pas déclenché.**
  Rien n'est partagé, publié, distribué, prêté ni transféré. Installer le SDK,
  copier `SimConnect.dll` localement, la placer dans un layout de publication qui ne
  quitte pas l'interne, ou la désigner par `--simconnect-library` : aucune de ces
  actions n'est une distribution. **Rien ne bride le développement ni les tests du
  chemin natif** — y compris sur une machine interne sans SDK.
- **premier build remis à quelqu'un qui n'est pas Andy, même gratuitement :** §2(e)
  s'applique, et A comme B redeviennent des distributions non permises.

L'option C reste donc la conclusion **pour tout canal externe**, et l'autorisation
écrite prévue au §2 devient une **condition de sortie du premier canal externe**,
non un préalable au travail d'aujourd'hui. Cette autorisation est vraisemblablement
facile à obtenir : à peu près tout add-on MSFS livre sa copie de `SimConnect.dll`
— le relevé du 5 août 2026 en trouve une déposée par BeyondATC sur la machine de
validation. Une pratique répandue n'est pas un droit, mais elle indique qu'une
demande a de bonnes chances d'aboutir, ce qui rend la voie propre peu coûteuse
comparée au risque de s'en passer.

**Ce qui n'est pas fait ici, et pourquoi :** aucun contournement de la clause n'est
inscrit dans le produit ni dans cette documentation. Redistribuer sciemment en
dehors du périmètre ci-dessus est une décision juridique qui appartient à Andy et à
un conseil, pas une option d'ingénierie à consigner comme acquise.

**Réserve posée honnêtement** : ce n'est pas un avis juridique, et la lecture
repose sur une **absence** (aucun grant de distributable code). Solide, mais si le
produit en dépend, cela mérite un conseil.

**Ce que la licence ne ferme pas**, et qui reste ouvert pour le produit :

- **§2 ouvre lui-même la porte** : « Unless applicable law gives you more rights
  despite this limitation **or unless otherwise approved in writing by
  Microsoft** ». Demander cette autorisation écrite est la voie sanctionnée par la
  licence, et c'est ce qui rouvrirait A ou B. Décision d'Andy, consignée en
  `Follow-ups`.
- **L'utilisateur peut désigner sa copie** : `--simconnect-library`, livré en J1,
  accepte un chemin explicite. Sur une machine où un add-on tiers a déposé
  `SimConnect.dll` — le cas BeyondATC relevé le 5 août 2026 — la personne peut
  pointer ce qu'elle possède déjà. Nous ne distribuons rien. C'est un chemin
  volontaire et borné, pas un élargissement de la sonde : la liste fermée de J1 ne
  bouge pas, et une copie hors liste n'est jamais chargée implicitement.

**Deux contraintes de la licence à retenir hors de J3.** §1(g) interdit d'utiliser
le Software pour « the development of a competing flight simulator product or for
the purpose of competitive benchmarking, competitive analysis, **AI or machine
learning**, or intelligence gathering » — Thrustline est un add-on de carrière,
donc le Purpose colle, mais toute idée future d'entraîner un modèle sur des données
dérivées du SDK est exclue. Et §1(c) interdit de représenter ou laisser entendre
que Microsoft soutient Thrustline.

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
- `docs/SECURITY.md`, `docs/ARCHITECTURE.md`, `docs/QUALITY.md`, `docs/SUPPORT.md`,
  `docs/CURRENT_STATE.md`, `docs/KNOWN_ISSUES.md` ;
- ce fichier et `docs/features/README.md` ;
- pour J3 uniquement et selon l'option retenue : le layout de publication et
  l'installateur.

**Retrait du 7 août 2026 :** la restitution desktop de l'état indisponible
(`apps/desktop/src/`) a quitté cette liste avec la moitié desktop de J2, portée
dans F0007. Le retrait est réel et non décoratif : le sélecteur lit ces chemins
pour détecter les collisions de zones entre unités concurrentes, et laisser la
ligne — même raturée — aurait empêché F0007 de démarrer en parallèle de cette
unité.

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

### J3 — Une machine sans SDK n'obtient rien de nous, et l'apprend clairement

Status: Done
Risk: High
Security-sensitive: Yes
Autonomous: No

**Tranché le 7 août 2026 par la lecture de l'EULA : option C.** Ce jalon ne livre
donc **aucun binaire, aucun layout de publication modifié, aucune étape
d'installateur** — l'EULA ne permet ni A ni B (voir la section de décision). Ce
qu'il livre est un énoncé honnête, et la fermeture du gate qui bloquait l'unité.

- résultat : Thrustline ne fournit pas la bibliothèque cliente. La télémétrie live
  n'existe que sur une machine qui en possède déjà une — SDK MSFS installé par la
  personne, ou chemin explicite `--simconnect-library` vers une copie qu'elle
  possède. `docs/SUPPORT.md` le dit, et sa règle « l'utilisateur ne doit installer
  ni SDK .NET, ni outils de développement, ni SDK MSFS » est corrigée pour ne plus
  se contredire. L'invariant de J1 tient sans changement : aucun binaire n'entre
  dans le dépôt, l'origine de la bibliothèque chargée est consignée, une
  bibliothèque d'origine inconnue n'est jamais chargée.
- frontière : documentation seulement. **Ni `apps/`, ni le layout de publication,
  ni l'installateur ne sont touchés** — donc aucun budget ni gate de packaging n'est
  concerné.
- validations : `pnpm maintenance:check`. Les gates de packaging et le budget de
  128 Mio sont sans objet, rien n'étant ajouté au layout.
- revue : vérifier que la licence est **citée** et non résumée de mémoire ; qu'aucun
  binaire n'a été ajouté au dépôt ni au layout ; que la sonde de J1 n'est pas
  élargie en compensation ; et que la limitation produit est énoncée sans être
  minimisée.

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
      — Respecté : l'EULA a été lu le 7 août 2026, ses clauses §1(a), §1(b), §1(g),
      §2 et §2(e) sont citées dans la section de décision, et **aucun binaire
      n'entre dans le dépôt ni dans le layout** — l'option retenue est précisément
      celle qui n'en livre aucun.
- [x] Une machine sans bibliothèque cliente sait quoi faire, et Thrustline ne lui
      fournit rien qu'il n'a pas le droit de fournir. — J3, 7 août 2026 : option C,
      `docs/SUPPORT.md` énonce la limitation et les deux chemins possibles (SDK
      installé par la personne, ou `--simconnect-library` vers une copie qu'elle
      possède), et sa règle « ni SDK MSFS » est corrigée pour ne plus se
      contredire. La limitation produit est consignée en `KI-033`.

**Critère porté hors de cette unité, décision d'Andy du 7 août 2026 :** « les
capacités déjà livrées restent utilisables sans télémétrie » quitte cette liste
pour celle de **F0007**, avec la moitié desktop de J2. Cette unité ne gate donc
plus dessus.

Précision du même jour, une fois l'option C tranchée pour F0007 : **l'alpha ne
sélectionnera jamais la source `native`**, puisqu'elle n'embarque aucune trace et
n'active aucune télémétrie. Le cas « bibliothèque cliente absente → télémétrie
indisponible » n'est donc pas observable dans le parcours humain de l'alpha : il se
prouve par un contrôle déterministe du shell, et sa vérification humaine attend
MSFS réel (T0059) ou J3 de cette unité. Ce que F0007 rend visible dans l'alpha,
c'est l'énoncé honnête « cette version ne mesure pas le temps de bloc » — une
cause distincte, que son vocabulaire d'états ne confond pas avec la bibliothèque
manquante.

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
sonde, pas de la retirer. **J3 n'a rien à rétracter** : sous l'option C il n'ajoute
ni binaire, ni étape d'installation, ni entrée de layout — seulement de la
documentation. Si Microsoft accordait un jour l'autorisation écrite prévue au §2,
c'est une reprise de J3, pas un rollback.

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

- résultat obtenu : **option C, forcée par la licence et non choisie par
  préférence.** L'EULA du SDK a été lu le 7 août 2026 (Andy en a fourni le texte,
  aucun extracteur PDF n'existant sur ce poste) et ses clauses sont citées dans la
  section de décision : §2(e) interdit de distribuer le Software, son exception
  « distributable code, subject to the terms above » ne renvoie à aucun grant dans
  le §1, et §1(g) confirme que les composants sont du Software. A (livrer
  `SimConnect.dll`) et B (embarquer `SimConnect.msi`) sont donc écartées. Thrustline
  ne fournit pas la bibliothèque : la télémétrie live n'existe que sur une machine
  qui en possède déjà une, par SDK installé volontairement ou par
  `--simconnect-library`. La sonde de J1 n'est **pas** élargie en compensation.
- fichiers modifiés : ce fichier (section de décision, jalon J3, critères,
  rollback, ce rapport), `docs/SUPPORT.md` (limitation énoncée et contradiction
  « ni SDK MSFS » résolue), `docs/KNOWN_ISSUES.md` (`KI-033` créée),
  `docs/CURRENT_STATE.md`, `docs/features/README.md`. **Aucun fichier sous
  `apps/`, aucun binaire, aucun changement de layout de publication ni
  d'installateur.**
- commandes et résultats : `pnpm maintenance:check` vert. Les gates de packaging et
  le budget de fondation de 128 Mio sont sans objet — rien n'est ajouté au layout,
  donc il n'y a rien à mesurer.
- vérification manuelle : vérification disque du SDK 1.5.7 tel qu'installé —
  `C:\MSFS2024SDK\Licenses\MSFS SDK EULA.pdf` est la seule licence couvrant le SDK ;
  les autres licences présentes (`Tools\`, `WASM\`) couvrent des composants tiers
  sans rapport ; et `SimConnect SDK\installer\SimConnect.msi` comme
  `lib\SimConnect.dll` n'ont aucune licence distincte, aucune notice de
  redistribution, aucun dossier `redist`. Le §7 (« supplements ») ne fournit donc
  rien ici.
- revue et constats traités : la licence est citée clause par clause et non résumée
  de mémoire — c'était l'exigence explicite du jalon. La lecture repose sur une
  **absence** (aucun grant de distributable code), ce qui est consigné comme réserve
  et non masqué : ce n'est pas un avis juridique. Constat traité plutôt que laissé :
  `docs/SUPPORT.md` affirmait « L'utilisateur ne doit installer ni SDK .NET, ni
  outils de développement, ni SDK MSFS », ce que l'option C contredit
  frontalement — la règle est corrigée pour distinguer ce que l'application exige
  (rien) de ce que la télémétrie live exige (une bibliothèque que la personne
  possède). Voie de sortie non fermée et consignée en `Follow-ups` : le §2 prévoit
  « unless otherwise approved in writing by Microsoft ».

### Synthèse

Cette fonctionnalité est partie d'une question d'Andy — « il faut qu'on le trouve
nous-même, dans l'hypothèse où la personne n'a rien de tout ça » — et elle y répond
en deux temps qui ne se recouvrent pas.

**Le trouver, oui, et c'est fait.** Le chargeur d'origine ne pouvait réussir sur
aucune machine où le SDK n'est pas dans un répertoire cherché — pas même sur la
machine de validation, MSFS 2024 et SDK 1.5.7 installés. `SimConnectLibraryLocator`
le corrige par une liste ordonnée et fermée, un chargement par chemin absolu, et un
refus prouvé de toute source hors liste. 44 tests bridge, vérification manuelle sur
le bridge publié, `KI-031` résolue.

**Le fournir, non, et la licence l'interdit.** L'EULA du SDK ne contient aucun grant
de distributable code : ni `SimConnect.dll` ni `SimConnect.msi` ne peuvent être
redistribués. La découverte était donc nécessaire mais insuffisante, exactement
comme le `Context` le pressentait — et l'insuffisance n'est pas technique, elle est
contractuelle. Sur une machine sans bibliothèque cliente, Thrustline dit la vérité
au lieu d'échouer sans explication, et c'est tout ce qu'il peut faire.

Le résultat net est honnête et inconfortable : la capacité centrale du produit —
la télémétrie live — ne fonctionne aujourd'hui que pour qui installe volontairement
un SDK de développement, ou pointe une copie qu'il possède déjà. C'est consigné en
`KI-033`, pas dissimulé dans un statut `Done`.

### Risks and limitations

- **La télémétrie live n'est atteignable par presque aucun utilisateur final**, dès
  lors qu'un build sort de l'interne : la redistribution y est interdite,
  et MSFS 2024 n'expose sur la machine qu'un `SimConnect_internal.dll` — nom
  différent, protégé par ACL, qui n'est pas la bibliothèque cliente. C'est `KI-033`,
  et c'est la limitation dominante de cette unité.
- **La lecture de licence repose sur une absence.** Le §2(e) renvoie à un
  « distributable code » que le §1 ne définit jamais. C'est une lecture solide, ce
  n'est pas un avis juridique, et le produit ne devrait pas parier gros dessus sans
  conseil.
- **`--simconnect-library` déplace une décision vers la personne.** Le chemin
  explicite est borné et validé (absolu, nom imposé, fichier réel, pas de point de
  réanalyse, source native seulement, aucun repli), mais il reste un chemin par
  lequel une personne peut désigner un binaire qu'elle exécute dans notre processus.
  C'est volontaire et documenté ; ce n'est pas sans conséquence.
- **La liste fermée vieillira** — `KI-032`, acceptée, revalidée à chaque évolution
  du SDK.
- **La moitié desktop de J2 n'est pas livrée ici** : elle vit dans F0007, dont le
  démarrage dépendait de la sortie de cette unité.

### Follow-ups

- **Autorisation écrite de Microsoft — condition du premier canal externe, non
  engagée.** Le §2 de l'EULA réserve explicitement « unless otherwise approved in
  writing by Microsoft ». C'est la seule voie qui rouvrirait l'option A ou B, et donc
  la seule qui rendrait la télémétrie live atteignable par un utilisateur ordinaire.
  Précision du 7 août 2026 : ce n'est **pas** un préalable au travail interne — tant
  que rien ne quitte les machines d'Andy, §2(e) n'est pas déclenché et le chemin
  natif se développe et se teste sans restriction. L'autorisation devient nécessaire
  au moment où un build est remis à quelqu'un d'autre, **même gratuitement** :
  « share » et « lend » sont nommés dans la clause. Démarche produit et juridique,
  pas d'ingénierie ; elle appartient à Andy, et `KI-033` reste ouverte jusque-là.

- **Matrice de validation d'`ADR-0003`** — le cas « bibliothèque cliente
  SimConnect absente » n'entre pas dans le scénario 14 (« variable absente,
  invalide ou corrompue ») : il se situe un cran plus tôt, au niveau du
  prérequis. Décision d'Andy du 7 août 2026 : **aucune modification d'`ADR-0003`
  ici**, ni depuis cette unité ni par réécriture. L'extension de la matrice
  passera par une **ADR nouvelle**, au moment de la première promotion d'un canal
  vers `Supported` (T0059). Précision du 7 août 2026, J3 étant désormais tranché :
  la raison d'attendre reste entière et s'est même renforcée — sous l'option C
  aucune machine utilisateur ne peut atteindre la télémétrie live sans installer un
  SDK, donc fixer maintenant une barre de promotion pour cette capacité n'aurait
  rien à valider.
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
