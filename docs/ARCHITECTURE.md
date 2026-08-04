# Architecture du desktop

## Cycle de vie des données T0017–T0019

`eng/data-policy.json` est la source canonique des catégories, environnements,
durées maximales et capacités de cycle de vie. `docs/DATA_POLICY.md` en donne la
lecture humaine. La CI refuse les données de production hors production, une
catégorie obligatoire absente ou une durée supérieure aux maxima.

```text
collecte minimale
  → état actif autorisé
  → demande vérifiée / durée atteinte
  → effacement ou anonymisation irréversible
  → expiration des sauvegardes sous 30 jours
```

Une restauration reste fermée aux utilisateurs jusqu'au contrôle d'intégrité et
au replay des suppressions postérieures au point restauré. T0019 prouve ce
chemin uniquement sur une base PostgreSQL 17 CI synthétique, distincte et non
servie par PostgREST. Purge, sauvegarde managée et promotion d'une cible
restaurée restent non implémentées.

T0018 ajoute une migration append-only sans modifier la FK T0012. Trois
commandes authentifiées demandent la suppression, récupèrent l'export et
annulent pendant une fenêtre de 7 jours ; elles exigent une nouvelle session
Supabase de 5 minutes au plus. Une quatrième commande, exécutable seulement par
`service_role`, finalise la suppression dans une transaction. Les tables de
cycle de vie sont dans `private`, sans privilège API et avec RLS activée/forcée.
T0022 retire ensuite toute mutation directe de `companies` aux rôles clients ;
le cycle T0018 reste l'unique voie de suppression.

T0019 crée pour chaque compagnie un sujet de restauration opaque dans
`private`. La finalisation écrit atomiquement un événement pseudonyme versionné
avant de supprimer la correspondance active. Après restauration, une commande
`service_role` applique cet événement, compare tout rejeu à l'enregistrement
exact et échoue fermée sur un sujet absent ou un contenu différent. Le jeton
reste traité comme personnel tant qu'une sauvegarde permet de le relier au
compte.

T0020 ajoute un sujet financier UUID privé par compagnie et une table d'écritures
append-only sans identité Auth, identifiant ou nom de compagnie. La première
commande économique, `post_company_opening_balance`, est réservée à
`service_role`, verrouille la compagnie et compare exactement clé
d'idempotence, montant et devise avant tout rejeu. `authenticated` dispose
uniquement de `get_company_ledger()`, qui dérive la compagnie de `auth.uid()` ;
aucune mutation financière directe n'est exposée à un client.

La suppression T0018 et son replay T0019 déclenchent le détachement transactionnel
du lien compagnie–sujet. Les écritures restent immuables et ne conservent que le
sujet opaque nécessaire à l'intégrité. Cette première tranche n'est pas une
comptabilité en partie double et ne définit encore ni revenus, ni coûts, ni
clôture de vol.

T0022 ajoute `create_company_with_opening_balance`, réservée à `service_role`.
La commande verrouille l'identité Auth non anonyme, lie la clé d'idempotence à
l'intégralité du payload, crée la compagnie et appelle l'ouverture T0020 dans la
même transaction. Les triggers créent aussi les sujets privés de restauration
et de grand livre. Un rejeu identique rend les mêmes identifiants ; une collision,
une deuxième compagnie ou une panne annule tout le statement. Cette frontière
n'ajoute encore aucun appelant applicatif direct.

T0023 place cette RPC derrière l'Edge Function `company-onboarding`. Le client
envoie uniquement un nom normalisé et une clé d'idempotence. La fonction vérifie
le bearer token auprès de Supabase Auth, dérive `owner_id` de l'utilisateur non
anonyme et lit montant/devise depuis la projection embarquée de la politique
T0028 avant d'appeler T0022 avec `service_role`. `eng/economy-policy.json` fixe
la v1 à `43000000` unités mineures en `EUR`; le gate exige que la copie livrée
avec la fonction soit strictement identique et interdit les anciennes surcharges
par environnement. La fonction ne fractionne donc pas la transaction SQL et ne
livre jamais le credential privilégié au desktop. Aucun appelant desktop, CORS
applicatif ou déploiement distant n'est encore fourni.

T0029 ajoute `purchase_aircraft`, réservée à `service_role`. La commande dérive
la compagnie du propriétaire fourni par la future frontière serveur, verrouille
compagnie, sujet financier puis offre unitaire, et calcule le solde depuis les
écritures immuables. Offre, avion possédé, débit `aircraft_purchase` négatif et
registre d'idempotence sont modifiés dans un seul statement transactionnel. Le
client authentifié ne reçoit que les offres actives et ses avions via RLS et
`get_company_aircraft()` ; il ne peut fournir ni prix, ni devise, ni compagnie
à la commande.

T0035 ajoute `aircraft-purchase`, une Edge Function séparée qui accepte seulement
`offerId` et `idempotencyKey`, vérifie la session auprès de Supabase Auth, dérive
le propriétaire du JWT puis appelle `purchase_aircraft` avec `service_role`.
Elle borne corps et appels amont, redige les rejets et allowliste la réponse.
Cette tranche couvre uniquement l'achat synthétique authentifié : appelant
desktop, location, déploiement distant et catalogue de production restent
absents.

## Inventaire d'autorité T0024

`eng/authority-inventory.json` relie les dix étapes du golden path aux domaines
qui peuvent modifier propriété, compte, argent, vol ou progression. Une capacité
présente est `server-authoritative` ou `external-authority`; une capacité absente
reste `not-implemented` et ne franchit aucun gate fonctionnel par défaut.

Les trois composants distribués sont inventoriés comme surfaces non fiables :

```text
WebView React ─┐
Tauri/Rust ────┼─ demande validée → frontière serveur → transaction autoritaire
bridge .NET ───┘
```

Le gate `authority:check` refuse dans leurs sources le credential privilégié,
les commandes `service_role`, tout accès Data API non classé, le DML Supabase ou
SQL direct et toute nouvelle extension de code non classée. Cette preuve décrit
le nouveau dépôt uniquement ; elle n'implémente pas les domaines encore absents.

T0043 et T0044 classent deux lectures Data API depuis des transports desktop
séparés : `aircraft_purchase_offers` et `companies`. Chaque chemin source et sa
ressource sont déclarés dans l'inventaire ; tout autre fichier, ressource
divergente, chemin dupliqué ou entrée orpheline fait échouer le gate. Les requêtes
restent des `GET` à projection et limite constantes ; le catalogue ajoute filtre
et ordre constants. La présence de compagnie est immédiatement réduite à un
booléen avant la composition React. Ces lectures n'autorisent aucune mutation
Data API.

T0045 compose le résultat validé du catalogue avec la commande Edge T0037 sans
fusionner les transports : la sélection ne peut référencer qu'une offre chargée,
et le panneau d'achat obtient le bearer depuis le gestionnaire de session à la
soumission. Le payload serveur reste limité à l'offre et à l'idempotence ; prix,
devise, compagnie, propriétaire et solde ne traversent pas cette frontière comme
autorité cliente.

T0046 ajoute un troisième transport Data API desktop vers `company_aircraft`.
Sa projection, son ordre et sa limite sont constants ; aucun identifiant de
compagnie ou propriétaire ne sert de filtre client. La RLS T0029 sélectionne la
flotte du sujet Auth, puis le transport valide strictement la réponse avant que
le panneau ne la rende. Le succès d'achat ne construit aucun avion localement :
il signale seulement au panneau déjà chargé de relire la source autoritaire.

T0047 ouvre le domaine dispatch par une migration serveur append-only. La
commande `create_dispatch_draft`, réservée à `service_role`, reçoit uniquement
le propriétaire vérifié par la frontière T0048, une clé d'idempotence, un
avion et deux codes ICAO. Elle verrouille la compagnie puis l'avion, dérive la
compagnie depuis le propriétaire, vérifie l'appartenance et persiste dans une
transaction un brouillon `draft` horodaté par PostgreSQL avec son registre privé.

`flight_dispatches` force RLS et reste en lecture seule pour `authenticated`,
filtrée par la compagnie du sujet Auth. Une contrainte et le verrou d'avion
garantissent un seul brouillon actif par avion. T0048 ajoute l'Edge Function
`dispatch-draft` : elle borne le corps à 4 Kio, vérifie le bearer auprès d'Auth,
dérive le propriétaire, normalise les ICAO puis appelle la RPC avec le credential
`service_role` sous délai de cinq secondes. Elle projette uniquement la réponse
publique versionnée et `no-store`. Aucun transport desktop, SimBrief, transition
ou runtime de vol n'est fourni.

T0050 ouvre le domaine `flight-runtime` par une seconde migration append-only qui
ne réécrit pas T0047. Elle remplace la contrainte `draft` unique par une liste
fermée de deux états connus, `draft` et `active`, et ajoute un horodatage de
départ `started_at` lié par contrainte au seul état `active`. La contrainte
`flight_dispatches_one_draft_per_aircraft` couvre désormais les deux états : un
avion n'a jamais plus d'un dispatch, brouillon ou vol. Un trigger `before insert
or update` dérive `started_at` de `clock_timestamp()` au passage à `active`, le
conserve ensuite et le remet à null pour un brouillon, de sorte qu'aucun appelant
ne peut fournir ni remplacer ce temps.

La commande `start_flight_from_dispatch`, réservée à `service_role`, reçoit
uniquement le propriétaire vérifié en amont, une clé d'idempotence et un
dispatch. Elle verrouille la compagnie du propriétaire puis le dispatch, dérive
la compagnie et l'avion du serveur, refuse un compte en suppression et n'accepte
que la transition `draft` → `active` dans une seule transaction. Un dispatch
inconnu, étranger ou déjà actif rend le même refus opaque. Le registre privé
`private.flight_start_commands` lie `(owner_id, idempotency_key)` à l'empreinte
du payload et n'admet qu'un démarrage par dispatch ; un rejeu identique rend la
même réponse versionnée à cinq champs. Aucune frontière Auth, appelant desktop,
télémétrie, clôture ni écriture financière n'est fournie.

T0057 ajoute un référentiel d'aérodromes borné par une troisième migration
append-only qui ne réécrit ni T0047 ni T0050. `public.airports` porte un code
ICAO en clé primaire, un nom borné, une latitude et une longitude en
`numeric` à quatre décimales contraintes à `[-90, 90]` et `[-180, 180]`, un
palier de popularité pris dans une liste fermée de quatre valeurs ordonnées
— `regional`, `standard`, `major`, `hub` — et une `schema_version` contrainte.
La table force RLS, n'accorde que `select` à `authenticated` par une politique
unique et ne donne aucune mutation à `anon`, `authenticated` ou `service_role`.

La source canonique est `eng/airports.json` ; `supabase/seed.sql` en charge une
projection idempotente et le référentiel ne porte aucun montant ni
multiplicateur, la tarification restant à la politique de clôture qui le lira.
`backend:check` rejoue la projection depuis la source et échoue sur toute
divergence textuelle ; le harnais CI compare en plus la table réellement
chargée à la source, ligne par ligne.

La même migration remplace `create_dispatch_draft` par `create or replace` en
conservant sa signature, son contrat public, son idempotence et ses verrous : la
validation bornée exige désormais que les deux codes normalisés existent dans le
référentiel. Un code inconnu réutilise exactement le message de refus d'un code
mal formé, ce qui le rend indiscernable et empêche d'énumérer le référentiel.
Aucune lecture desktop, aucun sélecteur d'aérodromes et aucun calcul de
distance, de temps ou de revenu n'est fourni.

T0052 ajoute le premier appelant desktop du domaine dispatch en réappliquant le
patron T0037/T0045 : un module de commande borné plus un panneau mince, sans
nouvelle lecture Data API. Le module n'accepte qu'une cible loopback `http:` sans
identifiants, requête, fragment ni chemin, normalise les deux ICAO en majuscules
après trim, exige des UUID canoniques et deux codes distincts avant tout appel,
borne la requête à cinq secondes et la réponse lue à 16 Kio, puis valide les sept
champs publics avec `state: draft` et `schemaVersion: 1` en recoupant avion et
aérodromes avec la demande. Les échecs sont réduits à quatre catégories closes,
sans détail serveur.

Le panneau n'exécute aucun appel au rendu : la sélection est limitée aux avions
réellement chargés par le transport T0046, exposés sans changer sa requête, et le
bearer est obtenu du gestionnaire T0038 à la soumission. Une clé d'idempotence
reste stable par intention — avion et deux ICAO normalisés — et n'est renouvelée
que si l'intention change ; la double soumission est bloquée et la requête est
annulée au démontage. Le payload ne porte jamais propriétaire, compagnie, état,
temps ni route : ces valeurs restent dérivées par la frontière T0048 et la
commande T0047. Aucune lecture durable des dispatchs, transition de vol ou effet
financier n'est fourni.

## Packaging Windows T0014

Le package Windows est un installateur NSIS x64 en mode utilisateur courant.
La configuration commune Tauri reste indépendante du packaging ;
`tauri.package.conf.json`, chargée uniquement par la commande T0014, active NSIS
et inclut comme ressource le dossier complet du bridge .NET 10 publié
self-contained :

```text
installateur NSIS
├── thrustline-desktop.exe
└── bridge/
    ├── Thrustline.Bridge.exe
    └── runtime .NET self-contained
```

En Release, Tauri résout le bridge depuis `$RESOURCE/bridge/`. En Debug seulement,
`THRUSTLINE_BRIDGE_PATH` permet de viser une publication locale. Le package
n'ajoute ni plugin, ni capability invitée, ni service Windows, ni accès de la
WebView au système de fichiers ou au processus enfant.

Le bundle utilise WebView2 Evergreen et le mode `downloadBootstrapper`. Il
n'embarque ni runtime WebView2 fixe, ni updater. MSI, signature, provenance,
upgrade et rollback de version restent hors du socle.

## Backend Supabase local T0012

Le backend initial est recréé depuis `supabase/config.toml`, les migrations
append-only puis `supabase/seed.sql`. PostgreSQL 17, Auth, PostgREST et l'Edge
Runtime T0023 sont actifs localement ; Realtime, Storage et Analytics restent
désactivés. L'Edge Runtime reste derrière le port API 54321 : le daemon isolé
T0021 ne publie toujours que 54321–54323 sur `127.0.0.1`.

`public.companies` porte la première frontière de propriété du MVP solo :

```text
auth.users.id → companies.owner_id unique → une compagnie au plus par utilisateur
```

La clé étrangère impose un propriétaire Auth existant. La RLS est activée et
forcée. Après T0022, `authenticated` conserve uniquement `select` avec la
politique `auth.uid() = owner_id`; `insert`, `update` et `delete` directs sont
révoqués et leurs politiques supprimées. Les types versionnés sous
`packages/database` sont régénérés depuis la pile locale ; aucun client
applicatif ne les consomme encore.

## Télémétrie SimConnect T0011

`ISimConnectAdapter` est la seule frontière consommable par le futur moteur de
vol. Il émet des `FlightSample` validés et ne référence aucun type SDK.
`NativeSimConnectAdapter` charge la DLL officielle à l'exécution, ouvre la
connexion avec un handle d'événement et confine définitions, requête à 1 Hz,
dispatch et fermeture dans une boucle dédiée. Il ne publie encore aucun
échantillon sur REST ou SignalR.

`ReplaySimConnectAdapter` lit le même domaine depuis un JSON Lines versionné :

```text
en-tête format/schéma/source → échantillons à offsets monotones → FlightSample
```

Les traces sont non fiables : schéma strict, UTF-8 strict, ligne limitée à
16 Kio, valeurs bornées et contenu absent des erreurs. La trace livrée est
synthétique ; elle caractérise le pipeline, pas la fidélité d'un avion réel.

## Contrat local T0010

Tauri crée un jeton d'instance aléatoire de 256 bits et réserve un port
dynamique, puis lance le bridge .NET. Le bridge écoute uniquement sur
`127.0.0.1` et expose `GET /api/v1/health` et `/hubs/v1/bridge`. Chaque requête
porte `X-Thrustline-Instance`. Le jeton reste natif et la fermeture de la fenêtre
termine le processus enfant.

Le processus Rust/Tauri possède la fenêtre native et charge exclusivement le
build Vite local de `apps/desktop/dist`. Sous Windows, WRY s'appuie sur WebView2
Evergreen ; aucun Chromium ni runtime WebView2 Fixed Version n'est embarqué.

Le frontend T0008 est organisé par responsabilités :

```text
src/app      composition, routeur et error boundary
src/pages    pages associées aux routes
src/shared   unique composant UI réutilisable
src/styles   tokens et styles locaux
src/test     setup et invariants
```

L'alias TypeScript `@/*` désigne `src/*`. `HashRouter` est retenu parce que les
fichiers sont chargés sans serveur de réécriture dans Tauri ; il conserve
l'historique avant/arrière dans la WebView sans inventer de route serveur.

T0009 ajoute `apps/bridge`, un processus console .NET 10 indépendant. Sa logique
de cycle de vie ne dépend pas de `Console`, ce qui permet de tester le diagnostic
de santé et l'annulation. Le point d'entrée adapte uniquement Ctrl+C et
`ProcessExit` vers un `CancellationToken`.

La séparation reste :

```text
page locale → API Tauri explicitement autorisée → processus Rust
                                               → bridge .NET
```

Le bridge est lancé par Tauri et son port reste inaccessible à la WebView.
L'adaptateur T0011 n'élargit ni le contrat local, ni les capabilities.
