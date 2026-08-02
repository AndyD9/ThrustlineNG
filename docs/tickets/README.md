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
| T0012 | Créer Supabase local et les tests RLS | 1 | T0006 | Done |
| T0013 | Consolider la CI multi-stack | 1 | T0006–T0012 | Done |
| T0014 | Valider le packaging Windows non signé | 1 | T0007–T0010, T0013 | Done |
| T0015 | Fixer les budgets stabilité et performance | 0–1 | T0007–T0011 | Done |
| T0016 | Corriger l’avis de sécurité React Router | 1 | T0013 | Done |
| T0017 | Définir et contrôler la politique de données | 0 | T0002–T0003, T0012 | Done |
| T0018 | Exporter puis supprimer un compte sans perte ni double opération | 2 | T0012, T0017, revue phase 1 | Done |
| T0019 | Restaurer sans ressusciter un compte supprimé | 2 | T0017–T0018, T0013 | Done |
| T0020 | Ouvrir un grand livre financier immuable | 2 | T0012, T0017–T0019 | Done |
| T0021 | Isoler Supabase local sur Windows | 1–2 | T0012, T0018–T0020 | Done |
| T0022 | Créer une compagnie et ouvrir son grand livre atomiquement | 2 | T0018, T0020–T0021 | Done |
| T0023 | Exposer l’onboarding derrière une frontière serveur authentifiée | 2 | T0022 | Done |
| T0024 | Inventorier les mutations sensibles du golden path | 2 | T0018–T0020, T0022–T0023 | Done |
| T0025 | Synchroniser la roadmap avec l'état prouvé | 1–2 | T0012, T0021, T0024 | Done |
| T0026 | Réconcilier la livraison de T0010 | 1 | T0010 | Done |
| T0027 | Encadrer l'orchestration multitâche des agents | Gouvernance | T0026 | Review |
| T0028 | Fixer la politique économique d'ouverture de production | 2 | T0020, T0022–T0023, décision Andy | Draft |

Les branches T0006 à T0008 sont présentes dans l'ascendance technique de T0009.
T0006 est `Done` depuis sa preuve clean-clone du 30 juillet 2026. T0007 et T0008
restent en vérification tant que leurs contrôles humains ne sont pas clos. T0009
reste aussi en vérification pour son smoke test interactif.
T0011 possède un replay synthétique automatisé et
reste en vérification jusqu'au test réel MSFS 2024. T0012 est `Done` depuis que
T0021, sa preuve loopback et l'inspection visuelle de Studio sont fusionnés dans
`main` par la PR #41.
T0016 a corrigé `KI-018` sans affaiblir le gate, puis les PR #16 et #15 ont
intégré T0016 et T0013 dans `main` avec tous les checks verts.
T0017 fixe la politique de données et son gate, fusionnés dans `main` par la
PR #24. Andy a validé sa clôture le 30 juillet 2026 ; aucune donnée réelle ni
capacité de suppression/restauration n'est revendiquée.

T0018 est le premier ticket détaillé de phase 2. Andy a validé le 31 juillet
2026 un délai récupérable de 7 jours, une session Supabase réauthentifiée depuis
5 minutes au plus et un export récupérable pendant le délai. PostgreSQL 17 CI
valide 4 fichiers/70 assertions, la concurrence et les types. Le 1er août, la
checklist Windows loopback confirme demande, rejeu après réponse perdue,
isolation B/anonyme, annulation, expiration, rollback injecté et finalisation ;
T0018 est `Done`. Aucune donnée réelle n'a été admise.

T0019 a d'abord été empilé sur `security/T0018-account-lifecycle`, puis livré
dans `main` par la PR #41. Il borne la preuve à une sauvegarde synthétique
restaurée dans une base PostgreSQL 17 distincte et au replay des suppressions
T0018 avant réouverture. Il ne provisionne aucun projet distant, ne prouve aucune
sauvegarde managée et n'autorise aucune donnée réelle.
Le run `30621209180` valide 6 fichiers/105 assertions, la concurrence, les types
et le dump/restore/replay. Le 1er août, la checklist Windows confirme dump,
restauration hors API, replay idempotent, refus altéré/inconnu, absence de
résurrection et nettoyage ; T0019 est `Done`.

T0020 a d'abord été empilé sur T0019, puis livré dans `main` par la PR #41. Il
borne la première tranche économique à une ouverture de grand livre réservée au
serveur, à des écritures append-only et à une lecture propriétaire isolée. Il
n'expose aucune mutation économique au desktop et n'admet aucune donnée réelle.
Le job PostgreSQL 17 final `30628851680` valide 8 fichiers/148 assertions, la
concurrence, la restauration/replay et les types. Le 1er août, la checklist
Windows confirme ouverture/rejeu, refus collision/deuxième ouverture, isolation,
append-only, blocage pendant suppression et anonymisation sans réécriture ;
T0020 est `Done`.

T0021 résout `KI-017` sans
modifier Docker Desktop globalement : la pile est confinée dans un daemon
Docker dédié et seuls ses trois ports utiles sont republiés explicitement sur
`127.0.0.1`. Le diagnostic Windows du 31 juillet 2026 confirme que l'option
loopback du réseau et l'option daemon sont ignorées par Docker Desktop 29.6.2
lorsque la CLI Supabase transmet un `HostIp` vide. Docker et les sockets Windows
confirment les trois liaisons `127.0.0.1`; 8 fichiers/148 assertions et les types
passent localement. Andy confirme l'inspection visuelle de Studio le 31 juillet
2026. La PR #41 livre la pile dans `main`; T0021 est `Done`.

T0022 retire les mutations directes de compagnie accordées
aux rôles clients et assemble création solo et ouverture financière dans une
commande `service_role` transactionnelle et idempotente. Deux resets, 10 fichiers/190
assertions, les types, la concurrence et la checklist manuelle passent
localement ; les runs GitHub `30652926904` et `30652926644` sont verts. La PR
#41 livre T0022 dans `main`; le ticket est `Done`.

T0023 ajoute une Edge Function qui vérifie la session
auprès de Supabase Auth, dérive le propriétaire du JWT, refuse tout montant,
devise ou propriétaire client et lit la politique d'ouverture dans son
environnement serveur. Quatorze tests Node, le gate backend avec 11 mutations, deux
resets, 10 fichiers/190 assertions, les types et une intégration Auth → Edge →
RPC passent localement. Le rejeu conserve les mêmes identifiants et l'état SQL
est `1|1|1`; un appel sans JWT rend HTTP 401. La revue adversariale corrige la
minimisation de la réponse privilégiée dans `aa4d0a2`. Les PR #38–#40 propagent
la correction dans T0020, puis la PR #41 livre T0023 dans `main`; le ticket est
`Done`.

T0024 inventorie les dix étapes du golden path dans 13 domaines et scanne les
trois surfaces clientes actives. Quatre domaines implémentés restent
partiellement autoritaires côté serveur, Supabase Auth est externe et huit
domaines sont explicitement absents. Le gate passe avec cinq mutations
négatives et ne trouve aucune mutation métier dans React, Tauri ou le bridge ;
`KI-001` est résolu et la PR #46 livre T0024 dans `main`, sans présenter les
capacités futures comme livrées.

T0025 synchronise la roadmap après les PR #41 et #46 : T0012 et T0024 y sont
désormais correctement livrés et `Done`, tandis que T0007–T0009 et T0011 restent
ouverts. Les Completion Reports et la revue de phase datée restent inchangés ;
`KI-006` est résolu sans modifier une priorité produit ou un gate.

T0026 réconcilie l'écart de livraison T0010 sans réécrire son rapport historique.
La PR #7 avait ciblé une branche déjà intégrée ; la PR #10 a ensuite fusionné
les commits T0010 `22f97d4` et `41cc940` dans `main` via `26cbcbf`. Les tests
d'ascendance et les validations bridge/desktop repassent ; `KI-016` est résolu.

T0027 définit une orchestration multitâche contrôlée : un coordinateur reste
responsable de chaque ticket, la lecture parallèle est privilégiée, les écritures
dans un worktree partagé exigent des chemins disjoints et plusieurs tickets ne
peuvent avancer simultanément que dans des worktrees et branches distincts. La
branche est empilée sur T0026 jusqu'à la livraison de ce dernier dans `main`.

T0028 cadre la politique d'ouverture économique unique des nouvelles compagnies
MVP. Il reste `Draft` tant qu'Andy n'a pas confirmé le montant et la devise ; la
fixture locale `43000000`/`EUR` ne constitue pas une décision implicite.

La dépendance T0014 est bornée aux implémentations desktop et bridge
T0007–T0010 présentes dans `main`, ainsi qu'à la CI T0013 terminée. Ses quatre
cycles manuels et ses preuves CI sont validés ; T0014 est `Done` depuis le
30 juillet 2026. Les vérifications encore ouvertes de T0007–T0009, les essais
MSFS de T0011 restent suivis séparément.
