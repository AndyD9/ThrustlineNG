# T0053 — Lire et actualiser les dispatchs depuis le desktop

Status: Review
Owner: Andy
Branch: `feature/T0053-desktop-dispatch-read`
Phase: 4
Risk: Medium
Security-sensitive: Yes

## Goal

Afficher les dispatchs de la compagnie du propriétaire depuis une lecture Data
API bornée et les réactualiser après une création, sans qu'aucun filtre de
propriété ne vienne du client.

## Context

T0052 crée un brouillon et en affiche la réponse immédiate, mais rien ne survit à
un rechargement de la page. T0046 fournit le patron exact : une lecture `GET`
constante, sans filtre de compagnie ou de propriétaire, dont l'autorité de
sélection reste la RLS T0047, plus un signal d'actualisation externe.

Ce ticket est resté `Draft` par ordre d'intégration du flux 3 : il n'entrait pas
en `Ready` avant que T0052 soit réellement fusionné dans `main`, afin de ne pas
créer une nouvelle branche empilée. Aucune autre décision produit n'est requise.

Condition de sortie satisfaite le 4 août 2026 : la Pull Request #94
`feature/T0052-dispatch-draft-composition` → `main` a été fusionnée par Andy dans
le commit de merge `9ea2493`, après ses trois checks verts. La branche
`feature/T0053-desktop-dispatch-read` part de ce `origin/main` et n'est donc pas
empilée.

## Dependencies

- T0038 — configuration publique et session en mémoire ;
- T0044 — aiguillage de l'accueil selon la présence de compagnie ;
- T0046 — patron de lecture Data API bornée et de refresh externe ;
- T0047 — table `flight_dispatches` et sa RLS ;
- T0052 — panneau de création, condition de sortie du `Draft`.

## Allowed areas

- `apps/desktop/src/features/flight-dispatch/` pour le transport de lecture, le
  panneau et leurs tests ;
- `apps/desktop/src/pages/HomePage.tsx` pour la composition et le signal
  d'actualisation ;
- `apps/desktop/src/styles/index.css` si nécessaire ;
- `eng/authority-inventory.json` ;
- `docs/ARCHITECTURE.md`, `docs/QUALITY.md`, `docs/CURRENT_STATE.md` ;
- ce ticket et `docs/tickets/README.md`.

## Do not touch

- migrations, RLS, commandes SQL et Edge Functions ;
- commande de création T0052 et son payload ;
- transports flotte, catalogue, présence de compagnie et achat ;
- CSP de production, persistance de session et stockage Windows ;
- Rust/Tauri, bridge, SimConnect, SimBrief et cycle de vol ;
- workflows, manifests, lockfiles, cible distante et données réelles.

## Requirements

### 1. Transport de lecture constant

- Émettre un `GET` unique vers `flight_dispatches` avec projection, ordre et
  limite constants, sans aucun filtre de compagnie, de propriétaire ou d'avion
  fourni par le client.
- Imposer une cible loopback `http:` sans identifiants, requête, fragment ni
  chemin, comme les trois transports existants.
- Borner la réponse lue et valider strictement chaque ligne : UUID, ICAO en
  quatre caractères, aéroports distincts, état appartenant à la liste connue,
  horodatage canonique et `schema_version` attendu.
- Refuser les doublons d'identifiant et toute ligne excédant la limite.
- Mapper les échecs vers `authentication-required`, `invalid-response` et
  `unavailable`, sans détail serveur.

### 2. Panneau et actualisation

- N'exécuter aucun appel réseau au rendu tant que la compagnie n'est pas connue.
- Obtenir le bearer depuis le gestionnaire de session au chargement et effacer la
  session sur refus Auth.
- Relire la source autoritaire après une création réussie, y compris si le signal
  arrive pendant une lecture en cours, sans construire localement le dispatch
  créé.
- Rendre explicitement l'absence de dispatch, l'état de chargement et l'échec,
  avec des libellés accessibles.
- Annuler proprement la requête au démontage.

### 3. Autorité et preuves

- L'inventaire déclare exactement un nouveau couple chemin/ressource pour cette
  lecture Data API et le gate d'autorité doit échouer sur toute ressource
  divergente, chemin dupliqué ou entrée orpheline.
- Les tests couvrent requête sans filtre client, projection, ordre, limite,
  taille bornée, schéma strict, doublons, liste vide, 401/403, panne, zéro réseau
  au rendu, concurrence, retry, démontage, actualisation après création et signal
  reçu pendant une lecture.

## Non-goals

- créer, démarrer, reprendre, annuler ou clôturer un dispatch ou un vol ;
- paginer, filtrer, trier côté client ou rechercher un dispatch ;
- afficher un effet financier, une route détaillée, une météo ou un OFP ;
- persister la session, ouvrir la CSP de production ou viser une cible distante.

## Acceptance criteria

- [x] T0052 est fusionné dans `main` avant le passage en `Ready` — PR #94,
      merge `9ea2493`, 4 août 2026.
- [x] La requête est un `GET` à projection, ordre et limite constants, sans
      aucun filtre de propriété client.
- [x] Une réponse hors schéma, hors bornes ou avec doublons est refusée sans
      rendu partiel.
- [x] L'accueil n'appelle rien au rendu, affiche une liste vide explicite et
      relit la source après une création réussie.
- [x] Un refus Auth efface la session et ramène vers la connexion.
- [x] Typecheck, tests frontend, couverture, build et gates applicables passent
      avec leurs compteurs réellement observés.

## Security review

- actifs : session utilisateur, existence et destinations des dispatchs ;
- frontière : WebView non fiable → Data API sous RLS T0047 ;
- abus : filtre de propriété forgé pour lire les dispatchs d'un tiers, réponse
  injectée, fuite de token dans le DOM ;
- validation/autorisation : requête constante, RLS comme unique autorité de
  sélection, validation stricte avant rendu ;
- atomicité/idempotence : sans objet, lecture seule ;
- logs/vie privée : aucun token, identifiant ou détail serveur journalisé.

## Maintenance review

- problèmes applicables : `KI-005` sur le mélange UI/données ; `KI-021` sur les
  données réelles ;
- dette créée : absence de pagination assumée tant que la limite constante
  couvre la flotte de l'alpha ;
- règle de sécurité : aucun filtre de propriété n'est fourni par un client ;
- contrôle manuel à automatiser : couvert par les espions réseau des tests ;
- risque résiduel : preuve jsdom et `fetch` injecté, sans WebView live.

## Automated validation

```powershell
pnpm.cmd frontend:typecheck
pnpm.cmd frontend:test
pnpm.cmd frontend:coverage
pnpm.cmd frontend:build
pnpm.cmd authority:check
pnpm.cmd data-policy:check
pnpm.cmd maintenance:check
git diff --check
```

## Manual verification

1. Rendre l'accueil sans session puis avec session et compagnie injectées.
2. Inspecter l'URL, les headers, la projection et la limite de l'unique requête.
3. Créer un dispatch et confirmer la relecture de la source autoritaire.
4. Injecter une réponse hors schéma, un 401 et une panne, puis vérifier les états
   rendus et l'absence de fuite.

Temps cible : 5–10 minutes.

## Rollback

Avant fusion, abandonner la branche. Après fusion, retirer le panneau de lecture
dans un ticket correctif ; aucune donnée serveur n'est modifiée.

## Completion Report

### Summary

La lecture durable des dispatchs est livrée dans un module séparé du module de
commande T0052, condition imposée par le gate d'autorité qui exige qu'un chemin
allowlisté n'utilise que `GET`. `loadDispatchList` émet un `GET` unique vers
`flight_dispatches` avec une projection, un ordre `created_at.desc,id.desc` et une
limite de cinquante lignes constants côté client, sans aucun paramètre de
compagnie, de propriétaire, d'avion ou d'état : la RLS `flight_dispatches_select_own`
de T0047 reste l'unique autorité de sélection. La cible reste loopback `http:`
sans identifiants, requête, fragment ni chemin, la requête est bornée à cinq
secondes et la réponse lue en flux à 64 Kio avec annulation dès le dépassement.

Chaque ligne est validée avant tout rendu : jeu de clés exact, UUID canoniques
pour le dispatch et l'avion, deux ICAO de quatre caractères ASCII majuscules et
distincts, état appartenant à `draft` ou `active` — la liste connue depuis la
contrainte `flight_dispatches_known_states` de T0050 —, horodatage canonique et
`schema_version` égal à `1`. La liste refuse tout tableau plus long que la limite
et tout doublon d'identifiant ou d'avion. Les échecs sont réduits à
`authentication-required`, `invalid-response` et `unavailable`, sans détail
serveur.

`DispatchListPanel` ne lit rien au rendu, obtient le bearer du gestionnaire T0038
au chargement, efface la session sur refus Auth, rend explicitement la liste vide,
le chargement et l'échec, et annule sa requête au démontage. L'accueil incrémente
un compteur d'actualisation à chaque création réussie ; le panneau relit alors la
source autoritaire au lieu de construire localement le dispatch créé, et un signal
reçu pendant une lecture en cours est rejoué à la fin de celle-ci.

### Files changed

- `apps/desktop/src/features/flight-dispatch/dispatchList.ts` — nouveau transport
  de lecture borné ;
- `apps/desktop/src/features/flight-dispatch/DispatchListPanel.tsx` — nouveau
  panneau de lecture et d'actualisation ;
- `apps/desktop/src/features/flight-dispatch/dispatchList.test.ts` — nouveau ;
- `apps/desktop/src/features/flight-dispatch/DispatchListPanel.test.tsx` —
  nouveau ;
- `apps/desktop/src/features/flight-dispatch/dispatchList.invariants.test.ts` —
  nouveau ;
- `apps/desktop/src/features/flight-dispatch/homeComposition.test.tsx` — deux
  scénarios de composition et d'actualisation ;
- `apps/desktop/src/features/flight-dispatch/FlightDispatchPanel.tsx` — rappel
  optionnel `onDraftCreated` uniquement ; la commande et le payload T0052 sont
  inchangés ;
- `apps/desktop/src/pages/HomePage.tsx` — composition et signal d'actualisation ;
- `eng/authority-inventory.json` — quatrième entrée `clientDataApiReads`, preuves
  et limites du domaine dispatch ;
- `docs/ARCHITECTURE.md`, `docs/QUALITY.md`, `docs/CURRENT_STATE.md`,
  `docs/tickets/README.md` et ce ticket.

`apps/desktop/src/styles/index.css` était autorisé mais n'a pas été nécessaire.

### Commands and results

Exécutées le 4 août 2026 depuis `.worktrees/t0053`, Windows 11, pnpm 11.17.0,
vitest 4.1.10 :

| Commande | Résultat |
| --- | --- |
| `pnpm.cmd frontend:typecheck` | réussi |
| `pnpm.cmd frontend:test` | réussi — 24 fichiers/297 tests passés, 1 fichier/2 tests ignorés |
| `pnpm.cmd frontend:coverage` | réussi — 94,46 % statements, 88,96 % branches, 97,51 % fonctions, 94,42 % lignes |
| `pnpm.cmd frontend:build` | réussi — `dist/assets/index-BQCpT0lF.js` 279,58 kB, gzip 84,02 kB |
| `pnpm.cmd authority:check` | réussi — 10 étapes golden path, 13 domaines, 3 surfaces, 9 mutations |
| `pnpm.cmd data-policy:check` | réussi — T0017–T0020 plus 6 mutations |
| `pnpm.cmd maintenance:check` | réussi — registre, index, marqueurs de dette, 8 mutations |
| `git diff --check` | réussi, aucune sortie |

Détail ciblé : `pnpm exec vitest run src/features/flight-dispatch` rend
7 fichiers/122 tests, contre 4 fichiers/66 tests livrés par T0052, soit
56 nouveaux tests. La couverture du domaine atteint 98,01 % des statements et
93,27 % des branches, dont 98,87 % des statements sur `dispatchList.ts`.

Contrôles non exécutés : `desktop:check`, `desktop:test`, `desktop:build`,
`backend:*` et `ci:backend` sont hors périmètre — aucun changement Rust/Tauri,
SQL, Edge Function ou toolchain n'est inclus.

### Manual verification result

Effectuée le 4 août 2026 sous jsdom avec `fetch` injecté et espionné, via les
scénarios automatisés qui reproduisent les quatre étapes demandées :

1. accueil rendu sans session puis avec session et compagnie injectées — aucun
   appel réseau au rendu, `globalThis.fetch` jamais appelé, panneau de lecture
   présent dès que la compagnie est connue et lecture déclenchée par l'utilisateur ;
2. URL, headers, projection et limite de l'unique requête inspectés — origine et
   chemin loopback, exactement `select`, `order` et `limit`, absence vérifiée des
   paramètres `company_id`, `owner_id`, `aircraft_id`, `id` et `state`, quatre
   headers et aucun corps ;
3. création d'un dispatch suivie de la relecture de la source autoritaire — la
   commande de lecture est appelée deux fois et la liste rendue provient de la
   seconde lecture, pas du brouillon renvoyé par la création ;
4. réponse hors schéma, 401 et panne injectés — aucun rendu partiel, session
   effacée et retour login sur 401, message générique sur panne, et ni token, ni
   identifiant de dispatch, ni identifiant d'avion présents dans le DOM.

Cette vérification est une preuve jsdom. La vérification en WebView Tauri live,
contre une RLS réelle et un Edge Runtime réel, n'est pas couverte ici.

### Risks and limitations

- preuve jsdom avec `fetch` injecté : ni WebView live, ni CSP de production, ni
  RLS réelle, ni cible distante, ni donnée réelle ne sont exercées ; l'isolation
  effective entre propriétaires reste prouvée côté serveur par les tests pgTAP de
  T0047 ;
- absence de pagination assumée tant que la limite constante de cinquante lignes
  couvre la flotte de l'alpha ; au-delà, la lecture tronque silencieusement côté
  serveur et aucun indicateur n'est rendu ;
- comme le panneau de flotte T0046 dont le patron est repris, un signal
  d'actualisation reçu avant toute ouverture de la liste n'est pas consommé : la
  première ouverture manuelle déclenche alors une seconde lecture immédiate. Le
  comportement est identique sur les deux panneaux, sans effet de bord serveur
  puisque la lecture est un `GET` borné ;
- le rejet d'un doublon d'`aircraft_id` s'appuie sur la contrainte
  `flight_dispatches_one_draft_per_aircraft` : si un ticket ultérieur autorisait
  plusieurs dispatchs par avion, cette validation devrait être relâchée en même
  temps que la migration.

### Follow-ups

- T0052 est fusionné dans `main` mais son fichier de ticket y porte encore
  `Status: Review` et la ligne correspondante de `docs/tickets/README.md` aussi ;
  la clôture en `Done` appartient à T0052 et sort des `Allowed areas` de ce
  ticket. À traiter dans un ticket de réconciliation dédié, comme cela a été fait
  pour T0049 et T0050 ;
- candidat de mutualisation : `dispatchList.ts`, `aircraftFleet.ts`,
  `companyState.ts` et `aircraftCatalog.ts` répètent la garde de cible loopback,
  la lecture bornée et la validation d'horodatage canonique. La dette est déjà
  suivie par `KI-005` ; une extraction partagée mériterait un ticket borné plutôt
  qu'une correction opportuniste ;
- consommer le signal d'actualisation reçu avant la première ouverture, sur les
  deux panneaux à la fois, pour supprimer la seconde lecture immédiate.

### Documentation updated

- `docs/ARCHITECTURE.md` : frontière de lecture, autorité de sélection RLS,
  validation stricte et composition du signal d'actualisation ;
- `docs/QUALITY.md` : preuve T0053 datée avec compteurs, couverture et périmètre
  réellement observés ;
- `docs/CURRENT_STATE.md` : tranche T0053, quatrième entrée `clientDataApiReads`
  et réconciliation des fusions. Deux affirmations obsolètes du même fichier sont
  corrigées avec preuve : T0052 y était décrit comme non fusionné alors que la
  Pull Request #94 est fusionnée dans `main` par le merge `9ea2493`, et T0057 y
  était décrit comme non fusionné dans deux passages alors que la Pull Request #91
  est fusionnée par le merge `df685b7`. Ces corrections sont documentaires,
  vérifiées contre `origin/main` et signalées ici plutôt que faites en silence ;
- `docs/tickets/README.md` : statut T0053 et levée de sa condition d'ordre
  d'intégration ;
- ce ticket : statut, condition de sortie et Completion Report.
