# T0052 — Composer la préparation de dispatch depuis le desktop

Status: Ready
Owner: Andy
Branch: `feature/T0052-desktop-dispatch-draft`
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

- [ ] Depuis une session avec compagnie et au moins un avion, une soumission
      explicite crée un brouillon et l'affiche depuis la réponse serveur.
- [ ] Le payload envoyé contient exactement avion, deux ICAO normalisés et clé
      d'idempotence ; aucun propriétaire, compagnie, état, temps ou route.
- [ ] Cible non loopback, ICAO invalides ou identiques et avion hors flotte sont
      refusés avant tout appel réseau.
- [ ] Un retry conserve la clé, un changement d'intention en crée une nouvelle et
      le double clic n'émet qu'un appel.
- [ ] Un refus Auth efface la session et ramène vers la connexion.
- [ ] Typecheck, tests frontend, couverture, build et gates applicables passent
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

À remplir après implémentation.

### Summary

### Files changed

### Commands and results

### Manual verification result

### Risks and limitations

### Follow-ups

### Documentation updated
