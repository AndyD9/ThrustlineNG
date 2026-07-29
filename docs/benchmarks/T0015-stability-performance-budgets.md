# Budgets stabilité et performance T0015

- Date : 29 juillet 2026
- Branche : `foundation/t0015-stability-performance-budgets`
- Base mesurée : `0817dfbc92eebefc30396e14225bf994f15fd454`
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
| Frontend gzip | T0008 | 77 111 o | 262 144 o | Conforme |
| Artefacts desktop | T0008 | 5 531 158 o | 16 777 216 o | Conforme |
| Affichage froid médian / max | T0008 | 87,2 / 182,5 ms | 500 / 1 000 ms | Conforme |
| Affichage chaud médian / max | T0008 | 84,5 / 98,4 ms | 350 / 750 ms | Conforme |
| Mémoire privée médiane à 60 s | T0008 | 7,30 Mio | 64 Mio | Conforme |
| WebView2 médian à 60 s | T0008 | 121,04 Mio | 192 Mio | Conforme |
| Croissance privée 30 → 60 s | T0008 | 0 Mio | 16 Mio | Conforme |
| Cycles / orphelins | T0008 | 10 / 0 | ≥ 10 / 0 | Conforme |
| Publication bridge | T0015 | 110 477 582 o, 334 fichiers | 134 217 728 o | Conforme |
| Health bridge médian / max | T0015 | 58,75 / 118,7 ms, 10 runs | 1 000 / 2 000 ms | Conforme |

Le contrôle direct des artefacts reconstruits pendant T0015 donne :

- frontend gzip : 76 526 octets ;
- artefacts desktop : 5 560 929 octets ;
- publication bridge : 110 477 582 octets.

Ces trois tailles passent le gate automatisé. Les valeurs T0007/T0008 restent
dans leurs rapports d'origine ; ce document les compare sans réécrire leur
provenance.

## Campagne GUI T0015

Le premier essai a construit l'application et affiché la fenêtre, puis a été
bloqué par le refus WMI du bac à sable lors de l'inspection WebView2. Le second
essai, avec accès WMI autorisé, a révélé une agrégation non sûre en mode strict ;
le harness échoue maintenant explicitement si WebView2 n'est pas associé.

Après cette correction, le binaire lancé dans la session d'outil est sorti
anormalement avec le code `-1073740791` avant la mesure longue. Le harness
détecte désormais aussi toute sortie avant 30 ou 60 secondes. La campagne T0015
est donc **non concluante**, pas réussie et pas interprétée comme un dépassement.
La cause produit ou environnement n'est pas tranchée avant reproduction dans une
session interactive. La baseline T0008 demeure la seule preuve GUI complète.

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
