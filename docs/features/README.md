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
| F0003 | Trouver SimConnect nous-mêmes, ou le dire proprement | 3 | T0011, T0054, ADR-0003, ADR-0004 | Ready |
| F0004 | Voir le temps de bloc mesuré de son vol en replay | 3–4 | T0054, T0010, F0001 fusionnée, décision Andy prise le 6 août 2026 | Done |
| F0005 | Rendre l'alpha installée cliquable | 4 | T0014, T0038, T0055, décision Andy prise le 6 août 2026, vérification humaine J2 | In progress |
| F0006 | Rattacher la mesure de vol à son dispatch et la réarmer entre deux vols | 3–4 | F0004 fusionnée, décisions Andy des 7 août 2026 (KI-028, « go 1 ») | Verify |
| F0007 | Mesurer un vol sans harnais externe | 3–4 | F0004 et F0006 fusionnées, décision d'Andy sur l'origine de la trace **non prise** | Draft |

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

F0006 est `Verify` et **livrée dans `main`** (PR #132, fusionnée le 7 août
2026) : ses trois jalons sont `Done` — le bridge mesure par générations
réarmables, Tauri rattache la génération armée au dispatch sans exposer ni
jeton ni génération, l'application arme au départ et échoue fermé sur toute
mesure non rattachée — plus le branchement de la clôture F0002 absorbé après la
fusion de la PR #131. Elle est `Verify` et non `Done` parce que son propre
compte rendu laisse une chose ouverte : le parcours manuel deux-vols-d'affilée,
qui appartient à Andy. KI-028 est résolue par cette fusion, mais reste
`Scheduled` dans `docs/KNOWN_ISSUES.md` : le gate de maintenance n'accepte
qu'un `TXXXX` comme référence d'une entrée `Resolved` et ne connaît pas encore
les `FXXXX` du format T0068 — l'évolution de ce gate appartient à Andy.

F0005 est `In progress` sur la
seconde décision du même jour : le canal `internal-alpha` reçoit une CSP
limitée à `http://127.0.0.1:54321` pendant que le canal public garde
`connect-src 'none'`, ce qui rendra l'application installée réellement
cliquable et clôturera T0055. Son J1 est `Done` et **livré dans `main`**
(PR #133 et #134, fusionnées le 7 août 2026) — surcouche de canal, garde
d'allowlist dans le script de packaging, CSP inscrite au manifeste, huit
mutations négatives, et un contrôle qui relit la CSP réellement embarquée dans
l'exécutable produit. Son J2, le package installé parcouru à la main,
appartient à Andy.

F0007 est `Draft` et porte **KI-027**, le dernier trou entre « l'alpha cliquable »
et « l'alpha qui mesure » : l'application intégrée ne produit pas de temps de
bloc par elle-même. Trois maillons manquent, et un seul suffit à tuer la chaîne
— le superviseur ne passe aucune trace au bridge, l'adaptateur replay n'existe
pas sans `--telemetry-trace`, et la publication attend un premier abonné
SignalR que rien ne crée. Elle reste `Draft` parce que son premier jalon dépend
d'une décision produit qu'Andy n'a pas prise : **d'où vient la trace de
l'alpha ?** — trace dorée embarquée, trace choisie par la personne, ou pas de
trace du tout jusqu'à MSFS réel. Les deux autres décisions (qui crée le premier
abonné, cadence de rejeu) en découlent.

F0003 sort d'une question d'Andy du 5 août 2026 — « il faut qu'on le trouve nous-même,
dans l'hypothèse où la personne n'a rien de tout ça » — et d'un relevé qui lui donne
raison plus durement que prévu : le bridge charge `SimConnect.dll` par
`DllImportSearchPath.SafeDirectories`, qui ne regarde ni le `PATH` ni un chemin
d'installation du SDK, si bien que le chargement échouerait **même sur la machine de
validation**, où MSFS 2024 et le SDK `1.5.7` sont pourtant installés. Et une machine
d'utilisateur final n'a rien à trouver, puisque personne n'installe un SDK de
développement. Elle est `Ready` parce que ses deux premiers jalons — sonde bornée et
état dégradé explicite — n'attendent aucune décision ; seul son J3, qui fournit la
bibliothèque à une machine sans SDK, dépend d'une décision d'Andy et de la lecture de
l'EULA du SDK. C'est exactement ce que le format T0068 permet : une fonctionnalité
exécutable dont un jalon tardif reste bloqué, au lieu d'un ticket entier bloqué par sa
dernière étape.

## Transition

Les tickets `TXXXX` encore ouverts vont jusqu'à leur terme au format précédent : le
sélecteur lit les deux répertoires et applique la même capacité de travail aux
fonctionnalités comme aux tickets. Aucun ticket existant n'est regroupé
rétroactivement.
