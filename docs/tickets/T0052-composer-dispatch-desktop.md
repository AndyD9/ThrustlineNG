# T0052 — Composer la préparation de dispatch depuis le desktop

Status: Review
Owner: Andy
Branch: `feature/T0052-dispatch-draft-composition`
Phase: 2–4
Risk: Medium
Security-sensitive: Yes

## Goal

Permettre depuis l'accueil authentifié de choisir un avion de la flotte, de
saisir deux aéroports et d'obtenir un brouillon de dispatch créé par le serveur,
sans qu'aucune autorité métier ne passe côté client.

## Context

T0046 charge la flotte du propriétaire et T0048 expose `dispatch-draft` derrière
Auth ; aucun appelant applicatif n'existe. Le gate de l'alpha technique interne
exige un parcours desktop cohérent jusqu'à la préparation d'un vol.

Le patron d'appel est déjà établi par T0037/T0045 : un module de commande
WebView borné (`aircraftPurchase.ts`) plus un panneau React mince qui obtient le
bearer depuis le gestionnaire de session T0038 au moment de la soumission. Ce
ticket applique le même patron au dispatch et appartient au flux 3 du mode
accéléré.

## Dependencies

- T0038 — configuration publique et gestionnaire de session en mémoire ;
- T0041, T0044 — route protégée et aiguillage de l'accueil ;
- T0046 — lecture de la flotte, source des avions sélectionnables ;
- T0048 — Edge Function `dispatch-draft`, présente dans `main` ;
- T0049 — preuve runtime Edge recommandée avant la vérification manuelle, sans
  bloquer l'implémentation.

## Allowed areas

- `apps/desktop/src/features/flight-dispatch/` pour le module de commande et le
  panneau, avec leurs tests ;
- `apps/desktop/src/pages/HomePage.tsx` et `apps/desktop/src/app/App.tsx` pour
  l'injection et la composition minimales ;
- `apps/desktop/src/features/aircraft-fleet/` uniquement si l'exposition de la
  flotte déjà chargée l'exige, sans changer sa requête ;
- `apps/desktop/src/styles/index.css` pour les styles nécessaires ;
- `eng/authority-inventory.json` ;
- `docs/ARCHITECTURE.md`, `docs/QUALITY.md`, `docs/CURRENT_STATE.md` ;
- ce ticket et `docs/tickets/README.md`.

## Do not touch

- migrations, RLS, commandes SQL et Edge Functions ;
- requête, projection, ordre ou limite du transport de flotte T0046 ;
- transports catalogue, présence de compagnie, onboarding et achat ;
- CSP de production, persistance de session, stockage Windows et OAuth ;
- Rust/Tauri, bridge, SimConnect, SimBrief et cycle de vol ;
- workflows, manifests, lockfiles, cible distante et données réelles.

## Requirements

### 1. Commande WebView bornée

- Accepter uniquement URL publique loopback `http:`, clé anonyme, bearer
  utilisateur, avion, deux ICAO et clé d'idempotence.
- Refuser toute cible non loopback, avec identifiants, requête, fragment ou
  chemin, avant tout appel réseau.
- Normaliser les ICAO en majuscules après trim, exiger quatre caractères ASCII
  alphanumériques, refuser deux codes identiques et exiger des UUID canoniques.
- Borner la requête à cinq secondes et la réponse lue à 16 Kio.
- Valider strictement les sept champs publics de la réponse, exiger
  `state: draft` et `schemaVersion: 1`, et recouper avion et ICAO avec la
  demande.
- Mapper les échecs vers `authentication-required`, `rejected`,
  `invalid-response` et `unavailable`, sans exposer de détail serveur.

### 2. Panneau mince

- N'exécuter aucun appel réseau au rendu ; l'action vient d'une soumission
  explicite.
- Limiter la sélection aux avions réellement chargés depuis la flotte : aucun
  identifiant saisi librement.
- Obtenir le bearer depuis le gestionnaire de session à la soumission et effacer
  la session si Auth refuse.
- Bloquer la double soumission, conserver la même clé d'idempotence pour un
  retry de la même intention et créer une nouvelle clé si l'avion ou un ICAO
  change.
- Exposer des états accessibles `ready`, `pending`, `created`, `rejected` et
  `unavailable`, avec des messages actionnables sans détail technique.
- Annuler proprement la requête au démontage.

### 3. Autorité et preuves

- L'inventaire d'autorité ajoute le chemin desktop au domaine `dispatch` sans
  déclarer de nouvelle lecture Data API et sans introduire de mutation cliente.
- Les tests couvrent payload et headers fermés, cible refusée, ICAO invalides ou
  identiques, UUID invalide, timeout, panne réseau, réponses 400/401/409/5xx,
  contrat de réponse invalide, double clic, retry idempotent, changement
  d'intention, refus Auth, zéro réseau au rendu, absence de fuite au DOM et
  démontage.
- Le bundle ne contient ni credential de test, ni marqueur privilégié.

## Non-goals

- lire, lister ou actualiser les dispatchs existants, traité par T0053 ;
- démarrer, reprendre, annuler ou clôturer un vol ;
- préparer SimBrief, une route détaillée, la météo ou un OFP ;
- persister la session, ouvrir la CSP de production ou viser une cible distante ;
- afficher un solde, un prix ou un effet financier.

## Acceptance criteria

- [x] Depuis une session avec compagnie et au moins un avion, une soumission
      explicite crée un brouillon et l'affiche depuis la réponse serveur.
- [x] Le payload envoyé contient exactement avion, deux ICAO normalisés et clé
      d'idempotence ; aucun propriétaire, compagnie, état, temps ou route.
- [x] Cible non loopback, ICAO invalides ou identiques et avion hors flotte sont
      refusés avant tout appel réseau.
- [x] Un retry conserve la clé, un changement d'intention en crée une nouvelle et
      le double clic n'émet qu'un appel.
- [x] Un refus Auth efface la session et ramène vers la connexion.
- [x] Typecheck, tests frontend, couverture, build et gates applicables passent
      avec leurs compteurs réellement observés.

## Security review

- actifs : session utilisateur, propriété d'avion, intention de vol ;
- frontière : WebView non fiable → Edge Function T0048 → RPC T0047 ;
- abus : avion forgé, champ caché ajouté au payload, cible détournée, double
  création, fuite de token dans le DOM ou les logs ;
- validation/autorisation : allowlist du payload, cible loopback imposée,
  bearer obtenu à la soumission, réponse recoupée ;
- atomicité/idempotence : clé stable par intention et blocage du double envoi ;
- logs/vie privée : aucun token, identifiant ou détail serveur rendu ou
  journalisé.

## Maintenance review

- problèmes applicables : `KI-005` interdit de remélanger UI, règles et accès aux
  données ; `KI-021` interdit les données réelles ;
- dette créée : aucune ; la lecture durable des dispatchs reste T0053 ;
- règle de sécurité : le desktop ne fournit jamais propriétaire, compagnie, état
  ou temps ;
- contrôle manuel à automatiser : espions réseau et invariants de fuite DOM déjà
  couverts par les tests ;
- risque résiduel : la preuve reste jsdom et `fetch` injecté, sans WebView live.

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

1. Rendre l'accueil avec une session et une flotte injectées, sans réseau.
2. Choisir un avion, saisir deux ICAO valides et soumettre ; inspecter l'URL, les
   headers et le payload exact.
3. Rejouer la même intention, changer d'ICAO, double-cliquer et provoquer un
   refus Auth.
4. Confirmer l'absence de token, d'identifiant serveur et de détail technique
   dans le DOM et la console.

Temps cible : 5–10 minutes.

## Rollback

Avant fusion, abandonner la branche. Après fusion, retirer l'injection du panneau
dans un ticket correctif ; aucune donnée serveur n'est créée par ce retrait.

## Completion Report

### Summary

Le desktop appelle pour la première fois la frontière `dispatch-draft` de T0048.
Un module de commande borné (`flightDispatch.ts`) n'accepte qu'une cible loopback
`http:` sans identifiants, requête, fragment ni chemin, normalise les deux ICAO en
majuscules après trim, exige quatre caractères ASCII alphanumériques, deux codes
distincts et des UUID canoniques avant tout appel réseau, borne la requête à cinq
secondes et la réponse lue à 16 Kio, puis valide les sept champs publics avec
`state: draft` et `schemaVersion: 1` en recoupant avion et aérodromes avec la
demande. Les échecs sont réduits à `authentication-required`, `rejected`,
`invalid-response` et `unavailable`, sans détail serveur.

Le panneau `FlightDispatchPanel` n'exécute aucun appel au rendu, limite la
sélection aux avions réellement chargés par le transport T0046 — exposés par un
nouveau rappel `onFleetLoaded` sans changer la requête, la projection, l'ordre ou
la limite —, obtient le bearer du gestionnaire T0038 à la soumission, conserve une
clé d'idempotence par intention, en crée une nouvelle si l'avion ou un ICAO change,
bloque la double soumission, efface la session sur refus Auth et annule sa requête
au démontage. `HomePage` compose le panneau uniquement quand la compagnie est
présente et la flotte non vide. L'inventaire d'autorité rattache les deux chemins
desktop au domaine `dispatch` sans nouvelle lecture Data API ni mutation cliente.

### Files changed

- `apps/desktop/src/features/flight-dispatch/flightDispatch.ts` (nouveau) ;
- `apps/desktop/src/features/flight-dispatch/flightDispatch.test.ts` (nouveau) ;
- `apps/desktop/src/features/flight-dispatch/FlightDispatchPanel.tsx` (nouveau) ;
- `apps/desktop/src/features/flight-dispatch/FlightDispatchPanel.test.tsx`
  (nouveau) ;
- `apps/desktop/src/features/flight-dispatch/flightDispatch.invariants.test.ts`
  (nouveau) ;
- `apps/desktop/src/features/flight-dispatch/homeComposition.test.tsx` (nouveau) ;
- `apps/desktop/src/features/aircraft-fleet/AircraftFleetPanel.tsx` et son test :
  rappel `onFleetLoaded` uniquement ;
- `apps/desktop/src/pages/HomePage.tsx` : état de flotte et injection du panneau ;
- `apps/desktop/src/styles/index.css` : styles du panneau et du sélecteur ;
- `eng/authority-inventory.json` : chemins, marqueurs et limites du domaine
  `dispatch` ;
- `docs/ARCHITECTURE.md`, `docs/QUALITY.md`, `docs/CURRENT_STATE.md`,
  `docs/tickets/README.md` et ce ticket.

### Commands and results

Toutes les commandes sont exécutées le 4 août 2026 depuis
`.worktrees/t0052` sous Windows 11, Node 24.18.0 et pnpm 11.17.0.

- `pnpm.cmd frontend:typecheck` : réussi, aucune erreur `tsc`.
- `pnpm.cmd frontend:test` : réussi, 21 fichiers/241 tests passés, 1 fichier/2
  scénarios runtime T0040 ignorés faute d'environnement explicite. Le flux
  T0052 apporte 66 tests dans `features/flight-dispatch` et 2 dans
  `features/aircraft-fleet` ; la base était de 173 tests.
- `pnpm.cmd frontend:coverage` : réussi, 93,96 % des statements (857/912),
  88,41 % des branches (687/777), 97,18 % des fonctions (138/142) et 93,93 % des
  lignes (837/891). `features/flight-dispatch` atteint 98,34 % des statements et
  94,06 % des branches ; `flightDispatch.ts` est à 100 % des statements et des
  lignes, `FlightDispatchPanel.tsx` à 96,55 %, les deux lignes non couvertes
  étant les gardes de réentrance et d'annulation.
- `pnpm.cmd frontend:build` : réussi, `dist/assets/index-DaikaJBL.js` 273,71 kB
  (83,22 kB gzip) et `index-BsTWmy3G.css` 8,15 kB.
- Inspection du bundle produit : ni JWT `eyJ…`, ni `private-user-token`, ni
  `public-anon-key`, ni `service_role`, ni `SUPABASE_SERVICE_ROLE`, ni
  `create_dispatch_draft` ; le seul chemin serveur présent est
  `/functions/v1/dispatch-draft`.
- `pnpm.cmd authority:check` : réussi, 10 étapes, 13 domaines, 3 surfaces
  clientes et 9 scénarios de mutation.
- `pnpm.cmd data-policy:check` : réussi, dépôt T0017–T0020 et 6 mutations.
- `pnpm.cmd maintenance:check` : réussi, registre, index des tickets, marqueurs de
  dette et 8 mutations.
- `git diff --check` : aucun avertissement d'espaces.
- CI de la première publication, PR #92 sur la branche
  `feature/T0052-desktop-dispatch-draft` : `Supabase PostgreSQL 17` et
  `Windows multi-stack` passent en 3 min 11 s et 16 min 16 s ;
  `Audits, licences and SBOM` échoue uniquement sur `SECRET_SCAN`. Gitleaks
  8.24.3 signale une occurrence `generic-api-key` à la ligne 262 de ce ticket :
  le littéral JSON `"…Key":"<UUID>"` de la preuve manuelle. La valeur est un UUID
  v4 tiré localement par la sonde jsdom, sans système derrière elle ; aucun
  secret, JWT ni credential n'est concerné. La ligne est reformulée ici pour ne
  plus présenter de valeur à haute entropie derrière un nom de clé. L'action
  scanne toute la plage de commits de la Pull Request, donc un commit correctif
  ne pouvait pas reverdir cette branche et un force-push est interdit : le
  travail est republié sur `feature/T0052-dispatch-draft-composition`, la
  PR #92 est fermée et remplacée sans réécrire d'historique publié.
- CI de la republication, PR #94 au commit `c4c86f5`, arbre identique : les trois
  checks passent. `Audits, licences and SBOM` en 3 min 41 s, dont `SECRET_SCAN`
  redevenu vert, `Supabase PostgreSQL 17` en 3 min 11 s et `Windows multi-stack`
  en 15 min 24 s.

### Manual verification result

La vérification manuelle du 4 août 2026 est exécutée par une sonde jsdom
temporaire qui rend `HomePage` avec session et flotte injectées, laisse le panneau
utiliser le module de commande réel et espionne `globalThis.fetch` ; la sonde est
supprimée après lecture et n'est pas livrée.

1. Après rendu, vérification de compagnie et chargement de flotte : `0` appel
   réseau émis par le panneau, qui n'apparaît qu'après une flotte non vide.
2. Soumission explicite avec `lfpg`/`lfbo` : cible
   `http://127.0.0.1:54321/functions/v1/dispatch-draft`, exactement quatre
   headers `accept`, `apikey`, `authorization: Bearer …`, `content-type`, et
   payload composé exactement des quatre champs `aircraftId`, `departureIcao`,
   `arrivalIcao` et la clé d'idempotence, portant l'avion sélectionné
   `5a3f2d1e-…-abcd`, `LFPG`, `LFBO` et la clé `28a1e0f9-…` générée localement —
   aucun propriétaire, compagnie, état, temps ou route.
3. Après un 503, double clic sur `Réessayer` : un seul appel supplémentaire, soit
   deux au total, avec la clé identique `28a1e0f9-…`; la réponse 200 affiche
   « Brouillon créé pour LFPG → LFBO » depuis les champs serveur.
4. Changement d'arrivée en `lfml` : nouvelle clé
   `407c85ca-ff9e-4b7e-8358-5c07d575370e` et nouveau brouillon affiché.
5. Réponse 401 : session effacée (`hasSession()` faux) et un unique retour vers la
   connexion demandé.
6. Inspection finale : le texte du DOM ne contient ni `private-user-access-token`,
   ni `public-anon-key-value`, ni l'identifiant de dispatch, ni `Bearer`, et zéro
   appel `console.debug/error/info/log/warn` n'a été émis.

L'identifiant d'avion reste présent dans l'attribut `value` des options du
sélecteur, ce qui est nécessaire à la sélection ; il provient de la flotte du
propriétaire déjà chargée et n'est pas rendu comme texte.

### Risks and limitations

- La preuve reste jsdom avec `fetch` injecté ou espionné : ni WebView Tauri live,
  ni CSP de production, ni Edge Runtime réel, ni cible distante, ni donnée réelle.
- Le champ ICAO est borné à quatre caractères par `maxLength`; un espace saisi
  avant le code consomme donc une position et fait refuser l'intention avec le
  message actionnable du panneau. Le trim reste appliqué par le module.
- Le sélecteur d'avion porte `aria-required` sans `required` HTML, afin que
  l'absence de sélection ou une sélection devenue absente de la flotte soit
  refusée par la validation du code plutôt que par la validation native.
- L'injection du panneau reste locale à `HomePage`; `App.tsx` et `routes.tsx` ne
  transportent pas de commande de dispatch, ce qui laisse la valeur par défaut du
  panneau en production et l'injection aux tests.
- Le délai de cinq secondes est prouvé par un `AbortSignal` déjà annulé, pas par
  une horloge réelle.

### Follow-ups

- T0053 reste responsable de la lecture et de l'actualisation durables des
  dispatchs ; ce ticket n'affiche que la réponse de la création courante.
- `docs/CURRENT_STATE.md` et `docs/tickets/README.md` décrivent encore T0057 comme
  non fusionné et `Review` alors que la PR #91 l'a fusionné dans `main` au commit
  `df685b7`. Cet écart appartient à la clôture de T0057 et n'est pas corrigé ici.
- Aucune preuve WebView live n'existe pour les appels desktop ; elle reste à
  cadrer avec la livraison de l'alpha technique interne T0055.
- Candidat d'apprentissage, une seule occurrence, à ne pas promouvoir en règle
  globale avant une seconde : citer dans une preuve documentaire un littéral
  `"…Key":"<valeur à haute entropie>"` déclenche la règle `generic-api-key` de
  Gitleaks et fait échouer `SECRET_SCAN`, même pour une valeur synthétique.
  Décrire les champs et tronquer la valeur suffit à conserver la preuve. Le
  contournement d'allowlist n'est pas retenu : il affaiblirait une gate de
  sécurité et exigerait l'accord explicite d'Andy.

### Documentation updated

`docs/ARCHITECTURE.md`, `docs/QUALITY.md`, `docs/CURRENT_STATE.md`,
`docs/tickets/README.md`, `eng/authority-inventory.json` et ce ticket.
