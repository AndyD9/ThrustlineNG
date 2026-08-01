# État actuel du dépôt

Dernière revue documentaire : 1er août 2026 (preuve locale T0023 de la
frontière Edge d'onboarding).
Statut : les implémentations T0012 à T0019 sont fusionnées dans `main`. T0005,
T0006 et T0013 à T0017 sont `Done`. La phase 0 est terminée, la phase 1 a
franchi conditionnellement son gate de reproductibilité et la phase 2 est
active sous interdiction de données utilisateur réelles. T0021 résout `KI-017` :
la pile locale est isolée et ses trois sockets Windows écoutent uniquement sur
`127.0.0.1`. Andy confirme l'inspection visuelle de Studio le 31 juillet 2026.
T0012 reste `Verify` tant que la correction T0021 n'est pas fusionnée dans
`main`.

T0018 et T0019 sont présents dans `main` mais restent `Verify` car leurs
checklists humaines n'ont pas été exécutées. T0020–T0022 ne sont pas dans
`main` : les PR #35–#37 ont été fusionnées dans leurs branches parentes, sans
propager ensuite la pile jusqu'à `main`. T0020 reste `Verify`, T0021 et T0022
restent `Review`. T0023 ajoute sur une nouvelle branche empilée un appelant Edge
authentifié avec preuves Node et PostgreSQL 17 locales.

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
- Supabase CLI absente lors de la baseline, puis épinglée à 2.109.1 par T0012 ;
- Docker Desktop 29.6.2 utilisé pour la vérification locale T0012 ;
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
- Workflows du nouveau socle dans `main` :
  `.github/workflows/ci.yml` et `.github/workflows/security.yml`.
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

## Vérification clean-clone du socle

Le 30 juillet 2026, un clone distant propre de `main` au commit `c9966e2` a
suivi `docs/SETUP.md` sur Windows 11 x64. Les versions épinglées ont été
confirmées, `CheckOnly` n'a rien modifié et deux bootstraps successifs ont laissé
le clone sans diff.

Les 15 assertions toolchain, le frontend, le desktop Tauri, le bridge .NET et
les contrôles statiques backend, politique de données, CI, budgets et packaging
ont réussi. Le build Tauri Release et le build bridge Release ont été produits
sans secret. Cette preuve clôt T0006 ; elle ne clôt pas les vérifications
interactives T0007 à T0009, les essais MSFS T0011 ni le démarrage loopback T0012.

La revue `docs/reviews/PHASE-1.md` combine cette preuve Windows avec le backend
PostgreSQL 17 réel de la CI T0013. Elle accorde un passage conditionnel vers la
phase 2 sans fermer les vérifications environnementales restantes, sans
provisionner staging/production et sans autoriser de donnée utilisateur réelle.

## Contrôles non exécutables dans cette baseline

- Connexion réelle à MSFS/SimConnect et parcours de vol : MSFS absent. Le replay
  synthétique automatisé T0011 ne remplace pas une trace réelle avec provenance.
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
- Le runtime Supabase local repose sur un daemon DinD privilégié et conserve un
  volume de cache d'images ; il ne monte ni socket Docker hôte ni source du
  dépôt complète.
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
- T0016 remplace `react-router` 7.18.1 par 8.3.0 pour
  `GHSA-qwww-vcr4-c8h2` ; l'audit local et le workflow supply-chain GitHub sont
  verts, et `KI-018` est résolu dans `main`.
- Cargo ne signale aucune vulnérabilité, mais plusieurs crates GTK3 non
  maintenues et `glib` 0.18.5 unsound restent dans le lockfile multi-plateforme.
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

La vision et le périmètre de `PRODUCT.md` ont passé leur revue de cohérence et
sont validés pour la phase 1 depuis le 30 juillet 2026. Cette validation ne
prouve ni les objectifs encore non mesurés, ni le support réel d'un canal
Windows/MSFS.

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
shell Tauri, le frontend React, le bridge .NET minimal et la configuration
Supabase locale PostgreSQL 17. Les performances, la parité Supabase local/cloud
et la compatibilité réelle avec MSFS restent à prouver.

## Bridge .NET minimal

T0009 ajoute un processus console .NET 10 publiable self-contained `win-x64`.
Il expose un diagnostic local `--health-check`, rejette les arguments inconnus
et gère une annulation propre. Quatre scénarios unitaires passent sans package
NuGet tiers. Le bridge n'est pas encore lancé par Tauri, n'ouvre aucun port et
ne contient ni SimConnect, ni secret, ni donnée métier.

La publication courante mesurée par T0015 contient 334 fichiers pour
110 477 582 octets. Le budget de fondation est 128 Mio et son gate est présent
dans `main`.

## Contrat local

T0010 ajoute un serveur ASP.NET Core lié à `127.0.0.1`, un health check REST
versionné et une surface SignalR vide. Chaque requête exige un jeton éphémère de
256 bits créé par Tauri. Le desktop lance et termine le bridge sans exposer le
jeton à la WebView. Les données métier et la reconnexion après crash restent
absentes ; la source SimConnect T0011 n'est pas exposée sur ce contrat.

## Adaptateur SimConnect et replay

T0011 ajoute `ISimConnectAdapter`, un échantillon de vol validé, un adaptateur
natif sans package tiers et un replay JSONL strict. Tous les appels natifs sont
confinés à une boucle dédiée et la télémétrie reste déconnectée de REST, SignalR,
du frontend et de l'économie.

Une trace synthétique de huit points se rejoue sans MSFS. Elle couvre sol,
décollage, montée, croisière, descente et retour au sol, mais ne prouve ni le SDK
installé, ni MSFS 2024 Store/Steam, ni un comportement d'avion réel. Aucun
binaire de l'ancien build n'est copié.

## Budgets stabilité et performance

T0015 ajoute une source JSON unique, un validateur fail-closed, cinq scénarios de
harnais et un gate CI sur les tailles construites. Les baselines T0008 et la
nouvelle mesure bridge respectent les seuils de fondation. L'implémentation est
fusionnée dans `main` par la PR #22.

Les objectifs MVP de démarrage, mémoire intégrée, quatre heures, installation et
sessions sans crash restent `Not measured`. La campagne GUI T0015 passe avec
cinq lancements froids, cinq chauds, dix cycles propres, un WebView2 et un bridge
associés par mesure, et zéro processus orphelin. Andy a validé le ticket le
30 juillet 2026 ; il est `Done` sans changer aucun statut de support.

## Backend Supabase local et RLS

T0012 épingle Supabase CLI 2.109.1 et ajoute une configuration locale
PostgreSQL 17, une migration append-only `companies`, un seed synthétique, des
types TypeScript et deux fichiers pgTAP. La migration impose un propriétaire
Auth unique, force la RLS et sépare les politiques CRUD du rôle
`authenticated`.

Le harnais statique T0021 passe avec sept mutations négatives. Le runtime copie
seulement les sources Supabase filtrées dans un volume, exécute la CLI dans un
conteneur sans socket Docker hôte et place la pile dans un daemon DinD dédié.
Docker et `Get-NetTCPConnection` confirment le 31 juillet 2026 que 54321–54323
écoutent uniquement sur `127.0.0.1`. Deux resets successifs, 8 fichiers/148
assertions pgTAP et le contrôle des types passent localement. Le redémarrage avec
cache prend 45,5 s ; Studio répond 200 et PostgreSQL contient uniquement les
deux identités `.invalid`. Andy confirme leur inspection visuelle dans Studio le
31 juillet 2026. Aucune parité cloud n'est revendiquée et la capacité n'est pas
présente dans `main` avant fusion de la pile de PR.

## Politique de données

T0017 ajoute dans `main` une source JSON versionnée et une politique
d'ingénierie pour huit catégories et quatre environnements. Local, CI et staging
refusent les données de production. Les maxima initiaux sont de
7 jours pour la télémétrie brute après rapport, 30 jours pour diagnostics et
sauvegardes, et 90 jours pour les journaux sécurité.

L'admission de données utilisateur réelles reste bloquée. T0018 implémente
l'export et la suppression transactionnelle du compte actuel en local/CI. T0019
prouve une restauration PostgreSQL 17 isolée et le replay post-sauvegarde sur
données synthétiques. Purge, sauvegarde managée, purge du journal pseudonyme et
restauration de production restent `Not implemented`. L'anonymisation du grand
livre T0020 est prouvée uniquement en local/CI synthétique. `KI-021` suit les
contrôles restants. Andy a validé T0017 le
30 juillet 2026 ; le ticket est `Done`.

## Export et suppression de compte

T0018 ajoute une migration append-only et quatre commandes serveur. Une session
Supabase créée depuis 5 minutes au plus peut demander une suppression,
récupérer l'export versionné et annuler pendant 7 jours. Les mutations directes
de compagnie sont bloquées pendant ce délai. Seul `service_role` peut finaliser
la suppression de la compagnie, de l'identité Auth et des liens temporaires.

Deux resets, 4 fichiers pgTAP et 70 assertions passent sur PostgreSQL 17 dans le
run GitHub `30616958479`. Deux transactions réellement concurrentes avec des
clés différentes convergent vers une demande et deux enregistrements
d'idempotence ; les types générés restent stables. T0021 permet désormais la
validation locale Windows et ses 70 assertions sont incluses dans le run local
de 148 assertions. La checklist humaine T0018 reste non exécutée ; le ticket
reste `Verify` et aucune donnée réelle n'est admise.

## Restauration isolée et replay des suppressions

T0019 ajoute un sujet de restauration opaque par compagnie et un événement
pseudonyme écrit dans la transaction de finalisation T0018. `anon` et
`authenticated` n'accèdent ni aux tables privées ni au replay ; seul
`service_role` peut appliquer un événement. Le rejeu identique est idempotent,
un contenu altéré ou un sujet inconnu échoue fermé et une panne injectée restaure
la transaction.

Le run GitHub `30621209180` valide deux resets, 6 fichiers pgTAP et
105 assertions sur PostgreSQL 17, la concurrence T0018 et les types stables. Un
dump pris avant la demande est restauré dans une base distincte non servie par
PostgREST : A est supprimé, B reste intact, `pgcrypto` 1.3 correspond à la
source, puis la cible et les fichiers temporaires sont détruits. Dump,
restauration et replay ont pris respectivement 158 ms, 228 ms et 76 ms sur ce
runner ; ces durées ne sont pas des objectifs RPO/RTO.

La preuve est bornée aux schémas `auth`, `public`, `private`, `extensions` et
`supabase_migrations`. Elle exclut Vault, Storage et les `DEFAULT ACL` des rôles
internes ; elle ne prouve ni sauvegarde managée/chiffrée, ni purge, ni
restauration ou promotion de production. Les assertions T0019 passent aussi
localement via T0021 ; le ticket reste `Verify` car sa checklist humaine n'a pas
été exécutée.

## Grand livre financier immuable

T0020 ajoute sur sa branche un sujet financier opaque par compagnie, des écritures
privées append-only et une commande d'ouverture réservée à `service_role`.
`authenticated` ne peut que lire les écritures de sa propre compagnie par une
fonction qui dérive l'identité du JWT. La suppression et le replay détachent le
lien personnel sans modifier les écritures.

Les gates statiques backend et politique T0020 passent avec respectivement 5 et 6
mutations négatives. Le run `30628851680` valide deux resets, 8 fichiers pgTAP,
148 assertions, la concurrence, la restauration/replay et les types stables sur
PostgreSQL 17. T0021 reproduit localement les 8 fichiers/148 assertions et les
types stables ; T0020 reste `Verify` pour sa checklist humaine et n'est pas
présent dans `main`.

## Onboarding de compagnie autoritaire

T0022 retire à `authenticated` les mutations directes de `public.companies` et
ajoute une commande `service_role` qui verrouille l'identité Auth, crée la
compagnie et son ouverture financière dans une transaction. Le registre privé
lie propriétaire, clé d'idempotence et empreinte du payload ; le rejeu identique
rend la même réponse, tandis qu'une collision, une identité anonyme, un compte en
suppression ou une deuxième compagnie échouent sans état partiel.

Localement sous Windows/Docker Desktop 29.6.2, deux resets, 10 fichiers pgTAP et
190 assertions passent avec `Result: PASS`; les types sont stables. Deux sessions
concurrentes convergent vers une compagnie, une commande et une écriture. La
checklist manuelle confirme rejeu, collision, refus d'une mutation directe et
rollback injecté avec l'état final `1|1|1|0|0`. T0022 reste empilé et n'est pas
présent dans `main`. La PR #37 a été fusionnée dans
`feature/T0020-immutable-ledger`, pas dans `main`; aucun appelant desktop/bridge,
donnée réelle ou environnement distant n'est ajouté. Les runs GitHub `30652926904` et
`30652926644` valident PostgreSQL 17, Windows multi-stack et la supply chain.

## Frontière Edge d'onboarding

T0023 ajoute `company-onboarding`, une Edge Function `POST` qui accepte
uniquement le nom et la clé d'idempotence. Elle vérifie le bearer token auprès
de Supabase Auth, refuse l'anonyme, dérive le propriétaire de la session et lit
montant/devise dans la configuration serveur avant d'appeler la RPC T0022 avec
`service_role`. Le corps est borné à 4 Kio et les réponses sont JSON `no-store`
sans détail SQL.

Les 14 tests Node, le gate backend T0012–T0023 avec 11 mutations, deux resets,
10 fichiers/190 assertions pgTAP et les types passent localement. L'intégration
Auth → Edge → RPC rend une réponse v1 active, rejoue les mêmes identifiants et
laisse exactement `1|1|1`; un appel sans JWT rend HTTP 401. L'Edge Runtime reste
derrière l'API loopback et n'ajoute aucun port externe. T0023 est en `Review`
sur `feature/T0023-authoritative-onboarding-endpoint`, empilée sur T0022 ; rien
de T0020–T0023 n'est livré dans `main` et aucune valeur économique de production
n'est décidée. L'arrêt local utilise désormais `--no-backup`; un
arrêt/redémarrage prouve que l'identité et la compagnie synthétiques T0023 ne
survivent pas dans le volume conservé pour les images. La PR #38 a été fusionnée
dans la branche T0022, pas dans `main`. La revue adversariale a ensuite corrigé
la minimisation de la réponse privilégiée dans `aa4d0a2`; la PR brouillon #39
cible également T0022. Les runs GitHub `30696692468` et `30696692529` valident
PostgreSQL 17, Windows multi-stack et la supply chain avant cette correction ;
ses checks GitHub restent à obtenir.

## CI multi-stack

T0013 ajoute un workflow de validation sur `windows-2025` et `ubuntu-24.04`,
ainsi qu'un workflow supply-chain en lecture seule. Les actions sont épinglées
par SHA, les credentials checkout ne persistent pas, les restaurations utilisent
les lockfiles sans cache de dépendances et les artefacts non signés expirent
après 30 jours.

Le job Windows couvre toolchain, frontend, Tauri et bridge. Le job Linux crée une
pile Supabase locale, inspecte les ports effectifs, rejoue deux resets, pgTAP et
les types, puis garantit l'arrêt. Le workflow supply-chain exécute pnpm audit,
l'audit NuGet transitif, cargo-audit 0.22.2, Gitleaks, un contrôle de licences et
un SBOM SPDX JSON. Un gate final agrège tous les résultats sans empêcher les
autres rapports d'être produits après un premier échec.

Localement, le harnais CI et ses deux mutations passent, le rapport couvre
566 composants, NuGet ne relève aucun package vulnérable et Cargo aucune
vulnérabilité. Le gate pnpm échoue correctement sur la vulnérabilité haute
`GHSA-qwww-vcr4-c8h2`. L'exécution GitHub `30437716790` valide Windows et
Supabase ; `30437717487` valide tous les contrôles supply-chain sauf le gate
pnpm attendu. Les deux artefacts ont été téléchargés et inspectés sans motif de
credential.

Après intégration de T0016 par la PR #16, les exécutions finales
`30442195734` et `30442195776` ont validé Windows, Supabase et la supply chain.
Andy a fusionné la PR #15 dans `main` le 29 juillet 2026 ; la capacité CI de
T0013 est désormais livrée.

T0016 remplace le paquet de réexport `react-router-dom` par `react-router` 8.3.0
et conserve le routage déclaratif SPA. Localement, l'installation figée,
l'audit pnpm, le typecheck, les 8 tests frontend, la couverture et le build
réussissent. Les workflows GitHub `30440481257` et `30440480513` valident
Windows, Supabase et la supply chain. La correction a été intégrée par les
PR #16 puis #15 et est présente dans `main`.

## Package Windows non signé

T0014 a été implémenté sur `foundation/t0014-windows-unsigned-packaging`, empilé
sur la réconciliation `f3350c6`. La PR #18 a été fusionnée le 29 juillet 2026 et
son commit final `30dcb393` est présent dans `main`. La première exécution GitHub
`30449481995` a validé Supabase et la supply chain ; le job Windows a échoué
après fabrication NSIS sur le chargement Authenticode de Windows PowerShell
5.1. Le rejeu `30451302116` a franchi Authenticode puis échoué sur
`Get-FileHash`, indisponible depuis le même module. Le calcul SHA-256 utilise
désormais directement l'API cryptographique .NET ; le build et le cycle
d'installation locaux passent. Le rejeu `30452603753` est vert, comme Supabase
et la supply chain. L'inspection de l'artefact `8724603795` a ensuite détecté que
le chemin desktop téléversé n'était pas celui du manifeste ; le chemin et son
invariant CI sont corrigés. Le rejeu final `30454097418` / `30454097327` est
entièrement vert. L'artefact `8725167519`, conservé jusqu'au 28 août 2026, a été
téléchargé : ses trois hashes correspondent au manifeste, les trois binaires
sont `NotSigned` et aucun motif de secret n'a été détecté.

PowerShell `7.6.4` est installé sous
`C:\Users\andyd\AppData\Local\Microsoft\WindowsApps\pwsh.exe`. Le `PATH` du
shell sandboxé Codex ne l'expose pas, mais le harnais toolchain exécuté avec ce
chemin explicite réussit ses 15 assertions.

Le dernier build local produit un NSIS x64 `currentUser` de 35 396 442 octets. Il
contient le desktop et 334 fichiers de bridge .NET 10 self-contained, soit
110 477 582 octets avant compression. L'installateur, le desktop et le bridge
sont `NotSigned`. Le manifeste SHA-256 ne contient aucun chemin utilisateur.

Quatre cycles installation/lancement/health check/fermeture/désinstallation ont
réussi dans une cible explicite. Un contrôle renforcé a ensuite détecté que le
payload desktop reçoit des métadonnées PE Tauri différentes du fichier de build ;
le manifeste distingue désormais ce fichier de build du payload installé. Le
hash de l'installateur couvre le conteneur et celui du bridge installé est
comparé à la publication. Aucun processus, fichier, raccourci Menu Démarrer ou
enregistrement de désinstallation Thrustline n'est resté après les cycles.
T0014 est `Done` depuis la réconciliation du 30 juillet 2026.

Signature, SmartScreen, MSI, updater, provenance, upgrade N-1 et rollback de
version restent non validés et relèvent de la phase 6.

## Prochain ticket recommandé

Faire revoir T0023, propager T0020–T0023 jusqu'à `main`, puis exécuter les
checklists humaines T0018–T0020 sur le runtime T0021. Décider la politique
économique de production avant tout déploiement ou appel desktop et ne pas
détailler une deuxième variation économique avant ces clôtures. T0011 reste
`Verify` jusqu'aux essais réels Windows 11/MSFS 2024 exigés par ADR-0003.

## Mise à jour de ce fichier

Après chaque ticket terminé, modifier uniquement :

- capacités réellement disponibles ;
- structure ou dépendances actives ;
- validation réellement exécutée ;
- dette ajoutée/résolue ;
- prochain ticket recommandé.

Ne pas y copier l'historique Git ni les projets futurs.
