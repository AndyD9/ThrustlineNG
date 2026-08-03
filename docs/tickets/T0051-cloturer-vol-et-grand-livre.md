# T0051 — Clôturer un vol une seule fois, régler son revenu et sa réputation

Status: Draft
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
n'a plus d'ambiguïté de cadrage. Il reste `Draft` uniquement pour une raison
technique d'ordre d'intégration, afin de ne pas rouvrir une pile de branches.

Condition de sortie du `Draft` : T0050 et T0057 fusionnés dans `main`.

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

- [ ] T0050 et T0057 sont fusionnés dans `main` avant le passage en `Ready`.
- [ ] Un vol actif possédé se clôture exactement une fois, avec état terminal,
      rapport borné, écriture nette unique et événement de réputation dans la
      même transaction.
- [ ] Le montant correspond exactement au barème versionné, plafond et plancher
      compris ; aucun montant, devise, distance ou solde client n'est accepté.
- [ ] Un temps de bloc déclaré supérieur au temps réellement écoulé côté serveur
      est ramené au temps serveur.
- [ ] Rejeu, collision, seconde clôture, rapport hors bornes, dispatch étranger,
      dispatch non actif et compte en suppression échouent fermés sans fuite.
- [ ] L'avion est immédiatement dispatchable après clôture et aucun dispatch
      historique n'est supprimé.
- [ ] Le score de réputation reste borné `0–100`, informatif, lisible seulement
      par son propriétaire et non modifiable par un client.
- [ ] pgTAP, types générés et gates applicables passent avec leurs scénarios
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

À remplir après implémentation.

### Summary

### Files changed

### Commands and results

### Manual verification result

### Risks and limitations

### Follow-ups

### Documentation updated
