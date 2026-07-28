# Sécurité du desktop

## Frontière locale T0010

Le bridge exige un port dynamique loopback et un jeton hexadécimal de 256 bits.
Le header `X-Thrustline-Instance` est exigé sur REST et SignalR et comparé en
temps constant. Le jeton passe de Tauri au bridge par un pipe stdin anonyme ; il
n'apparaît ni dans les arguments, ni dans l'environnement, ni dans les logs, et
n'est pas transmis à React.

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

## Bridge .NET T0009

Le bridge minimal n'ouvre aucune frontière :

- aucune écoute réseau, socket, requête ou IPC ;
- aucune lecture de secret, variable métier ou fichier utilisateur ;
- aucune dépendance NuGet tierce et sources de packages désactivées ;
- diagnostic `--health-check` constant, sans détail d'environnement ;
- arguments inconnus rejetés sans les recopier ;
- aucun lien avec Tauri ou SimConnect.

Le lancement authentifié et le contrat local appartiennent à T0010. Ils devront
considérer le processus desktop et le bridge comme mutuellement non fiables.
