# Stack cible de la refonte

Statut : proposition acceptée par ADR-0004 le 26 juillet 2026.
Date de consultation des sources : 26 juillet 2026.

## Décision en bref

Le nouveau dépôt conserve les frontières Tauri + React + bridge .NET + Supabase,
mais ne reprend aucun manifeste de l'ancien dépôt. Les versions initiales sont
figées exactement, avec lockfiles, puis les correctifs sont examinés chaque mois.

- Node.js 24 LTS, pnpm 11 et TypeScript 6 ;
- React 19, Vite 8, Vitest 4 et Tailwind CSS 4 ;
- Tauri 2.11 sur WebView2 Evergreen, Rust stable épinglé ;
- bridge ASP.NET Core/SignalR en .NET 10 LTS, self-contained `win-x64` ;
- SDK SimConnect officiel MSFS 2024 derrière `ISimConnectAdapter` ;
- Supabase managé, PostgreSQL 17, RLS, Auth, Realtime ciblé et Edge Functions
  seulement pour les commandes qui ne tiennent pas dans une RPC SQL.

Firebase, Electron, une alternative à React et `SimConnect.NET` ne sont pas
retenus comme fondations. Ce sont des conclusions d'architecture, pas des
mesures de performance : les budgets et benchmarks restent à exécuter.

## Réponses d'Andy

| Question | Réponse retenue |
| --- | --- |
| LTS systématique | Non ; choisir selon stabilité et compatibilité. |
| Support sans changement majeur | 12 mois minimum. |
| Majeure pendant le MVP | Oui, après fenêtre de test. |
| Gestionnaire JS | pnpm autorisé. |
| Frontend | Alternative autorisée si plus stable et performante. |
| Backend | Supabase ou Firebase à déterminer. |
| Desktop | Choix le plus stable et économe ; Electron exclu. |
| Runtime .NET | Choix guidé par sécurité et performance. |
| SimConnect | SDK officiel autorisé, selon maintenance réelle. |
| Maintenance après lancement | Revue mensuelle. |

## Matrice des versions

« Ancien » sépare la plage déclarée de la version verrouillée observée. Une date
de fin absente signifie que le projet ne publie pas de LTS contractuelle.

| Composant | Ancien dépôt | Dernière stable au 26/07/2026 | Recommandée | Support jusqu'à | Compatibilités | Décision |
| --- | --- | --- | --- | --- | --- | --- |
| Node.js | moteur `>=24.18.0 <25`; machine 24.14.1; CI 24.18.0 | 26.5.0 Current (08/07/2026) | **24.18.0 LTS** | avril 2028 | Vite 8 exige 20.19+ ou 22.12+; pnpm 11 exige 22.13+ | LTS ici : 26 reste Current jusqu'en octobre et n'apporte rien au runtime distribué. |
| pnpm | absent; npm 11.11.0 | 11.17.0 | **11.17.0** | sans LTS publiée | Node >=22.13; Corepack désactivé par défaut côté Node moderne | Remplace npm : lockfile strict, économie disque, contrôle des scripts et âge minimal des paquets. |
| TypeScript | `^5.6.2` → 5.9.3 | 7.0.2 | **6.0.3** | sans LTS publiée | React 19, Vite 8 et Testing Library; valider TS 7 séparément | TS 7 est une nouvelle majeure/native toolchain trop récente pour le socle; réévaluation mensuelle. |
| React / React DOM | `^18.3.1` → 18.3.1 | 19.2.8 | **19.2.8** | sans LTS publiée | types React 19, Testing Library 16, routeur 7 | Reste le choix le plus mature pour l'équipe et l'écosystème Tauri; pas de Server Components. |
| Routeur | `^6.27.0` → 6.30.4 | 7.18.1 (29/06/2026) | **7.18.1** | sans LTS publiée | React 19; Node >=20; mode SPA uniquement | Nouvelle base sans dette v6; ne pas activer les fonctions serveur du routeur. |
| Vite | `^8.1.5` → 8.1.5 | 8.1.5 | **8.1.5** | correctifs réguliers sur 8.1 | Node 24; plugin React 6; Tailwind Vite 4 | Retenu après stabilisation de Rolldown; version mineure exacte, pas `^`. |
| Vitest / couverture | `^4.1.10` → 4.1.10 | 4.1.10 | **4.1.10** | sans LTS publiée | Vite 6–8; Node 20+; couverture exactement alignée | Même pipeline que Vite; épingler `vitest` et `coverage-v8` à la même version. |
| jsdom | `^29.1.1` → 29.1.1 | 29.1.1 | **29.1.1** | sans LTS publiée | Node 20.19/22.13/24+ | Seulement en développement; tests UI, jamais embarqué. |
| Testing Library React | `^16.3.2` → 16.3.2 | 16.3.2 | **16.3.2** | sans LTS publiée | React/types 18 ou 19 | Conserver avec `jest-dom` 6.9.1 et `user-event` 14.6.1. |
| Tailwind CSS / plugin Vite | `^4.3.3` → 4.3.3 | 4.3.3 | **4.3.3** | sans LTS publiée | Vite 5.2–8; WebView2 Evergreen | Conserver; aucune contrainte de navigateur ancien pour Windows 11/WebView2. |
| Tauri core | plage Cargo `2` → 2.10.1 | 2.11.5 (01/07/2026) | **2.11.5** | série 2 maintenue, sans date contractuelle | Rust MSRV fournisseur >=1.77.2; WebView2; MSVC x64 | Conserver : shell web natif sans Chromium/Node embarqué. 2.11.1+ corrige deux failles ACL/origines. |
| Tauri CLI / API | `^2.0.4`/`^2.0.3` → 2.10.1 | CLI 2.11.4; API 2.11.1 | **2.11.4 / 2.11.1** | série 2 maintenue | même ligne Tauri 2.11 | Versions exactes et vérification de compatibilité croisée au bootstrap. |
| Plugins Tauri | shell 2.3.5 | shell 2.3.5; updater 2.10.1 | **aucun par défaut**; process/updater seulement au ticket dédié | selon plugin | capabilities explicites | Ne pas reprendre `plugin-shell`; le sidecar est déclaré/configuré, pas lancé par shell générique. |
| WebView2 | Evergreen système | Evergreen Stable | **Evergreen Stable** | cycle Edge stable | inclus normalement dans Windows 11; détection installateur obligatoire | Partagé, auto-corrigé et moins lourd qu'une Fixed Version. |
| Rust | machine 1.94.1; CI `stable` | 1.97.1 (16/07/2026) | **1.97.1** dans `rust-toolchain.toml` | six semaines environ par stable | cible `x86_64-pc-windows-msvc`; Tauri MSRV inférieur | Épingler le compilateur réel; MSRV projet = 1.97.1 au départ, révisée mensuellement. |
| .NET / ASP.NET Core | SDK local 10.0.201; projet/CI net8.0 | 10.0.10 LTS (14/07/2026) | **SDK/runtime 10.0.10, TFM net10.0** | 14/11/2028 | Windows 11 x64; SignalR 10; self-contained | .NET 8 finit le 10/11/2026; .NET 10 offre toute la fenêtre MVP. |
| SignalR JS | `^8.0.7` → 8.0.17 | 10.0.0 | **10.0.0** | ligne .NET 10 jusqu'au 14/11/2028 | serveur ASP.NET Core 10; Node LTS/browser courant | Aligner la majeure avec .NET; le package JS possède sa propre version de patch. |
| HTTP/résilience | `HttpClient` natif | .NET 10 | **`HttpClientFactory` + handlers maison bornés** | .NET 10 | pas de retry non idempotent | Pas de Polly au socle; l'ajouter seulement si un cas mesuré le justifie. |
| Sérialisation/validation | `System.Text.Json` implicite | .NET 10 | **System.Text.Json 10 + validation explicite** | .NET 10 | contrats versionnés TS/C# | Pas de dépendance runtime additionnelle initiale. |
| Tests .NET | aucun projet | xUnit v3 3.2.2; xUnit v4 encore preview | **xunit.v3 3.2.2** | sans LTS publiée | net10.0 | Refuser la preview v4; `Microsoft.NET.Test.Sdk` exact est relevé avec le ticket bridge et son runner MTP/VSTest. |
| SimConnect | `SimConnect.NET` 0.1.18 | wrapper 0.2.1 beta (12/05/2026); SDK MSFS 2024 courant | **SDK/API officiel MSFS 2024 + adaptateur interne** | cycle MSFS 2024 | x64, out-of-process, non thread-safe | Le wrapper reste beta et sans support Microsoft. L'officiel est la source d'API; tests via fake/replay. |
| Supabase JS | `^2.45.4` → 2.101.1 | 2.110.8 (23/07/2026) | **2.110.8** | sans LTS publiée | Node >=22; PostgreSQL/RLS/Auth/Realtime | Conserver; pin exact après audit et tests de contrat. |
| Supabase CLI | absent | 2.109.1 (24/07/2026) | **2.109.1** | sans LTS publiée | runtime Docker; stack locale non identique à 100 % au cloud | La CLI orchestre local, migrations, types et pgTAP; images par digest dans le nouveau dépôt. |
| PostgreSQL | cloud non relevé; 25 migrations | 18 amont; Supabase Platform 17 | **17 fourni par Supabase** | politique Supabase + PostgreSQL | Auth, RLS, Realtime, RPC | Ne pas viser 18 tant que la plateforme choisie ne le fournit pas officiellement. |
| Edge Functions / Deno | fonctions Supabase, version non épinglée | runtime Edge Supabase courant | **runtime fourni par CLI; Deno éditeur seulement** | politique Supabase | TypeScript/Deno; JWT vérifié | Une RPC SQL est préférée pour transaction DB; Edge Function pour orchestration réseau/secret serveur. |
| Tests SQL/RLS | aucun automatisé | pgTAP via CLI | **pgTAP + tests clients A/B/anonyme** | avec PostgreSQL 17 | `supabase test db` et intégration JS | Double preuve : structure/policies SQL et comportement API réel. |
| PowerShell | Windows PowerShell + `pwsh` CI | 7.6.0 LTS | **7.6.0 LTS** | 14/11/2028 | Windows 11, .NET 10 et runners GitHub | Aligne la fenêtre .NET; scripts en `pwsh`, `Set-StrictMode`, erreurs bloquantes; pas de dépendance à 5.1. |
| GitHub Actions | tags flottants `@v4`, `@v2`, `stable`, runners `latest` | versions maintenues courantes | **versions courantes épinglées par SHA** | revue mensuelle | `windows-2025` explicite, Node/.NET/Rust pins | Les tags servent seulement à documenter; exécution sur SHA immuable avec commentaire de version. |

## Compatibilités par groupe

### Groupe A — frontend

**Compatible sous conditions.** Node 24.18.0 satisfait pnpm 11, Vite 8, Vitest 4
et jsdom 29. React 19.2.8 est compatible avec Testing Library 16. TypeScript 6
est préféré à 7 pendant le bootstrap. `pnpm-lock.yaml` est obligatoire et
`pnpm install --frozen-lockfile` est la seule restauration CI.

Risques : Vite 8 remplace Rollup/esbuild par Rolldown; React 19 change quelques
API et comportements; React Router 7 est une majeure. Chacun exige un ticket
minimal et ses tests avant ajout de la couche suivante.

### Groupe B — desktop

**Compatible pour Windows 11 x64, à prouver par packaging.** Tauri utilise WRY et
WebView2 au lieu d'embarquer Chromium. Le toolchain est
`x86_64-pc-windows-msvc`, Rust 1.97.1, Visual Studio Build Tools maintenu et
WebView2 Evergreen. Le sidecar porte le suffixe de target Tauri attendu.

Capabilities minimales : aucune permission shell générale, domaines externes
allowlistés, CSP restrictive, updater séparé et signatures obligatoires. Tester
le crash/restart WebView2 et la présence du runtime à l'installation.

### Groupe C — bridge

**Compatible avec réserve SimConnect.** ASP.NET Core et SignalR suivent .NET 10
LTS. Le bridge est publié self-contained, single-file, `win-x64`. Le trimming et
Native AOT sont désactivés initialement : réflexion, sérialisation, ASP.NET et
interop SimConnect doivent être prouvés avant optimisation.

L'API officielle SimConnect est non thread-safe et doit rester confinée à une
boucle dédiée. `ISimConnectAdapter` expose des événements de domaine, jamais des
types SDK. Une implémentation fake et un lecteur de traces versionnées sont
obligatoires avant le premier scénario MSFS réel.

### Groupe D — backend

**Compatible et préféré à Firebase.** Supabase fournit un PostgreSQL complet,
des transactions SQL, RLS, Auth et un workflow migrations/seed/pgTAP. Cela
correspond directement au grand livre append-only et aux commandes
transactionnelles. Firestore a des transactions atomiques mais un modèle
documentaire et des limites d'évaluation des règles; Firebase SQL Connect
ajouterait une nouvelle couche GraphQL/IAM et une migration d'architecture sans
bénéfice démontré.

L'environnement local Supabase n'est pas entièrement équivalent au cloud :
chaque promotion exige migrations et tests de contrat sur staging. Realtime est
activé table par table; Storage reste hors socle jusqu'à besoin produit.

### Groupe E — CI/release

**Compatible sous contrôle de supply chain.** Runner Windows explicite, actions
épinglées par SHA, caches issus uniquement des lockfiles, permissions minimales,
aucun secret sur PR externe. Le build produit des artefacts non signés; un job
protégé séparé signe; un troisième publie l'updater et la provenance.

Les scans minimaux sont `pnpm audit`, audit NuGet transitif, `cargo audit`,
licences, secret scan et SBOM. Les artefacts de build sont conservés 30 jours,
les releases et leur SBOM/provenance pendant toute la durée de support du
produit.

## Revue sécurité et licences

| Dépendance runtime | Licence / source | Maintenance et risque | Contrôle / alternative |
| --- | --- | --- | --- |
| React / React DOM | MIT, React Foundation/Meta | mature; failles RSC 2025 corrigées dans 19.2.1+, RSC inutilisé | 19.2.8 exacte; alternative Preact seulement après benchmark et test d'écosystème |
| Tauri | MIT ou Apache-2.0, Tauri Programme | actif; correctifs ACL/origines en 2.11.1 | >=2.11.5, capabilities minimales; alternative native .NET si benchmark Tauri échoue |
| Plugins Tauri | MIT/Apache-2.0, dépôt officiel | chaque plugin élargit l'autorité | aucun par défaut; revue permission et transitifs par plugin |
| SignalR JS | MIT, Microsoft | suit ASP.NET Core | aligner la majeure 10 avec le serveur; fallback REST/SSE local si hub inutile |
| Supabase JS | MIT, Supabase | actif, transitifs Auth/Realtime/PostgREST | pin exact, audit; client REST maison déconseillé |
| SimConnect officiel | SDK Microsoft sous termes MSFS | API officielle, binaire natif et SDK hors registre | checksum/provenance SDK, adaptateur; wrapper communautaire seulement en expérimentation |
| System.Text.Json / ASP.NET Core | MIT, Microsoft/.NET | support LTS Microsoft | patch mensuel .NET; aucune alternative externe initiale |

Aucune vulnérabilité critique/haute connue ne doit rester dans le graphe au
moment de créer le socle. L'absence de résultat dans un registre n'est pas une
preuve d'innocuité : les audits sont répétés sur le lockfile réel.

## Politique de versions

- Manifests : versions exactes pour outils et dépendances directes; aucune plage
  `^`, `~`, tag `latest` ou canal flottant.
- Lockfiles : `pnpm-lock.yaml` et `Cargo.lock` versionnés; NuGet utilise gestion
  centrale avec lockfile en mode locked.
- Toolchains : `.node-version`, champ `packageManager`, `global.json` .NET et
  `rust-toolchain.toml` exacts. Le MSRV du projet est la version Rust épinglée au
  bootstrap; il ne descend que par décision explicite.
- Cadence : revue mensuelle; correctifs critiques/hauts immédiatement. Patchs
  testés puis intégrés; mineures après CI complète; majeures avec ADR légère,
  fenêtre de test de deux semaines et rollback lockfiles.
- Dependabot est autorisé pour GitHub Actions, NuGet et Cargo. Renovate est
  préféré si pnpm nécessite un regroupement plus fin; un seul bot est activé.
- Une dépendance abandonnée, sans licence claire, à mainteneur unique critique
  ou avec scripts d'installation injustifiés est refusée. Une exception indique
  propriétaire, menace, alternative et date d'expiration maximale de 90 jours.
- `pnpm` refuse par défaut les scripts de build non allowlistés et impose un âge
  minimal de publication de 7 jours, avec exception revue pour correctif urgent.
- Les builds candidats sont conservés 30 jours; releases, checksums, SBOM,
  provenance et symboles nécessaires au diagnostic sont conservés pendant la
  durée de support.

## Ordre d'adoption

1. **T0006 — runtimes et source de versions** : pins Node/pnpm/Rust/.NET/pwsh,
   bootstrap et CI de version.
2. **T0007 — shell Tauri minimal** : fenêtre vide, CSP/capabilities, mesure
   démarrage/mémoire et packaging `win-x64`.
3. **T0008 — frontend React minimal** : React/Vite/TS/Tailwind/Vitest, un écran
   et un test.
4. **T0009 — bridge .NET minimal** : process self-contained, health check,
   unit tests et arrêt propre.
5. **T0010 — contrat local** : lancement du sidecar, authentification
   d'instance, REST/SignalR et récupération.
6. **T0011 — adaptateur SimConnect/replay** : interface, fake, traces et SDK
   officiel sans logique métier liée aux types natifs.
7. **T0012 — Supabase local** : PostgreSQL 17, migration initiale, seed, types,
   pgTAP et tests A/B/anonyme.
8. **T0013 — CI multi-stack** : runners explicites, SHA d'actions, audits,
   licences, SBOM et artefacts.
9. **T0014 — packaging Windows non signé** : installation/upgrade/désinstallation
   sur VM propre.
10. **Phase 6 — signature et updater** : jobs séparés, clés protégées,
    provenance, rollback N-1.

Les identifiants T0006–T0014 remplacent les sujets de backlog actuellement
numérotés; leur contenu détaillé doit être créé par lots de 3 à 8 tickets selon
`WORKFLOW.md`.

## Sources officielles

Toutes consultées le 26 juillet 2026.

- [Node.js Releases](https://nodejs.org/en/about/previous-releases) — cycles
  Current/LTS/EOL et dates des lignes 24/26.
- [Node.js 26.5.0](https://nodejs.org/en/blog/release/v26.5.0) — version Current
  du 8 juillet 2026.
- [Registre npm : pnpm](https://registry.npmjs.org/pnpm/latest),
  [TypeScript](https://registry.npmjs.org/typescript/latest) et
  [React](https://registry.npmjs.org/react/latest) — métadonnées, moteurs,
  licences et versions publiées.
- [Vite Releases](https://vite.dev/releases) et
  [Vite 8](https://vite.dev/blog/announcing-vite8) — support et contraintes
  Node/Rolldown.
- [Vitest migration v4](https://vitest.dev/guide/migration.html) — Node/Vite.
- [React versions](https://react.dev/versions) et
  [advisory RSC](https://github.com/facebook/react/security/advisories/GHSA-fv66-9v8q-g76r).
- [Tauri releases](https://tauri.app/release/),
  [changelog core](https://tauri.app/release/tauri/all-versions/) et
  [dépôt officiel](https://github.com/tauri-apps/tauri) — versions, correctifs
  sécurité, licences et WebView2/WRY.
- [Rust releases](https://blog.rust-lang.org/releases/) — stable 1.97.1.
- [.NET support policy](https://dotnet.microsoft.com/en-us/platform/support/policy)
  et [single-file deployment](https://learn.microsoft.com/en-us/dotnet/core/deploying/single-file/overview).
- [PowerShell support lifecycle](https://learn.microsoft.com/en-gb/powershell/scripting/install/powershell-support-lifecycle)
  — version 7.6 LTS et fin de support.
- [SignalR supported platforms](https://learn.microsoft.com/en-us/aspnet/core/signalr/supported-platforms?view=aspnetcore-10.0).
- [WebView2 production guidance](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/developer-guide)
  et [distribution](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/distribution).
- [MSFS 2024 SimConnect SDK](https://docs.flightsimulator.com/msfs2024/html/6_Programming_APIs/SimConnect/SimConnect_SDK.htm),
  [managed code](https://docs.flightsimulator.com/msfs2024/flighting/programming-apis/simconnect/programming-simconnect-clients-using-managed-code/)
  et [SimConnect.NET 0.2.1](https://www.nuget.org/packages/SimConnect.NET).
- [Supabase database](https://supabase.com/docs/guides/database/overview),
  [local workflow](https://supabase.com/docs/guides/local-development/cli-workflows),
  [Edge Functions](https://supabase.com/docs/guides/functions) et
  [database testing](https://supabase.com/docs/guides/database/testing).
- [Supabase PostgreSQL 17](https://supabase.com/changelog/35851-forthcoming-postgres-17-release-notes),
  [supabase-js sur npm](https://www.npmjs.com/package/@supabase/supabase-js) et
  [CLI sur npm](https://www.npmjs.com/package/supabase).
- [xUnit v3 sur NuGet](https://www.nuget.org/packages/xunit.v3) — stable 3.2.2,
  v4 encore en préversion.
- [Firestore transactions](https://firebase.google.com/docs/firestore/manage-data/transactions),
  [Security Rules](https://firebase.google.com/docs/rules) et
  [Firebase release notes](https://firebase.google.com/support/releases).

Les numéros futurs relevés dans les registres sont des faits de publication.
Les choix de version, la préférence Supabase et l'appréciation de performance
sont des inférences d'architecture à valider par les tickets d'adoption.
