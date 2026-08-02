# T0029 — Acquérir un premier avion sans double débit ni propriété partielle

Status: Done
Owner: Andy
Branch: `feature/T0029-authoritative-aircraft-acquisition`
Phase: 2
Risk: High
Security-sensitive: Yes

## Goal

Ajouter une première acquisition d'avion entièrement autoritaire côté serveur,
atomique et idempotente, qui ne puisse créer ni avion sans écriture financière,
ni double débit, ni propriété forgée par un client distribué.

## Context

T0020 fournit un grand livre immuable mais seulement le type
`opening_balance`. T0022–T0023 créent une compagnie derrière une frontière
serveur. T0024 classe encore la flotte `not-implemented`. T0028 fixe l'ouverture
des nouvelles compagnies à 430 000 EUR et recommande ensuite une première
acquisition d'avion avec débit transactionnel et rejeu idempotent.

Le parcours produit autorise « acheter ou louer un avion », mais implémenter les
deux dans une même tranche anticiperait contrats, paiements temporels, résiliation
et opérations passives.

### Décision d'Andy

Andy confirme le 2 août 2026 que le produit doit proposer achat **et** location.
Ils restent séquencés : T0029 implémente d'abord l'achat, propriété immédiate et
débit unique ; un ticket séparé traitera ensuite contrat, échéances,
défaut/résiliation et autorité temporelle de la location.

## Workflow evidence

- 2 août 2026 — `Ready` : option achat bornée confirmée pour T0029 ; T0020 et
  T0022–T0024 sont dans `main`; T0028 est implémenté et validé sur la PR #54 ;
  worktree propre sur `feature/T0029-authoritative-aircraft-acquisition`.
- 2 août 2026 — `In progress` : implémentation de l'achat autorisée sur la
  branche T0029, dans les seules zones `Allowed areas`.
- 2 août 2026 — `Review` : migration, tests, types, gates et courses locales
  terminés ; diff prêt à publier, sans vérification distante revendiquée.
- T0029 reste empilé sur T0028 tant que #54 n'est pas fusionnée et ne présume
  pas cette capacité dans `main`.

## Dependencies

- T0020 — grand livre immuable (`Done`, dans `main`) ;
- T0022–T0023 — compagnie et frontière serveur (`Done`, dans `main`) ;
- T0024 — inventaire d'autorité (`Done`, dans `main`) ;
- T0028 — politique d'ouverture en `Review`, PR de livraison #54 vers `main` ;
- décision d'Andy : achat T0029, location dans un ticket ultérieur.

## Allowed areas

Après passage `Ready` pour l'option achat uniquement :

- `supabase/migrations/` — une nouvelle migration append-only ;
- `supabase/seed.sql` — offres synthétiques uniquement ;
- `supabase/tests/database/` — pgTAP T0029 ;
- `tests/backend/` et `scripts/ci/test-backend.ps1` ;
- `packages/database/src/database.types.ts` — types régénérés ;
- `eng/authority-inventory.json` ;
- `docs/PRODUCT.md`, `docs/ARCHITECTURE.md`, `docs/SECURITY.md`,
  `docs/QUALITY.md`, `docs/CURRENT_STATE.md` ;
- ce ticket et `docs/tickets/README.md`.

## Do not touch

- migrations existantes, `eng/economy-policy.json` et ouverture T0028 ;
- location, loyers, échéancier, résiliation, crédit ou remboursement ;
- marché dynamique, enchères, revente, maintenance, équipage ou assurance ;
- Edge Function, appel desktop, UX, bridge ou SimConnect ;
- projet Supabase distant, staging, production, secret ou donnée réelle ;
- workflows GitHub, manifests, lockfiles et toolchain ;
- statuts ou Completion Reports des autres tickets.

## Requirements

Les exigences suivantes portent exclusivement sur l'achat. La location reste un
résultat produit confirmé mais sera détaillée et exécutée dans un autre ticket.

### 1. Catalogue et autorité de prix

- Une offre d'achat versionnée identifie un type d'avion synthétique, une devise
  et un prix positif en unités mineures.
- Le prix, la devise, le vendeur et l'identité de la compagnie ne proviennent
  jamais d'un payload client ; la commande résout et verrouille l'offre serveur.
- Le MVP T0029 accepte uniquement une offre active en `EUR`, cohérente avec le
  grand livre mono-devise actuellement prouvé.

### 2. Propriété et débit atomiques

- Une commande `service_role` verrouille compagnie, offre et sujet financier,
  vérifie le solde calculé depuis le grand livre, puis crée l'avion possédé et
  une écriture négative `aircraft_purchase` dans une transaction unique.
- Solde insuffisant, offre inactive, devise différente, compte en suppression ou
  panne injectée ne laisse ni propriété, ni commande, ni écriture partielle.
- Les rôles `anon` et `authenticated` ne peuvent créer, modifier ou supprimer
  directement offre, avion, commande ou écriture.

### 3. Idempotence et concurrence

- La clé UUID est liée au propriétaire, à l'offre et au payload normalisé.
- Un rejeu identique rend les mêmes identifiants sans nouveau débit.
- Une collision de clé ou deux achats concurrents de la même offre unitaire
  échouent ou convergent sans double propriété ni double débit.
- Deux achats distincts concurrents ne peuvent pas dépenser le même solde.

### 4. Lecture et preuves

- Le propriétaire authentifié lit uniquement les avions de sa compagnie ; A ne
  lit jamais B et `anon` ne lit rien.
- Les pgTAP couvrent structure, ACL/RLS, succès, rejeu, collision, concurrence,
  solde insuffisant, rollback injecté et compte en suppression.
- Le gate backend refuse le retour d'une mutation client ou d'un prix fourni par
  le client ; l'inventaire d'autorité passe la flotte à `partial` seulement avec
  ces preuves.

## Non-goals

- endpoint Edge authentifié ou consommation desktop ;
- plusieurs devises, conversion ou solde matérialisé ;
- location et toute logique temporelle ;
- revente, amortissement, valeur résiduelle ou marché dynamique ;
- deuxième type d'acquisition ou équilibrage complet de la flotte ;
- données réelles ou environnement distant.

## Acceptance criteria

- [x] Andy a confirmé achat puis location ; T0029 est borné à l'achat et la
      location reste un ticket distinct.
- [x] Pour l'achat, offre serveur, propriété et débit immuable sont atomiques.
- [x] Rejeu, collision, concurrence et solde insuffisant ne créent aucun double
      débit ni état partiel.
- [x] A/B/anonyme et toutes les mutations directes client sont isolés.
- [x] Deux resets, tous les pgTAP, les types, la concurrence et les gates passent
      sur PostgreSQL 17.
- [x] La documentation distingue branche, preuve synthétique et capacité livrée
      dans `main`.

## Security review

- actifs/données : offre et prix serveur, solde dérivé, avion possédé,
  écriture financière et clé d'idempotence ;
- frontière : futur appelant serveur → commande `service_role` → transaction
  PostgreSQL ; clients distribués limités aux lectures RLS ;
- abus : prix/devise/compagnie forgés, double achat, double débit, course sur le
  solde, propriété sans paiement et lecture de la flotte B ;
- validation/autorisation : offre verrouillée, compagnie dérivée de l'autorité
  serveur, `service_role` seul et ACL/RLS forcées ;
- atomicité/idempotence : transaction unique, registre privé, empreinte du
  payload, contraintes uniques et verrous ordonnés ;
- logs/vie privée : aucune journalisation de JWT, email, secret ou détail SQL ;
  uniquement identifiants synthétiques dans les preuves.

## Maintenance review

- dettes et problèmes connus applicables : flotte `not-implemented` dans T0024,
  grand livre limité à l'ouverture et `KI-021` interdisant les données réelles ;
- dette créée ou aggravée : aucune attendue pour l'option achat bornée ;
- règle de sécurité ajoutée, modifiée ou à revalider : achat et débit
  indissociables, prix serveur et verrou de solde ;
- contrôle manuel à automatiser : courses achat/solde et rollback injecté ;
- risque résiduel : aucun endpoint applicatif et aucune location ; le catalogue
  synthétique ne prouve pas un équilibrage de production.

## Automated validation

```powershell
pnpm backend:check
pnpm data-policy:check
pnpm authority:check
pnpm backend:start
pnpm backend:reset
pnpm backend:reset
pnpm backend:test
pnpm backend:types:check
pnpm backend:stop
git diff --check
```

## Manual verification

1. Créer une compagnie synthétique et acheter l'offre avec `service_role`.
2. Rejouer la clé, provoquer une collision et deux achats concurrents.
3. Confirmer un avion, une commande et un débit unique, puis les lectures A/B.
4. Tenter prix/devise/compagnie forgés et toutes les mutations directes client.
5. Tester solde insuffisant et panne injectée, puis confirmer l'absence d'état
   partiel.

Temps cible : 10–15 minutes.

## Rollback

Avant fusion, abandonner la branche et recréer la base locale jetable. Après
fusion, ne jamais modifier la migration ni supprimer une écriture : toute
correction utilise une nouvelle migration append-only. Aucun rollback sur donnée
réelle n'est autorisé.

## Completion Report

### Summary

- Ajout d'un catalogue synthétique d'offres unitaires en EUR et d'une propriété
  de compagnie lisible uniquement par son propriétaire.
- Ajout de `purchase_aircraft`, commande `service_role` atomique et idempotente
  qui verrouille compagnie, sujet financier et offre, puis crée avion et débit.
- Extension append-only du grand livre au type négatif `aircraft_purchase` et
  ajout de deux preuves de concurrence réelles.

### Files changed

- migration T0029, seed synthétique et types générés ;
- deux fichiers pgTAP et harnais backend/CI ;
- inventaire d'autorité et documentation produit, architecture, sécurité,
  qualité et état courant ;
- ticket T0029 et index.

### Commands and results

- `pnpm backend:check` — PASS, T0029 et 15 mutations statiques ;
- `pnpm data-policy:check` — PASS, 6 mutations ;
- `pnpm authority:check` — PASS, 10 étapes, 13 domaines, 5 mutations ;
- `pnpm backend:start` — PASS avec Docker Desktop 29.6.2, loopback isolé ;
- `pnpm backend:reset` deux fois après rechargement des sources — PASS ;
- `pnpm backend:test` — PASS, 12 fichiers et 234 assertions ;
- `pnpm backend:types` puis `pnpm backend:types:check` — PASS, types stables ;
- deux sessions, même offre/même clé — mêmes identifiants et état
  `1|1|1|33000000` ;
- deux sessions, offres distinctes de 10 000 000 sur solde 15 000 000 — un
  succès, un refus insuffisant et état `1|1|1|5000000` ;
- `git diff --check` — PASS.
- PR brouillon #56, base `docs/T0028-production-economy-policy`, head
  `feature/T0029-authoritative-aircraft-acquisition` ; CI `30740977879` :
  PostgreSQL 17 et Windows PASS ; supply-chain `30740977888` : PASS sur
  `1ede937`.

### Manual verification result

PASS le 2 août 2026 sur PostgreSQL 17 local synthétique : succès, rejeu,
collision, offre consommée, solde insuffisant, A/B/anonyme, suppression en
attente, rollback injecté et deux courses contrôlés. Une première exécution a
révélé que la FK du registre interceptait `TRUNCATE` avant le trigger append-only
T0020 ; elle a été retirée, la source rechargée, puis les deux resets et les 234
assertions ont été rejoués avec succès.

### Risks and limitations

- T0029 reste empilé sur T0028/#54 et n'est pas livré dans `main`.
- Aucun endpoint applicatif, appel desktop, catalogue de production ou donnée
  réelle n'est couvert.
- La location, les paiements récurrents et l'autorité temporelle restent absents.
- La PR reste en brouillon et dépend de la livraison préalable de T0028/#54 ;
  Andy conserve seul l'autorité de revue et de merge.

### Follow-ups

- Créer après T0029 un ticket séparé pour location, contrat, échéances,
  défaut/résiliation et autorité temporelle.
- Ajouter une frontière serveur authentifiée et sa consommation desktop dans un
  ticket ultérieur, sans exposer `service_role`.

### Documentation updated

`PRODUCT.md`, `ARCHITECTURE.md`, `SECURITY.md`, `QUALITY.md`,
`CURRENT_STATE.md`, `eng/authority-inventory.json`, ce ticket et l'index.

### Delivery reconciliation

Le 2 août 2026, T0033 confirme que le commit d'implémentation `1ede937` et sa
preuve CI sont dans l'ascendance de `origin/main` par la chaîne de fusions
empilées intégrée avec la PR #54. Les deux resets, 234 assertions, courses et
vérifications manuelles étant déjà consignés, T0029 passe de `Review` à `Done`.
