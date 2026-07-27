# Baseline du shell Tauri T0007

- Date : 27 juillet 2026
- Commit de base : `da2c56fa8c2cf82583b381e25fde9bcbe1a5bb87` (arbre T0007 non commité)
- Plateforme : Windows 11 x64
- Machine : CPU x64, 32 Gio de RAM (aucun identifiant personnel)
- Rust : 1.97.1
- Tauri : 2.11.5
- Tauri CLI : 2.11.4
- tauri-build : 2.6.3
- WebView2 Evergreen : 150.0.4078.99, relevé sur le processus réellement lancé
- Configuration : Release, sans bundle

## Protocole

Le script `scripts/measure-tauri-shell.ps1` réalise un build propre et
incrémental, cinq lancements froids, cinq lancements chauds, puis dix cycles de
lancement/fermeture. Une fenêtre native visible est obligatoire. Les working
sets privés et handles sont relevés après 30 et 60 secondes ; les processus
WebView2 enfants sont comptés. Les données brutes sont écrites dans le dossier
explicitement fourni au script.

## Résultats

| Mesure | Minimum | Médiane | Maximum |
| --- | ---: | ---: | ---: |
| Affichage, série froide | 81,7 ms | 89,4 ms | 132,3 ms |
| Affichage, série chaude | 81,7 ms | 92,5 ms | 97,0 ms |
| Mémoire privée processus principal à 30 s | 6,73 Mio | 6,77 Mio | 6,79 Mio |
| Mémoire privée processus principal à 60 s | 6,73 Mio | 6,77 Mio | 6,79 Mio |
| Working set WebView2 associé à 60 s | 120,70 Mio | 120,96 Mio | 122,21 Mio |

- Frontend statique : 1 529 octets.
- Exécutable Release : 2 687 488 octets (2,56 Mio).
- Artefacts de lancement présents dans le dossier Release : 5 289 684 octets
  (5,04 Mio).
- Processus WebView2 enfant observé : 1 par lancement.
- Handles du processus principal : 338–341 à 30 s, 337–339 à 60 s.
- Build propre : 132,992 s.
- Build incrémental immédiat : 2,878 s.
- Dix cycles de lancement/fermeture : 10 réussis, zéro processus Thrustline
  orphelin.

Les mesures ont été exécutées avec Rust 1.97.1, Cargo 1.97.1 et Tauri CLI
2.11.4. La restauration et les builds ont utilisé pnpm 11.17.0 via Corepack.
Après la première campagne, l'hôte a été aligné sur Node 24.18.0, pnpm 11.17.0
et PowerShell 7.6.0 ; le contrôle T0006 est désormais entièrement conforme.

## Limites et anomalies

- Une seule machine Windows est disponible.
- Les séries « froide » et « chaude » sont deux séries séquentielles ; aucun
  cache système n'a été purgé, car cela aurait nécessité une intervention
  privilégiée et rendu le protocole plus intrusif.
- Une première mesure incrémentale a été invalidée par la suspension de la tâche
  Codex ; la valeur publiée vient d'une relance immédiate non interrompue.
- L'absence de WebView2 n'a pas été testée dans une VM propre.
- Aucune comparaison Electron ou shell .NET n'est possible sans protocole
  équivalent.
- Aucun budget n'est appliqué avant T0015.

## Conclusion

Le shell est acceptable pour continuer techniquement vers T0008 : il compile,
s'affiche et se ferme proprement, et sa baseline est désormais reproductible.
Le ticket reste néanmoins limité par la non-conformité de la toolchain hôte et
par l'absence de test sur une machine sans WebView2.
