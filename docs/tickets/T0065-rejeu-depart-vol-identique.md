# T0065 — Rendre le rejeu d'un départ de vol identique à la réponse acquise

Status: Ready
Owner: Andy
Branch: `fix/T0065-rejeu-depart-vol-identique`
Phase: 2
Risk: Medium
Security-sensitive: Yes

## Goal

Le rejeu d'une commande de départ de vol déjà acquise rend exactement la réponse
rendue à l'acquisition, y compris après la clôture du vol. La garantie est tenue et
non réduite : c'est l'issue A, retenue par Andy le 5 août 2026.

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
l'état vivant, et de façon plus brutale que l'état : le trigger
`private.set_flight_dispatch_started_at` du même fichier de migration, lignes 21 à
43, exécute `new.started_at := null` dès que `new.state` n'est pas `active`. Une
contrainte `flight_dispatches_started_at_matches_state` impose d'ailleurs cette
nullité. Le rejeu d'une commande acquise rend donc, après clôture,
`state = 'completed'` **et** `startedAt = null` — deux champs sur cinq, dont un
effacé et non seulement périmé. Vérifié le 5 août 2026 sur `origin/main` au commit
`c0f16dc`.

Trois champs sont en revanche réellement stables, parce qu'aucune commande livrée
ne les modifie après la création du brouillon : `aircraftId`, `dispatchId` et
`schemaVersion`.

Le comportement vient de T0050 et n'est pas une régression de T0060 ; il a été
relevé par la revue adversariale de la Pull Request brouillon #112 du 5 août 2026,
en sévérité Medium non bloquante. L'écart est documentaire autant que technique :
`docs/SECURITY.md`, `docs/ARCHITECTURE.md` et `docs/QUALITY.md` décrivent un rejeu
qui « rend la même réponse stockée », ce que le code ne fait pas.

## Décision d'Andy du 5 août 2026 — issue A retenue

**Andy retient l'issue A : le rejeu doit rendre la réponse acquise.** La garantie
est tenue, pas réduite. Les trois documents qui la décrivent seront donc réalignés
sur un rejeu exact, et non sur la reconstruction actuelle.

Cette décision ferme la contradiction de l'exigence §2 de T0060 en faveur de la
moitié « rend la même réponse stockée » : le chemin de rejeu **change**, ce que
l'autre moitié interdisait. Le contrat d'idempotence de
`public.start_flight_from_dispatch` devient donc explicite, et
`docs/SECURITY.md` doit le porter comme tel.

Conséquence de séquencement, non négociable : ce ticket redéfinit
`start_flight_from_dispatch`, or la Pull Request brouillon #112 la redéfinit déjà.
Il ne peut donc pas être implémenté avant la fusion de #112, sous peine d'un
quatrième conflit sur la définition vivante — exactement le piège que
`LC-2026-002` décrit. Le ticket est `Ready` mais **son exécution est bloquée par
cette fusion**, qui appartient à Andy.

Les deux issues et leurs coûts, conservés pour la trace de la décision :

- **A — tenir la garantie.** Le chemin de rejeu restitue la réponse acquise sans
  dépendre de l'état vivant. Coût réel, plus faible que prévu : **aucune colonne
  nouvelle n'est nécessaire.** `private.flight_start_commands` conserve déjà
  `aircraft_id`, `dispatch_id` et `started_at not null`, et ce registre est le seul
  endroit où l'instant de départ survit à la clôture ; `state` valait forcément
  `active` à l'acquisition, par construction, puisque la ligne de registre n'est
  écrite qu'après la transition réussie ; `schema_version` est immuable et peut
  rester lu sur la ligne de dispatch. La réponse rejouée se reconstruit donc depuis
  le registre plus un littéral. Le coût véritable est ailleurs : c'est une
  redéfinition de plus de `start_flight_from_dispatch` — la troisième — avec la
  réaffirmation complète des invariants T0050 et de la garde T0060 contre le
  nouveau fichier, conformément à `LC-2026-002`.
- **B — réduire la garantie.** La documentation et les critères ne promettent plus
  qu'un rejeu ne crée pas de second départ et rend les trois champs stables
  `aircraftId`, `dispatchId` et `schemaVersion`, sans rien promettre sur `state` ni
  `startedAt`. Coût : un client ne peut plus se fier au rejeu pour connaître l'état
  ni l'instant de l'acquisition, et un rejeu après clôture rend un `startedAt` nul
  qu'un appelant naïf peut prendre pour « jamais parti ». **Non retenue.**

Condition de sortie remplie : la décision est reportée datée ci-dessus, le ticket
passe `Ready`. Son exécution reste suspendue à la fusion de #112.

## Dependencies

- T0050 — départ de vol autoritaire et registre `private.flight_start_commands`
  (`Done`, présent dans `main`) ;
- T0051 — clôture de vol qui produit l'état terminal observé (`Done`) ;
- T0060 — garde d'usage, dont la Pull Request brouillon #112 documente la même
  garantie et qui doit être fusionnée avant toute nouvelle redéfinition des deux
  commandes, sous peine d'un quatrième conflit sur la définition vivante ;
- décision d'Andy ci-dessus.

## Allowed areas

- `supabase/migrations/` — une seule migration append-only, dont l'horodatage doit
  être strictement supérieur au dernier fichier présent dans `origin/main` au moment
  de l'implémentation, et vérifié à ce moment-là ;
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

- L'issue A est appliquée entièrement, jamais partiellement : le rejeu restitue la
  réponse acquise, et les trois documents qui décrivent aujourd'hui la
  reconstruction sont réalignés sur cette exactitude dans le même changement.
- Le chemin de rejeu ne lit plus de l'état vivant du dispatch aucun
  champ que la clôture modifie ou efface. Reconstruire la réponse depuis
  `private.flight_start_commands`, dont l'écriture appartient déjà à la transaction
  du départ, suffit et doit être préféré à l'ajout d'une colonne : ne conserver une
  donnée nouvelle que si cette reconstruction se révèle insuffisante, et le
  justifier alors dans le Completion Report.
- La redéfinition de `start_flight_from_dispatch` reprend intégralement les
  invariants T0050 et la garde d'usage T0060, et les réaffirme contre le nouveau
  fichier conformément à `LC-2026-002`. C'est la troisième redéfinition de cette
  fonction : le diff des définitions avant/après doit montrer la seule
  restitution du rejeu, rien d'autre.
- Un pgTAP place la clôture **avant** le rejeu : le test actuel appelle le rejeu
  avant `close_flight`, donc il ne peut pas échouer sur le cas contraire.
- Aucun privilège client nouveau, `execute` toujours réservé à `service_role`.

## Non-goals

- endpoint authentifié, appel desktop, UX ou libellé client ;
- garde d'usage à la clôture de vol ;
- annulation d'un dispatch, replanification ou libération d'un avion ;
- ordonnanceur des échéances, projet Supabase distant, données réelles.

## Acceptance criteria

- [x] La décision d'Andy est reportée datée dans ce ticket avant toute
      implémentation : issue A, le 5 août 2026.
- [ ] La Pull Request #112 est fusionnée avant le début de l'implémentation, pour
      qu'aucune quatrième redéfinition concurrente de `create_dispatch_draft` et
      `start_flight_from_dispatch` ne soit ouverte en même temps.
- [ ] Un départ acquis, puis un vol clôturé, puis un rejeu de la même clé : le
      rejeu rend les cinq champs de la réponse acquise, `state` valant `active` et
      `startedAt` l'instant du départ, prouvé par un pgTAP dont l'ordre place la
      clôture **avant** le rejeu.
- [ ] Aucun second départ, aucune seconde ligne de registre, aucun effet financier
      n'est créé par le rejeu.
- [ ] `docs/SECURITY.md`, `docs/ARCHITECTURE.md` et `docs/QUALITY.md` décrivent la
      même garantie que le code, sans exception résiduelle : ils portent aujourd'hui
      la reconstruction, ils doivent porter la restitution.
- [ ] `KI-024` passe `Resolved` en citant ce ticket.
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
  troisième fois, ce qui est son coût réel ; reconstruite depuis le registre
  existant, elle ne conserve en revanche aucune donnée nouvelle et n'ajoute donc
  rien à purger. Si une colonne était finalement ajoutée, elle deviendrait une
  donnée de plus à couvrir par une politique de rétention ;
- règle de sécurité ajoutée, modifiée ou à revalider : le contrat d'idempotence
  d'une commande privilégiée devient explicite dans `docs/SECURITY.md` ;
- contrôle manuel à automatiser : l'ordre du scénario pgTAP, clôture avant rejeu,
  doit être imposé par un marqueur et non par une consigne de revue ;
- risque résiduel ou exception approuvée : l'issue A étant retenue, aucune exception
  n'est demandée ; le risque résiduel est la troisième redéfinition de la fonction,
  couvert par le diff avant/après exigé plus haut.

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

Avant fusion, abandonner la branche. Après fusion, la restitution du rejeu ne peut
être retirée que par une nouvelle migration append-only qui redéfinit explicitement
la commande ; ne jamais modifier ni supprimer une migration livrée. Revenir à la
reconstruction actuelle rouvrirait `KI-024` et demanderait un nouveau ticket, la
garantie étant alors écrite dans `docs/SECURITY.md`.

## Completion Report

À remplir après implémentation.

### Summary

### Files changed

### Commands and results

### Manual verification result

### Risks and limitations

### Follow-ups

### Documentation updated
