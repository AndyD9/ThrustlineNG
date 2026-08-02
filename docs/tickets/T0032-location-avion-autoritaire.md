# T0032 — Louer un avion sans double prélèvement ni usage hors contrat

Status: Draft
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
proposer achat puis location, mais aucune décision ne fixe encore la durée du
contrat, la cadence et le montant des loyers, la grâce en cas d'impayé, ni les
conditions de résiliation.

La location introduit aussi une autorité temporelle absente du noyau actuel.
Une heure ou une commande venant du desktop, du bridge ou de la WebView ne peut
donc ni rendre une échéance exigible, ni déclarer un défaut, ni terminer un
contrat. Le ticket doit borner cette autorité avant de passer en `Ready`.

### Décisions requises d'Andy avant `Ready`

- durée fixe du premier contrat MVP ;
- cadence des loyers, instant du premier prélèvement et règle calendaire ;
- montant du loyer et éventuel paiement ou dépôt initial ;
- délai de grâce, état produit en cas d'impayé et nombre d'échecs avant défaut ;
- résiliation volontaire : autorisée ou non, préavis et éventuelle pénalité ;
- sort de l'avion à expiration, défaut et résiliation ;
- autorité serveur chargée de matérialiser les échéances tant qu'aucun ordonnanceur
  distant n'est livré.

## Workflow evidence

- 2 août 2026 — `Draft` : T0029, T0030 et T0031 sont combinés au commit
  `c94b9ff` de la branche d'intégration T0028 ; T0029 reste `Review` et absent de
  `origin/main`. T0032 est créé dans le worktree isolé `.worktrees/t0032`, sans
  présumer cette livraison.
- 2 août 2026 — cadrage suspendu avant `Ready` : les décisions économiques et
  temporelles ci-dessus modifient le produit et ne peuvent pas être inventées
  par l'agent.

## Dependencies

- T0020 — grand livre financier immuable (`Done`, livré dans `main`) ;
- T0022–T0024 — compagnie autoritaire, frontière serveur et inventaire des
  mutations (`Done`, livrés dans `main`) ;
- T0028 — politique d'ouverture (`Review`, PR #54 fusionnée dans `main` selon
  les références Git inspectées) ;
- T0029 — achat autoritaire (`Review`, fusionné dans la branche T0028 par la PR
  #56, absent de `origin/main` au dernier fetch) ;
- décisions explicites d'Andy listées dans ce ticket.

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

- [ ] Andy a validé et le ticket consigne durée, cadence, montants, grâce,
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

### Files changed

### Commands and results

### Manual verification result

### Risks and limitations

### Follow-ups

### Documentation updated
