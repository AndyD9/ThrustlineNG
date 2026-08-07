# F0004 — Voir le temps de bloc mesuré de son vol en replay

Status: In progress
Owner: Agent (session du 6 août 2026)
Branch: `feature/f0004-mesurer-le-temps-de-bloc-du-vol-replay`
PR: [#128](https://github.com/AndyD9/ThrustlineNG/pull/128) (ouverte, passée
« ready for review » le 6 août 2026, base `main` ; checks verts le 7 août 2026
sur la tête J1+J2+J3 `18e8a5f` : Windows multi-stack — bridge et budgets
inclus —, Supabase PostgreSQL 17, Audits/licences/SBOM — relancés après
l'incident GitHub Actions du 6 août qui avait perdu les événements de push)
Phase: 3–4
Risk: Medium
Security-sensitive: Yes
Autonomous: No

## Goal

À la fin d'un vol joué en replay, la personne voit dans l'application le temps
de bloc mesuré par la télémétrie — la valeur qui alimentera le rapport de
clôture, au lieu d'une saisie manuelle.

## Context

La décision d'Andy du 6 août 2026 (option C, consignée dans F0002) : le temps de
vol d'un rapport de clôture vient de la télémétrie, jamais d'une saisie ni d'une
migration. Or rien ne relie aujourd'hui la télémétrie au cycle de vol : T0054
publie `telemetry.v1` sur le contrat local du bridge (SignalR loopback, jeton
d'instance détenu par Tauri et jamais exposé à la WebView), et F0001 fait
décoller un vol sans rien savoir de la télémétrie. F0002 est `Blocked` sur ce
chaînon : cette fonctionnalité est le chemin critique du jalon « alpha
cliquable ».

Le serveur reste l'autorité finale : `close_flight` retient
`min(temps déclaré, temps écoulé serveur)` (T0051). Le temps de bloc mesuré ici
est donc une **déclaration mieux fondée**, pas une autorité nouvelle — un client
trafiqué qui surdéclare ne gagne rien, exactement comme pour une saisie.

Trois frontières existantes cadrent la solution : le bridge voit les
échantillons (c'est lui qui mesure) ; le processus Tauri détient le jeton du
contrat local (c'est lui qui interroge le bridge) ; la WebView n'a jamais accès
ni au jeton ni au port (elle reçoit un résumé typé par commande Tauri).

## Décision attendue d'Andy

**Décision prise le 6 août 2026 : mesure « mouvement → sol ».** Le temps de
bloc va du premier échantillon en mouvement (vitesse sol non nulle ou airborne)
au dernier retour au sol de la trace, arrondi à la minute supérieure, minimum
une minute ; une trace sans retour au sol rend un état « incomplet » sans temps
de bloc inventé. Le statut passe `Ready`.

**Précision confirmée par Andy le 6 août 2026 (revue J1) :** `completed` exige
une trace terminée au sol. Un touch-and-go dont la trace finit en vol reste
`incomplete`, sans temps de bloc, même si un retour au sol a été observé.

## Dependencies

- T0054 — télémétrie replay bornée sur le contrat local (`Done`) ;
- T0010 — contrat local REST/SignalR à jeton (`Done`) ;
- F0001 — départ de vol depuis l'application (fusionnée, PR #124/#126) ;
- décision d'Andy ci-dessus : **prise le 6 août 2026** (mouvement → sol).

## Allowed areas

- `apps/bridge/` — mesure du temps de bloc et exposition additive sur le
  contrat local, avec ses tests ;
- `apps/desktop/src-tauri/` — commande Tauri de lecture du résumé, le jeton
  restant côté Rust ;
- `apps/desktop/src/features/flight-dispatch/` — affichage du résumé rattaché
  au vol actif ;
- `apps/desktop/src/pages/HomePage.tsx` — **ajout au J3, à valider par Andy en
  revue** : simple passage de la commande de mesure vers la liste des
  dispatchs, aucune logique ni accès aux données ;
- `tests/backend/run.ps1` seulement si une règle de gate est ajoutée ;
- `tests/desktop-shell/run.ps1` et
  `apps/desktop/src/test/security-invariants.test.ts` — **ajout au J2, à
  valider par Andy en revue** : ces deux harnais interdisaient toute commande
  `#[tauri::command]` (baseline T0007), or le résultat J2 est précisément la
  première commande ; la règle est resserrée, pas retirée — exactement une
  commande, `flight_summary`, sans paramètre invité ;
- `docs/SECURITY.md`, `docs/ARCHITECTURE.md`, `docs/QUALITY.md`,
  `docs/CURRENT_STATE.md`, `docs/KNOWN_ISSUES.md` ;
- ce fichier et `docs/features/README.md`.

## Do not touch

- `public.close_flight`, le barème de règlement et le grand livre : la
  consommation du temps mesuré dans un rapport de clôture appartient à F0002 ;
- le protocole `telemetry.v1`, sa cadence et ses bornes T0054 ;
- l'adaptateur SimConnect natif et T0059/F0003 ;
- toute cible distante, toute donnée réelle.

## Non-goals

- clôturer le vol ou créer le rapport : F0002, débloquée par cette capacité ;
- détection fine des phases de vol, reprise après crash, persistance d'un vol ;
- télémétrie MSFS réelle : la source replay est le périmètre de l'alpha ;
- associer plusieurs vols ou plusieurs sources : un vol actif, une trace, un
  résumé. L'exclusivité serveur étant **par avion** (index
  `flight_dispatches_one_open_per_aircraft`, T0051), plusieurs vols actifs
  sont possibles : l'affichage est alors fail-closed (aucune mesure rendue,
  constat de la revue adversariale du 7 août 2026).

## Jalons

### J1 — Le bridge mesure le temps de bloc d'une trace replay

Status: Done
Risk: Medium
Security-sensitive: No
Autonomous: Yes

- résultat : le bridge dérive des échantillons replay un résumé de vol —
  état (`idle`, `running`, `completed`, `incomplete`), temps de bloc en
  minutes selon la règle décidée par Andy — et l'expose en lecture seule,
  additive et versionnée, sur le contrat local existant, derrière le même
  jeton. Aucun échantillon n'est persisté.
- frontière : contrat local du bridge (T0010/T0054).
- validations : `pnpm bridge:build`, `pnpm bridge:test` (scénarios : trace
  nominale, trace sans retour au sol, trace vide, arrondi et minimum),
  `pnpm bridge:health`, budgets de performance.
- revue : chercher une divergence entre la règle décidée et la mesure, et
  toute fuite du chemin de trace ou du jeton dans le résumé.

### J2 — Tauri relaie le résumé sans exposer le contrat local

Status: Done
Risk: Medium
Security-sensitive: Yes
Autonomous: No

- résultat : une commande Tauri lit le résumé sur le contrat local — le jeton
  et le port restent côté Rust — et rend à la WebView un objet typé strictement
  validé. La WebView n'apprend ni le port, ni le jeton, ni le chemin de trace.
- frontière : frontière de confiance Tauri ↔ WebView.
- validations : `pnpm desktop:check`, `pnpm desktop:test` (dont un test qui
  prouve que le jeton ne traverse pas), `pnpm frontend:typecheck`.
- revue : chercher tout chemin par lequel la WebView atteindrait le contrat
  local directement ou apprendrait le jeton.

### J3 — L'application affiche le temps de bloc du vol actif

Status: Done
Risk: Low
Security-sensitive: No
Autonomous: Yes

- résultat : quand un vol est `active` et que le replay est terminé, la ligne
  du vol affiche le temps de bloc mesuré, prêt pour la clôture F0002 ; aucun
  appel au rendu, états explicites (en cours, terminé, incomplet,
  indisponible).
- frontière : desktop React.
- validations : `pnpm frontend:typecheck`, `pnpm frontend:test`,
  `pnpm frontend:coverage`, `pnpm frontend:build`, `pnpm authority:check`.
- revue : vérifier que l'affichage vient exclusivement du résumé typé et
  qu'aucun temps n'est calculé dans la WebView.

## Acceptance criteria

- [x] Une trace replay jouée de bout en bout produit un temps de bloc conforme
      à la règle décidée, visible dans l'application sur le vol actif (parcours
      complet du 7 août 2026, détail au Completion Report J3 ; le déclenchement
      du replay a exigé un harnais externe — voir `KI-027`).
- [x] Une trace sans retour au sol rend un état « incomplet » explicite, sans
      temps de bloc inventé (prouvé J1 sur le bridge, affiché J3 sans temps).
- [x] Le jeton d'instance et le port du contrat local ne traversent jamais la
      frontière WebView, prouvé par un test (J2, serveur factice côté Rust).
- [x] Le résumé est additif sur le contrat local : les consommateurs T0054
      existants sont inchangés (J1, tests bridge 34/34).
- [x] La documentation décrit la capacité et ses limites (mesure replay
      uniquement, un vol à la fois, serveur toujours autorité du règlement).

## Security review

Jalon concerné : **J2**.

- actifs/données : jeton d'instance du contrat local, port loopback ;
- frontière : Tauri ↔ WebView (la WebView est un client non fiable) ;
- abus : exfiltrer le jeton ou le port par la commande, faire interroger une
  autre cible que le bridge de l'instance, injecter un résumé forgé ;
- validation/autorisation : commande sans paramètre de cible, réponse validée
  par jeu de clés strict avant de traverser ;
- atomicité/idempotence : lecture seule, sans effet ;
- logs/vie privée : ni jeton, ni port, ni chemin de trace dans les logs ou la
  WebView.

## Maintenance review

- dettes et problèmes connus applicables : `KI-009`, `KI-011`, `KI-015`
  (télémétrie réelle absente — inchangés, cette capacité est replay) ;
- dette créée ou aggravée : le résumé de vol est une deuxième lecture dérivée
  de la même trace ; si T0059 introduit la source native, la règle de mesure
  doit être revalidée sur des échantillons réels ;
- règle de sécurité ajoutée : la frontière Tauri ↔ WebView du résumé dans
  `SECURITY.md` ;
- contrôle manuel à automatiser : la mesure sur trace nominale est un test
  unitaire dès J1 ;
- risque résiduel : le temps mesuré reste une déclaration côté client du point
  de vue du serveur ; `min(déclaré, écoulé)` de T0051 reste la borne.

## Automated validation

```powershell
pnpm bridge:build
pnpm bridge:test
pnpm bridge:health
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

1. J1 : rejouer la trace synthétique T0011 et relever le résumé sur le contrat
   local (jeton requis) ; vérifier l'état `incomplete` sur une trace tronquée.
2. J2 : depuis la WebView dev, appeler la commande et confirmer qu'aucun jeton
   ni port n'apparaît dans le résultat ni dans les outils réseau.
3. J3 : parcours complet — départ F0001, replay joué, temps de bloc affiché
   sur le vol actif.

## Rollback

Avant fusion, abandonner la branche. Après fusion, retirer le résumé, la
commande et l'affichage laisse T0054 et F0001 exactement dans leur état
actuel ; aucune donnée n'est persistée par cette capacité. Retour partiel
cohérent après chaque jalon.

## Completion Report

Un bloc par jalon, rempli au moment de son commit, puis une synthèse.

### J1

- résultat obtenu : le bridge dérive des échantillons replay validés un résumé
  de vol — `idle`, `running`, `completed`, `incomplete`, temps de bloc en
  minutes selon la règle « mouvement → sol » (arrondi supérieur, minimum une
  minute) — exposé en lecture seule sur `GET /api/v1/flight-summary`, additif
  et versionné (`contractVersion` 1), derrière le jeton d'instance. Aucun
  échantillon persisté : le tracker ne retient que deux instants et le dernier
  état au sol. Sémantique fermée : `completed` exige une trace finie au sol ;
  un touch-and-go finissant en vol, un taxi seul, une trace vide ou une
  lecture interrompue restent `incomplete` sans temps inventé.
- fichiers modifiés : `apps/bridge/Telemetry/FlightSummaryTracker.cs`
  (nouveau), `apps/bridge/Telemetry/TelemetryPublisher.cs`,
  `apps/bridge/BridgeContract.cs`, `apps/bridge/BridgeServer.cs`,
  `tests/bridge/Program.cs` (9 tests), `docs/ARCHITECTURE.md`,
  `docs/SECURITY.md`, `docs/QUALITY.md`, `docs/CURRENT_STATE.md`, ce fichier
  et `docs/features/README.md`.
- commandes et résultats (6 août 2026) : `pnpm bridge:build` — succès,
  0 avertissement ; `pnpm bridge:test` — 34/34 dont 9 nouveaux (nominale
  6 minutes exactes, arrondi 100 s → 2 min, plancher 1 min, sans retour au
  sol, touch-and-go finissant en vol, taxi seul, départ en vol, trace vide,
  interruption) ; `pnpm bridge:health` — Healthy ;
  `performance:measure:bridge` puis `check-performance-budgets` — passed ;
  `pnpm maintenance:check` — passed ; `pnpm authority:check` — passed.
- vérification manuelle : exécutée le 6 août 2026 sur le binaire publié
  (win-x64 self-contained) — sans jeton → 401 ; trace dorée T0011 rejouée par
  un abonné WebSocket réel → `completed`, `blockMinutes: 1` (mouvement à 1 s,
  retour au sol à 7 s, plancher d'une minute) ; trace tronquée finissant en
  vol → `incomplete`, `blockMinutes: null` ; corps brut sans jeton ni chemin
  de trace.
- revue et constats traités : revue adversariale du 6 août 2026 par un agent
  séparé — 0 bloquant, 1 majeur, 7 mineurs. Le majeur (touch-and-go finissant
  en vol rendu `completed` avec un temps arrêté au toucher) est fermé :
  `completed` exige désormais une trace terminée au sol, choix « fail closed »
  **confirmé par Andy le 6 août 2026**. Mineurs corrigés : résumé rendu terminal avant l'état du health
  check (ordre de `Transition`), tracker repassé `internal`, cas
  touch-and-go/taxi/départ en vol testés, documentation alignée (interruption
  sans aucun échantillon reste `idle`). Dette notée : le tracker est mono-vol
  et définitivement terminal — un futur redémarrage du publisher (T0059)
  devra le réarmer.

### J2

- résultat obtenu : l'unique commande IPC du shell, `flight_summary` —
  asynchrone, lecture seule, aucun paramètre fourni par la WebView — lit
  `GET /api/v1/flight-summary` sur le contrat local. Le port et le jeton
  restent des champs privés du superviseur Rust (le client HTTP est un
  `TcpStream` std en HTTP/1.0 borné à 16 KiB avec délais, sans nouvelle
  dépendance réseau ; seuls `serde`/`serde_json`, déjà transitifs de Tauri,
  deviennent des dépendances directes épinglées). La réponse est revalidée
  par jeu de clés strict avant de traverser : exactement `{contractVersion,
  state, blockMinutes}`, version `1`, états fermés, temps de bloc entier ≥ 1
  seulement si `completed`. Les échecs se réduisent à `unavailable` et
  `invalid-response`, sans contenu dynamique. Côté WebView,
  `flightSummary.ts` revalide le même contrat et ne dépend que d'une fonction
  `invoke` injectée (le câblage réel appartient à J3). La capability reste à
  zéro permission. **Écart de périmètre consigné dans `Allowed areas`** : les
  deux harnais d'invariants du shell interdisaient toute commande IPC et ont
  été resserrés au strict périmètre J2 (une seule commande, `flight_summary`,
  sans paramètre invité) — à valider par Andy en revue.
- fichiers modifiés : `apps/desktop/src-tauri/src/flight_summary.rs`
  (nouveau), `apps/desktop/src-tauri/src/bridge.rs`,
  `apps/desktop/src-tauri/src/lib.rs`, `apps/desktop/src-tauri/Cargo.toml`,
  `Cargo.lock` (+2 lignes),
  `apps/desktop/src/features/flight-dispatch/flightSummary.ts` (+ tests et
  invariants, nouveaux), `apps/desktop/src/test/security-invariants.test.ts`,
  `tests/desktop-shell/run.ps1`, `docs/SECURITY.md`, `docs/ARCHITECTURE.md`,
  `docs/QUALITY.md`, `docs/CURRENT_STATE.md`, ce fichier et
  `docs/features/README.md`.
- commandes et résultats (6 août 2026) : `pnpm desktop:check` — succès
  (typecheck, fmt, check, clippy `-D warnings`) ; `pnpm desktop:test` —
  vitest 383/383 (dont 24 nouveaux sur le résumé), cargo 15/15 (dont 12
  nouveaux : validation stricte, non-200, port fermé, serveur factice
  prouvant que le jeton authentifie la requête sans traverser dans le
  résultat), invariants du shell conformes ; `pnpm frontend:typecheck` —
  succès ; `pnpm frontend:coverage` — 94,87 % ; `pnpm desktop:build` —
  succès ; `pnpm authority:check` et `pnpm maintenance:check` — passed.
- vérification manuelle : exécutée le 6 août 2026 sur l'app Tauri dev (bridge
  publié win-x64 via `THRUSTLINE_BRIDGE_PATH`, WebView2 inspectée par CDP) :
  `invoke('flight_summary')` depuis la WebView rend
  `{"contractVersion":"1","state":"idle","blockMinutes":null}` ; aucun jeton
  hexadécimal ni port dynamique dans le résultat ; les outils réseau ne
  voient que le transport IPC interne `http://ipc.localhost/flight_summary`,
  jamais le port du bridge.
- revue et constats traités : revue adversariale à la charge de la PR #128 ;
  points à examiner en priorité : l'assouplissement borné des deux harnais
  d'invariants et le parseur HTTP/1.0 manuel de `flight_summary.rs`.

### J3

- résultat obtenu : la ligne du vol `active` de « Mes dispatchs » porte
  `FlightSummaryControl` : lecture du résumé sur action explicite — jamais au
  rendu, prouvé par test — et quatre états explicites : replay en cours, temps
  de bloc mesuré en minutes pour un replay terminé, trace incomplète sans
  temps inventé, indisponibilité en alerte avec retry ; l'état `idle` est rendu
  « aucun replay mesuré ». Le câblage réel de l'`invoke`, différé par le J2,
  vit dans `flightSummaryShell.ts` — seul module qui touche
  `window.__TAURI_INTERNALS__.invoke` et qui ne transmet que le nom de la
  commande, sans aucun autre argument (invariant testé) ; hors du shell Tauri,
  l'échec est classé `unavailable`. La WebView ne calcule aucun temps :
  `blockMinutes` est affiché tel que revalidé par `readFlightSummary`
  (invariant testé). **Écart de périmètre consigné dans `Allowed areas`** :
  `HomePage.tsx` passe la commande de mesure à la liste des dispatchs — simple
  transmission de prop, à valider par Andy en revue.
- fichiers modifiés :
  `apps/desktop/src/features/flight-dispatch/FlightSummaryControl.tsx` et
  `flightSummaryShell.ts` (nouveaux, avec leurs tests),
  `DispatchListPanel.tsx`, `apps/desktop/src/pages/HomePage.tsx`,
  extensions de `DispatchListPanel.test.tsx`, `homeComposition.test.tsx` et
  `flightSummary.invariants.test.ts`, `docs/ARCHITECTURE.md`,
  `docs/QUALITY.md`, `docs/CURRENT_STATE.md`, `docs/KNOWN_ISSUES.md`
  (`KI-027`, découverte de la vérification manuelle), ce fichier et
  `docs/features/README.md`.
- commandes et résultats (6 août 2026) : `pnpm frontend:typecheck` — succès ;
  `pnpm frontend:test` — vitest 401 passés, 2 ignorés préexistants (18
  nouveaux : contrôle d'affichage, câblage shell, rattachement à la seule
  ligne active, composition d'accueil sans réseau, invariants J3) ;
  `pnpm frontend:coverage` — 94,81 % ; `pnpm frontend:build` — succès ;
  `pnpm authority:check` — passed ; `pnpm maintenance:check` — passed.
- vérification manuelle : **exécutée le 7 août 2026**, parcours complet piloté
  par CDP sur l'app Tauri dev (pile Supabase locale isolée, bridge publié
  win-x64, WebView2 inspectée sur le port de débogage) : login (identité
  synthétique Admin API) → création de compagnie → achat « Synthetic Cessna
  172 » → brouillon LFPG → LFBO → départ F0001 (« En vol », heure serveur) →
  clic « Afficher le temps de bloc » rendant l'état explicite « Aucun replay
  mesuré pour l'instant. » (résumé `idle` réel via la commande Tauri) → replay
  de la trace dorée T0011 déclenché par un abonné WebSocket réel sur le
  contrat local (`completed`, `blockMinutes: 1` côté bridge) → clic
  « Actualiser la mesure » rendant **« Temps de bloc mesuré : 1 min. »** sur
  la ligne du vol actif. Balayage anti-fuite : ni jeton d'instance, ni port du
  bridge, ni chaîne hex 64 dans le DOM ; le réseau WebView n'a vu que Vite,
  Supabase loopback et l'IPC interne — zéro requête vers le port du bridge.
  **Harnais requis** : le superviseur Tauri lance le bridge sans trace et rien
  dans l'app ne s'abonne au hub ; la trace dorée a été injectée par un wrapper
  `THRUSTLINE_BRIDGE_PATH` et le replay déclenché par un abonné externe —
  découverte consignée en `KI-027`.
- revue et constats traités : revue adversariale du 7 août 2026 par un agent
  séparé sur le périmètre J2+J3 — 0 bloquant, 4 majeurs, 5 mineurs. Corrigés
  sur la branche : la prémisse « mono-vol par construction (T0050) » était
  fausse (l'exclusivité est par avion — affichage rendu fail-closed quand
  plusieurs vols sont actifs, documentation corrigée) ; les deux harnais
  d'invariants ne lisaient pas les sous-modules Rust (`-Recurse` ajouté,
  motif d'attribut sans crochet fermant côté vitest) ; l'unicité du
  consommateur `__TAURI_INTERNALS__` n'était affirmée que par la
  documentation (balayage récursif ajouté aux invariants) ; deux documents de
  suivi contredisaient le parcours manuel exécuté (alignés). Restent,
  consignés sans correction : l'arbitrage d'Andy sur le résumé terminal relu
  après un vol suivant (risque résiduel ci-dessous), et trois mineurs sur le
  client HTTP du shell (corps délimité par la seule fermeture de connexion,
  pas de budget de durée totale, dépassement de borne rendu `unavailable` au
  lieu d'`invalid-response`) — code sécurité J2, à retoucher sous revue et
  non à la volée. L'écart `HomePage.tsx` est confirmé sans logique (seam de
  test, la production passe par le défaut). **Arbitrage du constat séquentiel
  rendu par Andy le 7 août 2026** (plusieurs vols d'affilée requis) :
  libellé sans rattachement « Dernière mesure de replay de la session » +
  `KI-028` faisant du rattachement résumé ↔ vol et du réarmement du tracker
  des prérequis de F0002.

### Synthèse

Les trois jalons sont implémentés sur la PR #128 : le bridge mesure le temps
de bloc selon la règle « mouvement → sol » et l'expose additivement sur le
contrat local (J1), l'unique commande Tauri `flight_summary` relaie le résumé
revalidé sans exposer jeton ni port (J2), et l'application affiche le temps de
bloc sur la ligne du vol actif, sur action explicite et sans aucun calcul côté
WebView (J3). Le parcours manuel complet a été exécuté le 7 août 2026 (critère
d'acceptation 1, preuve au Completion Report J3). Restent, avant fusion : la
revue adversariale de la PR et la décision d'Andy.

### Risks and limitations

- Le câblage WebView repose sur `window.__TAURI_INTERNALS__.invoke`, API
  interne de Tauri 2 — le dépôt n'embarque pas `@tauri-apps/api` (pas de
  nouvelle dépendance) ; à revalider à chaque montée de version de Tauri.
- Le résumé du bridge est global et sans identité de vol : la liste l'affiche
  sur la ligne `active` sans que le bridge connaisse le dispatch.
  L'exclusivité serveur est par avion, pas par compagnie (revue adversariale
  du 7 août 2026) : deux vols actifs sont possibles, et l'affichage est alors
  fail-closed — le contrôle n'est rendu que lorsqu'exactement un vol est
  actif. Cas séquentiel (tracker terminal pour la session : un résumé
  `completed` d'un vol précédent est relu sur le vol suivant) — **décision
  d'Andy du 7 août 2026** : plusieurs vols d'affilée sont requis ; le libellé
  ne rattache donc pas la mesure au vol (« Dernière mesure de replay de la
  session : N min. ») et le rattachement résumé ↔ vol plus le réarmement du
  tracker sont des prérequis de F0002, consignés en `KI-028`.
- Le temps mesuré reste une déclaration côté client : `close_flight` conserve
  `min(déclaré, écoulé serveur)` (T0051).
- Mesure replay uniquement ; la source native (T0059/F0003) devra revalider la
  règle sur échantillons réels et réarmer le tracker terminal.

### Follow-ups

- `KI-027` : dans l'application intégrée, rien ne fournit de trace au bridge
  ni ne déclenche le replay (premier abonné) — le câblage du cycle de vol
  appartient à F0002 ou à une unité dédiée.
- F0002 consomme ce résumé pour la clôture depuis l'application.
- T0059 : réarmement du tracker terminal au redémarrage du publisher (dette
  J1).

### Documentation updated

`docs/ARCHITECTURE.md` (affichage J3 et câblage shell), `docs/QUALITY.md`
(couverture J3), `docs/CURRENT_STATE.md`, `docs/features/README.md` et ce
fichier.
