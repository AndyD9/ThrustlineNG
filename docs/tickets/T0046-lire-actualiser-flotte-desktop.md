# T0046 — Lire et actualiser la flotte depuis le desktop

Status: Review
Owner: Andy
Branch: `feature/T0046-desktop-aircraft-fleet`
Phase: 4
Risk: High
Security-sensitive: Yes

## Goal

Permettre à une session desktop possédant une compagnie de charger explicitement
sa flotte puis de l'actualiser après un achat réussi, sans exposer la flotte
d'une autre compagnie ni transformer le client en autorité métier.

## Context

T0029 fournit `company_aircraft`, une lecture `authenticated` protégée par RLS
propriétaire et une acquisition atomique. T0045 compose déjà le catalogue et
l'achat, mais son message de succès ne prouve pas que la flotte persistée peut
être relue. T0043–T0045 restent absents de `main`; ce ticket est donc empilé sur
la branche T0045 et ne présente pas la pile comme livrée.

## Workflow evidence

- 3 août 2026 — `Ready` : le schéma T0029 fournit la lecture propriétaire et la
  branche T0045 contient la composition nécessaire ; aucun choix produit nouveau
  n'est requis.
- 3 août 2026 — `In progress` : branche
  `feature/T0046-desktop-aircraft-fleet` créée depuis T0045 au commit `011f68c` ;
  dépendance empilée explicite sur T0043–T0045.
- 3 août 2026 — `Review` : lecture RLS, composition post-achat, revue
  adversariale et validations automatisées terminées ; publication encore à
  effectuer sur la branche T0045.

## Dependencies

- T0029 — flotte persistée, privilège `SELECT` et RLS propriétaire ;
- T0038 — configuration locale et gestionnaire de session en mémoire ;
- T0044 — aiguillage d'une compagnie existante ;
- T0045 — achat composé et résultat serveur.

## Allowed areas

- `apps/desktop/src/features/aircraft-fleet/` et tests associés ;
- composition sous `apps/desktop/src/app/`, `apps/desktop/src/pages/HomePage.tsx`
  et tests associés ;
- callbacks strictement nécessaires sous les panneaux catalogue et achat, avec
  leurs tests ;
- `eng/authority-inventory.json` et le gate d'autorité associé ;
- ce ticket, l'index, `CURRENT_STATE.md`, `QUALITY.md`, `ARCHITECTURE.md` et
  `SECURITY.md`.

## Do not touch

- migrations, RLS, grants, seed, RPC, Edge Functions et types générés ;
- contrat HTTP d'achat, prix, devise, politique économique et grand livre ;
- onboarding, location, dispatch, finance et maintenance ;
- persistance locale, cible distante et CSP production ;
- Rust/Tauri, bridge, SimConnect, manifests, dépendances et lockfiles.

## Requirements

### 1. Lecture propriétaire bornée

- Lire uniquement `company_aircraft` avec une projection, un ordre et une limite
  constants ; ne jamais fournir de compagnie ou propriétaire comme filtre.
- Acquérir le bearer au clic depuis `DesktopSessionManager` et s'appuyer sur la
  RLS propriétaire T0029.
- Borner la réponse et valider strictement chaque ligne avant de la rendre.

### 2. États explicites et sans chargement implicite

- N'effectuer aucun appel réseau au rendu ; proposer une action explicite pour
  afficher la flotte.
- Distinguer prêt, chargement, flotte vide, flotte chargée et indisponibilité ;
  bloquer les lectures concurrentes et annuler au démontage.
- Effacer la session et revenir au login sur refus Auth, sans rendre ni
  journaliser de détail amont ou de credential.

### 3. Réconciliation post-achat

- Après un achat réussi, déclencher une actualisation explicite de la flotte
  déjà chargée, ou rendre une action d'actualisation lorsque la flotte n'a pas
  encore été chargée.
- Ne jamais construire localement un avion détenu à partir de l'offre ou du
  résultat d'achat : seule la relecture RLS fait foi.
- Conserver l'idempotence et les protections de soumission de T0045.

## Non-goals

- muter, renommer, vendre, affecter ou maintenir un avion ;
- afficher prix d'acquisition, solde, grand livre ou historique ;
- location T0032, dispatch, vol ou données temps réel ;
- chargement automatique au rendu, pagination interactive ou cache persistant ;
- WebView live, staging, production, cible distante ou donnée réelle.

## Acceptance criteria

- [x] La flotte propriétaire peut être chargée sur action via une requête fermée.
- [x] Zéro réseau au rendu et aucun identifiant de compagnie/propriétaire client
      ne sont utilisés.
- [x] Réponse, nombre de lignes et champs sont strictement bornés et validés.
- [x] Flotte vide, chargement, succès, erreur, concurrence et démontage sont
      couverts.
- [x] Un refus Auth efface la session et revient au login.
- [x] Un achat réussi peut réactualiser la flotte sans fabriquer l'avion côté
      client.
- [x] Tests ciblés, typecheck, couverture, build et gates applicables passent.
- [x] La documentation conserve T0043–T0046 comme pile absente de `main`.

## Security review

- actifs/données : bearer en mémoire, clé anonyme publique et flotte propriétaire ;
- frontière : WebView non fiable → Data API en lecture/RLS → PostgreSQL ;
- abus : filtre propriétaire forgé, réponse surdimensionnée, champ inattendu,
  lecture concurrente, fuite de bearer ou avion optimiste non persisté ;
- validation/autorisation : requête constante, session tardive, RLS T0029 et
  schéma de réponse fermé ;
- logs/vie privée : aucun credential, identifiant interne de compagnie ou détail
  amont dans les logs ou messages.

## Maintenance review

- dette applicable : `KI-005`; transport et panneau flotte restent séparés de la
  page et des commandes d'achat ;
- dette créée : aucune attendue ; pagination et mutations futures restent hors
  périmètre ;
- règle de sécurité : étendre l'allowlist Data API à la lecture de flotte sans
  relâcher le contrôle des mutations ;
- risque résiduel : WebView compromise et pile non propagée dans `main`.

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

1. Rendre l'accueil avec une session synthétique et confirmer zéro réseau.
2. Vérifier une compagnie, charger une flotte vide puis une flotte existante.
3. Acheter une offre et confirmer que seule une relecture de flotte fait
   apparaître l'avion.
4. Simuler double clic, réponse invalide, refus Auth, panne/retry et démontage.

Temps cible : 10 minutes.

## Rollback

Retirer le panneau et le transport de flotte ainsi que le callback post-achat.
Aucun backend, donnée, migration, cible ou persistance n'est modifié.

## Completion Report

### Summary

Le desktop dispose d'un transport et d'un panneau de flotte séparés. La requête
`GET` possède une projection, un ordre et une limite constants, sans filtre de
compagnie ou propriétaire ; la RLS T0029 reste l'unique autorité d'isolation.
Une flotte déjà chargée est relue après achat, y compris si le signal arrive
pendant une lecture en cours, sans construire d'avion optimiste côté client.

### Files changed

- transport, panneau et tests sous `features/aircraft-fleet/` ;
- callbacks post-achat bornés dans les panneaux achat/catalogue ;
- injection App/routes/accueil et test d'intégration ;
- allowlist d'autorité, ce ticket, index, état courant, qualité, architecture et
  sécurité.

Aucun backend, contrat d'achat, migration, RLS, seed, type généré, manifeste,
lockfile, stockage, CSP ou cible n'est modifié.

### Commands and results

- `pnpm.cmd frontend:typecheck` — PASS ;
- `apps\\desktop\\node_modules\\.bin\\vitest.CMD run ...` depuis
  `apps/desktop` — PASS, 3 fichiers/34 tests ciblés ;
- `pnpm.cmd frontend:test` — PASS, 17 fichiers/173 tests exécutés ; 1 fichier/2
  scénarios runtime T0040 ignorés sans environnement explicite ;
- `pnpm.cmd frontend:coverage` — PASS, 93,26 % statements, 87,36 % branches,
  96,72 % fonctions et 93,25 % lignes ;
- `pnpm.cmd frontend:build` — PASS, bundle JS 267,00 kB / 81,89 kB gzip ;
- `pnpm.cmd authority:check` — PASS, 9 mutations ;
- `pnpm.cmd data-policy:check` — PASS, 6 mutations ;
- `pnpm.cmd maintenance:check` — PASS, 8 mutations ;
- `git diff --check` — PASS, avertissements LF/CRLF seulement.

Deux essais ciblés depuis la racine n'ont exécuté aucun test : le premier chemin
Vitest était absent et le second a chargé la configuration racine au lieu de
Vite. Ils ont été remplacés par la commande explicite réussie depuis
`apps/desktop` et ne sont pas comptés comme preuves.

### Manual verification result

PASS le 3 août 2026 via DOM jsdom et commandes injectées : zéro lecture au
rendu, flotte vide puis chargée, payload sans filtre propriétaire, identifiants
et tokens absents du DOM, achat suivi d'une relecture, refresh reçu pendant une
lecture rejoué, double clic borné, retry, refus Auth et annulation au démontage.

### Security and maintenance review result

La relecture ne reçoit aucun `company_id` ou `owner_id`; RLS sélectionne la
compagnie du sujet Auth. Réponse, champs, UUID, timestamps, doublons et taille
sont validés avant rendu. Bearer et clé anonyme restent transitoires, sans état
React, stockage, log ou rendu. Transport, panneau et composition restent
séparés ; `KI-005` n'est pas aggravé. Aucune dette, exception ou dépendance
nouvelle n'est créée.

### Risks and limitations

La preuve reste jsdom/fetch injectée : aucun WebView live, CSP production,
projet distant ou donnée réelle n'est validé. La limite de cinquante avions ne
fournit pas encore de pagination. T0046 est empilé sur T0045, elle-même dépendante
de T0043–T0044 absents de `main`; aucune livraison de la pile n'est revendiquée.
Une WebView compromise peut encore lire le bearer en mémoire.

### Follow-ups

- publier T0046 sur T0045 puis propager T0043–T0046 vers `main` dans l'ordre ;
- cadrer ensuite le premier slice dispatch autoritaire sans anticiper la
  location T0032 ;
- traiter pagination, mutations de flotte et persistance dans des tickets
  séparés si le parcours les exige.

### Documentation updated

Ce ticket, l'index, `CURRENT_STATE.md`, `QUALITY.md`, `ARCHITECTURE.md`,
`SECURITY.md` et l'inventaire d'autorité.

### Git status

- branche : `feature/T0046-desktop-aircraft-fleet` ;
- base : T0045 au commit `011f68c` ;
- dépendances empilées : T0043–T0045 restent absents de `main` ;
- commit, push et Pull Request : à effectuer après inspection du diff indexé.
