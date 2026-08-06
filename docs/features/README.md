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
| F0001 | Faire décoller un vol préparé depuis l'application | 2–4 | T0050, T0048, T0052–T0053, T0065 fusionné | Ready |
| F0002 | Clôturer son vol et encaisser son revenu depuis l'application | 2–4 | T0051, T0057, F0001 fusionnée, liaison télémétrie → cycle de vol | Blocked |
| F0003 | Trouver SimConnect nous-mêmes, ou le dire proprement | 3 | T0011, T0054, ADR-0003, ADR-0004 | Ready |

Les deux premières fonctionnalités ouvrent le format sur ce qui restait du golden
path : `start_flight_from_dispatch` et `close_flight` sont livrées dans `main` depuis
T0050 et T0051, mais ce sont les deux seules commandes du golden path sans frontière
authentifiée ni appelant. Chacune est donc un slice vertical de trois jalons —
frontière Edge, validation sur l'Edge Runtime local réel, composition desktop — au
lieu des quatre à six tickets que le format précédent aurait produits.

F0001 est `Ready` : aucune décision n'est en attente, et sa seule condition d'ordre
est la fusion de la PR #121 (T0065), qui change le contrat de rejeu que sa projection
publique doit refléter. F0002 est `Blocked` depuis la décision d'Andy du 6 août
2026 (option C) : le temps de vol d'un rapport de clôture viendra de la télémétrie,
jamais d'une saisie ni d'une migration. Sa condition de sortie est une
fonctionnalité encore à ouvrir qui relie la télémétrie du bridge (replay T0054
d'abord, MSFS réel ensuite) au cycle de vol ; elle devient le chemin critique du
jalon « alpha cliquable » après F0001.

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
