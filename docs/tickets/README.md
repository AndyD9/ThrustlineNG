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
| T0027 | Encadrer l'orchestration multitâche des agents | Gouvernance | T0026 | Done |
| T0028 | Fixer la politique économique d'ouverture de production | 2 | T0020, T0022–T0023, décision Andy | Done |
| T0029 | Acquérir un premier avion sans double débit ni propriété partielle | 2 | T0020, T0022–T0024, T0028, décision Andy | Done |
| T0030 | Empêcher les dettes techniques silencieuses | Gouvernance | T0027–T0028 | Done |
| T0031 | Réconcilier l'index après les fusions T0029–T0030 | Gouvernance | T0029–T0030 | Done |
| T0032 | Louer un avion sans double prélèvement ni usage hors contrat | 2 | T0020, T0022–T0024, T0028–T0029, décisions Andy | Draft |
| T0033 | Réconcilier les livraisons récentes et le README | Gouvernance | T0027–T0032 | Done |
| T0034 | Découpler la fixture du gate de maintenance | Gouvernance | T0030, T0033 | Done |
| T0035 | Exposer l'achat d'avion derrière une frontière serveur authentifiée | 2 | T0023–T0024, T0029, T0034 | Done |
| T0036 | Valider l'achat d'avion sur le runtime local réel | 2 | T0021, T0023, T0029, T0035 | Done |
| T0037 | Consommer l'achat d'avion depuis le desktop sans autorité client | 2–4 | T0024, T0029, T0035–T0036 | Done |
| T0038 | Fonder la configuration et la session authentifiée du desktop | 2–4 | T0021, T0024, T0035–T0037 | Done |
| T0039 | Acquérir une session locale par email et mot de passe | 4 | T0021, T0024, T0038, décision Andy | Done |
| T0040 | Activer et valider Auth locale email/mot de passe | 4 | T0021, T0038–T0039 | Review |
| T0041 | Rendre la connexion locale accessible par une route bornée | 4 | T0038–T0040 | Review |

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
PR #51 livre ces règles dans `main`; T0027 est `Done`.

T0028 cadre la politique d'ouverture économique unique des nouvelles compagnies
MVP. Andy confirme le 2 août 2026 une ouverture de 430 000 EUR ; la même valeur
utilisée auparavant comme fixture locale ne constitue pas une preuve de
production rétroactive. La source canonique, le handler et les gates sont
livrés dans `main` par la PR #54 ; T0028 est `Done`.

T0029 cadre la première acquisition d'avion autoritaire. Andy confirme le
2 août 2026 achat puis location : T0029 traite l'achat atomique ; la location,
ses contrats, paiements temporels et résiliation restent un ticket distinct.
Deux resets, 12 fichiers/234 assertions, types, gates et deux courses PostgreSQL
locales passent ; CI `30740977879` et supply-chain `30740977888` sont vertes sur
le commit d'implémentation. La chaîne de fusions empilées est désormais dans
`main`; T0029 est `Done`, sans endpoint applicatif ni environnement distant.

T0030 automatise l'intégrité du registre de maintenance, la cohérence entre
statuts des tickets et index, ainsi que la traçabilité des marqueurs de dette
dans le code. Le gate et ses huit mutations sont dans `main`; T0030 est `Done`,
sans correction opportuniste d'une dette produit. KI-022 suit encore le
découplage de sa fixture d'auto-test, découvert par T0033.

T0031 a restauré l'entrée T0030 perdue pendant les fusions croisées et son
résultat est livré dans `main`. T0031 est `Done`.

T0032 cadre la location d'avion confirmée après l'achat T0029. Il reste `Draft`
jusqu'à décision explicite d'Andy sur durée, cadence, montants, grâce, défaut,
résiliation, fin d'usage et autorité temporelle. Aucune migration ni politique
économique n'est inventée avant ce passage en `Ready`. Son cadrage est présent
dans `main` depuis la PR #59, sans migration ni capacité de location.

T0033 réconcilie les livraisons T0027–T0031, l'état courant et le README. Il ne
modifie aucune capacité produit et conserve T0032 en attente des décisions
économiques et temporelles d'Andy. La PR #60 est fusionnée dans `main`; T0033
est `Done` et T0034 traite séparément la fixture résiduelle KI-022.

T0034 découple l'auto-test du gate de maintenance des entrées réelles du
registre et rend ses assertions négatives explicites. La PR #61 est fusionnée
dans `main` avec ses trois checks verts ; le ticket est `Done` sans changer de
règle de maintenance ni de capacité produit.

T0035 expose l'achat autoritaire T0029 derrière une Edge Function qui vérifie
la session auprès de Supabase Auth, dérive le propriétaire du JWT et limite le
payload client à l'offre et à l'idempotence. La PR #62 est fusionnée dans
`main` au commit `76a47c9` avec ses trois checks verts ; le ticket est `Done`
sans consommation desktop, location ni déploiement distant.

T0036 valide cette fonction dans l'Edge Runtime local réel, avec une
identité, une session, une compagnie et un achat exclusivement synthétiques. Il
confirme Auth, rejeu, état SQL et nettoyage sans modifier le contrat, la
transaction ni une cible distante. La PR #63 est fusionnée dans `main`; T0036
est `Done`.

T0037 ajoute la commande et l'état UI desktop bornés pour cette Edge Function.
Il ne crée ni authentification, ni catalogue, ni cible distante et reçoit la
session ainsi que l'offre de futurs appelants. Ses 38 tests frontend, sa
couverture, son build et les gates d'autorité, données et maintenance passent ;
la PR #64 est fusionnée dans `main` au commit `47cd50c` avec ses trois checks
verts et le ticket est `Done`.

T0038 borne la configuration desktop aux deux paramètres publics de Supabase
local et ajoute un cycle de session en mémoire avec refresh convergent. La CSP
de développement n'ajoute que l'API loopback ; production, login, persistance,
staging et appel live restent fermés. La PR #65 est fusionnée dans `main` au
commit `e88bdef` avec ses trois checks verts ; le ticket est `Done`.

T0039 retient la décision d'Andy du 2 août 2026 : première acquisition de
session par email et mot de passe sur Supabase local, strictement en mémoire.
La persistance Windows, OAuth, inscription, récupération de mot de passe, cible
distante et données réelles restent exclues. La PR #66 est fusionnée dans
`main` au commit `47c8f341` avec Windows, PostgreSQL 17 et supply-chain verts ;
T0039 est `Done`.

T0040 corrige l'écart entre cette commande et la configuration locale qui
désactivait le provider email. Après fusion de T0039, sa branche est rebasée sur
`main` : inscription globale fermée, identité `.invalid` provisionnée par
l'Admin API locale, test runtime et destruction sans backup. Sa branche ne doit
pas être présentée comme livrée dans
`main` tant que T0040 n'est pas fusionné. Deux scénarios runtime
passent et le redémarrage confirme zéro identité T0040. La PR #67 est ouverte
prête vers `main`; le ticket est `Review`.

T0041 compose la configuration et le gestionnaire de session existants avec une
route `/login`, une garde d'accueil et une déconnexion exclusivement en mémoire.
Ses 80 tests frontend, sa couverture, son build et les gates autorité, données
et maintenance passent localement. La branche est empilée sur T0040/PR #67 :
elle reste `Review`, ne cible pas encore `main` indépendamment et ne revendique
ni login WebView live, persistance, onboarding, catalogue ou achat composé.

La dépendance T0014 est bornée aux implémentations desktop et bridge
T0007–T0010 présentes dans `main`, ainsi qu'à la CI T0013 terminée. Ses quatre
cycles manuels et ses preuves CI sont validés ; T0014 est `Done` depuis le
30 juillet 2026. Les vérifications encore ouvertes de T0007–T0009, les essais
MSFS de T0011 restent suivis séparément.
