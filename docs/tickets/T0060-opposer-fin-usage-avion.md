# T0060 — Opposer la fin d'usage d'un avion au dispatch et au départ de vol

Status: Review
Owner: Andy
Branch: `feature/T0060-aircraft-usability-guard`
Phase: 2
Risk: High
Security-sensitive: Yes

## Goal

Rendre `public.company_aircraft.is_usable` opposable aux deux seules entrées qui
mettent un avion en service — la création d'un brouillon de dispatch et le départ
de vol — pour qu'un avion dont la location est expirée, en défaut, résiliée ou
suspendue pendant la grâce ne puisse plus recevoir de mission.

## Context

T0032 a livré la location autoritaire dans `main` par la PR #105. Sa migration
`supabase/migrations/20260804000200_authoritative_aircraft_lease.sql` ajoute
`public.company_aircraft.is_usable`, la met à `false` à l'expiration, au défaut,
à la prise d'effet du préavis et pendant la grâce, et la remet à `true` quand les
arriérés sont soldés par la commande temporelle.

Aucun consommateur ne lit cette colonne :

- `public.create_dispatch_draft`, dont la définition vivante est celle de
  `supabase/migrations/20260804000100_authoritative_flight_settlement.sql:349`,
  ne vérifie que l'appartenance de l'avion à la compagnie — la recherche qui rend
  `Aircraft is unavailable for dispatch.` filtre sur `id` et `company_id`, jamais
  sur l'usage ;
- `public.start_flight_from_dispatch`, dans
  `supabase/migrations/20260803000200_authoritative_flight_start.sql`, ne lit pas
  du tout la ligne d'avion : elle verrouille la compagnie puis le dispatch et
  fait passer l'état `draft` → `active` sans jamais consulter
  `public.company_aircraft`.

Conséquence directe : un avion dont la location est terminée peut encore recevoir
un nouveau brouillon et décoller. La garantie « pas d'usage hors contrat » de
T0032 est donc autoritaire dans les données mais **pas opposable** — T0032 le
consigne explicitement dans ses *Risks and limitations*, ses *Follow-ups* et sa
*Maintenance review*, le dispatch étant dans sa liste « Do not touch ».

Ce ticket ferme exactement cet écart. Il n'ajoute aucune source d'inutilisabilité
nouvelle : `is_usable` reste écrit par les seules commandes de location et lu par
les deux commandes de mise en service.

La définition vivante de `create_dispatch_draft` ayant déjà été réécrite deux
fois — par T0057 puis par T0051 —, la garde impose une troisième réécriture
intégrale de cette fonction. C'est le risque principal du ticket : T0032 a perdu
puis réintégré le crédit `flight_settlement` de T0051 en réécrivant en bloc la
contrainte `financial_ledger_entries_known_type`. Le même piège existe ici, et le
gate backend ne le rattrape pas seul : `tests/backend/run.ps1` épingle chaque
série de marqueurs sur le **fichier de migration** qui l'a introduite, donc les
marqueurs T0057 et T0051 continueront de passer contre leurs propres fichiers
même si la nouvelle définition perd un de leurs invariants.

## Workflow evidence

- 4 août 2026 — création du ticket dans un worktree isolé, à partir de
  `origin/main` au commit `0ea42fe`.
- 4 août 2026 — la dépendance à T0032 est vérifiée contre `origin/main` et non
  supposée : la PR #105 est fusionnée au merge `0ea42fe` et la migration de
  location est présente dans `main` depuis le commit `18a8bac`. Le prérequis de
  fusion est donc **déjà satisfait** et le ticket est créé directement en
  `Ready`, sans passer par un `Draft` d'attente. Le fichier T0032 et sa ligne
  d'index restent `Review` en attendant la confirmation de ses trois checks
  GitHub ; ce ticket ne les modifie pas.
- 4 août 2026 — décision produit d'Andy : un vol **déjà en cours** sur un avion
  qui devient inutilisable reste clôturable. `public.close_flight` n'est donc pas
  gardé et le périmètre se limite aux deux entrées de mise en service. La raison
  retenue : garder un dispatch actif inclôturable rendrait le vol définitivement
  bloqué après un défaut terminal, et la sortie de grâce de T0032 suppose un
  crédit au grand livre, donc en pratique un règlement de vol T0051.
- 4 août 2026 — écart hors périmètre trouvé puis corrigé avant l'implémentation
  de ce ticket, dans un commit distinct : la chaîne de fichiers pgTAP exigés par
  `scripts/ci/test-backend.ps1` ne listait pas les deux fichiers de location de
  T0032. `supabase test db` les exécutait, mais rien ne les rendait
  obligatoires : supprimés ou renommés, le job Linux aurait continué de passer.
  Les deux fichiers rejoignent la chaîne, le refus annonce désormais
  « all twenty-two files with Result: PASS », la ligne de résumé passe de
  « 20 pgTAP files » à « 22 pgTAP files » et cite la location, et
  `tests/backend/run.ps1` reçoit trois marqueurs qui interdisent une nouvelle
  dérive silencieuse du décompte. Ce ticket enregistrera ses propres fichiers
  pgTAP dans la même chaîne et mettra à jour le même décompte.
- 5 août 2026 — passage en `In progress` dans le fichier et dans l'index, sur la
  branche `feature/T0060-aircraft-usability-guard` créée depuis `origin/main` au
  merge `c51f3fe`. Le worktree dédié `.worktrees/t0060` est propre à la création
  et aucune modification préexistante n'y est constatée. La dépendance T0032 est
  revérifiée à cette date : la migration
  `supabase/migrations/20260804000200_authoritative_aircraft_lease.sql` est bien
  présente dans `origin/main`, donc le prérequis de fusion reste acquis.
- 5 août 2026 — passage en `Review` dans le fichier et dans l'index après
  implémentation, preuves locales et revue adversariale du diff. Le seul contrôle
  non exécuté ici est la course concurrente du harnais CI Linux, qui reste attendue
  de la Pull Request ; aucune Pull Request n'est fusionnée par ce ticket.
- 5 août 2026 — `origin/main` avait avancé de deux commits pendant
  l'implémentation (T0062, merge `c0f16dc`). `origin/main` est fusionné dans la
  branche sans conflit — la seule zone commune est la ligne d'index ajoutée pour
  T0062, résolue automatiquement — puis tous les statuts ticket/index sont
  revérifiés et tous les gates statiques rejoués sur l'arbre fusionné. Avant cette
  fusion, `pnpm ticket-automation:check` échouait sur la branche : c'est
  exactement le défaut que T0062 corrige dans `main`, il est étranger à ce ticket
  et le gate passe après la fusion. Aucun fichier SQL n'est touché par la fusion,
  donc les preuves pgTAP et de types restent valides.
- 5 août 2026 — branche poussée et **Pull Request brouillon #112** ouverte vers
  `main` : <https://github.com/AndyD9/ThrustlineNG/pull/112>, base `main`, head
  `feature/T0060-aircraft-usability-guard`, état `MERGEABLE`. Le job Linux
  `Supabase PostgreSQL 17` **réussit en 3 min 32 s**, ce qui lève la seule réserve
  du ticket : `scripts/ci/test-backend.ps1` lance la course entre le retrait
  d'usage et la création d'un brouillon et échoue fermé si elle ne converge pas,
  donc son succès prouve la convergence sur le runner Linux. La fusion reste
  exclusivement à Andy.
- 5 août 2026 — les **trois checks GitHub sont verts** sur la PR #112 :
  `Audits, licences and SBOM` en 3 min 50 s, `Supabase PostgreSQL 17` en
  3 min 32 s et `Windows multi-stack` en 17 min 19 s. Le journal du job Linux rend
  les lignes attendues :
  `Applying migration 20260805000100_aircraft_usability_guard.sql...` sur les deux
  resets, `aircraft_usability_guard.test.sql .......... ok`,
  `Files=23, Tests=539` puis `Result: PASS`,
  `Aircraft usability concurrency passed: 2 sessions, 1 temporal command, unusable
  aircraft, no dispatch and no orphan command.` et enfin
  `Backend CI passed: 2 resets, 23 pgTAP files, ... aircraft lease and aircraft
  usability withdrawal, ...`. La dernière réserve du ticket est donc levée par le
  harnais lui-même, et non déduite d'un code de sortie.

## Dependencies

- T0032 — location autoritaire et colonne `is_usable` (`Review`, mais **fusionné
  dans `main`** par la PR #105 au merge `0ea42fe` : c'est cette fusion qui est le
  prérequis, et elle est acquise) ;
- T0047 — brouillon de dispatch et son registre privé (`Done`) ;
- T0050 — départ de vol autoritaire (`Done`) ;
- T0051 — règlement de vol, propriétaire de la définition vivante de
  `create_dispatch_draft` (`Done`) ;
- T0057 — référentiel d'aérodromes borné, dont les contrôles sont portés par la
  même fonction (`Done`) ;
- T0024 — inventaire et gate d'autorité ;
- décision d'Andy du 4 août 2026 sur la clôture d'un vol en cours, consignée
  ci-dessus.

## Allowed areas

- `supabase/migrations/` — une seule migration append-only, dont l'horodatage
  doit être strictement supérieur au dernier fichier présent dans `origin/main`
  au moment de l'implémentation et vérifié à ce moment-là, pas déduit de ce
  ticket ;
- `supabase/tests/database/` — pgTAP T0060 ;
- `tests/backend/run.ps1` et `scripts/ci/test-backend.ps1` — fichiers attendus,
  marqueurs, mutations négatives et scénario concurrent ;
- `packages/database/src/database.types.ts` — types régénérés par le script
  existant ;
- `eng/authority-inventory.json` ;
- `docs/ARCHITECTURE.md`, `docs/SECURITY.md`, `docs/QUALITY.md`,
  `docs/CURRENT_STATE.md` ;
- ce ticket et `docs/tickets/README.md`.

## Do not touch

- migrations existantes, y compris celle de la location T0032 : la garde arrive
  par un nouveau fichier ;
- écriture de `is_usable` : les trois commandes de location restent la seule
  autorité qui la modifie ;
- `public.close_flight`, le règlement, la réputation et le grand livre : la
  décision d'Andy exclut toute garde à la clôture ;
- termes de location, échéances, grâce, défaut, pénalité et ordonnanceur ;
- Edge Functions, endpoint applicatif, desktop, Rust/Tauri, bridge, SimConnect ;
- maintenance, assurance, équipage, disponibilité opérationnelle ;
- workflows, manifests, lockfiles, toolchain, cible distante, données réelles ;
- statuts et Completion Reports des autres tickets, dont ceux de T0032.

## Requirements

### 1. Garde d'usage à la création du brouillon de dispatch

- Une migration append-only redéfinit `public.create_dispatch_draft` en bloc, à
  partir de sa définition vivante du fichier de règlement, et ajoute la garde
  d'usage sur la ligne d'avion déjà verrouillée `for update`.
- La redéfinition **reprend intégralement** tous les contrôles existants :
  appartenance de l'avion à la compagnie, référentiel d'aérodromes borné T0057,
  exclusivité d'un dispatch par avion, compte en suppression, registre
  d'idempotence, forme et champs de la réponse versionnée. Aucun invariant
  existant ne peut disparaître ni être affaibli au passage.
- La garde ne lit que `is_usable` sur l'avion dérivé du serveur. Aucun paramètre
  nouveau, aucune colonne nouvelle, aucune valeur d'usage fournie par un
  appelant.
- La fonction conserve `security definer`, `set search_path = ''` et le seul
  `execute` accordé à `service_role`.

### 2. Garde d'usage au départ de vol

- La même migration redéfinit `public.start_flight_from_dispatch` pour qu'elle
  lise la ligne d'avion du dispatch, `for update`, et refuse le passage
  `draft` → `active` si l'avion n'est pas utilisable.
- Le chemin de rejeu reste inchangé : un départ déjà enregistré, obtenu quand
  l'avion était utilisable, rend exactement la même réponse stockée même si
  l'avion est devenu inutilisable entre-temps. La garde ne s'applique qu'à la
  transition fraîche, jamais à l'idempotence d'une commande déjà acquise.
- L'ordre de verrouillage est documenté dans la migration — compagnie, puis
  dispatch, puis avion — et rendu cohérent avec celui des commandes de location,
  afin qu'aucune paire (dispatch, location) ne puisse s'interbloquer.
- Aucun autre contrôle de T0050 n'est retiré : compte en suppression, dérivation
  de la compagnie et de l'avion, registre `private.flight_start_commands`,
  empreinte de payload et réponse à cinq champs sont conservés.

### 3. Message d'erreur public générique

- Les deux refus réutilisent **verbatim** les messages déjà livrés :
  `Aircraft is unavailable for dispatch.` et
  `Dispatch is unavailable for flight start.`, avec le même SQLSTATE
  `object_not_in_prerequisite_state`.
- Un avion inutilisable est donc indistinguable d'un avion inconnu ou
  appartenant à une autre compagnie. Aucun message, aucun `detail`, aucun `hint`
  ne révèle l'existence d'une location, son état, une échéance ou une grâce.
- Aucun privilège de lecture nouveau n'est accordé aux rôles clients sur les
  tables de location.

### 4. Un vol déjà en cours reste clôturable — décision d'Andy du 4 août 2026

- `public.close_flight` n'est pas modifié et ne reçoit aucune garde d'usage.
- Un vol parti alors que l'avion était utilisable se clôture et se règle
  normalement même si la location a expiré, fait défaut, a été résiliée ou est
  suspendue pendant la grâce.
- Le même avion refuse en revanche tout **nouveau** brouillon après cette
  clôture, tant qu'il n'est pas redevenu utilisable.

### 5. Preuves pgTAP

- Au moins un nouveau fichier pgTAP T0060, enregistré dans les listes de fichiers
  attendus de `tests/backend/run.ps1` et `scripts/ci/test-backend.ps1`, avec un
  nombre d'assertions **réellement découvert** et consigné.
- Les scénarios couvrent, pour chaque état d'avion inutilisable produit par les
  commandes de location réelles — expiration, défaut, résiliation prise d'effet
  et suspension pendant la grâce :
  - refus de `create_dispatch_draft` avec le message générique attendu ;
  - refus de `start_flight_from_dispatch` sur un brouillon déjà existant, créé
    quand l'avion était encore utilisable ;
  - message identique à celui rendu pour un avion appartenant à une autre
    compagnie, prouvant l'absence de canal distinctif.
- Les scénarios couvrent aussi :
  - un avion acheté comptant T0029 et un avion sous location `active`, tous deux
    dispatchables et démarrables sans régression ;
  - un retour `grace` → `active` par la commande temporelle qui rend l'avion de
    nouveau dispatchable ;
  - un vol en cours clôturé normalement pendant que l'avion est inutilisable,
    suivi du refus d'un nouveau brouillon sur ce même avion ;
  - le rejeu d'un départ enregistré avant la perte d'usage, rendant la réponse
    stockée à l'identique ;
  - `anon` et `authenticated` toujours privés d'`execute` sur les deux commandes
    et incapables d'écrire `is_usable` directement.
- Le harnais CI reçoit une course concurrente : une commande temporelle qui rend
  l'avion inutilisable et une création de brouillon sur le même avion convergent
  vers un seul résultat cohérent, sans interblocage ni brouillon orphelin.

### 6. Marqueurs de gate backend prouvant que la garde ne peut pas disparaître

- `tests/backend/run.ps1` reçoit le chemin de la nouvelle migration et une série
  de marqueurs exigeant : la lecture de `is_usable` dans chacune des deux
  commandes, les deux messages génériques inchangés, `set search_path = ''`, les
  `grant execute` réservés à `service_role` et l'ordre de verrouillage documenté.
- Parce que la garde réécrit deux fonctions en bloc, la même série **réaffirme
  contre le nouveau fichier** les invariants qu'elle reprend : appartenance de
  l'avion, bornes du référentiel d'aérodromes T0057, exclusivité d'un dispatch
  par avion et blocage d'un compte en suppression. Sans cela, ces invariants
  perdraient leur gate au moment même où leur définition vivante change de
  fichier.
- La garde append-only vérifie qu'aucune migration antérieure ne porte les
  marqueurs de la garde d'usage, et son décompte de fichiers couverts est mis à
  jour.
- Les mutations négatives ajoutées font échouer le gate lorsqu'on : retire la
  garde d'une des deux commandes, la transforme en avertissement sans `raise`,
  remplace un message générique par un message parlant de location ou d'état,
  accorde `execute` à `anon` ou `authenticated`, ou ajoute un paramètre d'usage
  contrôlé par l'appelant. Le nombre total de scénarios de mutation est mis à
  jour et consigné.
- `eng/authority-inventory.json` enregistre que les domaines `dispatch` et
  `flight-runtime` opposent désormais la fin d'usage, sans changer le statut
  d'autorité des commandes de location.

## Non-goals

- endpoint authentifié, appel desktop, UX, notification ou libellé client ;
- toute écriture de `is_usable` hors des commandes de location déjà livrées ;
- garde à la clôture de vol, changement de revenu, de plancher ou de réputation ;
- deuxième source d'inutilisabilité — maintenance, assurance, équipage,
  disponibilité opérationnelle ou immobilisation ;
- ordonnanceur des échéances, cron de production, projet Supabase distant ;
- renégociation, renouvellement, revente, transfert ou remboursement ;
- annulation d'un dispatch, replanification ou libération d'un avion ;
- suppression ou réécriture d'un contrat, d'un événement ou d'une écriture ;
- données utilisateur réelles et secrets.

## Acceptance criteria

- [x] Une seule migration append-only ajoute la garde, sans modifier ni
      supprimer aucune migration livrée, avec un horodatage vérifié contre
      `origin/main` au moment de l'implémentation.
- [x] Un avion dont la location est expirée, en défaut, résiliée ou suspendue
      pendant la grâce est refusé **aux deux bornes** : création de brouillon et
      départ de vol.
- [x] Les deux refus rendent les messages publics génériques déjà livrés, sans
      révéler l'existence ni l'état d'une location ; le refus est indistinguable
      de celui d'un avion étranger.
- [x] Un avion acheté comptant, un avion sous location `active` et un avion
      revenu de `grace` à `active` restent dispatchables et démarrables.
- [x] Un vol déjà en cours reste clôturable et réglé normalement, conformément à
      la décision d'Andy, et le même avion refuse ensuite un nouveau brouillon.
- [ ] Le rejeu d'une commande de départ acquise avant la perte d'usage rend la
      même réponse stockée. **Non satisfait, et volontairement laissé décoché.**
      La garde ne s'applique effectivement jamais à un rejeu et aucun second
      départ n'est créé — c'est la propriété que ce ticket devait préserver, et
      elle est prouvée. Mais le chemin de rejeu de T0050, repris inchangé,
      reconstruit sa réponse depuis la ligne de dispatch vivante au lieu de la
      relire d'un enregistrement : après un `close_flight`, le rejeu rend
      `state = 'completed'` au lieu de `'active'`, et `startedAt = null` parce que
      le trigger `private.set_flight_dispatch_started_at` efface cet instant dès
      que l'état quitte `active`. L'exigence §2 demande à la fois que
      ce chemin « reste inchangé » et qu'il rende « la même réponse stockée » :
      les deux moitiés ne peuvent pas être vraies ensemble. T0065 porte cette
      contradiction et sa décision.
- [x] Les redéfinitions de `create_dispatch_draft` et
      `start_flight_from_dispatch` conservent tous les invariants T0047, T0050,
      T0051 et T0057, et ces invariants sont réaffirmés par les marqueurs du
      gate contre le nouveau fichier.
- [x] Les mutations négatives du gate échouent quand la garde est retirée,
      affaiblie, rendue bavarde, ouverte à un rôle client ou pilotée par un
      paramètre d'appelant.
- [x] Deux resets consécutifs, tous les pgTAP, les types régénérés et les gates
      passent avec des décomptes réellement découverts et consignés ; la course
      concurrente est confirmée sur le runner CI Linux.
      Localement le 5 août 2026 : deux resets, 23 fichiers / 539 assertions, types
      inchangés, cinq gates verts. Sur le runner Linux de la PR #112, le harnais
      rend lui-même `Aircraft usability concurrency passed: 2 sessions, 1 temporal
      command, unusable aircraft, no dispatch and no orphan command.`
- [x] La documentation distingue la garde livrée de ce qui reste absent :
      ordonnanceur, endpoint et autres sources d'indisponibilité.

## Security review

- actifs/données : état d'usage de l'avion, propriété de la flotte, état de
  dispatch et de vol, existence et état d'une location ;
- frontière : client non fiable en lecture → future frontière authentifiée →
  commandes `service_role` → PostgreSQL ;
- abus : dispatcher ou faire décoller un avion hors contrat, forger un usage,
  contourner la garde par une écriture directe, distinguer un avion inutilisable
  d'un avion étranger pour sonder la flotte d'un tiers, gagner la course entre
  la commande temporelle et un brouillon ;
- validation/autorisation : usage lu exclusivement sur la ligne dérivée du
  serveur, aucun paramètre d'appelant, `execute` réservé à `service_role`, aucun
  privilège client nouveau, RLS existantes inchangées ;
- atomicité/idempotence : garde évaluée dans la transaction de la commande, sur
  une ligne verrouillée, dans un ordre de verrouillage documenté ; le rejeu d'une
  commande déjà acquise reste inchangé ;
- logs/vie privée : messages publics génériques déjà en place, aucun secret,
  aucun identifiant Auth, aucune donnée réelle ; preuves synthétiques seulement.

## Maintenance review

- dettes et problèmes connus applicables : `KI-021` interdit toujours les données
  réelles ; l'ordonnanceur des échéances reste absent, donc la fin d'usage n'est
  déclenchée que par un appel manuel de la commande temporelle ;
- dette résorbée : la dette explicitement consignée par T0032 —
  `company_aircraft.is_usable` écrit mais lu par aucun consommateur — est
  fermée ; la garantie « pas d'usage hors contrat » devient opposable ;
- dette créée ou aggravée : la définition vivante de `create_dispatch_draft` est
  réécrite pour la troisième fois et celle de `start_flight_from_dispatch` pour
  la seconde ; le coût de lecture du schéma augmente, et les marqueurs pinnés par
  fichier doivent être réaffirmés à chaque réécriture ;
- règle de sécurité ajoutée : la mise en service d'un avion dépend de son état
  d'usage serveur, jamais d'une donnée d'appelant ; l'écriture de cet état reste
  réservée aux commandes de location ;
- contrôle manuel à automatiser : la course entre commande temporelle et création
  de brouillon reste portée par le seul harnais CI Linux ;
- risque résiduel : sans ordonnanceur, un avion peut rester utilisable après la
  date réelle d'expiration jusqu'au prochain appel de la commande temporelle ;
  la garde est exacte par rapport à l'état enregistré, pas par rapport à l'heure
  murale.

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

1. Réinitialiser la pile locale, créer deux compagnies, louer un avion pour A et
   acheter un avion comptant pour A.
2. Avec l'avion loué encore `active`, créer un brouillon et démarrer le vol pour
   confirmer l'absence de régression, puis clôturer ce vol.
3. Faire expirer, défaillir ou résilier la location par les commandes T0032, puis
   confirmer le refus d'un nouveau brouillon et le refus du départ d'un brouillon
   préexistant, avec les messages génériques attendus et un message identique à
   celui d'un avion de la compagnie B.
4. Sur un avion suspendu pendant la grâce, confirmer le même refus, solder les
   arriérés par la commande temporelle et confirmer que le brouillon redevient
   possible.
5. Démarrer un vol, rendre l'avion inutilisable pendant ce vol, confirmer que la
   clôture reste possible et réglée, puis confirmer le refus d'un nouveau
   brouillon sur cet avion.
6. Confirmer en SQL que `authenticated` et `anon` ne peuvent ni exécuter les deux
   commandes ni écrire `is_usable`.

Temps cible : 10–15 minutes hors démarrage de la pile.

## Rollback

Avant fusion, abandonner la branche. Après fusion, la garde ne peut être levée
que par une nouvelle migration append-only qui redéfinit explicitement les deux
commandes ; ne jamais modifier ni supprimer une migration livrée, un contrat, un
dispatch ou une écriture existants. Une levée temporaire doit être consignée comme
dette de sécurité, puisqu'elle rouvre l'usage hors contrat.

## Completion Report

### Summary

Une seule migration append-only,
`supabase/migrations/20260805000100_aircraft_usability_guard.sql`, rend
`public.company_aircraft.is_usable` opposable aux deux seules entrées qui mettent
un avion en service. Son horodatage a été vérifié au moment de l'implémentation
contre `origin/main` au merge `c51f3fe` : le dernier fichier présent est
`20260804000200_authoritative_aircraft_lease.sql`, donc `20260805000100` lui est
strictement supérieur. Aucune migration livrée n'est modifiée ni supprimée.

`public.create_dispatch_draft` et `public.start_flight_from_dispatch` sont
redéfinies en bloc, à partir de leurs définitions vivantes respectives
(`20260804000100_authoritative_flight_settlement.sql:349` et
`20260803000200_authoritative_flight_start.sql:72`). Les deux lisent uniquement
`is_usable`, sur la ligne d'avion dérivée du serveur et verrouillée `for update`,
et refusent avec les messages déjà livrés
`Aircraft is unavailable for dispatch.` et
`Dispatch is unavailable for flight start.` sous
`object_not_in_prerequisite_state`. Les signatures, le contrat public,
`security definer`, `set search_path = ''` et le seul `execute` de `service_role`
sont inchangés. `start_flight_from_dispatch` lit désormais la ligne d'avion du
dispatch, ce qu'elle ne faisait pas du tout.

Deux choix de placement sont volontaires et prouvés par le gate :

- à la création d'un brouillon, la garde d'usage précède le contrôle
  d'exclusivité, pour qu'un avion inutilisable rende le même refus opaque qu'il
  porte ou non un dispatch ouvert. Sur la pile locale, le refus d'un avion
  inutilisable et celui d'un avion d'une autre compagnie partent de la même ligne
  de la fonction (`line 110`) : ils sont indistinguables jusque dans le `CONTEXT`
  PostgreSQL ;
- au départ de vol, la garde suit le chemin de rejeu, pour qu'un départ déjà
  acquis ne soit jamais refusé après la perte d'usage et ne crée aucun second
  départ. Ce rejeu rend une réponse identique tant que le dispatch est encore
  `active`, ce que le pgTAP prouve ; il ne rend pas une réponse stockée verbatim
  après une clôture, parce qu'il la reconstruit depuis la ligne de dispatch
  vivante — voir le critère décoché et T0065.

`public.close_flight` n'est pas modifié : conformément à la décision d'Andy du
4 août 2026, un vol déjà en cours reste clôturable et réglé, et seul le brouillon
suivant est refusé. Aucune écriture de `is_usable` n'est ajoutée ; les trois
commandes de location restent sa seule autorité, ce que le gate vérifie.

### Files changed

- `supabase/migrations/20260805000100_aircraft_usability_guard.sql` — nouvelle
  migration append-only : redéfinition en bloc des deux commandes, garde d'usage,
  ordre de verrouillage documenté, commentaire de colonne ;
- `supabase/tests/database/aircraft_usability_guard.test.sql` — nouveau fichier
  pgTAP, 37 assertions réellement découvertes ;
- `tests/backend/run.ps1` — chemins attendus, série de marqueurs T0060,
  réaffirmation des invariants T0047/T0050/T0051/T0057 contre le nouveau fichier,
  garde append-only à décompte explicite de onze migrations livrées, marqueurs de
  scénarios pgTAP, exigences CI et six mutations négatives nouvelles ;
- `scripts/ci/test-backend.ps1` — fichier pgTAP attendu, décompte porté à
  vingt-trois, course concurrente « retrait d'usage contre création de brouillon »
  et ligne de résumé ;
- `eng/authority-inventory.json` — les domaines `dispatch` et `flight-runtime`
  déclarent l'opposabilité de la fin d'usage, avec chemins, marqueurs et limites ;
  aucun statut d'autorité des commandes de location n'est modifié ;
- `docs/ARCHITECTURE.md`, `docs/SECURITY.md`, `docs/QUALITY.md`,
  `docs/CURRENT_STATE.md` ;
- `docs/tickets/T0060-opposer-fin-usage-avion.md`, `docs/tickets/README.md`.

Aucun autre chemin n'est touché. `packages/database/src/database.types.ts` est
resté inchangé et n'apparaît donc pas dans le diff : la migration ne remplace que
des corps de fonction, ce que `pnpm backend:types:check` confirme.

### Commands and results

Windows 11 Pro 26200, Docker Desktop 29.6.2, Supabase CLI 2.109.1,
PostgreSQL 17, worktree `.worktrees/t0060`.

| Commande | Résultat | Limite |
| --- | --- | --- |
| `pnpm backend:check` | réussi — « 50 mutation scenarios » | statique |
| `pwsh -NoProfile -File .\tests\backend\run.ps1` | réussi — même sortie sous PowerShell 7 | statique |
| `pnpm backend:start` | réussi | voir la note d'environnement ci-dessous |
| `pnpm backend:reset` (1er) | réussi — douze migrations appliquées | local |
| `pnpm backend:reset` (2e) | réussi | local |
| `pnpm backend:test` | réussi — `Files=23, Tests=539`, `Result: PASS` | base fraîchement réinitialisée requise |
| `pnpm backend:types:check` | réussi — « Database types match the local schema. » | local |
| `pnpm backend:functions:test` | réussi — 46 tests Node, 0 échec | injecté |
| `pnpm authority:check` | réussi — 10 étapes, 13 domaines, 3 surfaces, 9 mutations | statique |
| `pnpm data-policy:check` | réussi — 6 mutations | statique |
| `pnpm maintenance:check` | réussi — registre, index, marqueurs, 8 mutations | statique |
| `pnpm ticket-automation:check` | **échoué avant la fusion de `origin/main`, réussi après** — 34 assertions, 10 mutations | défaut étranger au ticket, corrigé par T0062 dans `main` ; `tests/ticket-automation/run.ps1` est hors des zones autorisées de T0060 |
| `pnpm ci:check` | réussi — dépôt plus 2 mutations | statique |
| `pnpm backend:stop` | réussi — pile arrêtée, seul le cache d'images conservé | — |
| `git diff --cached --check` | réussi, aucune sortie | — |
| `pnpm ci:backend` | **non exécuté localement, réussi sur le runner CI Linux de la PR #112** | `scripts/ci/test-backend.ps1` refuse toute machine autre que le runner Linux ; sa course concurrente T0060 est prouvée par le job `Supabase PostgreSQL 17`, pas par cette machine |

Preuve CI de la PR #112, run `31002454980` : les trois checks sont verts —
`Audits, licences and SBOM` 3 min 50 s, `Supabase PostgreSQL 17` 3 min 32 s,
`Windows multi-stack` 17 min 19 s. Le journal du job Linux applique
`20260805000100_aircraft_usability_guard.sql` sur les deux resets, rend
`aircraft_usability_guard.test.sql .......... ok`, `Files=23, Tests=539`,
`Result: PASS`, puis
`Aircraft usability concurrency passed: 2 sessions, 1 temporal command, unusable
aircraft, no dispatch and no orphan command.` et
`Backend CI passed: 2 resets, 23 pgTAP files, ... aircraft lease and aircraft
usability withdrawal, ...`.

Décompte réellement découvert : 23 fichiers pgTAP et **539 assertions**, contre 22
et 502 avant ce ticket, soit **37 assertions nouvelles**. Le gate backend porte
**50 scénarios de mutation**, contre 44 avant, soit six nouveaux : garde retirée de
la création de brouillon, garde retirée du départ de vol, garde dégradée en
`raise warning`, message générique remplacé par un message nommant la location,
`execute` accordé à `authenticated`, paramètre d'usage ajouté à la signature.

Note d'environnement, consignée sans être attribuée à ce ticket : au démarrage, la
pile locale singleton portait un runtime résiduel `thrustline-local-engine` **déjà
arrêté** (`exited 255`, démarré le 4 août 2026 à 15:36 UTC, terminé le 5 août 2026
à 10:42 UTC) et aucun des ports 54321–54323 n'était en écoute. Aucun travail
concurrent ne l'occupait donc. Il a été retiré par les seules commandes du dépôt
(`pnpm backend:stop` puis le nettoyage automatique de `pnpm backend:start` en
échec), jamais par une manipulation Docker directe.

### Manual verification result

Réalisée le 5 août 2026 sur la pile locale, **sur état réellement commité** hors
transaction annulée, en suivant les six étapes du ticket. Deux compagnies A et B,
plus deux compagnies dédiées à la grâce et au vol en cours.

1. A loue un avion et en achète un comptant ; B achète un avion et crée un
   brouillon.
2. Avec la location encore `active` : brouillon `draft`, départ `active`, clôture
   `completed` réglée à `21086` unités mineures pour 18,44 NM. Un second brouillon
   est créé sur le même avion, toujours utilisable.
3. `terminate_aircraft_lease` rend `terminating`, puis `process_aircraft_lease` à
   +24 h rend `terminated` avec `is_usable = f`. Le départ du brouillon
   préexistant est refusé par `Dispatch is unavailable for flight start.`, le
   départ du dispatch de B rend **le même message**, un nouveau brouillon sur
   l'avion inutilisable et un brouillon sur l'avion de B rendent tous deux
   `Aircraft is unavailable for dispatch.` **depuis la même ligne de la fonction**.
   L'avion acheté comptant de la même compagnie reste dispatchable (`draft`).
4. Avion suspendu pendant la grâce : état `grace`, brouillon refusé par le message
   générique ; après un crédit au grand livre et un rattrapage à +30 h, le contrat
   revient `active` avec `is_usable = t` et le brouillon redevient possible.
5. Vol démarré puis avion rendu inutilisable pendant le vol : l'état rend
   `terminated | f | active`, le rejeu de la commande de départ acquise rend
   `replay_is_identical = t`, la clôture réussit et règle `21086`, puis un nouveau
   brouillon sur ce même avion est refusé.
6. `authenticated` et `anon` reçoivent `permission denied for function
   create_dispatch_draft`, `permission denied for function
   start_flight_from_dispatch` et `permission denied for table company_aircraft`
   sur `update ... set is_usable`.

État final commité `5|3|2|6|4|0|2|2|2` : cinq avions dont trois utilisables et deux
inutilisables, six dispatchs dont quatre brouillons, aucun vol actif et deux vols
clôturés, deux commandes de départ et deux rapports. Aucune donnée réelle, aucun
secret, aucun identifiant Auth réel : uniquement des identités `.invalid`
synthétiques. La pile a ensuite été arrêtée.

La seule vérification qui reste hors de cette machine est la course concurrente du
harnais Linux `ci:backend` : elle doit être confirmée par le job
`Supabase PostgreSQL 17` de la Pull Request, qui doit annoncer
`Aircraft usability concurrency passed` et l'état `0|0|0|1`.

### Risks and limitations

- **Réécriture en bloc.** La définition vivante de `create_dispatch_draft` est
  réécrite pour la troisième fois et celle de `start_flight_from_dispatch` pour la
  seconde. Le piège identifié par le ticket est traité de front : le gate backend
  réaffirme **contre le nouveau fichier** l'appartenance de l'avion, les deux
  bornes du référentiel T0057 et son refus opaque, l'exclusivité limitée aux
  dispatchs ouverts T0051, le blocage d'un compte en suppression, les deux
  registres d'idempotence, l'empreinte de payload, la transition `draft`-seule et
  les réponses à sept et cinq champs. Sans cela, ces invariants auraient perdu
  leur gate au moment même où leur définition changeait de fichier.
- **Pas d'ordonnanceur.** La garde est exacte par rapport à l'état enregistré, pas
  par rapport à l'heure murale : un avion peut rester utilisable après sa date
  réelle d'expiration jusqu'au prochain appel manuel de la commande temporelle.
- **Course concurrente non exécutée ici.** Elle est écrite dans le harnais Linux
  et n'a pas tourné sur cette machine ; elle est prouvée par le job
  `Supabase PostgreSQL 17` de la PR #112 et reste non reproductible sous Windows.
  Elle repose sur un ordonnancement temporel — la session temporelle ouvre 750 ms
  avant la session de dispatch et tient la ligne d'avion quatre secondes —, comme
  les courses de location, d'achat, de dispatch et de clôture déjà en place ; une
  inversion la ferait échouer plutôt que passer à tort.
- **Canal résiduel au départ de vol.** Le message et le SQLSTATE d'un avion
  inutilisable et d'un dispatch étranger sont identiques, mais le `CONTEXT`
  PostgreSQL cite deux lignes différentes de la fonction. Ce `CONTEXT` n'est ni un
  message, ni un `detail`, ni un `hint`, il n'est pas rendu au client par la
  frontière Edge, et il n'est visible que d'un opérateur disposant déjà d'un accès
  SQL privilégié. À la création d'un brouillon, même cette différence n'existe pas.
- **Coût de lecture du schéma.** Trois définitions successives de
  `create_dispatch_draft` coexistent dans l'historique des migrations ; la
  définition vivante est désormais celle de ce fichier.
- **Aucune preuve applicative.** Ni frontière Auth, ni endpoint, ni appelant
  desktop, ni WebView, ni cible distante, ni parité cloud, ni donnée réelle.

### Follow-ups

- Ordonnanceur d'échéances de location, pour que la fin d'usage soit déclenchée par
  le temps et non par un appel manuel de `process_aircraft_lease`.
- Propager la garde vers la frontière Auth `dispatch-draft` et vers un futur
  endpoint de départ de vol, sans jamais accepter d'état d'usage d'un appelant.
- Rendre l'état d'usage lisible par le desktop pour que l'interface distingue un
  avion indisponible d'un avion refusé, sans révéler l'existence d'une location.
- Automatiser la course « commande temporelle contre création de brouillon »
  ailleurs que dans le seul harnais CI Linux.
- Écart hors périmètre relevé et **non corrigé** :
  `docs/CURRENT_STATE.md` annonce toujours « Migrations Supabase append-only
  constatées : 7 dans `main` » dans son inventaire reproductible, alors que
  `origin/main` au merge `c51f3fe` en porte onze. Ce décompte est antérieur à ce
  ticket et sort de son périmètre ; il mérite un ticket de gouvernance. Il n'est
  pas corrigé ici pour une seconde raison : la PR brouillon #111 possède déjà ce
  fichier et l'écrire des deux côtés recréerait la dérive de suivi des fusions
  T0043 à T0050.

### Constats de la revue adversariale du 5 août 2026

La revue indépendante du diff poussé a rendu `fix required` avec quatre constats,
tous non bloquants. Traitement, dans ce même commit sauf indication contraire :

- **Corrigé — garantie de rejeu fausse (Medium).** Le critère d'acceptation
  correspondant est décoché, et `docs/SECURITY.md`, `docs/ARCHITECTURE.md`,
  `docs/QUALITY.md`, ce Completion Report et l'intitulé de l'assertion pgTAP
  disent désormais ce que le code fait : la garde ne s'applique jamais à un rejeu,
  mais la réponse rejouée n'est pas stockée verbatim. Décision de fond portée par
  T0065.
- **Corrigé — garde-fou append-only tautologique (Low).** `tests/backend/run.ps1`
  comparait la taille d'un tableau de onze littéraux à `11`, un test qui ne pouvait
  pas échouer, et n'inspectait que ces onze fichiers. Il énumère maintenant les
  migrations réellement présentes, scanne chacune sauf celle de T0060 — donc aussi
  une treizième à venir — et exige que les onze fichiers livrés avant T0060
  apparaissent dans l'énumération, pour qu'une énumération cassée échoue au lieu de
  ne rien scanner.
- **Non corrigé, porté par T0066 — motif de refus des courses (Low).** La course
  concurrente conclut `refused` sur le seul code de sortie non nul de `psql`, donc
  un interblocage passerait pour un succès. Le défaut est partagé par les six
  courses déjà livrées dans `main` : le corriger ici élargirait ce ticket et
  entrerait en conflit avec T0066, qui le traite pour toutes.
- **Non corrigé, hors périmètre utile — décompte de migrations (Low).** Voir le
  point ci-dessus sur `docs/CURRENT_STATE.md` et la PR #111.

### Learning candidates

Selon `docs/LEARNINGS.md`, ces candidats sont consignés ici et non promus en règle
globale, `docs/LEARNINGS.md` étant hors des zones autorisées de ce ticket.

1. **Une réécriture en bloc doit réaffirmer ses invariants contre le nouveau
   fichier.** Les marqueurs du gate backend sont épinglés par fichier de migration :
   les séries T0047, T0050, T0051 et T0057 continuent de passer contre leurs
   propres fichiers même quand la définition vivante déménage. Deuxième occurrence
   indépendante de la même classe de piège après la contrainte
   `financial_ledger_entries_known_type` réécrite par T0032 ; la règle candidate
   est : toute migration qui redéfinit une fonction déjà livrée doit ajouter une
   série de marqueurs qui réaffirme, contre son propre fichier, chaque invariant
   qu'elle reprend.
2. **L'ordre des refus est une propriété de sécurité, pas un détail de style.**
   Placer la garde d'usage avant le contrôle d'exclusivité rend les deux refus
   indistinguables jusque dans le `CONTEXT` PostgreSQL ; l'inverse aurait créé un
   canal d'énumération. Encodé au niveau le plus vérifiable : deux contrôles de
   position dans `tests/backend/run.ps1`, pas une consigne de revue.
3. **Une pile locale singleton peut être « résiduelle » sans être « occupée ».**
   Un runtime `exited 255` sans aucun port en écoute n'est pas un travail
   concurrent ; distinguer les deux cas évite autant un faux blocage qu'un reset
   destructeur. Candidat de procédure : avant de déclarer la pile occupée, relever
   `docker inspect` et `Get-NetTCPConnection` sur 54321–54323.
4. **`results_eq` de pgTAP échoue sur une colonne de type `name`** avec « could not
   determine which collation to use for string comparison ». Comparer
   `proname::text`, ou agréger en une seule chaîne, contourne le problème de façon
   déterministe.
5. **`proconfig` rend `search_path=""` et non `search_path=`.** Toute assertion sur
   `set search_path = ''` doit attendre les guillemets.

### Documentation updated

- `docs/ARCHITECTURE.md` — nouvelle section « Opposabilité de la fin d'usage
  T0060 » et fermeture de la dette consignée par la section T0032 ;
- `docs/SECURITY.md` — nouvelle section T0060 avec la règle de sécurité ajoutée, et
  levée de la réserve « non opposable » de la section T0032 ;
- `docs/QUALITY.md` — décompte porté à vingt-trois fichiers et 539 assertions, et
  nouvelle section de preuve T0060 avec ses 50 mutations et sa course CI ;
- `docs/CURRENT_STATE.md` — état prouvé de T0060 sur sa branche, avec ses décomptes
  réels, sa vérification manuelle et ce qui reste absent ;
- ce ticket et `docs/tickets/README.md`.
