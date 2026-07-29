# Budgets stabilité et performance T0015

- Date : 29 juillet 2026
- Branche : `foundation/t0015-stability-performance-budgets`
- Base mesurée : `7f33073bd931f00dd936384cbd6cfde13511bc96`, arbre
  T0015 non commité pendant la campagne finale
- Plateforme : Windows 11 x64
- Configuration : Release
- Source des seuils : `eng/stability-performance-budgets.json`

## Portée

Les budgets de fondation détectent des régressions grossières sur le frontend,
le desktop et le bridge actuels. Ils ne prouvent ni le MVP complet, ni le profil
matériel minimum, ni une session MSFS ou un vol de quatre heures.

Les mesures T0007/T0008 ont été réalisées sur une seule machine Windows. Le
bridge T0015 a été remesuré depuis la publication self-contained courante. Les
objectifs de release restent explicitement `Not measured`.

## Budgets automatisés

| Surface | Mesure | Budget |
| --- | --- | ---: |
| Frontend | bundle total gzip | ≤ 262 144 octets |
| Desktop | artefacts nécessaires au lancement | ≤ 16 777 216 octets |
| Desktop | affichage froid, médiane / maximum | ≤ 500 / 1 000 ms |
| Desktop | affichage chaud, médiane / maximum | ≤ 350 / 750 ms |
| Desktop | mémoire privée médiane à 60 s | ≤ 67 108 864 octets |
| Desktop | working set WebView2 médian à 60 s | ≤ 201 326 592 octets |
| Desktop | croissance médiane privée 30 → 60 s | ≤ 16 777 216 octets |
| Desktop | cycle de vie | ≥ 10 cycles propres, 0 orphelin |
| Bridge | publication self-contained | ≤ 134 217 728 octets |
| Bridge | health check, médiane / maximum | ≤ 1 000 / 2 000 ms sur ≥ 10 runs |

Les seuils desktop laissent de la marge à la reconstruction fonctionnelle sans
autoriser une croissance silencieuse de plusieurs ordres de grandeur. Le budget
bridge tient compte du runtime .NET self-contained et conserve environ 21 % de
marge sur la publication courante. Une hausse exige une PR avec mesure, cause,
risque et stratégie de réduction ; un échec ne relève jamais automatiquement le
budget.

## Comparaison aux preuves existantes

| Mesure | Preuve | Résultat | Budget | État |
| --- | --- | ---: | ---: | --- |
| Frontend gzip | T0015 | 77 387 o | 262 144 o | Conforme |
| Artefacts desktop hors bridge | T0015 | 5 560 929 o | 16 777 216 o | Conforme |
| Affichage froid médian / max | T0015 | 83,1 / 89,5 ms | 500 / 1 000 ms | Conforme |
| Affichage chaud médian / max | T0015 | 81,7 / 90,9 ms | 350 / 750 ms | Conforme |
| Mémoire privée médiane à 60 s | T0015 | 7 725 056 o | 67 108 864 o | Conforme |
| WebView2 médian à 60 s | T0015 | 127 072 256 o | 201 326 592 o | Conforme |
| Croissance privée 30 → 60 s | T0015 | 0 o | 16 777 216 o | Conforme |
| Cycles / orphelins desktop / bridge | T0015 | 10 / 0 / 0 | ≥ 10 / 0 / 0 | Conforme |
| Publication bridge | T0015 | 110 477 582 o, 334 fichiers | 134 217 728 o | Conforme |
| Health bridge médian / max | T0015 | 58,75 / 118,7 ms, 10 runs | 1 000 / 2 000 ms | Conforme |

Le contrôle direct des artefacts reconstruits pendant T0015 donne :

- frontend gzip : 77 387 octets ;
- artefacts desktop : 5 560 929 octets ;
- publication bridge : 110 477 582 octets.

Ces trois tailles passent le gate automatisé. Les valeurs T0007/T0008 restent
dans leurs rapports d'origine ; la campagne finale T0015 les remplace comme
preuve courante sans réécrire leur provenance.

## Campagne GUI T0015

Le premier essai a lancé l'exécutable Tauri nu produit par `--no-bundle`. Depuis
T0014, ce binaire exige la publication bridge dans son répertoire de ressources ;
son absence provoquait la sortie avant 30 secondes. Le harness publie et stage
maintenant le bridge dans le layout Release attendu avant tout lancement.

Un second essai a compté les bridges immédiatement après dix fermetures rapides
et les a pris pour des orphelins. Le préflight de cycle de vie attend désormais
jusqu'à cinq secondes la terminaison du bridge associé, le nettoie en fail-safe
si nécessaire et échoue dans ce cas. Les dix cycles finaux ont tous fermé
desktop et bridge proprement.

La campagne finale contient cinq lancements froids, cinq chauds, dix observations
à 30/60 secondes avec un WebView2 et un bridge associés, puis dix cycles propres.
Elle produit zéro processus orphelin et respecte tous les budgets.

## Objectifs de release — Not measured

| Objectif | Cible | Preuve manquante |
| --- | ---: | --- |
| Démarrage utilisable p50 / p95 | ≤ 2 / 4 s | application MVP et protocole E2E |
| Mémoire idle desktop + WebView2 + bridge p50 | ≤ 512 Mio | processus intégrés |
| Croissance mémoire sur quatre heures | ≤ 128 Mio | replay long ou vol MSFS |
| Installation complète | ≤ 350 Mio | installateur T0014/Phase 6 |
| Sessions sans crash non géré | ≥ 99,5 % / 30 j / 1 000 sessions | télémétrie consentie avant bêta |
| Orphelin, double clôture, perte silencieuse, mutation hors grand livre | 0 | vertical slice et gates de release |

## Commandes exécutées

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass `
  -File .\tests\performance-budgets\run.ps1

powershell.exe -NoProfile -ExecutionPolicy Bypass `
  -File .\scripts\measure-bridge.ps1 `
  -OutputDirectory .\artifacts\t0015 -SkipPublish

powershell.exe -NoProfile -ExecutionPolicy Bypass `
  -File .\scripts\check-performance-budgets.ps1 `
  -BridgeMeasurementsPath .\artifacts\t0015\bridge-measurements.json

powershell.exe -NoProfile -ExecutionPolicy Bypass `
  -File .\scripts\check-performance-budgets.ps1 -BuiltArtifacts
```

Le harnais exécute une mesure conforme et quatre scénarios négatifs :
dépassement frontend, dépassement bridge, schéma inconnu et mesure incomplète.
Tous ont produit le résultat attendu.

## Révision

Les budgets sont relus après une modification d'architecture runtime, avant
chaque jalon de phase, lorsque le profil minimum devient mesurable et avant
bêta. Une révision indique ancienne valeur, nouvelle valeur, mesures comparables
et conséquence utilisateur.

Les performances MSFS, cloud et longue durée ne peuvent pas être déduites de ces
seuils de fondation.
