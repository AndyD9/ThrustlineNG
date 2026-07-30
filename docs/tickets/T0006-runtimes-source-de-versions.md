# T0006 — Épingler les runtimes et créer la source de versions

Status: Done
Owner: Andy
Branch: `docs/T0006-clean-clone-verification`
Phase: 1
Risk: High
Security-sensitive: Yes

## Clôture du suivi — 30 juillet 2026

L'implémentation a été fusionnée dans `main` par la PR #1 le 26 juillet 2026.
Les anciens blockers décrivaient la situation avant la création de
ThrustlineNG ; ils ne correspondent plus à l'état Git réel.

T0005 est désormais `Done`. La preuve manquante a été exécutée le 30 juillet
2026 depuis un clone distant propre de `main` au commit `c9966e2`, sur la branche
de suivi `docs/T0006-clean-clone-verification`.

Le contrôle de toolchain, le mode JSON, les 15 assertions, `CheckOnly`, deux
exécutions idempotentes du bootstrap, les tests et les builds représentatifs du
socle ont réussi. Le clone est resté sans diff ; le ticket peut donc passer de
`Verify` à `Done`.

## Goal

Créer dans le nouveau dépôt Thrustline un socle de développement reproductible
qui :

- épingle les versions Node.js, pnpm, Rust, .NET et PowerShell retenues ;
- possède une source de versions lisible et contrôlable ;
- détecte immédiatement une machine incompatible ;
- restaure les outils et dépendances sans dérive silencieuse ;
- documente un démarrage depuis une machine Windows 11 propre ;
- ne contient encore aucun shell Tauri, frontend React, bridge .NET ou backend.

Le résultat attendu est un dépôt minimal que tous les tickets suivants peuvent
utiliser sans deviner leur environnement.

## Context

ADR-0002 impose une réécriture totale dans un nouveau dépôt et un historique Git
neuf. L'ancien dépôt devient une référence en lecture seule.

ADR-0004 retient :

- Node.js 24 LTS ;
- pnpm 11 ;
- TypeScript 6 pour les futurs projets TypeScript ;
- Rust stable épinglé ;
- .NET 10 LTS ;
- PowerShell pour les scripts Windows ;
- versions directes exactes, lockfiles et contrôle mensuel.

T0006 est le premier ticket de fondation du nouveau dépôt. Il ne doit pas copier
les manifests, lockfiles, scripts ou code applicatif de l'ancien dépôt.

## Repository decision required

Avant exécution, Andy doit confirmer :

1. nom local du nouveau dépôt ;
2. nom GitHub, par exemple `AndyD9/Thrustline-Rebuild` ou autre ;
3. visibilité `private` ou `public` ;
4. branche principale, recommandée : `main` ;
5. licence initiale ou absence temporaire de licence ;
6. conservation du nom produit affiché `Thrustline` ;
7. emplacement local hors de l'ancien dépôt ;
8. création du remote par Andy ou autorisation explicite pour `gh repo create`.

Le nouveau dépôt ne doit pas être créé à l'intérieur de
`C:\Users\andyd\Documents\Thrustline`.

La création d'un dépôt GitHub est une action externe distincte. L'agent doit
présenter le nom, le propriétaire, la visibilité et la commande exacte, puis
obtenir une confirmation explicite immédiatement avant de l'exécuter.

## Dependencies

- T0001 à T0004 terminés.
- T0005 terminé.
- `docs/decisions/ADR-0004-stack-cible.md`
- `docs/STACK.md`
- `docs/SECURITY.md`
- `docs/QUALITY.md`
- nouveau dépôt initialisé avec une branche `main`.

## Allowed areas

Dans le **nouveau dépôt uniquement** :

- `.gitignore`
- `.gitattributes`
- `.editorconfig`
- `.node-version`
- `.nvmrc`
- `package.json` racine, privé et sans dépendance applicative
- `pnpm-workspace.yaml`
- `pnpm-lock.yaml` uniquement s'il est généré par la version pnpm épinglée
- `rust-toolchain.toml`
- `global.json`
- `eng/versions.json`
- `scripts/check-toolchain.ps1`
- `scripts/bootstrap.ps1`
- `tests/toolchain/`
- `README.md`
- `AGENTS.md`
- `docs/STACK.md`
- `docs/SETUP.md`
- documents ADR/workflow strictement nécessaires au nouveau dépôt

Dans l'ancien dépôt :

- ce ticket ;
- `docs/tickets/README.md` et `docs/CURRENT_STATE.md` uniquement pour le statut et
  le Completion Report après exécution.

## Do not touch

- code et manifests applicatifs de l'ancien dépôt ;
- `legacy/` ;
- ancien projet Supabase ;
- secrets et fichiers `.env` ;
- Tauri et plugins Tauri ;
- React, Vite, Vitest et Tailwind ;
- projet ou package .NET applicatif ;
- SDK ou wrapper SimConnect ;
- Docker/Supabase local ;
- workflow CI complet ;
- installateur, signature et updater ;
- dépendances fonctionnelles ;
- installation Windows ou modification du registre ;
- modification globale de la configuration Git utilisateur.

## Requirements

### 1. Créer la source canonique de versions

Créer `eng/versions.json` avec au minimum :

```json
{
  "node": "<version exacte validée par ADR-0004>",
  "pnpm": "<version exacte validée par ADR-0004>",
  "rust": "<toolchain exacte validée>",
  "dotnetSdk": "<SDK exact validé>",
  "dotnetRuntime": "10.0",
  "powershellMinimum": "<version minimale>",
  "schemaVersion": 1
}
```

Règles :

- JSON valide, sans commentaire ;
- versions exactes, pas `latest`, `stable`, `*`, `^` ou `~` ;
- aucune URL de téléchargement non officielle ;
- aucune valeur de secret ;
- `schemaVersion` obligatoire pour les futurs changements de format.

`eng/versions.json` est la référence humaine et de contrôle. Les fichiers natifs
de chaque écosystème restent nécessaires au fonctionnement de leurs outils.

### 2. Créer les pins natifs

Les fichiers suivants doivent être cohérents avec `eng/versions.json` :

- `.node-version` ;
- `.nvmrc` ;
- `package.json` :
  - `"private": true` ;
  - `"engines"` ;
  - `"packageManager": "pnpm@<version exacte>"` avec intégrité si supportée ;
- `rust-toolchain.toml` avec toolchain exacte et profil minimal ;
- `global.json` avec SDK .NET exact et politique `rollForward` explicitement
  choisie ;
- version PowerShell minimale documentée dans les scripts.

Une version ne doit pas être dupliquée sans contrôle automatique de cohérence.

### 3. Créer le workspace minimal

`pnpm-workspace.yaml` peut définir les emplacements futurs sans créer leurs
applications :

```yaml
packages:
  - "apps/*"
  - "packages/*"
```

Ne pas créer artificiellement vingt dossiers vides. Créer seulement les dossiers
nécessaires au ticket.

Le `package.json` racine ne doit contenir aucune dépendance runtime ou
devDependency tant qu'un ticket ne la justifie pas.

### 4. Créer le contrôle de toolchain

`scripts/check-toolchain.ps1` doit :

- nécessiter PowerShell selon la version minimale décidée ;
- fonctionner sans droits administrateur ;
- lire `eng/versions.json` ;
- vérifier la présence et la version de :
  - `node` ;
  - `pnpm` ;
  - `rustc` ;
  - `cargo` ;
  - `dotnet` ;
  - `git` ;
- vérifier la cohérence des pins natifs ;
- distinguer `missing`, `wrong version`, `compatible patch` si autorisé et
  `unexpected error` ;
- retourner `0` si conforme et un code non nul sinon ;
- ne pas modifier la machine ;
- ne pas afficher de variables d'environnement sensibles ;
- produire des messages actionnables.

Le script doit accepter un mode machine-readable, par exemple `-Json`, pour la
future CI.

### 5. Créer le bootstrap sûr

`scripts/bootstrap.ps1` doit :

- commencer par le contrôle de toolchain ;
- restaurer uniquement depuis les fichiers verrouillés ;
- utiliser pnpm avec lockfile figé ;
- ne pas installer silencieusement un SDK global ;
- ne pas demander de privilèges administrateur ;
- ne pas exécuter de script distant téléchargé ;
- ne pas modifier le profil PowerShell ;
- expliquer précisément le prérequis manquant avec un lien officiel ;
- être idempotent ;
- proposer `-CheckOnly` ;
- refuser de continuer si une version structurante est incompatible.

Comme aucun projet applicatif n'existe encore, le bootstrap peut rester court. Il
ne doit pas simuler des étapes futures.

### 6. Normaliser fichiers et fins de ligne

Créer :

- `.gitattributes` imposant une politique explicite pour textes, PowerShell et
  fichiers binaires ;
- `.editorconfig` pour UTF-8, fin de ligne et indentation ;
- `.gitignore` minimal adapté aux futurs écosystèmes sans copier aveuglément
  celui de l'ancien dépôt.

Le but est d'empêcher la répétition des changements massifs de fins de ligne et
des erreurs Git WSL observées dans l'ancien dépôt.

Documenter que ce projet Windows doit utiliser Git pour Windows/PowerShell, pas
Git WSL sur un chemin `/mnt/c`.

### 7. Créer les tests du socle

Ajouter des tests PowerShell ou un harness minimal qui vérifie :

- JSON de versions invalide ;
- pin Node incohérent ;
- pin pnpm incohérent ;
- SDK .NET absent ou incorrect ;
- toolchain Rust incorrecte ;
- mode JSON valide ;
- absence de fuite d'une variable factice sensible ;
- exécution répétée sans changement.

Ne pas ajouter un framework lourd uniquement pour ces tests si des scripts
PowerShell déterministes suffisent.

### 8. Documenter le setup

`docs/SETUP.md` doit contenir :

- plateformes supportées selon ADR-0003 ;
- outils requis et versions exactes ;
- liens officiels ;
- procédure depuis un clone propre ;
- commande de contrôle ;
- commande de bootstrap ;
- erreurs fréquentes ;
- Git Windows contre WSL ;
- aucun secret requis à ce stade ;
- procédure de mise à jour future des pins.

Le README racine doit rester court et pointer vers `docs/SETUP.md`.

### 9. Adapter les règles du nouveau dépôt

Créer un `AGENTS.md` adapté au nouveau dépôt qui reprend uniquement les règles
encore pertinentes :

- un ticket à la fois ;
- branche confirmée avant travail ;
- zones autorisées/interdites ;
- sécurité et absence de secrets ;
- validations ;
- commit/push uniquement après confirmation explicite ;
- PowerShell/Git Windows ;
- aucun héritage implicite de l'ancien code.

Ne pas recopier des affirmations devenues fausses sur les dossiers `app/`,
`sim-bridge/` ou `supabase/` tant qu'ils n'existent pas.

### 10. Définir la procédure de mise à jour

Documenter une procédure future :

1. ouvrir un ticket dédié ;
2. vérifier sources officielles et sécurité ;
3. modifier `eng/versions.json` ;
4. régénérer ou synchroniser les pins natifs ;
5. restaurer les lockfiles avec l'ancienne puis la nouvelle version selon le cas ;
6. exécuter contrôle, bootstrap et tests ;
7. mesurer les impacts ;
8. conserver un rollback vers le commit précédent.

Le script ne doit pas mettre automatiquement les versions à jour.

## Non-goals

- Créer l'application Tauri.
- Installer React ou TypeScript.
- Créer un projet Rust applicatif.
- Créer un projet .NET.
- Implémenter SimConnect.
- Configurer Supabase ou Docker.
- Créer la CI multi-stack finale.
- Mesurer les performances de l'application.
- Construire un installateur.
- Ajouter un gestionnaire automatique de mises à jour.
- Copier du code ou un lockfile de l'ancien dépôt.

## Acceptance criteria

- [x] T0005 est `Done`.
- [x] Le nouveau dépôt, sa visibilité et sa branche principale sont confirmés.
- [x] Le travail se trouve sur `foundation/t0006-toolchain-pins`.
- [x] `eng/versions.json` contient uniquement des versions exactes validées.
- [x] Les pins Node, pnpm, Rust et .NET sont cohérents avec la source canonique.
- [x] Aucun composant applicatif n'est introduit.
- [x] `check-toolchain.ps1` échoue clairement sur une version incorrecte.
- [x] `check-toolchain.ps1 -Json` produit une sortie exploitable.
- [x] `bootstrap.ps1 -CheckOnly` ne modifie pas la machine.
- [x] Le bootstrap est idempotent.
- [x] Aucun téléchargement distant arbitraire ou privilège administrateur.
- [x] Les fins de ligne et UTF-8 sont explicitement configurés.
- [x] Les tests couvrent les incohérences principales et une fuite factice.
- [x] Un clone propre peut suivre `docs/SETUP.md`.
- [x] `AGENTS.md` du nouveau dépôt ne décrit aucun dossier inexistant.
- [x] Aucun fichier applicatif de l'ancien dépôt n'est modifié ou copié.
- [x] Le Completion Report indique le commit des deux dépôts si l'ancien ticket
      est mis à jour séparément.

## Security review

### Assets

- poste de développement ;
- toolchains et gestionnaires de paquets ;
- lockfiles ;
- scripts PowerShell ;
- dépôt GitHub ;
- futurs secrets CI.

### Abuse and failure cases

- script bootstrap téléchargeant ou exécutant du contenu distant ;
- package manager différent de la version auditée ;
- typosquatting d'un outil ;
- modification globale du poste ou du profil utilisateur ;
- exécution en administrateur ;
- sortie du script révélant une variable sensible ;
- Git configuré via WSL sur NTFS et corruption des fins de ligne ;
- dépôt GitHub créé public par erreur ;
- fichiers de l'ancien dépôt copiés sans provenance ;
- pin `latest` changeant silencieusement.

### Required controls

- versions exactes et sources officielles ;
- check-only par défaut pour les installations manquantes ;
- aucun secret nécessaire ;
- aucun script distant ;
- permissions utilisateur standard ;
- lockfile figé ;
- sortie redigée ;
- visibilité du dépôt confirmée avant création ;
- liste explicite des fichiers pour chaque commit ;
- revue du diff avant commit et confirmation distincte avant push.

## Automated validation

Les commandes exactes doivent être adaptées au nouveau chemin confirmé :

```powershell
# Depuis la racine du nouveau dépôt
pwsh -NoProfile -File .\scripts\check-toolchain.ps1
pwsh -NoProfile -File .\scripts\check-toolchain.ps1 -Json
pwsh -NoProfile -File .\scripts\bootstrap.ps1 -CheckOnly
pwsh -NoProfile -File .\scripts\bootstrap.ps1

# Restauration déterministe
pnpm install --frozen-lockfile

# Tests du socle
pwsh -NoProfile -File .\tests\toolchain\run.ps1

# Vérifications Git
git diff --check
git status --short
```

Si un outil exact n'est pas disponible sur la machine, le ticket reste en
`Verify` avec la preuve de détection correcte ; il ne doit pas être déclaré
`Done` en prétendant que l'environnement est conforme.

## Manual verification

1. Exécuter le contrôle sur la machine conforme.
2. Simuler une mauvaise version dans une copie temporaire du fichier de versions.
3. Vérifier le message et le code de sortie.
4. Exécuter deux fois le bootstrap et confirmer l'absence de nouveau diff.
5. Vérifier que le mode JSON ne contient aucun chemin ou secret inutile.
6. Suivre `docs/SETUP.md` depuis un clone propre ou une VM.
7. Confirmer qu'aucun dossier Tauri, React, .NET ou Supabase n'a été créé.

Temps cible : 15 minutes hors installation initiale des outils.

## Rollback

Avant tout utilisateur ou code applicatif, le rollback consiste à :

- abandonner la branche T0006 ;
- revenir au commit initial propre du nouveau dépôt ;
- supprimer localement uniquement le clone explicitement confirmé si Andy le
  demande ;
- ne jamais supprimer automatiquement le dépôt GitHub.

Après fusion, revenir au commit précédent ou ouvrir un ticket de correction. Ne
pas modifier manuellement les pins sans synchroniser la source canonique.

## Completion Report

### Summary

Le socle de toolchain exact et reproductible a été livré. La réconciliation a
également corrigé le harnais synthétique, qui ne copiait plus les manifests Tauri
devenus obligatoires pour `check-toolchain.ps1`.

### Repository created or used

`AndyD9/ThrustlineNG`, branche par défaut `main`.

### Versions pinned

Node `24.18.0`, pnpm `11.17.0`, Rust `1.97.1`, SDK .NET `10.0.201` et
PowerShell `7.6.0` minimum.

### Files changed in the new repository

Commit historique `60f0aba` : pins natifs, `eng/versions.json`, scripts de
contrôle/bootstrap, harnais toolchain, setup et normalisation Git.

### Files changed in the reference repository

Sans objet : ThrustlineNG est le nouveau dépôt effectivement retenu.

### Commands and results

- `check-toolchain.ps1` et `-Json` : conformes le 28 juillet 2026 ;
- `tests/toolchain/run.ps1` : premier rejeu en échec (5/15), puis 15/15 après
  synchronisation du dépôt synthétique avec les manifests Tauri ;
- `bootstrap.ps1 -CheckOnly` : réussi, sans modification ;
- deux `bootstrap.ps1` successifs : réussis, lockfile inchangé.
- `git clone --branch main --single-branch
  https://github.com/AndyD9/ThrustlineNG.git` : réussi le 30 juillet 2026 ;
  `HEAD` vaut `c9966e2` et le clone suit `origin/main` ;
- un premier clone depuis le dépôt local a été refusé avant copie par la
  protection Git `dubious ownership` du compte sandboxé ; aucune exception
  globale n'a été ajoutée et le clone distant a servi de preuve ;
- `pwsh -NoProfile -File .\scripts\check-toolchain.ps1` et `-Json` : réussis,
  17 contrôles conformes, PowerShell `7.6.4` détecté ;
- `pwsh -NoProfile -File .\tests\toolchain\run.ps1` : 15 assertions réussies,
  incluant les mauvaises versions et la fuite factice ;
- `pwsh -NoProfile -File .\scripts\bootstrap.ps1 -CheckOnly`, puis deux
  exécutions sans option : réussies ; la seconde restauration indique
  `Already up to date` ;
- `pnpm frontend:typecheck`, `frontend:test`, `frontend:build`,
  `desktop:check`, `desktop:test`, `desktop:build`, `bridge:build`,
  `bridge:test` et `bridge:health` : réussis ; 8 tests frontend, 3 tests Rust,
  13 tests bridge, builds Tauri/.NET Release et diagnostic `Healthy` ;
- `pnpm backend:check`, `data-policy:check`, `ci:check`,
  `performance:test` et `windows:package:check` : réussis avec leurs mutations
  négatives attendues ;
- `git diff --exit-code`, `git diff --check` et
  `git status --short --branch` : réussis ; clone final propre.

### Clean-clone verification

Réussie le 30 juillet 2026 depuis un clone distant propre de
`https://github.com/AndyD9/ThrustlineNG.git`, branche `main`, commit `c9966e2`.
La machine Windows 11 x64 possédait les versions épinglées. `CheckOnly`, deux
bootstraps et les validations représentatives du socle ont réussi sans modifier
un fichier suivi.

### Manual verification result

Contrôle lisible, sortie JSON sans chemin ni secret inutile, détection des
mauvaises versions, idempotence et restauration depuis un clone propre vérifiés.
Le clone final est resté propre.

### Security review result

Aucun téléchargement distant, secret, privilège administrateur ou modification
globale du poste n'est effectué par les scripts.

### Risks and limitations

- La preuve a été exécutée depuis un clone propre sur la machine Windows 11 de
  validation, pas depuis une VM fraîche sans caches utilisateur.
- Les caches pnpm, Cargo et NuGet étaient déjà alimentés ; la restauration
  déterministe et l'absence de secret sont prouvées, pas un téléchargement
  entièrement à froid.

### Follow-ups

- Aucun follow-up T0006 bloquant. Les vérifications interactives des tickets
  T0007 à T0009 et les limites T0011/T0012 restent suivies séparément.

### Documentation updated

Ticket, backlog et `CURRENT_STATE.md` mis à jour le 30 juillet 2026 avec la
preuve clean-clone.

### Git handoff

- branche historique : `foundation/t0006-toolchain-pins` ;
- commit : `60f0aba` ;
- PR : https://github.com/AndyD9/ThrustlineNG/pull/1 ;
- PR fusionnée dans `main` le 26 juillet 2026.
- branche de vérification : `docs/T0006-clean-clone-verification` ;
- commit de clôture : `49f4f93` ;
- PR de clôture prête : https://github.com/AndyD9/ThrustlineNG/pull/27,
  base/head `main` / `docs/T0006-clean-clone-verification`.

Indiquer séparément pour chaque dépôt :

- branche constatée ;
- remote et branche cible ;
- fichiers exacts du ticket ;
- modifications hors ticket à préserver ;
- message de commit proposé ;
- commandes PowerShell de vérification ;
- confirmation demandée avant commit/push ;
- résultat du push s'il est autorisé.

Ne jamais utiliser `git add .` ou `git add -A`.
