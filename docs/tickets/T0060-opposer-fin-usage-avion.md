# T0060 — Opposer la fin d'usage d'un avion au dispatch et au départ de vol

Status: In progress
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

- [ ] Une seule migration append-only ajoute la garde, sans modifier ni
      supprimer aucune migration livrée, avec un horodatage vérifié contre
      `origin/main` au moment de l'implémentation.
- [ ] Un avion dont la location est expirée, en défaut, résiliée ou suspendue
      pendant la grâce est refusé **aux deux bornes** : création de brouillon et
      départ de vol.
- [ ] Les deux refus rendent les messages publics génériques déjà livrés, sans
      révéler l'existence ni l'état d'une location ; le refus est indistinguable
      de celui d'un avion étranger.
- [ ] Un avion acheté comptant, un avion sous location `active` et un avion
      revenu de `grace` à `active` restent dispatchables et démarrables.
- [ ] Un vol déjà en cours reste clôturable et réglé normalement, conformément à
      la décision d'Andy, et le même avion refuse ensuite un nouveau brouillon.
- [ ] Le rejeu d'une commande de départ acquise avant la perte d'usage rend la
      même réponse stockée.
- [ ] Les redéfinitions de `create_dispatch_draft` et
      `start_flight_from_dispatch` conservent tous les invariants T0047, T0050,
      T0051 et T0057, et ces invariants sont réaffirmés par les marqueurs du
      gate contre le nouveau fichier.
- [ ] Les mutations négatives du gate échouent quand la garde est retirée,
      affaiblie, rendue bavarde, ouverte à un rôle client ou pilotée par un
      paramètre d'appelant.
- [ ] Deux resets consécutifs, tous les pgTAP, les types régénérés et les gates
      passent avec des décomptes réellement découverts et consignés ; la course
      concurrente est confirmée sur le runner CI Linux.
- [ ] La documentation distingue la garde livrée de ce qui reste absent :
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

À remplir après implémentation.

### Summary

### Files changed

### Commands and results

### Manual verification result

### Risks and limitations

### Follow-ups

### Documentation updated
