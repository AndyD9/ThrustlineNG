# T0057 — Créer un référentiel d'aérodromes borné et autoritaire

Status: Review
Owner: Andy
Branch: `feature/T0057-airport-reference`
Phase: 2
Risk: Medium
Security-sensitive: Yes

## Goal

Fournir côté serveur un référentiel versionné d'aérodromes portant code ICAO,
coordonnées et palier de popularité, puis exiger que tout brouillon de dispatch
référence deux aérodromes connus.

## Context

`flight_dispatches` accepte aujourd'hui n'importe quel code de quatre caractères
alphanumériques : aucune table n'associe un ICAO à des coordonnées ou à une
importance. Andy a décidé le 3 août 2026 que le revenu d'un vol serait dérivé du
temps, de la distance et de la popularité des aérodromes. Sans référentiel, le
serveur ne peut ni calculer une distance, ni appliquer un multiplicateur, et un
brouillon créé avec un code inconnu deviendrait impossible à clôturer.

Ce ticket est donc le prérequis technique de T0051. Il appartient au flux 2 du
mode accéléré et n'ajoute aucune valeur monétaire : les multiplicateurs associés
aux paliers appartiennent à la politique de clôture de T0051.

## Dependencies

- T0024 — inventaire et gate d'autorité ;
- T0047 — brouillon de dispatch et sa validation ICAO ;
- T0048 — frontière Auth du dispatch, dont les rejets doivent rester redigés ;
- décision d'Andy du 3 août 2026 sur un revenu dérivé de la popularité.

## Allowed areas

- une nouvelle source canonique `eng/airports.json` ;
- une nouvelle migration `supabase/migrations/` append-only ;
- `supabase/seed.sql` uniquement pour charger le référentiel ;
- `supabase/tests/database/` pour les nouveaux fichiers pgTAP ;
- `packages/database/src/database.types.ts` régénéré par le script existant ;
- `scripts/ci/test-backend.ps1`, `tests/backend/run.ps1` et
  `eng/authority-inventory.json` ;
- `docs/ARCHITECTURE.md`, `docs/PRODUCT.md`, `docs/QUALITY.md`,
  `docs/CURRENT_STATE.md` ;
- ce ticket et `docs/tickets/README.md`.

## Do not touch

- grand livre, politique économique T0028 et location T0032 ;
- table, RLS et registre privé T0047 au-delà de la validation ICAO ajoutée par
  une nouvelle migration ;
- contrat public, payload et réponse de l'Edge Function `dispatch-draft` ;
- desktop, Rust/Tauri, bridge, SimConnect et SimBrief ;
- workflows, manifests, lockfiles, cible distante et données réelles.

## Requirements

### 1. Source canonique bornée

- Déclarer dans `eng/airports.json` une liste versionnée de 200 aérodromes au
  plus, chacun avec code ICAO unique en quatre caractères, nom borné, latitude,
  longitude et palier de popularité.
- Utiliser exactement quatre paliers ordonnés et documentés ; le référentiel
  attribue le palier, il ne porte aucun montant ni multiplicateur.
- Écrire cette liste dans le dépôt sans importer de jeu de données tiers, sans
  téléchargement à l'exécution et sans dépendance nouvelle ; consigner
  l'origine des valeurs.
- Borner latitude à `[-90, 90]`, longitude à `[-180, 180]` et refuser tout
  doublon d'ICAO.

### 2. Table serveur

- Créer `public.airports` par une migration append-only, avec RLS activée et
  forcée, `select` seul accordé à `authenticated` et aucune mutation accordée à
  un rôle client.
- Contraindre le format ICAO, les bornes de coordonnées, la liste fermée de
  paliers et `schema_version`.
- Charger le référentiel depuis le seed de façon idempotente, sans donnée
  personnelle ni identité.
- Le gate backend doit échouer si la table livrée diverge de
  `eng/airports.json`.

### 3. Validation du dispatch

- Par une nouvelle migration append-only, exiger que
  `create_dispatch_draft` référence deux aérodromes présents dans le
  référentiel, en plus des règles existantes de normalisation et de distinction.
- Refuser un code inconnu par le même message générique que les autres rejets
  métier, sans divulguer le contenu du référentiel ni de détail SQL.
- Ne modifier ni la signature de la commande, ni le contrat public de l'Edge
  Function, ni l'idempotence, ni les verrous existants.

### 4. Preuves

- Les pgTAP couvrent ACL/grants, RLS, isolation A/B/anonyme, refus de mutation
  cliente, cohérence des bornes, unicité ICAO, acceptation de deux aérodromes
  connus, refus d'un code inconnu et stabilité du rejeu T0047.
- Les types générés restent stables et le gate d'autorité classe la nouvelle
  lecture ou son absence de consommateur client de façon explicite.

## Non-goals

- exposer le référentiel au desktop ou proposer un sélecteur d'aérodromes ;
- calculer une distance, un temps de vol, un revenu ou un multiplicateur ;
- couvrir tous les aérodromes mondiaux, les pistes, fréquences, procédures,
  la météo ou SimBrief ;
- importer un jeu de données externe ou introduire une obligation de licence.

## Acceptance criteria

- [x] Une source canonique versionnée décrit au plus 200 aérodromes valides,
      sans doublon ni coordonnée hors bornes.
- [x] `public.airports` est en lecture seule pour `authenticated`, sans mutation
      cliente possible, et son contenu correspond exactement à la source.
- [x] Un brouillon de dispatch exige deux aérodromes connus et distincts ; un
      code inconnu est refusé de façon redigée.
- [x] Le contrat public, l'idempotence et le rejeu T0047 restent inchangés.
- [x] pgTAP, types générés et gates applicables passent avec leurs scénarios
      réellement découverts et consignés.
- [x] La documentation précise l'origine des données et l'absence de dépendance
      externe.

Réserve sur le cinquième critère : `backend:check`, `backend:test`,
`backend:types:check`, `authority:check` et `data-policy:check` passent.
`maintenance:check` échoue sur une dérive d'index T0049 déjà présente sur
`origin/main` et déjà réparée par une branche en attente de fusion, sans lien
avec ce ticket. `ci:backend` reste réservé au runner Linux.

## Security review

- actifs : intégrité du référentiel, cohérence des dispatchs, contenu du
  référentiel ;
- frontière : client non fiable → lecture RLS ; migration et seed côté serveur ;
- abus : mutation cliente du référentiel pour gonfler un futur revenu, ICAO
  inconnu créant un dispatch inclôturable, énumération du référentiel par les
  messages d'erreur ;
- validation/autorisation : contraintes SQL, `select` seul pour les rôles
  clients, rejets génériques ;
- atomicité/idempotence : seed idempotent, migration append-only, aucune
  modification du registre T0047 ;
- logs/vie privée : aucune donnée personnelle, aucun détail SQL rendu.

## Maintenance review

- problèmes applicables : `KI-021` interdit les données réelles utilisateur ; les
  coordonnées d'aérodromes ne sont pas des données personnelles ;
- dette créée : le référentiel restera partiel et devra être élargi ou remplacé
  par une source maintenue avant toute publication ; à consigner ;
- règle de sécurité : un référentiel autoritaire ne doit jamais être mutable par
  un rôle client ;
- contrôle manuel à automatiser : la comparaison source/table appartient au gate
  backend, pas à une inspection ;
- risque résiduel : les paliers de popularité de l'alpha sont un choix de
  cadrage, pas une mesure de trafic réel.

## Automated validation

```powershell
pnpm.cmd backend:check
pnpm.cmd backend:start
pnpm.cmd backend:reset
pnpm.cmd backend:test
pnpm.cmd backend:types:check
pnpm.cmd backend:stop
pnpm.cmd authority:check
pnpm.cmd data-policy:check
pnpm.cmd maintenance:check
git diff --check
```

## Manual verification

1. Réinitialiser la pile et confirmer le chargement du référentiel.
2. Vérifier qu'`authenticated` lit la table et qu'`insert`/`update`/`delete` sont
   refusés, y compris pour `anon`.
3. Créer un brouillon avec deux aérodromes connus, puis avec un code inconnu.
4. Rejouer une intention existante et confirmer un contrat inchangé.

Temps cible : 10 minutes hors démarrage de la pile.

## Rollback

Avant fusion, abandonner la branche. Après fusion, corriger uniquement par une
nouvelle migration append-only ; ne jamais supprimer une migration livrée ni un
dispatch existant.

## Completion Report

### Summary

Le référentiel d'aérodromes est livré comme source canonique versionnée
`eng/airports.json` de 103 aérodromes écrits à la main, projetée de façon
idempotente dans `supabase/seed.sql` et matérialisée par la neuvième migration
append-only `20260803000300_bounded_airport_reference.sql`.

`public.airports` porte un code ICAO en clé primaire, un nom borné à 64
caractères ASCII non entourés d'espaces, une latitude `numeric(7,4)` et une
longitude `numeric(8,4)` contraintes à `[-90, 90]` et `[-180, 180]`, un palier de
popularité pris dans la liste fermée ordonnée `regional`, `standard`, `major`,
`hub`, et une `schema_version` contrainte à 1. La table active et force RLS,
n'accorde que `select` à `authenticated` par la politique unique
`airports_select_reference`, et ne laisse aucune mutation à `public`, `anon`,
`authenticated` ou `service_role`. Le référentiel ne porte ni montant, ni devise,
ni multiplicateur : la tarification reste à la politique de clôture T0051 qui le
lira.

La même migration remplace `create_dispatch_draft` par `create or replace` sans
toucher sa signature, son contrat public, son idempotence, ses verrous ni ses
messages : la validation bornée existante gagne deux `exists` sur le référentiel,
de sorte qu'un brouillon ne peut plus nommer un aérodrome que le serveur serait
incapable de positionner. Un code inconnu réutilise exactement le message d'un
code mal formé, ce qui le rend indiscernable et interdit d'énumérer le
référentiel.

Deux gates protègent la cohérence source/livraison : `backend:check` reconstruit
la projection SQL depuis `eng/airports.json` et échoue sur toute divergence
textuelle, sur un chargement dissimulé dans un commentaire SQL et sur un second
statement de chargement ; le harnais CI compare en plus la table réellement
chargée à la source, ligne par ligne, avant d'exécuter les pgTAP.

### Files changed

- `eng/airports.json` — nouvelle source canonique versionnée, 103 aérodromes,
  quatre paliers ordonnés, origine des valeurs consignée ;
- `supabase/migrations/20260803000300_bounded_airport_reference.sql` — nouvelle
  migration append-only : table, contraintes, RLS forcée, grants, politique de
  lecture, commentaires et revalidation de `create_dispatch_draft` ;
- `supabase/seed.sql` — chargement idempotent `on conflict … do update` de la
  projection du référentiel, sans identité ni donnée personnelle ;
- `supabase/tests/database/airport_reference_structure.test.sql` — nouveau,
  16 assertions ACL/RLS/politique/contraintes et signature de commande ;
- `supabase/tests/database/airport_reference.test.sql` — nouveau, 28 assertions
  bornes, unicité, isolation A/B/anonyme, refus de mutation cliente, rejeu
  idempotent du chargement et validation de dispatch ;
- `tests/backend/run.ps1` — validation de la source, égalité de la projection
  seed, invariants de la migration, marqueurs pgTAP, marqueurs de types et cinq
  nouvelles mutations négatives ;
- `scripts/ci/test-backend.ps1` — comparaison table ↔ source, dix-huit fichiers
  pgTAP exigés et rapport mis à jour ;
- `packages/database/src/database.types.ts` — régénéré par le script existant,
  ajout de la seule table `airports` ;
- `eng/authority-inventory.json` — référentiel rattaché au domaine `dispatch`,
  trois marqueurs de preuve et absence de consommateur client déclarée
  explicitement ;
- `docs/ARCHITECTURE.md`, `docs/PRODUCT.md`, `docs/QUALITY.md`,
  `docs/CURRENT_STATE.md`, ce ticket et `docs/tickets/README.md`.

### Commands and results

Environnement : Windows 11 Pro 26200, PowerShell 7.6.4 et Windows PowerShell pour
les gates, Docker Desktop 29.6.2, Supabase CLI 2.109.1 isolée, PostgreSQL 17.

| Commande | Résultat |
| --- | --- |
| `pnpm backend:check` | Réussi — 35 mutations négatives |
| `pnpm backend:start` | Réussi |
| `pnpm backend:reset` (×2) | Réussi — neuf migrations append-only puis seed |
| `pnpm backend:test` | Réussi — 18 fichiers/356 assertions, `Result: PASS` |
| `pnpm backend:types` | Réussi — ajout de la seule table `airports`, 27 lignes |
| `pnpm backend:types:check` | Réussi — types stables |
| `pnpm backend:stop` | Réussi |
| `pnpm authority:check` | Réussi — 9 mutations négatives |
| `pnpm data-policy:check` | Réussi — 6 mutations négatives |
| `pnpm maintenance:check` | Échoué sur une dérive préexistante, hors périmètre |
| `git diff --check` | Réussi — aucun problème d'espaces |
| `pnpm ci:backend` | Non exécuté — harnais réservé au runner Linux |

`maintenance:check` échoue sur `origin/main` avant toute modification de ce
ticket : le fichier T0049 déclare `Done` alors que l'index déclare `Review`. La
réparation existe déjà dans le commit `56ee4e3` de la branche
`docs/T0050-record-merge`, poussée et en attente de fusion. Aucune ligne T0049
n'est touchée ici et la dérive n'est pas attribuée à T0057.

Deux échecs intermédiaires sont consignés parce qu'ils portent un apprentissage.
Le premier `backend:start` a échoué sur `syntax error at or near "on"` : le
commentaire d'en-tête du seed et le `insert` étaient collés sur une même ligne,
donc tout le statement était commenté et seul le `on conflict` restait analysable.
Le gate ne l'avait pas vu, il exige désormais un saut de ligne avant la projection
et refuse un chargement précédé de `--` sur la même ligne. Le second échec venait
de `backend:test` rejouant l'ancienne copie d'un fichier pgTAP : les sources ne
sont copiées dans le runtime isolé qu'au `backend:start`.

### Manual verification result

Vérification manuelle du 3 août 2026 sur la pile locale, données synthétiques :

1. Après reset, le référentiel rend `103|103|4|0|1` : 103 lignes, 103 codes
   uniques, quatre paliers, aucune coordonnée hors bornes, une seule
   `schema_version`. La comparaison avec `eng/airports.json` est exacte sur les
   103 lignes, apostrophes échappées comprises — `Chicago O'Hare` et
   `Nice Cote d'Azur` reviennent intactes.
2. `authenticated` lit 103 aérodromes et reçoit `SQLSTATE 42501`
   « permission denied for table airports » sur `insert`, `update` et `delete`;
   `anon` reçoit `42501` en lecture.
3. ` lfpg `/`lfml` sont normalisés en `LFPG`/`LFML` et créent un seul brouillon
   `cc9c4506-defc-4efc-8fab-d3968ebb81cc` horodaté
   `2026-08-03T16:54:40.654855+00:00`. Un départ inconnu `ZZZZ`, une arrivée
   inconnue `ZZZZ` et un code mal formé `ABC` rendent tous trois `SQLSTATE 22023`
   avec le message identique « Departure and arrival must be distinct
   four-character ICAO codes. »; aucun brouillon n'est créé pour l'avion refusé.
4. Le rejeu de la clé d'idempotence existante rend exactement la même réponse à
   sept champs, même `dispatchId` et même `createdAt` : le contrat T0047 est
   inchangé. L'état final montre un brouillon `LFPG` → `LFML` sans `started_at`
   et une seule commande privée.
5. Le rejeu du chargement du seed est prouvé en pgTAP et non seulement par la
   présence de la clause : réexécuter la même ligne avec `on conflict … do
   update` laisse le nombre d'aérodromes inchangé et fait converger la ligne sur
   sa valeur canonique.

Durée effective hors démarrage de la pile : environ 6 minutes, sous la cible de
10 minutes.

### Risks and limitations

- Le référentiel est volontairement partiel : 103 aérodromes sur les milliers
  existants, coordonnées transcrites à la main et arrondies à quatre décimales,
  noms restreints à l'ASCII. Il devra être élargi ou remplacé par une source
  maintenue avant toute ouverture externe.
- Les paliers de popularité sont un choix de cadrage de l'alpha, pas une mesure
  du trafic réel ; ils n'ont encore aucun effet, T0051 leur associera des
  multiplicateurs.
- Le chargement passe par `supabase/seed.sql`, conformément au ticket : il est
  donc rejoué à chaque reset local et en CI, mais un futur déploiement distant
  exigera un mécanisme de chargement propre. À traiter par le ticket qui ouvrira
  une cible distante.
- `flight_dispatches` ne porte pas de clé étrangère vers `airports` : la
  validation vit dans la commande, seul chemin d'écriture possible puisque
  aucune insertion directe n'est accordée. Une contrainte référentielle serait
  une défense supplémentaire mais dépasse l'exigence du ticket.
- La lecture du référentiel par `create_dispatch_draft` repose sur son exécution
  `security definer` par le propriétaire de la migration, qui contourne RLS. Si ce
  propriétaire perdait `bypassrls`, la politique `to authenticated` ne
  s'appliquerait pas à lui et la commande refuserait tous les brouillons : le
  mode de défaillance est fermé, donc acceptable, mais il est consigné plutôt que
  contourné par un élargissement de la politique.
- `pnpm ci:backend` n'est pas exécutable depuis Windows ; la comparaison
  table ↔ source qu'il ajoute a été rejouée manuellement avec la même logique,
  mais sa preuve dans le harnais Linux reste attendue de la CI.
- Preuves locales et synthétiques : ni cible distante, ni consommateur desktop,
  ni donnée réelle ne sont validés.

### Follow-ups

- `maintenance:check` reste rouge sur `main` jusqu'à la fusion de
  `docs/T0050-record-merge`, qui répare la ligne d'index T0049.
- T0051 peut sortir de `Draft` une fois T0050 puis T0057 fusionnés ; il
  consommera les coordonnées pour la distance et les paliers pour le
  multiplicateur.
- Candidat `LEARNINGS.md` : `backend:test`, `backend:reset` et
  `backend:types` s'exécutent sur les sources copiées dans le runtime isolé par
  `backend:start`. Toute modification de migration, de seed ou de fichier pgTAP
  exige un nouveau `backend:start`, sinon la commande rejoue silencieusement la
  version précédente et peut produire un faux succès comme un faux échec. Deux
  occurrences sont désormais consignées dans ce rapport ; la note est ajoutée à
  `docs/QUALITY.md` et mérite un encodage exécutable si elle se reproduit.
- Candidat `LEARNINGS.md` : une comparaison de gate par `Contains` ne prouve pas
  qu'un statement SQL est actif. Vérifier aussi le contexte, ici l'absence de
  commentaire ouvrant sur la même ligne.

### Documentation updated

- `docs/ARCHITECTURE.md` — table, contraintes, autorité, gates et revalidation de
  la commande de dispatch ;
- `docs/PRODUCT.md` — règle produit du référentiel borné et mesure de réussite ;
- `docs/QUALITY.md` — preuve T0057 datée, nombre de fichiers et d'assertions
  pgTAP à jour, et piège de la copie du runtime isolé ;
- `docs/CURRENT_STATE.md` — capacité réellement livrée, classification
  d'autorité et prochain ticket recommandé ;
- `eng/authority-inventory.json` — preuves et absence de consommateur client ;
- `docs/tickets/README.md` — statut du ticket.
