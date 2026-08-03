# T0044 — Lire l’état de compagnie depuis le desktop

Status: Review
Owner: Andy
Branch: `feature/T0044-desktop-company-state`
Phase: 4
Risk: High
Security-sensitive: Yes

## Goal

Permettre à une session desktop authentifiée de vérifier explicitement si elle
possède déjà une compagnie, puis d’afficher soit l’onboarding T0042, soit le
catalogue T0043, sans autorité métier cliente ni achat composé.

## Context

T0042 affiche aujourd’hui l’onboarding sans détecter une compagnie existante et
T0043 fournit un catalogue encore injecté. Composer directement l’achat
laisserait donc les sessions reprises dans un état incohérent. La table
`companies` accorde déjà une lecture authentifiée protégée par la RLS propriétaire
et conserve une unicité par propriétaire ; aucune évolution backend n’est
nécessaire.

## Workflow evidence

- 3 août 2026 — `Ready` : la lecture propriétaire RLS est livrée par T0012, la
  création autoritaire par T0022–T0023 et les composants desktop par T0042–T0043.
- 3 août 2026 — `In progress` : branche
  `feature/T0044-desktop-company-state` créée au-dessus de T0043 au commit
  `340810c`; dépendances empilées explicites sur T0042/PR #71 et T0043/PR #72.
- 3 août 2026 — `Review` : transport, composition, allowlist, revue adversariale,
  vérification jsdom et validations automatisées terminés ; la branche reste
  empilée sur T0043/PR #72.

## Dependencies

- T0012 et T0022 — table `companies`, unicité propriétaire, grant de lecture et
  RLS propriétaire ;
- T0042 / PR #71 — onboarding desktop empilé, non fusionné dans `main` ;
- T0043 / PR #72 — catalogue desktop empilé sur T0042.

## Allowed areas

- nouveau module sous `apps/desktop/src/features/company-state/` et tests ;
- composition sous `apps/desktop/src/app/` et tests associés ;
- `apps/desktop/src/pages/HomePage.tsx` et tests associés ;
- callback borné sous `apps/desktop/src/features/company-onboarding/` et tests ;
- `apps/desktop/src/styles/index.css` si nécessaire ;
- `eng/authority-inventory.json` et `tests/authority/run.ps1` pour déclarer la
  nouvelle lecture sans relâcher les mutations ;
- ce ticket, l’index, `CURRENT_STATE.md`, `QUALITY.md`, `ARCHITECTURE.md` et
  `SECURITY.md`.

## Do not touch

- migrations, RLS, grants, seed, RPC, Edge Functions et types générés ;
- contrat d’onboarding, catalogue, commande d’achat, location, flotte et finance ;
- persistance, cookies, credentials Windows, cible distante et CSP production ;
- Rust/Tauri, bridge, SimConnect, manifests et lockfiles.

## Requirements

### 1. Lecture de présence fermée

- Appeler uniquement `GET /rest/v1/companies` avec bearer courant et clé anonyme
  publique, projection `id` et limite 2 afin de détecter une violation d’unicité.
- Refuser URL non loopback, méthode ou paramètre libre et borner délai, taille du
  corps, nombre de lignes et schéma de réponse.
- Retourner seulement une présence booléenne ; ne conserver, rendre, persister ou
  journaliser aucun identifiant ou nom de compagnie.
- Classer Auth, réponse invalide et indisponibilité sans exposer le détail amont.

### 2. Aiguillage explicite et reprenable

- Ne déclencher aucun réseau au rendu ; vérifier la présence uniquement sur
  action explicite de l’utilisateur.
- Obtenir le bearer au moment de la lecture depuis le gestionnaire de session,
  sans copier les tokens dans l’état React.
- Afficher l’onboarding si aucune compagnie n’existe et le catalogue si elle
  existe ; après création réussie, basculer immédiatement vers le catalogue.
- Borner double clic, annulation au démontage, retry et expiration Auth ; cette
  dernière efface la session puis revient au login.

### 3. Autorité vérifiable

- Déclarer le nouveau couple chemin/ressource dans l’allowlist Data API.
- Conserver le refus de toute lecture non déclarée, mutation Supabase directe,
  commande service-only, SQL embarqué et credential privilégié.
- Étendre les mutations négatives pour prouver qu’une déclaration dupliquée ou
  divergente ne peut pas étendre implicitement la lecture.

## Non-goals

- charger automatiquement une compagnie ou persister le résultat ;
- afficher profil, nom, identifiant, solde ou flotte possédée ;
- sélectionner une offre ou composer `AircraftPurchasePanel` ;
- modifier le backend, l’économie, l’onboarding ou le catalogue ;
- WebView live, staging, production, cible distante ou donnée réelle.

## Acceptance criteria

- [x] Une session peut vérifier explicitement zéro ou une compagnie propriétaire.
- [x] URL, headers, projection et limite sont fermés et testés.
- [x] Réponse malformée, duplicat, corps excessif, timeout, 401 et panne sont couverts.
- [x] Zéro réseau au rendu, concurrence, retry et démontage sont bornés.
- [x] L’accueil affiche onboarding ou catalogue et bascule après création réussie.
- [x] L’allowlist n’autorise que les deux lectures déclarées sans mutation cliente.
- [x] Tests ciblés, typecheck, couverture, build et gates applicables passent.
- [x] Documentation distingue branche empilée, lecture RLS et achat non composé.

## Security review

- actifs/données : bearer en mémoire, clé anonyme publique et identifiant de
  compagnie transitoire non exposé ;
- frontière : WebView non fiable → Data API → RLS propriétaire ;
- abus : ressource libre, lecture anonyme, duplication, mutation directe, fuite
  de bearer, réponse énorme ou forgée ;
- validation/autorisation : requête constante, session `authenticated`, RLS
  `auth.uid() = owner_id`, réponse strictement réduite à une présence ;
- atomicité : lecture seule ; l’onboarding reste T0022/T0023 ;
- logs/vie privée : aucun log, stockage ou rendu de credential ou compagnie.

## Maintenance review

- dette applicable : `KI-005`; transport, état de composition et panneaux restent
  séparés ;
- dette créée : aucune attendue ; toute lecture Data API reste déclarée et testée ;
- règle de sécurité : synchroniser allowlist canonique et gate dans ce ticket ;
- risque résiduel : WebView compromise, cible locale et composition achat absente.

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
2. Vérifier les branches aucune compagnie et compagnie existante.
3. Créer une compagnie synthétique et confirmer la bascule vers le catalogue.
4. Simuler expiration Auth, panne, réponse dupliquée, double clic et démontage.
5. Injecter les mutations négatives d’autorité et confirmer leur rejet.

Temps cible : 10 minutes.

## Rollback

Retirer le module de présence, la composition et l’entrée d’allowlist associée.
Aucun backend, donnée, mutation, cible ou persistance n’est modifié.

## Completion Report

### Summary

Le desktop dispose d'une commande de présence locale fermée qui réduit la seule
ligne RLS propriétaire à un booléen. L'accueil compose cette vérification avec
l'onboarding et le catalogue existants, y compris la bascule après création.

### Files changed

- transport, panneau et tests sous `features/company-state/` ;
- composition App/routes/accueil, callback onboarding borné et styles ;
- inventaire et gate d'autorité ;
- ticket, index, état courant, qualité, architecture et sécurité.

Aucun backend, contrat métier, achat, flotte, CSP, manifeste, lockfile ou
stockage n'est modifié.

### Commands and results

- tentative `git switch -c feature/T0044-desktop-company-state` dans le sandbox —
  bloquée par `.git` en lecture seule ; même commande autorisée — PASS ;
- `pnpm.cmd frontend:typecheck` — PASS ;
- `pnpm.cmd frontend:test` — PASS, 15 fichiers/146 tests ; 1 fichier/2 scénarios
  runtime T0040 ignorés sans environnement explicite ;
- `pnpm.cmd frontend:coverage` — PASS, 92,69 % statements, 86,79 % branches,
  95,04 % fonctions et 92,85 % lignes ;
- `pnpm.cmd frontend:build` — PASS, bundle JS 256,05 kB / 80,05 kB gzip ;
- `pnpm.cmd authority:check` — PASS, 9 mutations ;
- `pnpm.cmd data-policy:check` — PASS, 6 mutations ;
- `pnpm.cmd maintenance:check` — PASS, 8 mutations ;
- `git diff --check` — PASS, avertissements LF/CRLF seulement.

### Manual verification result

PASS le 3 août 2026 via fetch et DOM jsdom injectés : zéro réseau au rendu,
requête et headers exacts, absence/présence aiguillées, création suivie du
catalogue, double clic borné, retry, annulation au démontage et effacement de
session sur refus Auth. Les mutations Data API divergentes, orphelines et
dupliquées échouent comme attendu.

### Security and maintenance review result

La lecture est constante, locale et limitée ; seuls bearer et clé anonyme sont
envoyés, puis l'identifiant validé est réduit à une présence sans stockage, log
ou rendu. La RLS dérive le propriétaire et aucune mutation cliente n'est ajoutée.
Transport, état de composition et panneaux restent séparés ; `KI-005` n'est pas
aggravé. Aucune dépendance ou exception de sécurité n'est créée.

### Risks and limitations

T0044 reste empilé sur T0043/PR #72, elle-même dépendante de T0042/PR #71. La
CSP de production reste fermée et la preuve est injectée : aucun WebView live,
projet distant ou donnée réelle n'est revendiqué. Le catalogue ne compose pas
encore l'achat T0037 et une WebView compromise peut lire le bearer mémoire.

### Follow-ups

- publier une PR T0044 empilée sur T0043 puis rebaser ou changer sa base après
  les fusions ordonnées de T0042 et T0043 ;
- T0045 : composer la sélection catalogue avec l'achat T0037 ;
- traiter la persistance Windows dans un ticket de sécurité séparé.

### Documentation updated

Ce ticket, l'index, `CURRENT_STATE.md`, `QUALITY.md`, `ARCHITECTURE.md` et
`SECURITY.md`.

### Git status

- branche : `feature/T0044-desktop-company-state` ;
- base : T0043 au commit `340810c`, PR #72 vers T0042 ;
- dépendances : T0042/PR #71 puis T0043/PR #72 doivent fusionner dans l'ordre ;
- commit : à créer ;
- PR : à créer, base attendue `feature/T0043-desktop-aircraft-catalog`.
