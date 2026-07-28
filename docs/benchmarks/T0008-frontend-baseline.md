# Baseline du frontend T0008

- Date : 27 juillet 2026
- Commit de base : `3012ecc5759ff71c977bb697219664f6eb9b6f2c` (arbre T0008 non commité)
- Plateforme : Windows 11 x64, même machine que T0007
- Node / pnpm : 24.18.0 / 11.17.0
- React / React DOM / React Router : 19.2.8 / 19.2.8 / 7.18.1
- TypeScript : 6.0.3
- Vite / plugin React : 8.1.5 / 6.0.4
- Vitest / couverture V8 : 4.1.10 / 4.1.10
- jsdom : 29.1.1
- Testing Library React / jest-dom / user-event : 16.3.2 / 6.9.1 / 14.6.1
- Tailwind CSS / plugin Vite : 4.3.3 / 4.3.3
- Tauri / CLI : 2.11.5 / 2.11.4

## Protocole

`scripts/measure-frontend.ps1` exécute le typecheck, les tests, un build Vite
après suppression contrôlée de `apps/desktop/dist`, puis un second build. Il
mesure les tailles brutes et gzip du HTML/CSS/JS et délègue au harness T0007
cinq lancements froids, cinq chauds, la mémoire à 30 et 60 secondes et dix
cycles de fermeture. Les conditions et la machine sont les mêmes que T0007 ;
aucun cache système n'a été purgé.

## Build et bundle

| Mesure | Résultat |
| --- | ---: |
| Typecheck | 3,460 s |
| Tests (8 scénarios) | 3,228 s |
| Build Vite propre | 4,794 s |
| Build Vite immédiatement répété | 4,808 s |
| HTML brut / gzip | 445 / 281 octets |
| CSS brut / gzip | 6 878 / 2 391 octets |
| JavaScript brut / gzip | 235 015 / 74 439 octets |
| Total brut / gzip | 242 338 / 77 111 octets |
| Chunks JavaScript | 1 |
| Exécutable Tauri Release | 2 928 640 octets |
| Artefacts Release de lancement | 5 531 158 octets |

Le second build n'est pas plus rapide sur cette application minuscule ; aucune
conclusion sur un cache incrémental n'est tirée de cette seule paire.

## Démarrage et mémoire

| Mesure | Minimum | Médiane | Maximum |
| --- | ---: | ---: | ---: |
| Affichage, série froide | 84,3 ms | 87,2 ms | 182,5 ms |
| Affichage, série chaude | 79,5 ms | 84,5 ms | 98,4 ms |
| Mémoire privée à 30 s | 6,61 Mio | 7,30 Mio | 7,35 Mio |
| Mémoire privée à 60 s | 6,61 Mio | 7,30 Mio | 7,35 Mio |
| Working set WebView2 à 60 s | 120,96 Mio | 121,04 Mio | 123,70 Mio |

Les dix cycles de lancement/fermeture ont réussi et aucun processus Thrustline
orphelin n'est resté.

## Delta T0007 → T0008

| Mesure médiane ou taille | T0007 | T0008 | Delta |
| --- | ---: | ---: | ---: |
| Frontend brut | 1 529 o | 242 338 o | +240 809 o |
| Exécutable Release | 2 687 488 o | 2 928 640 o | +241 152 o |
| Affichage froid | 89,4 ms | 87,2 ms | -2,2 ms |
| Affichage chaud | 92,5 ms | 84,5 ms | -8,0 ms |
| Mémoire privée, 60 s | 6,77 Mio | 7,30 Mio | environ +0,53 Mio |
| Working set WebView2, 60 s | 120,96 Mio | 121,04 Mio | environ +0,08 Mio |

Les écarts de démarrage et de mémoire sont descriptifs. Les séries sont courtes
et séquentielles ; elles ne permettent pas d'attribuer causalement les écarts à
React ou au bundle.

## Limites et régressions

- Une seule machine Windows a été utilisée.
- Le premier lancement froid à 182,5 ms est un point haut conservé.
- WebView2 n'a pas été détecté dans le registre pendant cette campagne, bien
  qu'un processus enfant WebView2 ait été mesuré à chaque lancement.
- L'arbre était non commité pendant la mesure ; le hash désigne la base T0007.
- Les artefacts JSON bruts restent locaux sous `artifacts/t0008`.
- La taille frontend et celle de l'exécutable augmentent ; aucun budget final
  n'est fixé avant T0015.

## Conclusion

**Continuer.** Le frontend reste local, les invariants de sécurité passent, les
dix lancements se ferment proprement et les deltas observés ne justifient pas
de bloquer la prochaine tranche. T0009 est le prochain ticket recommandé par la
roadmap ; toute ouverture du bridge devra conserver les frontières Tauri posées
ici.
