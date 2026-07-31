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
| T0005 | Sélectionner la stack cible et ses versions compatibles | 0 | T0001–T0004 | Done |
| T0006 | Épingler les runtimes et créer la source de versions | 1 | T0005 | Done |
| T0007 | Créer le shell Tauri minimal et mesurer son empreinte | 1 | T0006 | Verify |
| T0008 | Créer le frontend React minimal | 1 | T0006–T0007 | Verify |
| T0009 | Créer le bridge .NET minimal | 1 | T0006 | Verify |
| T0010 | Établir le contrat local et le health check | 1 | T0007–T0009 | Done |
| T0011 | Créer l'adaptateur SimConnect et le replay | 1–3 | T0009–T0010 | Verify |
| T0012 | Créer Supabase local et les tests RLS | 1 | T0006 | Verify |
| T0013 | Consolider la CI multi-stack | 1 | T0006–T0012 | Done |
| T0014 | Valider le packaging Windows non signé | 1 | T0007–T0010, T0013 | Done |
| T0015 | Fixer les budgets stabilité et performance | 0–1 | T0007–T0011 | Done |
| T0016 | Corriger l’avis de sécurité React Router | 1 | T0013 | Done |
| T0017 | Définir et contrôler la politique de données | 0 | T0002–T0003, T0012 | Done |
| T0018 | Exporter puis supprimer un compte sans perte ni double opération | 2 | T0012, T0017, revue phase 1 | Verify |
| T0019 | Restaurer sans ressusciter un compte supprimé | 2 | T0017–T0018, T0013 | Verify |
| T0020 | Ouvrir un grand livre financier immuable | 2 | T0012, T0017–T0019 | Verify |

Les branches T0006 à T0008 sont présentes dans l'ascendance technique de T0009.
T0006 est `Done` depuis sa preuve clean-clone du 30 juillet 2026. T0007 et T0008
restent en vérification tant que leurs contrôles humains ne sont pas clos. T0009
reste aussi en vérification pour son smoke test interactif.
T0011 possède un replay synthétique automatisé et
reste en vérification jusqu'au test réel MSFS 2024. T0012 est fusionné dans
`main` par la PR #14 mais reste `Verify` pour la preuve loopback manquante.
T0016 a corrigé `KI-018` sans affaiblir le gate, puis les PR #16 et #15 ont
intégré T0016 et T0013 dans `main` avec tous les checks verts.
T0017 fixe la politique de données et son gate, fusionnés dans `main` par la
PR #24. Andy a validé sa clôture le 30 juillet 2026 ; aucune donnée réelle ni
capacité de suppression/restauration n'est revendiquée.

T0018 est le premier ticket détaillé de phase 2. Andy a validé le 31 juillet
2026 un délai récupérable de 7 jours, une session Supabase réauthentifiée depuis
5 minutes au plus et un export récupérable pendant le délai. PostgreSQL 17 CI
valide 4 fichiers/70 assertions, la concurrence et les types. Le ticket reste
`Verify` sur `security/T0018-account-lifecycle` car `KI-017` empêche encore sa
checklist manuelle Windows.

T0019 est empilé sur `security/T0018-account-lifecycle`. Il borne la preuve à
une sauvegarde synthétique restaurée dans une base PostgreSQL 17 distincte et au
replay des suppressions T0018 avant réouverture. Il ne provisionne aucun projet
distant, ne prouve aucune sauvegarde managée et n'autorise aucune donnée réelle.
Le run `30621209180` valide 6 fichiers/105 assertions, la concurrence, les types
et le dump/restore/replay ; le ticket reste `Verify` car `KI-017` bloque sa
checklist Windows.

T0020 est empilé sur `security/T0019-isolated-restore-replay`. Il borne la
première tranche économique à une ouverture de grand livre réservée au serveur,
à des écritures append-only et à une lecture propriétaire isolée. Il n'expose
aucune mutation économique au desktop et n'admet aucune donnée réelle. Le job
PostgreSQL 17 final `30628851680` valide 8 fichiers/148 assertions, la
concurrence, la restauration/replay et les types ; T0020 reste `Verify` car
`KI-017` bloque sa checklist Windows.

La dépendance T0014 est bornée aux implémentations desktop et bridge
T0007–T0010 présentes dans `main`, ainsi qu'à la CI T0013 terminée. Ses quatre
cycles manuels et ses preuves CI sont validés ; T0014 est `Done` depuis le
30 juillet 2026. Les vérifications encore ouvertes de T0007–T0009, les essais
MSFS de T0011 et le runtime Supabase de T0012 restent suivis séparément.
