# Tickets de refonte

Créer un fichier par ticket à partir de `docs/templates/TICKET.md`.

## Convention

- Nom : `T0001-baseline-reproductible.md`
- Un ticket = un résultat et une branche.
- Les tickets détaillés ne sont créés que quelques étapes à l'avance.
- Le statut et le Completion Report restent dans le fichier du ticket.
- Un ticket terminé est conservé pour la traçabilité.

## Backlog initial

| ID | Titre | Phase | Dépend de | Statut |
| --- | --- | --- | --- | --- |
| T0001 | Baseline reproductible et inventaire | 0 | — | Done |
| T0002 | Choisir le modèle produit solo ou collaboratif | 0 | T0001 | Done |
| T0003 | Choisir la stratégie de refonte | 0 | T0001–T0002 | Done |
| T0004 | Définir la matrice de support Windows et MSFS | 0 | T0001–T0003 | Done |
| T0005 | Sélectionner la stack cible et ses versions compatibles | 0 | T0001–T0004 | Verify |
| T0006 | Épingler les runtimes et créer la source de versions | 1 | T0005 | Blocked |
| T0007 | Créer le shell Tauri minimal et mesurer son empreinte | 1 | T0006 | Blocked |
| T0008 | Créer le frontend React minimal | 1 | T0006–T0007 | Blocked |
| T0009 | Créer le bridge .NET minimal | 1 | T0006 | Backlog |
| T0010 | Établir le contrat local et le health check | 1 | T0007–T0009 | Backlog |
| T0011 | Créer l'adaptateur SimConnect et le replay | 1–3 | T0009–T0010 | Backlog |
| T0012 | Créer Supabase local et les tests RLS | 1 | T0006 | Backlog |
| T0013 | Consolider la CI multi-stack | 1 | T0006–T0012 | Backlog |
| T0014 | Valider le packaging Windows non signé | 1 | T0007–T0013 | Backlog |
| T0015 | Fixer les budgets stabilité et performance | 0–1 | T0007–T0011 | Backlog |

T0005 attend la vérification humaine de la matrice et des sources. T0006 est
préparé mais reste bloqué jusqu'à l'acceptation de T0005 et au choix explicite du
nouveau dépôt. T0007 est préparé mais reste bloqué jusqu'à la validation complète
du socle T0006. T0008 est préparé mais reste bloqué jusqu'à la validation du shell
Tauri et de sa baseline T0007. Les tickets détaillés sont créés par lots de 3 à 8
selon `WORKFLOW.md`.
