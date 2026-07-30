# Apprentissages opérationnels

Ce registre permet aux agents de conserver et d'améliorer les méthodes prouvées
dans le dépôt. Il ne remplace ni les tickets, ni `KNOWN_ISSUES.md`, ni les ADR.
Il interdit qu'une observation de session devienne silencieusement une vérité
globale.

## États

| État | Signification |
| --- | --- |
| `Observed` | Un fait a été observé une fois avec son contexte. |
| `Reproduced` | Le fait a été reproduit dans deux contextes indépendants ou par un scénario déterministe. |
| `Codified` | La méthode prouvée est documentée à sa destination canonique. |
| `Enforced` | Un test, un script ou une gate détecte automatiquement le cas. |
| `Stale` | La règle doit être revalidée, remplacée ou retirée de sa destination canonique. |

Les états décrivent le niveau de preuve, pas une progression obligatoire. Un
apprentissage non automatisable peut rester `Codified`. Un candidat `Observed`
peut expirer sans être promu.

## Règles de preuve et de promotion

- Capturer une première occurrence dès qu'elle peut éviter une fausse
  conclusion, une perte de temps répétée ou un faux résultat de validation.
- Ne jamais stocker de secret, jeton, header d'authentification, donnée
  personnelle ou chemin contenant une identité lorsqu'une variable
  d'environnement suffit.
- Consigner la commande exacte, l'environnement utile, le résultat et la limite.
  Un code de sortie seul ne prouve pas que le contrôle attendu a réellement
  tourné.
- Exiger deux occurrences indépendantes ou une reproduction déterministe avant
  promotion.
- Autoriser une promotion après une occurrence reproductible uniquement pour un
  risque élevé de sécurité, perte de données ou faux succès, avec revue
  explicite.
- Préférer une preuve négative ou un contre-exemple lorsque la règle empêche une
  confusion, par exemple « trouvé » ne signifie pas « exécutable ».
- Donner une portée étroite et une date de revalidation aux règles dépendantes de
  Windows, d'un sandbox, d'un outil externe ou d'une version.
- Ne jamais utiliser un apprentissage opérationnel pour modifier une décision
  produit, une frontière de confiance, une politique de données, le support ou
  un budget sans ticket et, lorsque nécessaire, ADR acceptée.

## Destination canonique

| Nature | Destination |
| --- | --- |
| Observation propre au travail courant | Completion Report du ticket |
| Défaut réel hors périmètre | `docs/KNOWN_ISSUES.md` |
| Commande ou preuve de validation | `docs/QUALITY.md` |
| Méthode de réalisation des tickets | `docs/WORKFLOW.md` |
| Invariant applicable à tous les agents | `AGENTS.md` |
| Décision produit, sécurité ou architecture | Ticket et ADR |
| Détection déterministe | `scripts/` et `tests/` dans un ticket autorisé |

Dupliquer une règle détaillée dans plusieurs destinations crée de la dérive.
Conserver ici son historique et un lien vers sa destination canonique.

## Modèle de candidat

Copier ce bloc dans le Completion Report. L'identifiant suit
`LC-AAAA-NNN`, avec un compteur annuel croissant.

```markdown
### Learning candidate LC-AAAA-NNN

- Date :
- Ticket, branche ou contexte :
- État : Observed | Reproduced | Codified | Enforced | Stale
- Symptôme observé :
- Conclusion erronée évitée :
- Diagnostics exécutés :
- Résultats et limites :
- Cause : Confirmée | Probable | Inconnue
- Reproductibilité :
- Portée :
- Contournement sûr :
- Risques :
- Destination proposée :
- Revalidation :
```

Si le ticket n'autorise pas la destination proposée, conserver le candidat dans
son Completion Report et créer un follow-up borné. Ne pas élargir le diff.

## Registre

| ID | État | Résumé | Preuve et portée | Destination canonique | Revalidation |
| --- | --- | --- | --- | --- | --- |
| LC-2026-001 | `Codified` | Sous Windows, la résolution ou la présence d'un lanceur ne prouve ni son démarrage dans le sandbox ni sa compatibilité de version. | Incidents PowerShell observés lors des validations Windows ; distinguer absent, trouvé mais non lançable, lançable incompatible et lançable compatible. Portée : agents Windows et outils dépendant du contexte utilisateur. | `AGENTS.md`, section « Validation proportionnée » | 2026-10-30 ou changement de runner |

## Procédure générique de diagnostic d'un outil

Pour un outil dont le lanceur peut dépendre du profil utilisateur, établir
séparément :

1. sa résolution dans le `PATH` du processus ;
2. la présence d'un chemin candidat construit sans nom d'utilisateur codé en
   dur ;
3. la capacité à créer le processus dans le contexte courant ;
4. la version réellement exécutée ;
5. la compatibilité avec la version exigée par le dépôt.

Le résultat appartient à l'un des états suivants :

| Capacité | Conclusion autorisée |
| --- | --- |
| Introuvable après les probes prévus | Absent dans le contexte inspecté |
| Trouvé mais démarrage refusé | Installé ou exposé, non exécutable ici |
| Démarré avec mauvaise version | Exécutable, incompatible |
| Démarré avec version conforme | Exécutable et compatible |

Un fallback peut permettre une lecture ou un diagnostic limité. Il ne prouve
jamais la réussite d'une validation exigeant l'outil ou la version d'origine.

## Revalidation et retrait

À la date prévue, après changement du runner ou après mise à jour majeure de
l'outil :

1. rejouer les probes documentés ;
2. conserver les nouveaux résultats sans secrets ;
3. confirmer la portée ou marquer l'entrée `Stale` ;
4. corriger ou retirer la règle dans sa destination canonique ;
5. conserver ici l'entrée et la référence au changement qui l'a remplacée.

Une règle contredite n'est jamais maintenue « par prudence » : elle est marquée
`Stale` jusqu'à réconciliation.
