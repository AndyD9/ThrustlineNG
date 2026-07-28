# État actuel du dépôt

Dernière revue documentaire : 24 juillet 2026 (ticket T0003).
Statut : baseline locale vérifiée ; validations externes encore requises.

## Produit

La version existante est une alpha active de gestion de compagnie aérienne
virtuelle. Le routeur et la navigation exposent les parcours suivants :

- authentification et création initiale d'une compagnie ;
- tableau de bord, compagnie, flotte et marchés d'avions ;
- routes, dispatch/SimBrief, vols et suivi de vol en direct ;
- horaires et opérations passives ;
- équipage, finances, paramètres, EFB et succès.

Le code contient aussi des services de maintenance, expérience passager, ACARS,
météo, événements de jeu et calculs d'atterrissage. T0001 prouve leur présence
dans le dépôt, pas leur fonctionnement de bout en bout. Il n'existe pas encore de
version publique stable.

## Stack active et versions observées

Baseline exécutée sous Windows le 24 juillet 2026 :

- Node.js `24.14.1` et npm `11.11.0` ;
- SDK .NET `10.0.201`, projet bridge ciblant `net8.0` ;
- `rustc 1.94.1` et `cargo 1.94.1` ;
- Supabase CLI non installée/non trouvée ;
- Tauri v2 / Rust, React 18 / TypeScript / Vite / Tailwind ;
- ASP.NET Core et SimConnect.NET pour le bridge ;
- REST et SignalR sur loopback entre UI et bridge ;
- Supabase Auth/PostgreSQL/RLS/Realtime/Edge Functions.

Le moteur Node déclaré par `app/package.json` est `>=24.18.0 <25`. La machine de
baseline est donc en dessous de la version minimale, même si les tests et le
build frontend réussissent. Les workflows CI utilisent Node `24.18.0`, .NET 8.x
et Rust stable.

## Inventaire reproductible

- Lockfiles : `app/package-lock.json` et `app/src-tauri/Cargo.lock`.
- Scripts npm : `dev`, `build`, `test`, `test:watch`, `test:coverage`, `preview`,
  `tauri`, `tauri:dev`, `tauri:build`, `sidecar:build`.
- Scripts dépôt : `scripts/build-sidecar.ps1` et
  `scripts/security-check.ps1`.
- Workflows : `.github/workflows/ci.yml` et
  `.github/workflows/security.yml`.
- Migrations Supabase append-only constatées : 25.
- Dépendances directes : 11 npm runtime, 12 npm développement, 2 NuGet,
  6 Cargo runtime et 1 Cargo build.
- Variables/configurations relevées par nom seulement :
  `VITE_SUPABASE_URL`, `VITE_SUPABASE_ANON_KEY`, `VITE_SIM_BRIDGE_URL`,
  `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `SUPABASE_SERVICE_ROLE_KEY` et
  `THRUSTLINE_BRIDGE_TOKEN`.

## Procédure vérifiée depuis un clone propre

Installer Windows, Node `24.18.x`, npm, le SDK .NET 8, Rust stable et les
prérequis Tauri v2, puis exécuter depuis la racine :

```powershell
Set-Location app
npm ci
npm test
npm run build

Set-Location ..\sim-bridge
dotnet restore
dotnet build --configuration Release
dotnet test --configuration Release

Set-Location ..\app\src-tauri
cargo check --locked

Set-Location ..\..
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\security-check.ps1
```

Configurer uniquement après restauration les variables nécessaires dans un
fichier local non versionné. L'exécution de l'application et les validations
cloud nécessitent une instance Supabase configurée. Le suivi réel nécessite
MSFS/SimConnect. Le packaging signé nécessite un certificat approprié.

## Validation exécutée le 24 juillet 2026

- `npm ci` : réussi depuis le lockfile ; avertissement `EBADENGINE` à cause de
  Node `24.14.1` ; audit npm signalant 2 vulnérabilités modérées.
- `npm test` : 4 fichiers, 11 tests réussis.
- `npm run build` : TypeScript/Vite réussi.
- `dotnet restore` : réussi.
- `dotnet build --configuration Release` : réussi, 0 avertissement, 0 erreur.
- `dotnet test --configuration Release` : code 0, mais aucun projet de tests ni
  test exécuté.
- `cargo check --locked` : réussi ; avertissement d'environnement sur la
  canonicalisation de `C:\Users\andyd`.
- `scripts/security-check.ps1` : invariants réussis lorsque PowerShell est lancé
  avec `-ExecutionPolicy Bypass`.

Les premiers essais de `npm ci`, `dotnet restore` et `dotnet test` ont échoué
par refus d'accès du bac à sable aux caches/configurations utilisateur, puis ont
réussi avec cet accès autorisé. Le premier lancement direct du script de sécurité
a été bloqué par la politique PowerShell locale, puis a réussi avec le bypass
explicite. Ces échecs sont classés comme environnement, pas comme défauts du code.

## Contrôles non exécutables dans cette baseline

- Connexion réelle à MSFS/SimConnect, replay de trace et parcours de vol : MSFS
  absent et aucun replay automatisé fourni.
- Démarrage/reset Supabase local, application des migrations et tests RLS entre
  deux utilisateurs : Supabase CLI absente et aucun environnement de test fourni.
- Déploiement de l'Edge Function et validation cloud : projet/identifiants
  Supabase absents.
- Build installable signé, installation, mise à jour et rollback : aucun
  certificat de signature ni pipeline de release complet fourni.
- Validation manuelle complète de l'interface : services externes requis absents.

## Sécurité déjà présente

- Bridge lié à localhost.
- Jeton aléatoire d'instance entre Tauri et bridge.
- CSP Tauri et capacités limitées.
- Clôture de vol privilégiée déplacée vers une Edge Function/RPC.
- Migrations de durcissement RLS/grants.
- CI avec audits de dépendances, scan de secrets et invariants.

## Dette et risques structurants

- Aucun projet de tests .NET dédié constaté.
- Aucun test RLS automatisé livré constaté.
- Le build Tauri complet dépend du sidecar généré dans `externalBin`.
- L'environnement local Node ne satisfait pas le moteur déclaré.
- Les README divergent (`Node 24.18 LTS` contre `Node 20+`) et utilisent
  `npm install` au lieu de la restauration déterministe `npm ci`.
- Deux vulnérabilités npm modérées sont signalées ; aucune mise à jour n'a été
  faite dans T0001.
- Pages React volumineuses et mélange UI/orchestration/données.
- Mutations métier directes depuis le client et séquences multi-écritures non
  atomiques.
- Pas de pipeline complet de release signée/updater.
- Versions répétées dans plusieurs manifestes.
- Politique de suppression/récupération du propriétaire et durée de rétention à
  définir avant toute suppression irréversible.

## Travail local à préserver

La modification utilisateur de `app/src-tauri/Cargo.toml` est restée intacte
pendant T0001. Son empreinte SHA-256 avant et après validation est
`94BF4E46145BC363B70BD3EEE5BBA578EF198718EBDADB7264C260FEAFAE2AFE`.
Les autres modifications utilisateur préexistantes n'ont pas été intégrées au
ticket.

## Décision produit

`ADR-0001` retient un MVP solo connecté préparé pour une collaboration
ultérieure : au plus une compagnie par utilisateur, un propriétaire humain
unique, aucun membre ni rôle collaboratif dans le MVP. La collaboration probable
après le MVP exigera une nouvelle ADR.

## Décision de refonte

`ADR-0002` retient une réécriture totale isolée dans un nouveau dépôt avec un
historique Git neuf. Le dépôt actuel devient une référence en lecture seule pour
l'UX, les comportements et la documentation jusqu'à parité du golden path, puis
il sera archivé. Le nouveau produit utilise un schéma Supabase neuf : les données
actuelles sont uniquement des données de développement et ne seront pas migrées.
Il n'y aura ni coexistence en production, ni double écriture, ni ancien client
connecté au nouveau backend. Une seule bascule publique est prévue après les
gates de caractérisation, SimConnect, parité, restauration et distribution.

## Décision de support

`ADR-0003` retient Windows 11 x64, sur une version publique encore maintenue par
Microsoft, et MSFS 2024 stable uniquement. Microsoft Store/Xbox App et Steam sont
deux combinaisons distinctes qui restent `Unsupported — validation requise`
jusqu'à une fiche de test réelle par canal. Windows 10, ARM64, MSFS 2020,
Windows Insider et les builds MSFS Beta/Preview sont `Unsupported`.

Une machine Ryzen 7 5800X, 32 Go et RX 6070 XT est disponible comme profil
recommandé de validation. Elle ne prouve pas le minimum matériel. Aucun test
MSFS réel n'a été exécuté dans T0004.

## Décision de stack cible

`ADR-0004` retient Node 24 LTS avec pnpm 11, React 19/Vite 8, Tauri 2.11 sur
WebView2 Evergreen, Rust stable épinglé, un bridge .NET 10 LTS self-contained
`win-x64`, le SDK SimConnect officiel derrière une abstraction interne, et
Supabase/PostgreSQL 17. Firebase, Electron et le wrapper `SimConnect.NET` ne sont
pas les fondations de la refonte.

Cette décision est désormais partiellement adoptée par les pins de toolchain, le
shell Tauri, le frontend React et le bridge .NET minimal. Les performances et la
compatibilité self-contained avec le futur adaptateur SimConnect restent à
prouver par les tickets d'adoption.

## Bridge .NET minimal

T0009 ajoute un processus console .NET 10 publiable self-contained `win-x64`.
Il expose un diagnostic local `--health-check`, rejette les arguments inconnus
et gère une annulation propre. Quatre scénarios unitaires passent sans package
NuGet tiers. Le bridge n'est pas encore lancé par Tauri, n'ouvre aucun port et
ne contient ni SimConnect, ni secret, ni donnée métier.

La publication vérifiée contient 191 fichiers pour environ 80,5 Mo. Cette mesure
est informative ; T0015 fixera les budgets.

## Contrat local

T0010 ajoute un serveur ASP.NET Core lié à `127.0.0.1`, un health check REST
versionné et une surface SignalR vide. Chaque requête exige un jeton éphémère de
256 bits créé par Tauri. Le desktop lance et termine le bridge sans exposer le
jeton à la WebView. SimConnect, les données métier et la reconnexion après crash
restent absents.

## Prochain ticket recommandé

`T0011 — Créer l'adaptateur SimConnect et le replay` doit isoler le SDK officiel
derrière une interface testable et introduire des traces synthétiques, sans
connecter encore de logique économique.

## Mise à jour de ce fichier

Après chaque ticket terminé, modifier uniquement :

- capacités réellement disponibles ;
- structure ou dépendances actives ;
- validation réellement exécutée ;
- dette ajoutée/résolue ;
- prochain ticket recommandé.

Ne pas y copier l'historique Git ni les projets futurs.
