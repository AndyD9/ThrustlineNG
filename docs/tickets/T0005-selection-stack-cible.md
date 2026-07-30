# T0005 — Sélectionner la stack cible et ses versions compatibles

Status: Done
Owner: Andy
Branch: `docs/t0005-stack-cible`
Phase: 0
Risk: High
Security-sensitive: Yes

## Goal

Choisir la stack technique du nouveau dépôt Thrustline et figer un ensemble de
versions :

- récentes ;
- stables ;
- officiellement supportées ;
- compatibles entre elles ;
- compatibles avec Windows 11 x64 et MSFS 2024 ;
- maintenables pendant toute la période visée pour le MVP ;
- sans vulnérabilité bloquante connue.

Le ticket doit distinguer pour chaque composant :

1. la version utilisée par l'ancien dépôt ;
2. la dernière version stable disponible au jour de l'étude ;
3. la version recommandée pour la refonte ;
4. la raison pour laquelle cette version est retenue ou écartée.

La version ayant le numéro le plus élevé ne doit pas être choisie automatiquement.

## Context

ADR-0001 retient un MVP solo connecté préparé pour une collaboration ultérieure.
ADR-0002 retient une réécriture totale isolée dans un nouveau dépôt avec un
historique Git neuf et un backend Supabase neuf.

ADR-0003 cible :

- Windows 11 x64 sur une version publique encore maintenue ;
- MSFS 2024 stable ;
- Microsoft Store/Xbox App et Steam à valider séparément ;
- aucun support Windows 10, ARM64, MSFS 2020 ou Preview dans le MVP.

L'ancien dépôt mélange actuellement plusieurs générations de versions et contient
des écarts entre environnement local, manifests et CI. Le nouveau dépôt ne doit
pas reproduire ces incohérences.

T0005 est un ticket de recherche et de décision. Il ne crée pas encore le nouveau
dépôt et ne met aucune dépendance à jour.

## Research requirement

L'exécution nécessite une recherche web actualisée à la date du ticket.

Utiliser en priorité :

- documentation officielle et pages de releases des projets ;
- politiques officielles de support/LTS ;
- registres officiels npm, NuGet, crates.io et GitHub Releases du mainteneur ;
- Microsoft Learn pour .NET, ASP.NET Core, SignalR, WebView2 et Windows ;
- documentation officielle Tauri et Rust ;
- documentation officielle Supabase ;
- documentation officielle MSFS/SimConnect ;
- avis de sécurité GitHub, RustSec, npm et NuGet.

Pour chaque décision conserver :

- URL directe ;
- titre de la source ;
- date de consultation ;
- version et date de publication ;
- politique de support ;
- distinction entre information officielle et inférence.

Un blog, une réponse Stack Overflow ou un commentaire communautaire ne peut pas
être l'unique source d'un choix structurant.

## Components in scope

### Outils et runtimes

- Node.js ;
- npm ou autre gestionnaire de paquets si changement justifié ;
- TypeScript ;
- Rust toolchain et politique MSRV ;
- .NET SDK/runtime ;
- PowerShell requis pour les scripts ;
- GitHub Actions utilisées pour CI/release ;
- Supabase CLI ;
- Deno pour les Edge Functions si encore applicable.

### Desktop et frontend

- Tauri v2 et CLI ;
- plugins Tauri strictement nécessaires ;
- React ;
- React DOM ;
- Vite ;
- Vitest ;
- Testing Library ;
- Tailwind CSS ;
- routeur ;
- bibliothèque SignalR cliente ;
- SDK Supabase JavaScript.

### Bridge et intégrations

- ASP.NET Core ;
- SignalR serveur ;
- bibliothèque SimConnect .NET ou SDK officiel ;
- sérialisation et validation ;
- client HTTP/résilience ;
- framework de tests .NET ;
- outil de replay ou abstraction maison à décider.

### Backend et données

- version PostgreSQL fournie/supportée par Supabase ;
- Supabase Auth, Realtime, Storage si nécessaire ;
- Edge Functions ;
- génération des types ;
- framework de tests SQL/RLS ;
- migrations et environnement local.

Les bibliothèques fonctionnelles non fondatrices — cartes, graphiques, icônes,
dates, formulaires — sont hors de la décision initiale sauf si elles imposent une
contrainte de compatibilité globale.

## Inputs required from Andy

1. Préfères-tu les versions LTS lorsqu'elles existent, même si une version stable
   plus récente est disponible ?
2. Quelle durée minimale de support souhaites-tu couvrir sans changement majeur :
   12, 18, 24 ou 36 mois ?
3. Acceptes-tu une mise à niveau majeure pendant le développement du MVP ?
4. Veux-tu conserver npm ou autorises-tu l'étude de pnpm ?
5. Souhaites-tu rester sur React ou comparer une alternative frontend ?
6. Supabase reste-t-il un choix ferme pour le nouveau backend ?
7. Tauri v2 reste-t-il un choix ferme pour le desktop ?
8. Préfères-tu un runtime .NET embarqué autonome dans l'application ?
9. Acceptes-tu d'utiliser le SDK SimConnect officiel si le wrapper actuel n'offre
   pas une maintenance ou une compatibilité suffisante ?
10. Quel rythme de mise à jour souhaites-tu après lancement : mensuel,
    trimestriel ou seulement pour sécurité/compatibilité ?

Une réponse qui remet en cause Tauri, Supabase, React ou .NET peut modifier
l'architecture ; dans ce cas, produire une ADR dédiée ou bloquer le ticket avant
de poursuivre.

### Réponses reçues le 26 juillet 2026

1. Pas de préférence LTS systématique.
2. Douze mois minimum sans changement majeur.
3. Mise à niveau majeure autorisée pendant le MVP.
4. pnpm peut être étudié.
5. Une alternative à React peut être étudiée si elle est plus stable et
   performante.
6. Firebase peut être comparé à Supabase.
7. Choisir le shell le plus stable et économe en ressources ; Electron exclu.
8. Choisir le mode .NET le plus sûr et performant.
9. SDK SimConnect officiel autorisé selon maintenance et compatibilité.
10. Revue mensuelle après lancement.

## Dependencies

- T0001 terminé.
- T0002 terminé.
- T0003 terminé.
- T0004 terminé sans conflit Git.
- ADR-0001, ADR-0002 et ADR-0003 acceptées.
- `docs/PRODUCT.md`
- `docs/ARCHITECTURE.md`
- `docs/SECURITY.md`
- `docs/QUALITY.md`
- `docs/SUPPORT.md`

## Allowed areas

- `docs/STACK.md`
- `docs/ARCHITECTURE.md`
- `docs/QUALITY.md`
- `docs/SECURITY.md`
- `docs/CURRENT_STATE.md`
- `docs/ROADMAP.md`
- `docs/KNOWN_ISSUES.md`
- `docs/decisions/`
- `docs/tickets/README.md`
- ce ticket

## Do not touch

- `app/`
- `sim-bridge/`
- `supabase/`
- `legacy/`
- `.github/`
- scripts existants
- manifests et lockfiles
- installation locale des SDK/runtimes
- création du nouveau dépôt
- téléchargement ou installation d'une dépendance candidate

## Requirements

### 1. Inventorier l'ancien dépôt

Pour chaque composant existant, relever depuis les manifests/lockfiles :

- version déclarée ;
- version verrouillée réelle ;
- usage principal ;
- dépendances directes qui lui imposent une contrainte ;
- avertissements ou vulnérabilités déjà connus ;
- statut : conserver conceptuellement, remplacer ou réévaluer.

Ne jamais afficher la valeur d'une variable secrète.

### 2. Construire la matrice des versions

Créer dans `docs/STACK.md` une table minimale :

| Composant | Ancien dépôt | Dernière stable | Recommandée | Support jusqu'à | Compatibilités | Décision |
| --- | --- | --- | --- | --- | --- | --- |

Chaque ligne doit expliquer :

- pourquoi la version recommandée est adaptée ;
- pourquoi une version plus récente éventuelle est écartée ;
- les contraintes Windows 11 x64 ;
- les contraintes avec les autres composants ;
- les breaking changes pertinents ;
- les risques et inconnues.

### 3. Valider les groupes de compatibilité

Étudier au minimum les groupes suivants comme ensembles, pas composant par
composant :

#### Groupe A — Frontend

`Node → npm → TypeScript → React → Vite → Vitest → Tailwind`

Vérifier engines, types React, plugin Vite, environnement jsdom et compatibilité
de build.

#### Groupe B — Desktop

`Windows 11 x64 → WebView2 → Rust → Tauri → plugins Tauri → sidecar`

Vérifier toolchain MSVC, MSRV, format du sidecar, capabilities, updater et
signature.

#### Groupe C — Bridge

`.NET → ASP.NET Core → SignalR → SimConnect → packaging self-contained`

Vérifier support Microsoft, architecture x64, dépendances natives, single-file,
trim/AOT éventuels et compatibilité MSFS 2024.

#### Groupe D — Backend

`Supabase CLI → PostgreSQL → Auth → RLS → Realtime → Edge Functions → SDK JS`

Vérifier versions locales/cloud, Deno, génération de types, migrations et
compatibilité des clients.

#### Groupe E — CI/release

`GitHub Actions → Node/.NET/Rust → Tauri build → signature → updater`

Vérifier runners Windows, actions épinglables, caches, provenance et secrets de
signature.

### 4. Définir la politique de versions

L'ADR doit décider :

- LTS vs Current pour Node et .NET ;
- version exacte vs plage autorisée ;
- lockfiles obligatoires ;
- politique Rust stable et `rust-toolchain.toml` ;
- politique MSRV ;
- fréquence de mise à jour ;
- fenêtre de test avant mise à niveau majeure ;
- traitement des correctifs de sécurité ;
- outils automatiques autorisés, par exemple Dependabot ;
- règle d'acceptation d'une dépendance abandonnée ;
- durée de conservation d'une version de build.

### 5. Évaluer SimConnect séparément

Comparer au minimum :

- wrapper `SimConnect.NET` actuel ;
- SDK/API SimConnect officiel Microsoft ;
- éventuel adaptateur interne autour de l'une de ces options.

Évaluer :

- maintenance et cadence de release ;
- compatibilité MSFS 2024 ;
- dépendances natives ;
- documentation ;
- licence ;
- capacité de simulation/mock/replay ;
- single-file/self-contained ;
- risque supply chain ;
- plan de remplacement.

La décision doit privilégier une abstraction interne stable, même si une
bibliothèque externe est retenue.

### 6. Effectuer une revue sécurité et licences

Pour chaque dépendance runtime recommandée :

- licence ;
- mainteneur/source ;
- historique de maintenance ;
- vulnérabilités connues ;
- scripts d'installation ;
- permissions/capabilities ;
- nombre et risque des dépendances transitives ;
- alternative si le composant est abandonné.

Une dépendance critique non maintenue ou sans licence claire ne peut pas être
retenue sans exception écrite.

### 7. Produire un ordre d'adoption

Découper la création du nouveau socle en tickets indépendants, par exemple :

1. runtimes et source de version ;
2. shell Tauri minimal ;
3. frontend React minimal ;
4. bridge .NET minimal ;
5. contrat local et health check ;
6. Supabase local ;
7. CI multi-stack ;
8. packaging Windows non signé ;
9. signature et updater.

Chaque ticket doit avoir son propre build/test et ne pas introduire plusieurs
groupes majeurs sans validation intermédiaire.

### 8. Propager la décision

Après acceptation :

- créer `docs/decisions/ADR-0004-stack-cible.md` ;
- créer `docs/STACK.md` ;
- mettre `ARCHITECTURE.md`, `QUALITY.md` et `SECURITY.md` en cohérence ;
- adapter `ROADMAP.md` ;
- ajouter les risques différés dans `KNOWN_ISSUES.md` ;
- actualiser `CURRENT_STATE.md` ;
- renuméroter l'ancien sujet « budgets stabilité et performance » dans un prochain
  ticket disponible sans réutiliser T0005.

## Non-goals

- Installer les versions retenues.
- Modifier une dépendance de l'ancien dépôt.
- Créer le nouveau dépôt.
- Générer les nouveaux manifests ou lockfiles.
- Implémenter le frontend, le bridge ou Supabase.
- Choisir toutes les bibliothèques UI/métier.
- Résoudre une incompatibilité par du code.
- Utiliser automatiquement la toute dernière version.

## Acceptance criteria

- [x] Les dix questions d'Andy ont une réponse ou le ticket reste `Blocked`.
- [x] Toutes les informations évolutives sont sourcées et datées.
- [x] Chaque composant a une version actuelle, dernière stable et recommandée.
- [x] Les groupes A à E ont une conclusion de compatibilité explicite.
- [x] Node et .NET ont une décision LTS/Current justifiée.
- [x] La politique Rust/MSRV est définie.
- [x] Tauri/WebView2/sidecar sont compatibles avec Windows 11 x64.
- [x] Le choix SimConnect est documenté avec une stratégie d'abstraction.
- [x] Supabase local/cloud et Edge Functions ont des versions compatibles.
- [x] Les dépendances runtime ont une revue sécurité/licence.
- [x] L'ordre d'adoption est découpé en petits tickets vérifiables.
- [x] `ADR-0004-stack-cible.md` est accepté.
- [x] `docs/STACK.md` est exploitable pour créer les manifests du nouveau dépôt.
- [x] Aucun code, manifest, lockfile ou workflow n'est modifié.

## Security review

### Assets

- chaîne de build ;
- dépendances et registres ;
- secrets CI/release ;
- binaire desktop et sidecar ;
- backend Supabase ;
- mécanisme de mise à jour.

### Abuse and failure cases

- typosquatting ou package compromis ;
- dépendance abandonnée ;
- script d'installation non nécessaire ;
- action GitHub flottante compromise ;
- versions locales différentes de la CI ;
- runtime en fin de support ;
- plugin Tauri demandant des capacités trop larges ;
- wrapper SimConnect distribuant un binaire natif non vérifié ;
- mise à niveau automatique cassant les lockfiles ;
- secret de signature exposé à une PR.

### Required controls

- lockfiles et versions reproductibles ;
- actions CI épinglées par SHA ;
- provenance et checksum des outils ;
- permissions minimales ;
- scans npm, NuGet et RustSec ;
- SBOM ;
- séparation build/signature/publication ;
- revue humaine des mises à niveau majeures ;
- exception documentée et datée pour toute dépendance à risque.

## Automated validation

Ticket documentaire : aucun build applicatif requis.

```powershell
# Vérifier les livrables
Test-Path docs/STACK.md
Test-Path docs/decisions/ADR-0004-stack-cible.md

# Vérifier les rubriques essentielles
rg -n "Node|React|Tauri|Rust|\\.NET|SimConnect|Supabase|PostgreSQL|LTS|MSRV" `
  docs/STACK.md docs/decisions/ADR-0004-stack-cible.md

# Examiner strictement la portée du ticket
git diff --name-only
```

La validité des versions et de leurs compatibilités exige une revue humaine des
sources officielles.

## Manual verification

1. Choisir un composant, par exemple Node, Tauri ou .NET.
2. Retrouver sa version actuelle, dernière stable et recommandée.
3. Vérifier la source officielle et la date.
4. Suivre ses contraintes jusqu'aux composants dépendants.
5. Vérifier qu'un plan de test existe avant son adoption.
6. Choisir une dépendance critique et vérifier licence, maintenance et alternative.
7. Confirmer qu'aucune version n'est recommandée uniquement parce qu'elle est la
   plus récente.

Temps cible : 15 minutes.

## Rollback

Tant que le nouveau dépôt n'est pas créé, une nouvelle ADR peut remplacer ADR-0004.
Après création du socle, toute modification majeure de stack exige :

- une ADR qui remplace ADR-0004 ;
- une matrice de compatibilité actualisée ;
- un plan de migration ;
- un rollback vers les derniers manifests/lockfiles validés.

## Completion Report

À remplir après décision.

### Summary

Stack de la réécriture sélectionnée et politique de versions définie. Les choix
ouverts par Andy ont été comparés; Tauri/React/Supabase restent retenus, avec
pnpm, .NET 10 LTS et le SDK SimConnect officiel abstrait.

### Recommended stack

Node 24/pnpm 11/TypeScript 6/React 19/Vite 8/Tauri 2.11/Rust stable/.NET 10/
SimConnect officiel/Supabase PostgreSQL 17. Détails dans `docs/STACK.md`.

### Versions selected

Matrice complète dans `docs/STACK.md`; versions directes exactes et lockfiles
obligatoires, revue mensuelle.

### Official sources consulted

Sources Node, npm, React, Vite, Vitest, Tauri, Rust, Microsoft .NET/WebView2/
SignalR/MSFS, Supabase, Firebase, NuGet et GitHub Advisory listées avec URL dans
`docs/STACK.md`, consultées le 26 juillet 2026.

### Compatibility conclusions

Groupes A à E compatibles sous les réserves consignées : TypeScript 7 différé,
packaging SimConnect/.NET 10 à prouver, parité Supabase local/cloud à tester,
actions et secrets de signature à isoler.

### Security and license review

Licences et maintenance des dépendances runtime fondatrices revues. Tauri
2.11.1+ requis pour les correctifs ACL/origines; React 19.2.8 est postérieur aux
correctifs RSC. Aucune exception de dépendance à risque n'est accordée.

### Files changed

`docs/STACK.md`, `docs/decisions/ADR-0004-stack-cible.md`,
`docs/ARCHITECTURE.md`, `docs/QUALITY.md`, `docs/SECURITY.md`,
`docs/CURRENT_STATE.md`, `docs/ROADMAP.md`, `docs/KNOWN_ISSUES.md`,
`docs/tickets/README.md` et ce ticket.

### Commands and results

Inventaire local des manifests/lockfiles et recherches `rg` réussis.
`Test-Path` des deux livrables : `True`/`True`. Recherche des rubriques
essentielles : réussie. Contrôle des zones interdites : aucune modification.
`git diff --check` : réussi, avec avertissements de normalisation LF/CRLF
seulement. Aucun build applicatif exécuté, conformément au ticket documentaire.

### Manual verification result

Revue agent effectuée sur Node, Tauri, .NET, SimConnect, Supabase et les
dépendances critiques. Andy a validé T0005 le 30 juillet 2026. La direction de
stack reste celle de l'ADR-0004 acceptée ; les performances, le packaging et la
compatibilité MSFS demeurent des preuves à produire dans leurs tickets
d'adoption respectifs.

### Risks and limitations

Aucun benchmark ni test MSFS/cloud/packaging n'a été exécuté. Les versions sans
LTS contractuelle exigent la revue mensuelle. Risques différés KI-013 à KI-015.

### Follow-ups

T0006 à T0015 dans `docs/tickets/README.md`; détails créés progressivement.

### Documentation updated

Architecture, qualité, sécurité, roadmap, état courant, problèmes connus,
matrice, ADR et index des tickets mis en cohérence.

### Git handoff

Branche : `docs/t0005-stack-cible`. Branche distante par défaut :
`origin/main`. Aucun upstream sur la branche. Message proposé :
`docs: select target stack for rebuild`.

`AGENTS.md` et `docs/WORKFLOW.md` sont des modifications préexistantes hors
T0005. `docs/CURRENT_STATE.md` et `docs/tickets/README.md` contenaient déjà des
modifications préexistantes avant T0005 et ont aussi reçu des changements du
ticket : une revue/staging par hunks est nécessaire avant commit. Aucun commit,
push ou PR n'a été exécuté.

### Closure evidence

Andy a approuvé la revue humaine le 30 juillet 2026. Le ticket passe de `Verify`
à `Done` dans la maintenance documentaire `docs/phase0-gate-closure`; aucune
version, dépendance, ADR ou frontière technique n'est modifiée par cette
transition.
