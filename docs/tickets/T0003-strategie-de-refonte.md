# T0003 — Choisir la stratégie de refonte

Status: Done
Owner: Andy
Branch: `docs/t0003-strategie-refonte`
Phase: 0
Risk: High
Security-sensitive: Yes

## Goal

Choisir et documenter la manière de reconstruire Thrustline sans perdre les
comportements utiles, les données existantes ni la capacité de revenir en arrière.

Le ticket doit décider entre :

1. une **réécriture totale isolée** ;
2. une **refonte incrémentale dans la structure actuelle** ;
3. un **remplacement progressif par tranches verticales** — stratégie de type
   strangler ;
4. une variante hybride clairement définie si aucune des trois options ne répond
   aux contraintes.

La décision finale doit être enregistrée dans
`docs/decisions/ADR-0002-strategie-de-refonte.md`.

## Context

T0001 a établi que l'application actuelle compile et contient déjà une couverture
fonctionnelle importante, mais aussi :

- très peu de tests automatisés par rapport au périmètre ;
- aucun projet de tests .NET dédié ;
- aucun test RLS automatisé constaté ;
- des mutations métier directes depuis le client ;
- plusieurs pages React monolithiques ;
- une chaîne de distribution encore incomplète ;
- des versions et documents partiellement désynchronisés.

ADR-0001 a retenu un MVP solo connecté, préparé pour une collaboration ultérieure,
sans rôles collaboratifs dans le MVP.

L'expression « refonte totale » ne doit pas automatiquement conduire à supprimer
l'existant. Le dépôt actuel constitue à la fois une source de comportements
métier, une référence UX, un outil de comparaison et un risque de dette. T0003
doit déterminer précisément ce qui est conservé comme référence, réutilisé,
migré, remplacé ou archivé.

## Inputs required from Andy

Le ticket doit obtenir des réponses explicites aux questions suivantes :

1. Les données Supabase existantes doivent-elles être conservées en production,
   migrées vers un nouveau schéma ou peuvent-elles être supprimées ?
2. Existe-t-il déjà des utilisateurs externes ou uniquement des données de
   développement ?
3. L'application actuelle doit-elle continuer à fonctionner pendant la refonte ?
4. Acceptes-tu une période sans nouvelles fonctionnalités pour stabiliser le
   nouveau socle ?
5. Souhaites-tu conserver le même dépôt et le même historique Git ?
6. Quelles fonctionnalités actuelles sont indispensables pour déclarer la
   nouvelle version équivalente au MVP ?
7. Quelles parties sont considérées comme suffisamment fiables pour être
   réutilisées : UI, calculs métier, migrations, bridge SimConnect, assets ?
8. Préfères-tu une première version plus rapide avec migration progressive ou
   une attente plus longue pour remplacer l'ensemble ?
9. Quelle durée maximale de coexistence entre ancienne et nouvelle architecture
   est acceptable ?
10. Quel niveau de rollback est requis après le premier déploiement de la refonte ?

Une réponse manquante concernant les données existantes, la coexistence ou le
rollback est bloquante.

## Dependencies

- T0001 terminé.
- T0002 terminé.
- `docs/decisions/ADR-0001-modele-produit.md` accepté.
- `docs/CURRENT_STATE.md`
- `docs/PRODUCT.md`
- `docs/ARCHITECTURE.md`
- `docs/SECURITY.md`
- `docs/QUALITY.md`

## Allowed areas

- `docs/ARCHITECTURE.md`
- `docs/CURRENT_STATE.md`
- `docs/ROADMAP.md`
- `docs/KNOWN_ISSUES.md`
- `docs/decisions/`
- `docs/tickets/README.md`
- ce ticket

## Do not touch

- `app/`
- `sim-bridge/`
- `supabase/`
- `legacy/`
- `.github/`
- scripts de build ou de déploiement
- manifests, lockfiles et dépendances
- données ou migrations existantes
- modification utilisateur existante dans `app/src-tauri/Cargo.toml`

## Requirements

### 1. Inventorier les actifs à traiter

Créer une matrice classant chaque grand ensemble :

| Ensemble | Conserver comme référence | Réutiliser | Adapter | Réécrire | Archiver | Preuve requise |
| --- | --- | --- | --- | --- | --- | --- |
| UI et design | | | | | | |
| Domaine/économie | | | | | | |
| Bridge SimConnect | | | | | | |
| Contrats REST/SignalR | | | | | | |
| Schéma et données Supabase | | | | | | |
| RLS/RPC/Edge Functions | | | | | | |
| Tests | | | | | | |
| CI/release | | | | | | |
| Assets et catalogues | | | | | | |
| Documentation | | | | | | |
| `legacy/` | | | | | | |

Un choix « réutiliser » exige une preuve de qualité ou un ticket préalable de
caractérisation. La seule présence de code ne suffit pas.

### 2. Comparer les stratégies

Pour chaque option, documenter :

- organisation du dépôt et des branches ;
- durée pendant laquelle deux implémentations coexistent ;
- risque de régression fonctionnelle ;
- risque de corruption ou perte de données ;
- capacité à tester les comportements avant remplacement ;
- facilité de mise à niveau des dépendances ;
- coût de migration Supabase ;
- vitesse jusqu'à une bêta stable ;
- complexité cognitive et opérationnelle ;
- stratégie de release et rollback ;
- critères d'arrêt ou de changement de stratégie.

### 3. Produire une matrice pondérée

Noter chaque option de 1 à 5 avec justification pour :

- stabilité pendant la refonte ;
- conservation des données ;
- vitesse de livraison ;
- testabilité ;
- sécurité ;
- capacité de rollback ;
- réduction de dette ;
- risque de double maintenance ;
- compréhension du système ;
- compatibilité avec ADR-0001.

Andy valide les poids avant le score final. La stratégie ayant le meilleur score
ne devient pas automatiquement la décision si un risque bloquant subsiste.

### 4. Définir le plan de coexistence

L'ADR doit préciser :

- emplacement du nouveau code ;
- branche longue ou intégration fréquente ;
- règle d'accès à l'ancien code ;
- mécanisme de comparaison ancien/nouveau ;
- propriété du schéma et des données pendant la transition ;
- compatibilité ascendante/descendante nécessaire ;
- feature flags éventuels ;
- conditions permettant d'arrêter l'ancienne implémentation ;
- procédure d'archivage finale.

Éviter une branche de refonte isolée pendant plusieurs mois sans intégration ni CI.
Si une branche longue est retenue, documenter les synchronisations, propriétaires
et critères de sortie qui limitent ce risque.

### 5. Définir la stratégie de données

Documenter séparément :

- données jetables et données à préserver ;
- sauvegarde avant migration ;
- migrations forward-only ou réversibles ;
- double lecture/écriture éventuellement nécessaire ;
- validation d'intégrité avant et après ;
- stratégie de rehearsal sur staging ;
- fenêtre de migration ;
- rollback de l'application et du schéma ;
- durée de conservation de l'ancien format.

Aucune migration destructrice ne doit être planifiée sans sauvegarde restaurée
avec succès sur un environnement de test.

### 6. Définir les gates

La stratégie retenue doit avoir des gates mesurables :

1. baseline de caractérisation ;
2. nouveau socle reproductible ;
3. premier vertical slice fonctionnel ;
4. parité du golden path ;
5. migration des données répétée ;
6. distribution signée ;
7. extinction de l'ancienne implémentation.

Chaque gate doit indiquer preuves, responsable de validation et rollback.

### 7. Propager la décision

Après acceptation :

- créer `docs/decisions/ADR-0002-strategie-de-refonte.md` ;
- mettre `docs/ARCHITECTURE.md` en cohérence ;
- ajuster les phases et gates de `docs/ROADMAP.md` ;
- ajouter les risques différés dans `docs/KNOWN_ISSUES.md` ;
- mettre à jour `docs/CURRENT_STATE.md` ;
- identifier le prochain ticket Ready.

## Non-goals

- Créer le nouveau socle.
- Déplacer, supprimer ou réécrire du code.
- Mettre à jour Node, React, Tauri, .NET, Rust ou Supabase.
- Choisir les versions finales de la stack.
- Modifier ou appliquer une migration.
- Supprimer `legacy/`.
- Concevoir tous les tickets de la refonte.
- Implémenter des feature flags.

## Acceptance criteria

- [x] Les dix questions d'Andy ont une réponse ou le ticket est `Blocked`.
- [x] Les actifs existants sont classés avec une justification.
- [x] Les trois stratégies principales sont comparées équitablement.
- [x] Les poids de la matrice sont validés par Andy.
- [x] Une stratégie est retenue et décrite sans ambiguïté.
- [x] Le traitement du dépôt, des branches et de l'ancien code est défini.
- [x] La conservation, migration et restauration des données sont définies.
- [x] Les gates de remplacement et d'extinction sont mesurables.
- [x] Les risques de coexistence et de rollback sont explicités.
- [x] `ADR-0002` est acceptée et cohérente avec `ADR-0001`.
- [x] Aucun fichier applicatif, migration ou dépendance n'est modifié.
- [x] Le prochain ticket recommandé est identifié.

## Security review

### Assets and data

- comptes et identités ;
- compagnies, flotte, finances et rapports de vol ;
- tokens/sessions et configuration ;
- migrations, sauvegardes et ancien schéma ;
- binaires distribués et mécanisme de mise à jour.

### Trust boundaries

- ancienne application vers ancien/nouveau schéma ;
- nouvelle application vers APIs/RPC de transition ;
- processus de migration vers données de production ;
- staging, CI et production ;
- ancienne et nouvelle version installées chez les utilisateurs.

### Abuse and failure cases

- ancien client contournant une nouvelle règle serveur ;
- double écriture créant deux transactions ;
- migration partielle ou rejouée ;
- rollback applicatif incompatible avec le nouveau schéma ;
- données sensibles copiées dans un environnement non protégé ;
- feature flag modifiable côté client ;
- ancienne version restant utilisable après révocation ;
- divergence silencieuse entre ancien et nouveau calcul métier.

### Required controls

- sauvegarde chiffrée et restauration testée ;
- migrations idempotentes ou protégées contre le rejeu ;
- compatibilité explicitement versionnée ;
- serveur autoritaire pendant toute coexistence ;
- journal de migration sans secret ;
- kill switch serveur si un ancien client devient dangereux ;
- comparaison d'intégrité avant bascule ;
- séparation des environnements et moindre privilège.

## Automated validation

Ticket documentaire : aucun build applicatif requis.

```powershell
# Vérifier l'ADR produite
Test-Path docs/decisions/ADR-0002-strategie-de-refonte.md

# Vérifier les références à la stratégie dans les sources de vérité
rg -n "réécriture|incrémental|progressif|strangler|coexistence|rollback|migration" `
  docs/ARCHITECTURE.md docs/ROADMAP.md `
  docs/decisions/ADR-0002-strategie-de-refonte.md

# Vérifier qu'aucun fichier applicatif n'appartient au ticket
git diff --name-only
```

La revue humaine de la matrice, des gates et du rollback reste obligatoire.

## Manual verification

1. Lire uniquement `Decision` et `Consequences` de l'ADR.
2. Expliquer où sera développé le nouveau code.
3. Expliquer comment un comportement actuel sera comparé à son remplacement.
4. Simuler une migration qui échoue à 50 % et vérifier le plan de récupération.
5. Simuler la découverte d'une régression après publication et vérifier le rollback.
6. Vérifier que l'on sait précisément quand l'ancienne implémentation pourra être
   archivée.

Temps cible : 10–15 minutes.

## Rollback

Tant qu'aucune implémentation ne dépend de la décision, une nouvelle ADR peut
remplacer ADR-0002. Après démarrage de la refonte, tout changement de stratégie
doit inventorier le travail déjà engagé, les données créées et le coût de retour.

## Completion Report

### Summary

ADR-0002 documente le choix accepté par Andy d'une réécriture totale isolée.
L'ancien dépôt reste une référence en lecture seule ; le produit cible sera créé
dans un nouveau dépôt et un nouveau projet Supabase, sans coexistence en
production ni migration des données de développement.

### Strategy selected

Réécriture totale isolée, nouveau dépôt et historique Git neuf, branches courtes,
intégration fréquente, une seule bascule publique après parité du golden path.

### Existing assets disposition

L'UI et le design servent de référence à adapter. Tous les autres ensembles
servent au plus de référence ou de matière à caractérisation ; aucun code n'est
réutilisé par défaut. Le bridge SimConnect et le domaine sont réécrits avec
replays et tests. Le dépôt actuel et `legacy/` seront archivés après les gates.

### Data migration approach

Les données Supabase existantes sont exclusivement des données de développement
et sont jetables. Le nouveau schéma est créé depuis zéro avec seeds synthétiques.
Il n'y a ni migration, ni double lecture/écriture, ni ancien format à conserver.
La suppression réelle des anciennes données reste hors périmètre et n'a pas été
effectuée.

### Files changed

- `docs/decisions/ADR-0002-strategie-de-refonte.md`
- `docs/ARCHITECTURE.md`
- `docs/ROADMAP.md`
- `docs/KNOWN_ISSUES.md`
- `docs/CURRENT_STATE.md`
- `docs/tickets/README.md`
- `docs/tickets/T0003-strategie-de-refonte.md`

### Commands and results

- Lecture des sources de vérité, du ticket, d'ADR-0001 et inventaire des grands
  ensembles : réussi.
- `Test-Path docs/decisions/ADR-0002-strategie-de-refonte.md` : `True`.
- `rg -n "réécriture|incrémental|progressif|strangler|coexistence|rollback|migration" ...` :
  références présentes dans l'ADR, l'architecture et la roadmap.
- `git diff --check -- <fichiers T0003>` : réussi après correction d'une espace
  finale.
- Contrôle de `git status --short`, `git diff --name-only` et des fichiers non
  suivis : aucun fichier de `app/`, `sim-bridge/`, `supabase/`, `legacy/`,
  `.github/`, manifeste, lockfile ou dépendance modifié par T0003.
- Aucun build applicatif requis pour ce ticket documentaire.

### Manual verification result

Revue documentaire effectuée : la décision et ses conséquences identifient le
nouveau dépôt comme lieu de développement, les tests de caractérisation comme
comparaison, la recréation de l'environnement neuf comme récupération d'un échec
avant bascule et le rollback N-1/correctif forward après apparition de données
réelles. L'ancienne implémentation n'est archivable qu'après les sept gates.

### Risks and limitations

- Risque d'oublier des comportements non caractérisés.
- Aucun corpus de traces SimConnect rejouables n'existe encore.
- Aucun rollback vers l'ancien produit après création de données réelles.
- La création du nouveau dépôt et la suppression des anciennes données ne font
  pas partie de T0003.

### Follow-ups

- Caractériser le golden path et constituer des traces SimConnect.
- Exécuter T0004 pour la matrice Windows/MSFS.
- Fixer les budgets de stabilité et de performance.
- Créer ensuite le nouveau dépôt et son socle reproductible par ticket dédié.

### Documentation updated

ADR-0002 créée ; architecture, roadmap, état courant, problèmes connus et index
des tickets mis en cohérence.
### Git handoff

Branche constatée avant exécution : `docs/t0002-modele-produit`. Le ticket
demande `docs/t0003-strategie-refonte` ; aucune branche n'a été créée ou changée
et aucun commit, push ou PR n'a été effectué. Les modifications préexistantes
hors ticket doivent rester exclues du staging. Le bloc PowerShell final est
fourni dans le rapport de l'agent après contrôle de l'état Git, de la branche
distante par défaut et de l'upstream.
