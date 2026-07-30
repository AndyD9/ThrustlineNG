# Centre de pilotage de la refonte

Ce dossier est la mémoire partagée entre Andy, les agents de planification et
Codex. Il est inspiré d'un workflow « planifier → ticket → implémenter → vérifier
→ actualiser », avec moins de doublons documentaires.

## Lecture rapide

| Besoin | Document |
| --- | --- |
| Comprendre le produit | `PRODUCT.md` |
| Comprendre la cible technique | `ARCHITECTURE.md` |
| Connaître l'état réel | `CURRENT_STATE.md` |
| Choisir le prochain travail | `ROADMAP.md` puis `tickets/` |
| Exécuter un ticket | `WORKFLOW.md` |
| Vérifier une modification | `QUALITY.md` |
| Appliquer les règles de sécurité | `SECURITY.md` |
| Appliquer la politique de données | `DATA_POLICY.md` |
| Voir les problèmes différés | `KNOWN_ISSUES.md` |
| Prendre une décision structurante | `decisions/README.md` |
| Créer un ticket | `templates/TICKET.md` |

## Sources de vérité

Il n'existe que quatre documents d'état à maintenir :

1. `PRODUCT.md` : ce que Thrustline doit être ;
2. `ARCHITECTURE.md` : comment le système est structuré ;
3. `CURRENT_STATE.md` : ce qui existe aujourd'hui ;
4. les tickets : ce qui est prévu, en cours ou terminé.

`SECURITY.md`, `QUALITY.md` et `WORKFLOW.md` sont des règles relativement stables.
Les ADR conservent l'historique des décisions sans réécrire le passé.

## Cycle

```text
Vision / contraintes
        ↓
Roadmap par résultats
        ↓
Ticket petit et vérifiable
        ↓
Revue du ticket avant code
        ↓
Branche isolée + implémentation
        ↓
Tests + vérification manuelle
        ↓
Revue sécurité / architecture
        ↓
Completion Report
        ↓
CURRENT_STATE + ticket suivant
```

## Discipline documentaire

- Ne jamais copier la même information dans plusieurs fichiers.
- Une décision structurante devient un ADR.
- Une découverte hors périmètre devient une entrée dans `KNOWN_ISSUES.md`.
- `CURRENT_STATE.md` décrit le présent, jamais les intentions.
- La roadmap décrit des résultats, pas un historique de commits.
- Les détails exécutables appartiennent au ticket.
