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
| KI-001 | High | Data | Certaines mutations métier du golden path restaient à inventorier avant de prouver qu'aucun client ne fait autorité. | T0024 couvre 10 étapes, 13 domaines et 3 surfaces ; `pnpm authority:check` passe avec 5 mutations négatives et aucune mutation cliente détectée | T0024 | Resolved |
| KI-002 | High | Quality | L'exécution PostgreSQL de la suite RLS A/B/anonyme T0012 devait être prouvée sur un runtime Docker réel. | `pnpm backend:test` réussi le 29 juillet 2026 : 2 fichiers, 21 tests, résultat PASS | T0012 | Resolved |
| KI-003 | High | Release | Pas de pipeline complet d'artefacts/updater signés. | Audit initial | Phase 6 | Open |
| KI-004 | Medium | Bridge | Pas de projet de tests .NET/replay SimConnect constaté. | T0011 ajoute un harnais .NET et un replay synthétique versionné | T0011 | Resolved |
| KI-005 | Medium | Frontend | Plusieurs pages mélangent UI, règles et accès aux données. | Audit initial | Phase 4 | Open |
| KI-006 | Medium | Docs | La roadmap courante annonçait encore T0012 en `Verify` après sa clôture. | T0025 aligne T0012 sur T0021/#41 et T0024 sur #46, tout en conservant les instantanés historiques datés | T0025 | Resolved |
| KI-007 | Medium | Product | Mode solo ou VA collaborative non tranché. | ADR-0001 : MVP solo préparé pour collaboration ultérieure | T0002 | Resolved |
| KI-008 | High | Rebuild | Une réécriture totale peut omettre des comportements actuels non caractérisés. | ADR-0002 : couverture automatisée faible face au périmètre existant | Caractérisation du golden path | Open |
| KI-009 | High | Bridge | Aucun corpus de traces SimConnect rejouables n'est fourni pour prouver la parité du moteur de vol. | T0001 et ADR-0002 | Premier vertical slice SimConnect | Open |
| KI-010 | High | Release | Après création de données réelles dans le nouveau schéma, aucun retour vers l'ancien produit ne sera possible. | ADR-0002 : nouveau schéma sans compatibilité descendante | Phase 6 | Accepted |
| KI-011 | High | Support | Aucune preuve réelle distincte ne valide encore MSFS 2024 Microsoft Store/Xbox App et Steam ; une seule machine de test est disponible. | T0004 et proposition ADR-0003 | Validation plateformes / premier vertical slice SimConnect | Open |
| KI-012 | Medium | Support | Le profil matériel minimum Thrustline n'est pas mesuré ; la machine Ryzen 7 5800X, 32 Go, RX 6070 XT ne prouve que le profil recommandé cible. | T0015 fixe des garde-fous de fondation mais classe encore le profil minimum et le scénario de quatre heures `Not measured` | Validation plateforme / avant bêta | Open |
| KI-013 | Medium | Desktop | Le gain réel de Tauri/WebView2 face à un shell .NET natif n'est pas mesuré sur le profil cible. | ADR-0004 : choix fondé sur l'architecture et l'absence de runtime Chromium embarqué | T0007 puis T0015 | Open |
| KI-014 | Medium | Backend | La stack Supabase locale n'est pas strictement identique au cloud et PostgreSQL 17 doit être confirmé sur chaque projet dev/staging/prod. | Documentation officielle Supabase consultée dans T0005 | T0012 | Open |
| KI-015 | High | Bridge | Le SDK managed SimConnect officiel documente .NET Framework et dépend de binaires/installation SDK ; sa publication self-contained .NET 10 reste à prouver. | Documentation MSFS 2024 SimConnect consultée dans T0005 | T0011 | Open |
| KI-016 | Medium | Delivery | La PR #7 avait fusionné T0010 dans une branche déjà intégrée et ne l'avait pas propagé vers `main`. | T0026 prouve que la PR #10 a ensuite fusionné `22f97d4` et `41cc940` dans `main` via `26cbcbf` ; build bridge, harnais 13/13 et tests desktop réussis le 1er août 2026 | T0026 | Resolved |
| KI-017 | High | Backend / Security | Docker Desktop 29.6.2 publie les ports Supabase sur toutes les interfaces malgré l'option loopback du réseau Docker. | T0021 confine la pile dans un daemon DinD sans socket hôte et republie 54321–54323 explicitement sur `127.0.0.1` ; inspection Docker et `Get-NetTCPConnection` réussies le 31 juillet 2026 | T0021 | Resolved |
| KI-018 | High | Frontend / Security | `react-router` 7.18.1 était concerné par `GHSA-qwww-vcr4-c8h2` ; le gate pnpm T0013 a échoué comme prévu. | T0016 épingle 8.3.0 ; audit local sans vulnérabilité connue et supply-chain GitHub `30440480513` réussie le 29 juillet 2026 | T0016 | Resolved |
| KI-019 | Medium | Desktop / Supply chain | Le lockfile Cargo contient des dépendances GTK3 non maintenues et `glib` 0.18.5 signalé unsound, même si la cible Windows ne compile pas ce chemin. | `cargo audit 0.22.2 --file apps/desktop/src-tauri/Cargo.lock --json` le 29 juillet 2026 : 0 vulnérabilité, avertissements RustSec informatifs | Revue des dépendances Tauri/Cargo | Open |
| KI-020 | High | Desktop / Stability | Le binaire Tauri Release sortait avant 30 s dans le harness, puis les bridges des cycles rapides étaient comptés trop tôt comme orphelins. | T0015 stage la publication bridge dans le layout Release, attend sa terminaison avec nettoyage fail-safe, puis réussit 5 lancements froids, 5 chauds et 10 cycles avec zéro orphelin | T0015 | Resolved |
| KI-021 | High | Backend / Privacy | T0018 couvre export/suppression et T0019 couvre restauration/replay synthétiques en CI et local Windows, mais aucune sauvegarde managée/chiffrée, purge du journal pseudonyme, restauration Vault/Storage ou promotion de production n'existe. | Run PostgreSQL 17 `30621209180` ; checklist Windows T0019 du 1er août 2026 : dump 246 ms, restauration 688 ms, replay 166 ms, refus altéré/inconnu et nettoyage réussis ; aucune donnée réelle | Sauvegarde managée, purge et exercice de production avant données réelles | Open |

## Règles

- Ajouter une preuve reproductible.
- Lier à un ticket lorsqu'il devient planifié.
- Ne pas résoudre discrètement un problème hors scope.
- Retirer une entrée uniquement si son historique reste traçable dans un ticket.
