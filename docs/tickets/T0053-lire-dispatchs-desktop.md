# T0053 — Lire et actualiser les dispatchs depuis le desktop

Status: Draft
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

Ce ticket reste `Draft` par ordre d'intégration du flux 3 : il n'entre pas en
`Ready` avant que T0052 soit réellement fusionné dans `main`, afin de ne pas
créer une nouvelle branche empilée. Aucune autre décision produit n'est requise.

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

- [ ] T0052 est fusionné dans `main` avant le passage en `Ready`.
- [ ] La requête est un `GET` à projection, ordre et limite constants, sans
      aucun filtre de propriété client.
- [ ] Une réponse hors schéma, hors bornes ou avec doublons est refusée sans
      rendu partiel.
- [ ] L'accueil n'appelle rien au rendu, affiche une liste vide explicite et
      relit la source après une création réussie.
- [ ] Un refus Auth efface la session et ramène vers la connexion.
- [ ] Typecheck, tests frontend, couverture, build et gates applicables passent
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

À remplir après implémentation.

### Summary

### Files changed

### Commands and results

### Manual verification result

### Risks and limitations

### Follow-ups

### Documentation updated
