# Architecture du shell desktop

Le processus Rust/Tauri possède la fenêtre native et charge exclusivement les
fichiers statiques de `apps/desktop/web`. Sous Windows, WRY s'appuie sur le
runtime WebView2 Evergreen du système ; aucun Chromium ni runtime WebView2 Fixed
Version n'est embarqué.

T0007 ne contient ni framework frontend, ni bridge .NET, ni commande IPC. Le
double lancement crée deux instances indépendantes. La séparation future est :

```text
page locale → API Tauri explicitement autorisée → processus Rust
                                               → futur bridge .NET
```

Chaque ouverture de cette frontière exigera un ticket, une capability ciblée et
une validation des entrées. T0008 pourra remplacer la page statique si la
baseline T0007 est acceptée.
