# T0029 — Acquérir un premier avion sans double débit ni propriété partielle

Status: Draft
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
et opérations passives. Le ticket reste `Draft` jusqu'au choix explicite d'Andy.

### Décision réservée à Andy

- **Achat recommandé** : propriété immédiate et débit unique dans la même
  transaction. C'est la plus petite tranche qui prouve flotte + finance sans
  introduire d'autorité temporelle.
- **Location** : contrat, échéances, défaut/résiliation et source de temps
  serveur. Ce choix exige de réécrire le ticket et de dépendre d'une politique
  de paiements périodiques avant de passer `Ready`.

## Dependencies

- T0020 — grand livre immuable (`Done`, dans `main`) ;
- T0022–T0023 — compagnie et frontière serveur (`Done`, dans `main`) ;
- T0024 — inventaire d'autorité (`Done`, dans `main`) ;
- T0028 — politique d'ouverture en `Review`, PR de livraison #54 vers `main` ;
- choix explicite d'Andy entre achat et location.

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

Les exigences suivantes deviennent exécutables uniquement si Andy confirme
l'option achat. L'option location exige une nouvelle version du ticket.

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

- [ ] Andy a choisi achat ou location ; le ticket est réécrit avant `Ready` si
      la location est retenue.
- [ ] Pour l'achat, offre serveur, propriété et débit immuable sont atomiques.
- [ ] Rejeu, collision, concurrence et solde insuffisant ne créent aucun double
      débit ni état partiel.
- [ ] A/B/anonyme et toutes les mutations directes client sont isolés.
- [ ] Deux resets, tous les pgTAP, les types, la concurrence et les gates passent
      sur PostgreSQL 17.
- [ ] La documentation distingue branche, preuve synthétique et capacité livrée
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

À remplir après décision puis implémentation.

### Summary

### Files changed

### Commands and results

### Manual verification result

### Risks and limitations

### Follow-ups

### Documentation updated
