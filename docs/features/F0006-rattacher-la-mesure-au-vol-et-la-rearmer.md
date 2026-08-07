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

Status: Ready
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

Status: Ready
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

Status: Ready
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

- [ ] Deux vols d'affilée dans la même session produisent deux mesures
      distinctes, chacune attribuée à son dispatch.
- [ ] Une relecture après un vol suivant ne rend jamais la mesure du vol
      précédent comme si elle appartenait au vol courant.
- [ ] Réarmer en pleine mesure est refusé et ne perd rien.
- [ ] Le jeton, le port et la génération ne traversent jamais la WebView ;
      aucune identité métier n'entre dans le bridge.
- [ ] Le réarmement exige le jeton du contrat local.
- [ ] La documentation décrit la capacité livrée et ce qui reste absent
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
