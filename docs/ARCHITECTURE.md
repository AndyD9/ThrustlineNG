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

T0008 ne contient ni bridge .NET, ni commande IPC, ni provider métier. La
séparation future est :

```text
page locale → API Tauri explicitement autorisée → processus Rust
                                               → futur bridge .NET
```

Chaque ouverture de cette frontière exigera un ticket, une capability ciblée et
une validation des entrées. L'error boundary ne transmet rien et ne présente
aucun détail interne ; son action de rechargement est injectée dans les tests.
