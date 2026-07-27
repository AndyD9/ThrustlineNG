# Sécurité du shell desktop

T0007 part d'une autorité nulle côté page :

- capability limitée à la fenêtre `main`, avec zéro permission ;
- aucun plugin Tauri et aucune commande `#[tauri::command]` ;
- aucune ressource distante ou requête réseau ;
- CSP sans origine réseau, script inline ou évaluation dynamique ;
- décorations Windows natives et devtools désactivés en production ;
- aucun accès aux fichiers, processus, presse-papiers, notifications ou URL.

La CSP est :

```text
default-src 'self'; script-src 'self'; style-src 'self'; img-src 'self' data:;
connect-src 'none'; object-src 'none'; frame-src 'none';
frame-ancestors 'none'; base-uri 'self'; form-action 'self'
```

`data:` est limité aux images afin de rester compatible avec les ressources
internes éventuelles de Tauri. Le test `tests/desktop-shell/run.ps1` bloque les
plugins, permissions, commandes IPC, ressources distantes et assouplissements
CSP interdits.
