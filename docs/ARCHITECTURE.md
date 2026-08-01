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
anonyme et lit montant/devise depuis son environnement serveur avant d'appeler
T0022 avec `service_role`. La fonction ne fractionne donc pas la transaction SQL
et ne livre jamais le credential privilégié au desktop. Aucun appelant desktop,
CORS applicatif ou déploiement distant n'est encore fourni.

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
