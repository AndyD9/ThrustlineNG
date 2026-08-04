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
| T0009 | Créer le bridge .NET minimal | 1 | T0006 | Done |
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
| T0040 | Activer et valider Auth locale email/mot de passe | 4 | T0021, T0038–T0039 | Done |
| T0041 | Rendre la connexion locale accessible par une route bornée | 4 | T0038–T0040 | Done |
| T0042 | Composer l'onboarding de compagnie depuis le desktop | 4 | T0022–T0023, T0038–T0041 | Done |
| T0043 | Lire le catalogue d'avions depuis le desktop | 4 | T0029, T0037–T0042 | Done |
| T0044 | Lire l’état de compagnie depuis le desktop | 4 | T0012, T0022, T0042–T0043 | Done |
| T0045 | Composer le catalogue avec l’achat desktop | 4 | T0037–T0038, T0043–T0044 | Done |
| T0046 | Lire et actualiser la flotte depuis le desktop | 4 | T0029, T0038, T0044–T0045 | Done |
| T0047 | Créer un brouillon de dispatch autoritaire et idempotent | 2–4 | T0012, T0018, T0024, T0029, T0046 | Done |
| T0048 | Exposer le brouillon de dispatch derrière une frontière authentifiée | 2–4 | T0023, T0024, T0047 | Done |
| T0049 | Valider le brouillon de dispatch sur le runtime local réel | 2 | T0021, T0036, T0040, T0047–T0048 | Done |
| T0050 | Démarrer un vol autoritaire depuis un brouillon de dispatch | 2 | T0018, T0020, T0024, T0029, T0047–T0048 | Done |
| T0051 | Clôturer un vol une seule fois, régler son revenu et sa réputation | 2 | T0020, T0028–T0029, T0047, T0050, T0057 | Draft |
| T0052 | Composer la préparation de dispatch depuis le desktop | 2–4 | T0038, T0041, T0044, T0046, T0048 | Done |
| T0053 | Lire et actualiser les dispatchs depuis le desktop | 4 | T0038, T0044, T0046–T0047, T0052 | Review |
| T0054 | Publier la télémétrie bornée du bridge sur le contrat local | 3 | T0010–T0011, T0015 | Review |
| T0055 | Fixer la source canonique de version produit et livrer l'alpha technique interne | 1–6 | T0006, T0014–T0015, T0043–T0048 | Ready |
| T0056 | Clôturer les vérifications interactives T0007 à T0009 | 1 | T0007–T0009, T0015, décision Andy | Ready |
| T0057 | Créer un référentiel d'aérodromes borné et autoritaire | 2 | T0024, T0047–T0048, décision Andy | Done |
| T0058 | Borner les avis Cargo informatifs par un gate déterministe | Gouvernance | T0013, T0016, T0030 | Done |

## Vague de tickets vers l'alpha interne

T0049 à T0057 constituent la vague détaillée suivante, ordonnée par les trois flux
du mode accéléré de `docs/ROADMAP.md`. Chaque flux ne porte qu'un ticket
`In progress` à la fois, dans un worktree distinct, et chaque branche part du
dernier `origin/main` en ciblant `main`.

- flux moteur de vol et bridge : T0054, puis la détection déterministe des phases
  et la reprise, encore au niveau roadmap ;
- flux backend du golden path : T0049, T0050 et T0057, puis T0051 ;
- flux desktop et parcours E2E : T0052 puis T0053 ;
- transverses au jalon d'alpha technique : T0055 et T0056.

Andy a tranché le 3 août 2026 les sept décisions de clôture de vol : revenu net
unique dérivé du temps, de la distance et de la popularité des aérodromes, en
`EUR`, avec un plancher pour un vol interrompu, un avion immédiatement
redisponible et une réputation informative bornée. T0057 devient donc le prérequis
technique de T0051, puisque distance et popularité exigent un référentiel
d'aérodromes autoritaire.

T0051 et T0053 restent `Draft` uniquement pour l'ordre d'intégration : T0051 attend
la fusion de T0050 et T0057, T0053 celle de T0052, afin de ne pas rouvrir une pile
de branches. Ces conditions sont désormais toutes satisfaites : T0050 est dans
`main` depuis la PR #89, T0057 depuis la fusion de la PR #91 le 3 août 2026 au
merge `df685b7`, et T0052 depuis la PR #94 le 4 août 2026 ; le passage de T0051 et
de T0053 à `Ready` appartient à leurs propres changements. La location T0032 reste
hors du gate de l'alpha et conserve son statut `Draft`. T0011 reste `Verify`
jusqu'aux essais MSFS 2024 réels et n'est pas couvert par T0056.

Les branches T0006 à T0008 sont présentes dans l'ascendance technique de T0009.
T0006 est `Done` depuis sa preuve clean-clone du 30 juillet 2026. T0007 et T0008
restent en vérification tant que leurs contrôles humains ne sont pas clos. T0009
est `Done` depuis le smoke test console Windows du 3 août 2026 : état prêt,
annulation console, sortie `0` et aucun processus restant.
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
désactivait le provider email : inscription globale fermée, identité `.invalid`
provisionnée par l'Admin API locale, test runtime et destruction sans backup.
Deux scénarios runtime passent et le redémarrage confirme zéro identité T0040.
La PR #67 est fusionnée dans `main` au commit `471c7c1` avec Windows,
PostgreSQL 17 et supply-chain verts ; le ticket est `Done`.

T0041 compose la configuration et le gestionnaire de session existants avec une
route `/login`, une garde d'accueil et une déconnexion exclusivement en mémoire.
Ses 80 tests frontend, sa couverture, son build et les gates autorité, données
et maintenance passent localement. La PR #68 a été fusionnée dans l'ancienne
branche T0040 après la fusion de #67 vers `main` : son état `MERGED` ne livre
donc pas les commits T0041 dans la branche par défaut. La PR corrective #69 est
ensuite fusionnée dans `main` au commit `cb179e9` avec ses trois checks verts ;
T0041 est `Done` et ne revendique ni
login WebView live, persistance, onboarding, catalogue ou achat composé.

T0042 compose l'Edge Function d'onboarding T0023 depuis l'accueil authentifié,
avec une intention idempotente, un payload fermé et le bearer obtenu à la
soumission depuis le gestionnaire T0038. Ses 104 tests frontend, couverture,
build et gates passent localement. La PR #70 a été fusionnée avec ses trois
checks verts dans la branche T0041 après son intégration à `main`; la PR
corrective #73 livre finalement T0042 dans `main` au commit `a4047a5` avec ses
trois checks verts. T0042 est `Done` et exclut persistance, catalogue, achat et
backend.

T0043 ajoute une lecture Data API locale explicitement allowlistée des offres
`available`, limitée à vingt lignes et 32 Kio, ainsi qu'un panneau injecté sans
réseau au rendu. Ses 125 tests frontend, couverture, build et gates passent
localement ; le gate d'autorité couvre désormais huit mutations négatives. La
PR #72 a fusionné dans la branche T0042, puis la PR corrective #79 a livré
T0043 dans `main` au commit `6c232c6` avec ses trois checks verts. T0043 est
`Done` sans composer achat, flotte ou cible distante.

T0044 ajoute au-dessus de T0043 une lecture Data API locale de la présence de
compagnie, projetée sur `id`, bornée à deux lignes puis réduite à un booléen.
L'accueil ne charge rien au rendu et aiguille explicitement une session vers
l'onboarding ou le catalogue ; une création réussie bascule vers le catalogue.
Les 146 tests frontend, la couverture, le build et les gates passent localement.
La PR #74 a fusionné dans T0043 avant la PR corrective #79, qui a donc livré
T0044 dans `main` au commit `6c232c6` avec ses trois checks verts. T0044 est
`Done`, sans achat composé, WebView live, cible distante ou donnée réelle.

T0045 compose la sélection d'une offre T0043 avec la
commande d'achat T0037 derrière l'aiguillage T0044. Le bearer est acquis au clic
depuis le gestionnaire de session, la sélection reste limitée au catalogue
validé et aucun prix, propriétaire ou solde n'est envoyé comme autorité. Ses 149
tests frontend exécutés, sa couverture, son build et ses gates passent
localement. T0046 ajoute la lecture et l'actualisation de la flotte propriétaire.
Les deux tickets sont `Done` : la PR corrective #83 a livré leurs commits
`34f96bb` et `ad46315` dans `main` au merge `d117690`, avec les trois checks
verts. WebView live, cible distante et donnée réelle restent hors preuve.

T0047 ajoute sur T0046 un brouillon de dispatch serveur minimal pour un avion
possédé et deux ICAO distincts. La compagnie, l'état et le temps restent
serveur ; rejeu, isolation A/B, exclusivité et concurrence sont prouvés sur
PostgreSQL 17 avec 14 fichiers/270 assertions. Le ticket est `Done` et son
commit `0559a8e` est livré dans `main` par la PR #83, sans endpoint Auth,
desktop, SimBrief, cycle de vol ou cible distante au-delà de son périmètre.

T0048 ajoute sur T0047 une Edge Function `dispatch-draft` bornée à 4 Kio. Elle
vérifie une session Auth non anonyme, dérive le propriétaire, normalise les ICAO
et appelle la RPC T0047 avec le credential serveur, puis projette uniquement la
réponse publique versionnée. Les 46 tests de fonctions et les gates applicables
passent. Le ticket est `Done` et son commit `175203c` est livré dans `main` par
la PR #83, sans desktop, Edge Runtime live, SimBrief, cycle de vol ou cible
distante au-delà de son périmètre.

T0049 charge enfin cette frontière dans l'Edge Runtime local réel. Le 3 août
2026, 48 contrôles passent sans échec : chaînage Auth → Edge → RPC, sept champs
publics avec `no-store`, rejeu convergent, refus sans bearer, champ interdit,
ICAO malformés ou identiques, avion d'un autre propriétaire, avion inconnu,
deuxième brouillon, état final `1|1|1|1` et bindings loopback inchangés. Le
ticket n'ajoute aucune capacité produit : ni migration, ni handler, ni desktop,
ni cible distante. La PR #87 est fusionnée dans `main` au merge `00ec05d` avec
ses trois checks verts sur le commit `2685a2a`; T0049 est `Done`. Le commit
`7e9a76d`, poussé après la fusion, est propagé séparément par
`docs/T0049-record-merge`. Le nettoyage réel vient de la destruction de la pile jetable, parce que
`companies_owner_id_fkey` refuse volontairement d'orphaner une compagnie en
supprimant son propriétaire par l'Admin API.

T0050 ajoute au-dessus de T0049 le démarrage serveur d'un vol depuis un
brouillon possédé. Une huitième migration append-only ouvre une liste fermée de
deux états, ajoute un horodatage de départ dérivé de PostgreSQL et réserve
`start_flight_from_dispatch` à `service_role`. Compagnie, avion, état et temps
restent serveur ; rejeu, collision, dispatch étranger, dispatch déjà actif,
compte en suppression, rollback injecté et concurrence sont prouvés sur
PostgreSQL 17 avec 16 fichiers/312 assertions, et la vérification manuelle
confirme un vol actif unique sans écriture financière. T0050 est `Done` : son
commit `3e798db` est livré dans `main` par la PR #89 au merge `6577125`, et le
job Linux `Supabase PostgreSQL 17` y passe avec 16 fichiers pgTAP, `Result: PASS`
et `Flight start concurrency passed: 2 sessions, 1 active flight, 1 command,
1 server time`. Le ticket n'ajoute ni frontière Auth, endpoint, desktop,
SimBrief, télémétrie, clôture ni cible distante.

La fusion de T0050 a rejoué la dérive d'index déjà connue : le merge `09565ee`
de `main` dans la branche a résolu le conflit de cette table en écartant la PR
#88, ramenant la ligne T0049 à `Review` alors que son fichier restait `Done`, ce
qui a laissé `pnpm maintenance:check` et le job `Windows multi-stack` rouges sur
`main` au commit `6577125`. Aucune autre ligne de la PR #88 n'est perdue. Cette
entrée restaure la ligne T0049 à `Done` et consigne la clôture de T0050 ; aucun
statut substantiel n'est inventé.

T0049 réconcilie aussi l'index avec les fichiers de tickets : la fusion #86 avait
ramené les six lignes T0043–T0048 à `Review` alors que leurs fichiers étaient
déjà `Done`, ce qui laissait `pnpm maintenance:check` rouge sur `main`. Les
statuts substantiels ne changent pas ; seule la table revient à l'état déjà
prouvé par la PR #85.

La dépendance T0014 est bornée aux implémentations desktop et bridge
T0007–T0010 présentes dans `main`, ainsi qu'à la CI T0013 terminée. Ses quatre
cycles manuels et ses preuves CI sont validés ; T0014 est `Done` depuis le
30 juillet 2026. Les vérifications encore ouvertes de T0007–T0008 et les essais
MSFS de T0011 restent suivis séparément.
