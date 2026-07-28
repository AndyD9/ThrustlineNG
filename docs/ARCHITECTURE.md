# Architecture du desktop

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

Le bridge n'est pas encore lancé par Tauri et n'ouvre aucun port. T0010 possède
la future liaison, son authentification et son contrat. Chaque ouverture de cette
frontière exigera une capability ciblée et une validation des entrées.
