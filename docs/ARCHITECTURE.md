# Architecture du desktop

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
