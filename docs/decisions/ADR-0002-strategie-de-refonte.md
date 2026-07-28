# ADR-0002 — Réécriture totale isolée

Status: Accepted
Date: 2026-07-24
Deciders: Andy (Product Owner)
Supersedes: —
Superseded by: —

## Context

Thrustline possède une alpha active couvrant déjà une part importante du produit,
mais sa couverture automatisée est faible au regard de ce périmètre. Aucun projet
de tests .NET ni test RLS A/B/anonyme n'a été constaté, plusieurs mutations
sensibles partent encore du client et les frontières métier sont mêlées à l'UI.

Les données Supabase actuelles sont exclusivement des données de développement.
Il n'existe aucun utilisateur externe ni donnée de production à préserver. Andy
accepte leur suppression, une indisponibilité pendant la bascule, un gel des
fonctionnalités sans limite de durée prédéfinie et une livraison publique unique.
L'application actuelle n'a pas à rester utilisable pendant la refonte. Le nouveau
produit ne doit conserver ni le dépôt ni l'historique Git actuels.

ADR-0001 impose toujours un MVP solo connecté, un propriétaire humain unique par
compagnie et au plus une compagnie par utilisateur. SimConnect reste le cœur du
produit et doit recevoir la priorité de caractérisation et de validation.

## Decision drivers

Andy a approuvé les poids suivants. Les notes vont de 1 (défavorable) à 5 (très
favorable). Pour « risque de double maintenance », une note élevée signifie un
risque faible.

| Critère | Poids |
| --- | ---: |
| Stabilité pendant la refonte | 20 % |
| Conservation des données | 15 % |
| Sécurité | 15 % |
| Testabilité | 10 % |
| Capacité de rollback | 10 % |
| Vitesse de livraison | 10 % |
| Réduction de dette | 8 % |
| Faible risque de double maintenance | 5 % |
| Compréhension du système | 4 % |
| Compatibilité avec ADR-0001 | 3 % |

La sécurité, le déterminisme du moteur de vol et l'absence de perte silencieuse
restent des conditions bloquantes indépendamment du score.

## Options considered

### Option 1 — Réécriture totale isolée

Un nouveau dépôt et un historique Git neuf accueillent le produit cible. L'ancien
dépôt reste une référence en lecture seule jusqu'à la validation de la parité du
golden path, puis est archivé. Il n'existe qu'une implémentation destinée à la
production et une seule bascule publique.

- **Dépôt et branches** : nouveau dépôt ; branches courtes et intégration
  fréquente sur sa branche principale ; aucune branche de refonte longue dans
  l'ancien dépôt.
- **Coexistence** : coexistence de développement seulement, sans exploitation
  simultanée ni double maintenance fonctionnelle.
- **Régressions** : risque élevé d'oubli fonctionnel, compensé par des tests de
  caractérisation, des replays SimConnect et une checklist de parité.
- **Données** : nouveau projet et nouveau schéma Supabase ; aucune migration de
  production puisque les données actuelles sont jetables.
- **Dépendances** : liberté de construire un socle reproductible sans compatibilité
  structurelle avec l'ancien dépôt.
- **Release** : une bascule après atteinte des gates ; retour possible au dernier
  artefact candidat avant ouverture à des utilisateurs, mais aucun retour de
  données vers l'ancien schéma.
- **Critère d'arrêt** : réévaluer la stratégie si la caractérisation ne permet pas
  de définir le golden path ou si un actif irremplaçable sans preuve est découvert.

### Option 2 — Refonte incrémentale dans la structure actuelle

Le code est restructuré composant par composant dans le dépôt courant.

- **Dépôt et branches** : historique conservé, branches courtes et migrations
  internes successives.
- **Coexistence** : frontières anciennes et nouvelles mélangées pendant une
  période longue.
- **Régressions** : comparaison locale plus facile, mais couplages cachés et
  modifications opportunistes plus probables.
- **Données** : évolution du schéma existant par migrations append-only.
- **Dépendances** : mises à niveau contraintes par le socle courant.
- **Release** : rollback par petits incréments théoriquement plus simple, mais les
  migrations et contrats doivent rester compatibles.
- **Critère d'arrêt** : abandon si les frontières ne peuvent être isolées sans
  maintenir durablement deux modèles métier.

### Option 3 — Remplacement progressif par tranches verticales

Une nouvelle implémentation remplace les parcours un à un, avec routage ou
feature flags entre ancien et nouveau système.

- **Dépôt et branches** : même dépôt ou dépôts coordonnés ; intégrations fréquentes.
- **Coexistence** : deux implémentations actives jusqu'à extinction de l'ancienne.
- **Régressions** : comparaison en conditions réelles efficace.
- **Données** : compatibilité, migration progressive ou double lecture/écriture
  nécessaires.
- **Dépendances** : nouveau socle possible, mais contrats de transition coûteux.
- **Release** : rollback par tranche et kill switch possibles.
- **Critère d'arrêt** : abandon de la coexistence si le serveur ne peut garantir
  une autorité unique ou si la double écriture menace l'intégrité.

## Decision matrix

| Critère | Poids | Totale isolée | Incrémentale | Strangler |
| --- | ---: | ---: | ---: | ---: |
| Stabilité pendant la refonte | 20 % | 3 | 3 | 4 |
| Conservation des données | 15 % | 5 | 4 | 5 |
| Sécurité | 15 % | 5 | 3 | 4 |
| Testabilité | 10 % | 5 | 3 | 4 |
| Capacité de rollback | 10 % | 2 | 4 | 5 |
| Vitesse de livraison | 10 % | 2 | 4 | 3 |
| Réduction de dette | 8 % | 5 | 3 | 4 |
| Faible risque de double maintenance | 5 % | 5 | 3 | 1 |
| Compréhension du système | 4 % | 4 | 3 | 5 |
| Compatibilité avec ADR-0001 | 3 % | 5 | 5 | 5 |
| **Total pondéré / 5** | **100 %** | **3,96** | **3,41** | **4,07** |

Le strangler obtient le meilleur score brut grâce à son rollback et à sa
stabilité en production. Il n'est toutefois pas retenu : sans utilisateurs ni
données de production, ses mécanismes de coexistence, de compatibilité et de
double maintenance ne réduisent aucun risque utilisateur réel. Ils augmentent en
revanche la surface opérationnelle et prolongent l'exposition au modèle actuel.

La réécriture totale isolée correspond aux contraintes explicites d'Andy et
maximise sécurité, testabilité et réduction de dette. Son risque principal est
la perte de comportements utiles ; les gates ci-dessous sont obligatoires pour
le maîtriser.

## Existing assets disposition

| Ensemble | Référence | Réutiliser | Adapter | Réécrire | Archiver | Preuve requise |
| --- | :---: | :---: | :---: | :---: | :---: | --- |
| UI et design | Oui | Non | Oui | Oui | Après parité | Inventaire d'écrans, captures et revue du golden path |
| Domaine/économie | Oui | Non | Non | Oui | Après tests équivalents | Tests de caractérisation puis invariants serveur |
| Bridge SimConnect | Oui | Non | Non | Oui | Après replays réussis | Traces représentatives et machine à états testée |
| Contrats REST/SignalR | Oui | Non | Non | Oui | Après tests de contrat | Schémas versionnés et tests des deux extrémités |
| Schéma et données Supabase | Oui | Non | Non | Oui | Oui | Nouveau schéma jetable, tests RLS A/B/anonyme |
| RLS/RPC/Edge Functions | Oui | Non | Non | Oui | Après équivalence | Tests négatifs, transactionnels et idempotents |
| Tests | Oui | Non | Oui | Oui | Avec l'ancien dépôt | Rejouer ou porter uniquement un test démontré pertinent |
| CI/release | Oui | Non | Oui | Oui | Après pipeline neuf | Clone propre et artefacts signés reproductibles |
| Assets et catalogues | Oui | Non | Oui | Si provenance absente | Après vérification | Licence, provenance, exactitude et format validés |
| Documentation | Oui | Non | Oui | Oui | Historique conservé | Revue contre le code et les décisions acceptées |
| `legacy/` | Oui | Non | Non | Non | Avec l'ancien dépôt | Consultation ponctuelle uniquement |

« Non » à réutiliser signifie qu'aucun code n'est copié par défaut. Une exception
exige un ticket de caractérisation, une preuve de qualité, une provenance claire
et une revue sécurité/licence.

## Decision

Thrustline sera réécrit intégralement dans un nouveau dépôt avec un historique Git
neuf. Le dépôt actuel devient une référence fonctionnelle, visuelle et
documentaire en lecture seule ; il ne sert ni de socle, ni de dépendance, ni de
branche longue de refonte.

Le nouveau dépôt utilise des branches courtes et une intégration fréquente avec
CI obligatoire. Il construit un nouveau projet Supabase et un schéma neuf. Les
données actuelles sont des données de développement jetables : elles ne sont ni
migrées, ni copiées, ni restaurées. Aucune double lecture, double écriture,
compatibilité ascendante avec l'ancien schéma ou feature flag entre les deux
applications n'est prévu.

Il n'existe aucune coexistence en production. Une seule bascule publique aura
lieu lorsque les gates sont franchies. Avant cette bascule, les environnements,
domaines, secrets et identifiants de projet restent séparés. L'ancien client ne
doit jamais recevoir d'accès au nouveau backend.

Le golden path minimal est :

1. authentification et création atomique d'une compagnie solo ;
2. acquisition et consultation d'une flotte minimale ;
3. création d'un dispatch et préparation du vol ;
4. connexion à MSFS, suivi déterministe des phases et télémétrie bornée ;
5. reprise après déconnexion ou crash ;
6. génération d'un rapport et clôture unique du vol ;
7. écriture financière autoritaire dans un grand livre minimal ;
8. installation et mise à jour signées sans perte de données.

SimConnect est le premier vertical slice critique. L'UI et le design actuels sont
adaptés comme référence d'expérience ; leur code n'est pas présumé réutilisable.
Les opérations passives, l'équipage avancé, les événements et la profondeur
économique reviennent après stabilité du golden path.

## Data and rollback strategy

- Les données actuelles sont jetables et aucune donnée externe n'existe.
- La suppression réelle des données ou du projet actuels n'appartient pas à
  T0003 et nécessite une action explicitement autorisée dans un ticket futur.
- Le nouveau schéma est créé depuis zéro par migrations forward-only,
  reproductibles et testées sur environnement jetable.
- Aucune fenêtre de migration, double écriture ou conservation de l'ancien format
  n'est requise.
- Avant la première ouverture à des utilisateurs externes, les sauvegardes et une
  restauration du nouveau backend doivent être testées.
- Avant la bascule publique, une régression ramène au dernier artefact candidat
  sain et le backend de test peut être recréé.
- Après création de données réelles, aucun rollback vers l'ancien schéma n'est
  possible. Les releases du nouveau produit devront utiliser des changements
  compatibles et un rollback applicatif vers N-1, ou une correction forward.
- Une régression découverte après publication bloque les nouvelles commandes,
  préserve les données du nouveau backend et déclenche rollback applicatif N-1
  seulement si son contrat reste compatible ; sinon, correction forward.

## Gates

| Gate | Preuves | Validation | Rollback |
| --- | --- | --- | --- |
| 1. Baseline de caractérisation | Golden path documenté, inventaire UI, traces SimConnect et invariants métier | Andy + reviewer | Compléter la caractérisation ; aucun nouveau socle dépendant |
| 2. Nouveau socle reproductible | Clone propre, builds/tests/CI et Supabase local jetable | Reviewer technique | Revenir au dernier commit vert du nouveau dépôt |
| 3. Premier vertical slice | Replay SimConnect déterministe jusqu'à un rapport versionné, sans MSFS | Reviewer bridge + Andy | Désactiver la slice ; aucun utilisateur externe |
| 4. Parité du golden path | E2E auth → compagnie → flotte → dispatch → vol → rapport → grand livre | Andy + reviewer | Refuser la bascule et corriger dans le nouveau dépôt |
| 5. Données répétées | Recréation complète du schéma, seeds et restauration d'une sauvegarde du nouveau backend | Reviewer données | Recréer l'environnement jetable |
| 6. Distribution signée | Installation propre, upgrade N-1 → N, signature, checksums et rollback applicatif | Andy sur VM + reviewer release | Conserver le dernier candidat signé sain |
| 7. Extinction de l'ancien | Gates 1–6 vertes, checklist de parité acceptée, nouvelle application seule autorisée sur le nouveau backend | Andy | Ne pas archiver tant qu'un écart bloquant subsiste |

## Consequences

### Positive

- Le nouveau socle ne porte pas les couplages ni l'historique accidentel actuels.
- Les frontières de confiance et l'autorité serveur sont conçues avant les
  fonctionnalités.
- L'absence de données réelles élimine le risque et le coût d'une migration de
  production.
- Il n'y a ni double écriture, ni routage hybride, ni ancien client connecté au
  nouveau backend.
- SimConnect et la reprise deviennent testables par replay avant reconstruction
  de l'UI complète.

### Negative

- Aucune livraison fonctionnelle publique n'a lieu avant la parité du golden path.
- Les comportements non caractérisés peuvent être oubliés.
- Le nouveau dépôt perd la traçabilité Git directe de l'implémentation actuelle.
- Une réutilisation opportuniste est interdite tant qu'elle n'est pas justifiée.
- Après la bascule et l'arrivée de données réelles, le retour à l'ancien produit
  est exclu.

### Risks and mitigations

- **Oubli fonctionnel** : inventaire, captures, tests de caractérisation et
  validation manuelle de chaque étape du golden path.
- **Moteur de vol incorrect** : traces versionnées, replays déterministes et tests
  de reconnexion, pause, slew, go-around, touch-and-go et crash.
- **Ancien client dangereux** : environnements séparés ; aucun secret du nouveau
  backend dans l'ancien client ; révocation avant ouverture publique.
- **Copie de données sensibles** : aucune copie de l'ancien projet ; seeds
  synthétiques uniquement.
- **Régression après bascule** : contrats compatibles, kill switch serveur pour
  commandes sensibles, sauvegarde restaurée et rollback N-1 testé.
- **Divergence documentaire** : ancien dépôt figé comme référence datée ; le
  nouveau dépôt devient l'unique source de vérité de l'implémentation.

## Follow-ups

1. Créer le ticket de caractérisation du golden path et des traces SimConnect.
2. Définir la matrice Windows/MSFS supportée.
3. Fixer les budgets de stabilité et de performance.
4. Créer explicitement le nouveau dépôt, ses règles de branches et son socle
   reproductible ; T0003 n'autorise pas cette création.
5. Définir avant toute bêta la sauvegarde, la restauration, la rétention et le
   rollback N-1 du nouveau produit.
