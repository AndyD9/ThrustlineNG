# T0065 — Rendre le rejeu d'un départ de vol identique à la réponse acquise

Status: Draft
Owner: Unassigned
Branch: `fix/T0065-rejeu-depart-vol-identique`
Phase: 2
Risk: Medium
Security-sensitive: Yes

## Goal

Le rejeu d'une commande de départ de vol déjà acquise rend exactement la réponse
rendue à l'acquisition, ou la garantie documentée est réduite à ce que le code
tient réellement. Une seule des deux issues est retenue, sur décision d'Andy.

## Context

`KI-024`. Dans `origin/main` au commit `c0f16dc`,
`supabase/migrations/20260803000200_authoritative_flight_start.sql` traite le rejeu
aux lignes 121 à 141 : lorsque la clé d'idempotence est retrouvée dans
`private.flight_start_commands`, la fonction relit `public.flight_dispatches` puis
construit la réponse depuis cette ligne vivante. Le registre privé ne stocke que
propriétaire, clé, dispatch et empreinte de payload ; aucune réponse n'y est
conservée.

Conséquence : un départ acquis alors que le dispatch était `active` puis clôturé
par `public.close_flight` T0051 rend, au rejeu de la même clé, l'état `completed`
et non l'état rendu à l'acquisition. Le champ `startedAt` suit la même dépendance à
l'état vivant.

Le comportement vient de T0050 et n'est pas une régression de T0060 ; il a été
relevé par la revue adversariale de la Pull Request brouillon #112 du 5 août 2026,
en sévérité Medium non bloquante. L'écart est documentaire autant que technique :
`docs/SECURITY.md`, `docs/ARCHITECTURE.md` et `docs/QUALITY.md` décrivent un rejeu
qui « rend la même réponse stockée », ce que le code ne fait pas.

## Décision réservée à Andy

Deux issues sont possibles et elles ne coûtent pas la même chose :

- **A — tenir la garantie.** Une migration append-only ajoute la réponse rendue
  dans `private.flight_start_commands` et le chemin de rejeu la restitue sans
  relire `public.flight_dispatches`. Coût : une colonne de plus dans un registre
  privé, une redéfinition de plus de `start_flight_from_dispatch`, et la réponse
  d'une commande devient une donnée conservée.
- **B — réduire la garantie.** La documentation et les critères ne promettent plus
  qu'un rejeu ne crée pas de second départ et rend le même `dispatchId`, sans rien
  promettre sur `state` ni `startedAt`. Coût : un client ne peut plus se fier au
  rejeu pour connaître l'état au moment de l'acquisition.

Condition de sortie : ce ticket reste `Draft` jusqu'à ce qu'Andy choisisse A ou B.
La réponse est reportée datée dans ce ticket, qui passe alors `Ready`. Aucun agent
ne tranche ce choix, parce qu'il fixe le contrat d'idempotence d'une commande déjà
livrée.

## Dependencies

- T0050 — départ de vol autoritaire et registre `private.flight_start_commands`
  (`Done`, présent dans `main`) ;
- T0051 — clôture de vol qui produit l'état terminal observé (`Done`) ;
- T0060 — garde d'usage, dont la Pull Request brouillon #112 documente la même
  garantie et qui doit être fusionnée avant toute nouvelle redéfinition des deux
  commandes, sous peine d'un quatrième conflit sur la définition vivante ;
- décision d'Andy ci-dessus.

## Allowed areas

- `supabase/migrations/` — au plus une migration append-only, seulement pour
  l'issue A ;
- `supabase/tests/database/` — pgTAP du rejeu ;
- `tests/backend/run.ps1` — marqueurs et mutations négatives ;
- `packages/database/src/database.types.ts` — types régénérés par le script
  existant ;
- `docs/SECURITY.md`, `docs/ARCHITECTURE.md`, `docs/QUALITY.md`,
  `docs/CURRENT_STATE.md`, `docs/KNOWN_ISSUES.md` ;
- ce ticket et `docs/tickets/README.md`.

## Do not touch

- migrations existantes, y compris celle du départ de vol : toute correction
  arrive par un nouveau fichier ;
- `public.close_flight`, le règlement, la réputation et le grand livre ;
- la garde d'usage T0060 et ses messages publics ;
- Edge Functions, endpoint applicatif, desktop, Rust/Tauri, bridge, SimConnect ;
- workflows, manifests, lockfiles, toolchain, cible distante, données réelles ;
- statuts et Completion Reports des autres tickets.

## Requirements

- L'issue retenue est appliquée entièrement, jamais partiellement : soit le rejeu
  restitue la réponse conservée, soit la promesse documentaire est réduite dans les
  trois documents qui la portent.
- Pour l'issue A, la réponse conservée est écrite dans la même transaction que le
  départ, et le chemin de rejeu ne lit plus l'état vivant du dispatch.
- Pour l'issue A, la redéfinition de `start_flight_from_dispatch` reprend
  intégralement les invariants T0050 et la garde d'usage T0060, et les réaffirme
  contre le nouveau fichier conformément à `LC-2026-002`.
- Un pgTAP place la clôture **avant** le rejeu : le test actuel appelle le rejeu
  avant `close_flight`, donc il ne peut pas échouer sur le cas contraire.
- Aucun privilège client nouveau, `execute` toujours réservé à `service_role`.

## Non-goals

- endpoint authentifié, appel desktop, UX ou libellé client ;
- garde d'usage à la clôture de vol ;
- annulation d'un dispatch, replanification ou libération d'un avion ;
- ordonnanceur des échéances, projet Supabase distant, données réelles.

## Acceptance criteria

- [ ] La décision d'Andy est reportée datée dans ce ticket avant toute
      implémentation.
- [ ] Un départ acquis, puis un vol clôturé, puis un rejeu de la même clé : la
      réponse du rejeu est prouvée conforme à l'issue retenue par un pgTAP dont
      l'ordre place la clôture avant le rejeu.
- [ ] Aucun second départ, aucune seconde ligne de registre, aucun effet financier
      n'est créé par le rejeu.
- [ ] `docs/SECURITY.md`, `docs/ARCHITECTURE.md` et `docs/QUALITY.md` décrivent la
      même garantie que le code, sans exception résiduelle.
- [ ] `KI-024` passe `Resolved` en citant ce ticket, ou reste `Accepted` avec le
      risque explicitement accepté par Andy si l'issue B est retenue.
- [ ] Deux resets consécutifs, tous les pgTAP, les types et les gates passent avec
      des décomptes réellement découverts et consignés.

## Security review

- actifs/données : réponse d'une commande privilégiée, état de vol, empreinte de
  payload ;
- frontière : future frontière authentifiée puis commandes `service_role` et
  PostgreSQL ;
- abus : rejouer une clé pour observer l'état courant d'un dispatch, faire créer un
  second départ, forger un `startedAt` ;
- validation/autorisation : `execute` réservé à `service_role`, aucun paramètre
  nouveau contrôlé par l'appelant ;
- atomicité/idempotence : c'est exactement l'objet du ticket ; la conservation
  éventuelle de la réponse appartient à la transaction du départ ;
- logs/vie privée : aucune donnée réelle, aucun secret, preuves synthétiques.

## Maintenance review

- dettes et problèmes connus applicables : `KI-024` ouvre ce ticket ; `KI-021`
  interdit toujours les données réelles ;
- dette créée ou aggravée : l'issue A réécrit `start_flight_from_dispatch` une
  troisième fois et conserve une réponse de commande, donc une donnée de plus à
  purger le jour où une politique de rétention la couvre ;
- règle de sécurité ajoutée, modifiée ou à revalider : le contrat d'idempotence
  d'une commande privilégiée devient explicite dans `docs/SECURITY.md` ;
- contrôle manuel à automatiser : l'ordre du scénario pgTAP, clôture avant rejeu,
  doit être imposé par un marqueur et non par une consigne de revue ;
- risque résiduel ou exception approuvée : à consigner selon l'issue retenue.

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

1. Réinitialiser la pile locale, créer une compagnie, acheter un avion comptant.
2. Créer un brouillon puis démarrer le vol, relever exactement la réponse rendue.
3. Clôturer ce vol par `public.close_flight`.
4. Rejouer la commande de départ avec la même clé d'idempotence et comparer la
   réponse, champ par champ, à celle relevée à l'étape 2.
5. Confirmer en SQL qu'aucun second départ, aucune seconde ligne de registre et
   aucune écriture financière supplémentaire n'existent.

Temps cible : 5–10 minutes hors démarrage de la pile.

## Rollback

Avant fusion, abandonner la branche. Après fusion de l'issue A, la conservation de
la réponse ne peut être retirée que par une nouvelle migration append-only ; ne
jamais modifier ni supprimer une migration livrée. Pour l'issue B, la réduction est
documentaire et se révise par un nouveau ticket.

## Completion Report

À remplir après implémentation.

### Summary

### Files changed

### Commands and results

### Manual verification result

### Risks and limitations

### Follow-ups

### Documentation updated
