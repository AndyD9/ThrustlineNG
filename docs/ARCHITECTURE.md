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
même réponse versionnée à cinq champs.

F0001 fournit sa frontière et son appelant : l'Edge Function `flight-start`,
quatrième frontière sur le modèle exact de `dispatch-draft` (corps de 4 Kio
limité à `dispatchId` et `idempotencyKey`, bearer vérifié auprès d'Auth,
propriétaire dérivé, RPC en `service_role` sous cinq secondes, projection
`no-store` des cinq champs publics, refus indistinguables), prouvée sur l'Edge
Runtime local réel ; et, côté desktop, un transport borné à la cible loopback
plus un contrôle par ligne `draft` de la liste T0053 qui relit la source
autoritaire après un départ — la lecture expose désormais `started_at` pour un
vol `active`, validé nul pour un brouillon. Aucune télémétrie, clôture composée
ni écriture financière n'est fournie par cette capacité.

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

T0051 ferme le cycle serveur par une quatrième migration append-only qui ne
réécrit ni le grand livre T0020, ni l'achat T0029, ni le référentiel T0057. La
liste fermée d'états de dispatch passe à quatre valeurs, `completed` et
`interrupted` étant terminales et sans transition sortante, et une colonne
`closed_at` n'existe que pour ces deux états. L'unicité globale par avion devient
un index unique partiel limité à `draft` et `active` : un vol clôturé reste en
place comme historique et l'avion redevient immédiatement dispatchable, ce que la
validation de `create_dispatch_draft` suit désormais en ne regardant que les
dispatchs ouverts. Le registre privé de brouillons perd son unicité par avion,
devenue redondante avec cet index.

`eng/flight-settlement-policy.json` est la source canonique du barème, de son
plancher, de son plafond, des multiplicateurs de palier et des deltas de
réputation. La migration en embarque une projection stricte dans
`private.flight_settlement_policy()`, que `backend:check` reconstruit depuis la
source et compare texte à texte ; aucune valeur monétaire ne vient d'une variable
d'environnement ni d'un réglage de session. `private.airport_distance_nm` dérive
la distance en milles nautiques par formule de grand cercle depuis les deux
positions du référentiel et l'arrondit une seule fois, de sorte qu'une même paire
règle toujours le même montant.

`close_flight` écrit dans une seule transaction l'état terminal, un rapport
versionné unique par dispatch dans `private.flight_reports`, une écriture nette
positive `flight_settlement` dans le grand livre, un événement de réputation
append-only et son registre d'idempotence `private.flight_close_commands`. Le
rapport client ne porte qu'une nature de fin prise dans une liste fermée, un temps
de bloc déclaré borné et deux mesures facultatives bornées ; le temps retenu est
le minimum entre ce temps déclaré et le temps réellement écoulé côté serveur, et
montant, devise, distance et multiplicateur sont recalculés. La réputation reste
informative : `public.get_company_reputation` dérive la compagnie de `auth.uid()`
et rend un score borné `0–100` qui n'autorise, ne refuse et ne module aucune
capacité. Aucune frontière Auth, appelant desktop, annulation, télémétrie de
clôture ni SimBrief n'est fourni.

F0002 fournit sa frontière et son appelant : l'Edge Function `flight-close`,
cinquième frontière sur le modèle exact de `flight-start` (corps de 4 Kio limité
à `dispatchId`, `idempotencyKey` et un rapport strictement allowlisté, bearer
vérifié auprès d'Auth, propriétaire dérivé, RPC en `service_role` sous cinq
secondes, projection `no-store` de dix champs publics sans identifiant de grand
livre, refus indistinguables), prouvée sur l'Edge Runtime local réel ; et, côté
desktop, un transport borné à la cible loopback plus un contrôle par ligne
`active` qui lit d'abord le résumé mesuré F0004, n'envoie que
`{ outcome: "completed", blockMinutes mesuré }` (option C du 6 août 2026),
épingle la clé d'idempotence au rapport exact qu'elle a signé et relit flotte et
dispatchs après la clôture — la liste filtre désormais les états ouverts, la
sélection par ligne restant à la RLS. Aucune clôture `interrupted` depuis
l'application, annulation ni historique de vols n'est fourni.

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

T0053 ajoute la lecture durable manquante en réappliquant le patron T0046 dans un
module distinct du module de commande : la lecture est un `GET` unique vers
`flight_dispatches` dont la projection, l'ordre `created_at.desc,id.desc` et la
limite de cinquante lignes sont des constantes du client. Aucun filtre de
compagnie, de propriétaire, d'avion ou d'état n'est jamais envoyé : la RLS
`flight_dispatches_select_own` de T0047 reste l'unique autorité de sélection, et
un test d'invariants vérifie que les seuls paramètres construits sont `select`,
`order` et `limit`. La cible reste loopback `http:` sans identifiants, requête,
fragment ni chemin, la requête est bornée à cinq secondes et la réponse lue à
64 Kio en flux, avec annulation dès le dépassement.

Chaque ligne est validée strictement avant tout rendu : jeu de clés exact, UUID
canoniques pour le dispatch et l'avion, deux ICAO de quatre caractères ASCII
majuscules et distincts, état appartenant à `draft` ou `active` — la liste connue
depuis T0050 —, horodatage canonique et `schema_version` égal à `1`. La liste
refuse un tableau plus long que la limite ainsi que tout doublon d'identifiant ou
d'avion, ce dernier étant garanti unique par la contrainte
`flight_dispatches_one_draft_per_aircraft`. Les échecs sont réduits à
`authentication-required`, `invalid-response` et `unavailable`, sans détail
serveur.

Le panneau de lecture n'exécute aucun appel au rendu : il n'est composé que
lorsque la compagnie est connue et sa première lecture reste déclenchée par
l'utilisateur, comme la flotte T0046. Le bearer est obtenu du gestionnaire T0038
au chargement et un refus Auth efface la session. Une création réussie incrémente
un compteur d'actualisation porté par l'accueil ; le panneau relit alors la source
autoritaire au lieu de construire localement le dispatch créé, et un signal reçu
pendant une lecture en cours est rejoué à la fin de celle-ci plutôt que perdu.
L'absence de dispatch, le chargement et l'échec sont rendus explicitement, et la
requête est annulée au démontage. Aucune pagination, aucun tri ou filtre client,
aucune transition de vol et aucun effet financier n'est fourni.

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
dispatch et fermeture dans une boucle dédiée.

`ReplaySimConnectAdapter` lit le même domaine depuis un JSON Lines versionné :

```text
en-tête format/schéma/source → échantillons à offsets monotones → FlightSample
```

Les traces sont non fiables : schéma strict, UTF-8 strict, ligne limitée à
16 Kio, valeurs bornées et contenu absent des erreurs. La trace livrée est
synthétique ; elle caractérise le pipeline, pas la fidélité d'un avion réel.

## Diffusion bornée de la télémétrie T0054

T0054 relie cette source au contrat local sans l'élargir. La diffusion est un
seul chemin, additif au health check et à `/hubs/v1/bridge` :

```text
ISimConnectAdapter → TelemetryPublisher → 1 slot par abonné → telemetry.v1
```

`TelemetryPublisher` est la seule autorité de publication. Il n'ouvre la source
qu'à l'arrivée du premier abonné, valide chaque `FlightSample` avant diffusion,
cadence la lecture à un échantillon par seconde au plus et n'écrit jamais dans un
tampon non borné : chaque abonné possède un canal d'un seul élément en mode
`DropOldest`, donc un abonné lent perd les échantillons intermédiaires au lieu de
retarder la lecture ou les autres abonnés. Un envoi qui dépasse le délai borné
abandonne l'abonné et annule sa connexion. Le nom de message `telemetry.v1` est
versionné indépendamment du contrat `1`.

La source est choisie par option explicite du processus, `replay` par défaut :

```text
--telemetry-source replay|native   --telemetry-trace <fichier JSONL>
```

Sans trace, l'état reste `idle` et rien n'est publié ; c'est le cas du lancement
actuel par Tauri, qui ne passe que `--port`. La source `native` reste facultative
et son absence de SDK devient l'état `unavailable` sans faire échouer le
processus. Le health check expose `telemetrySource` et `telemetryState` comme
champs additifs, sans chemin de fichier, version de SDK ni jeton. Aucun
échantillon n'est persisté, relié à une compagnie, à un vol ou au grand livre, et
la WebView n'a toujours aucun accès au canal.

## Résumé de vol mesuré F0004 J1

Le bridge dérive des mêmes échantillons validés un résumé de vol exposé en
lecture seule sur `GET /api/v1/flight-summary`, derrière le même jeton
d'instance. `FlightSummaryTracker` observe le flux au moment de la diffusion,
sans persister aucun échantillon : il ne retient que le premier instant en
mouvement (vitesse sol non nulle ou airborne), le dernier retour au sol et le
dernier état au sol observé.

La règle décidée le 6 août 2026 s'applique à la fin du replay : temps de bloc du
premier échantillon en mouvement au dernier retour au sol de la trace, arrondi à
la minute supérieure, minimum une minute. Les états sont `idle` (aucun
échantillon observé), `running` (échantillons en cours), `completed` (trace
finie **au sol** et temps mesuré) et `incomplete` — aucun temps inventé — pour
tout le reste : trace finie sans retour au sol ou finissant en vol même après
un toucher, taxi seul sans décollage, trace vide, lecture interrompue après un
premier échantillon. La réponse
`{contractVersion, state, blockMinutes}` est additive : le health check,
`telemetry.v1` et ses bornes T0054 sont inchangés, et une lecture tronquée n'est
jamais présentée comme complète. Le temps mesuré reste une déclaration côté
client : `close_flight` conserve `min(déclaré, écoulé serveur)` (T0051).

Le relais vers la WebView (J2) est l'unique commande IPC du shell :
`flight_summary`, asynchrone, en lecture seule et sans aucun paramètre fourni
par la WebView. Le processus Rust — seul détenteur du port et du jeton
d'instance — interroge `GET /api/v1/flight-summary` sur le contrat local, puis
revalide la réponse par jeu de clés strict (exactement `contractVersion`,
`state`, `blockMinutes`, version `1`, états fermés, temps de bloc cohérent avec
l'état) avant de la faire traverser. Les échecs se réduisent à deux catégories
fixes, `unavailable` et `invalid-response`, sans contenu dynamique. Côté
WebView, `flightSummary.ts` revalide le même jeu de clés et ne dépend que de la
fonction `invoke` injectée : ni port, ni jeton, ni chemin de trace ne franchit
la frontière.

L'affichage (J3) rattache le résumé au vol actif de la liste des dispatchs :
`FlightSummaryControl`, rendu sur la seule ligne `active`, lit le résumé sur
action explicite — jamais au rendu — via `readFlightSummary` et le câblage
`flightSummaryShell.ts`, seul module qui touche
`window.__TAURI_INTERNALS__.invoke` et qui ne transmet que le nom de la
commande. La WebView ne calcule aucun temps : `blockMinutes` est affiché tel
que revalidé, avec des états explicites (replay en cours, temps de bloc
mesuré, trace incomplète sans temps inventé, indisponibilité). Le résumé du
bridge est global et sans identité de vol, et l'exclusivité serveur des
dispatchs ouverts est **par avion** (index
`flight_dispatches_one_open_per_aircraft`, T0051), pas par compagnie : deux
vols actifs sont possibles. L'affichage est donc fail-closed — le contrôle de
mesure n'est rendu que lorsqu'exactement un vol est actif ; au-delà, aucune
mesure n'est proposée plutôt qu'un temps attribuable au mauvais vol.

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

## Frontière temporelle de location T0032

La migration T0032 ajoute des termes de location versionnés aux offres serveur,
des contrats et échéances lisibles sous RLS, ainsi que des registres et événements
privés. `lease_aircraft`, `process_aircraft_lease` et
`terminate_aircraft_lease` sont des commandes `security definer` réservées à
`service_role`. La création verrouille compagnie, sujet financier puis offre ;
le rattrapage verrouille contrat puis sujet financier. Avion, contrat,
obligation et grand livre restent dans une même transaction.

`process_aircraft_lease` matérialise les échéances dans l'ordre du contrat. Son
temps effectif est une autorité privilégiée fournie par l'appelant serveur ; il
ne doit jamais être relayé depuis un client. La même commande porte les deux
transitions différées du contrat : la sortie de grâce quand les arriérés sont
soldés, et la finalisation d'un préavis de résiliation à la fin de la période
payée. `terminate_aircraft_lease` n'écrit donc jamais l'état terminal lui-même ;
il pose le préavis, prélève la pénalité plafonnée et laisse la frontière
temporelle conclure.

La migration étend la liste des types d'écriture du grand livre en conservant le
crédit `flight_settlement` de T0051 : toute migration financière ultérieure qui
recompose cette contrainte doit reprendre les types déjà livrés, sous peine de
désactiver silencieusement une capacité voisine.

Aucun cron, ordonnanceur distant, endpoint Edge, desktop ou bridge n'est ajouté
par T0032. `company_aircraft.is_usable` est écrit par les trois commandes ; la
dette « écrit mais lu par personne » qu'il consignait est fermée par T0060.

## Opposabilité de la fin d'usage T0060

La migration `20260805000100_aircraft_usability_guard.sql` rend
`public.company_aircraft.is_usable` opposable aux deux seules entrées qui mettent
un avion en service. Elle redéfinit en bloc `public.create_dispatch_draft` et
`public.start_flight_from_dispatch`, sans toucher aucune migration livrée et sans
ajouter de source d'inutilisabilité : les trois commandes de location restent la
seule autorité qui écrit cet état, les deux commandes de mise en service se
contentent de le lire sur la ligne d'avion dérivée du serveur et verrouillée.

L'ordre de verrouillage est documenté dans la migration et identique dans les deux
commandes : compagnie, puis dispatch, puis avion. `public.company_aircraft` est
toujours la dernière ligne verrouillée, exactement comme
`process_aircraft_lease` verrouille contrat puis sujet financier avant de toucher
l'avion, si bien qu'aucune paire (dispatch, location) ne forme de cycle de verrou.

Deux propriétés de conception sont volontaires. À la création d'un brouillon, la
garde d'usage est évaluée **avant** le contrôle d'exclusivité, pour qu'un avion
inutilisable rende le même refus opaque qu'il porte ou non un dispatch ouvert. Au
départ de vol, la garde est placée **après** le chemin de rejeu : un départ déjà
acquis alors que l'avion était utilisable n'est jamais refusé par la garde et ne
crée pas de second départ, celle-ci ne s'appliquant qu'à la transition fraîche
`draft` → `active`.

Ce chemin de rejeu **restitue** la réponse acquise depuis T0065, livré par la
migration `20260805000200_flight_start_replay_fidelity.sql` : `aircraftId`,
`dispatchId` et `startedAt` viennent du registre `private.flight_start_commands`,
écrit dans la transaction même qui a accordé le départ, `state` est le littéral
`active` — la ligne de registre n'existant qu'après une transition réussie — et
seul le `schema_version` immuable est encore lu sur la ligne de dispatch. Le rejeu
ne lit donc aucun champ qu'une clôture déplace ou effacerait, et rend les cinq
champs de l'acquisition même après un `close_flight`. Aucune colonne n'a été
ajoutée pour cela.

Avant T0065, ce chemin reconstruisait sa réponse depuis la ligne de dispatch
vivante et son `state` suivait l'état courant : après une clôture, le rejeu rendait
`completed` au lieu de `active`. `KI-024` décrivait aussi un `startedAt` remis à
`null` par `private.set_flight_dispatch_started_at`, ce qui n'était plus vrai :
T0051 avait déjà redéfini ce trigger pour qu'un état terminal conserve
`old.started_at`, et sa contrainte l'exige non nul. Un seul champ sur cinq dérivait
donc réellement, ce que la preuve pgTAP du 5 août 2026 constate. La restitution ne
dépend en revanche pas de ce trigger, si bien qu'une migration future qui le
changerait ne peut pas rouvrir l'écart.

`public.close_flight` n'est pas gardé, sur décision d'Andy du 4 août 2026 : un vol
déjà en cours reste clôturable et réglé même après la fin de la location, sinon un
défaut terminal immobiliserait définitivement le vol. Le même avion refuse en
revanche tout nouveau brouillon après cette clôture.

T0060 n'ajoute ni ordonnanceur d'échéances, ni endpoint applicatif, ni appelant
desktop. La garde est donc exacte par rapport à l'état enregistré, pas par rapport
à l'heure murale : sans ordonnanceur, un avion peut rester utilisable après sa
date réelle d'expiration jusqu'au prochain appel de la commande temporelle.
