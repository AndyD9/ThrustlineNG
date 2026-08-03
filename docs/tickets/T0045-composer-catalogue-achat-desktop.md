# T0045 — Composer le catalogue avec l’achat desktop

Status: Review
Owner: Andy
Branch: `feature/T0045-compose-aircraft-purchase`
Phase: 4
Risk: High
Security-sensitive: Yes

## Goal

Permettre à une session desktop possédant une compagnie de choisir une offre
chargée par le catalogue T0043 puis d’exécuter la commande d’achat T0037, sans
copier le bearer dans l’état React ni déplacer l’autorité économique au client.

## Context

T0037 livre une commande d’achat fermée et idempotente encore injectée avec une
session brute. T0043 livre un catalogue validé mais sans sélection, et T0044
aiguille les compagnies existantes vers ce catalogue. Les PR #72 et #74 ont été
fusionnées dans leurs branches parentes après la propagation de T0042 vers
`main`; elles restent donc des dépendances empilées et ne sont pas revendiquées
comme livrées dans la branche distante par défaut.

## Workflow evidence

- 3 août 2026 — `Ready` : T0037 est livré dans `main`; T0043 et T0044 sont
  validés et fusionnés dans leur pile, qui contient les contrats nécessaires.
- 3 août 2026 — `In progress` : branche
  `feature/T0045-compose-aircraft-purchase` créée depuis T0044 au commit
  `2a2de58`; dépendances empilées explicites sur T0043/PR #72 et T0044/PR #74.
- 3 août 2026 — `Review` : composition, acquisition tardive de session, revue
  adversariale, vérification jsdom et validations automatisées terminées ; la
  branche reste empilée sur T0044.
- 3 août 2026 — publication : commit `34f96bb` poussé ; PR prête #76 ouverte,
  base `feature/T0044-desktop-company-state`, head
  `feature/T0045-compose-aircraft-purchase`, fusionnable ; les trois checks
  GitHub sont en attente ou en cours lors de l'observation initiale.
- 3 août 2026 — fusion empilée : PR #76 fusionnée par Andy dans la branche
  T0044 pendant les checks ; PostgreSQL 17 et supply-chain sont verts, Windows
  multi-stack reste en cours. T0045 demeure `Review`, car cette fusion ne
  propage ni T0043, ni T0044, ni T0045 dans `main`.
- 3 août 2026 — réconciliation : commit documentaire `e643b89` poussé ; PR
  corrective #77 ouverte vers T0044 pour propager l'état exact de #76.

## Dependencies

- T0029 et T0035–T0037 — achat serveur atomique, frontière authentifiée et
  commande desktop idempotente ;
- T0038 — configuration locale et gestionnaire de session en mémoire ;
- T0043 / PR #72 — catalogue desktop validé, empilé sur T0042 ;
- T0044 / PR #74 — aiguillage de compagnie, empilé sur T0043.

## Allowed areas

- `apps/desktop/src/features/aircraft-catalog/` et tests associés ;
- `apps/desktop/src/features/aircraft-purchase/` et tests associés ;
- composition sous `apps/desktop/src/app/`, `apps/desktop/src/pages/HomePage.tsx`
  et tests associés ;
- `apps/desktop/src/styles/index.css` si nécessaire ;
- T0042 uniquement pour réconcilier sa livraison corrective #73 ;
- ce ticket, l’index, `CURRENT_STATE.md`, `QUALITY.md`, `ARCHITECTURE.md` et
  `SECURITY.md`.

## Do not touch

- migrations, RLS, grants, seed, RPC, Edge Functions et types générés ;
- contrat HTTP d’achat, prix, devise, politique économique, grand livre et
  autorité propriétaire ;
- onboarding, présence de compagnie, location, flotte et finance ;
- persistance, cookies, credentials Windows, cible distante et CSP production ;
- Rust/Tauri, bridge, SimConnect, manifests, dépendances et lockfiles.

## Requirements

### 1. Sélection bornée du catalogue

- Autoriser la sélection uniquement parmi les offres strictement validées et
  actuellement chargées par T0043 ; ne jamais accepter d’identifiant, prix ou
  propriétaire saisi librement.
- Présenter l’offre sélectionnée de façon accessible et conserver zéro achat ou
  chargement réseau au rendu.
- Réinitialiser l’intention d’achat lorsqu’une autre offre est choisie et
  annuler toute commande démontée.

### 2. Session acquise à la soumission

- Remplacer l’injection d’un bearer brut dans le panneau T0037 par le
  `DesktopSessionManager` et obtenir le bearer au moment de chaque soumission.
- Ne jamais copier, persister, rendre ou journaliser access token, refresh token
  ou clé anonyme.
- Sur expiration Auth issue du gestionnaire ou de l’Edge Function, effacer la
  session et revenir au login ; classer les autres rejets sans détail amont.

### 3. Idempotence et autorité préservées

- Envoyer à la commande existante uniquement l’identifiant d’offre sélectionné
  et une clé d’idempotence stable pour les retries de la même intention.
- Bloquer les doubles soumissions ; un changement d’offre crée une nouvelle
  intention et l’achat réussi reste affiché comme résultat serveur.
- Ne pas envoyer prix, devise, compagnie, propriétaire, solde ou credential
  privilégié et ne pas appeler Data API ou RPC pour muter.

### 4. Réconciliation de dépendance

- Passer T0042 à `Done` avec sa fusion corrective #73 et ses trois checks verts,
  sans modifier ses preuves historiques.
- Conserver T0043 et T0044 en `Review` tant que leurs commits ne sont pas
  propagés dans `main`.

## Non-goals

- charger automatiquement la compagnie, le catalogue ou lancer un achat ;
- afficher ou actualiser flotte, solde, grand livre ou historique ;
- permettre plusieurs achats concurrents ou inventer un panier ;
- modifier le backend, l’économie, les offres ou l’onboarding ;
- WebView live, staging, production, cible distante ou donnée réelle.

## Acceptance criteria

- [x] Une offre chargée peut être choisie puis achetée par la commande T0037.
- [x] Zéro réseau au rendu et aucune sélection forgée ne sont possibles.
- [x] Le bearer est acquis à la soumission et absent des props/états rendus.
- [x] Double clic, retry idempotent, changement d’offre et démontage sont bornés.
- [x] Un refus Auth efface la session et revient au login.
- [x] Aucun prix, devise, propriétaire, compagnie ou solde n’est envoyé comme
      autorité d’achat.
- [x] Tests ciblés, typecheck, couverture, build et gates applicables passent.
- [x] Documentation distingue branche empilée, composition locale et absence de
      livraison T0043–T0045 dans `main`.

## Security review

- actifs/données : bearer en mémoire, clé anonyme publique, offres validées et
  clé d’idempotence ;
- frontière : WebView non fiable → Data API en lecture/RLS puis Edge Function
  authentifiée → RPC service ;
- abus : offre forgée, prix client, bearer stocké, double achat, retry divergent,
  achat après expiration Auth ou mutation Data API directe ;
- validation/autorisation : sélection issue du catalogue validé, session acquise
  tardivement, propriétaire et prix dérivés côté serveur ;
- atomicité/idempotence : une clé stable par offre/intention UI, transaction
  T0029 autoritaire ;
- logs/vie privée : aucun log ou rendu de credential, requête ou détail amont.

## Maintenance review

- dette applicable : `KI-005`; transport, catalogue, achat et composition restent
  séparés ;
- dette créée : aucune attendue ; la flotte et l’actualisation post-achat restent
  des capacités futures explicites ;
- règle de sécurité : aucune nouvelle règle, composition des invariants existants ;
- risque résiduel : WebView compromise, preuve injectée et pile non propagée
  dans `main`.

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

1. Rendre l’accueil avec une session synthétique et confirmer zéro réseau.
2. Vérifier la compagnie, charger deux offres et choisir l’une d’elles.
3. Acheter, contrôler le payload fermé, le bearer acquis tardivement et l’état
   `owned` sans identifiant sensible rendu.
4. Simuler double clic, panne/retry, changement d’offre, refus Auth et démontage.

Temps cible : 10 minutes.

## Rollback

Retirer la sélection et la composition, puis restaurer l’injection isolée du
panneau T0037. Aucun backend, donnée, migration, cible ou persistance n’est
modifié.

## Completion Report

### Summary

Le catalogue permet de choisir exactement une offre issue de sa réponse validée
puis compose le panneau d'achat T0037. Le panneau obtient désormais le bearer au
clic depuis le gestionnaire de session, conserve l'idempotence de l'intention et
revient au login si Auth refuse la commande.

### Files changed

- composition et tests sous `features/aircraft-catalog/` et
  `features/aircraft-purchase/` ;
- injection bornée App/routes/accueil et tests d'intégration ;
- ticket T0042 réconcilié avec sa livraison corrective #73 ;
- ticket T0045, index, état courant, qualité, architecture et sécurité.

Aucun backend, contrat HTTP, migration, RLS, inventaire d'autorité, CSP,
manifeste, lockfile, stockage ou cible n'est modifié.

### Commands and results

- `pnpm.cmd frontend:typecheck` — PASS ;
- `node_modules\\.bin\\vitest.CMD run` sur les trois suites ciblées — PASS,
  3 fichiers/23 tests ;
- `pnpm.cmd frontend:test` — PASS, 15 fichiers/149 tests ; 1 fichier/2 scénarios
  runtime T0040 ignorés sans environnement explicite ;
- `pnpm.cmd frontend:coverage` — PASS, 92,86 % statements, 86,61 % branches,
  96,15 % fonctions et 92,87 % lignes ;
- `pnpm.cmd frontend:build` — PASS, bundle JS 261,04 kB / 80,94 kB gzip ;
- `pnpm.cmd authority:check` — PASS, 9 mutations ;
- `pnpm.cmd data-policy:check` — PASS, 6 mutations ;
- `pnpm.cmd maintenance:check` — PASS, 8 mutations ;
- `git diff --check` — PASS, avertissements LF/CRLF seulement.

### Manual verification result

PASS le 3 août 2026 via DOM jsdom et commandes injectées : zéro chargement ou
achat au rendu, offre choisie uniquement après catalogue, bearer remplacé après
le chargement puis acquis à la soumission, payload sans prix/propriétaire,
double clic borné, offre concurrente verrouillée, retry, changement d'offre,
annulation au démontage et retour au login sur refus Auth. Aucun identifiant
d'offre, token ou résultat interne n'est rendu.

### Security and maintenance review result

Le client affiche le prix validé pour le choix mais n'envoie que l'identifiant
de l'offre et l'idempotence comme payload métier. Bearer et clé anonyme restent
des paramètres transitoires de commande, sans prop brute, état React, stockage,
log ou rendu. Prix, propriétaire et transaction restent autoritaires côté
serveur. Catalogue, achat et composition restent séparés ; `KI-005` n'est pas
aggravé. Aucune dette, dépendance, règle ou exception de sécurité n'est créée.

### Risks and limitations

T0045 reste empilé sur T0044/PR #74, elle-même empilée sur T0043/PR #72. Ces
deux PR ont fusionné dans leurs branches parentes après la livraison T0042 et
n'ont pas propagé T0043/T0044 dans `main`. La CSP de production reste fermée et
la preuve est injectée : aucun WebView live, projet distant, donnée réelle,
actualisation de flotte ou solde post-achat n'est revendiqué. Une WebView
compromise peut encore lire le bearer en mémoire.

### Follow-ups

- publier T0045 sur T0044 puis propager T0043–T0045 vers `main` par des PR
  correctives ordonnées ;
- choisir ensuite un ticket phase 4 borné pour la flotte ou la reprise
  post-achat, sans anticiper la location T0032 ;
- traiter la persistance Windows dans un ticket de sécurité séparé.

### Documentation updated

T0042, ce ticket, l'index, `CURRENT_STATE.md`, `QUALITY.md`, `ARCHITECTURE.md` et
`SECURITY.md`.

### Git status

- branche : `feature/T0045-compose-aircraft-purchase` ;
- base : T0044 au commit `2a2de58`, PR #74 fusionnée dans T0043 ;
- dépendances : T0043 et T0044 restent absents de `main` ;
- commit d'implémentation : `34f96bb` ;
- PR #76 : fusionnée par Andy dans `feature/T0044-desktop-company-state`, head
  `feature/T0045-compose-aircraft-purchase` ; PostgreSQL 17 et supply-chain sont
  réussis, Windows multi-stack reste en cours lors de la dernière observation.
  Cette fusion empilée ne livre pas T0045 dans `main`.
- PR corrective #77 : ouverte vers T0044, strictement documentaire, pour
  propager la réconciliation `e643b89`.
