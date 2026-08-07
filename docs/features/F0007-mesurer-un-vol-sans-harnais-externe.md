# F0007 — Finir son vol dans l'alpha, et dire honnêtement pourquoi elle ne mesure pas

Status: Ready
Séquencement: `Ready` mais **différée par le sélecteur** tant que F0003 est
`In progress` — collision de zone sur `docs/ARCHITECTURE.md`, que les deux unités
réclament légitimement. C'est donc la sortie de F0003 (son J3, qui attend la
lecture de l'EULA du SDK) qui libère un démarrage en parallèle ; en pilotage
interactif, Andy peut la lancer sans attendre le sélecteur.
Owner: Unassigned
Branch: `feature/f0007-mesurer-un-vol-sans-harnais-externe`
Phase: 3–4
Risk: Medium
Security-sensitive: Yes
Autonomous: No

## Goal

La personne qui installe l'alpha déroule le golden path **jusqu'au bout** : elle
part en vol, et elle peut le finir. L'application lui dit franchement que cette
version ne mesure pas le temps de bloc et pourquoi, au lieu de lui demander de
terminer un replay qui n'existe pas.

**Pivot du 7 août 2026.** Ce fichier visait « voir un temps de bloc mesuré sans
rien lancer d'autre que l'application ». Andy a tranché l'option C — pas de trace
dans l'alpha — donc cet objectif n'est plus atteignable ici : la mesure arrive
avec MSFS réel (F0003 J3, T0059). Ce que l'unité livre à la place, c'est un
parcours qui se termine et une application qui ne ment pas sur ce qu'elle sait
faire. Le titre suit ce pivot ; l'identifiant `F0007`, le nom de fichier et la
branche ne changent pas, pour ne casser aucune référence.

## Context

KI-027, constatée le 7 août 2026 pendant la vérification manuelle de F0004 J3.
Trois maillons manquent au câblage, et il suffit d'un seul pour que la chaîne
reste morte :

- `apps/desktop/src-tauri/src/bridge.rs` lance le bridge avec `--port` et rien
  d'autre : aucune `--telemetry-trace`, aucune `--telemetry-source` ;
- `TelemetryAdapterFactory.TryCreate` rend `null` sans `--telemetry-trace`,
  donc aucun adaptateur n'existe ;
- `TelemetryPublisher.PublishAsync` attend `_firstSubscriber`
  (`apps/bridge/Telemetry/TelemetryPublisher.cs:168`) avant de lire la trace, et
  rien dans l'application ne crée cet abonné SignalR.

Résultat : le résumé de vol reste `idle` dans l'alpha telle qu'assemblée, et
l'affichage F0004 J3 n'a rien à montrer. Le parcours manuel du 7 août n'a abouti
qu'avec un wrapper `THRUSTLINE_BRIDGE_PATH` injectant
`tests/traces/synthetic-golden-flight.jsonl` **et** un abonné WebSocket externe.

F0006 a rendu le tracker réarmable et rattaché la mesure à son vol ; F0002
consomme cette mesure pour la clôture. Le seul trou restant entre « l'alpha
cliquable » et « l'alpha qui mesure » est celui-ci.

**Ajout du 7 août 2026 — la moitié desktop de F0003 J2 est portée ici.** F0003 J1
a livré la sonde SimConnect bornée et exposé l'état de localisation dans le health
check du bridge (`nativeLibrary` : `located`/`unavailable`/`not-required` ;
`nativeLibraryOrigin` : `explicit`/`application`/`sdk`/`none`). L'affichage
« télémétrie indisponible » dans l'application était inexécutable dans les
`Allowed areas` de F0003 : le superviseur ne consomme pas le health check, la seule
surface IPC est `flight_summary` dont le vocabulaire d'états est fermé des deux
côtés, et l'étendre relève de `apps/desktop/src-tauri/` et du gate
`tests/desktop-shell/run.ps1`. Andy a tranché : ce câblage vient ici, parce que
cette unité possède déjà ces fichiers et que sa décision 2 pose exactement la même
question — qui parle au bridge, le superviseur ou la WebView. Une seule évolution
de la surface IPC sert donc les deux besoins : l'origine de la mesure et
l'indisponibilité de la télémétrie.

## Décisions d'Andy — prises le 7 août 2026

1. **D'où vient la trace de l'alpha ? → option C, pas de trace du tout.** L'alpha
   n'embarque aucune trace, n'ouvre aucun sélecteur de fichier, et n'affichera un
   temps de bloc mesuré que sous MSFS réel (F0003 J3 et T0059). Les options
   écartées : **A**, trace dorée embarquée — l'alpha aurait toujours mesuré le
   même vol synthétique ; **B**, trace choisie par la personne — aurait ouvert une
   frontière d'entrée utilisateur vers le bridge et un accès au système de
   fichiers que le shell n'a pas (capability vide, aucun plugin Tauri).
2. **Qui crée le premier abonné ? → sans objet sous C.** Il n'y a plus d'abonné à
   créer pour une mesure replay, et J1 retire la barrière au lieu de la contourner.
   La question se reposera pour la source native, dans T0059.
3. **Temps réel ou accéléré ? → sans objet sous C.** Aucune trace n'est rejouée
   par l'application.

### Conséquence tranchée le même jour : l'alpha doit pouvoir finir son vol

L'option C, prise littéralement, **rendait le golden path de l'alpha installée non
clôturable**, ce qui a été constaté dans le code avant de consigner la décision :
sans source, le résumé reste `idle` et `blockMinutes` à `null` ;
`FlightCloseControl` échoue fermé sur exactement ce cas (état `unmeasured`,
`close_flight` jamais appelé) et affiche « terminez le replay puis réessayez » —
un conseil impossible à suivre dans une version sans replay. Le dispatch restait
« En vol » indéfiniment, sans sortie depuis l'application.

**Décision d'Andy : l'application gagne un chemin d'abandon de vol.** Sans
télémétrie, la personne peut **abandonner** son vol au lieu de le clôturer.
Aucun temps de bloc n'est inventé — la décision du 6 août 2026 (« le temps de
bloc vient de la télémétrie, jamais d'une saisie ») tient entière.

Ce que le serveur fait déjà, vérifié le 7 août 2026, et qui explique pourquoi
cette unité ne touche ni l'Edge ni une migration :

- `flight-close` accepte `outcome: "interrupted"` et `blockMinutes: 0`, et sait
  répondre `state: "interrupted"` ;
- le règlement autoritaire pose `settled_amount_minor` au plancher
  `interruptedFloorMinor` = **5 000 minor (50,00 €)** — un plancher, pas zéro, et
  jamais l'échelle complète ;
- la réputation reçoit `reputationInterruptedDelta` = **−3** (contre +1 pour un
  vol complété). Cette réputation est **informative** : aucune capacité n'est
  modulée par le score, ce que la base garantit explicitement ;
- le dispatch passe à l'état `interrupted`, qui est de l'histoire et **ne bloque
  plus l'avion** pour un nouveau dispatch.

Le travail est donc **entièrement desktop** : `flightClose.ts` fige aujourd'hui
`outcome: "completed"`, `state: "completed"` et refuse `blockMinutes < 1` ; il
faut ouvrir ces trois points au cas `interrupted`, ajouter le contrôle et son
état, et couvrir le tout en tests.

## Dependencies

- F0004 fusionnée — mesure, contrat local, commande `flight_summary` ;
- F0006 fusionnée — générations réarmables et rattachement au dispatch ;
- F0003 J1 fusionnée — champs de santé `nativeLibrary` et `nativeLibraryOrigin`,
  consommés par la moitié desktop portée ici le 7 août 2026 ;
- **décision d'Andy sur l'origine de la trace : prise le 7 août 2026 — option C**,
  plus le chemin d'abandon de vol (voir la section des décisions) ;
- T0051 et le règlement autoritaire : `outcome: "interrupted"`, le plancher
  `interruptedFloorMinor` et le delta de réputation existent déjà et ne changent
  pas — cette unité les **consomme**, elle ne les redéfinit pas ;
- T0054 : l'invariant « le bridge ne connaît ni compagnie, ni dispatch, ni grand
  livre » ne bouge pas.

## Allowed areas

- `apps/desktop/src-tauri/src/bridge.rs` et le superviseur ;
- `apps/bridge/Telemetry/` — publication de télémétrie (barrière du premier
  abonné). **Resserré depuis `apps/bridge/` le 7 août 2026** : J1 ne touche que
  `TelemetryPublisher`, et la zone large entrait inutilement en collision avec
  `apps/bridge/BridgeHealth.cs` de F0003 ;
- `tests/bridge/`, `tests/desktop-shell/run.ps1`, `apps/desktop/src/test/` ;
- `apps/desktop/src/` — restitution de l'état « télémétrie indisponible » (moitié
  desktop de F0003 J2, portée ici le 7 août 2026) et chemin d'abandon de vol
  (`features/flight-dispatch/`) ;
- `docs/SECURITY.md`, `docs/ARCHITECTURE.md`, `docs/QUALITY.md`,
  `docs/SUPPORT.md`, `docs/CURRENT_STATE.md`, `docs/KNOWN_ISSUES.md` ;
- ce fichier, `docs/features/README.md`, et
  `docs/features/F0003-trouver-simconnect-ou-degrader-proprement.md` pour cocher le
  critère qui lui a été porté.

## Do not touch

- La CSP par canal de F0005 : aucune origine nouvelle ;
- le jeton et le port du contrat local : ils restent privés au superviseur ;
- l'autorité serveur : la mesure reste informative, le serveur conserve
  `min(déclaré, écoulé)` (T0051) ;
- **`supabase/` en entier — aucune fonction Edge, aucune migration.** Le chemin
  d'abandon existe déjà côté serveur et côté base ; le toucher serait rouvrir le
  règlement autoritaire pour un besoin purement client ;
- **la politique de règlement et les deltas de réputation** :
  `interruptedFloorMinor`, `reputationInterruptedDelta` et
  `reputationCompletedDelta` restent tels quels. L'abandon coûte ce qu'il coûte
  déjà ;
- **aucune saisie de temps de bloc par la WebView**, sous aucune forme : un
  abandon envoie `blockMinutes: 0` avec `outcome: "interrupted"`, jamais une
  valeur choisie. C'est la décision du 6 août 2026, et elle est le cœur de
  l'anti-triche de cette unité.

## Non-goals

- MSFS réel et SimConnect natif : F0003 J3 et T0059 — **c'est là que la mesure
  arrive**, pas ici ;
- embarquer une trace, dans quelque canal que ce soit : option A écartée le
  7 août 2026 ;
- ouvrir un sélecteur de fichier vers le bridge : option B écartée le même jour ;
- la détection de phases de vol, la reprise après crash ;
- la persistance du rattachement au redémarrage (limite connue de F0006).

## Jalons

### J1 — La barrière du premier abonné disparaît du chemin de mesure

Status: Ready
Risk: Medium
Security-sensitive: No
Autonomous: Yes

**Pourquoi ce jalon survit à l'option C.** Il ne sert pas l'alpha, qui n'aura
aucune source de télémétrie : il sert MSFS réel. `TelemetryPublisher.RunAsync`
attend `_firstSubscriber` **avant de créer n'importe quel adaptateur**, source
native comprise — la barrière n'a rien de spécifique au replay. Laissée en place,
elle bloquera T0059 exactement comme elle bloque le replay aujourd'hui : pas
d'abonné, pas d'adaptateur, pas de mesure. Elle est corrigeable et prouvable dès
maintenant au harnais bridge, sans MSFS ni matériel — donc elle se corrige ici.

- résultat : le bridge mesure dès qu'une source existe, sans attendre qu'un
  abonné SignalR se présente. La diffusion `telemetry.v1` reste inchangée pour les
  abonnés réels ; c'est l'attente bloquante sur le chemin de la mesure qui
  disparaît, pas la diffusion.
- frontière : `TelemetryPublisher`.
- validations : `pnpm bridge:test`, `pnpm bridge:build`.
- revue : chercher toute régression de la borne de cadence, de l'abandon d'un
  abonné lent, et tout échantillon émis hors des bornes T0054. Vérifier qu'un
  bridge sans aucune source reste `idle` et ne crée pas d'adaptateur fantôme.

### J2 — L'application dit ce qu'elle sait mesurer, et ne le devine pas

Status: Ready
Risk: Medium
Security-sensitive: Yes
Autonomous: No

Ce jalon absorbe la **moitié desktop de F0003 J2**, portée ici le 7 août 2026.

- résultat : le superviseur — seul lecteur du health check du bridge — relaie à la
  WebView un état de disponibilité de la télémétrie à **vocabulaire fermé des deux
  côtés**, sans jamais transmettre chemin, version de SDK ni jeton. L'application
  affiche un état accessible qui dit la vérité de la version installée : cette
  version ne mesure pas le temps de bloc, la mesure arrivera avec MSFS réel. Le
  message trompeur « terminez le replay puis réessayez » disparaît de ce cas.
  L'état couvre les deux causes distinctes, sans les confondre : **aucune source
  configurée dans cette version** (le cas de l'alpha sous option C) et
  **bibliothèque cliente absente** (le cas F0003, `nativeLibrary=unavailable`).
- frontière : superviseur Rust, surface IPC, `apps/desktop/src/`.
- validations : `pnpm desktop:check`, `pnpm desktop:test`, `pnpm frontend:typecheck`,
  `pnpm frontend:test`, `pnpm frontend:coverage`, `pnpm frontend:build`,
  `pnpm bridge:test` pour les champs de santé consommés.
- revue : vérifier qu'aucun chemin local, version de SDK ni jeton ne traverse vers
  la WebView ; qu'un état dégradé ne se présente jamais comme une réussite ;
  qu'aucun kill switch n'est introduit là où `SUPPORT.md` l'interdit ; et que la
  WebView ne peut pas **choisir** l'état affiché, seulement le lire.

### J3 — Le vol se termine, sans mesure et sans mensonge

Status: Ready
Risk: Medium
Security-sensitive: Yes
Autonomous: No

- résultat : sans télémétrie, la personne peut **abandonner** son vol depuis
  l'application. L'appel part avec `outcome: "interrupted"` et `blockMinutes: 0` —
  jamais une valeur saisie — et le serveur applique ce qu'il applique déjà :
  plancher `interruptedFloorMinor`, delta de réputation informatif, dispatch en
  état `interrupted` qui libère l'avion. Le contrôle **nomme sa conséquence avant
  l'action** (indemnité plancher, réputation, pas de revenu de vol), et
  l'abandon n'est jamais présenté comme une clôture réussie. Le golden path de
  l'alpha installée se termine.
- frontière : `apps/desktop/src/features/flight-dispatch/` — `flightClose.ts` fige
  aujourd'hui `outcome: "completed"`, `state: "completed"` et refuse
  `blockMinutes < 1` ; ces trois points s'ouvrent au cas `interrupted` **sans
  élargir ce qu'un client peut déclarer**. Aucune fonction Edge, aucune migration.
- validations : `pnpm frontend:typecheck`, `pnpm frontend:test`,
  `pnpm frontend:coverage`, `pnpm frontend:build`, `pnpm authority:check`,
  `pnpm maintenance:check`, plus le parcours manuel consigné sur l'alpha installée.
- revue : **c'est la frontière anti-triche de cette unité.** Chercher tout chemin
  par lequel un `blockMinutes` non nul, ou un `outcome: "completed"`, pourrait
  partir d'un vol non mesuré ; vérifier l'idempotence de l'abandon (une clé par
  intention, un rejeu ne double pas le règlement) ; vérifier qu'un vol mesuré
  n'emprunte jamais le chemin d'abandon par défaut.

## Acceptance criteria

- [ ] Le bridge mesure dès qu'une source existe, sans abonné SignalR — prouvé au
      harnais, et la diffusion `telemetry.v1` reste inchangée pour les abonnés
      réels.
- [ ] L'application installée indique que cette version ne mesure pas le temps de
      bloc, sans jamais afficher « terminez le replay ».
- [ ] Le golden path de l'alpha installée **se termine** : la personne part en vol
      et peut l'abandonner, l'avion est libéré pour un nouveau dispatch.
- [ ] Un abandon envoie `outcome: "interrupted"` et `blockMinutes: 0`, et rien
      d'autre ne peut partir d'un vol non mesuré — prouvé par un contrôle
      déterministe et par `pnpm authority:check`.
- [ ] L'abandon nomme sa conséquence avant l'action et n'est jamais présenté comme
      une clôture réussie.
- [ ] La WebView ne peut influencer ni le jeton, ni le port, ni l'état de
      disponibilité relayé — prouvé par un contrôle déterministe.
- [ ] KI-027 passe `Accepted` en citant la décision d'Andy du 7 août 2026 : l'alpha
      ne mesure pas par elle-même, par choix ; la mesure arrive avec T0059.
- [ ] **Porté de F0003 J2 le 7 août 2026** — quand la source de télémétrie
      sélectionnée n'a pas de bibliothèque cliente, l'application affiche un état
      accessible « télémétrie indisponible » disant quoi installer, sans divulguer
      chemin, version de SDK ni jeton, et cet état ne se présente jamais comme une
      réussite. **Sous option C l'alpha ne sélectionne jamais la source native** :
      ce cas se prouve donc par un contrôle déterministe du shell, et sa
      vérification humaine attend MSFS réel (T0059) ou F0003 J3.
- [ ] **Porté de F0003 J2 le 7 août 2026** — les capacités déjà livrées restent
      utilisables sans télémétrie : compagnie, catalogue, achat, dispatch et flotte,
      conformément à `docs/SUPPORT.md`, et aucun kill switch n'est introduit là où
      `SUPPORT.md` l'interdit. À consigner daté dans la note de portage de F0003
      (section `Acceptance criteria`), qui pointe ici.

## Security review

Jalons concernés : **J2** et **J3**.

- actifs/données : jeton et port du contrat local ; état de disponibilité de la
  télémétrie ; **le rapport de vol envoyé au règlement autoritaire** ;
- frontière : WebView ↔ superviseur Tauri ↔ bridge, et WebView ↔ Edge
  `flight-close` ;
- abus : (J2) une WebView compromise qui lirait le jeton, le port ou un chemin
  local à travers l'état relayé, ou qui **choisirait** l'état affiché pour
  faire croire à une indisponibilité ; (J3) **une WebView qui déclarerait un
  temps de bloc** en empruntant le chemin d'abandon — envoyer un `blockMinutes`
  non nul, ou un `outcome: "completed"` sans mesure, pour se payer un vol
  qu'elle n'a pas volé ; ou un rejeu d'abandon qui réglerait deux fois ;
- validation/autorisation : l'état de disponibilité est un vocabulaire fermé
  dérivé du health check par le superviseur, jamais reçu de la WebView ;
  l'abandon envoie exactement `outcome: "interrupted"` et `blockMinutes: 0`,
  constantes du code et non valeurs d'entrée ; le serveur reste autoritaire sur
  le règlement (plancher) et sur la réputation ; contrôles déterministes avec
  mutations négatives des deux côtés ;
- atomicité/idempotence : l'abandon porte une clé d'idempotence liée à son
  intention, comme la clôture — un rejeu rejoue le même règlement et n'en crée
  pas un second ;
- logs/vie privée : aucun chemin local ni jeton journalisé ; l'état de
  disponibilité ne porte jamais le chemin de la bibliothèque, sa version de SDK
  ni le jeton du contrat local.

## Maintenance review

- dettes et problèmes connus applicables : **KI-027**, qui passe `Accepted` et
  non `Resolved` — l'alpha ne mesure pas par elle-même, par décision d'Andy du
  7 août 2026, et la mesure arrive avec T0059 ;
- dette créée ou aggravée : **aucune trace embarquée**, donc pas la dette de
  l'option A. En échange, l'alpha publie une capacité centrale absente : c'est
  une dette produit assumée, pas une dette technique. Et le chemin d'abandon
  devra cohabiter avec la clôture mesurée quand MSFS réel arrivera — les deux
  chemins doivent rester distincts, l'abandon ne devenant jamais la sortie par
  défaut d'un vol mesurable ;
- règle de sécurité ajoutée : dans `SECURITY.md`, l'origine de l'état de
  disponibilité (superviseur seul lecteur du health check) et l'invariant « la
  WebView ne déclare jamais de temps de bloc, y compris à l'abandon » ;
- contrôle manuel à automatiser : la preuve qu'aucun abonné externe n'est requis
  (J1, au harnais) ; et la preuve qu'un abandon ne peut pas partir avec un
  `blockMinutes` non nul (J3, contrôle déterministe) ;
- risque résiduel : une personne peut abandonner un vol qu'elle aurait pu voler,
  et perdre le revenu correspondant contre le plancher — c'est un choix
  explicite, nommé avant l'action, pas un piège ; et l'alpha reste une alpha qui
  ne mesure pas, ce que `SUPPORT.md` doit énoncer.

## Automated validation

```powershell
pnpm bridge:build
pnpm bridge:test
pnpm desktop:check
pnpm desktop:test
pnpm frontend:typecheck
pnpm frontend:test
pnpm frontend:coverage
pnpm frontend:build
pnpm authority:check
pnpm maintenance:check
```

## Manual verification

1. J1 : lancer le bridge avec une trace, **sans aucun abonné**, et constater que
   `GET /api/v1/flight-summary` atteint `completed`.
2. J2 : lancer l'application installée et constater qu'elle énonce que cette
   version ne mesure pas le temps de bloc, sans jamais afficher « terminez le
   replay », et qu'aucun chemin ni jeton ne traverse vers la WebView.
3. J3, bout en bout : dérouler le golden path dans l'alpha installée jusqu'à
   l'abandon du vol, constater le règlement au plancher, le dispatch en état
   `interrupted` et **l'avion de nouveau disponible pour un dispatch** ; puis
   enchaîner un second vol pour prouver que la boucle se referme.
4. J2, porté de F0003 J2 : sur une machine sans bibliothèque cliente, lancer le
   bridge en source `native` et constater l'état « télémétrie indisponible » et
   que compagnie, catalogue, achat, dispatch et flotte restent utilisables.
   **L'alpha ne sélectionnant jamais `native` sous l'option C**, cette
   vérification se fait au harnais du shell ; sa version humaine attend T0059 ou
   F0003 J3.

## Rollback

J1 et J2 sont rétractables sans donnée concernée : rétablir la barrière du premier
abonné, retirer l'état relayé et son affichage rend l'alpha à son état actuel —
résumé `idle` et message trompeur compris.

**J3 ne l'est pas de la même façon.** Un vol abandonné est réglé au grand livre et
porte un événement de réputation ; les deux sont append-only et ne se rétractent
pas. Retirer le contrôle d'abandon empêche d'en créer de nouveaux, mais les vols
déjà abandonnés restent abandonnés. Le rollback utile de J3 est donc de retirer le
contrôle, pas d'annuler ses effets — et c'est une raison de plus pour que le
contrôle nomme sa conséquence avant l'action.

## Completion Report

Un bloc par jalon, rempli au moment de son commit, puis une synthèse.

### J1

- résultat obtenu :
- fichiers modifiés :
- commandes et résultats :
- vérification manuelle :
- revue et constats traités :

### J2

- résultat obtenu :
- fichiers modifiés :
- commandes et résultats :
- vérification manuelle :
- revue et constats traités :

### J3

- résultat obtenu :
- fichiers modifiés :
- commandes et résultats :
- vérification manuelle :
- revue et constats traités :

### Synthèse

### Risks and limitations

### Follow-ups

### Documentation updated
