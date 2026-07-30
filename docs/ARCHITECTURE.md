# Architecture du desktop

## Cycle de vie des données T0017

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
au replay des suppressions postérieures au point restauré. Ces workflows sont
des contraintes d'architecture, pas des capacités actuelles : export,
suppression, purge, sauvegarde distante et restauration restent non implémentés.

Le futur grand livre est append-only, mais son lien personnel doit être
anonymisable. La FK T0012 `companies.owner_id ... on delete restrict` impose une
migration append-only et une commande serveur dédiées avant toute suppression de
compte ; T0017 ne modifie pas le schéma existant.

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
append-only puis `supabase/seed.sql`. PostgreSQL 17, Auth et PostgREST suffisent
à cette tranche ; Realtime, Storage, Edge Runtime et Analytics restent
désactivés.

`public.companies` porte la première frontière de propriété du MVP solo :

```text
auth.users.id → companies.owner_id unique → une compagnie au plus par utilisateur
```

La clé étrangère impose un propriétaire Auth existant. La RLS est activée et
forcée. Quatre politiques séparées limitent select/insert/update/delete à
`auth.uid() = owner_id` et au rôle `authenticated`. Les types versionnés sous
`packages/database` sont destinés à être régénérés depuis la pile locale ; aucun
client applicatif ne les consomme encore.

Cette table ne constitue pas l'onboarding transactionnel complet. Les futures
mutations multi-écritures et économiques resteront des commandes serveur
transactionnelles et idempotentes.

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
