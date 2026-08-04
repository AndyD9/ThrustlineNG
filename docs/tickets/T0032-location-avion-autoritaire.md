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
3 août 2026 et sont consignés ci-dessous.

La location introduit aussi une autorité temporelle absente du noyau actuel.
Une heure ou une commande venant du desktop, du bridge ou de la WebView ne peut
donc ni rendre une échéance exigible, ni déclarer un défaut, ni terminer un
contrat. Le ticket doit borner cette autorité avant de passer en `Ready`.

### Décisions d'Andy approuvées le 3 août 2026

- durée fixe : 30 jours à partir de l'activation serveur ;
- cadence : un loyer toutes les 24 heures, premier loyer prélevé à l'activation ;
- montant : 0,5 % du prix d'achat de référence par loyer, arrondi au centime
  supérieur ; aucun dépôt ni autre paiement initial ;
- impayé : grâce unique de 48 heures à partir de l'échéance ; si le loyer reste
  impayé à la fin de la grâce, le contrat passe en défaut ;
- résiliation volontaire : immédiate, sans préavis, pénalité ni remboursement ;
- usage : autorisé pendant la grâce, interdit dès expiration, défaut ou
  résiliation ;
- autorité temporelle MVP : commande de rattrapage réservée à `service_role`,
  invoquée manuellement jusqu'à livraison d'un ordonnanceur distinct.

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
- 3 août 2026 — `Ready` : Andy approuve explicitement les termes ci-dessus ; les
  dépendances sont `Done` et le périmètre est exécutable.
- 3 août 2026 — `In progress` : branche
  `feature/T0032-authoritative-aircraft-lease` mise à niveau sur la branche
  documentaire corrective `docs/reconcile-delivered-tickets` au commit
  `a1e937c`; implémentation démarrée sans ordonnanceur distant.
- 3 août 2026 — implémentation locale : migration, fixtures, types, inventaire,
  gate à 28 mutations et 16 fichiers pgTAP ajoutés. Une révision intermédiaire
  de la migration a passé un reset PostgreSQL 17. Le run découvrant réellement
  les 16 fichiers a trouvé successivement une collision de fixture puis une
  lecture directe interdite au rôle privilégié ; les deux causes sont corrigées.
  La relance sur la révision finale est bloquée par le quota d'exécution Docker,
  donc le ticket reste `In progress`.

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

- Les transitions autorisées sont explicites, monotones et auditées ; un client
  ne peut ni retarder une échéance, ni lever un défaut, ni prolonger un contrat.
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
- [ ] Une offre serveur et un contrat versionné sont créés atomiquement avec
      l'avion et toute écriture initiale applicable.
- [ ] Chaque échéance est déterministe, rattrapable et prélevée au plus une fois
      sous rejeu et concurrence.
- [ ] Défaut, expiration et résiliation suivent les transitions approuvées sans
      usage hors contrat ni mutation de l'historique financier.
- [ ] A/B/anonyme et toutes les mutations ou horloges clientes sont isolés.
- [ ] Deux resets, tous les pgTAP, les types, les courses et les gates passent
      avec un nombre d'assertions réellement découvert et consigné.
- [ ] La documentation distingue commande temporelle prouvée, ordonnanceur
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

À remplir après décisions, implémentation et validation.

### Summary

Implémentation locale d'une location serveur de 30 jours avec premier loyer à
l'activation, rattrapage quotidien ordonné, grâce, défaut, expiration,
résiliation et retrait d'usage. Les contrats et événements sont conservés et
détachés lors de la suppression d'une compagnie. Aucun ordonnanceur ni endpoint
client n'est ajouté.

### Files changed

- migration append-only T0032 et deux fixtures synthétiques ;
- deux fichiers pgTAP structure/comportement ;
- types de base, gate backend, course CI et inventaire d'autorité ;
- documentation produit, architecture, sécurité, qualité et état courant.

### Commands and results

- reset local PostgreSQL 17 sur une révision intermédiaire — PASS ;
- premier run pgTAP après ajout des tests — non probant, seulement 14 fichiers
  historiques découverts ;
- run reconstruit, 16 fichiers — FAIL sur collision de fixture, corrigée ;
- run reconstruit suivant, 16 fichiers/22 assertions T0032 atteintes — FAIL sur
  lecture directe sous `service_role` dans la fixture, corrigée ;
- relance finale, second reset, types générés et courses CI — non exécutés,
  quota Docker de la plateforme atteint ;
- `tests/backend/run.ps1` — PASS, 28 mutations ;
- gates autorité, données et maintenance — PASS, 9/6/8 mutations ;
- parse PowerShell CI et JSON d'autorité — PASS ;
- `git diff --check` — PASS, avertissements LF/CRLF seulement.

### Manual verification result

Non terminée. Les scénarios sont encodés dans pgTAP, mais leur run final et les
courses concurrentes doivent être exécutés avant toute transition vers
`Review` ou `Done`.

### Risks and limitations

La révision finale de la migration, incluant le détachement à la suppression de
compagnie et la correction stricte de fin de grâce, n'a pas encore été rejouée
sur PostgreSQL 17. Les types ont été alignés localement mais pas comparés à une
régénération. Aucun ordonnanceur ne garantit les échéances à l'heure réelle.

### Follow-ups

- reconstruire la pile locale, effectuer deux resets, exécuter les 16 fichiers
  pgTAP et vérifier le total attendu de 331 assertions ;
- exécuter `backend:types:check` et la course CI création/rattrapage ;
- seulement après ces preuves, effectuer la revue adversariale finale et passer
  le ticket à `Review` ou `Verify` selon les résultats.

### Documentation updated

`PRODUCT.md`, `ARCHITECTURE.md`, `SECURITY.md`, `QUALITY.md`,
`CURRENT_STATE.md`, ce ticket et son index.
