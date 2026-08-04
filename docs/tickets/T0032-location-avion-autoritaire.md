# T0032 — Louer un avion sans double prélèvement ni usage hors contrat

Status: In progress
Owner: Andy
Branch: `feature/T0032-authoritative-aircraft-lease`
Phase: 2
Risk: High
Security-sensitive: Yes

## Goal

Ajouter une première location d'avion autoritaire côté serveur, atomique et
idempotente, dont le contrat, les échéances et la fin d'usage ne puissent être
forgés par un client distribué ni produire un double prélèvement.

## Context

T0029 implémente l'achat comptant d'une offre serveur et laisse explicitement la
location à un ticket séparé. Andy a confirmé le 2 août 2026 que le MVP doit
proposer achat puis location. Les termes MVP ont été explicitement approuvés le
4 août 2026 et sont consignés ci-dessous.

La location introduit aussi une autorité temporelle absente du noyau actuel.
Une heure ou une commande venant du desktop, du bridge ou de la WebView ne peut
donc ni rendre une échéance exigible, ni déclarer un défaut, ni terminer un
contrat. Le ticket doit borner cette autorité avant de passer en `Ready`.

### Décisions d'Andy approuvées le 4 août 2026

Ces valeurs remplacent le jeu de termes consigné le 3 août dans une révision
non fusionnée de cette branche. L'agent a présenté chaque écart avant de
réécrire l'implémentation ; Andy a tranché en faveur des termes ci-dessous.

- durée fixe : 30 jours à partir de l'activation serveur, en intervalles de
  24 heures UTC, sans date d'anniversaire ni règle de fin de mois ;
- cadence : un loyer toutes les 24 heures payé d'avance ; le loyer 1 est prélevé
  dans la transaction d'activation, les loyers 2 à 30 aux bornes suivantes, et
  l'expiration à 30 jours ne prélève rien ;
- montant : loyer autoré par offre et versionné, borné côté serveur entre 0,1 %
  et 0,5 % du prix d'achat de référence — 25 minor par jour pour le C172 de
  référence, 90 minor pour le TBM 930 ;
- paiement initial : frais de mise en service **non remboursables** de dix
  loyers, prélevés avec le loyer 1 dans la même transaction ; pas de dépôt de
  garantie, un dépôt restituable imposerait un remboursement hors périmètre ;
- impayé : aucune écriture partielle et aucun solde négatif ; grâce de 72 heures
  à partir de l'échéance échouée, soit trois échéances quotidiennes, avion
  **suspendu** pendant toute la grâce ; arriérés soldés dans la grâce par la
  commande temporelle → retour en `active` et usage rétabli ; grâce expirée avec
  arriéré → défaut terminal, sans dette et sans écriture ;
- résiliation volontaire : autorisée depuis `active` uniquement ; préavis jusqu'à
  la fin de la période déjà payée, sans prorata ; pénalité de deux loyers
  plafonnée au loyer restant dû, prélevée atomiquement ; solde insuffisant →
  commande refusée et contrat inchangé ; une échéance déjà exigible doit être
  traitée par la commande temporelle avant tout préavis ;
- usage : l'avion quitte l'inventaire exploitable à l'expiration, au défaut et à
  la prise d'effet du préavis ; la ligne d'avion, l'historique du contrat et les
  écritures restent immuables et ne sont jamais supprimés ;
- autorité temporelle MVP : commande de rattrapage réservée à `service_role`,
  portée sur un contrat, échéances traitées par `due_at` croissant, identité
  idempotente `(contrat, version de termes, séquence)`, aucune horloge cliente,
  invoquée manuellement jusqu'à livraison d'un ordonnanceur distinct.

Une seule transition est réversible, `active ⇄ past_due` — nommée `grace` dans
le schéma — et seule la commande temporelle la pilote. `defaulted`, `expired` et
`terminated` restent terminaux, donc aucun client ne peut lever un défaut.

## Workflow evidence

- 2 août 2026 — `Draft` : T0029, T0030 et T0031 sont combinés au commit
  `c94b9ff` de la branche d'intégration T0028 ; T0029 reste `Review` et absent de
  `origin/main`. T0032 est créé dans le worktree isolé `.worktrees/t0032`, sans
  présumer cette livraison.
- 2 août 2026 — cadrage suspendu avant `Ready` : les décisions économiques et
  temporelles ci-dessus modifient le produit et ne peuvent pas être inventées
  par l'agent.
- 2 août 2026 — réconciliation T0033 : la PR #59 a livré ce cadrage documentaire
  dans `main`. Le ticket reste `Draft` et aucune capacité de location n'est
  implémentée.
- 3 août 2026 — `Ready` puis `In progress` : une première série de termes est
  consignée et implémentée sur cette branche, à partir de
  `docs/reconcile-delivered-tickets` au commit `a1e937c`. Le travail reste local
  et non commité ; la relance des validations est bloquée par le quota
  d'exécution Docker de la plateforme.
- 4 août 2026 — reprise du cadrage : Andy demande à l'agent de proposer les
  termes restants, puis approuve la proposition. Les écarts avec la série du
  3 août — montant du loyer, existence et nature du paiement initial, durée de
  grâce, usage pendant la grâce, préavis et pénalité de résiliation — sont
  présentés avec leur coût avant toute réécriture. Andy tranche pour les termes
  du 4 août, qui deviennent seuls normatifs.
- 4 août 2026 — travail du 3 août sauvegardé au commit `9bea4ac` avant
  réécriture, puis `origin/main` fusionné au commit `f9c3505` : la branche
  rattrape 49 commits, dont le dispatch, le départ de vol, le référentiel
  d'aérodromes et le règlement T0051. Les conflits du gate backend, de
  l'inventaire d'autorité, des types, du seed et des documents d'état sont
  résolus en gardant les deux côtés.
- 4 août 2026 — la migration est renommée `20260804000200` : `main` possède déjà
  `20260803000200` pour le départ de vol autoritaire. La collision d'horodatage
  aurait été indétectable sans ce rattrapage.
- 4 août 2026 — la réécriture de `financial_ledger_entries_known_type` conservait
  les types de T0029 mais perdait le crédit `flight_settlement` de T0051, ce qui
  aurait désactivé silencieusement le revenu de vol. Le type est réintégré et un
  commentaire de migration l'exige explicitement.
- 4 août 2026 — validations exécutées sur la révision finale : quatre gates
  statiques verts, deux resets PostgreSQL 17 consécutifs, 22 fichiers pgTAP et
  **502 assertions réellement découvertes** au vert, types régénérés conformes.
  La fixture de concurrence du harnais CI est rejouée à la main contre la base
  locale, faute de runner Linux disponible.

## Dependencies

- T0020 — grand livre financier immuable (`Done`, livré dans `main`) ;
- T0022–T0024 — compagnie autoritaire, frontière serveur et inventaire des
  mutations (`Done`, livrés dans `main`) ;
- T0028 — politique d'ouverture (`Done`, livrée dans `main` par la PR #54) ;
- T0029 — achat autoritaire (`Done`, livré dans `main` par la chaîne de fusions
  empilées intégrée avec la PR #54) ;
- décisions explicites d'Andy listées dans ce ticket, approuvées le 3 août 2026.

## Allowed areas

Après passage du ticket en `Ready` :

- `supabase/migrations/` — une migration append-only ;
- `supabase/seed.sql` — offres et contrats synthétiques uniquement ;
- `supabase/tests/database/` — pgTAP T0032 ;
- `tests/backend/` et `scripts/ci/test-backend.ps1` ;
- `packages/database/src/database.types.ts` — types régénérés ;
- `eng/authority-inventory.json` ;
- `docs/PRODUCT.md`, `docs/ARCHITECTURE.md`, `docs/SECURITY.md`,
  `docs/QUALITY.md`, `docs/CURRENT_STATE.md` ;
- ce ticket et `docs/tickets/README.md`.

## Do not touch

- migrations existantes, politique d'ouverture T0028 et achat T0029 ;
- endpoint Edge, appel desktop, UX, bridge ou SimConnect ;
- ordonnanceur distant, cron de production ou projet Supabase distant ;
- maintenance, assurance, équipage, dispatch, revenus de vol ou fiscalité ;
- revente, location entre joueurs, transfert, crédit ou remboursement ;
- données utilisateur réelles, secrets, workflows, manifests, lockfiles et
  toolchain ;
- statuts ou Completion Reports des autres tickets.

## Requirements

Les valeurs et transitions marquées comme décisions d'Andy ne deviennent
normatives qu'après leur consignation dans ce ticket et son passage en `Ready`.

### 1. Offre et contrat serveur

- Une offre de location versionnée porte type d'avion, devise, durée, cadence,
  loyer, paiement initial éventuel et règles de fin validées par Andy.
- Le prix, la devise, les dates contractuelles, l'identité de la compagnie et
  l'état du contrat ne proviennent jamais d'un payload client.
- La commande `service_role` verrouille compagnie et offre, crée le contrat et
  rend l'avion utilisable dans une transaction unique avec toute écriture
  financière exigible à la prise d'effet.
- Une offre unitaire ne peut soutenir qu'un achat ou une location active.

### 2. Échéances et autorité temporelle

- Le serveur calcule les échéances depuis la prise d'effet et les termes
  versionnés ; aucune horloge cliente n'est acceptée.
- Une commande temporelle réservée à `service_role` matérialise une échéance
  déterminée au plus une fois et écrit son prélèvement dans le grand livre.
- Le traitement est rattrapable après interruption : un rejeu identique ne
  prélève pas deux fois et les échéances manquées sont traitées dans un ordre
  déterministe.
- T0032 prouve la commande et son rattrapage sans prétendre livrer un
  ordonnanceur distant ; l'appel automatique reste un ticket d'exploitation
  distinct avant toute donnée réelle.

### 3. Défaut, expiration et résiliation

- Les transitions autorisées sont explicites et auditées ; un client ne peut ni
  retarder une échéance, ni lever un défaut, ni prolonger un contrat. La seule
  transition réversible est `active ⇄ grace`, pilotée exclusivement par la
  commande temporelle quand les arriérés sont soldés ; `defaulted`, `expired` et
  `terminated` restent monotones et terminaux.
- Une résiliation volontaire ne raccourcit aucune obligation déjà exigible : le
  préavis court jusqu'à la fin de la période payée et la commande est refusée si
  une échéance due n'a pas encore été traitée par la commande temporelle.
- Solde insuffisant applique exactement la grâce et la transition décidées par
  Andy sans écriture partielle ni solde négatif implicite.
- À expiration, défaut ou résiliation, l'avion cesse d'être utilisable selon la
  décision produit ; l'historique du contrat et les écritures restent
  immuables.
- Une panne injectée pendant prélèvement ou terminaison restaure l'ensemble de
  la transaction.

### 4. Idempotence, isolation et preuves

- Chaque création, échéance et terminaison possède une identité idempotente liée
  au contrat et à sa version de termes.
- Une collision de clé ou deux traitements concurrents convergent vers un seul
  contrat, un seul état et au plus une écriture par obligation financière.
- `anon` ne lit rien ; le propriétaire authentifié lit uniquement les offres
  disponibles, contrats et avions de sa compagnie, sans mutation directe.
- Les pgTAP couvrent structure, ACL/RLS, succès, rejeu, collision, concurrence,
  temps aux bornes, solde insuffisant, rattrapage, fin de contrat, rollback
  injecté et compte en suppression.
- Le gate backend refuse une mutation cliente, une heure cliente, des termes
  fournis par le client ou une commande privilégiée non classée.

## Non-goals

- ordonnanceur cloud ou garantie d'exécution en production ;
- prélèvement sur un moyen de paiement réel ou dette hors grand livre ;
- renouvellement automatique, renégociation ou changement de termes ;
- plusieurs devises, conversion, inflation ou équilibrage complet ;
- maintenance, disponibilité opérationnelle ou dispatch de l'avion ;
- endpoint applicatif, UX, notifications ou données réelles.

## Acceptance criteria

- [x] Andy a validé et le ticket consigne durée, cadence, montants, grâce,
      défaut, résiliation, fin d'usage et autorité temporelle.
- [x] Une offre serveur et un contrat versionné sont créés atomiquement avec
      l'avion et toute écriture initiale applicable.
- [x] Chaque échéance est déterministe, rattrapable et prélevée au plus une fois
      sous rejeu ; la convergence concurrente reste couverte par le seul harnais
      CI Linux, rejouée manuellement en local et non exécutée sur cette machine.
- [x] Défaut, expiration et résiliation suivent les transitions approuvées sans
      mutation de l'historique financier. Réserve explicite : l'état
      `company_aircraft.is_usable` est autoritaire mais aucun consommateur ne le
      lit encore, donc « pas d'usage hors contrat » n'est pas encore opposable au
      dispatch — voir *Risks and limitations*.
- [x] A/B/anonyme et toutes les mutations ou horloges clientes sont isolés.
- [x] Deux resets, tous les pgTAP, les types et les gates passent avec un nombre
      d'assertions réellement découvert et consigné — 22 fichiers, 502
      assertions. Les courses CI restent à confirmer sur la PR.
- [x] La documentation distingue commande temporelle prouvée, ordonnanceur
      absent, branche empilée et capacité effectivement livrée dans `main`.

## Security review

- actifs/données : contrat, termes, échéances, état d'usage de l'avion,
  écritures immuables, solde et clés d'idempotence ;
- frontière : client non fiable en lecture → future frontière authentifiée →
  commandes `service_role` → PostgreSQL et horloge serveur ;
- abus : termes ou temps forgés, double prélèvement, prolongation illégitime,
  avion utilisable après fin, concurrence et rattrapage désordonné ;
- validation/autorisation : termes versionnés, identité dérivée côté serveur,
  ACL/RLS A/B/anonyme et commandes sensibles réservées à `service_role` ;
- atomicité/idempotence : création, échéance et terminaison transactionnelles,
  identités stables et verrous dans un ordre documenté ;
- logs/vie privée : aucun secret ni donnée réelle ; erreurs publiques génériques
  et preuves synthétiques sans identifiant personnel.

## Maintenance review

- dettes et problèmes connus applicables : `KI-021` interdit toujours les
  données réelles ; l'ordonnanceur et les opérations passives sont absents ;
- dette créée ou aggravée : séparation explicite entre commande temporelle et
  déclencheur automatique pour éviter une garantie de production fictive ;
- règle de sécurité ajoutée, modifiée ou à revalider : toute échéance financière
  dépend exclusivement d'un temps et d'une commande serveur ;
- contrôle manuel à automatiser : rattrapage ordonné après plusieurs échéances
  et courses concurrentes ;
- dette créée et non résorbée par ce ticket : `company_aircraft.is_usable` est
  écrit par les trois commandes de location mais lu par aucune commande de
  dispatch ; l'application effective de la fin d'usage appartient à un ticket
  dédié, le dispatch étant explicitement hors périmètre ici ;
- risque résiduel : sans ordonnanceur distant, aucune exécution à l'heure réelle
  ni disponibilité opérationnelle n'est prouvée.

## Automated validation

```powershell
pnpm.cmd backend:check
pnpm.cmd backend:test
pnpm.cmd backend:types:check
pnpm.cmd data-policy:check
pnpm.cmd authority:check
pnpm.cmd maintenance:check
git diff --check
```

## Manual verification

1. Créer deux compagnies et plusieurs offres synthétiques, puis louer une offre
   pour A et vérifier l'isolation B/anonyme.
2. Rejouer la création et une échéance après réponse perdue, puis lancer deux
   traitements concurrents et confirmer une seule obligation/écriture.
3. Avancer le temps serveur de test aux bornes validées, rattraper plusieurs
   échéances et confirmer l'ordre, les montants et les états.
4. Provoquer solde insuffisant, défaut ou résiliation selon la décision Andy,
   puis confirmer l'absence d'usage et la conservation de l'historique.
5. Injecter une panne avant chaque écriture finale et confirmer le rollback.

Temps cible : 15–20 minutes.

## Rollback

Avant fusion, abandonner la branche. Après fusion et avant toute donnée réelle,
ajouter une migration corrective ; ne jamais modifier ni supprimer la migration,
un contrat ou une écriture déjà appliqués. Une désactivation éventuelle doit
fermer les nouvelles offres sans réécrire l'historique.

## Completion Report

### Summary

Location serveur de 30 jours sur les termes approuvés le 4 août 2026 : frais de
mise en service de dix loyers et premier loyer prélevés dans la transaction
d'activation, rattrapage quotidien ordonné, grâce de 72 heures avec suspension et
rétablissement de l'avion, défaut terminal sans dette, expiration, préavis de
résiliation jusqu'à la fin de la période payée et pénalité de deux loyers
plafonnée au loyer restant dû. Les contrats et événements sont conservés et
détachés lors de la suppression d'une compagnie. Aucun ordonnanceur ni endpoint
client n'est ajouté.

### Files changed

- migration append-only `20260804000200_authoritative_aircraft_lease.sql` ;
- `supabase/seed.sql` — deux offres de location synthétiques ;
- `supabase/tests/database/aircraft_lease.test.sql` et
  `aircraft_lease_structure.test.sql` — 43 et 32 assertions ;
- `packages/database/src/database.types.ts` — types régénérés ;
- `tests/backend/run.ps1` et `scripts/ci/test-backend.ps1` ;
- `eng/authority-inventory.json` ;
- documentation produit, architecture, sécurité, qualité et état courant.

### Commands and results

- `pnpm.cmd backend:check` — PASS, 44 scénarios de mutation ;
- `pnpm.cmd authority:check` — PASS, 10 étapes, 13 domaines, 9 mutations ;
- `pnpm.cmd data-policy:check` — PASS, 6 mutations ;
- `pnpm.cmd maintenance:check` — PASS, 8 mutations ;
- `pnpm.cmd backend:reset` puis `backend:test` — PASS, 22 fichiers,
  **502 assertions découvertes** ;
- second `backend:reset` puis `backend:test` — PASS, mêmes 22 fichiers et
  502 assertions ;
- `pnpm.cmd backend:types` puis `backend:types:check` — PASS, « Database types
  match the local schema » ;
- `pnpm.cmd ci:backend` — NON EXÉCUTÉ : le harnais refuse toute machine autre
  que le runner Linux explicite. Sa fixture de location et son scénario temporel
  ont été rejoués à la main contre la base locale, avec réponse de rejeu
  identique, deux échéances et le grand livre attendu ;
- `git diff --check` — PASS, avertissements LF/CRLF seulement.

### Manual verification result

Partiellement exécutée. Isolation A/B/anonyme, rejeu, collision de clé, bornes
temporelles, solde insuffisant, entrée et sortie de grâce, défaut, expiration,
préavis, pénalité plafonnée, refus sur solde insuffisant, refus sur échéance
exigible et rollback injecté sont encodés dans les pgTAP et verts. La
convergence sous concurrence réelle n'est pas rejouée sur cette machine : elle
appartient au harnais CI Linux.

### Risks and limitations

- `company_aircraft.is_usable` est écrit par les trois commandes de location mais
  **lu par aucune commande de dispatch** : `create_dispatch_draft` ne vérifie que
  l'appartenance de l'avion à la compagnie. Un avion dont la location a expiré,
  fait défaut ou été résiliée reste donc dispatchable. La fin d'usage est
  autoritaire dans les données, pas encore opposable au dispatch ;
- la réversion `grace → active` est la seule transition non monotone du
  contrat ; elle n'est atteignable que par la commande temporelle, mais elle
  suppose un crédit au grand livre, donc en pratique un règlement de vol T0051 ;
- depuis `grace`, laisser filer jusqu'au défaut ne coûte aucune pénalité, alors
  qu'une résiliation volontaire en coûte deux loyers. L'incitation est
  assumée pour l'alpha ; son correctif naturel est un malus de réputation, hors
  périmètre ici ;
- la convergence concurrente et les trois checks GitHub restent à confirmer ;
- aucun ordonnanceur ne garantit les échéances à l'heure réelle.

### Follow-ups

- ouvrir un ticket appliquant `is_usable` aux commandes de dispatch et de départ
  de vol, seule façon de rendre « pas d'usage hors contrat » opposable ;
- confirmer les trois checks GitHub de la PR, dont le harnais CI Linux et son
  scénario de concurrence de location ;
- ordonnanceur distant des échéances, ticket d'exploitation distinct, obligatoire
  avant toute donnée réelle ;
- endpoint authentifié de location, absent par décision de périmètre.

### Documentation updated

`PRODUCT.md`, `ARCHITECTURE.md`, `SECURITY.md`, `QUALITY.md`,
`CURRENT_STATE.md`, ce ticket et son index.
