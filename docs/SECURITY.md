# Sécurité du desktop

Le desktop part d'une autorité nulle côté page :

- capability limitée à la fenêtre `main`, avec zéro permission ;
- aucun plugin Tauri et aucune commande `#[tauri::command]` ;
- aucune ressource distante ou requête réseau ;
- décorations Windows natives et devtools désactivés en production ;
- aucun accès aux fichiers, processus, presse-papiers, notifications ou URL.

La CSP de production est :

```text
default-src 'self'; script-src 'self'; style-src 'self'; img-src 'self' data:;
connect-src 'none'; object-src 'none'; frame-src 'none';
frame-ancestors 'none'; base-uri 'self'; form-action 'self'
```

T0008 conserve ces frontières. Le build frontend :

- n'expose aucune variable d'environnement (`envPrefix: []`) ;
- ne produit pas de source map de production ;
- ne configure ni proxy ni origine réseau ;
- charge uniquement le HTML, le CSS et le JavaScript compilés localement ;
- n'utilise ni `dangerouslySetInnerHTML`, ni télémétrie, ni appel réseau ;
- limite la CSP de développement à `127.0.0.1:1420` et son WebSocket HMR.

La CSP de production n'autorise ni Internet, ni `unsafe-inline`, ni
`unsafe-eval`. L'écran d'erreur masque l'erreur, la stack et les chemins locaux.
Les tests bloquent tout assouplissement des capabilities, commandes IPC,
ressources distantes et garanties CSP.
