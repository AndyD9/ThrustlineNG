# Architecture Decision Records

Les ADR conservent les décisions difficiles et leur contexte. Ils évitent que les
agents réouvrent sans cesse une question ou suivent une règle devenue obsolète.

## Convention

- `ADR-0001-solo-or-collaborative.md`
- Numéro séquentiel, titre stable.
- Une ADR acceptée n'est pas réécrite pour changer l'histoire.
- Une nouvelle ADR peut en remplacer une ancienne.
- Les détails d'implémentation ordinaires restent dans les tickets.

## ADR prioritaires

1. Modèle solo connecté ou VA collaborative.
2. Stratégie de refonte incrémentale.
3. Canal local Tauri ↔ bridge.
4. Stockage/cache hors ligne.
5. Autorité et modèle anti-triche.
6. Stratégie de distribution et mise à jour.
