# T0043 — Lire le catalogue d'avions depuis le desktop

Status: Done
Owner: Andy
Branch: `feature/T0043-desktop-aircraft-catalog`
Phase: 4
Risk: High
Security-sensitive: Yes

## Goal

Permettre à une session desktop authentifiée de charger explicitement les offres
d'achat disponibles déjà protégées par la RLS T0029, avec une requête et une
réponse bornées, sans ouvrir de mutation Data API ni composer encore l'achat.

## Context

T0029 accorde uniquement `select` à `authenticated` sur les offres disponibles
et garde toute mutation derrière `aircraft-purchase`. T0037 fournit une commande
d'achat qui attend encore une offre injectée. T0038–T0041 fournissent la session
locale ; T0042 est livré dans `main` par la PR corrective #73.

## Workflow evidence

- 2 août 2026 — `Ready` : T0029, T0037–T0041 sont livrés ; la lecture RLS et ses
  tests A/B/anonyme existent déjà dans `main`.
- 2 août 2026 — `In progress` : branche
  `feature/T0043-desktop-aircraft-catalog` créée au-dessus de T0042 au commit
  `db5f557`; dépendance empilée explicite sur la PR corrective #71.
- 2 août 2026 — `Review` : transport, panneau, allowlist, revue adversariale et
  validations automatisées terminés ; la branche reste empilée sur T0042/#71.
- 2 août 2026 — publication : commit `c792512` poussé ; PR brouillon #72 ouverte
  avec base `feature/T0042-desktop-company-onboarding` et les trois checks GitHub
  en cours lors de l'observation initiale.
- 3 août 2026 — `Done` : la PR corrective #79 a livré `c792512` dans `main` au
  commit de merge `6c232c6`; Windows multi-stack, PostgreSQL 17 et
  audits/licences/SBOM sont tous réussis.

## Dependencies

- T0029 — table d'offres, grants de lecture et RLS `available` ;
- T0037 — contrat d'offre attendu par le futur panneau d'achat ;
- T0038–T0041 — configuration locale et session en mémoire ;
- T0042 — base documentaire et applicative livrée dans `main` par la PR #73.

## Allowed areas

- nouveau module sous `apps/desktop/src/features/aircraft-catalog/` et tests ;
- invariant frontend sous `apps/desktop/src/test/` si nécessaire ;
- `eng/authority-inventory.json` et `tests/authority/run.ps1` pour allowlister
  cette unique lecture sans relâcher les mutations ;
- ce ticket, l'index, `CURRENT_STATE.md`, `QUALITY.md`, `ARCHITECTURE.md` et
  `SECURITY.md`.

## Do not touch

- migrations, RLS, grants, seed, RPC, Edge Functions et types générés ;
- achat, location, flotte possédée, finance et politique économique ;
- routes, accueil, onboarding et composition du panneau T0037 ;
- persistance, cookies, credentials Windows, cible distante et CSP production ;
- Rust/Tauri, bridge, SimConnect, manifests et lockfiles.

## Requirements

### 1. Lecture Data API fermée

- Appeler uniquement `GET /rest/v1/aircraft_purchase_offers` avec bearer courant
  et clé anonyme publique.
- Fixer une projection, l'ordre, `status=eq.available` et une limite maximale de
  20 ; refuser URL non loopback, méthode ou paramètre libre.
- Borner délai, taille du corps, nombre d'éléments et réponse ; accepter seulement
  les champs nécessaires au choix d'une offre.
- Classer Auth, réponse invalide et indisponibilité sans exposer détail amont.

### 2. Panneau de catalogue injecté

- Ne déclencher aucun réseau au rendu ; charger uniquement sur action explicite.
- Obtenir le bearer au moment du chargement depuis le gestionnaire de session,
  sans copier les tokens dans l'état React.
- Rendre les états prêt, chargement, vide, disponible et indisponible de façon
  accessible ; annuler au démontage et bloquer les chargements concurrents.
- En cas d'expiration Auth, effacer la session et revenir au login.
- Ne persister ni journaliser offre, token, clé ou réponse.

### 3. Autorité vérifiable

- Remplacer l'interdiction Data API globale par une allowlist fermée de lectures
  déclarées par chemin et ressource.
- Conserver le refus de toute lecture non déclarée, mutation Supabase directe,
  commande service-only, SQL embarqué et credential privilégié.
- Ajouter des mutations négatives prouvant le rejet d'un second fichier Data API,
  d'une ressource divergente et d'une allowlist orpheline.

## Non-goals

- charger automatiquement le catalogue ou l'état d'une compagnie ;
- sélectionner une offre et composer `AircraftPurchasePanel` ;
- lire la flotte possédée, le solde ou un prix calculé côté client ;
- modifier le backend, créer une offre ou exécuter un achat ;
- WebView live, staging, production, cible distante ou donnée réelle.

## Acceptance criteria

- [x] Une session peut charger explicitement au plus 20 offres disponibles.
- [x] URL, headers, projection, filtre, ordre et limite sont fermés et testés.
- [x] Réponse malformée, corps excessif, timeout, 401 et panne sont couverts.
- [x] Zéro réseau au rendu, concurrence et démontage sont bornés.
- [x] L'allowlist autorise seulement cette lecture et les mutations négatives
      refusent toute extension implicite.
- [x] Tests ciblés, typecheck, couverture, build et gates applicables passent.
- [x] Documentation distingue T0043 empilé, lecture RLS et achat non composé.

## Security review

- actifs/données : bearer en mémoire, clé anonyme publique, offres synthétiques ;
- frontière : WebView non fiable → Data API → RLS T0029 ;
- abus : ressource ou filtre libre, lecture anonyme, mutation directe, fuite de
  bearer, réponse énorme ou forgée ;
- validation/autorisation : requête constante, session `authenticated`, RLS
  `status = 'available'`, réponse strictement allowlistée ;
- atomicité : lecture seule ; l'achat reste T0035/T0029 ;
- logs/vie privée : aucun log ni stockage de credential ou catalogue.

## Maintenance review

- dette applicable : `KI-005`; transport et panneau restent séparés ;
- dette créée : toute future lecture Data API doit être déclarée et testée ;
- règle de sécurité : synchroniser l'allowlist canonique et son gate dans ce
  ticket ;
- risque résiduel : WebView compromise, catalogue synthétique, cible locale et
  absence de composition achat.

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

1. Rendre le panneau avec une session synthétique et confirmer zéro réseau.
2. Charger un catalogue injecté et inspecter URL, headers et états DOM.
3. Simuler expiration Auth, panne, corps invalide, double clic et démontage.
4. Injecter les mutations négatives d'autorité et confirmer leur rejet.

Temps cible : 10 minutes.

## Rollback

Retirer le module catalogue et l'allowlist associée. Aucun backend, donnée,
mutation, cible, route ou persistance n'est modifié.

## Completion Report

### Summary

Le desktop dispose d'une commande de catalogue locale fermée et d'un panneau à
chargement explicite. La lecture reste sous le grant/RLS T0029 et l'inventaire
d'autorité permet uniquement le couple chemin/ressource introduit par T0043.

### Files changed

- transport, panneau et tests sous `features/aircraft-catalog/` ;
- invariant frontend, inventaire et gate d'autorité ;
- ticket, index, état courant, qualité, architecture et sécurité.

Aucun backend, route, achat, flotte, CSP, manifeste, lockfile ou stockage n'est
modifié.

### Commands and results

- premier `pnpm.cmd frontend:typecheck` — FAIL : mock `fetch` inféré sans
  arguments ; signature ajoutée ;
- tentative ciblée `pnpm.cmd --dir apps/desktop exec vitest ...` — FAIL avant
  exécution, binaire non résolu par cette forme sous le shell ;
- premier `pnpm.cmd frontend:test` — FAIL, 122 tests passent et la fixture UUID
  entièrement numérique ne change pas en majuscules ; fixture corrigée ;
- second `pnpm.cmd frontend:test` — PASS, 13 fichiers/123 tests ; 1 fichier/2
  scénarios runtime T0040 ignorés sans environnement explicite ;
- premier `pnpm.cmd authority:check` — FAIL : le test contenait littéralement
  l'URL Data API et était correctement classé comme second accès ; assertion
  construite sans nouveau marqueur runtime ;
- `pnpm.cmd frontend:typecheck` — PASS ;
- `pnpm.cmd frontend:test` — PASS, 13 fichiers/125 tests ;
- `pnpm.cmd frontend:coverage` — PASS, 92,26 % statements, 86,41 % branches,
  94,38 % fonctions et 92,48 % lignes ;
- `pnpm.cmd frontend:build` — PASS, bundle JS 246,92 kB / 78,48 kB gzip ;
- `pnpm.cmd authority:check` — PASS, 8 mutations ;
- `pnpm.cmd data-policy:check` — PASS, 6 mutations ;
- `pnpm.cmd maintenance:check` — PASS, 8 mutations ;
- `git diff --check` — PASS, avertissements LF/CRLF seulement.

### Manual verification result

PASS le 2 août 2026 via fetch et DOM jsdom injectés : zéro réseau au rendu, URL
et headers exacts, offre/état vide rendus, double chargement borné, retry,
annulation au démontage et effacement de session sur refus Auth. Les trois
mutations Data API ajoutées échouent comme attendu.

### Security and maintenance review result

La lecture est constante, locale et limitée ; seuls bearer et clé anonyme sont
envoyés, sans stockage ni log. L'allowlist ne relâche aucune mutation et refuse
un autre fichier, une autre ressource ou une entrée sans preuve. Transport et UI
restent séparés ; `KI-005` n'est pas aggravé. Aucune dépendance ni exception de
sécurité n'est créée.

### Risks and limitations

La CSP de production reste fermée et la preuve est injectée : aucun WebView
live, projet distant ou donnée réelle n'est revendiqué. Le catalogue livré par
T0043 seul ne compose pas l'achat T0037. Une WebView compromise peut lire le
bearer mémoire.

### Follow-ups

- T0044 a livré la lecture d'état de compagnie et l'aiguillage associé ;
- traiter la persistance Windows dans un ticket de sécurité séparé.

### Documentation updated

Ce ticket, l'index, `CURRENT_STATE.md`, `QUALITY.md`, `ARCHITECTURE.md` et
`SECURITY.md`.

### Git status

- branche : `feature/T0043-desktop-aircraft-catalog` ;
- base historique : T0042 au commit `db5f557` ;
- commit d'implémentation : `c792512` ;
- PR #72 : fusionnée dans la branche T0042 ;
- PR corrective #79 : fusionnée dans `main` au commit `6c232c6`, avec Windows
  multi-stack, PostgreSQL 17 et audits/licences/SBOM réussis.
