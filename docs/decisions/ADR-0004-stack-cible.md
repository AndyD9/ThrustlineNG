# ADR-0004 — Stack cible et politique de versions

Date : 26 juillet 2026
Statut : Accepted
Décideur : Andy
Ticket : T0005

## Contexte

La réécriture vise Windows 11 x64 et MSFS 2024, doit laisser le maximum de
ressources au simulateur et rendre l'économie autoritaire. Andy autorise pnpm,
une alternative frontend, Firebase, un autre shell hors Electron et une majeure
pendant le MVP. Il demande douze mois sans majeure obligatoire et une revue
mensuelle après lancement.

L'ancien dépôt mélange versions déclarées, verrouillées, locales et CI. .NET 8
arrive en fin de support en novembre 2026; le wrapper SimConnect actuel est beta;
les dépendances npm utilisent des plages qui ont déjà produit une dérive forte.

## Décision

Adopter la stack et les pins décrits dans `docs/STACK.md` :

1. Node 24 LTS + pnpm 11 + TypeScript 6;
2. React 19 + Vite 8 + Vitest 4 + Tailwind 4;
3. Tauri 2.11 + WebView2 Evergreen + Rust stable exact;
4. bridge .NET 10 LTS/ASP.NET Core/SignalR, self-contained `win-x64`;
5. SDK SimConnect officiel MSFS 2024 derrière une abstraction interne rejouable;
6. Supabase managé avec PostgreSQL 17, Auth, RLS, migrations, pgTAP et Realtime
   limité aux besoins réels.

Electron est exclu. Firebase/Firestore, Firebase SQL Connect, Preact/Svelte/Vue,
un shell .NET natif et `SimConnect.NET` ont été considérés mais ne sont pas
retenus pour le socle.

## Raisons

- Tauri réutilise WebView2 fourni et maintenu sur Windows 11; il évite de livrer
  Chromium et Node avec l'application. Le shell actuel prouve déjà la faisabilité.
- React ne détermine pas l'essentiel de l'empreinte du runtime desktop. Changer
  de framework créerait un coût d'apprentissage et un risque d'écosystème sans
  preuve de gain utilisateur. Les gains doivent d'abord venir de la fréquence
  de rendu, du découpage des vues et des mesures.
- Supabase/PostgreSQL correspond nativement aux transactions, contraintes,
  grand livre append-only et RLS. Firestore est robuste mais documentaire;
  SQL Connect ajouterait une nouvelle abstraction et ne simplifie pas les
  invariants déjà conçus en SQL.
- .NET 10 LTS couvre le MVP jusqu'en novembre 2028; .NET 8 impose une migration
  presque immédiate. Le runtime self-contained garantit le patch testé, au prix
  d'un artefact plus lourd.
- Microsoft documente directement le client SimConnect managed et recommande un
  exécutable out-of-process. Le wrapper communautaire 0.2.1 reste explicitement
  beta. L'abstraction interne protège le domaine contre les deux options.

## Politique

- Versions directes et outils épinglés exactement; lockfiles obligatoires et
  restauration CI figée.
- Revue mensuelle; correctifs critiques/hauts hors cycle.
- Majeure autorisée pendant le MVP avec ADR, deux semaines de validation et
  rollback reproductible.
- Actions GitHub par SHA, permissions minimales, build/signature/publication
  séparés, audits multi-écosystèmes, SBOM et provenance.
- Dépendance critique abandonnée ou sans licence claire refusée, sauf exception
  écrite expirant sous 90 jours.
- Rust stable est épinglé dans `rust-toolchain.toml`; le MSRV initial du projet
  est ce pin, même si le MSRV fournisseur Tauri est inférieur.
- Le trimming et Native AOT .NET sont désactivés jusqu'à preuve de compatibilité
  SimConnect/ASP.NET; ReadyToRun est benchmarké, pas présumé.

## Conséquences positives

- Une seule matrice cohérente et supportée plus de douze mois.
- Faible empreinte desktop relative à Electron.
- Autorité transactionnelle et tests RLS locaux/staging.
- Bridge installable sans prérequis .NET machine.
- Remplacement possible de SimConnect sans contaminer le domaine.

## Conséquences négatives et risques

- WebView2 Evergreen peut changer hors release Thrustline; il faut tester les
  canaux preview et gérer les pannes de processus.
- Le self-contained .NET augmente la taille de distribution.
- Supabase local n'est pas une copie exacte du cloud et demande Docker.
- Tauri, React, Vite, pnpm et Supabase ne publient pas tous une garantie LTS :
  la cadence mensuelle et les lockfiles compensent, sans l'annuler.
- Les affirmations d'empreinte restent à confirmer sur le profil matériel;
  aucune mesure Tauri contre shell natif n'a été exécutée dans T0005.

## Options rejetées

### Electron

Rejeté par Andy et incompatible avec l'objectif d'éviter un runtime
Chromium/Node embarqué.

### Shell natif .NET, WinUI/WPF/Avalonia

Option de repli si les mesures Tauri échouent. Elle supprimerait Rust mais
imposerait une reconstruction UI complète et, selon le framework, un runtime ou
des dépendances supplémentaires. Aucun gain mesuré ne justifie cette divergence.

### Preact, Svelte ou Vue

Potentiellement plus petits en bundle, mais le bundle n'est pas le budget
dominant face à MSFS/WebView2/bridge. Le risque de migration et d'écosystème est
supérieur au gain non mesuré. Réouverture seulement par benchmark représentatif.

### Firebase

Firestore ne correspond pas au modèle relationnel et aux invariants SQL. SQL
Connect est plus récent et introduit GraphQL/Cloud SQL/IAM. Le coût de bascule
et de nouvelle ADR est injustifié sans défaut bloquant Supabase.

### SimConnect.NET

API agréable et active, licence MIT, mais beta, faible adoption et non supportée
par Microsoft. Peut servir de spike derrière l'adaptateur, jamais devenir la
frontière du domaine sans nouvelle décision.

## Validation requise

Cette ADR accepte une direction; elle ne prouve pas encore les performances.
Chaque ticket d'adoption doit mesurer build, démarrage, mémoire au repos et en
vol long, taille, reprise et compatibilité. Les canaux MSFS Store/Steam restent
non supportés jusqu'aux fiches réelles ADR-0003.

## Remplacement

Toute divergence majeure remplace cette ADR avec matrice actualisée, migration
et rollback vers les derniers manifests/lockfiles validés.
