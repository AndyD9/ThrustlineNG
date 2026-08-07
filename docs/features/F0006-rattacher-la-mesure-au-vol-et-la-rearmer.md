# F0006 — Rattacher la mesure de vol à son dispatch et la réarmer entre deux vols

Status: In progress
Owner: Agent (session du 7 août 2026)
Branch: `feature/f0006-rattacher-la-mesure-au-vol-et-la-rearmer`
Phase: 3–4
Risk: Medium
Security-sensitive: Yes
Autonomous: No

## Goal

La personne qui enchaîne plusieurs vols dans la même session de l'application
voit chaque temps de bloc mesuré attribué au bon vol — jamais la mesure d'un
vol précédent — et peut mesurer un nouveau vol sans redémarrer l'application.

## Context

KI-028 (revue adversariale de F0004, 7 août 2026) : le résumé de vol du bridge
ne porte aucune identité et son tracker est définitivement terminal pour la
session — plusieurs vols d'affilée ne peuvent ni être mesurés ni être
attribués, et une relecture après un vol suivant rend la mesure du vol
précédent. **Décision d'Andy du 7 août 2026 consignée dans KI-028 : le
rattachement résumé ↔ vol et le réarmement du tracker sont des prérequis de
F0002.** Décision de séquencement d'Andy du 7 août 2026 (« go 1 ») : cette
unité est fusionnée d'abord, puis la clôture F0002 (PR #131, en brouillon) y
est branchée.

L'invariant T0054 est conservé tel quel : le bridge ne connaît ni compagnie,
ni dispatch, ni grand livre. Le rattachement vit donc dans le processus Tauri,
seul détenteur du jeton du contrat local : le bridge n'expose qu'un **numéro de
génération de mesure**, opaque et local ; Tauri associe en mémoire la
génération armée à l'identifiant du dispatch fourni par la WebView au départ du
vol, et ne rend à la WebView que le dispatch rattaché — jamais le jeton, le
port ni la génération.

## Décisions d'implémentation (proposées, réversibles avant fusion)

- **Génération de mesure** : le bridge démarre en génération 1 (comportement
  actuel inchangé) ; `POST /api/v1/flight-summary/rearm`, derrière le jeton du
  contrat local, n'est accepté que lorsque la session de mesure courante est
  terminale ou vierge — réarmer en pleine mesure est refusé (409) plutôt que de
  perdre une mesure en cours. Un réarmement crée un tracker neuf, incrémente la
  génération et rejoue la source replay depuis le début.
- **Contrat local** : `GET /api/v1/flight-summary` gagne un champ `generation`
  (entier ≥ 1). Le contrat WebView, lui, n'expose pas la génération : la
  commande Tauri `flight_summary` rend `{ contractVersion, state, blockMinutes,
  attachedDispatchId }` où `attachedDispatchId` est l'UUID armé pour la
  génération courante, ou `null` si rien n'est armé ou si la génération a
  changé.
- **Armement** : nouvelle commande Tauri `flight_summary_arm` invocable par la
  WebView avec un `dispatchId` UUID canonique : elle réarme le bridge puis
  enregistre `{ génération retournée ↔ dispatchId }` en mémoire du processus.
  L'application arme au départ du vol (succès de `flight-start`), jamais à la
  clôture.

## Dependencies

- F0004 fusionnée (PR #128 et #130) — la mesure, le contrat local et la
  commande `flight_summary` existent ;
- décision d'Andy du 7 août 2026 (KI-028) : **prise, prérequis de F0002** ;
- décision de séquencement d'Andy du 7 août 2026 : **« go 1 », câblage
  d'abord**.

## Allowed areas

- `apps/bridge/` (télémétrie, contrat local, serveur) et `tests/bridge/` ;
- `apps/desktop/src-tauri/src/` (commandes `flight_summary` et
  `flight_summary_arm`) ;
- `tests/desktop-shell/run.ps1` — la règle « une seule commande IPC » de
  F0004 J2 devient « deux commandes fermées », avec la signature exacte de
  chacune (ajouté aux Allowed areas le 7 août 2026 : omission de rédaction,
  le gate évolue avec l'unité qui le concerne) ;
- `apps/desktop/src/features/flight-dispatch/` ;
- `eng/authority-inventory.json` ;
- `docs/SECURITY.md`, `docs/ARCHITECTURE.md`, `docs/QUALITY.md`,
  `docs/CURRENT_STATE.md`, `docs/KNOWN_ISSUES.md` ;
- ce fichier et `docs/features/README.md`.

## Do not touch

- `supabase/` : aucun changement serveur — le rattachement est local ;
- la politique de règlement et tout ce que F0002 interdit déjà ;
- le jeton du contrat local et sa non-exposition à la WebView (T0054/F0004) ;
- toute cible distante, toute donnée réelle.

## Non-goals

- KI-027 — la production autonome d'une mesure par l'application intégrée
  (trace replay fournie au bridge par le superviseur, premier abonné créé par
  l'application) : gap distinct, avec ses propres décisions produit (d'où vient
  la trace de l'alpha ?), suivi par sa propre unité ;
- la consommation de la mesure rattachée par la clôture : c'est le branchement
  de F0002 (PR #131) après fusion de cette unité ;
- MSFS réel (F0003/T0059), détection de phases, reprise après crash.

## Jalons

### J1 — Le bridge mesure par générations réarmables

Status: Done
Risk: Medium
Security-sensitive: Yes
Autonomous: No

- résultat : le résumé porte `generation` ; `POST /api/v1/flight-summary/rearm`
  (jeton requis) refuse en pleine mesure, sinon crée un tracker neuf,
  incrémente la génération et rejoue la source replay ; deux vols d'affilée
  produisent deux mesures distinctes, chacune sous sa génération.
- frontière : contrat local loopback du bridge.
- validations : `pnpm bridge:build`, `pnpm bridge:test` (harnais .NET, cas
  nouveaux : réarmement refusé en streaming, générations distinctes, rejeu de
  la trace, jeton exigé sur rearm).
- revue : vérifier qu'aucune identité métier n'entre dans le bridge et que le
  réarmement ne peut pas effacer une mesure en cours.

### J2 — Tauri arme, rattache et ne laisse rien fuir

Status: Done
Risk: Medium
Security-sensitive: Yes
Autonomous: No

- résultat : `flight_summary_arm(dispatchId)` valide l'UUID, réarme le bridge
  et mémorise génération ↔ dispatch ; `flight_summary` rend
  `attachedDispatchId` (ou `null` sur génération inconnue ou changée) ; ni
  jeton, ni port, ni génération, ni chemin ne traversent la WebView.
- frontière : commandes Tauri (WebView non fiable).
- validations : tests Rust des deux commandes (armement, mismatch de
  génération, UUID refusé, non-fuite), `pnpm desktop:check`.
- revue : chercher toute fuite du contrat local et tout moyen pour la WebView
  de forger un rattachement sans départ réel.

### J3 — L'application arme au départ et affiche la mesure rattachée

Status: Done
Risk: Low
Security-sensitive: No
Autonomous: No

- résultat : le départ d'un vol arme la mesure pour son dispatch (échec
  non bloquant si le shell est absent) ; l'affichage du temps de bloc n'est
  rendu que sur la ligne dont le dispatch est rattaché — la garde « un seul vol
  actif » de la PR #130 est remplacée par le rattachement exact ; le libellé
  « Dernière mesure de replay de la session » disparaît au profit de la mesure
  attribuée.
- frontière : desktop React.
- validations : `pnpm frontend:typecheck`, `pnpm frontend:test`,
  `pnpm frontend:coverage`, `pnpm frontend:build`, `pnpm authority:check`.
- revue : vérifier qu'une mesure d'un vol précédent ne peut plus s'afficher ni
  s'attribuer à un autre vol.

## Acceptance criteria

- [x] Deux vols d'affilée dans la même session produisent deux mesures
      distinctes, chacune attribuée à son dispatch (tests bridge « rearm opens
      a fresh measurement », panneau à deux vols actifs ; le parcours manuel
      sur harnais replay reste à Andy).
- [x] Une relecture après un vol suivant ne rend jamais la mesure du vol
      précédent comme si elle appartenait au vol courant (rattachement `null`
      sur génération changée, affichage fail-closed).
- [x] Réarmer en pleine mesure est refusé et ne perd rien (409, mesure
      poursuivie, prouvé au harnais bridge).
- [x] Le jeton, le port et la génération ne traversent jamais la WebView ;
      aucune identité métier n'entre dans le bridge.
- [x] Le réarmement exige le jeton du contrat local (401 anonyme au harnais).
- [x] La documentation décrit la capacité livrée et ce qui reste absent
      (KI-027).

## Security review

Jalons concernés : **J1 et J2**.

- actifs/données : intégrité de la mesure qui alimentera un règlement
  financier (F0002) ; jeton du contrat local.
- frontières : contrat loopback du bridge (rearm = nouvelle surface
  d'écriture) ; commandes Tauri exposées à une WebView non fiable.
- abus : forger un rattachement pour faire payer la mesure d'un autre vol ;
  réarmer pour effacer ou tronquer une mesure ; sonder le contrat local depuis
  la WebView ; épuiser le bridge par réarmements répétés.
- contrôles : rearm derrière le jeton détenu par Tauri seul ; refus en pleine
  mesure ; le rattachement n'est écrit que par Tauri sur un armement explicite
  et l'application n'arme qu'au départ d'un vol ; la WebView ne voit ni jeton,
  ni port, ni génération.
- résidu : la WebView peut armer un dispatch arbitraire (elle est non fiable
  par principe) — le serveur reste l'autorité finale par
  `min(déclaré, écoulé)` et l'appartenance du dispatch est vérifiée par
  `close_flight` ; le rattachement local est une garantie d'attribution UX,
  pas une autorité financière.

## Maintenance review

- dettes applicables : KI-027 (hors périmètre, reste ouverte), KI-028 (cette
  unité la résout côté mesure) ;
- dette créée : le mapping génération ↔ dispatch vit en mémoire du processus
  Tauri — un redémarrage de l'application perd le rattachement (le vol reste
  clôturable après réarmement + nouveau replay ; à consigner) ;
- contrôle manuel à automatiser : le scénario deux-vols-d'affilée sur le
  harnais replay.

## Automated validation

- `pnpm bridge:build`, `pnpm bridge:test` ;
- `pnpm desktop:check`, `pnpm desktop:test` ;
- `pnpm frontend:typecheck`, `pnpm frontend:test`, `pnpm frontend:coverage`,
  `pnpm frontend:build` ;
- `pnpm authority:check`, `pnpm data-policy:check`, `pnpm maintenance:check`.

## Manual verification

Sur le harnais replay (wrapper `THRUSTLINE_BRIDGE_PATH`, méthode du parcours
F0004 du 7 août 2026) : mesurer un vol, le voir attribué à sa ligne ; démarrer
un second vol, vérifier que la mesure précédente ne s'affiche plus pour lui,
réarmer par le départ et mesurer à nouveau.

## Rollback

Avant fusion, abandonner la branche. Après fusion : retirer l'endpoint rearm et
le champ `generation` ramène le contrat local à F0004 ; les commandes Tauri et
l'affichage reviennent au comportement « un seul vol actif » de la PR #130.
Aucune donnée persistée nulle part.

## Completion Report

### J1

- résultat obtenu : le résumé du contrat local porte une `generation` ;
  `POST /api/v1/flight-summary/rearm` (jeton requis) refuse en pleine mesure
  (409) et ouvre sinon une session neuve — tracker recréé, génération
  incrémentée, source replay rejouée par le service de publication en boucle.
- fichiers modifiés : `TelemetryPublisher.cs`, `TelemetryPublicationService.cs`,
  `FlightSummaryTracker.cs` (lecture `FlightSummaryReading`),
  `BridgeContract.cs`, `BridgeServer.cs`, `tests/bridge/Program.cs`.
- commandes et résultats : `pnpm bridge:build` 0 avertissement ;
  `pnpm bridge:test` 37/37, dont trois cas nouveaux (réarmement refusé en
  streaming, deux vols d'affilée sous deux générations, contrat HTTP du rearm
  avec 401 anonyme et second `completed` en génération 2).
- vérification manuelle : relevé des 37 PASS du harnais.
- revue et constats traités : `RunAsync` garde sa sémantique une-passe (aucun
  test existant réécrit) ; c'est le service hôte qui boucle. Un signal de
  réarmement précédant l'attente est consommé sans perte (`_rearmPending`).

### J2

- résultat obtenu : `flight_summary_arm(dispatchId)` valide l'UUID canonique,
  réarme le bridge et mémorise génération ↔ dispatch en mémoire du processus ;
  `flight_summary` projette `attachedDispatchId` (`null` sur génération
  inconnue ou changée). Ni jeton, ni port, ni génération ne traversent.
- fichiers modifiés : `flight_summary.rs`, `bridge.rs`, `lib.rs`,
  `tests/desktop-shell/run.ps1` (deux commandes fermées, signatures exactes).
- commandes et résultats : `cargo test` 21/21 ; `pnpm desktop:check`
  (typecheck, fmt, check, clippy -D warnings) vert ; harnais du shell vert.
- vérification manuelle : néant (couverte par les serveurs factices Rust).
- revue et constats traités : la génération est absente du type sérialisable
  qui traverse (`FlightSummary`), pas seulement omise — un test épingle sa
  non-traversée ; le refus 409 du bridge remonte en catégorie fermée
  `rejected`.

### J3

- résultat obtenu : le départ d'un vol arme la mesure pour son dispatch (échec
  non bloquant, jamais avant un départ réussi) ; l'affichage n'attribue une
  mesure qu'à la ligne rattachée et échoue fermé sinon — la garde « un seul
  vol actif » de la PR #130 est remplacée par le rattachement exact.
- fichiers modifiés : `flightSummary.ts` (+`attachedDispatchId`),
  `flightSummaryArm.ts` (nouveau), `flightSummaryShell.ts` (invoke à
  arguments), `FlightSummaryControl.tsx`, `DispatchStartControl.tsx`,
  `DispatchListPanel.tsx`, `HomePage.tsx`, `security-invariants.test.ts`,
  tests associés, `eng/authority-inventory.json`.
- commandes et résultats : typecheck vert, 427 tests frontend verts,
  couverture 94,86 % lignes / 90,13 % branches, build vert,
  `authority:check`, `data-policy:check`, `maintenance:check` verts.
- vérification manuelle : à faire par Andy — scénario deux-vols-d'affilée sur
  le harnais replay (méthode du parcours F0004 du 7 août 2026).
- revue et constats traités : une mesure d'un vol précédent ne peut plus
  s'afficher pour un autre vol — prouvé sur le panneau à deux vols actifs et
  sur le contrôle avec rattachement divergent ou nul.

### Synthèse

Les deux prérequis de F0002 consignés par KI-028 sont livrés : le tracker se
réarme par générations et la mesure est rattachée à son vol, sans qu'aucune
identité métier n'entre dans le bridge ni qu'aucun secret ne traverse la
WebView. Trois jalons, trois commits ; 37 tests bridge, 21 tests Rust,
427 tests frontend.

### Risks and limitations

- Le rattachement vit en mémoire du processus Tauri : un redémarrage de
  l'application le perd — le vol reste mesurable en réarmant (nouveau départ
  impossible : armer à nouveau exige... le départ ; en pratique la mesure du
  vol en cours est perdue au redémarrage, comme avant F0006).
- Une WebView compromise peut armer un dispatch arbitraire : le rattachement
  est une attribution d'affichage, jamais une autorité financière — le serveur
  conserve `min(déclaré, écoulé)` et l'appartenance du dispatch (T0051).
- KI-027 reste ouvert : sans harnais externe, l'application intégrée ne
  produit toujours pas de mesure par elle-même.

### Follow-ups

- Brancher la clôture F0002 (PR #131) sur `attachedDispatchId` après fusion :
  exiger le rattachement au dispatch clôturé avant d'envoyer le rapport.
- KI-027 : unité dédiée à la production autonome d'une mesure (trace replay
  fournie par le superviseur, premier abonné créé par l'application).

### Documentation updated

`docs/SECURITY.md` (contrat local par générations, deux commandes IPC),
`docs/ARCHITECTURE.md` (section « Cycle de mesure rattaché et réarmable »),
`docs/QUALITY.md` (preuves F0006), `docs/KNOWN_ISSUES.md` (KI-028 résolue par
F0006), `docs/CURRENT_STATE.md`, `docs/features/README.md`, ce fichier.
