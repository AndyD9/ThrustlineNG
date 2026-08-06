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
- Avant d'attribuer un identifiant, chercher sa valeur dans tout le dépôt et non
  seulement dans ce registre. Un `LC-AAAA-NNN` peut être réservé par le
  Completion Report d'un ticket sans être encore inscrit ici : c'est une
  réservation, pas un numéro libre. Collision réellement survenue le 5 août 2026,
  `LC-2026-004` ayant été réservé par T0061 puis réattribué par la vague T0060 ;
  l'entrée la plus récente a été renumérotée `LC-2026-007`, parce que renuméroter
  celle de T0061 aurait exigé de réécrire le Completion Report d'un ticket déjà
  fusionné. Un trou dans la suite est préférable à une collision.
- Un candidat nommé dans le Completion Report d'un ticket fusionné doit être
  inscrit ici, sans quoi son identifiant reste réservé mais introuvable, et le
  prochain agent le réattribue de bonne foi.

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
| LC-2026-002 | `Codified` | Une réécriture en bloc d'un objet SQL déjà livré doit réaffirmer ses invariants contre le **nouveau** fichier, et prouver par un diff avant/après qu'elle n'a rien perdu. | Deux contextes indépendants. T0032 a réécrit en bloc la contrainte `financial_ledger_entries_known_type` et supprimé puis réintégré le crédit `flight_settlement` de T0051. T0060 réécrit `create_dispatch_draft` pour la troisième fois alors que les marqueurs de `tests/backend/run.ps1` sont épinglés par fichier de migration : les séries T0047, T0050, T0051 et T0057 continuent de passer contre leurs propres fichiers même quand la définition vivante déménage, donc le gate ne rattrape pas seul la perte d'un invariant. Le diff des deux définitions extraites avant et après est la preuve la moins coûteuse que le seul écart attendu est la garde ajoutée. Portée : migrations Supabase append-only et tout gate dont les marqueurs sont épinglés par fichier. | `docs/QUALITY.md`, section « Règles issues des défauts déjà observés » | 2026-11-05 ou à la prochaine redéfinition d'une fonction déjà livrée |
| LC-2026-003 | `Codified` | Un gate à regex multiligne ou de proximité doit être exécuté contre les fins de ligne que le runner verra, pas contre celles que le script vient d'écrire. | Deux contextes indépendants. T0062 a établi que le fixture écrit par `Set-Content` est en CRLF alors qu'une ancre `$` sous `(?m)` en .NET ne correspond jamais avant `\r\n` : quatre des dix mutations ne mutaient rien et `pnpm ticket-automation:check` rendait 10 assertions sur 34 dans `main`, après avoir été annoncé vert. T0060 a rejoué ses marqueurs de proximité après conversion de ses deux nouveaux fichiers en CRLF, l'état que produisent `.gitattributes` `* text=auto` et `core.autocrlf true` au checkout Windows, avant de publier. Portée : gates PowerShell à regex, sous Windows PowerShell 5.1 comme sous PowerShell 7. | `docs/QUALITY.md`, section « Règles issues des défauts déjà observés » | 2026-11-05 ou changement de `.gitattributes`, de runner ou d'hôte PowerShell |
| LC-2026-004 | `Enforced` | Un drapeau de sûreté exprimé en négatif dégrade vers le chemin dangereux dès que l'argument n'arrive pas sous la forme attendue : exiger un mode d'écriture explicite, et échouer fermé sur tout le reste, y compris une erreur d'analyse. | Reproduction pendant T0061, consignée dans `docs/tickets/T0061-automatiser-cycle-tickets.md` § Learning candidate LC-2026-004 : `ticket-run` lancé avec `args: { dryRun: true }` a franchi sa garde et démarré un agent d'implémentation réel sur T0056, arrêté par `TaskStop` avant toute écriture. L'argument est arrivé sous forme de chaîne JSON, donc `args.dryRun` valait `undefined` et `Boolean(undefined)` a rendu le mode écriture par défaut. Contre-preuve utile : le run précédent `wf_de548011-0df`, avec le drapeau exprimé en négatif, avait démarré un second agent d'implémentation. Portée : tout script d'orchestration recevant ses arguments d'un appelant externe. | `scripts/ticket-run` et tout workflow équivalent, où la garde `mode: "execute"` l'applique déjà | 2026-11-05 ou changement de la forme des arguments passés aux workflows |
| LC-2026-005 | `Codified` | Une assertion pgTAP sur le catalogue PostgreSQL doit caster le type `name` et attendre le littéral réellement stocké. | Reproduction déterministe sur PostgreSQL 17 pendant T0060 : `results_eq` sur une colonne de type `name` échoue par « could not determine which collation to use for string comparison » jusqu'à comparer `proname::text` ou une chaîne agrégée ; et `proconfig` rend `search_path=""`, guillemets inclus, donc une assertion sur `set search_path = ''` doit les attendre. Portée : fichiers pgTAP exécutés par `pnpm backend:test` sur l'image de Supabase CLI 2.109.1. | `docs/QUALITY.md`, section « Règles issues des défauts déjà observés » | 2026-11-05 ou changement d'image PostgreSQL ou de version de CLI Supabase |
| LC-2026-006 | `Observed` | L'ordre de deux contrôles de refus est une propriété de sécurité : placer la garde d'usage avant le contrôle d'exclusivité rend les deux refus indistinguables jusque dans le `CONTEXT` PostgreSQL. | Une occurrence, non promue. Dans la branche T0060, un avion inutilisable portant déjà un dispatch ouvert et un avion d'une autre compagnie rendent le même message depuis la même ligne de fonction ; l'ordre inverse aurait créé un canal d'énumération de la flotte d'un tiers. Deux contrôles de position encodent cet ordre dans `tests/backend/run.ps1`, mais ils vivent dans la Pull Request brouillon #112 et ne sont pas dans `main`. Portée : commandes serveur qui empilent plusieurs refus volontairement opaques. | Registre et Completion Report de T0060 ; `docs/SECURITY.md` proposé après fusion et une seconde occurrence indépendante | 2026-11-05 ou à la prochaine garde ajoutée à une commande de mise en service |
| LC-2026-008 | `Reproduced` | La pile locale sert la copie des sources Supabase prise à son démarrage : une Edge Function ajoutée après `backend:start` rend `404 Function not found` alors que tous les gates locaux passent. | Reproduction déterministe le 6 août 2026 pendant la vérification live de F0001 : `flight-start` rendait 404 sur la pile courante et 401 après un cycle `backend:stop`/`start`/`reset`, sans aucun autre changement. Diagnostic en une commande : sonder `POST /functions/v1/<nom>` sans auth — 401 = chargée, 404 = absente. Conclusion erronée évitée : « la fonction ou son client est défectueux » alors que la pile est simplement périmée. Portée : runtime local isolé T0021, tout changement sous `supabase/functions/` ou `config.toml`. | Registre ; `docs/QUALITY.md` proposé à la prochaine occurrence | 2026-11-05 ou changement du runtime local |
| LC-2026-007 | `Codified` | Une pile locale singleton peut être résiduelle sans être occupée : conclure « bloqué par l'environnement » exige les deux relevés qui le prouvent. | Une occurrence reproductible, promue par l'exception de ce registre pour un risque de faux résultat de validation, après revue explicite le 5 août 2026. Pendant T0060, le runtime `thrustline-local-engine` était présent mais `exited 255` depuis le 5 août 2026 à 10:42 UTC, sans aucun écouteur sur 54321 à 54323 : aucun travail concurrent ne l'occupait, et il a été retiré par les seules commandes du dépôt, jamais par une manipulation Docker directe. Exception confirmée et maintenue le 5 août 2026, Andy ayant explicitement délégué ce choix : la règle reste `Codified` parce que la redécouvrir coûte une vague entière conclue à tort « bloquée par l'environnement », alors que l'appliquer coûte deux relevés. Portée : Windows avec Docker Desktop 29.6.2 et la pile `backend:*`. Limite : le relevé prouve l'absence d'écouteur à l'instant du relevé, pas l'absence d'un autre agent qui démarrerait juste après. | `docs/QUALITY.md`, section « Règles issues des défauts déjà observés » | 2026-11-05 ou changement de Docker Desktop ou du runtime local |

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
