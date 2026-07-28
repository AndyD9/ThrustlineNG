# ADR-0001 — Modèle produit solo préparé pour une collaboration ultérieure

Status: Accepted
Date: 2026-07-24
Deciders: Andy (Product Owner)
Supersedes: —
Superseded by: —

## Context

Thrustline doit choisir son modèle de propriété avant de figer son schéma cible,
ses politiques RLS et son parcours d'onboarding. L'application actuelle est
principalement solo, tandis qu'une VA collaborative imposerait dès le MVP des
adhésions, rôles, invitations, révocations, conflits d'édition et audits
supplémentaires.

Andy considère la collaboration future comme probable, mais donne la priorité à
la stabilité. Après clarification, le MVP ne doit accueillir qu'un humain par
compagnie. Il ne doit exposer aucun parcours collaboratif, tout en évitant un
modèle de données qui rendrait une migration future inutilement destructive.

## Decision drivers

Les poids suivants ont été approuvés par Andy :

| Critère | Poids |
| --- | ---: |
| Adéquation à la vision d'Andy | 20 % |
| Rapidité jusqu'à une bêta stable | 20 % |
| Simplicité et fiabilité | 15 % |
| Sécurité et maîtrise des permissions | 15 % |
| Expérience solo | 10 % |
| Potentiel communautaire | 5 % |
| Coût d'hébergement et de support | 5 % |
| Capacité d'évolution | 10 % |

La stabilité prime sur la collaboration en cas de conflit.

## Options considered

### Option 1 — Solo connecté sans préparation collaborative

Un utilisateur crée, possède et gère seul une compagnie. Le MVP ne contient ni
membre, ni rôle, ni invitation. Toutes les ressources sont rattachées directement
à ce propriétaire.

- **MVP et UX** : onboarding court et aucune administration de membres.
- **Propriété et permissions** : un propriétaire unique ; données visibles par
  lui seul ; RLS principalement fondée sur son identité.
- **Audit, concurrence et exploitation** : surface minimale, sans concurrence
  entre humains sur une même compagnie.
- **Sécurité** : moindre risque d'élévation de rôle ou de fuite entre membres ;
  l'isolation entre propriétaires reste obligatoire.
- **Coût et délai** : option la moins coûteuse et la plus rapide.
- **Migration** : une collaboration ultérieure risque d'exiger une migration
  intrusive si l'identité utilisateur est utilisée partout comme clé de
  propriété.

### Option 2 — VA collaborative dès le MVP

Plusieurs utilisateurs partagent une compagnie. Le MVP doit alors fournir
membres, invitations, révocations, transfert de propriété et rôles tels que
propriétaire, administrateur, dispatcher et pilote.

- **MVP et UX** : onboarding solo plus administration complète d'une VA.
- **Propriété et permissions** : compagnie distincte de ses membres, permissions
  par rôle et appartenance vérifiée côté serveur.
- **Audit, concurrence et exploitation** : journal des actions sensibles,
  notifications, révocation immédiate et résolution des modifications
  concurrentes.
- **Sécurité** : risques supplémentaires d'élévation de rôle, d'invitation ou de
  transfert forgé, d'accès persistant d'un ancien membre et d'exposition de
  données.
- **Coût et délai** : tests RLS et scénarios d'exploitation nettement plus
  nombreux avant une bêta fiable.
- **Migration** : offre immédiatement le meilleur potentiel communautaire, au
  prix d'une complexité non nécessaire au parcours principal actuel.

### Option 3 — Solo connecté, structure préparée pour une extension collaborative

Le comportement du MVP reste strictement solo : un utilisateur possède une
compagnie et aucun autre humain ne peut la rejoindre. Le modèle persistant doit
cependant distinguer l'identité de la compagnie de celle du propriétaire et
permettre d'ajouter plus tard une relation d'appartenance sans réécrire les
ressources métier.

- **MVP et UX** : mêmes parcours visibles que l'option solo ; aucune invitation,
  liste de membres ou permission par rôle.
- **Propriété et permissions** : un propriétaire unique et une seule compagnie
  par utilisateur dans le MVP. Les contraintes serveur doivent faire respecter
  ces cardinalités.
- **Audit, concurrence et exploitation** : pas de concurrence multi-humain dans
  le MVP ; commandes sensibles toujours transactionnelles et auditables.
- **Sécurité** : l'autorisation reste strictement limitée au propriétaire. Une
  structure extensible ne doit jamais créer de droits collaboratifs implicites.
- **Coût et délai** : léger coût de modélisation supplémentaire, sans le coût des
  fonctionnalités collaboratives.
- **Migration** : une future ADR pourra ajouter membres et rôles autour de
  l'identité stable de la compagnie, avec migrations append-only.

## Decision matrix

Notes de 1 (défavorable) à 5 (très favorable). Le total est la moyenne pondérée
sur 5.

| Critère | Poids | Solo direct | VA collaborative | Solo préparé |
| --- | ---: | ---: | ---: | ---: |
| Adéquation à la vision | 20 % | 4 | 3 | 5 |
| Rapidité vers une bêta stable | 20 % | 5 | 2 | 4 |
| Simplicité et fiabilité | 15 % | 5 | 2 | 4 |
| Sécurité et permissions | 15 % | 5 | 2 | 4 |
| Expérience solo | 10 % | 5 | 3 | 5 |
| Potentiel communautaire | 5 % | 1 | 5 | 3 |
| Coût d'hébergement et de support | 5 % | 5 | 2 | 4 |
| Capacité d'évolution | 10 % | 2 | 5 | 5 |
| **Total pondéré** | **100 %** | **4,30** | **2,75** | **4,35** |

Le solo direct est légèrement plus simple à court terme, mais sa faible capacité
d'évolution le place derrière le solo préparé. La VA collaborative maximise le
potentiel communautaire, mais dégrade les critères prioritaires de stabilité,
sécurité et délai.

## Decision

**Thrustline livrera un MVP solo connecté dans lequel un utilisateur possède et
gère exactement une compagnie, avec un modèle de données préparé pour une
collaboration ultérieure mais aucune fonctionnalité collaborative exposée.**

Règles du MVP :

- cardinalité utilisateur ↔ compagnie : `0..1` compagnie possédée par utilisateur
  et exactement `1` propriétaire humain par compagnie ;
- seul rôle disponible : `owner` ;
- seul le propriétaire voit et modifie les vols, finances, flotte et horaires de
  sa compagnie ;
- aucun autre humain ne peut préparer ou effectuer un vol pour cette compagnie ;
- aucune invitation, adhésion, liste de membres, exclusion, suspension ou
  transfert de propriété ;
- le produit reste entièrement jouable seul, sans gestion de membres ;
- l'identité stable de la compagnie est distincte de l'identité du propriétaire ;
- toute structure interne préparant l'avenir reste contrainte à un propriétaire
  unique et ne confère aucun accès supplémentaire.

Si le propriétaire demande la suppression de son compte, la compagnie entre dans
le futur processus de suppression et de récupération des données. Elle est
supprimée après un délai, mais la durée, les données auditables conservées et les
obligations de rétention seront définies dans un ticket ultérieur de politique de
données. Aucune suppression irréversible ne doit être implémentée avant cette
décision.

Sont explicitement reportés après le MVP :

- membres humains supplémentaires ;
- rôles administrateur, dispatcher et pilote ;
- vols préparés ou effectués par un autre membre ;
- finances, flotte et horaires partagés en temps réel ;
- invitations, demandes d'adhésion et annuaire de membres ;
- exclusion, suspension et révocation de membre ;
- transfert de propriété ;
- appartenance d'un utilisateur à plusieurs compagnies.

Une future collaboration nécessitera une nouvelle ADR. Elle devra définir les
cardinalités, rôles, permissions, invitations, révocations, transfert de
propriété, concurrence, audit, notifications et rétention avant toute
implémentation.

## Consequences

### Positive

- Le golden path reste centré sur l'utilisateur principal décrit dans la vision.
- La surface d'autorisation et de tests inter-utilisateurs du MVP reste bornée.
- Le risque d'une collaboration partielle et incohérente est éliminé.
- Les ressources métier peuvent conserver une identité de compagnie stable lors
  d'une future extension.

### Negative

- Le produit ne peut pas servir de VA multi-pilotes dans son MVP.
- La structure préparatoire ajoute un faible coût sans bénéfice visible immédiat.
- La politique exacte de suppression du propriétaire reste à décider avant son
  implémentation.

### Risks and mitigations

- **Accès à une autre compagnie** : identité déduite du JWT, ownership vérifié
  côté serveur, RLS et tests utilisateur A/utilisateur B/anonyme.
- **Élévation de rôle côté client** : aucun rôle fourni par le client ne fait
  autorité ; seul `owner` existe dans le MVP.
- **Faux support collaboratif** : aucune ligne ou relation préparatoire ne doit
  permettre un second humain ; contrainte serveur et tests négatifs obligatoires.
- **Compagnie orpheline** : aucune suppression ou désactivation du propriétaire
  sans processus transactionnel conforme à la future politique de données.
- **Fraude financière ou de vol** : les commandes sensibles restent
  transactionnelles, idempotentes et calculées côté serveur.
- **Migration future risquée** : identité de compagnie stable, migrations
  append-only et déploiement de la collaboration seulement après une nouvelle
  ADR et des tests RLS dédiés.

## Validation

- Reformuler la section `Decision` comme : « un compte peut posséder au plus une
  compagnie et en est l'unique humain ; aucune collaboration n'est livrée dans le
  MVP ».
- Vérifier que seul le propriétaire peut voir les finances, préparer et effectuer
  un vol, ou acheter et vendre un avion.
- Vérifier qu'aucun écran ou contrat MVP ne suppose invitation, membre ou rôle
  supplémentaire.
- Lors de l'implémentation du schéma, tester anonyme, propriétaire A et
  propriétaire B, ainsi que le rejet d'un second propriétaire.
- Faire approuver une nouvelle ADR avant d'introduire toute collaboration.
