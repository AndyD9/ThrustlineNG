# Qualité du dépôt

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
les dix-huit fichiers pgTAP et conclure par `Result: PASS`; un code 0 sans test
découvert n'est pas une réussite. Les 356 assertions couvrent le cycle de compte
T0018, le replay T0019, le grand livre T0020, l'onboarding T0022, l'achat
T0029, le dispatch T0047, le démarrage de vol T0050 et le référentiel
d'aérodromes T0057. `backend:test` s'exécute sur les sources copiées dans le
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
clôture, cible distante ou donnée réelle ; T0050 est empilé sur T0049.

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

`windows:package:test` installe silencieusement dans une cible explicite sous
`artifacts/t0014`, compare le hash de l'installateur et du bridge au manifeste,
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
aucune vulnérabilité, mais signale des avertissements informatifs suivis par
`KI-019`.

Les commandes locales ne prouvent pas l'interprétation YAML ni l'exécution des
runners GitHub. Pour T0013, les jobs de la PR et les artefacts ont été inspectés
avant fusion sans trouver de credential. Toute modification future des workflows
doit répéter cette vérification avant promotion.
