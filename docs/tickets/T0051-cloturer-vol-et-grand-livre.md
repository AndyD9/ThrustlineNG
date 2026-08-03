# T0051 — Clôturer un vol une seule fois et écrire au grand livre

Status: Draft
Owner: Andy
Branch: `feature/T0051-authoritative-flight-finalization`
Phase: 2
Risk: High
Security-sensitive: Yes

## Goal

Accepter un rapport de vol versionné, clôturer le vol exactement une fois et
écrire l'effet financier correspondant dans le grand livre immuable, sans
création ni destruction de valeur inexpliquée.

## Context

Le gate de l'alpha jouable se termine par « rapport versionné, clôture unique et
écriture dans le grand livre ». T0020 fournit les écritures append-only, T0029 a
montré comment étendre `entry_type` par une migration append-only et T0050
fournit le vol actif à clôturer. Les domaines `flight-finalization` et
`reputation-progression` restent `not-implemented`.

Ce ticket reste `Draft` : il touche l'économie du produit, donc il exige des
décisions explicites d'Andy avant toute migration. Aucune valeur, formule ou
type d'écriture ne doit être inventé par un agent. Le mode accéléré demande
justement de regrouper ces décisions avant de lancer la vague suivante.

## Decisions required from Andy

1. Effet financier d'un vol alpha : montant fixe par vol, montant dérivé de la
   distance ou du temps, ou aucun revenu et seulement des coûts ?
2. Forme comptable : une écriture nette unique par vol, ou une écriture de
   revenu et une écriture de coût distinctes dans la même transaction ?
3. Nom, signe et bornes des nouveaux `entry_type`, et devise imposée : celle de
   la politique T0028 (`EUR`) ou une devise portée par le vol ?
4. Champs du rapport de vol qui font autorité côté serveur et champs
   réellement acceptés depuis le bridge, sachant que le bridge est un client non
   fiable et que ses valeurs doivent être bornées.
5. Traitement d'un vol interrompu, en crash ou jamais terminé : clôture partielle
   avec effet réduit, clôture sans effet financier, ou aucune clôture possible ?
6. Effet de la clôture sur l'avion et le dispatch : l'avion redevient-il
   immédiatement disponible pour un nouveau dispatch, et le dispatch clôturé
   reste-t-il lisible par le propriétaire ?
7. Réputation, progression, maintenance et usure : explicitement hors alpha, ou
   une première valeur est-elle attendue dès ce ticket ?

Tant que ces sept points ne sont pas tranchés, le ticket ne peut pas passer
`Ready` et aucune migration ne doit être écrite.

## Dependencies

- T0020 — grand livre immuable et sujet financier opaque ;
- T0028 — politique économique d'ouverture, référence de devise ;
- T0029 — précédent d'extension de `entry_type` par migration append-only ;
- T0047, T0050 — dispatch et vol actif à clôturer ;
- décisions produit et économiques d'Andy listées ci-dessus.

## Allowed areas

Périmètre prévisionnel, à confirmer au passage `Ready` :

- une nouvelle migration `supabase/migrations/` append-only ;
- `supabase/tests/database/` pour les nouveaux fichiers pgTAP ;
- `packages/database/src/database.types.ts` régénéré ;
- `eng/economy-policy.json` si et seulement si la décision d'Andy ajoute une
  valeur économique versionnée ;
- `scripts/ci/test-backend.ps1`, `tests/backend/run.ps1` et
  `eng/authority-inventory.json` ;
- `docs/PRODUCT.md`, `docs/ARCHITECTURE.md`, `docs/SECURITY.md`,
  `docs/QUALITY.md`, `docs/CURRENT_STATE.md` ;
- ce ticket et `docs/tickets/README.md`.

## Do not touch

- migrations et écritures existantes du grand livre : aucune réécriture, aucun
  `update` ni `delete` d'une écriture livrée ;
- politique économique T0028 sans décision explicite d'Andy ;
- location T0032, opérations passives, équipage et progression avancée ;
- desktop, Rust/Tauri, bridge, SimConnect et SimBrief ;
- workflows, manifests, lockfiles, cible distante et données réelles.

## Requirements

Exigences invariantes, indépendantes des décisions en attente :

- La clôture est une commande `service_role`, `security definer`,
  `set search_path = ''`, transactionnelle et idempotente par
  `(propriétaire, clé d'idempotence)` avec empreinte du payload.
- Le rapport de vol est versionné, borné champ par champ et validé avant toute
  écriture ; aucune valeur monétaire ne provient d'un client.
- Le montant écrit est recalculé côté serveur depuis la politique versionnée et
  le rapport validé, jamais transmis par l'appelant.
- Un vol ne peut être clôturé qu'une fois : un rejeu rend la même réponse, une
  seconde clôture avec une autre clé échoue, et l'état final est unique.
- Les écritures restent append-only, sans identité Auth directe, et la lecture
  reste limitée à `get_company_ledger()` pour le propriétaire.
- Un échec injecté à n'importe quelle étape laisse le vol, le dispatch, l'avion
  et le grand livre inchangés.
- Les pgTAP couvrent ACL/RLS, isolation A/B/anonyme, rapport invalide ou hors
  bornes, rejeu, collision, double clôture, compte en suppression, rollback
  injecté et cohérence du solde recalculé.

## Non-goals

- exposer une frontière Auth ou un appel desktop ;
- télémétrie, détection de phases et reprise, qui relèvent du flux bridge ;
- réputation, progression, maintenance, usure et opérations passives, sauf
  décision contraire d'Andy ;
- location T0032, fiscalité, prêts et profondeur économique ;
- déploiement distant ou admission de données réelles.

## Acceptance criteria

- [ ] Les sept décisions ci-dessus sont tranchées par Andy et citées dans le
      ticket avant toute migration.
- [ ] Un vol actif possédé se clôture exactement une fois, avec un rapport
      versionné validé et l'effet financier décidé.
- [ ] Le montant est recalculé côté serveur ; aucun montant, devise ou solde
      client n'est accepté.
- [ ] Rejeu, collision, double clôture, rapport invalide, vol étranger et compte
      en suppression échouent fermés sans fuite.
- [ ] Le grand livre reste append-only et le solde final est exactement celui
      attendu par la politique.
- [ ] pgTAP, types générés et gates applicables passent avec leurs scénarios
      réellement découverts et consignés.

## Security review

- actifs : argent, grand livre immuable, état de vol, rapport, idempotence ;
- frontière : bridge et desktop non fiables → future frontière Auth →
  `service_role` → transaction ;
- abus : montant ou devise forgés, double clôture, rapport gonflé, clôture du vol
  d'un tiers, création de valeur par rejeu divergent ;
- validation/autorisation : bornes strictes du rapport, montant recalculé,
  propriétaire vérifié, verrous sur compagnie, sujet financier et vol ;
- atomicité/idempotence : une transaction unique, registre privé par clé, refus
  de toute écriture partielle ;
- logs/vie privée : aucune donnée personnelle, aucun identifiant Auth dans les
  écritures, aucun détail SQL rendu.

## Maintenance review

- problèmes applicables : `KI-021` interdit les données réelles ; `KI-010`
  rappelle l'absence de retour arrière après création de données réelles ;
- dette créée : à qualifier au passage `Ready`, notamment si l'alpha accepte un
  effet financier volontairement simplifié ;
- règle de sécurité : aucune valeur monétaire ne franchit une frontière cliente ;
- contrôle manuel à automatiser : cohérence du solde après clôture dans le
  harnais CI backend ;
- risque résiduel : une politique économique provisoire d'alpha ne préjuge pas
  de l'équilibre économique du MVP.

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
2. Clôturer une fois avec un rapport valide, relever le solde, puis rejouer.
3. Tenter une seconde clôture, un rapport hors bornes et un vol appartenant à
   une autre identité.
4. Confirmer l'immuabilité des écritures, le refus de `update`/`delete` et
   l'absence de fuite dans les erreurs.

Temps cible : 10 minutes hors démarrage de la pile.

## Rollback

Avant fusion, abandonner la branche. Après fusion, corriger uniquement par une
nouvelle migration append-only et une écriture compensatoire décidée par Andy ;
ne jamais modifier ni supprimer une écriture existante.

## Completion Report

À remplir après implémentation.

### Summary

### Files changed

### Commands and results

### Manual verification result

### Risks and limitations

### Follow-ups

### Documentation updated
