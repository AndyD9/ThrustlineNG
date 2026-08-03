# T0057 — Créer un référentiel d'aérodromes borné et autoritaire

Status: Ready
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

- [ ] Une source canonique versionnée décrit au plus 200 aérodromes valides,
      sans doublon ni coordonnée hors bornes.
- [ ] `public.airports` est en lecture seule pour `authenticated`, sans mutation
      cliente possible, et son contenu correspond exactement à la source.
- [ ] Un brouillon de dispatch exige deux aérodromes connus et distincts ; un
      code inconnu est refusé de façon redigée.
- [ ] Le contrat public, l'idempotence et le rejeu T0047 restent inchangés.
- [ ] pgTAP, types générés et gates applicables passent avec leurs scénarios
      réellement découverts et consignés.
- [ ] La documentation précise l'origine des données et l'absence de dépendance
      externe.

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

À remplir après implémentation.

### Summary

### Files changed

### Commands and results

### Manual verification result

### Risks and limitations

### Follow-ups

### Documentation updated
