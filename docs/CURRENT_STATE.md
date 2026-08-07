# État actuel du dépôt

Dernière mise à jour : 7 août 2026. Ce fichier reste sous 200 lignes par
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
| Distribution | Version produit `0.1.0-alpha.1` (source `eng/product-version.json`), NSIS x64 non signé, CSP par canal produit (`internal-alpha` limité au loopback, public `connect-src 'none'`) prouvée sur l'exécutable produit, golden path déroulé dans l'application installée jusqu'au départ | T0014, T0055, F0005 |
| Socle | Toolchain épinglée, CI multi-stack, supply chain, gates autorité/données/maintenance | T0001–T0030 |

Limite transverse : les compositions desktop sont prouvées en jsdom avec `fetch`
injecté, **plus un premier parcours WebView live vérifié par Andy le 6 août
2026** (app Tauri dev sur la pile locale : login → compagnie → achat → dispatch
→ départ « En vol » avec l'heure serveur, F0001), **et le même parcours déroulé
le 7 août 2026 dans l'application installée** (canal `internal-alpha`, pile
locale, jusqu'au départ — F0005 J2 ; mesure et clôture installées relèvent de
KI-027/F0007).

## Unités en cours

Aucune. **F0003 est `Done` depuis le 7 août 2026** — ses trois jalons sont clos et
elle libère la capacité de travail. F0007 est `Ready` (voir ci-dessous).

Ce que F0003 laisse derrière elle : la bibliothèque cliente SimConnect est
désormais trouvée par une sonde à liste ordonnée et fermée, chargée par chemin
absolu, et son absence rend un état `unavailable` explicite au lieu d'un échec muet
(`KI-031` résolue, `KI-032` acceptée). Mais son J3 s'est heurté à la licence :
l'EULA du SDK MSFS n'accorde aucun droit de redistribution — §2(e) interdit de
distribuer le Software et son exception renvoie à un « distributable code » que le
§1 ne définit jamais — donc **Thrustline ne peut pas fournir la bibliothèque**,
ni avec l'application ni par son installateur. Décision d'Andy : option C, ne rien
fournir et le dire. Conséquence dominante, consignée en **`KI-033` (`High`)** : la
télémétrie live n'est atteignable que par qui installe volontairement le SDK MSFS
ou désigne une copie qu'il possède via `--simconnect-library`. Précision du même
jour : **la clause porte sur la distribution, pas sur le prix** — « share » et
« lend » y sont nommés, donc gratuit ne change rien — mais elle suppose un tiers,
donc l'usage interne sur des machines contrôlées n'est pas concerné et le chemin
natif se développe et se teste sans restriction. L'autorisation écrite prévue au §2
de l'EULA est requise **avant le premier canal externe** ; la démarche appartient à
Andy et n'est pas engagée.

Les deux autres décisions d'Andy du 7 août 2026, en marge de F0003 J1 : la moitié
desktop de J2 va dans F0007 ; l'extension de la matrice de validation d'`ADR-0003`
au cas « bibliothèque absente » **n'est pas faite ici** — elle passera par une ADR
nouvelle au moment de la première promotion d'un canal vers `Supported`, une ADR
acceptée ne se réécrivant pas.

## Ce qui manque pour l'alpha cliquable

1. F0007 (`Ready` depuis le 7 août 2026) — **le golden path installé doit se
   terminer.** La décision produit d'Andy est prise : option C, l'alpha n'embarque
   aucune trace et ne mesure donc pas par elle-même ; la mesure arrive avec MSFS
   réel (T0059), et KI-027 passe `Accepted`. **Elle n'est plus différée** : F0003
   étant `Done` depuis le 7 août 2026, la collision de zone sur
   `docs/ARCHITECTURE.md` qui la retenait a disparu — le sélecteur peut la prendre.
   Mais l'option C laissait
   l'alpha bloquée au départ : sans mesure, `FlightCloseControl` échoue fermé et
   demande de « terminer le replay », qui n'existe pas dans cette version, en
   laissant le dispatch « En vol » sans sortie. F0007 livre donc trois choses : la
   barrière du premier abonné retirée du chemin de mesure (elle bloquerait T0059 à
   l'identique), une application qui énonce qu'elle ne mesure pas — ce qui absorbe
   la moitié desktop de F0003 J2, même surface superviseur ↔ WebView — et un chemin
   d'**abandon** de vol (`outcome: "interrupted"`, `blockMinutes: 0`) qui existe
   déjà côté serveur et base, sans fonction Edge ni migration, et sans inventer
   aucun temps de bloc.

Le câblage du golden path est complet dans `main` depuis la fusion de F0006 —
départ, mesure rattachée et réarmable, clôture et règlement au grand livre,
vérifié deux-vols-d'affilée sur harnais replay le 7 août 2026 — et le parcours
installé est prouvé jusqu'au départ depuis F0005 J2 (7 août 2026).

## Hors du jalon, suivi ailleurs

- MSFS réel et SimConnect natif : T0059 (`Draft`, matériel/SDK) et F0003.
- Vérifications historiques : T0056 exécutée le 7 août 2026 (T0007 et T0008
  `Done` sous confirmation d'Andy à la fusion) ; T0062–T0064 (`Verify`,
  vérifications d'Andy sur la boucle, aujourd'hui en pause).
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
