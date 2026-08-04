# T0051 — Clôturer un vol une seule fois, régler son revenu et sa réputation

Status: Done
Owner: Andy
Branch: `feature/T0051-authoritative-flight-settlement`
Phase: 2
Risk: High
Security-sensitive: Yes

## Goal

Accepter un rapport de vol versionné, clôturer le vol exactement une fois, écrire
un règlement net unique dans le grand livre immuable, mettre à jour la réputation
de la compagnie et rendre l'avion immédiatement disponible.

## Context

Le gate de l'alpha jouable se termine par « rapport versionné, clôture unique et
écriture dans le grand livre ». T0020 fournit les écritures append-only, T0029 le
précédent d'extension de `entry_type`, T0050 le vol actif et T0057 le référentiel
d'aérodromes nécessaire au calcul de distance et de popularité.

Les décisions produit et économiques attendues sont désormais prises : ce ticket
n'a plus d'ambiguïté de cadrage. Il est resté `Draft` uniquement pour une raison
technique d'ordre d'intégration, afin de ne pas rouvrir une pile de branches.

Condition de sortie du `Draft` : T0050 et T0057 fusionnés dans `main`. Elle est
satisfaite le 4 août 2026 — T0050 par la PR #89 au merge `6577125`, T0057 par la
PR #91 au merge `df685b7` — et la branche
`feature/T0051-authoritative-flight-settlement` part du `origin/main` au merge
`2a07113`, sans branche empilée.

## Decisions taken

Décisions d'Andy du 3 août 2026, à citer dans le Completion Report :

1. **Revenu dérivé.** Le règlement d'un vol est calculé à partir du temps de
   bloc, de la distance parcourue entre les deux aérodromes et de la popularité
   de ces aérodromes.
2. **Forme comptable.** Une écriture nette unique par vol, pas de couple
   revenu/coût séparé.
3. **Devise.** `EUR`, cohérente avec la politique d'ouverture T0028.
4. **Autorité des champs.** Choix technique délégué à l'implémentation et arrêté
   ainsi : la distance vient du référentiel T0057, le temps de bloc retenu est le
   minimum entre le temps déclaré borné et le temps réellement écoulé côté
   serveur, le multiplicateur vient des paliers du référentiel, et le montant
   comme la devise sont recalculés côté serveur. Le rapport client ne fournit que
   la nature de fin de vol, un temps de bloc déclaré et quelques mesures bornées
   consignées sans effet monétaire.
5. **Vol interrompu.** Un vol interrompu ou en crash est clôturable et reçoit le
   revenu minimum de la politique, jamais zéro et jamais le barème complet.
6. **Avion.** L'avion redevient immédiatement disponible pour un nouveau
   dispatch dès la clôture.
7. **Réputation.** Attendue dès ce ticket, purement informative : score borné
   `0–100` partant de `50`, `+1` par vol terminé, `−3` par vol interrompu, écrite
   dans la transaction de clôture, sans aucun effet sur le revenu, le dispatch ou
   l'achat.

Barème retenu, en unités mineures `EUR` :

```text
net = (15000 + 120 × distance_nm + 300 × block_minutes) × hub_multiplier
plancher vol interrompu : 5 000        (50 EUR)
plafond par vol         : 2 000 000    (20 000 EUR)
multiplicateurs de palier : 0,90 / 1,00 / 1,15 / 1,30
hub_multiplier = moyenne des paliers du départ et de l'arrivée
```

Référence de contrôle : un vol de 150 NM en 75 minutes entre deux aérodromes de
palier standard règle environ `55 500` unités mineures, soit 555 EUR.

## Dependencies

- T0020 — grand livre immuable et sujet financier opaque ;
- T0028 — politique économique d'ouverture, référence de devise, non modifiée ;
- T0029 — précédent d'extension de `entry_type` par migration append-only ;
- T0047 — dispatch et son registre privé ;
- T0050 — vol actif à clôturer, à fusionner avant le passage `Ready` ;
- T0057 — référentiel d'aérodromes, à fusionner avant le passage `Ready`.

## Allowed areas

- une nouvelle source canonique `eng/flight-settlement-policy.json` ;
- une nouvelle migration `supabase/migrations/` append-only ;
- `supabase/tests/database/` pour les nouveaux fichiers pgTAP ;
- `packages/database/src/database.types.ts` régénéré par le script existant ;
- `scripts/ci/test-backend.ps1`, `tests/backend/run.ps1` et
  `eng/authority-inventory.json` ;
- `docs/PRODUCT.md`, `docs/ARCHITECTURE.md`, `docs/SECURITY.md`,
  `docs/QUALITY.md`, `docs/CURRENT_STATE.md` ;
- ce ticket et `docs/tickets/README.md`.

## Do not touch

- `eng/economy-policy.json`, la fonction `company-onboarding` et son gate de copie
  embarquée : la politique d'ouverture T0028 reste intacte ;
- écritures existantes du grand livre : aucun `update`, `delete` ou `truncate`,
  aucune réécriture d'une écriture livrée ;
- migrations livrées : toute évolution passe par un nouveau fichier ;
- Edge Functions et frontière Auth : l'endpoint de clôture est un ticket distinct ;
- location T0032, opérations passives, équipage, maintenance et usure ;
- desktop, Rust/Tauri, bridge, SimConnect et SimBrief ;
- workflows, manifests, lockfiles, cible distante et données réelles.

## Requirements

### 1. Politique versionnée et vérifiée

- Déclarer le barème, le plancher, le plafond, les multiplicateurs de palier, la
  devise et les deltas de réputation dans `eng/flight-settlement-policy.json`
  avec un `schemaVersion`.
- La migration embarque une projection strictement identique de ces valeurs ; le
  gate backend échoue sur toute divergence entre la source canonique et la copie
  livrée, ainsi que sur toute surcharge par environnement.
- Aucune valeur monétaire n'est lue depuis une variable d'environnement.

### 2. États terminaux et disponibilité de l'avion

- Étendre la liste fermée d'états à `draft`, `active`, `completed` et
  `interrupted`, les deux derniers étant terminaux et sans transition sortante.
- Remplacer l'unicité globale par avion par un index unique partiel limité aux
  états non terminaux, afin qu'un avion redevienne immédiatement dispatchable
  après clôture, sans jamais supprimer un dispatch historique.
- Conserver la lecture `authenticated` filtrée par la compagnie du sujet Auth
  pour tous les états.

### 3. Rapport de vol borné

- Créer une table de rapports versionnés, en écriture serveur uniquement, liée à
  un dispatch et unique par dispatch.
- Accepter uniquement une nature de fin de vol appartenant à une liste fermée, un
  temps de bloc déclaré borné à `[0, 1440]` minutes et des mesures facultatives
  bornées, sans valeur monétaire ni identité.
- Refuser tout champ supplémentaire et toute valeur hors bornes avant écriture.

### 4. Commande de clôture

- Ajouter une commande `security definer`, `set search_path = ''`, exécutable
  seulement par `service_role`, acceptant propriétaire vérifié, clé
  d'idempotence, dispatch et rapport borné.
- Verrouiller la compagnie, le sujet financier puis le dispatch ; dériver
  compagnie, avion, aérodromes et temps écoulé côté serveur.
- Calculer la distance en milles nautiques par formule de grand cercle depuis les
  coordonnées du référentiel, retenir `min(temps déclaré, temps écoulé serveur)`
  comme temps de bloc, appliquer le multiplicateur de palier, borner par le
  plafond, puis appliquer le plancher pour une fin interrompue.
- Écrire dans une seule transaction : état terminal du dispatch, rapport,
  écriture nette `flight_settlement` positive dans le grand livre, événement de
  réputation et registre d'idempotence lié à l'empreinte du payload.
- Refuser un compte en suppression, un dispatch appartenant à une autre
  compagnie, un dispatch non actif et une clé déjà utilisée avec un payload
  différent, sans révéler l'existence de l'objet visé.
- Un rejeu identique rend exactement la même réponse et n'écrit rien de plus.

### 5. Réputation informative

- Stocker des événements de réputation append-only sans identité Auth directe,
  sans privilège API, avec RLS activée et forcée.
- Exposer à `authenticated` une lecture unique dérivant la compagnie de
  `auth.uid()`, qui rend le score borné `clamp(50 + somme des deltas, 0, 100)`.
- Aucun rôle client ne peut écrire un événement ; aucune capacité n'est bloquée
  ou modulée par le score dans l'alpha.

### 6. Preuves SQL

- Les pgTAP couvrent ACL/grants, RLS, isolation A/B/anonyme, montant exact du
  barème sur au moins deux distances et deux paliers, plafond atteint, plancher
  d'un vol interrompu, temps déclaré supérieur au temps serveur ramené au temps
  serveur, rapport hors bornes, rejeu, collision de clé, seconde clôture,
  dispatch non actif, compte en suppression, rollback injecté, disponibilité
  immédiate de l'avion et bornes du score de réputation.
- Deux sessions concurrentes qui clôturent le même vol convergent vers une seule
  écriture, un seul rapport et un seul événement de réputation.
- Le solde recalculé après clôture est exactement celui attendu et les types
  générés restent stables.

## Non-goals

- exposer une frontière Auth, un appel desktop ou une lecture applicative ;
- télémétrie, détection de phases et reprise, qui relèvent du flux bridge ;
- rendre la réputation bloquante ou modulatrice du revenu ;
- maintenance, usure, équipage, opérations passives et location T0032 ;
- déploiement distant ou admission de données réelles.

## Acceptance criteria

- [x] T0050 et T0057 sont fusionnés dans `main` avant le passage en `Ready` —
      PR #89 merge `6577125` et PR #91 merge `df685b7`.
- [x] Un vol actif possédé se clôture exactement une fois, avec état terminal,
      rapport borné, écriture nette unique et événement de réputation dans la
      même transaction.
- [x] Le montant correspond exactement au barème versionné, plafond et plancher
      compris ; aucun montant, devise, distance ou solde client n'est accepté.
- [x] Un temps de bloc déclaré supérieur au temps réellement écoulé côté serveur
      est ramené au temps serveur.
- [x] Rejeu, collision, seconde clôture, rapport hors bornes, dispatch étranger,
      dispatch non actif et compte en suppression échouent fermés sans fuite.
- [x] L'avion est immédiatement dispatchable après clôture et aucun dispatch
      historique n'est supprimé.
- [x] Le score de réputation reste borné `0–100`, informatif, lisible seulement
      par son propriétaire et non modifiable par un client.
- [x] pgTAP, types générés et gates applicables passent avec leurs scénarios
      réellement découverts et consignés.

## Security review

- actifs : argent, grand livre immuable, état de vol, rapport, réputation,
  idempotence ;
- frontière : bridge et desktop non fiables → future frontière Auth →
  `service_role` → transaction unique ;
- abus : temps de bloc ou distance gonflés, montant ou devise forgés, double
  clôture, clôture du vol d'un tiers, création de valeur par rejeu divergent,
  réputation écrite par un client ;
- validation/autorisation : distance issue du référentiel serveur, temps borné
  par l'horloge serveur, montant recalculé, propriétaire vérifié, verrous
  `for update`, listes fermées d'états et de natures de fin ;
- atomicité/idempotence : une seule transaction, registre privé
  `(propriétaire, clé)` avec empreinte de payload, refus de toute écriture
  partielle ;
- logs/vie privée : aucune donnée personnelle, aucun identifiant Auth dans les
  écritures financières ou de réputation, aucun détail SQL rendu.

## Maintenance review

- problèmes applicables : `KI-021` interdit les données réelles ; `KI-010`
  rappelle l'absence de retour arrière après création de données réelles ;
- dette créée : le barème de l'alpha est volontairement simple et devra être
  revu avant toute ouverture externe ; le plafond protège l'économie sans
  remplacer un équilibrage mesuré ;
- règle de sécurité : aucune valeur monétaire, distance ou durée facturable ne
  franchit une frontière cliente sans être recalculée ou bornée par le serveur ;
- contrôle manuel à automatiser : cohérence du solde et bornes du score doivent
  rester dans le harnais CI backend ;
- risque résiduel : la réputation reste informative ; aucun équilibrage
  économique long terme n'est prouvé par ce ticket.

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

1. Préparer compagnie, avion, brouillon et vol actif synthétiques.
2. Clôturer un vol terminé, relever montant, solde, état, réputation et
   disponibilité de l'avion, puis rejouer la même clé.
3. Clôturer un second vol interrompu et confirmer le plancher et le `−3`.
4. Tenter une seconde clôture, un rapport hors bornes, un temps déclaré
   surévalué et un vol appartenant à une autre identité ; confirmer
   l'immuabilité des écritures et l'absence de fuite.

Temps cible : 10 minutes hors démarrage de la pile.

## Rollback

Avant fusion, abandonner la branche. Après fusion, corriger uniquement par une
nouvelle migration append-only et, si un montant erroné a été écrit, par une
écriture compensatoire explicitement décidée par Andy ; ne jamais modifier ni
supprimer une écriture existante.

## Completion Report

Branche : `feature/T0051-authoritative-flight-settlement`, créée depuis
`origin/main` au merge `2a07113` (PR #98). Aucune branche empilée.

Andy a fusionné la PR #102 dans `main` le 4 août 2026 par le merge `c0972fa`, sur
le commit de tête `8627fd3`, avec ses trois checks verts : `Audits, licences and
SBOM` en 4 min 9 s, `Supabase PostgreSQL 17` en 3 min 12 s et `Windows
multi-stack` en 16 min 16 s. Le ticket est `Done` : critères satisfaits,
validations locales et CI consignées, vérification manuelle réellement exécutée sur
état commité et documentation cohérente.

La seule réserve du ticket est levée par cette CI. Le job Linux exécute
`ci:backend`, non exécutable sous Windows : il rend
`flight_settlement.test.sql ... ok`, `flight_settlement_structure.test.sql ... ok`,
`Result: PASS`, puis `Flight closure concurrency passed: 2 sessions, 1 completed
flight, 1 report, 1 reputation event, 1 credit of 35194 minor units.` et conclut
par `Backend CI passed: 2 resets, 20 pgTAP files, ... flight start and flight
settlement, ...`. La convergence de deux clôtures réellement concurrentes sur le
même vol est donc prouvée par le harnais, et non seulement par un raisonnement sur
les verrous.

Le premier essai de publication avait échoué sur ce même job en 25 secondes, pour
le défaut de portabilité du gate consigné dans « Commands and results » ; le
correctif `8627fd3` est celui que la CI valide.

### Summary

Les sept décisions d'Andy du 3 août 2026 sont encodées telles quelles : revenu net
unique dérivé du temps de bloc, de la distance et de la popularité des aérodromes,
en `EUR`, plancher pour un vol interrompu, avion immédiatement redisponible et
réputation informative bornée `0–100` partant de `50` avec `+1` et `−3`.

`eng/flight-settlement-policy.json` est la source canonique du barème. La dixième
migration append-only en embarque une projection dans
`private.flight_settlement_policy()`, que `backend:check` reconstruit depuis la
source et compare texte à texte : aucune valeur monétaire ne peut dériver entre
les deux et aucune ne vient d'une variable d'environnement ou d'un réglage de
session.

La liste fermée d'états de dispatch passe à quatre valeurs, `completed` et
`interrupted` étant terminales, et `closed_at` n'existe que pour elles, dérivé de
`clock_timestamp()` par le trigger T0050 étendu — qui préserve désormais
`started_at` au lieu de l'effacer et refuse la création directe d'un état terminal.
L'unicité globale par avion devient l'index unique partiel
`flight_dispatches_one_open_per_aircraft` limité à `draft` et `active` : un vol
clôturé reste en historique et l'avion redevient immédiatement dispatchable. La
validation de `create_dispatch_draft` est réécrite par `create or replace` pour ne
regarder que les dispatchs ouverts, à signature, contrat public, idempotence,
verrous et revalidation d'aérodromes inchangés, et le registre privé de brouillons
perd son unicité par avion, devenue redondante.

`close_flight`, `security definer` à `search_path` vide et réservée à
`service_role`, accepte un propriétaire vérifié, une clé d'idempotence, un dispatch
et un rapport `jsonb` dont le jeu de clés est strictement validé : `outcome` et
`blockMinutes` obligatoires, `landingVerticalSpeedFpm` et `fuelUsedKg` facultatifs,
toute clé supplémentaire refusée, tout nombre non entier ou hors bornes refusé.
Elle verrouille compagnie, sujet financier puis dispatch, refuse un compte en
suppression, retient `min(temps déclaré, temps écoulé depuis l'horodatage serveur)`,
dérive la distance de grand cercle des deux positions du référentiel T0057,
recalcule le montant, l'écrête au plafond puis applique le plancher à une fin
interrompue, et écrit dans une seule transaction l'état terminal, le rapport,
l'écriture nette positive `flight_settlement`, l'événement de réputation et son
registre d'idempotence lié à l'empreinte du payload.

Les trois tables ajoutées vivent dans `private`, forcent RLS et n'accordent aucun
privilège à `anon`, `authenticated` ou `service_role` ; les événements de
réputation sont append-only par trigger comme les écritures du grand livre. La
seule lecture cliente est `public.get_company_reputation`, qui exige une session
`authenticated` non anonyme, dérive la compagnie de `auth.uid()` et rend un score
borné qui n'autorise, ne refuse et ne module aucune capacité.

### Files changed

- `eng/flight-settlement-policy.json` — nouvelle source canonique v1 : barème,
  plancher, plafond, quatre multiplicateurs de palier, devise et deltas de
  réputation ;
- `supabase/migrations/20260804000100_authoritative_flight_settlement.sql` —
  nouvelle migration append-only : états terminaux, `closed_at`, index partiel,
  extension du type d'écriture, projection de politique, distance de grand cercle,
  multiplicateur de palier, tables de rapport, de réputation et d'idempotence,
  `close_flight`, `get_company_reputation` et le `create or replace` de
  `create_dispatch_draft` ;
- `supabase/tests/database/flight_settlement_structure.test.sql` — nouveau,
  32 assertions d'ACL, RLS, contraintes, index, triggers et privilèges ;
- `supabase/tests/database/flight_settlement.test.sql` — nouveau, 39 assertions de
  comportement, montants exacts, refus, rollback, disponibilité et bornes de
  score ;
- `supabase/tests/database/flight_start_structure.test.sql` — une seule assertion
  mise à jour : l'exclusivité par avion, que T0050 vérifiait comme contrainte de
  table, est désormais vérifiée sur l'index partiel qui la porte. C'est une mise à
  jour de consommateur imposée par l'exigence 2, signalée ici plutôt que faite en
  silence, et non une correction opportuniste ;
- `tests/backend/run.ps1` — bloc de contrôles T0051, projection reconstruite,
  assertions de types, exigences CI et sept nouvelles mutations négatives ;
- `scripts/ci/test-backend.ps1` — vingt fichiers pgTAP exigés et course de deux
  clôtures concurrentes sur le même vol ;
- `eng/authority-inventory.json` — `flight-finalization` et
  `reputation-progression` passent de `not-implemented` à `server-authoritative`
  partiel, `finance` et `flight-runtime` voient leurs preuves et limites précisées ;
- `packages/database/src/database.types.ts` — régénéré par le script existant ;
- `docs/PRODUCT.md`, `docs/ARCHITECTURE.md`, `docs/SECURITY.md`,
  `docs/QUALITY.md`, `docs/CURRENT_STATE.md`, `docs/tickets/README.md` et ce
  ticket.

`docs/PRODUCT.md` était autorisé et a été utilisé : le barème, le plancher, le
plafond et la réputation sont des règles produit, pas des détails
d'implémentation.

### Commands and results

Le 4 août 2026, depuis la racine, sur Windows 11 Pro 26200, Docker Desktop 29.6.2,
Supabase CLI 2.109.1 isolée, PostgreSQL 17 :

| Commande | Résultat |
| --- | --- |
| `pnpm.cmd backend:check` | Réussi — 42 mutations négatives, dont 7 nouvelles |
| `pnpm.cmd backend:start` | Réussi — pile isolée, loopback IPv4 |
| `pnpm.cmd backend:reset` | Réussi deux fois — 10 migrations append-only appliquées |
| `pnpm.cmd backend:test` | Réussi — 20 fichiers/427 assertions, `Result: PASS` |
| `pnpm.cmd backend:types` | Réussi — 21 lignes ajoutées |
| `pnpm.cmd backend:types:check` | Réussi — types stables |
| `pnpm.cmd authority:check` | Réussi — 10 étapes, 13 domaines, 3 surfaces, 9 mutations |
| `pnpm.cmd data-policy:check` | Réussi — 6 mutations négatives |
| `pnpm.cmd maintenance:check` | Réussi — registre, index, marqueurs, 8 mutations |
| `pnpm.cmd backend:stop` | Réussi — arrêt sans sauvegarde |
| `git diff --check` | Réussi — aucune anomalie d'espaces |
| `pnpm.cmd ci:backend` | Non exécuté — harnais réservé au runner Linux |

Le premier `backend:test` a échoué sur deux assertions, toutes deux corrigées :
l'assertion T0050 d'exclusivité par avion, devenue fausse par conception, et une
attente trop précise de mon propre test — `anon` reçoit `permission denied for
schema private`, pas `for table company_reputation_events`, parce que le schéma
lui-même lui est fermé. Le second échec est une erreur de test, pas
d'implémentation. Un premier `backend:check` a aussi échoué sur mon propre
contrôle anti-environnement, dont le motif insensible à la casse attrapait le nom
de contrainte `flight_reports_multiplier` ; il est désormais sensible à la casse.

Les montants attendus ont été calculés hors de la base, avec Node, avant d'être
écrits en clair dans les tests : `57694`, `48648`, le plafond `2000000` pour un vol
qui atteindrait `2103629` et le plancher `5000`. Le barème n'est donc pas validé
contre lui-même.

La première publication a échoué sur `Supabase PostgreSQL 17` en 25 secondes, à
l'étape `Validate static backend invariants`, avec `Embedded flight settlement
policy diverges from eng/flight-settlement-policy.json.` La cause est un défaut de
portabilité de mon propre contrôle, invisible sous Windows : `package.json` lance
le gate avec `powershell` 5.1, dont `ConvertFrom-Json` rend un `Decimal` et
conserve l'échelle de `1.0`, tandis que le workflow le lance avec `pwsh` 7, dont
`ConvertFrom-Json` rend un `Double` que `[decimal]` réduit à `1`. La projection
reconstruite valait donc `'multiplierStandard', 1.0` en local et
`'multiplierStandard', 1` sur le runner. Le gate a correctement échoué fermé : il a
signalé une divergence réelle entre ce qu'il attendait et la migration.

Le correctif rend la projection indépendante du parseur : les multiplicateurs sont
formatés par `ToString("F2", InvariantCulture)`, stable depuis un `Decimal` comme
depuis un `Double`, et la source comme la migration portent la même forme
explicite à deux décimales — `0.90`, `1.00`, `1.15`, `1.30`. Le barème est
inchangé : `(1.30 + 1.15) / 2` vaut toujours `1.225`. Après correction, le gate
passe sous les deux hôtes — `pnpm.cmd backend:check` avec Windows PowerShell 5.1 et
`pwsh -NoProfile -File ./tests/backend/run.ps1` comme le runner — et la pile a été
redémarrée pour rejouer 20 fichiers/427 assertions en `Result: PASS` avec les types
stables, puisque le texte de la migration avait changé.

### Manual verification result

Vérification manuelle du 4 août 2026 sur la pile locale, en état réellement
commité et non dans une transaction annulée, avec une identité, une compagnie, un
avion et des vols exclusivement synthétiques :

1. compagnie ouverte à `43000000` EUR, brouillon `LFBO`→`LFML` créé et vol démarré
   par les commandes T0047 et T0050 livrées ;
2. clôture d'un vol terminé avec 95 minutes déclarées : réponse à onze champs,
   `settledAmountMinor` `35194`, `distanceNm` `168.28`, `blockMinutes` `0`,
   `currencyCode` `EUR`, `closedAt` serveur. Le temps retenu de `0` est la preuve
   directe de l'écrêtage par l'horloge serveur : le vol venait de démarrer. État
   `completed` avec départ conservé, rapport unique portant `95` déclarées, `0`
   retenues, `168.28`, `1.000` et `-142` fpm, deux écritures `43000000` puis
   `35194`, solde `43035194`, un événement de réputation `+1`;
3. rejeu de la même clé : même montant, et toujours exactement un rapport, un
   événement et une écriture de règlement ;
4. l'avion accepte immédiatement un nouveau brouillon ; la table porte alors un vol
   `completed` et un `draft` pour le même avion ;
5. deuxième vol clôturé `interrupted` : `settledAmountMinor` `5000`, état
   `interrupted`, événement `−3`, puis score lu par le propriétaire à `48` pour
   deux événements ;
6. quatre refus consécutifs — deuxième clôture d'un vol déjà clôturé, temps déclaré
   `1441`, rapport portant `settledAmountMinor`, clé réutilisée avec un autre
   payload — laissent le registre à deux commandes et le solde à `43040194`;
   `update` sur une écriture de règlement et sur un événement de réputation sont
   refusés, et `authenticated` ne peut pas exécuter la commande ;
7. constat supplémentaire : `service_role` n'a lui-même aucun `select` sur
   `public.flight_dispatches`, donc toute lecture d'état passe par la commande
   `security definer`. Mes trois premiers essais de refus ont d'ailleurs échoué
   pour cette raison, sur la sous-requête du harnais et non sur la commande.

La pile a été arrêtée sans sauvegarde. Durée effective hors démarrage : environ
8 minutes, sous la cible de 10.

### Risks and limitations

- la distance de grand cercle est calculée en `double precision` : une plateforme
  au comportement flottant différent pourrait déplacer la deuxième décimale et
  donc le montant d'une unité mineure. Le risque est borné par l'arrondi unique de
  la distance, mais il n'est pas nul et les montants exacts des tests y sont
  sensibles ;
- observer un temps de bloc non nul dans une transaction pgTAP exige de désactiver
  brièvement le trigger `flight_dispatches_server_started_at` pour antidater le
  départ. Seul le propriétaire de la table peut le faire ; aucun rôle applicatif
  n'y a accès, mais le test dépend de ce privilège ;
- une clé d'idempotence réutilisée entre deux familles de commandes — un achat puis
  une clôture — échoue sur la contrainte `financial_ledger_entries_idempotency`
  plutôt qu'avec le message métier. L'échec est fermé et sans état partiel, mais le
  message est moins actionnable. La limite existe déjà pour T0029 et n'est pas
  corrigée opportunément ici ;
- les événements de réputation sont liés à la compagnie et disparaissent avec elle
  par `on delete cascade`, alors que le grand livre T0020 se détache. C'est
  cohérent avec une donnée purement informative, mais ce n'est pas le même modèle
  de rétention ;
- `pnpm ci:backend` n'est pas exécutable depuis Windows : la course de deux
  clôtures concurrentes que ce ticket ajoute au harnais est attendue de la CI de la
  Pull Request, comme la vérification de l'interprétation du script ;
- le barème est un choix d'alpha protégé par un plancher et un plafond, pas un
  équilibrage économique mesuré ; il devra être revu avant toute ouverture externe ;
- preuves locales et synthétiques : aucune frontière Auth, aucun appelant desktop,
  aucune cible distante et aucune donnée réelle ne sont validés.

### Follow-ups

- exposer `close_flight` derrière une Edge Function authentifiée bornée, sur le
  modèle de T0048, puis la valider sur l'Edge Runtime local réel comme T0049 ;
- consommer la clôture et le score de réputation depuis le desktop, dans un ticket
  distinct du flux 3 ;
- relier la télémétrie T0054 à la clôture pour dériver le temps de bloc et la
  nature de fin de vol au lieu de les déclarer, ce qui suppose d'abord la détection
  déterministe des phases ;
- annulation d'un vol actif sans règlement, encore absente de la liste fermée
  d'états ;
- candidat `LEARNINGS.md` : un contrôle de gate écrit avec `(?i)` sur des motifs
  de style `NOM_DE_VARIABLE` attrape aussi les identifiants SQL en minuscules.
  Comparer les noms d'environnement avec `-cmatch`, jamais `-match` ;
- candidat `LEARNINGS.md`, à promouvoir en règle car reproduit de façon
  déterministe : un gate qui reconstruit du texte depuis un JSON ne doit jamais
  laisser le parseur choisir le rendu d'un nombre. `ConvertFrom-Json` rend un
  `Decimal` sous Windows PowerShell 5.1 et un `Double` sous `pwsh` 7, si bien qu'un
  contrôle vert en local échoue sur le runner. Formater explicitement, et exécuter
  au moins une fois tout gate modifié avec `pwsh -NoProfile -File`, l'hôte réel de
  la CI, en plus du script `pnpm` qui utilise `powershell` 5.1.

### Documentation updated

- `docs/PRODUCT.md` — clôture, barème, plancher, plafond, disponibilité de l'avion
  et réputation informative comme règles produit ;
- `docs/ARCHITECTURE.md` — quatrième migration du domaine vol, index partiel,
  projection de politique, distance dérivée et frontière de clôture ;
- `docs/SECURITY.md` — section T0051 : autorités, règle de sécurité ajoutée,
  refus opaques, append-only et lecture bornée du score ;
- `docs/QUALITY.md` — vingt fichiers pgTAP, 427 assertions, preuve datée,
  provenance des montants attendus et limites ;
- `docs/CURRENT_STATE.md` — capacité réellement disponible, source de politique,
  inventaire d'autorité et prochain ticket recommandé ;
- `eng/authority-inventory.json` — deux domaines reclassés avec leurs preuves ;
- `docs/tickets/README.md` — statut du ticket.
