# Fonctionnalités

Créer un fichier par fonctionnalité à partir de `docs/templates/FEATURE.md`.

## Convention

- Nom : `F0001-acheter-un-avion.md`
- Une fonctionnalité = **une capacité utilisateur, une branche, une Pull Request**.
- Le travail se découpe en **jalons** internes ordonnés, un commit par jalon, pas
  en fichiers de suivi séparés.
- Le statut et le Completion Report restent dans le fichier de la fonctionnalité.
- Le champ `Status` du fichier est la référence ; cette table doit refléter le même
  statut. Le sélecteur échoue fermé sur toute divergence.
- Au plus **deux** fonctionnalités `In progress` simultanément, chacune dans son
  worktree et sa branche.
- Une fonctionnalité terminée est conservée pour la traçabilité.

## Pourquoi ce format

`docs/tickets/` découpait une capacité en 4 à 6 tickets — migration, RPC, frontière
authentifiée, validation runtime, composition desktop — donc autant de branches, de
Pull Requests, de bases à choisir et de lignes d'index à tenir cohérentes. Le coût
mesuré le 5 août 2026 : 63 tickets pour 19 296 lignes, un index de 439 lignes,
113 merges, 4 tickets de réconciliation d'index sans capacité produit, 4 PR
correctives et 5 fusions hors de `main`.

Andy a tranché le 5 août 2026 : l'unité de suivi et d'intégration devient la
fonctionnalité. T0068 porte ce changement et `docs/tickets/README.md` est l'archive
gelée du format précédent.

## Fonctionnalités

| ID | Titre | Phase | Dépend de | Statut |
| --- | --- | --- | --- | --- |
| F0001 | Faire décoller un vol préparé depuis l'application | 2–4 | T0050, T0048, T0052–T0053, T0065 fusionné | Done |
| F0002 | Clôturer son vol et encaisser son revenu depuis l'application | 2–4 | T0051, T0057, F0001 fusionnée, F0004 fusionnée | Done |
| F0003 | Trouver SimConnect nous-mêmes, ou le dire proprement | 3 | T0011, T0054, ADR-0003, ADR-0004, EULA du SDK lue le 7 août 2026 | Done |
| F0004 | Voir le temps de bloc mesuré de son vol en replay | 3–4 | T0054, T0010, F0001 fusionnée, décision Andy prise le 6 août 2026 | Done |
| F0005 | Rendre l'alpha installée cliquable | 4 | T0014, T0038, T0055, décision Andy prise le 6 août 2026, vérification humaine J2 | Done |
| F0006 | Rattacher la mesure de vol à son dispatch et la réarmer entre deux vols | 3–4 | F0004 fusionnée, décisions Andy des 7 août 2026 (KI-028, « go 1 ») | Done |
| F0007 | Finir son vol dans l'alpha, et dire honnêtement pourquoi elle ne mesure pas | 3–4 | F0004, F0006 et F0003 J1 fusionnées, décisions d'Andy prises le 7 août 2026 (option C, chemin d'abandon) | Ready |

Les deux premières fonctionnalités ouvrent le format sur ce qui restait du golden
path : `start_flight_from_dispatch` et `close_flight` sont livrées dans `main` depuis
T0050 et T0051, mais ce sont les deux seules commandes du golden path sans frontière
authentifiée ni appelant. Chacune est donc un slice vertical de trois jalons —
frontière Edge, validation sur l'Edge Runtime local réel, composition desktop — au
lieu des quatre à six tickets que le format précédent aurait produits.

F0001 est `Done` et **livrée dans `main`** (PR #124 et #126, fusionnées le
6 août 2026) : trois jalons revus adversarialement — frontière Edge, preuve sur
l'Edge Runtime local réel, composition desktop — et le premier parcours WebView
live du projet, vérifié par Andy. F0002 est `Done` et **livrée dans `main`**
(PR #131, fusionnée par Andy le 7 août 2026, avant F0006) : frontière Edge
`flight-close` strictement allowlistée, preuve de 56 contrôles sur l'Edge
Runtime local réel, et clôture desktop qui consomme le résumé mesuré F0004
(option C du 6 août 2026 : le temps de bloc vient de la télémétrie, jamais
d'une saisie). F0004 est `Done` et **livrée dans `main`** (PR #128 et #130,
fusionnées le 7 août 2026) — mesure « mouvement → sol », arrondie à la minute
supérieure, minimum une minute : le bridge mesure et expose
`GET /api/v1/flight-summary` derrière le jeton du contrat local (J1), l'unique
commande Tauri `flight_summary` relaie le résumé revalidé à la WebView sans
exposer jeton ni port (J2), et l'application affiche le temps de bloc, sur
action explicite et sans calcul côté WebView (J3) ; parcours manuel exécuté et
constats de revue corrigés avant fusion. Sa revue a laissé deux dettes : KI-027
(l'application intégrée ne produit pas de mesure seule) et KI-028, dont les
prérequis de F0002 — rattachement résumé ↔ vol et tracker réarmable — sont
portés par **F0006**, ouverte sur la décision de séquencement d'Andy du 7 août
2026 (« go 1 ») ; F0002 ayant finalement été fusionnée la première, le
branchement de sa clôture sur la mesure rattachée est porté par F0006.

F0006 est `Done` et **livrée dans `main`** (PR #132, fusionnée le 7 août
2026) : ses trois jalons sont `Done` — le bridge mesure par générations
réarmables, Tauri rattache la génération armée au dispatch sans exposer ni
jeton ni génération, l'application arme au départ et échoue fermé sur toute
mesure non rattachée — plus le branchement de la clôture F0002 absorbé après la
fusion de la PR #131. Le parcours manuel deux-vols-d'affilée, dernière chose
ouverte de son compte rendu, a été exécuté le 7 août 2026 sur le harnais
replay d'un build dev (deux vols dans la même session, générations 2 et 3,
chaque mesure attribuée à la ligne de son vol, clôture du premier vol au
passage) — résultat consigné dans le Completion Report de son J3. KI-028 est
`Resolved` dans `docs/KNOWN_ISSUES.md` depuis la PR #136 (fusionnée le 7 août
2026), qui a appris au gate de maintenance les références `FXXXX` sur décision
d'Andy.

F0005 est `Done` sur la
seconde décision du même jour : le canal `internal-alpha` reçoit une CSP
limitée à `http://127.0.0.1:54321` pendant que le canal public garde
`connect-src 'none'`. Son J1 est **livré dans `main`** (PR #133 et #134,
fusionnées le 7 août 2026) — surcouche de canal, garde d'allowlist dans le
script de packaging, CSP inscrite au manifeste, mutations négatives, et un
contrôle qui relit la CSP réellement embarquée dans l'exécutable produit. Son
J2 est exécuté le 7 août 2026 sur instruction du passage de relais d'Andy : le
package `internal-alpha` construit localement s'installe, déroule le golden
path jusqu'au départ sur la pile locale (piloté par CDP, aucune requête hors
loopback) et se désinstalle sans résidu — ce qui clôt T0055. Le parcours
s'arrête au départ : mesure et clôture dans l'application installée relèvent
de KI-027, porté par F0007.

F0007 est `Ready` depuis le 7 août 2026, et elle a **changé de sujet ce jour-là**.
Elle portait **KI-027** — l'application intégrée ne produit pas de temps de bloc
par elle-même — et visait « mesurer un vol sans harnais externe ». Andy a tranché
sa décision bloquante, l'origine de la trace de l'alpha : **option C, pas de trace
du tout**. Les options écartées étaient la trace dorée embarquée (l'alpha aurait
toujours mesuré le même vol synthétique) et la trace choisie par la personne (une
frontière d'entrée utilisateur vers le bridge et un accès au système de fichiers
que le shell n'a pas). La mesure arrive donc avec MSFS réel, T0059 et F0003 J3, et
KI-027 passe `Accepted` : un état produit assumé, pas un défaut à corriger.

Ce choix a révélé une conséquence dure, constatée dans le code avant d'être
consignée : sans mesure, `FlightCloseControl` échoue fermé et affiche « terminez le
replay puis réessayez » — un conseil impossible dans une version sans replay — en
laissant le dispatch « En vol » sans aucune sortie. **L'alpha aurait été cliquable
jusqu'au départ, et bloquée là.** Andy a donc tranché la suite le même jour :
l'application gagne un chemin d'**abandon** de vol. Il ne coûte ni fonction Edge ni
migration — `outcome: "interrupted"` avec `blockMinutes: 0`, le plancher de
règlement et le delta de réputation existent déjà côté serveur et base — et il
n'invente aucun temps de bloc, donc la décision du 6 août 2026 tient.

F0007 livre maintenant trois choses : la barrière du premier abonné retirée du
chemin de mesure (elle bloquerait T0059 à l'identique, donc elle se corrige
maintenant qu'elle est prouvable au harnais) ; une application qui dit ce qu'elle
sait mesurer — ce qui absorbe la **moitié desktop de F0003 J2**, même surface
superviseur ↔ WebView ; et un golden path installé qui se termine. L'identifiant,
le nom de fichier et la branche ne changent pas, pour ne casser aucune référence.

F0003 sort d'une question d'Andy du 5 août 2026 — « il faut qu'on le trouve nous-même,
dans l'hypothèse où la personne n'a rien de tout ça » — et d'un relevé qui lui donne
raison plus durement que prévu : le bridge chargeait `SimConnect.dll` par
`DllImportSearchPath.SafeDirectories`, qui ne regarde ni le `PATH` ni un chemin
d'installation du SDK, si bien que le chargement échouait **même sur la machine de
validation**, où MSFS 2024 et le SDK `1.5.7` sont pourtant installés. Elle est
`In progress` depuis le 7 août 2026 : son J1 est `Done` — sonde à liste
ordonnée et fermée (chemin explicite, répertoire de l'application, installation
du SDK déclarée par le système), chargement par chemin absolu, état
`unavailable` dès le démarrage sans bibliothèque, 44 tests bridge et
vérification manuelle sur le bridge publié (KI-031 résolue). Son J2 est `Done`
sur son périmètre restant : la moitié bridge est livrée (champs de santé
additifs), et sa moitié desktop est **portée dans F0007** sur décision d'Andy du
7 août 2026 — l'affichage « télémétrie indisponible » exige
`apps/desktop/src-tauri/` et le gate du shell, que F0007 possède déjà et dont sa
décision 2 pose la même question. Son J3 est `Done` le même jour, et il
s'est terminé autrement que prévu : l'EULA du SDK, fournie par Andy et lue,
**n'accorde aucun droit de redistribution** — §2(e) interdit de distribuer le
Software, et son exception « distributable code, subject to the terms above »
renvoie à un grant que les huit alinéas du §1 ne contiennent pas. Ni
`SimConnect.dll` ni le redistribuable `SimConnect.msi` ne peuvent donc être livrés
aux utilisateurs. Andy a retenu l'**option C** : ne rien fournir, et le dire. La
conséquence produit est consignée en `KI-033` (`High`) — la télémétrie live n'est
atteignable que par qui installe volontairement le SDK MSFS ou désigne une copie
qu'il possède via `--simconnect-library`.

Précision du même jour, sur remarque d'Andy : **la clause porte sur la distribution,
pas sur le prix.** §2(e) nomme « share » et « lend » à côté de « distribute », donc
une diffusion gratuite est couverte ; mais elle suppose un transfert vers un tiers,
et l'alpha n'est pas distribuée. L'usage interne — installer le SDK, copier la
bibliothèque, la désigner par chemin explicite — n'est donc pas concerné, et rien ne
bride le développement ni les tests du chemin natif. L'autorisation écrite prévue au
§2 devient une condition **du premier canal externe**, non un préalable actuel.

C'est exactement ce que le format T0068 permet : une unité qui livre sa capacité
technique en entier — la bibliothèque est trouvée, son absence est dite proprement —
tout en constatant à son dernier jalon que la vraie limite n'était pas technique.

Les deux autres décisions d'Andy du 7 août 2026, prises en marge de F0003 J1 :
l'extension de la matrice de validation d'`ADR-0003` au cas « bibliothèque
cliente absente » **ne se fait pas depuis F0003** — une ADR acceptée ne se
réécrit pas, et le cas n'est pas celui du scénario 14 (« variable absente,
invalide ou corrompue ») mais un cran plus tôt, au niveau du prérequis ;
l'extension passera par une ADR nouvelle au moment de la première promotion d'un
canal vers `Supported`. Et `KI-032` — la liste fermée de sources est une dette
d'entretien — est **acceptée** telle quelle, sans travail correctif ouvert :
élargir la découverte rouvrirait le vecteur de détournement de DLL que J1 ferme.

## Transition

Les tickets `TXXXX` encore ouverts vont jusqu'à leur terme au format précédent : le
sélecteur lit les deux répertoires et applique la même capacité de travail aux
fonctionnalités comme aux tickets. Aucun ticket existant n'est regroupé
rétroactivement.
