# Qualité du dépôt

## Règles issues des défauts déjà observés

Ces règles viennent de défauts réellement rencontrés, dont le registre et les
preuves sont dans `docs/LEARNINGS.md`. Elles s'ajoutent à la règle des deux hôtes
PowerShell prouvée par T0051 et rappelée dans la section « Backend Supabase ».

1. **Réécriture en bloc d'un objet SQL déjà livré (`LC-2026-002`).** Les marqueurs
   du gate backend sont épinglés par fichier de migration : une série T0047,
   T0050, T0051 ou T0057 continue de passer contre son propre fichier même si la
   définition vivante déménage et perd un de ses invariants. Toute migration qui
   redéfinit une fonction déjà livrée doit donc réaffirmer contre le **nouveau**
   fichier les invariants qu'elle reprend, et prouver la reprise par un diff des
   deux définitions extraites avant et après, dont le seul écart attendu est le
   changement du ticket. T0032 avait supprimé puis réintégré le crédit
   `flight_settlement` de T0051 en réécrivant une contrainte de cette façon.
2. **Fins de ligne du runner (`LC-2026-003`).** Un gate à regex multiligne ou de
   proximité doit être exécuté contre les fins de ligne que le runner verra. En
   .NET, une ancre `$` sous `(?m)` ne correspond jamais avant `\r\n` : un fixture
   écrit par `Set-Content` est en CRLF, et un fichier nouvellement écrit en LF
   devient CRLF au checkout Windows par `.gitattributes` `* text=auto` et
   `core.autocrlf true`. Rejouer le gate sur la forme réellement checkoutée avant
   de publier, sinon il peut passer en local et échouer, ou muter à vide, sur le
   runner.
3. **Assertions pgTAP sur le catalogue PostgreSQL (`LC-2026-005`).** Un
   `results_eq` sur une colonne de type `name` échoue par « could not determine
   which collation to use for string comparison » : comparer `proname::text` ou
   agréger en une seule chaîne. Une assertion sur `set search_path = ''` doit
   attendre le littéral réellement stocké, `search_path=""` avec ses guillemets.
4. **Pile locale singleton résiduelle contre pile occupée (`LC-2026-007`).** La
   pile `backend:*` est un singleton sur `127.0.0.1`. Avant de déclarer un
   contrôle `bloqué par l'environnement` pour occupation, relever l'état réel du
   conteneur avec `docker inspect` et les écouteurs des ports 54321 à 54323 avec
   `Get-NetTCPConnection` : un conteneur `exited` sans écouteur est un résidu, pas
   un travail concurrent, et son nettoyage passe par `pnpm backend:stop`, jamais
   par une manipulation Docker directe. Si un écouteur existe, le contrôle est
   réellement bloqué et la pile ne doit pas être réinitialisée.

## Gouvernance de maintenance

Depuis la racine :

```powershell
pnpm maintenance:check
```

Le harnais valide `KNOWN_ISSUES.md`, la cohérence des statuts entre fichiers de
ticket et index et l'absence de marqueur `TODO`/`FIXME`/`HACK`/`XXX` non relié à
une entrée active. Huit mutations négatives couvrent schéma, sévérité et statut
invalides, preuve absente, identifiant dupliqué, divergence de statut et
marqueurs non suivis, y compris après un marqueur valide sur la même ligne.

Ce gate ne transforme pas une capacité future, un risque accepté ou une preuve
environnementale manquante en dette résolue.

## Automatisation du cycle des tickets

Depuis la racine :

```powershell
pnpm ticket-automation:check
pnpm ticket-batch:select
```

Le gate T0061 valide `scripts/select-ticket-batch.ps1` sur un dépôt synthétique,
indépendant des tickets réels, avec 50 assertions et quinze mutations négatives.

Cohérence du suivi et capacité : statut divergent entre fichier et index, statut
invalide, champ `Status` absent, ticket absent de l'index, identifiant d'index
dupliqué, dépendance revenue en `Draft`, collision de zones autorisées entre deux
candidats, flux `In progress` qui consomme la capacité et réserve ses chemins,
ticket forcé alors qu'il n'est pas `Ready`, sélection forcée séparée par des
virgules.

Frontière d'autonomie ajoutée par T0063, pour les runs non surveillés :
`Autonomous: No`, `Security-sensitive: Yes`, `Risk: High` et une dépendance nommant
une décision humaine sont chacun prouvés comme veto sous `-AutonomousOnly`. Une
quinzième mutation prouve la réciproque : le même veto ne bloque pas un run
surveillé.

Le scénario de référence vérifie aussi que les fichiers de suivi partagés restent
hors des collisions tout en étant signalés comme imposant un ordre d'intégration,
et que la fixture complète est classée autonome.

Le harnais écrit ses fixtures en LF et refuse toute mutation qui ne change rien,
d'après T0062. Les deux comptent : `.gitattributes` livre ce script en CRLF, et en
.NET une ancre `$` sous `(?m)` ne correspond jamais avant `\r\n`. Sans ces deux
garde-fous, les mutations cesseraient silencieusement de s'appliquer sur un clone
frais et le gate passerait à vide.

Exécuter ce gate sous les **deux** hôtes. Le harnais lance le sélecteur avec
l'hôte qui l'exécute, et les deux ne passent pas les arguments de la même façon :
une régression réelle de découpage d'argument n'a été visible que sous
PowerShell 7.

```powershell
pwsh -NoProfile -File .\tests\ticket-automation\run.ps1
```

`pnpm ticket-batch:select` est le contrôle à exécuter avant de planifier ou
d'exécuter une vague : sa sortie non nulle signale une incohérence de suivi à
corriger d'abord. Il reste en lecture seule et ne modifie aucun fichier.

Ce gate prouve le sélecteur, pas la qualité du travail des agents. Il ne
transforme pas une invite de workflow en garantie de comportement, et n'est pas
exécuté par la CI : `.github/workflows/` est hors des zones autorisées de T0061.

## Politique de données

Depuis la racine :

```powershell
pnpm data-policy:check
```

Le harnais T0017–T0019 valide la source JSON, quatre environnements, huit
catégories, les maxima de rétention, les seeds synthétiques et l'intégration CI.
Il détecte six mutations : catégorie absente, donnée de production autorisée en
staging, délai de journaux supérieur à 90 jours, dérive de la suppression de
compte et dérive du replay après restauration.

Ce contrôle est statique : il ne transforme pas une suppression, une sauvegarde
ou une restauration non exécutée en preuve. Ces capacités restent
`Not implemented` jusqu'à un test sur l'environnement concerné.

## Toolchain et bootstrap

Depuis la racine, avec PowerShell 7.6 ou plus récent :

```powershell
pwsh -NoProfile -File .\scripts\check-toolchain.ps1
pwsh -NoProfile -File .\scripts\check-toolchain.ps1 -Json
pwsh -NoProfile -File .\tests\toolchain\run.ps1
pwsh -NoProfile -File .\scripts\bootstrap.ps1 -CheckOnly
```

Le harnais utilise un dépôt synthétique qui doit contenir tous les manifests lus
par `check-toolchain.ps1`. Toute extension du contrôle de pins doit mettre à jour
ce fixture et ajouter ou préserver un scénario d'échec associé.

## Version produit

La source canonique unique `eng/product-version.json` porte la version produit,
son canal et le modèle de nom d'artefact. Elle reste indépendante de
`eng/versions.json`, qui épingle la toolchain, ainsi que des versions de schéma,
de contrat et d'outils.

Depuis la racine :

```powershell
pnpm product-version:check
```

Le gate T0055 refuse une version qui n'est pas une préversion SemVer 2.0.0
ordonnée `alpha.N`, `beta.N` ou `rc.N`, une version supérieure ou égale à `1.0.0`,
une métadonnée de build dans la source canonique et un canal autre que l'alpha
interne non signée. Il compare ensuite les cinq cibles — frontend, `tauri.conf.json`,
crate Rust, `Directory.Build.props` et l'affichage desktop — à cette source, exige
un nom d'installateur qui reprend exactement la version sans chemin, et vérifie
que les scripts de packaging dérivent ce nom et le manifeste de la source
canonique. Six mutations négatives sont prouvées : cible divergente, version
opaque `1.0aeb458345`, nom d'artefact désynchronisé, métadonnée de build dans la
source, concaténation du commit dans la version informationnelle .NET et script
de build détaché de la source.

Ce gate n'est pas exécuté par la CI : `.github/workflows/ci.yml` et son harnais
`tests/ci/run.ps1` sont hors des zones autorisées de T0055. Il reste donc un
contrôle local jusqu'au ticket de release qui l'ajoutera au workflow.

Une build interne peut porter la métadonnée `+YYYYMMDD.gSHORTSHA`, qui ne change
pas l'ordre des versions. L'interface n'affiche que la version produit ; ni tag,
ni signature, ni distribution publique ne sont produits par ce contrôle.

## Autorité des mutations

La source `eng/authority-inventory.json` et son gate couvrent les dix étapes du
golden path, les domaines non implémentés et les trois surfaces clientes :

```powershell
pnpm authority:check
```

Le résultat attendu mentionne 10 étapes, 13 domaines, 3 surfaces et 5 scénarios
de mutation. Le harnais retire une étape, introduit une autorité client, casse
un marqueur de preuve, injecte une mutation Supabase directe puis ajoute une extension de
code inconnue. Un code 0 sans ces scénarios n'est pas la preuve T0024. Le job
Windows exécute ce gate avant toute validation applicative ; `ci:check` refuse
sa disparition du workflow.

## Backend Supabase

Le contrôle statique fonctionne sans Docker et couvre la version de CLI, la
configuration PostgreSQL 17, l'ordre migration/seed, les contraintes, les
politiques, les scénarios A/B/anonyme et l'absence de commande distante. Il
exécute aussi dix-huit mutations négatives, dont une publication wildcard, un
montage du socket Docker hôte et une commande d'onboarding rendue exécutable par
un rôle client. T0023 ajoute la détection d'un propriétaire repris du payload ou
d'un appel RPC effectué sans le credential serveur. T0028 ajoute une version de
politique inconnue, une divergence entre source canonique et copie embarquée et
le retour d'une surcharge par environnement. T0035 ajoute trois mutations pour
le propriétaire d'achat repris du payload, le credential RPC abaissé et un prix
client réintroduit. T0048 ajoute quatre mutations : propriétaire de dispatch
repris du payload, credential RPC abaissé, état client réintroduit et contrat de
tests incomplet :

```powershell
pnpm backend:check
pnpm backend:functions:test
```

La preuve SQL réelle exige Docker Desktop ou un runtime Docker compatible
actif :

```powershell
pnpm backend:start
pnpm backend:reset
pnpm backend:test
pnpm backend:types:check
pnpm backend:stop
```

`backend:functions:test` exécute 46 tests Node sans dépendance tierce : 15 pour
l'onboarding, 15 pour l'achat et 16 pour le dispatch. Ils couvrent méthode, corps 4 Kio, payload
exact, normalisation, UUID, configuration, Auth anonyme ou invalide,
indisponibilité Auth/RPC, dérivation du propriétaire, credential privilégié,
redaction, rejeu et réponse allowlistée versionnée `no-store`.
Le harnais Linux `ci:backend` rejoue tous ces tests avant de démarrer PostgreSQL. Il
exclut ensuite Edge Runtime de la pile SQL : avec Supabase CLI 2.109.1 sur
Ubuntu, le cycle de reset tente sinon de recréer PostgreSQL alors que son port
est encore occupé. Le chargement Deno réel reste une preuve Windows séparée.

`backend:reset` inclut explicitement `--local`. `backend:test` doit découvrir
les vingt-quatre fichiers pgTAP et conclure par `Result: PASS`; un code 0 sans test
découvert n'est pas une réussite. Les 552 assertions couvrent le cycle de compte
T0018, le replay T0019, le grand livre T0020, l'onboarding T0022, l'achat
T0029, le dispatch T0047, le démarrage de vol T0050, le référentiel
d'aérodromes T0057, la clôture de vol T0051, la location T0032, l'opposabilité
de la fin d'usage T0060 et la restitution du rejeu de départ T0065. `backend:test` s'exécute sur les sources copiées dans le
runtime isolé par `backend:start` : après avoir modifié une migration, un seed ou
un fichier pgTAP, relancer `backend:start` avant de conclure, sinon la commande
rejoue silencieusement la version précédente. Le job CI
lance deux sessions PostgreSQL concurrentes pour les cycles sensibles et exige
notamment une compagnie, une commande et une ouverture uniques pour deux appels
T0022 identiques. Il restaure aussi un dump synthétique pris
avant suppression dans une base distincte, vérifie les ACL/RLS et `pgcrypto`,
rejoue le journal, refuse les événements altéré/inconnu et détruit les fichiers
et la cible. `backend:types:check` régénère les types en mémoire et échoue si le
fichier versionné diffère.

T0029 ajoute deux sessions concurrentes qui rejouent le même achat et exige les
mêmes identifiants, un avion, une commande, un débit et un solde final exact. Une
seconde course oppose deux offres de 10 000 000 à un solde de 15 000 000 : une
seule commande doit réussir et le solde final doit rester à 5 000 000.
Les pgTAP couvrent aussi prix serveur, ACL/RLS, A/B/anonyme, collision, offre
consommée, solde insuffisant, suppression en attente et rollback injecté. Ces
preuves restent locales et synthétiques ; elles ne valent ni déploiement distant
ni validation d'un catalogue de production.

Preuve T0035 du 2 août 2026 : les 30 tests Node passent, dont les 15 scénarios
de la nouvelle frontière d'achat. Le gate backend passe avec 18 mutations et
l'inventaire d'autorité référence le handler Edge pour flotte et finance. Cette
preuve est locale et simulée ; elle ne prouve ni chargement Deno réel,
déploiement distant, appel desktop ni donnée réelle.

Preuve T0036 du 2 août 2026 : l'Edge Runtime réel charge les fonctions sur la
pile T0021 et une identité/session/JWT synthétiques traverse Auth, onboarding et
achat. La réponse d'achat contient seulement les cinq champs publics et
`Cache-Control: no-store`; le rejeu conserve les identifiants. PostgreSQL
confirme une compagnie, deux écritures, un solde de `33000000`, un avion et une
commande. Sans JWT, l'appel rend HTTP 401 ; avec `priceMinor`, HTTP 400 sans
détail interne. L'arrêt `--no-backup` puis le redémarrage confirment zéro
identité T0036 persistée. Cette preuve ne vaut ni parcours de connexion
utilisateur, déploiement distant, parité cloud, appel desktop ou donnée réelle.

Preuve T0037 du 2 août 2026 : le typecheck, les 5 fichiers/38 tests frontend, la
couverture et le build Vite passent. La couverture globale atteint 91,52 % des
statements, 88,78 % des branches, 91,30 % des fonctions et 93,10 % des lignes.
Les tests couvrent payload/headers fermés, cibles HTTPS ou loopback, contrats de
réponse invalides, statuts 401/409/5xx, panne réseau, double clic, annulation et
retry avec clé d'idempotence stable. Les gates autorité, données et maintenance
passent avec 5, 6 et 8 mutations négatives. L'inspection du bundle ne trouve ni
credential de test, ni référence privilégiée, ni accès Data API. Cette preuve
porte sur une commande et un panneau injectés : la CSP reste `connect-src
'none'` et aucun auth, catalogue, écran routé, appel live ou cible distante
n'est validé.

Preuve T0038 du 2 août 2026 : typecheck, couverture et build passent avec
7 fichiers/58 tests frontend. La couverture globale atteint 89,80 % des
statements, 84,79 % des branches, 90 % des fonctions et 90,68 % des lignes.
Les tests couvrent configuration locale exacte, session en mémoire,
refresh avant expiration, rotation des deux tokens, convergence concurrente,
refus Auth, panne transitoire, taille et contrat de réponse. L'invariant CSP
confirme que le développement ajoute seulement `127.0.0.1:54321` et que la
production reste fermée. Les gates autorité, données et maintenance passent
avec 5, 6 et 8 mutations négatives. Cette preuve est simulée par `fetch` injecté : aucun
login, appel live, persistance, staging ou cible distante n'est validé.

Preuve T0039 du 2 août 2026 : typecheck, couverture et build passent avec
9 fichiers/78 tests frontend. La couverture globale atteint 92 % des
statements, 86,13 % des branches, 92,45 % des fonctions et 92,56 % des lignes.
Les tests couvrent payload et headers Auth fermés, bornes email/mot de passe,
timeout ou panne, refus redigé, réponse streaming limitée à 16 Kio, validation
de session, double soumission, installation atomique, effacement du mot de
passe et annulation. L'invariant auth refuse stockage Web, cookie et logs. Les
gates autorité, données et maintenance passent avec 5, 6 et 8 mutations. Cette
preuve utilise un `fetch` injecté et un DOM jsdom : aucun login live, route,
persistance Windows, cible distante ou donnée réelle n'est validé.

Preuve T0040 du 2 août 2026 : le gate backend passe avec 20 mutations, dont
l'ouverture du signup global et la désactivation du provider email local. Sur
Docker Desktop 29.6.2, la pile isolée publie uniquement 54321–54323 sur
`127.0.0.1`. Une identité `.invalid` provisionnée par l'Admin API traverse la
vraie commande `signInWithPassword` et le gestionnaire de session ; 1 fichier/2
tests runtime confirme aussi le refus d'un mauvais mot de passe et de `/signup`.
L'identité est supprimée, puis l'arrêt sans backup et le redémarrage rendent
`2|2|0` : deux identités seed `.invalid`, zéro identité T0040. La pile est
arrêtée. Cette preuve locale est réalisée après la fusion T0039 et ne valide ni route,
persistance, cible distante ou donnée réelle.

Preuve T0041 du 2 août 2026 : typecheck, couverture et build passent avec
9 fichiers/80 tests frontend ; 1 fichier/2 scénarios runtime T0040 reste ignoré
sans environnement explicite. La couverture globale atteint 91,69 % des
statements, 86,17 % des branches, 91,66 % des fonctions et 92,18 % des lignes.
Le DOM jsdom couvre `/` sans session, `/login` avec session, installation avant
navigation, déconnexion et route inconnue. Les espions réseau restent à zéro au
rendu, pendant les redirections et à la déconnexion ; après succès, le DOM ne
contient aucun identifiant ou token synthétique. Les gates autorité, données et
maintenance passent avec 5, 6 et 8 mutations. Cette preuve ne valide aucun login
WebView live, persistance, onboarding, catalogue, achat ou cible distante et la
PR corrective #69 est fusionnée dans `main` au commit `cb179e9`.

Preuve T0042 du 2 août 2026 : typecheck, couverture et build passent avec
11 fichiers/104 tests frontend ; 1 fichier/2 scénarios runtime T0040 reste
ignoré sans environnement explicite. La couverture globale atteint 91,78 % des
statements, 85,55 % des branches, 93,50 % des fonctions et 92,07 % des lignes.
Les tests couvrent payload/headers fermés, cible, nom, UUID, délai et réponse
bornés, retry idempotent, changement d'intention, double soumission, annulation,
expiration Auth, redirection et absence de réseau au rendu ou de fuite au DOM.
Les gates autorité, données et maintenance passent avec 5, 6 et 8 mutations.
Cette preuve jsdom/fetch injectée ne valide ni WebView live, CSP de production,
catalogue, achat, cible distante ou donnée réelle ; T0042 reste empilé sur
la PR corrective #71 vers `main`.

Preuve T0043 du 2 août 2026 : typecheck, couverture et build passent avec
13 fichiers/125 tests frontend ; 1 fichier/2 scénarios runtime T0040 reste
ignoré sans environnement explicite. La couverture globale atteint 92,26 % des
statements, 86,41 % des branches, 94,38 % des fonctions et 92,48 % des lignes.
Les tests couvrent la requête GET fermée, cible locale, headers, projection,
filtre, ordre, limite, taille streaming, schéma des offres, 401/403, panne,
zéro réseau au rendu, catalogue vide, concurrence, retry et démontage. Les gates
autorité, données et maintenance passent avec 8, 6 et 8 mutations. Cette preuve
jsdom/fetch injectée ne valide ni WebView live, CSP de production, achat composé,
cible distante ou donnée réelle ; T0043 est empilé sur T0042/PR #71.

Preuve T0044 du 3 août 2026 : typecheck, couverture et build passent avec
15 fichiers/146 tests frontend ; 1 fichier/2 scénarios runtime T0040 reste
ignoré sans environnement explicite. La couverture globale atteint 92,69 % des
statements, 86,79 % des branches, 95,04 % des fonctions et 92,85 % des lignes.
Les tests couvrent requête de présence fermée, cible locale, headers, projection,
limite, taille streaming, zéro/une compagnie, violation d'unicité, 401/403,
panne, zéro réseau au rendu, concurrence, retry, démontage et aiguillage des
sessions nouvelles ou existantes. Les gates autorité, données et maintenance
passent avec 9, 6 et 8 mutations. Cette preuve jsdom/fetch injectée ne valide ni
WebView live, CSP de production, achat composé, cible distante ou donnée réelle ;
T0044 est empilé sur T0043/PR #72.

Preuve T0045 du 3 août 2026 : typecheck, couverture et build passent avec 15
fichiers/149 tests frontend exécutés ; 1 fichier/2 scénarios runtime T0040 reste
ignoré sans environnement explicite. La couverture globale atteint 92,86 % des
statements, 86,61 % des branches, 96,15 % des fonctions et 92,87 % des lignes.
Les tests couvrent sélection issue du catalogue, bearer acquis à la soumission,
payload fermé, achat réussi, double clic, retry idempotent, changement d'offre,
verrouillage pendant la commande, refus Auth et démontage. Les gates autorité,
données et maintenance passent avec 9, 6 et 8 mutations. Cette preuve
jsdom/fetch injectée ne valide ni WebView live, CSP de production, cible
distante, donnée réelle ou livraison dans `main`; T0045 est empilé sur T0044.

Preuve T0046 du 3 août 2026 : typecheck, couverture et build passent avec 17
fichiers/173 tests frontend exécutés ; 1 fichier/2 scénarios runtime T0040 reste
ignoré sans environnement explicite. La couverture globale atteint 93,26 % des
statements, 87,36 % des branches, 96,72 % des fonctions et 93,25 % des lignes.
Les tests couvrent requête de flotte sans filtre propriétaire, réponse et taille
bornées, schéma strict, doublons, zéro réseau au rendu, flotte vide, concurrence,
retry, refus Auth, démontage, actualisation post-achat et refresh reçu pendant
une lecture. Les gates autorité, données et maintenance passent avec 9, 6 et 8
mutations. Cette preuve jsdom/fetch injectée ne valide ni WebView live, CSP de
production, cible distante, donnée réelle, pagination ou livraison dans `main`;
T0046 est empilé sur T0045.

Preuve T0047 du 3 août 2026 : le gate backend passe avec 22 mutations et les
gates autorité, données et maintenance avec 9, 6 et 8 mutations. Sous Docker
Desktop 29.6.2, deux resets appliquent les sept migrations append-only puis 14
fichiers/270 assertions pgTAP concluent par `Result: PASS`. Les types générés
depuis PostgreSQL restent stables. Les tests couvrent ACL/RLS, dérivation de
compagnie et d'état, normalisation ICAO, propriété A/B, anonyme, rejeu,
collision, deuxième brouillon, suppression en attente et rollback injecté.
Deux sessions avec des clés et destinations différentes sur le même avion
produisent les codes `0|1` et l'état `1|1|0|1` : un brouillon, une commande,
aucun état non-draft et un avion distinct. Cette preuve locale synthétique ne
valide ni Edge Function, desktop, SimBrief, cycle de vol, cible distante ou
donnée réelle ; T0047 est empilé sur T0046.

Preuve T0048 du 3 août 2026 : `backend:functions:test` exécute 46 tests Node,
dont 16 pour `dispatch-draft`, et `backend:check` passe avec 26 mutations. Les
gates autorité, données et maintenance passent avec 9, 6 et 8 mutations. Les
tests injectés couvrent allowlist, 4 Kio, UUID/ICAO, Auth non anonyme,
propriétaire dérivé, credential serveur, timeout, payload RPC exact, redaction,
projection publique, rejeu et `no-store`. Cette preuve ne valide pas l'Edge
Runtime live, un appel desktop, SimBrief, une cible distante ou une donnée réelle
et reste empilée sur T0047.

Preuve T0049 du 3 août 2026 : `scripts/validate-dispatch-draft-runtime.ps1`
exécute 48 contrôles sans échec sur la pile T0021, avec Docker Desktop 29.6.2,
Supabase CLI 2.109.1, PostgreSQL 17 et l'Edge Runtime/Deno local. Seuls
54321–54323 sont publiés sur `127.0.0.1`, avant et après le parcours. Deux
identités `.invalid` provisionnées par l'Admin API ouvrent leur compagnie par
`company-onboarding`; la première achète l'offre seedée abordable puis obtient un
brouillon par `dispatch-draft`. La réponse contient exactement `aircraftId,
arrivalIcao, createdAt, departureIcao, dispatchId, schemaVersion, state`, avec
`state: draft`, `schemaVersion: 1` et `Cache-Control: no-store`; le rejeu rend le
même `dispatchId` et le même `createdAt`. Sans bearer l'appel rend HTTP 401 ; un
champ supplémentaire rend HTTP 400 `invalid_request`; un ICAO malformé puis deux
ICAO identiques rendent HTTP 400 `invalid_airports`; l'avion d'un autre
propriétaire, un avion inconnu et un deuxième brouillon rendent HTTP 409
`dispatch_rejected`. Chaque refus ne porte que `error.code` et `error.message` et
ne contient ni compagnie, ni propriétaire, ni email, ni identifiant privilégié.
Le refus de propriété est exercé avant toute création et l'état reste à zéro
brouillon. L'état final est `1|1|1|1` : un brouillon, une commande, l'état
`draft` et l'appartenance à la compagnie du sujet Auth. Après arrêt
`--no-backup` et redémarrage, l'inspection rend `2|0|0|0|0`. Les gates backend
(26 mutations), fonctions (46 tests), pgTAP (14 fichiers/270 tests sur base
fraîche), types, autorité, données et maintenance passent. Cette preuve ne vaut
ni parité cloud, cible distante, staging, charge, consommation desktop ou donnée
réelle. Deux limites sont consignées : la suppression d'une identité déjà
propriétaire est refusée par `companies_owner_id_fkey`, donc la destruction de la
pile est le seul nettoyage ; et `pnpm backend:test` exige une base fraîchement
réinitialisée.

Preuve F0001 J2 du 6 août 2026 : `scripts/validate-flight-start-runtime.ps1`
exécute 46 contrôles sans échec sur la même pile, selon la méthode T0049. Après
onboarding, achat et brouillon réels, le départ nominal rend exactement les cinq
champs publics `aircraftId, dispatchId, schemaVersion, startedAt, state` avec
`state: active` et `Cache-Control: no-store`; le rejeu de la même clé restitue
la réponse acquise octet pour octet sans second départ ni seconde commande. Les
corps des trois refus — dispatch étranger, inconnu, déjà actif — sont comparés
entre eux et identiques (`409 flight_start_rejected`). Sans bearer : 401 sans
détail interne ; un champ injecté : 400 `invalid_request`; un corps de 5 Kio :
413 `request_too_large`. L'état SQL final est `1|1|0|1|1` — un vol actif, une
commande, possédés par le sujet Auth — et la pile jetable est détruite ensuite.
Le gate backend passe avec 67 mutations, dont 9 pour cette frontière ; les
tests de fonctions passent à 62.

Preuve T0050 du 3 août 2026 : `backend:check` passe avec 30 mutations, dont
quatre nouvelles qui détectent un démarrage exécutable par un client, un
troisième état de vol, un horodatage de départ fourni par l'appelant et la
réécriture d'une migration déjà livrée. Sous Docker Desktop 29.6.2 et
PostgreSQL 17, deux resets appliquent les huit migrations append-only puis 16
fichiers/312 assertions pgTAP concluent par `Result: PASS`; les types régénérés
n'exposent que `started_at: string | null` et `start_flight_from_dispatch`, et
`backend:types:check` les confirme stables. Les gates autorité, données et
maintenance passent avec 9, 6 et 8 mutations.

Les pgTAP couvrent ACL/grants, RLS forcée, isolation A/B/anonyme, dérivation de
compagnie et d'avion, rejeu identique, collision de clé, deuxième démarrage,
dispatch étranger, dispatch inexistant, compte en suppression, rollback injecté,
refus d'un état hors liste, refus d'un horodatage forgé sur un vol actif et refus
d'un horodatage sur un brouillon. La vérification manuelle du 3 août 2026
confirme sur la pile locale : un brouillon possédé devient un vol `active`
horodaté `2026-08-03T15:21:05.001358+00:00`, le rejeu de la même clé rend la même
réponse au même horodatage, et seconde identité, collision, dispatch déjà actif
et dispatch inconnu échouent fermés. L'état SQL rend `1|2|1|1` : un vol actif,
deux brouillons restants, une commande et un horodatage serveur. Aucune écriture
financière n'apparaît, `authenticated` et `anon` reçoivent `permission denied`
sur la commande comme sur la table, et deux sessions concurrentes sur le même
dispatch rendent les codes `0|1` avec l'état `1|1|0|1|0`. Cette preuve locale
synthétique ne valide ni frontière Auth, endpoint, appelant desktop, télémétrie,
clôture, cible distante ou donnée réelle. La PR #89 fusionne T0050 dans `main` au
merge `6577125`, où le job Linux `Supabase PostgreSQL 17` passe : deux resets,
16 fichiers/312 assertions pgTAP avec `Result: PASS`, `Flight start concurrency
passed: 2 sessions, 1 active flight, 1 command, 1 server time` puis
`Backend CI passed`. La course intersession du harnais CI, non exécutable
localement sous Windows, est donc prouvée sur le runner Linux.

Preuve T0051 du 4 août 2026, sous Windows 11, Docker Desktop 29.6.2 et
PostgreSQL 17 : `backend:check` passe avec 42 mutations, dont sept nouvelles qui
détectent un barème embarqué divergeant de `eng/flight-settlement-policy.json`, un
delta de réputation inversé, un plancher de vol interrompu ramené à zéro, un
montant de règlement fourni par l'appelant, une exclusivité par avion qui couvre
encore les vols terminés, une table de réputation rendue lisible par un rôle
client et un règlement qui fait confiance au temps de bloc déclaré. Deux resets
appliquent les dix migrations append-only, puis 20 fichiers/427 assertions pgTAP
concluent par `Result: PASS`. Les types régénérés n'ajoutent que `closed_at`,
`close_flight` et `get_company_reputation` en 21 lignes, et `backend:types:check`
les confirme stables ; `authority:check`, `data-policy:check` et
`maintenance:check` passent.

Les montants attendus de ces preuves ont été calculés hors de la base, avec Node,
avant d'être écrits en clair dans les tests : `57694` pour 168,28 NM et
75 minutes de bloc au palier standard, `48648` pour 18,44 NM et 75 minutes en
`hub`/`major`, le plafond `2000000` pour un vol qui atteindrait `2103629`, et le
plancher `5000` pour un vol interrompu. Le barème n'est donc pas validé contre
lui-même. Deux limites subsistent : la distance de grand cercle est calculée en
`double precision`, donc une plateforme différente pourrait déplacer la deuxième
décimale et le montant d'une unité mineure ; et l'observation d'un temps de bloc
non nul dans une transaction pgTAP exige de désactiver brièvement le trigger de
`started_at` pour antidater le départ, ce que seul le propriétaire de la table peut
faire.

Les commandes `pnpm backend:check`, `authority:check`, `data-policy:check`,
`maintenance:check` et `ci:check` sont lancées par `package.json` avec
`powershell`, soit Windows PowerShell 5.1, alors que les workflows GitHub les
lancent avec `pwsh`, soit PowerShell 7. Les deux hôtes ne se comportent pas
identiquement : `ConvertFrom-Json` rend un `Decimal` conservant l'échelle sous 5.1
et un `Double` sous 7, si bien qu'un gate reconstruisant du texte depuis un JSON
peut passer en local et échouer sur le runner. T0051 a rencontré exactement cet
écart. Tout gate modifié doit donc être exécuté au moins une fois avec
`pwsh -NoProfile -File .\tests\<gate>\run.ps1` en plus de son script `pnpm`, et tout
nombre reconstruit doit être formaté explicitement, jamais laissé au rendu par
défaut du parseur.

La vérification manuelle du même jour porte sur un état réellement commité, hors
transaction annulée : un vol terminé de 168,28 NM avec 95 minutes déclarées règle
`35194` unités mineures avec un temps retenu de `0`, ce qui prouve l'écrêtage par
l'horloge serveur ; un vol interrompu règle `5000` ; le solde atteint `43040194`;
la réputation vaut `48`; l'avion reprend un brouillon immédiatement et son vol
clôturé reste en historique ; le rejeu de la même clé ne crée ni deuxième rapport,
ni deuxième événement, ni deuxième écriture. Quatre refus — deuxième clôture,
temps déclaré hors bornes, champ monétaire dans le rapport et clé réutilisée avec
un autre payload — laissent le registre et le solde inchangés, et `service_role`
n'a lui-même aucun `select` sur `flight_dispatches`. `ci:backend` reste réservé au
runner Linux : la course de deux clôtures concurrentes qu'il ajoute n'est pas
exécutable localement sous Windows et sa preuve est attendue de la CI.

Preuve T0057 du 3 août 2026 : `backend:check` passe avec 35 mutations, dont cinq
nouvelles qui détectent un seed divergeant de `eng/airports.json`, un chargement
du référentiel caché dans un commentaire SQL, une coordonnée hors bornes dans la
source, un référentiel rendu mutable par un rôle client et une commande de
dispatch qui n'interroge plus le référentiel. Sous Docker Desktop 29.6.2 et
PostgreSQL 17, deux resets appliquent les neuf migrations append-only, puis 18
fichiers/356 assertions pgTAP concluent par `Result: PASS`. Les types régénérés
n'ajoutent que la table `airports` en 27 lignes, sans toucher
`create_dispatch_draft`, et `backend:types:check` les confirme stables. Les gates
autorité et données passent avec 9 et 6 mutations.

La comparaison table ↔ source est rejouée localement avec la logique ajoutée au
harnais CI : 103 aérodromes attendus, 103 chargés, égalité exacte sur code, nom,
latitude, longitude et palier. Le référentiel rend `103|103|4|0|1` — 103 lignes,
103 codes uniques, quatre paliers, aucune coordonnée hors bornes et une seule
`schema_version`. Les apostrophes échappées de la projection reviennent intactes,
par exemple `Chicago O'Hare` et `Nice Cote d'Azur`.

La vérification manuelle du 3 août 2026 confirme sur la pile locale :
` lfpg `/`lfml` sont normalisés en `LFPG`/`LFML` et créent un seul brouillon
`cc9c4506-defc-4efc-8fab-d3968ebb81cc` horodaté
`2026-08-03T16:54:40.654855+00:00`; le rejeu de la même clé rend exactement la
même réponse à sept champs, donc le contrat T0047 est inchangé. Un départ
inconnu `ZZZZ`, une arrivée inconnue `ZZZZ` et un code mal formé `ABC` rendent
tous trois `SQLSTATE 22023` avec le message identique « Departure and arrival
must be distinct four-character ICAO codes. », ce qui rend un aérodrome inconnu
indiscernable d'un code invalide et interdit d'énumérer le référentiel ; aucun
brouillon n'est créé pour l'avion refusé. `authenticated` lit 103 aérodromes et
reçoit `SQLSTATE 42501` sur `insert`, `update` et `delete`; `anon` reçoit
`42501` en lecture. Cette preuve locale synthétique ne valide ni consommateur
desktop, ni cible distante, ni donnée réelle, et le harnais Linux `ci:backend`
n'est pas exécutable depuis Windows.

La PR #91 fusionne T0057 dans `main` au merge `df685b7`, sur le commit de tête
`05ccffd`, avec ses trois checks verts : `Audits, licences and SBOM` en
4 min 16 s, `Supabase PostgreSQL 17` en 3 min 15 s et `Windows multi-stack` en
17 min 16 s. Le job Linux exécute le harnais qui manquait : deux resets appliquant
la migration `20260803000300_bounded_airport_reference.sql`, la comparaison
`Airport reference matches eng/airports.json: 103 aerodromes, schema version 1.`,
les deux nouveaux fichiers pgTAP en `ok` avec `Result: PASS`, puis `Backend CI
passed: 2 resets, 18 pgTAP files, airport reference matching its canonical source,
concurrent idempotence, purchase, dispatch and flight start, isolated restore
replay, authoritative onboarding, stable types, loopback ports.` La comparaison
table ↔ source est donc prouvée par le harnais lui-même sur le runner Linux, et
non plus seulement rejouée à la main sous Windows avec sa logique.

Preuve T0052 du 4 août 2026 : typecheck, tests, couverture et build passent avec
21 fichiers/241 tests frontend exécutés, dont 66 nouveaux pour le dispatch
desktop et 2 pour l'exposition de la flotte déjà chargée ; 1 fichier/2 scénarios
runtime T0040 reste ignoré sans environnement explicite. La couverture globale
atteint 93,96 % des statements, 88,41 % des branches, 97,18 % des fonctions et
93,93 % des lignes, dont 98,34 % des statements et 94,06 % des branches sur
`features/flight-dispatch`; les seules lignes non couvertes sont les gardes de
réentrance et d'annulation du panneau. Les tests couvrent payload et headers
fermés — quatre headers exactement —, normalisation ` lfpg ` → `LFPG`, cible
distante, loopback en `https`, credentials, requête, fragment, chemin et URL
illisible, UUID non canoniques, ICAO invalides ou identiques, HTTP
400/401/403/409/422/429/500/503 sans lecture du corps, douze réponses non
conformes dont état, version, champ supplémentaire, divergence d'avion ou d'ICAO
et corps surdimensionné, panne réseau, annulation appelante et délai borné. Côté
panneau : zéro appel au rendu, sélection limitée aux avions chargés, refus local
sans bearer, double clic, retry à clé conservée, nouvelle clé par changement
d'avion ou d'aérodrome, refus et indisponibilité sans détail technique, refus
Auth qui efface la session, démontage, et absence de token, de clé anonyme et
d'identifiant de dispatch dans le DOM. La composition d'accueil prouve que le panneau
n'apparaît qu'après une flotte non vide et que `globalThis.fetch` n'est jamais
appelé. Le bundle produit ne contient ni JWT, ni credential de test, ni marqueur
`service_role`, ni nom de commande privilégiée. Les gates autorité, données et
maintenance passent avec 9, 6 et 8 mutations. Cette preuve jsdom/`fetch` injecté
ne valide ni WebView live, ni CSP de production, ni Edge Runtime, ni cible
distante, ni donnée réelle.

La PR #94 fusionne T0052 dans `main` au merge `9ea2493`, sur le commit
d'implémentation `c4c86f5`, avec ses trois checks verts : `Audits, licences and
SBOM` en 3 min 41 s, `Supabase PostgreSQL 17` en 3 min 11 s et `Windows
multi-stack` en 15 min 24 s. La première publication du même arbre, PR #92, avait
échoué sur le seul `SECRET_SCAN` : la règle amont `generic-api-key` de Gitleaks
8.24.3 mesure 3,62 d'entropie sur l'UUID d'idempotence cité dans la preuve
manuelle du ticket et le signale comme secret, alors que la valeur est synthétique
et sans système derrière elle. Comme l'action scanne toute la plage de commits
d'une Pull Request et qu'un force-push est interdit, l'arbre a été republié sur une
branche propre. La cause amont est traitée séparément par la PR #93 : `.gitleaks.toml`
étend le jeu de règles par défaut d'une exception unique à `matchCondition = "AND"`,
exigeant à la fois le chemin d'un ticket et la forme UUID d'une valeur
`"idempotencyKey"`, de sorte qu'un vrai secret dans le même fichier reste signalé.

Preuve T0053 du 4 août 2026 : typecheck, tests, couverture et build passent avec
24 fichiers/297 tests frontend exécutés, dont 56 nouveaux pour la lecture des
dispatchs ; 1 fichier/2 scénarios runtime T0040 reste ignoré sans environnement
explicite. Le domaine `features/flight-dispatch` passe de 4 fichiers/66 tests à
7 fichiers/122 tests. La couverture globale atteint 94,46 % des statements,
88,96 % des branches, 97,51 % des fonctions et 94,42 % des lignes, dont 98,01 %
des statements et 93,27 % des branches sur `features/flight-dispatch`, et 98,87 %
des statements sur le seul module de lecture ; les seules lignes non couvertes
sont les gardes de réentrance et d'annulation du panneau et une branche de flux
borné. Les tests du transport couvrent l'URL complète, la projection, l'ordre et
la limite exacts, l'absence des paramètres `company_id`, `owner_id`,
`aircraft_id`, `id` et `state`, les quatre headers et l'absence de corps, la
liste vide, l'état `active`, la limite exacte de 50 puis 51 lignes refusées, les
doublons d'identifiant et d'avion, treize lignes non conformes dont clé
supplémentaire, clé manquante, UUID, ICAO, aéroports identiques, état inconnu,
horodatage non canonique ou impossible et version inattendue, une enveloppe non
tabulaire, un corps non JSON, une longueur déclarée hors borne, un corps
surdimensionné détecté en flux, les statuts 401/403 puis 404/429/500/503, une
panne réseau dont le message serveur n'est pas propagé, sept cibles refusées
avant tout appel et trois valeurs de header refusées avant tout appel. Côté
panneau : zéro lecture au rendu, liste vide explicite, chargement puis échec sans
rendu partiel, refus Auth qui efface la session, actualisation sur changement de
version, signal reçu pendant une lecture en cours et rejoué, absence de lecture
implicite quand le signal précède toute ouverture, lectures concurrentes bloquées
avec retry, annulation au démontage, et absence de token, d'identifiant de
dispatch et d'identifiant d'avion dans le DOM. La composition d'accueil prouve
que rien n'est appelé au rendu, que `globalThis.fetch` n'est jamais appelé et que
la source autoritaire est relue après une création réussie. Les gates autorité,
données et maintenance passent avec 9, 6 et 8 mutations, l'autorité déclarant
désormais quatre lectures Data API clientes. Cette preuve jsdom/`fetch` injecté ne
valide ni WebView live, ni CSP de production, ni RLS réelle, ni cible distante, ni
donnée réelle.

Preuve T0023 du 1er août 2026 : l'Edge Runtime réel est chargé sans nouveau port
hôte. Une identité/session/JWT synthétiques traverse Auth puis
`company-onboarding`; le rejeu rend les mêmes identifiants et PostgreSQL confirme
`1|1|1`. Un appel sans JWT rend HTTP 401. À cette date, les valeurs locales
`43000000`/`EUR` sont uniquement des fixtures serveur, pas une politique produit.
L'arrêt utilise `--no-backup` afin que le volume conservé ne contienne pas la
base synthétique ; une mutation statique refuse le retour au backup implicite.

Preuve T0028 du 2 août 2026 : quinze tests Node couvrent la politique v1
`43000000`/`EUR`, six politiques invalides, la tentative de surcharge par
environnement et les garanties T0023. Le gate backend exige
`eng/economy-policy.json`, sa copie embarquée identique et l'absence des deux
anciennes variables. Cette preuve valide le code local ; elle ne prouve aucun
déploiement distant ni admission de données réelles.

Preuve T0021 du 31 juillet 2026 sous Docker Desktop 29.6.2 : le daemon Supabase
isolé publie les trois ports externes uniquement sur `127.0.0.1`, confirmé par
Docker et les sockets Windows. Deux resets réussissent, 8 fichiers/148
assertions pgTAP concluent par `Result: PASS` et les types restent stables. Un
arrêt/redémarrage avec cache réussit en 45,5 s. Studio répond sur loopback ; son
inspection visuelle reste une vérification humaine distincte.

## Desktop et bridge

Le harnais bridge couvre le parsing strict, les jetons absents/incorrects, la
réponse REST versionnée et la négociation SignalR. Il couvre aussi les bornes des
échantillons, le replay synthétique, les offsets, les lignes surdimensionnées,
l'annulation, un faux adaptateur et l'absence de types SDK dans les contrats
publics. Les tests Rust vérifient les jetons et la sélection d'un port dynamique.

Depuis T0054, il couvre en plus la diffusion `telemetry.v1` : arguments de source
et de trace bornés, source close sans abonné, ordre et complétude des échantillons
validés, rejet d'un échantillon hors bornes, cadence prouvée sur un `TimeProvider`
manuel, conservation du seul dernier échantillon en attente, abandon d'un abonné
qui cesse de drainer sans retarder les autres, libération de l'adaptateur à
l'annulation, source native jamais requise, streaming de la trace synthétique à un
abonné WebSocket authentifié et refus de toute adresse autre que `127.0.0.1`. Le
harnais n'utilise aucun client SignalR tiers : il parle le protocole JSON du hub
sur `ClientWebSocket`.

Depuis F0004 J1, il couvre aussi le résumé de vol : mesure nominale mouvement →
dernier retour au sol, arrondi à la minute supérieure et minimum d'une minute,
départ en vol mesuré, puis trace sans retour au sol, touch-and-go finissant en
vol, taxi seul, trace vide et replay interrompu tous rendus `incomplete` sans
temps inventé, exposition `GET /api/v1/flight-summary` derrière le jeton et
absence de jeton comme de chemin de trace dans la réponse.

Depuis F0004 J2, les tests desktop couvrent le relais du résumé : côté Rust, la
validation stricte de la réponse du bridge (jeu de clés exact, version, états
fermés, cohérence du temps de bloc), les statuts non-200 et les réponses
malformées rendus en catégories fixes, et — contre un serveur factice — la
preuve que le jeton authentifie la requête sans jamais traverser dans le
résultat ; côté WebView, le rejet des résumés forgés et la classification des
échecs sans relayer leur contenu. Les invariants du shell
(`tests/desktop-shell/run.ps1` et `security-invariants.test.ts`) épinglent
l'unicité de la commande `flight_summary` et sa signature sans paramètre
invité.

Depuis F0004 J3, les tests frontend couvrent l'affichage du vol actif : aucune
lecture au rendu, mesure sur action explicite, états rendus distinctement
(temps de bloc d'un replay terminé, replay en cours, trace incomplète sans
temps inventé, indisponibilité en alerte avec retry), rattachement du contrôle
à la seule ligne `active` de la liste des dispatchs et composition d'accueil
sans réseau. Les invariants épinglent que le câblage
`flightSummaryShell.ts` ne transmet au shell que le nom de la commande, sans
autre argument, et que l'affichage ne recalcule aucun temps dans la WebView.

Depuis F0006, le harnais bridge (37 tests) couvre en plus les sessions de
mesure réarmables : un réarmement refusé pendant un streaming, deux vols
d'affilée mesurés sous deux générations distinctes, et le contrat local qui
exige le jeton sur `POST /api/v1/flight-summary/rearm` puis rejoue la source
jusqu'à un second `completed` sous la génération 2. Côté Tauri (21 tests
Rust), la validation stricte gagne `generation` (jamais projetée vers la
WebView), l'accusé d'armement et le refus `rejected` ; le harnais du shell et
`security-invariants.test.ts` épinglent **exactement deux** commandes IPC et
leurs signatures. Côté frontend (427 tests), l'armement au départ du vol est
prouvé non bloquant (échec silencieux, jamais avant un départ réussi) et
l'affichage échoue fermé sur toute mesure non rattachée ou rattachée à un
autre vol, y compris avec deux vols actifs.

Depuis la racine :

```powershell
pnpm frontend:typecheck
pnpm frontend:test
pnpm frontend:coverage
pnpm frontend:build
pnpm desktop:check
pnpm desktop:test
pnpm desktop:build
pnpm frontend:measure
pnpm bridge:build
pnpm bridge:test
pnpm bridge:health
pnpm bridge:publish
pnpm product-version:check
pnpm windows:package:check
pnpm windows:package
pnpm windows:package:test
```

Le typecheck active notamment `strict`, `noUncheckedIndexedAccess`,
`exactOptionalPropertyTypes`, les contrôles d'inutilisés et n'émet aucun
fichier. Vitest/jsdom couvre les routes, la navigation, l'error boundary,
l'action de rechargement, les landmarks, le focus, l'absence d'appel réseau et
les invariants HTML/CSS/Tauri. La couverture est une observation, sans seuil
arbitraire.

Le contrôle desktop combine le frontend, le format Rust, `cargo check --locked`,
Clippy avec les avertissements refusés, les tests Rust et les invariants Tauri.
`desktop:build` reste un build Release sans bundle. `windows:package` ajoute
séparément un bundle NSIS x64 non signé après publication du bridge complet.

Le harnais T0014 contrôle la cible NSIS unique, le mode `currentUser`, WebView2
`downloadBootstrapper`, l'absence de signature/updater/permission d'écriture et
l'inclusion du bridge. Il prouve deux mutations négatives : installation
`perMachine` et ajout d'une cible MSI.

Depuis T0055, `windows:package` exécute d'abord `product-version:check`, refuse un
bundle NSIS qui ne porte pas la version produit, nomme l'artefact copié
`Thrustline-<version>-win-x64.exe` et inscrit `productVersion` et `channel` dans
le manifeste, désormais en `schemaVersion` `2`.

`windows:package:test` installe silencieusement dans une cible explicite sous
`artifacts/t0014`, compare la version et le nom d'installateur du manifeste à la
source canonique, compare le hash de l'installateur et du bridge au manifeste,
confirme les trois statuts Authenticode `NotSigned`, ouvre la fenêtre
`Thrustline`, observe un seul bridge, ferme les deux processus, exécute
`Healthy`/`0`, désinstalle et exige la disparition de la cible. Ce parcours
modifie temporairement le profil utilisateur via NSIS ; il doit être exécuté sur
un poste ou une VM de validation, pas dans le job CI.

La mesure exige une fenêtre réellement visible, cinq lancements froids, cinq
lancements chauds et dix cycles de fermeture. Un échec de fenêtre ou un
processus orphelin rend le script non conforme.

Le bridge refuse les avertissements .NET et utilise nullable ainsi que les
analyseurs recommandés. Son harnais sans package tiers couvre les transitions de
santé, le diagnostic, les arguments invalides et l'annulation. La publication
produit un dossier self-contained `win-x64` ; single-file, trimming et AOT ne
sont pas activés sans mesure.

Une trace synthétique prouve le replay déterministe sans MSFS. Elle ne remplace
ni une trace enregistrée avec provenance, ni les fiches Store/Steam exigées par
ADR-0003.

## Budgets stabilité et performance

La source unique `eng/stability-performance-budgets.json` distingue les budgets
de fondation automatisés des objectifs de release encore `Not measured`.

Depuis la racine :

```powershell
pnpm performance:test
pnpm performance:measure:bridge
pnpm performance:check -- `
  -BridgeMeasurementsPath .\artifacts\t0015\bridge-measurements.json
pnpm performance:check:build
```

`performance:test` couvre une mesure conforme et quatre mutations négatives.
`performance:check:build` contrôle les tailles réellement construites du bundle,
des artefacts desktop et de la publication bridge sans lancer l'application.
La CI Windows exécute ces deux gates après les builds.

La campagne GUI reste locale :

```powershell
pnpm frontend:measure
pnpm performance:check -- `
  -FrontendMeasurementsPath .\artifacts\t0008\frontend-measurements.json `
  -DesktopMeasurementsPath .\artifacts\t0008\tauri-shell-measurements.json
```

Elle exige dix mesures avec un WebView2 associé, dix cycles propres et zéro
processus orphelin desktop ou bridge. Le harness publie puis stage le bridge dans
le layout de ressources Release exigé par Tauri. Les cycles rapides sont testés
avant les mesures longues et attendent la terminaison du bridge associé ; tout
nettoyage forcé reste un échec. Une sortie avant 30 ou 60 secondes est un échec.
Un budget ne peut être relevé qu'avec une mesure comparable et une revue
explicite.

## CI multi-stack et supply chain

T0013 ajoute deux workflows GitHub sans permission d'écriture :

- `CI` utilise `windows-2025` pour frontend, Tauri et bridge, puis
  `ubuntu-24.04` pour PostgreSQL 17, deux resets, pgTAP et types ;
- `Supply chain` utilise `ubuntu-24.04` pour les audits pnpm/NuGet/Cargo, le
  rapport de licences, Gitleaks et un SBOM SPDX JSON.

Chaque action est épinglée par SHA, checkout ne conserve pas ses credentials et
aucun cache de dépendances n'est activé. Les artefacts sont nommés comme non
signés ou comme preuves supply-chain et expirent après 30 jours.

Le harnais statique local couvre aussi deux mutations négatives :

```powershell
pnpm ci:check
```

La génération locale du rapport de licences exige les dépendances restaurées :

```powershell
pnpm supply-chain:report
```

Le gate d'avis Cargo T0058 se contrôle sans `cargo-audit` installé, avec le
harnais statique et ses huit mutations négatives :

```powershell
pnpm supply-chain:cargo:check
```

La comparaison au vrai rapport exige `cargo-audit` 0.22.2. Elle s'exécute
localement sur le lockfile, ou en CI sur le rapport JSON déjà produit :

```powershell
pnpm supply-chain:cargo
```

Le job backend Linux utilise `pnpm ci:backend`. Il masque la sortie de démarrage,
inspecte les ports Docker réels, exige tous les fichiers pgTAP attendus et
`Result: PASS`,
compare les types en mémoire et arrête la pile dans le script ainsi que dans une
étape `always()`.

T0020 étend ce gate à 8 fichiers pgTAP et 148 assertions. La CI doit aussi
prouver deux appels concurrents identiques vers l'ouverture financière qui
convergent vers une seule écriture immuable, puis conserver la preuve T0019 de
restauration/replay et la stabilité des types générés.

Le workflow supply-chain laisse chaque scanner produire son rapport, même si un
scanner échoue, puis un gate final agrège les résultats. T0013 a ainsi détecté
`GHSA-qwww-vcr4-c8h2` dans `react-router` 7.18.1. T0016 épingle 8.3.0 et l'audit
local du 29 juillet 2026 ne trouve plus de vulnérabilité connue ; la preuve
GitHub `30440480513` confirme ensuite tous les gates supply-chain verts et résout
`KI-018`. L'audit NuGet ne trouve aucun package vulnérable et Cargo ne trouve
aucune vulnérabilité, mais signale quinze avertissements informatifs. T0058 les
borne : `eng/cargo-advisory-allowlist.json` justifie chacun d'eux et le gate
échoue sur tout avertissement non revu, toute dérive de crate, version ou nature,
toute entrée périmée et toute liste expirée. `KI-019` est résolu par ce contrôle,
sans revendiquer la disparition des crates concernées.

Les commandes locales ne prouvent pas l'interprétation YAML ni l'exécution des
runners GitHub. Pour T0013, les jobs de la PR et les artefacts ont été inspectés
avant fusion sans trouver de credential. Toute modification future des workflows
doit répéter cette vérification avant promotion.

La PR #98 fusionne T0058 dans `main` au merge `2a07113`, sur le commit de tête
`52eb513`, avec ses trois checks verts : `Audits, licences and SBOM` en 4 min 5 s,
`Supabase PostgreSQL 17` en 3 min 15 s et `Windows multi-stack` en 15 min 52 s.
L'interprétation YAML des deux nouvelles étapes est donc prouvée par les runners :
`Validate Cargo advisory allowlist` exécute le harnais statique dans le job
Windows, et le job supply-chain compare le rapport réel de `cargo-audit` 0.22.2.

La première publication du même arbre, au commit de merge `96a4072`, avait échoué
sur `Windows multi-stack` à l'étape `Validate maintenance governance`, avec
`Ticket T0057 status differs: index 'Review', file 'Done'.` La cause est étrangère
à T0058 : ce commit fusionnait `main` dans la branche et a résolu la ligne T0057
de `docs/tickets/README.md` du côté branche, réintroduisant `Review` alors que la
PR #97 avait posé `Done` dans `main` et que le fichier du ticket porte
`Status: Done`. Le gate de maintenance T0030 a détecté la divergence exactement
comme prévu. Le correctif `52eb513` rétablit `Done` dans l'index ; le reste du
merge n'avait rien perdu de `main`. Un merge de `main` vers une branche doit donc
faire vérifier chaque statut ticket/index résolu, la résolution silencieuse du
côté branche étant indétectable sans ce gate.

Preuves CI des deux autres fusions du 4 août 2026, relevées pour lever la réserve
« checks GitHub restant à confirmer » de leurs tickets :

| PR | Ticket | Merge | Commit de tête | Audits, licences and SBOM | Supabase PostgreSQL 17 | Windows multi-stack |
| --- | --- | --- | --- | --- | --- | --- |
| #96 | T0053 | `87c4eec` | `57fc036` | 4 min 4 s | 2 min 57 s | 15 min 43 s |
| #99 | T0054 | `3a2c292` | `fd4716d` | 4 min 1 s | 3 min 7 s | 15 min 55 s |

Les six checks passent. Ces exécutions ne prouvent que ce que leurs jobs
contiennent : le job Windows couvre le frontend, le desktop, le bridge, les
budgets et le packaging non signé, et le job Linux la pile Supabase. Aucun des
deux ne prouve une WebView live, un Edge Runtime réel, une session MSFS 2024 ni
une cible distante.

## Preuve de location T0032

T0032 ajoute deux fichiers pgTAP. Ils doivent porter le total backend à 22
fichiers et couvrir structure, ACL/RLS, termes 30 jours/24 heures, loyer autoré
dans sa bande, frais de mise en service de dix loyers, premier loyer à
l'activation, rejeu et collision, isolation A/B/anonyme, borne de grâce
72 heures, suspension de l'avion pendant la grâce et rétablissement après
rattrapage, rattrapage ordonné, défaut, expiration, préavis et pénalité de
résiliation plafonnée, refus sur solde insuffisant, refus sur échéance déjà
exigible, rollback injecté et historique immuable. Un run qui ne découvre que les
20 fichiers antérieurs n'est pas une preuve T0032.

Mesure du 4 août 2026 : deux resets PostgreSQL 17 consécutifs, puis 22 fichiers
et **502 assertions réellement découvertes** au vert, dont 43 de comportement et
32 de structure pour T0032. Les types régénérés correspondent au schéma local.

Le gate backend classe les trois commandes privilégiées et rejette tout grant
client, toute mutation directe, ainsi que l'ajout de termes, compagnie, état ou
temps à la création. La convergence sous
concurrence n'est pas mesurable sur Windows : `scripts/ci/test-backend.ps1`
refuse toute machine autre que le runner Linux, donc sa fixture de location a été
rejouée à la main contre la base locale et sa course reste à confirmer en CI. La
preuve locale ne remplace pas l'ordonnanceur distant, explicitement absent.

## Preuve d'opposabilité de la fin d'usage T0060

T0060 ajoute un fichier pgTAP, `aircraft_usability_guard.test.sql`, qui porte le
total backend à 23 fichiers. Un run qui ne découvre que les 22 fichiers antérieurs
n'est pas une preuve T0060. Ses scénarios produisent chaque état inutilisable par
les commandes de location réelles — suspension pendant la grâce, défaut à la borne
de grâce, prise d'effet d'un préavis et expiration d'un contrat intégralement payé
— puis vérifient aux deux bornes le refus d'un brouillon et le refus du départ
d'un brouillon créé quand l'avion était encore utilisable. Ils comparent aussi les
refus caractère par caractère à ceux d'un avion et d'un dispatch appartenant à une
autre compagnie, confirment qu'un avion acheté comptant et un avion sous location
`active` restent dispatchables et démarrables, qu'un retour `grace` → `active`
redonne le droit au brouillon, qu'un vol déjà en cours se clôture et se règle
pendant que l'avion est inutilisable avant de refuser le brouillon suivant, que le
rejeu d'un départ acquis avant la perte d'usage rend une réponse identique tant
que le dispatch est encore `active` — la garde ne s'applique donc pas à une
commande déjà acquise —, et que `anon` comme `authenticated` restent privés
d'`execute` sur les deux commandes et d'`update` sur `public.company_aircraft`.
Le rejeu d'un départ postérieur à la clôture du vol n'était pas couvert par T0060 ;
il l'est par T0065, dont la preuve est décrite plus bas.

Mesure du 5 août 2026, sous Windows 11, Docker Desktop 29.6.2 et PostgreSQL 17 :
deux resets consécutifs appliquent les onze migrations livrées puis la douzième,
`20260805000100_aircraft_usability_guard.sql`, et 23 fichiers /
**539 assertions réellement découvertes** concluent par `Result: PASS`, soit 37
assertions nouvelles. `backend:types:check` confirme que les types régénérés sont
inchangés : la migration ne remplace que des corps de fonction, jamais une
signature ni une colonne.

Le gate backend passe avec **50 scénarios de mutation**, dont six nouveaux :
garde retirée de la création de brouillon, garde retirée du départ de vol, garde
dégradée en `raise warning`, message générique remplacé par un message qui nomme la
location, `execute` accordé à `authenticated`, et paramètre d'usage ajouté à la
signature. Parce que la garde réécrit deux fonctions en bloc, la même série
réaffirme contre le nouveau fichier les invariants dont la définition vivante a
changé de fichier : appartenance de l'avion, bornes du référentiel d'aérodromes
T0057 et son refus opaque, exclusivité limitée aux dispatchs ouverts T0051, blocage
d'un compte en suppression, registres d'idempotence et formes de réponse à sept et
cinq champs. Deux contrôles de position complètent la série : la garde d'usage doit
précéder le contrôle d'exclusivité, et elle doit suivre le chemin de rejeu du
départ de vol. Le gate a été exécuté sous les deux hôtes, Windows PowerShell 5.1
via `pnpm backend:check` et PowerShell 7 via
`pwsh -NoProfile -File .\tests\backend\run.ps1`.

La course concurrente ajoutée à `scripts/ci/test-backend.ps1` — une commande
temporelle qui retire l'usage pendant qu'un brouillon est créé sur le même avion —
n'est pas exécutable sous Windows : le harnais refuse toute machine autre que le
runner Linux. Elle est prouvée sur la PR #112, run `31002454980`, où le job
`Supabase PostgreSQL 17` réussit en 3 min 32 s et rend lui-même
`aircraft_usability_guard.test.sql .......... ok`, `Files=23, Tests=539`,
`Result: PASS`, puis
`Aircraft usability concurrency passed: 2 sessions, 1 temporal command, unusable
aircraft, no dispatch and no orphan command.` et
`Backend CI passed: 2 resets, 23 pgTAP files, ... aircraft lease and aircraft
usability withdrawal, ...`. La session temporelle ouvre 750 ms avant la session de
dispatch et tient la ligne d'avion quatre secondes, comme les courses de location,
d'achat, de dispatch et de clôture déjà en place ; l'état attendu après la course
est `0|0|0|1` — aucun brouillon, aucune commande orpheline, avion inutilisable et
une seule commande temporelle.

## Preuve de restitution du rejeu de départ T0065

T0065 ajoute un fichier pgTAP, `flight_start_replay_fidelity.test.sql`, qui porte le
total backend à 24 fichiers et 552 assertions. Un run qui ne découvre que les
23 fichiers antérieurs n'est pas une preuve T0065. Son ordre est sa valeur : le
scénario T0050 rejoue **avant** `close_flight` et ne peut donc pas échouer sur
`KI-024`, tandis que celui-ci clôture d'abord — un vol `completed` et un vol
`interrupted` — puis rejoue. Le gate vérifie cet ordre plutôt que de le confier à
une consigne de revue.

Mesure du 5 août 2026, sous Windows 11, Docker Desktop 29.6.2 et PostgreSQL 17 :
deux resets consécutifs appliquent les douze migrations livrées puis la treizième,
`20260805000200_flight_start_replay_fidelity.sql`, et 24 fichiers /
**552 assertions réellement découvertes** concluent par `Result: PASS`, soit
13 assertions nouvelles. `backend:types:check` rend `Database types match the local
schema.` : la migration ne remplace qu'un corps de fonction.

Le gate backend passe avec **58 scénarios de mutation**, dont huit nouveaux :
`state` rejoué depuis la ligne vivante, `startedAt` rejoué depuis la ligne vivante,
`aircraftId` reconstruit depuis le dispatch au lieu du registre, garde d'usage T0060
retirée de la redéfinition, transition élargie au-delà de `draft`, `execute` accordé
à `authenticated`, scénario pgTAP manquant, et scénario qui ne clôture jamais le vol
avant d'affirmer le rejeu. Parce que c'est la troisième redéfinition de
`start_flight_from_dispatch`, la même série réaffirme contre le nouveau fichier les
invariants T0050 et la garde T0060 : empreinte de payload, refus de collision de
clé, registre privé, transition `draft` seule, blocage d'un compte en suppression,
verrou de compagnie dérivé du serveur, verrou de l'avion et refus opaque. Un contrôle
de position exige que la garde d'usage reste après le chemin de rejeu, et un contrôle
de contenu interdit dans ce chemin toute lecture de `state`, `started_at` ou
`closed_at` de la ligne de dispatch vivante.

Vérification manuelle du même jour, sur **état réellement commité** hors transaction
annulée : un départ acquis rend `state = active` et un `startedAt` serveur ; la
clôture rend `completed`, `distanceNm = 168.28` et `settledAmountMinor = 35194` ; la
ligne de dispatch vivante rend ensuite `completed | departure kept | closed` ; le
rejeu de la même clé rend une réponse **identique champ par champ** à l'acquisition,
avec `state = active` ; l'état final est `1|1|0|1|2|43035194` — une commande de
départ, un dispatch, aucun vol actif, un rapport, deux écritures et un solde
inchangé par le rejeu ; un départ frais du dispatch clôturé reste refusé par
`Dispatch is unavailable for flight start.`

Deux limites sont consignées. Le fichier pgTAP de T0065 n'est pas nommé dans la liste
explicite de `scripts/ci/test-backend.ps1`, hors des `Allowed areas` du ticket : il
est bien exécuté et un échec ferait tomber `Result: PASS`, mais son nom et le
décompte « twenty-three » de ce script restent à mettre à jour par un suivi. Et
`backend:test` s'exécute sur les sources copiées dans le runtime isolé par
`backend:start` : après modification d'un fichier pgTAP, `backend:reset` seul rejoue
l'ancienne copie et peut faire croire à un échec — ou à une réussite — qui n'est plus
celui du fichier de travail. Constaté le 5 août 2026 pendant ce ticket.
