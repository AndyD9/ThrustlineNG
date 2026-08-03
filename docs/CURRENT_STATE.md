# État actuel du dépôt

Dernière revue documentaire : 3 août 2026 (T0042 livré ; T0043–T0048 validés
sur des branches empilées).
Statut : T0012–T0031, T0033–T0042 sont `Done`. T0042 est livré dans `main` par
la PR corrective #73 au commit `a4047a5`, avec ses trois checks verts.
T0043 est `Review` sur une branche empilée sur T0042 ; sa lecture de catalogue
n'est pas présente dans `main`. La PR #72 a fusionné dans T0042 après la
propagation de cette branche vers `main`.
T0044 est `Review` sur une branche empilée sur T0043 : la reprise de compagnie
et l'aiguillage onboarding/catalogue ne sont pas présents dans `main`. La PR
#74 a fusionné dans la branche T0043.
T0045 est `Review` sur une branche empilée sur T0044 : la composition
catalogue/achat est validée localement mais absente de `main`. La PR #76 a
fusionné dans la branche T0044 pendant les checks, sans propager la pile vers
`main`. La PR corrective documentaire #77 propage cette réconciliation vers
T0044.
T0046 est `Review` sur une branche empilée sur T0045 : la flotte propriétaire
peut être chargée et relue après achat, mais T0043–T0046 restent absents de
`main`. La PR prête #80 cible T0045 et ses trois checks sont en cours lors de
l'observation initiale.
T0047 est `Review` sur une branche empilée sur T0046 : un brouillon de dispatch
minimal peut être créé côté serveur pour un avion possédé, avec isolation,
idempotence et exclusivité prouvées localement. T0043–T0047 restent absents de
`main` et aucune frontière Edge ou consommation desktop du dispatch n'est
livrée. La PR prête #81 cible T0046 et ses trois checks sont en cours lors de
l'observation initiale.
T0048 est `Review` sur une branche empilée sur T0047 : l'Edge Function
`dispatch-draft` vérifie une session non anonyme, dérive le propriétaire et
appelle la commande T0047 avec le credential serveur. T0043–T0048 restent
absents de `main`; aucun appel desktop, runtime Edge live ou SimBrief n'est
livré.
Les vérifications historiques T0007–T0009 et T0011 restent `Verify`. Le cadrage
T0032 est `Draft` en attente de décisions produit. La phase 2 reste sous
interdiction de données utilisateur réelles.

La fusion #41 (`06cece5`) est couverte par le run CI `30706049048`, réussi sur
PostgreSQL 17 et Windows multi-stack, et par le run supply-chain `30706049088`,
réussi sur les audits, licences et SBOM.

La fusion T0024 #46 (`ffdc136`) est couverte par le run CI `30715814782`, réussi
sur Windows multi-stack et PostgreSQL 17, et le run supply-chain `30715814774`,
réussi sur les audits, licences et SBOM.

La phase 0 est terminée, la phase 1 a franchi conditionnellement son gate de
reproductibilité et la phase 2 reste active sous interdiction de données
utilisateur réelles. T0021 résout `KI-017` : la pile locale est isolée et ses
trois sockets Windows écoutent uniquement sur `127.0.0.1`. Cette preuve locale
ne démontre ni parité Supabase managée, ni staging, ni production.

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

La source canonique `eng/versions.json` épingle :

- Node.js `24.18.0` et pnpm `11.17.0` ;
- Rust `1.97.1`, Tauri `2.11.5` et Tauri CLI `2.11.4` ;
- SDK .NET `10.0.201`, runtime/TFM .NET 10 ;
- PowerShell `7.6.0` minimum ;
- React `19.2.8`, TypeScript `6.0.3` et Vite `8.1.5` ;
- Supabase CLI `2.109.1` et PostgreSQL 17.

Docker Desktop 29.6.2 sert aux preuves locales. Le desktop utilise
Tauri/WebView2, le bridge ASP.NET Core .NET 10 est publié self-contained
`win-x64`, et REST/SignalR restent liés au loopback avec jeton d'instance.

## Inventaire reproductible

- Lockfiles : `pnpm-lock.yaml`, `apps/desktop/src-tauri/Cargo.lock` et les
  `packages.lock.json` du bridge et de ses tests.
- Scripts racine : gates frontend, desktop, bridge, backend, données,
  performance, packaging Windows, CI et supply chain.
- Workflows dans `main` :
  `.github/workflows/ci.yml` et `.github/workflows/security.yml`.
- Migrations Supabase append-only constatées : 7 sur la branche T0047 ; `main`
  en contient 6.
- Variables/configurations relevées par nom seulement : `SUPABASE_URL`,
  `SUPABASE_ANON_KEY` et `SUPABASE_SERVICE_ROLE_KEY`.
- Politique économique T0028 présente dans `main` : source v1
  `eng/economy-policy.json`, ouverture `43000000` unités mineures en `EUR` ;
- Achat T0029 présent dans `main` : offre synthétique, propriété de compagnie et
  débit autoritaire atomique. T0035 ajoute dans `main` une Edge Function
  authentifiée et T0036 prouve son runtime local réel. T0037 ajoute dans `main`
  une commande et un panneau desktop injectés. T0038 ajoute dans `main` la
  configuration locale publique et le refresh de session en mémoire. T0039
  ajoute dans `main` l'acquisition email/mot de passe locale injectée, sans
  persistance, route, catalogue, connectivité live ni déploiement. T0040 active
  dans `main` le provider email local tout en gardant le signup
  global fermé et prouve la commande contre le runtime synthétique. T0041 livre
  dans `main` la route locale et la déconnexion en mémoire.
  T0042 compose sur sa branche l'onboarding T0023 avec la session en mémoire et
  une intention idempotente, sans catalogue, achat ou persistance.
  T0043 ajoute sur une branche empilée une lecture explicite et bornée des offres
  disponibles sous RLS, sans composition d'achat ni accès distant.
  T0044 ajoute au-dessus une lecture explicite de présence de compagnie et
  aiguille l'accueil vers onboarding ou catalogue, sans achat composé.
  T0045 compose ensuite catalogue et achat, T0046 relit la flotte après achat,
  puis T0047 ajoute sur sa branche un brouillon de dispatch serveur minimal.
  T0048 l'expose derrière une frontière Auth bornée, sans desktop, SimBrief ou
  cycle de vol.
- Gate de maintenance T0030 présent dans `main` : cohérence du registre, des
  statuts ticket/index et des marqueurs de dette, avec huit mutations négatives.
- Inventaire d'autorité : 10 étapes du golden path, 13 domaines et 3 surfaces
  clientes dans `eng/authority-inventory.json`.

## Procédure vérifiée depuis un clone propre

Installer les versions exactes de `eng/versions.json`, Docker Desktop pour le
backend, et les prérequis Tauri v2, puis exécuter depuis la racine :

```powershell
pwsh -NoProfile -File .\scripts\check-toolchain.ps1
pwsh -NoProfile -File .\scripts\bootstrap.ps1
pnpm frontend:typecheck
pnpm frontend:test
pnpm frontend:build
pnpm desktop:check
pnpm desktop:test
pnpm bridge:build
pnpm bridge:test
pnpm backend:check
pnpm backend:functions:test
pnpm data-policy:check
```

Les contrôles PostgreSQL réels ajoutent `backend:start`, deux `backend:reset`,
`backend:test`, `backend:types:check` puis `backend:stop`. Aucun projet Supabase
distant, donnée réelle ou certificat de signature n'est requis ou autorisé par
ce socle.

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

- Le runtime Supabase local repose sur un daemon DinD privilégié et conserve un
  volume de cache d'images ; il ne monte ni socket Docker hôte, ni dépôt complet,
  ni donnée réelle.
- Le build Tauri complet dépend de la publication préalable du sidecar dans le
  layout `externalBin` ; les gates de packaging contrôlent ce couplage.
- Les futures pages fonctionnelles doivent éviter le mélange historique
  UI/orchestration/données suivi par `KI-005`.
- T0024 inventorie toutes les mutations du golden path et ferme `KI-001` pour le
  code présent ; huit domaines restent explicitement non implémentés.
- Sauvegarde managée/chiffrée, purge du journal pseudonyme, restauration de
  production et promotion restent absentes ; `KI-021` interdit les données
  réelles jusque-là.
- Aucun pipeline complet de release signée ou d'updater avec rollback n'existe.
- Cargo ne signale aucune vulnérabilité, mais plusieurs crates GTK3 non
  maintenues et `glib` 0.18.5 unsound restent dans le lockfile multi-plateforme
  (`KI-019`).

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

La PR #7 avait fusionné T0010 dans une branche déjà intégrée, sans le livrer à
`main`. La PR #10 a ensuite propagé ses commits `22f97d4` et `41cc940` dans
`main` via `26cbcbf`. T0026 confirme leur ascendance et rejoue avec succès le
build bridge, 13 tests bridge, 8 tests frontend, 3 tests Rust et les invariants
du shell ; `KI-016` est résolu sans changement du contrat.

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
31 juillet 2026. T0012 et T0021 sont présents dans `main` depuis la PR #41 et
sont `Done`. Aucune parité cloud n'est revendiquée.

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
de 148 assertions.

La checklist Windows du 1er août 2026 confirme la demande, le rejeu après perte
de réponse, l'isolation B/anonyme, l'annulation, une nouvelle demande expirée,
le rollback injecté `1|1|1|0|0` puis la finalisation : A finit à `0|0|0|0`, B
reste à `1|1`, avec un marqueur et un événement pseudonymes. Les 10 fichiers/190
assertions et les types passent avant le parcours ; la pile est arrêtée sans
sauvegarde. T0018 est `Done` et aucune donnée réelle n'est admise.

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
localement via T0021.

La checklist Windows du 1er août 2026 prend le dump avant suppression en 246 ms,
restaure une base distincte non servie par l'API en 688 ms et rejoue l'unique
événement en 166 ms. A passe de présent dans le dump à absent après replay, B
reste intact, le rejeu identique est stable et les événements altéré/inconnu
sont refusés. La cible et les quatre fichiers temporaires sont détruits ; T0019
est `Done` sans élargir la preuve aux sauvegardes managées ou à la production.

## Grand livre financier immuable

T0020 ajoute un sujet financier opaque par compagnie, des écritures
privées append-only et une commande d'ouverture réservée à `service_role`.
`authenticated` ne peut que lire les écritures de sa propre compagnie par une
fonction qui dérive l'identité du JWT. La suppression et le replay détachent le
lien personnel sans modifier les écritures.

Les gates statiques backend et politique T0020 passent avec respectivement 5 et 6
mutations négatives. Le run `30628851680` valide deux resets, 8 fichiers pgTAP,
148 assertions, la concurrence, la restauration/replay et les types stables sur
PostgreSQL 17. T0021 reproduit localement les 8 fichiers/148 assertions et les
types stables.

La checklist Windows du 1er août 2026 confirme deux sujets opaques, ouverture et
rejeu A, refus collision/deuxième ouverture, isolation A/B/anonyme et refus
`update`/`delete`/`truncate`. La suppression bloque une nouvelle variation puis
détache le sujet sans réécrire l'entrée : A finit à `0|0|0|0`, B reste à `1|1`
et les deux écritures persistent sans colonne d'identité directe. T0020 est
`Done` ; il n'avait fixé aucune politique économique de production. T0028 prend
ultérieurement cette décision sans modifier la migration ni les écritures T0020.

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
rollback injecté avec l'état final `1|1|1|0|0`. T0022 est présent dans `main`
depuis la PR #41 et passe à `Done`. Aucun appelant desktop/bridge, donnée réelle
ou environnement distant n'est ajouté. Les runs GitHub `30652926904` et
`30652926644` valident PostgreSQL 17, Windows multi-stack et la supply chain.

## Frontière Edge d'onboarding

T0023 ajoute `company-onboarding`, une Edge Function `POST` qui accepte
uniquement le nom et la clé d'idempotence. Elle vérifie le bearer token auprès
de Supabase Auth, refuse l'anonyme, dérive le propriétaire de la session et, dans
la version livrée par T0023, lit montant/devise dans la configuration serveur
avant d'appeler la RPC T0022 avec `service_role`. Le corps est borné à 4 Kio et
les réponses sont JSON `no-store` sans détail SQL.

Les 14 tests Node, le gate backend T0012–T0023 avec 11 mutations, deux resets,
10 fichiers/190 assertions pgTAP et les types passent localement. L'intégration
Auth → Edge → RPC rend une réponse v1 active, rejoue les mêmes identifiants et
laisse exactement `1|1|1`; un appel sans JWT rend HTTP 401. L'Edge Runtime reste
derrière l'API loopback et n'ajoute aucun port externe. T0023 est présent dans
`main` depuis la PR #41 et passe à `Done`; aucune valeur économique de production
n'était décidée par ce ticket. L'arrêt local utilise désormais `--no-backup`; un
arrêt/redémarrage prouve que l'identité et la compagnie synthétiques T0023 ne
survivent pas dans le volume conservé pour les images. La revue adversariale a
corrigé la minimisation de la réponse privilégiée dans `aa4d0a2`. Les PR
#38–#40 ont propagé T0023 dans T0020, puis la PR #41 a fusionné la pile dans
`main`.

## Politique économique d'ouverture T0028

Andy confirme le 2 août 2026 une ouverture unique de 430 000 EUR pour toute
nouvelle compagnie MVP. La branche T0028 encode cette politique v1 dans
`eng/economy-policy.json` avec `openingAmountMinor = 43000000` et
`currencyCode = EUR`. La fonction consomme une copie embarquée strictement
identique ; les anciennes variables `COMPANY_OPENING_BALANCE_MINOR` et
`COMPANY_OPENING_CURRENCY` sont retirées du handler, du runtime et de la
configuration Supabase.

Quinze tests Node passent, dont six politiques invalides et une tentative de
surcharge par environnement. Le gate backend passe avec quatorze mutations et
le gate de données avec six mutations. L'inventaire d'autorité reflète la
politique tout en conservant l'absence d'une deuxième commande financière.
La PR #54 (`af2ab1b`) livre T0028 dans `main`. Aucun projet distant, appel
desktop ou donnée réelle n'est ajouté.

## Achat d'avion autoritaire T0029

T0029 ajoute dans `main` une offre synthétique unitaire, une propriété de
compagnie et une commande `service_role` atomique/idempotente. Le prix et la
devise viennent de l'offre verrouillée ; le solde est recalculé sous verrou
depuis le grand livre, puis l'avion et le débit immuable sont créés dans la même
transaction. Les clients authentifiés restent limités aux lectures RLS de leur
flotte et des offres actives.

Le 2 août 2026, le gate statique backend passe avec quinze mutations. Après
redémarrage de Docker Desktop 29.6.2, deux resets PostgreSQL 17 passent, les
12 fichiers/234 assertions concluent par `Result: PASS` et les types générés
restent stables. Deux connexions rejouant le même achat convergent vers
`1|1|1|33000000`; deux offres de 10 000 000 face à 15 000 000 produisent un
succès, un refus et `1|1|1|5000000`. La capacité est livrée dans `main`, sans
endpoint desktop, déploiement distant ni donnée réelle.
Andy a confirmé que la location suivra dans un ticket distinct avec contrat,
échéances et autorité temporelle.

Sur le commit d'implémentation `1ede937`, l'exécution CI `30740977879` valide
PostgreSQL 17 et Windows, et l'exécution supply-chain `30740977888` est verte.
La chaîne de fusions empilées qui portait T0029 est intégrée dans `main` par la
PR #54 ; T0033 réconcilie son statut sans rejouer ces preuves.

T0035 ajoute dans `main` `aircraft-purchase`, une frontière Edge qui accepte
uniquement offre et idempotence, vérifie une session non anonyme, dérive le
propriétaire puis appelle la commande T0029 avec le credential serveur. Trente
tests Node passent au total, dont quinze scénarios d'achat ; le gate backend
passe avec dix-huit mutations. La réponse est allowlistée et `no-store`, les
rejets sont redigés. La PR #62 est fusionnée au commit `76a47c9` avec ses trois
checks verts ; T0035 est `Done`.

T0036 charge cette fonction dans l'Edge Runtime local réel. Une
identité/session/JWT synthétiques traverse Auth, onboarding et achat ; le rejeu
conserve les mêmes identifiants. PostgreSQL confirme une compagnie, deux
écritures, un solde de `33000000`, un avion et une commande. Les refus sans JWT
et avec prix client rendent HTTP 401 et 400 sans détail interne. L'arrêt sans
backup puis le redémarrage confirment zéro identité T0036 persistée. Aucun appel
desktop, projet distant, parité cloud ou donnée réelle n'est prouvé.

T0037 ajoute une commande WebView qui accepte uniquement une URL publique, une
clé anonyme, un bearer utilisateur, l'offre et l'idempotence, puis appelle
`/functions/v1/aircraft-purchase`. Les cibles HTTP non loopback, UUID et réponses
non conformes sont refusés ; la requête expire après cinq secondes. Le panneau
React bloque les doubles clics, conserve la même clé pour un retry et expose des
états accessibles prêt, pending, owned, rejected et unavailable. La session et
l'offre restent injectées et non persistées : la CSP de production demeure
`connect-src 'none'`, aucun écran routé, auth, catalogue ou appel live n'est
revendiqué.

T0038 expose au bundle exactement deux paramètres publics et refuse toute cible
autre que `http://127.0.0.1:54321`. Un gestionnaire conserve la session injectée
en mémoire, rend le bearer valide ou le renouvelle 30 secondes avant expiration,
fait converger les appels concurrents vers un seul refresh et remplace les deux
tokens après validation. Les refus Auth effacent la session ; une panne
transitoire reste réessayable. La CSP de développement ajoute seulement l'API
Supabase loopback et la CSP de production demeure `connect-src 'none'`.

Le 2 août 2026, typecheck, couverture, build, 7 fichiers/58 tests frontend et
les gates autorité/données/maintenance passent. La couverture globale atteint
89,80 % des statements, 84,79 % des branches et 90,68 % des lignes. Cette preuve
utilise un `fetch` injecté : elle ne valide ni acquisition de session,
stockage Windows, appel live, CORS, staging, production ou donnée réelle.

T0039 ajoute une commande email/mot de passe limitée à Auth local et un panneau
injecté qui installe atomiquement une session T0038 validée. La requête expire
après cinq secondes, la réponse est lue jusqu'à 16 Kio, les refus sont redigés et
le mot de passe quitte le state dès la soumission. Les tests bloquent la
concurrence, vérifient l'annulation et interdisent stockage Web, cookie et logs.
Cette tranche simulée ne crée ni route, inscription, récupération de mot de
passe, OAuth, persistance Windows, appel live, cible distante ou donnée réelle.

Le 2 août 2026, typecheck, build et 9 fichiers/78 tests frontend passent. La
couverture globale atteint 92 % des statements, 86,13 % des branches, 92,45 %
des fonctions et 92,56 % des lignes. Les gates autorité, données et maintenance
passent avec 5, 6 et 8 mutations ; le bundle ne contient aucun credential de
test, marqueur `service_role` ou accès Data API.

T0040 corrige l'écart runtime qui rendait ce grant inutilisable : le provider
email local accepte désormais une identité provisionnée par l'Admin API tandis
que `auth.enable_signup = false` continue de refuser l'inscription publique.
Un gate exige ces deux valeurs sans ambiguïté, garde SMTP fermé et les couvre
par deux mutations négatives.

Le test runtime exécute la vraie commande T0039 puis installe la session dans le
gestionnaire T0038. Deux scénarios passent : succès avec bearer/refresh token,
puis refus d'un mauvais mot de passe et de `/signup`. Les bindings restent
54321–54323 sur `127.0.0.1`; après suppression, arrêt sans backup et redémarrage,
PostgreSQL contient deux identités seed `.invalid` et zéro identité T0040. La
pile est arrêtée. Cette preuve reste locale, synthétique et non routée ;
elle ne revendique ni persistance ni cible distante. T0040 est livré dans
`main` par la PR #67 au commit `471c7c1` avec ses trois checks verts.

T0041 compose un unique gestionnaire de session avec les routes `/login` et `/`.
Sans session, l'accueil redirige vers le formulaire ; après installation complète
par T0039, le login redirige vers l'accueil. La déconnexion efface la session
avant de revenir au formulaire. Les 80 tests frontend, la couverture et le build
passent ; les espions réseau confirment zéro appel au rendu, pendant les
redirections et à la déconnexion. Cette preuve jsdom ne constitue pas un login
WebView live. La PR #68 a été fusionnée avec ses checks verts dans
`fix/T0040-enable-local-password-auth` après que #67 avait déjà intégré cette
base. La PR corrective #69 livre ensuite T0041 dans `main` au commit `cb179e9`
avec Windows multi-stack, PostgreSQL 17 et supply-chain réussis.

T0042 ajoute à cet accueil protégé une commande `company-onboarding` qui envoie
uniquement nom normalisé et idempotence, obtient le bearer depuis le gestionnaire
au moment de la soumission et efface la session si Auth la refuse. Un retry du
même nom conserve la clé tandis qu'un changement crée une nouvelle intention.
Les 104 tests frontend, la couverture, le build et les gates passent localement.
Cette preuve jsdom/fetch injectée ne valide ni WebView live, CSP de production,
cible distante ou donnée réelle. La PR #70 a fusionné dans une branche déjà
intégrée ; la PR corrective #73 livre T0042 dans `main` au commit `a4047a5` avec
ses trois checks verts.

T0043 ajoute un transport `GET` constant vers les offres d'achat disponibles,
limité à vingt éléments et 32 Kio, ainsi qu'un panneau injecté sans réseau au
rendu. Le bearer est obtenu au chargement puis la réponse est strictement
allowlistée. Le gate d'autorité déclare l'unique couple chemin/ressource et passe
avec huit mutations négatives. Les 125 tests frontend, la couverture et le build
passent localement. La preuve reste jsdom/fetch injectée, locale, sans achat
composé, WebView live, cible distante ou donnée réelle.

T0044 ajoute un second transport `GET` constant vers `companies`, projeté sur
`id` et limité à deux lignes afin de détecter une violation de l'unicité
propriétaire. La réponse strictement validée est immédiatement réduite à un
booléen : aucun nom ou identifiant n'est conservé ou rendu. L'accueil ne charge
rien au rendu puis affiche explicitement l'onboarding en l'absence de compagnie
ou le catalogue si elle existe ; une création réussie bascule aussi vers le
catalogue. Les 146 tests frontend, la couverture, le build et les gates passent
localement ; le gate d'autorité couvre neuf mutations. Cette preuve reste
jsdom/fetch injectée, locale, sans achat composé, WebView live, cible distante ou
donnée réelle. T0044 est empilé sur T0043/PR #72.

T0045 limite la sélection aux offres validées du catalogue et compose l'unique
offre choisie avec la commande Edge T0037. Le bearer est obtenu depuis le
gestionnaire de session à la soumission ; aucun prix, devise, compagnie,
propriétaire ou solde n'entre dans le payload d'achat. Le changement d'offre est
bloqué pendant une commande, les retries conservent l'idempotence et un refus
Auth efface la session. Les 149 tests frontend exécutés, la couverture, le build
et les gates passent localement. La preuve reste injectée, empilée sur T0044,
sans WebView live, cible distante, donnée réelle, flotte ou livraison dans
`main`.

T0046 ajoute une lecture `GET` constante de `company_aircraft`, sans filtre de
compagnie ou propriétaire fourni par le client. La RLS T0029 reste l'autorité ;
le corps borné et chaque ligne sont validés avant rendu. L'accueil ne charge
rien implicitement et une flotte déjà ouverte est relue après achat, y compris
si le signal arrive pendant une lecture en cours. Les 173 tests frontend
exécutés, la couverture, le build et les gates passent localement. La preuve
reste injectée, empilée sur T0045, sans WebView live, cible distante, donnée
réelle, pagination ou livraison dans `main`.

T0047 ajoute `flight_dispatches`, un registre privé et la commande
`create_dispatch_draft` réservée à `service_role`. La compagnie, l'état et le
temps sont dérivés côté serveur ; l'avion doit appartenir à cette compagnie et
les deux ICAO normalisés doivent être distincts. Deux resets puis 14 fichiers/270
assertions pgTAP passent sur PostgreSQL 17, les types restent stables et une
course intersession différente sur le même avion rend `0|1` avec l'état
`1|1|0|1`. Cette tranche est empilée sur T0046 et ne livre ni endpoint Auth,
desktop, SimBrief, transition de vol, cible distante ou donnée réelle.

T0048 ajoute l'Edge Function `dispatch-draft`, limitée à `POST`, à un bearer et
à un corps de 4 Kio contenant seulement avion, deux ICAO et idempotence. Elle
normalise les ICAO, vérifie la session auprès d'Auth, dérive le propriétaire et
appelle `create_dispatch_draft` avec `service_role` sous timeout. La réponse est
validée, recoupée, projetée sur sept champs publics et marquée `no-store`. Les
46 tests de fonctions et le gate backend à 26 mutations passent ; la preuve
reste injectée, empilée sur T0047, sans Edge Runtime live, desktop, SimBrief,
cible distante ou donnée réelle.

Le 2 août 2026, 5 fichiers/38 tests frontend passent. La couverture atteint
91,52 % des statements, 88,78 % des branches et 93,10 % des lignes ; le build
Vite réussit. Les gates autorité, données et maintenance passent respectivement
avec 5, 6 et 8 mutations négatives. Le bundle ne contient ni credential de test,
ni référence privilégiée, ni accès Data API.

## Autorité des mutations du golden path

T0024 ajoute une source JSON versionnée couvrant exactement les dix étapes
produit. T0048 classe désormais le dispatch comme tranche serveur partielle avec
frontière Auth bornée, en
plus de la compagnie, du cycle de compte, de la flotte, de la finance et de la
continuité ; Supabase Auth est une autorité externe et six domaines restent
`not-implemented`.

`pnpm authority:check` scanne React, Tauri et le bridge, refuse toute mutation
Supabase/SQL directe, accès Data API non classé, credential ou commande
`service_role`, et échoue si
une extension cliente apparaît sans classification. Cinq mutations négatives
prouvent le harnais. L'inspection du 1er août ne trouve aucune mutation métier
dans les composants clients ; `KI-001` est résolu pour le code actuel, sans
revendiquer les capacités encore absentes. Le workflow CI publié
`30715814782` exécute le gate sous PowerShell 7 avant les validations
applicatives et réussit.

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

T0042 est livré. T0043 à T0048 doivent encore être propagés vers `main`
par des PR correctives ordonnées ; leurs fusions empilées ne suffisent pas à les
livrer dans la branche distante par défaut. Le prochain ticket recommandé est
la preuve locale réelle Auth → Edge Runtime → `create_dispatch_draft`, avec
identité, compagnie, avion et dispatch exclusivement synthétiques, sans encore
composer le desktop, appeler SimBrief ni démarrer un vol. La location T0032 reste bloquée sur
ses décisions produit et la persistance Windows reste un ticket de sécurité
séparé avant tout stockage de refresh token.

T0032 cadre la location d'avion mais reste `Draft` jusqu'à décision explicite
d'Andy sur durée, cadence, montants, grâce, défaut, résiliation, fin d'usage et
autorité temporelle. T0011 reste `Verify` jusqu'aux essais réels Windows 11/MSFS
2024 exigés par ADR-0003. Les autres dettes ouvertes restent priorisées par
sévérité dans `KNOWN_ISSUES.md`.

## Mise à jour de ce fichier

Après chaque ticket terminé, modifier uniquement :

- capacités réellement disponibles ;
- structure ou dépendances actives ;
- validation réellement exécutée ;
- dette ajoutée/résolue ;
- prochain ticket recommandé.

Ne pas y copier l'historique Git ni les projets futurs.
