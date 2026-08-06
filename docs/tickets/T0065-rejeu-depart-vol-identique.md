# T0065 — Rendre le rejeu d'un départ de vol identique à la réponse acquise

Status: Review
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
et non l'état rendu à l'acquisition.

**Correction de constat du 5 août 2026, au moment de l'implémentation.** Ce
paragraphe annonçait aussi un `startedAt` nul, donc deux champs dérivants sur cinq :
c'est faux sur la pile réelle, et l'implémentation l'a découvert en échouant sur son
propre test. Le trigger `private.set_flight_dispatch_started_at` de
`20260803000200_authoritative_flight_start.sql` exécute bien
`new.started_at := null` dès que l'état quitte `active`, mais **T0051 l'a redéfini**
dans `20260804000100_authoritative_flight_settlement.sql` lignes 64 à 100 : un état
terminal conserve désormais `new.started_at := old.started_at`, et la contrainte
`flight_dispatches_started_at_matches_state` réécrite lignes 30 à 33 exige au
contraire que `started_at` soit **non nul** pour `completed` et `interrupted`. Une
lecture vivante après clôture rend donc `('completed', started_at not null,
closed_at not null)`, prouvé par pgTAP le 5 août 2026. Un seul champ sur cinq dérive,
`state`, et le constat initial confondait la définition livrée par T0050 avec la
définition vivante. La décision d'Andy n'est pas affectée : l'issue A corrige la
dépendance elle-même, pas seulement ses symptômes observables aujourd'hui.

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
- [x] La Pull Request #112 est fusionnée avant le début de l'implémentation, pour
      qu'aucune quatrième redéfinition concurrente de `create_dispatch_draft` et
      `start_flight_from_dispatch` ne soit ouverte en même temps.
      Fusionnée par Andy le 5 août 2026 à 16 h 08 UTC au merge `56c787a`, vérifié
      avant la création de la branche, elle-même partie de `origin/main` au merge
      `17ad8a8`.
- [x] Un départ acquis, puis un vol clôturé, puis un rejeu de la même clé : le
      rejeu rend les cinq champs de la réponse acquise, `state` valant `active` et
      `startedAt` l'instant du départ, prouvé par un pgTAP dont l'ordre place la
      clôture **avant** le rejeu.
      13 assertions dans `flight_start_replay_fidelity.test.sql`, pour un vol
      `completed` et un vol `interrupted`, plus la vérification manuelle sur état
      commité.
- [x] Aucun second départ, aucune seconde ligne de registre, aucun effet financier
      n'est créé par le rejeu.
      Trois rejeux laissent `3|1|2|3` en pgTAP — commandes de départ, vol actif,
      rapports, écritures — et l'état commité rend `1|1|0|1|2|43035194`.
- [x] `docs/SECURITY.md`, `docs/ARCHITECTURE.md` et `docs/QUALITY.md` décrivent la
      même garantie que le code, sans exception résiduelle : ils portent aujourd'hui
      la reconstruction, ils doivent porter la restitution.
- [x] `KI-024` passe `Resolved` en citant ce ticket.
- [x] Deux resets consécutifs, tous les pgTAP, les types et les gates passent avec
      des décomptes réellement découverts et consignés.
      24 fichiers / 552 assertions `Result: PASS`, types inchangés, gate backend à
      58 mutations, gates autorité, données et maintenance verts.

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

### Summary

Une seule migration append-only,
`supabase/migrations/20260805000200_flight_start_replay_fidelity.sql`, redéfinit
`public.start_flight_from_dispatch` pour la troisième fois et ne change que son
chemin de rejeu. Son horodatage a été vérifié au moment de l'implémentation contre
`origin/main` au merge `17ad8a8` : le dernier fichier présent est
`20260805000100_aircraft_usability_guard.sql`, donc `20260805000200` lui est
strictement supérieur. `public.create_dispatch_draft` n'est pas redéfinie et sa
définition vivante reste dans le fichier T0060 ; le gate le vérifie.

Le rejeu reconstruit sa réponse depuis `private.flight_start_commands` :
`aircraftId` et `startedAt` viennent de ses colonnes, `dispatchId` de sa clé, et
`state` est le littéral `active` — cette ligne n'existant qu'après une transition
`draft` → `active` réussie. Seul le `schema_version` immuable est encore lu sur la
ligne de dispatch. Conformément à l'exigence, **aucune colonne n'est ajoutée** : le
registre conservait déjà tout le nécessaire.

Le constat d'ouverture a été corrigé en cours d'implémentation, et c'est le test qui
l'a révélé : `KI-024` annonçait deux champs dérivants, `state` et un `startedAt`
effacé. Sur la pile réelle, un seul dérive. T0051 avait déjà redéfini
`private.set_flight_dispatch_started_at` pour qu'un état terminal conserve
`old.started_at`, et sa contrainte l'exige non nul. La correction est reportée dans
`Context`, dans `KI-024` et dans les trois documents. La restitution ne dépend pas de
ce trigger, donc un changement futur ne peut pas rouvrir l'écart — c'est précisément
ce que l'issue A achète.

### Files changed

- `supabase/migrations/20260805000200_flight_start_replay_fidelity.sql` — nouvelle
  migration append-only : restitution du rejeu, invariants T0050 et garde T0060
  restatés, commentaire de table sur l'autorité du registre ;
- `supabase/tests/database/flight_start_replay_fidelity.test.sql` — nouveau fichier
  pgTAP, 13 assertions réellement découvertes, clôture avant rejeu ;
- `tests/backend/run.ps1` — chemins attendus, série d'invariants T0065, interdiction
  de lecture vivante dans le chemin de rejeu, contrôle de position de la garde,
  marqueurs de scénarios, contrôle d'ordre clôture/rejeu, exclusion du nouveau
  fichier de la garde append-only T0060, huit mutations négatives nouvelles et ligne
  de résumé ;
- `docs/SECURITY.md` — nouvelle section « Contrat d'idempotence d'une commande
  privilégiée T0065 » et réalignement de la réserve de la section T0060 ;
- `docs/ARCHITECTURE.md` — réalignement du chemin de rejeu sur la restitution ;
- `docs/QUALITY.md` — décompte porté à 24 fichiers / 552 assertions et nouvelle
  section de preuve T0065 ;
- `docs/KNOWN_ISSUES.md` — `KI-024` passe `Resolved` avec sa correction de constat ;
- `docs/CURRENT_STATE.md` — état prouvé de T0065 ;
- ce ticket et `docs/tickets/README.md`.

Aucun fichier de `packages/database/src/` n'est modifié : `backend:types:check` rend
`Database types match the local schema.`, la migration ne remplaçant qu'un corps de
fonction.

### Commands and results

Exécutées le 5 août 2026 depuis `.worktrees/t0065`, sur
`fix/T0065-rejeu-depart-vol-identique` partie de `origin/main` au merge `17ad8a8`,
sous Windows 11, Docker Desktop 29.6.2 et PostgreSQL 17.

| Commande | Résultat |
| --- | --- |
| `pwsh -NoProfile -File .\tests\backend\run.ps1` | passed — 58 mutations négatives |
| `pnpm backend:start` | passed |
| `pnpm backend:reset` (deux fois consécutives) | passed — treize migrations appliquées, seed rejoué |
| `pnpm backend:test` | passed — `Files=24, Tests=552`, `Result: PASS` |
| `pnpm backend:types:check` | passed — `Database types match the local schema.` |
| `pnpm authority:check` | passed — 10 étapes, 13 domaines, 3 surfaces, 9 mutations |
| `pnpm data-policy:check` | passed — 6 mutations |
| `pnpm maintenance:check` | passed — 8 mutations |
| `pnpm backend:stop` | passed |
| `git diff --check` | passed |

Le premier `backend:test` a **échoué**, sur l'assertion 2 de ce ticket et non sur la
restitution : elle attendait `started_at is null` après clôture. C'est ce que le
ticket annonçait ; ce n'est pas ce que la pile fait. L'assertion a été corrigée dans
le sens de la réalité mesurée, pas l'inverse, et la correction est documentée.

### Manual verification result

Réalisée le 5 août 2026 sur la pile locale, **sur état réellement commité** hors
transaction annulée, en suivant les cinq étapes du ticket. Identité `.invalid`
synthétique, aucune donnée réelle, aucun secret consigné.

1. Pile réinitialisée, compagnie créée, avion possédé, ouverture de grand livre à
   `43000000` unités mineures en `EUR`.
2. Brouillon créé puis vol démarré. Réponse acquise :
   `{"state": "active", "startedAt": "2026-08-05T18:47:14.983718+00:00",
   "aircraftId": "c1300000-…-000000000001", "dispatchId": "72ee27e6-…-24a39326931f",
   "schemaVersion": 1}`.
3. `public.close_flight` rend `completed`, `distanceNm = 168.28` et
   `settledAmountMinor = 35194`. La ligne de dispatch vivante rend ensuite
   `completed | departure kept | closed`.
4. Rejeu de la même clé d'idempotence : `replay_is_identical = t`,
   `replayed_state = active`, et les quatre autres champs identiques un par un.
5. État final commité `1|1|0|1|2|43035194` : une commande de départ, un dispatch,
   aucun vol actif, un rapport, deux écritures et un solde inchangé par le rejeu. Un
   départ frais du dispatch clôturé reste refusé par
   `Dispatch is unavailable for flight start.`

La pile a ensuite été arrêtée sans sauvegarde. Aucun contrôle de ce ticket ne
dépend du runner CI Linux : la course concurrente reste celle de T0060, déjà prouvée.

### Risks and limitations

- **Troisième redéfinition.** `start_flight_from_dispatch` est réécrite une fois de
  plus, ce qui est le coût assumé de l'issue A. Le piège de `LC-2026-002` est traité
  de front : la série T0065 du gate réaffirme contre le nouveau fichier l'empreinte
  de payload, le refus de collision, le registre privé, la transition `draft` seule,
  le blocage d'un compte en suppression, les deux verrous dérivés du serveur, la
  garde d'usage T0060 et son refus opaque. Sans cela, ces invariants auraient perdu
  leur gate au moment même où leur définition changeait de fichier.
- **Le fichier pgTAP n'est pas nommé dans le harnais CI.**
  `scripts/ci/test-backend.ps1` liste explicitement les fichiers attendus et annonce
  « twenty-three » ; il est hors des `Allowed areas` de ce ticket et n'a donc pas été
  touché. Conséquence bornée : le nouveau fichier est bien exécuté par
  `supabase test db` et un échec ferait tomber `Result: PASS`, que le harnais exige,
  mais son nom n'est pas une condition explicite. Suivi ci-dessous.
- **Le rejeu ne dit plus l'état courant.** C'est voulu et c'est la garantie
  demandée : un appelant qui voudrait connaître l'état d'un vol doit le lire, pas
  rejouer une commande. Aucun consommateur n'existe encore, la frontière Auth du
  départ de vol n'étant pas livrée.
- **Aucune frontière Auth, endpoint, appelant desktop ou cible distante** n'est
  ajoutée, conformément aux non-goals.
- **Coût cumulatif du motif de redéfinition en bloc.** La garde d'usage T0060 est
  désormais déclarée dans deux fichiers, et la garde append-only du gate exclut ces
  deux fichiers nommément. Une quatrième redéfinition devra s'y ajouter, sans quoi le
  gate la refusera — ce qui est le comportement voulu, mais chaque redéfinition
  alourdit la série d'invariants restatés. Le constat est consigné ici plutôt que
  corrigé opportunément.
- **Un rejeu affirme `active` par construction, pas par lecture.** Si une future
  commande écrivait une ligne de `private.flight_start_commands` sans transition
  réussie, le littéral deviendrait faux. Le gate ne peut pas prouver cette propriété
  d'écriture, seulement que la ligne est insérée après la mise à jour d'état dans
  cette définition ; c'est le seul endroit du dépôt qui écrit ce registre.

### Follow-ups

- Nommer `flight_start_replay_fidelity.test.sql` dans la liste explicite de
  `scripts/ci/test-backend.ps1` et corriger son décompte « twenty-three », hors
  `Allowed areas` de ce ticket.
- Étendre la même règle d'idempotence aux autres commandes privilégiées dont le
  rejeu reconstruit sa réponse depuis un état vivant, si un audit en trouve : ce
  ticket n'a corrigé que le départ de vol.

### Learning candidate LC-2026-008

- Date : 5 août 2026
- Contexte : T0065, pile Supabase locale isolée
- État : Reproduced
- Symptôme observé : après correction d'un fichier pgTAP, `pnpm backend:reset` puis
  `pnpm backend:test` rejouent l'**ancienne** version du test. Le message d'échec
  citait encore le libellé d'assertion supprimé.
- Conclusion erronée évitée : « ma correction est fausse ». Le fichier corrigé
  n'était simplement pas dans le conteneur.
- Diagnostics exécutés : le libellé d'échec ne correspondait plus au fichier de
  travail ; `Copy-SupabaseProjectToEngine` n'est appelée que par
  `scripts/start-supabase-local.ps1`, jamais par l'action `Reset` de
  `scripts/invoke-supabase-local.ps1`.
- Cause : Confirmée. Les sources Supabase sont copiées dans le moteur isolé au
  démarrage seulement ; `Reset` rejoue le contenu déjà présent dans le conteneur.
- Reproductibilité : déterministe pour toute modification de `supabase/` après un
  `backend:start`.
- Règle candidate : après toute modification sous `supabase/`, enchaîner
  `backend:stop` puis `backend:start` avant `backend:reset` et `backend:test`. Le
  risque n'est pas seulement de perdre du temps : une assertion affaiblie et jamais
  recopiée produirait un **faux succès**. `docs/QUALITY.md` porte déjà la version
  courte de cette règle pour les migrations et les seeds ; ce ticket l'étend aux
  fichiers de test et en documente le mode d'échec.

### Documentation updated

`docs/SECURITY.md`, `docs/ARCHITECTURE.md`, `docs/QUALITY.md`,
`docs/KNOWN_ISSUES.md`, `docs/CURRENT_STATE.md`, ce ticket et
`docs/tickets/README.md`.
