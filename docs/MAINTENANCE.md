# Workflow de dette technique et de règles de sécurité

Ce workflow donne à l'agent une boucle explicite pour détecter, qualifier,
planifier, corriger et revalider la dette technique ainsi que les règles de
sécurité. Il complète `WORKFLOW.md` sans autoriser de changement hors ticket.

## Principes

- Une dette ou une faiblesse découverte n'élargit jamais le ticket actif.
- `KNOWN_ISSUES.md` recense les défauts réels hors périmètre ; la roadmap décrit
  le travail planifié ; `SECURITY.md` contient les règles de sécurité acceptées.
- Toute correction passe par un ticket borné, sauf maintenance de gouvernance
  strictement documentaire explicitement demandée.
- Une règle de sécurité qui change une frontière de confiance, une politique de
  données, l'autorité métier ou le support exige un ticket et, si la décision est
  structurante, une ADR acceptée.
- Une consigne manuelle répétable doit devenir un test, un script ou une gate
  dès qu'une détection déterministe est raisonnable.

## Boucle obligatoire de l'agent

### 1. Inspecter

Au démarrage d'un ticket, l'agent recherche les entrées `Open`, `Accepted` ou
`Scheduled` de `KNOWN_ISSUES.md` qui touchent les zones autorisées, puis relit
les invariants correspondants de `SECURITY.md`.

À la fin du ticket, il recherche dans le diff :

- dette nouvelle ou aggravée ;
- règle de sécurité contournée, devenue inexacte ou non vérifiée ;
- contrôle manuel répété qui devrait être automatisé ;
- dépendance ou avertissement de supply chain nouvellement exposé.

### 2. Qualifier

Chaque découverte est classée avant toute action :

| Nature | Critère | Destination |
| --- | --- | --- |
| Dette technique | Coût, fragilité ou complexité prouvée sans faille active | `KNOWN_ISSUES.md` |
| Défaut de sécurité | Un invariant est violé ou une exposition réelle existe | `KNOWN_ISSUES.md` et ticket `security/*` |
| Règle de sécurité candidate | Un invariant nouveau est proposé sans décision acceptée | Completion Report, puis ticket/ADR |
| Apprentissage opérationnel | Méthode ou piège d'outil, sans défaut produit | `LEARNINGS.md` |

La preuve distingue observation, hypothèse et cause confirmée. Elle contient le
contexte, un moyen de reproduction ou une référence vérifiable, l'impact, les
limites et la zone concernée, sans secret ni donnée personnelle.

### 3. Prioriser

La sévérité de `KNOWN_ISSUES.md` pilote l'ordre :

- `Critical` : arrêter le travail concerné, préserver les preuves sans secret et
  demander une décision immédiate ; aucune publication connue vulnérable ;
- `High` : créer ou désigner un ticket avant de poursuivre un changement qui
  dépend de la zone affectée ; traiter avant une release concernée ;
- `Medium` : planifier dans les 3–8 prochains tickets lorsque la zone devient
  active, ou consigner explicitement le risque accepté par Andy ;
- `Low` : conserver dans le registre et réévaluer à la prochaine rétrospective
  de phase ou lors d'une modification de la zone.

La priorité finale respecte toujours l'ordre de mission défini dans `AGENTS.md`.
Une facilité de correction ou une préférence esthétique ne relève pas la
priorité.

### 4. Ticketiser

Le ticket de remédiation référence les entrées concernées et précise :

- le risque ou coût à réduire et la preuve de départ ;
- les zones autorisées et interdites ;
- l'invariant attendu après correction ;
- un test négatif ou contre-exemple pertinent ;
- les validations automatisées et manuelles ;
- le rollback et le risque résiduel ;
- la date ou l'événement de revalidation si le contrôle dépend d'un outil, d'une
  plateforme ou d'une version.

Utiliser une branche `security/TXXXX-*` pour une faille ou un invariant de
sécurité, et `refactor/TXXXX-*`, `fix/TXXXX-*` ou `chore/TXXXX-*` pour une dette
selon la nature réelle du changement.

### 5. Corriger et faire appliquer

L'agent implémente uniquement le ticket, exécute d'abord les preuves ciblées puis
les gates applicables et réalise la revue adversariale de `AGENTS.md`.

Pour une règle de sécurité, la définition documentaire et son mécanisme de
contrôle évoluent ensemble lorsque le ticket l'autorise. Si l'automatisation est
impossible, le ticket documente le responsable, l'environnement, la fréquence
et la preuve attendue du contrôle manuel.

Une exception à une règle de sécurité doit être explicite, bornée, approuvée par
Andy, reliée à un ticket, assortie d'un risque résiduel et d'une condition
d'expiration. L'agent ne crée ni ne renouvelle seul une exception.

### 6. Clore et revalider

Une remédiation n'est close que si :

- la preuve de non-régression passe réellement ;
- `KNOWN_ISSUES.md` conserve l'historique et passe à `Resolved`, ou documente
  explicitement un risque `Accepted` par Andy ;
- `SECURITY.md`, `CURRENT_STATE.md`, le ticket et son index sont synchronisés
  lorsqu'ils sont concernés ;
- le Completion Report consigne commandes, résultats, limites, vérification
  manuelle et risque résiduel ;
- toute règle dépendante du temps possède une date ou un événement de
  revalidation.

À chaque rétrospective de phase, l'agent revoit les entrées non résolues, les
exceptions non expirées et les règles arrivées à revalidation. Il propose les
changements de statut ; il ne transforme pas silencieusement `Accepted` en
`Resolved` et ne modifie pas seul une décision de risque d'Andy.

## Sortie attendue de chaque ticket

Le rapport final indique séparément :

- dettes et défauts de sécurité corrigés par le ticket ;
- découvertes ajoutées ou déjà suivies, sans correction opportuniste ;
- règles de sécurité ajoutées, modifiées, automatisées ou à revalider ;
- risques acceptés par Andy et risques résiduels ;
- prochain ticket de maintenance recommandé, s'il existe.
