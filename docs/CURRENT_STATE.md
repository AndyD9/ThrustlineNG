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
| Backend | Démarrage de vol serveur, rejeu restituant la réponse acquise | T0050, T0065 |
| Backend | Clôture de vol, règlement au grand livre, réputation informative — **sans frontière Auth** | T0051 |
| Desktop | Login, onboarding, catalogue/achat, flotte, création et liste de dispatchs | T0037–T0046, T0052, T0053 |
| Bridge | Contrat local loopback à jeton, adaptateur SimConnect replay, télémétrie bornée | T0010, T0011, T0054 |
| Distribution | Version produit `0.1.0-alpha.1` (source `eng/product-version.json`), NSIS x64 non signé | T0014, T0055 |
| Socle | Toolchain épinglée, CI multi-stack, supply chain, gates autorité/données/maintenance | T0001–T0030 |

Limite transverse : les compositions desktop sont prouvées en jsdom avec `fetch`
injecté. Aucun parcours WebView live de bout en bout n'est encore prouvé —
c'est précisément l'objet du jalon courant.

## Unités en cours

- **F0001** (`In progress`) — faire décoller un vol depuis l'application, sur la
  branche `feature/f0001-faire-decoller-un-vol-prepare`, PR #124 en brouillon.
  J1 (frontière Edge `flight-start`) est `Done` après revue adversariale et
  remédiation ; J2 (preuve sur l'Edge Runtime local réel, 45 contrôles verts le
  6 août 2026) est en revue ; J3 (composition desktop) reste à ouvrir.
- **F0002** (`Blocked`) — clôture et encaissement depuis l'application. Décision
  d'Andy du 6 août 2026 (option C) : le temps de vol viendra de la télémétrie ;
  la condition de sortie est une fonctionnalité de liaison télémétrie → cycle de
  vol encore à ouvrir.
- **F0003** (`Ready`) — découverte de la bibliothèque SimConnect ou dégradation
  propre ; son J3 attend une décision d'Andy (fourniture de la DLL) et la
  lecture de l'EULA du SDK.

## Ce qui manque pour l'alpha cliquable

1. F0001 J3 — le départ composé depuis le desktop — puis la fusion de la PR #124.
2. La liaison télémétrie replay → cycle de vol (fonctionnalité à ouvrir, chemin
   critique depuis la décision C) pour alimenter `blockMinutes`.
3. F0002 — la clôture depuis l'application, débloquée par la précédente.
4. Le parcours interactif réel dans l'application installée — la vérification
   humaine qui tient T0055 en `Verify`.

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
