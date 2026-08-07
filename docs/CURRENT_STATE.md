# État actuel du dépôt

Dernière mise à jour : 6 août 2026. Ce fichier reste sous 200 lignes par
décision d'Andy du 6 août 2026 — le gate de maintenance l'impose : il liste ce
qui est réellement livré dans `main`, ce qui manque pour le jalon courant, et
rien d'autre. Les statuts détaillés vivent dans `docs/features/README.md` et
`docs/tickets/README.md` ; le récit historique complet est archivé dans
`docs/archive/CURRENT_STATE-2026-08-06.md`, puis dans les Pull Requests et les
fichiers d'unités. Lors d'une fusion, ce fichier ne doit jamais reprendre plus
de 200 lignes : si un merge ressuscite le récit, c'est la version courte qui
fait foi.

## Jalon courant : l'alpha cliquable

Un parcours complet dans l'application installée, sur la pile Supabase locale :
login → création de compagnie → achat d'avion → dispatch → vol en replay →
clôture visible au grand livre. Défini par la décision de pilotage d'Andy du
6 août 2026 ; il précède l'« alpha jouable interne » de `docs/ROADMAP.md`, dont
il reprend le périmètre en remplaçant le vol MSFS réel par le replay.

## Capacités livrées dans `main`

Toutes les preuves sont locales ou CI, sur données synthétiques uniquement
(`KI-021` interdit les données réelles).

| Domaine | Capacité | Origine |
| --- | --- | --- |
| Backend | Auth locale email/mot de passe, signup public fermé | T0040 |
| Backend | Onboarding de compagnie autoritaire, ouverture 430 000 EUR | T0022, T0023, T0028 |
| Backend | Achat d'avion autoritaire (Edge + RPC), prouvé sur runtime local | T0029, T0035, T0036 |
| Backend | Location d'avion serveur : contrat, échéances, résiliation, garde d'usage opposable | T0032, T0060 |
| Backend | Grand livre immuable ; export/suppression de compte ; restauration isolée | T0018–T0020 |
| Backend | Brouillon de dispatch autoritaire + frontière Auth, référentiel de 103 aérodromes | T0047–T0049, T0057 |
| Backend | Départ de vol complet : commande serveur, frontière Edge authentifiée prouvée sur l'Edge Runtime réel, rejeu restitué octet pour octet | T0050, T0065, F0001 |
| Backend | Clôture de vol complète : règlement au grand livre, réputation informative, frontière Edge authentifiée prouvée sur l'Edge Runtime réel | T0051, F0002 |
| Desktop | Login, onboarding, catalogue/achat, flotte, création et liste de dispatchs, démarrage de vol avec heure serveur, clôture sur mesure télémétrique rattachée au vol clôturé, revenu affiché depuis le serveur | T0037–T0046, T0052, T0053, F0001, F0002, F0006 |
| Bridge | Contrat local loopback à jeton, adaptateur SimConnect replay, télémétrie bornée, résumé de vol mesuré par générations réarmables et rattaché à son dispatch côté Tauri | T0010, T0011, T0054, F0004, F0006 |
| Distribution | Version produit `0.1.0-alpha.1` (source `eng/product-version.json`), NSIS x64 non signé, CSP par canal produit (`internal-alpha` limité au loopback, public `connect-src 'none'`) prouvée sur l'exécutable produit | T0014, T0055, F0005 J1 |
| Socle | Toolchain épinglée, CI multi-stack, supply chain, gates autorité/données/maintenance | T0001–T0030 |

Limite transverse : les compositions desktop sont prouvées en jsdom avec `fetch`
injecté, **plus un premier parcours WebView live vérifié par Andy le 6 août
2026** (app Tauri dev sur la pile locale : login → compagnie → achat → dispatch
→ départ « En vol » avec l'heure serveur, F0001).

## Unités en cours

- **F0006** (`Verify`) — rattacher la mesure de vol à son dispatch et la
  réarmer entre deux vols : **livrée dans `main`** (PR #132, fusionnée le
  7 août 2026), y compris le branchement de la clôture F0002. Ne reste que le
  parcours manuel deux-vols-d'affilée, qui appartient à Andy.
- **F0005** (`In progress`) — CSP `internal-alpha` limitée au loopback pour
  rendre l'application installée cliquable et clore T0055 (décision du 6 août
  2026). **J1 livré dans `main`** (PR #133 et #134, fusionnées le 7 août
  2026) : la CSP suit le canal produit par allowlist, le canal public reste
  `connect-src 'none'`, et le build refuse un exécutable dont la CSP embarquée
  n'est pas celle de son canal. Reste J2 — package installé et parcours
  humain, qui appartient à Andy.
- **F0003** (`Ready`) — découverte de la bibliothèque SimConnect ou dégradation
  propre ; son J3 attend une décision d'Andy (fourniture de la DLL) et la
  lecture de l'EULA du SDK.

## Ce qui manque pour l'alpha cliquable

1. F0005 J2 — le parcours dans l'application **installée**, qui clôt T0055. La
   CSP par canal est livrée dans `main` (J1) ; reste à produire le package
   `internal-alpha`, l'installer et y dérouler le golden path.
2. Deux vérifications manuelles d'Andy sur du code déjà fusionné : le parcours
   deux-vols-d'affilée de F0006, et le parcours installé de F0005 J2 ci-dessus.

Le câblage du golden path est complet dans `main` depuis la fusion de F0006 :
départ, mesure rattachée et réarmable, clôture et règlement au grand livre.

## Hors du jalon, suivi ailleurs

- MSFS réel et SimConnect natif : T0059 (`Draft`, matériel/SDK) et F0003.
- Vérifications historiques : T0056 (`Ready`, appartient à Andy) ; T0062–T0064
  (`Verify`, vérifications d'Andy sur la boucle, aujourd'hui en pause).
- Cloud, staging, production, signature, updater, rollback : phase 6.
- Dettes et risques : `docs/KNOWN_ISSUES.md`, priorisés par sévérité.

## Pilotage

Mode hybride depuis le 6 août 2026 : sessions interactives par défaut, boucle
planifiée en pause, rigueur à deux vitesses — preuve maximale pour
argent/données/autorité/sécurité, typecheck + tests + build pour l'UI. Voir
`AGENTS.md` (brief) et `docs/WORKFLOW.md` (détail).

## Reproduire et valider

Installer les versions exactes d'`eng/versions.json` puis suivre
`docs/SETUP.md`. Les commandes de validation actives et leur périmètre sont
dans `docs/QUALITY.md`.

## Mise à jour de ce fichier

Quand une capacité est livrée dans `main` : modifier la ligne du tableau, les
sections « Unités en cours » et « Ce qui manque », rien d'autre. Ne jamais y
copier d'historique, de numéros de runs CI ni de récit de ticket : Git, les PR
et les fichiers d'unités les portent déjà.
