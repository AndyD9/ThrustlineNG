# État actuel du dépôt

Dernière mise à jour : 6 août 2026. Ce fichier reste court par décision d'Andy
du 6 août 2026 : il liste ce qui est réellement livré dans `main`, ce qui manque
pour le jalon courant, et rien d'autre. Les statuts détaillés vivent dans
`docs/features/README.md` et `docs/tickets/README.md` ; le récit historique
complet est archivé dans `docs/archive/CURRENT_STATE-2026-08-06.md`, puis dans
les Pull Requests et les fichiers d'unités.

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
| Backend | Grand livre immuable ; export/suppression de compte ; restauration isolée | T0018–T0020 |
| Backend | Brouillon de dispatch autoritaire + frontière Auth, référentiel de 103 aérodromes | T0047–T0049, T0057 |
| Backend | Démarrage de vol serveur — **sans frontière Auth ni appelant desktop** | T0050 |
| Backend | Clôture de vol, règlement au grand livre, réputation informative — **sans frontière Auth** | T0051 |
| Desktop | Login, onboarding, catalogue/achat, flotte, création et liste de dispatchs | T0037–T0046, T0052, T0053 |
| Bridge | Contrat local loopback à jeton, adaptateur SimConnect replay, télémétrie bornée | T0010, T0011, T0054 |
| Distribution | Version produit `0.1.0-alpha.1` (source `eng/product-version.json`), NSIS x64 non signé | T0014, T0055 |
| Socle | Toolchain épinglée, CI multi-stack, supply chain, gates autorité/données/maintenance | T0001–T0030 |

Limite transverse : les compositions desktop sont prouvées en jsdom avec `fetch`
injecté. Aucun parcours WebView live de bout en bout n'est encore prouvé —
c'est précisément l'objet du jalon courant.

## Ce qui manque pour l'alpha cliquable

1. Frontières Auth du démarrage et de la clôture de vol — F0001 et F0002,
   proposées par la PR #122 (brouillon, en attente d'Andy).
2. Consommation desktop du cycle de vol : démarrer, suivre en replay, clôturer.
3. Le parcours interactif réel dans l'application installée — la vérification
   humaine qui tient T0055 en `Verify`.
4. Rejeu idempotent du départ de vol (T0065, correctif en PR #121).

## Hors du jalon, suivi ailleurs

- MSFS réel et SimConnect natif : T0059, bloqué par le matériel/SDK.
- Location d'avions (T0032, `Verify`) et fin d'usage opposable (T0060, `Review`).
- Cloud, staging, production, signature, updater, rollback : phase 6.
- Vérifications interactives historiques : T0056.
- Dettes et risques : `docs/KNOWN_ISSUES.md`, priorisés par sévérité.

## Reproduire et valider

Installer les versions exactes d'`eng/versions.json` puis suivre
`docs/SETUP.md`. Les commandes de validation actives et leur périmètre sont
dans `docs/QUALITY.md` ; la rigueur à deux vitesses du pilotage (preuve maximale
pour argent/données/sécurité, typecheck + tests + build pour l'UI) est définie
dans `AGENTS.md`.

## Mise à jour de ce fichier

Quand une capacité est livrée dans `main` : modifier la ligne du tableau et la
section « Ce qui manque », rien d'autre. Ne jamais y copier d'historique, de
numéros de runs CI ni de récit de ticket : Git, les PR et les fichiers d'unités
les portent déjà.
