# Problèmes connus et follow-ups

Ce registre contient uniquement les découvertes réelles hors périmètre d'un
ticket. La roadmap contient le travail planifié.

## Format

| ID | Sévérité | Zone | Résumé | Preuve | Ticket cible | Statut |
| --- | --- | --- | --- | --- | --- | --- |

Sévérité : `Critical`, `High`, `Medium`, `Low`.
Statut : `Open`, `Accepted`, `Scheduled`, `Resolved`, `Invalid`.

## Entrées initiales

| ID | Sévérité | Zone | Résumé | Preuve | Ticket cible | Statut |
| --- | --- | --- | --- | --- | --- | --- |
| KI-001 | High | Data | Certaines mutations métier sont encore effectuées directement par le client. | Audit initial | Phase 2 | Open |
| KI-002 | High | Quality | L'exécution PostgreSQL de la suite RLS A/B/anonyme T0012 devait être prouvée sur un runtime Docker réel. | `pnpm backend:test` réussi le 29 juillet 2026 : 2 fichiers, 21 tests, résultat PASS | T0012 | Resolved |
| KI-003 | High | Release | Pas de pipeline complet d'artefacts/updater signés. | Audit initial | Phase 6 | Open |
| KI-004 | Medium | Bridge | Pas de projet de tests .NET/replay SimConnect constaté. | T0011 ajoute un harnais .NET et un replay synthétique versionné | T0011 | Resolved |
| KI-005 | Medium | Frontend | Plusieurs pages mélangent UI, règles et accès aux données. | Audit initial | Phase 4 | Open |
| KI-006 | Medium | Docs | Documentation historique partiellement désynchronisée. | Audit initial | T0001 | Open |
| KI-007 | Medium | Product | Mode solo ou VA collaborative non tranché. | ADR-0001 : MVP solo préparé pour collaboration ultérieure | T0002 | Resolved |
| KI-008 | High | Rebuild | Une réécriture totale peut omettre des comportements actuels non caractérisés. | ADR-0002 : couverture automatisée faible face au périmètre existant | Caractérisation du golden path | Open |
| KI-009 | High | Bridge | Aucun corpus de traces SimConnect rejouables n'est fourni pour prouver la parité du moteur de vol. | T0001 et ADR-0002 | Premier vertical slice SimConnect | Open |
| KI-010 | High | Release | Après création de données réelles dans le nouveau schéma, aucun retour vers l'ancien produit ne sera possible. | ADR-0002 : nouveau schéma sans compatibilité descendante | Phase 6 | Accepted |
| KI-011 | High | Support | Aucune preuve réelle distincte ne valide encore MSFS 2024 Microsoft Store/Xbox App et Steam ; une seule machine de test est disponible. | T0004 et proposition ADR-0003 | Validation plateformes / premier vertical slice SimConnect | Open |
| KI-012 | Medium | Support | Le profil matériel minimum Thrustline n'est pas mesuré ; la machine Ryzen 7 5800X, 32 Go, RX 6070 XT ne prouve que le profil recommandé cible. | Réponses Andy et ADR-0003 | T0015 | Open |
| KI-013 | Medium | Desktop | Le gain réel de Tauri/WebView2 face à un shell .NET natif n'est pas mesuré sur le profil cible. | ADR-0004 : choix fondé sur l'architecture et l'absence de runtime Chromium embarqué | T0007 puis T0015 | Open |
| KI-014 | Medium | Backend | La stack Supabase locale n'est pas strictement identique au cloud et PostgreSQL 17 doit être confirmé sur chaque projet dev/staging/prod. | Documentation officielle Supabase consultée dans T0005 | T0012 | Open |
| KI-015 | High | Bridge | Le SDK managed SimConnect officiel documente .NET Framework et dépend de binaires/installation SDK ; sa publication self-contained .NET 10 reste à prouver. | Documentation MSFS 2024 SimConnect consultée dans T0005 | T0011 | Open |
| KI-016 | Medium | Delivery | L'implémentation T0010 a été fusionnée par la PR #7 dans une branche déjà intégrée auparavant, mais le commit T0010 n'est pas présent dans `main`. | PR #7 et test d'ascendance Git au 28 juillet 2026 | Intégration T0010 | Open |
| KI-017 | High | Backend / Security | Docker Desktop 29.6.2 publie les ports Supabase sur toutes les interfaces malgré l'option loopback du réseau Docker. | Inspection des ports effectifs le 29 juillet 2026 ; `backend:start` arrête la pile et laisse zéro conteneur Supabase actif | T0012 | Open |

## Règles

- Ajouter une preuve reproductible.
- Lier à un ticket lorsqu'il devient planifié.
- Ne pas résoudre discrètement un problème hors scope.
- Retirer une entrée uniquement si son historique reste traçable dans un ticket.
