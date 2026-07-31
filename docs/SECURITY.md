# Sécurité du desktop

## Politique de données T0017–T0019

La collecte est refusée par défaut et les données utilisateur réelles restent
bloquées tant que purge, sauvegarde managée et contrôles de restauration de
production ne sont pas implémentés et testés. T0018 prouve export et suppression
sur des données synthétiques locales/CI ; T0019 prouve restauration et replay
uniquement sur PostgreSQL 17 CI synthétique. Staging accepte des données
synthétiques ou irréversiblement anonymisées, jamais un clone de production.

`eng/data-policy.json` borne la télémétrie brute à 7 jours, les diagnostics
facultatifs et sauvegardes à 30 jours, et les journaux sécurité à 90 jours. Les
diagnostics exigent un consentement explicite. Une restauration doit rester
isolée, vérifier l'intégrité et rejouer les suppressions avant réouverture.

Le gate `data-policy:check` contrôle ces invariants et cinq mutations négatives
sans service, réseau ou secret. T0018 exige une session Supabase créée depuis
5 minutes au plus, vérifie `session_id` contre `auth.sessions` et refuse un
simple `token_refresh`. L'export de A exclut B ; l'anonyme ne peut appeler aucune
commande ; la finalisation est réservée à `service_role`. Une panne injectée
avant la suppression Auth restaure toute la transaction. Le marqueur final ne
contient aucun identifiant Auth, email, nom de compagnie ou export.

T0019 ajoute un jeton de restauration opaque, privé et généré côté serveur. Le
journal de suppression ne contient aucun identifiant direct, mais reste une
donnée personnelle pseudonymisée tant qu'une sauvegarde permet la
correspondance. Seul `service_role` peut le rejouer ; le même événement est
idempotent, un événement altéré ou inconnu échoue fermé et toute panne restaure
la transaction.

La cible CI est une base distincte non servie par PostgREST. Son dump exclut
Vault et Storage, réinstalle `pgcrypto` à version identique et ne rejoue pas les
`DEFAULT ACL` des rôles internes. Cette frontière ne prouve ni sauvegarde
managée/chiffrée, ni purge du journal, ni RPO/RTO ou promotion de production.

## Grand livre financier T0020

Les correspondances entre compagnies et sujets financiers opaques restent dans
`private`, avec RLS activée et forcée et sans privilège de table pour les rôles
API. Les écritures ne contiennent aucune identité Auth ou compagnie directe et
des triggers refusent `update`, `delete` et `truncate`.

Seul `service_role` peut appeler la commande d'ouverture. Elle valide les
bornes, la devise ISO 4217, l'état actif T0018, verrouille la compagnie et rend
un rejeu uniquement si le payload correspond exactement. Le propriétaire
authentifié peut seulement lire son propre grand livre ; `anon` ne peut pas
appeler cette lecture. Lors d'une suppression ou d'un replay, le lien privé est
détaché et daté dans la transaction tandis que l'écriture non directement
personnelle reste intacte.

## Onboarding autoritaire T0022

`authenticated` ne possède plus que `select` sur `public.companies`; les
privilèges et politiques d'insertion, mise à jour et suppression sont retirés.
`anon` conserve zéro privilège. La création et l'ouverture passent par une
fonction `security definer` à `search_path` vide, exécutable uniquement par
`service_role`.

La commande verrouille une identité Auth existante et non anonyme, refuse un
cycle de suppression actif, valide nom, montant et devise, puis crée compagnie,
sujets privés et écriture dans une transaction. Le registre privé compare une
empreinte SHA-256 du payload complet avant tout rejeu et disparaît avec
l'identité ou la compagnie. Deux sessions concurrentes convergent vers une seule
compagnie et une seule ouverture ; une panne injectée ne laisse aucun état
partiel.

## Frontière installateur Windows T0014

Le package T0014 est une preuve interne non signée, jamais une release. Il
utilise uniquement NSIS `currentUser`, sans élévation, service, tâche planifiée,
association de fichiers, protocole URL, auto-start, updater ou permission CI
d'écriture. L'avertissement SmartScreen éventuel n'est ni masqué ni contourné.

Le script de build borne les suppressions aux sorties attendues, publie le
bridge self-contained, inclut tout son dossier comme ressource, exige
`NotSigned` pour les trois binaires et produit un manifeste relatif contenant
tailles et SHA-256, sans chemin personnel ni secret.

Le hash du fichier desktop de build ne prétend pas être celui du payload
installé : Tauri applique des métadonnées PE propres au type de bundle. Le hash
de l'installateur couvre le conteneur distribué ; le test confirme séparément que
le desktop installé reste non signé, démarre une seule fenêtre et lance un seul
bridge. Le bridge installé est comparé au SHA-256 de la publication.

Le test d'installation exige une cible explicite sous `artifacts/t0014`,
contrôle le nom et le chemin avant toute suppression, ferme les processus
identifiés puis utilise uniquement le désinstalleur de cette cible.

## Frontière Supabase T0012

Le client distribué, les rôles `anon`/`authenticated` et tout JWT présenté sont
non fiables. La table `companies` impose côté PostgreSQL :

- une clé étrangère vers `auth.users` et un propriétaire non nul ;
- une contrainte unique empêchant deux compagnies pour un propriétaire ;
- la RLS activée et forcée ;
- aucun privilège pour `anon` ;
- uniquement `select` pour `authenticated`, filtré par la politique fondée sur
  `(select auth.uid()) = owner_id` ; les mutations passent par des commandes
  serveur explicites.

Le seed utilise uniquement deux UUID, adresses `.invalid` et compagnies
synthétiques, sans mot de passe utilisable. Les scripts racine ciblent
explicitement la pile locale et n'exposent ni `link`, ni `db push`, ni reset
`--linked`. T0021 place Supabase dans un daemon Docker-in-Docker privilégié mais
sans socket Docker hôte, montage du dépôt ou port d'administration publié. La
CLI reçoit seulement une copie filtrée de `supabase/`; son paquet Linux est
vérifié contre l'intégrité SHA-512 du lockfile et les images de base sont
épinglées par digest. Les publications wildcard restent dans cette frontière et
les trois ports utiles sont republiés vers Windows avec un `HostIp` explicite
`127.0.0.1`. Le démarrage désactive la télémétrie CLI, masque les credentials,
vérifie les liaisons externes et nettoie la pile sur tout écart. Le harnais statique exécute sept mutations,
notamment politique manquante, reset distant, publication wildcard et montage
du socket Docker hôte.

La pile locale utilise des credentials de développement, n'a pas de TLS ni les
contrôles complets de la plateforme managée. Elle doit rester sur la machine de
développement et ne prouve pas la parité cloud.

## Frontière SimConnect T0011

Le SDK reste une entrée native non fiable. `NativeSimConnectAdapter` :

- charge uniquement le nom constant `SimConnect.dll` via les répertoires Windows
  sûrs et ne permet aucun chemin fourni par l'utilisateur ;
- utilise seulement des variables de simulation en lecture ;
- confine tous les appels et callbacks dans une boucle dédiée ;
- ferme la connexion dans un `finally` et borne le buffer asynchrone ;
- ne journalise ni chemin de DLL, ni valeur de télémétrie.

Les traces JSONL exigent UTF-8, format et schéma exacts, propriétés connues,
offsets strictement croissants, valeurs finies/bornées et lignes de 16 Kio au
maximum. Les erreurs indiquent seulement le numéro de ligne.

## Frontière locale T0010

Le bridge exige un port dynamique loopback et un jeton hexadécimal de 256 bits.
Le header `X-Thrustline-Instance` est exigé sur REST et SignalR et comparé en
temps constant. Le jeton passe de Tauri au bridge par un pipe stdin anonyme ; il
n'apparaît ni dans les arguments, ni dans l'environnement, ni dans les logs, et
n'est pas transmis à React.

Le desktop part d'une autorité nulle côté page :

- capability limitée à la fenêtre `main`, avec zéro permission ;
- aucun plugin Tauri et aucune commande `#[tauri::command]` ;
- aucune ressource distante ou requête réseau ;
- décorations Windows natives et devtools désactivés en production ;
- aucun accès aux fichiers, processus, presse-papiers, notifications ou URL.

La CSP de production est :

```text
default-src 'self'; script-src 'self'; style-src 'self'; img-src 'self' data:;
connect-src 'none'; object-src 'none'; frame-src 'none';
frame-ancestors 'none'; base-uri 'self'; form-action 'self'
```

T0008 conserve ces frontières. Le build frontend :

- n'expose aucune variable d'environnement (`envPrefix: []`) ;
- ne produit pas de source map de production ;
- ne configure ni proxy ni origine réseau ;
- charge uniquement le HTML, le CSS et le JavaScript compilés localement ;
- n'utilise ni `dangerouslySetInnerHTML`, ni télémétrie, ni appel réseau ;
- limite la CSP de développement à `127.0.0.1:1420` et son WebSocket HMR.

La CSP de production n'autorise ni Internet, ni `unsafe-inline`, ni
`unsafe-eval`. L'écran d'erreur masque l'erreur, la stack et les chemins locaux.
Les tests bloquent tout assouplissement des capabilities, commandes IPC,
ressources distantes et garanties CSP.

## Bridge .NET T0009

Le bridge minimal n'ouvre aucune frontière :

- aucune écoute réseau, socket, requête ou IPC ;
- aucune lecture de secret, variable métier ou fichier utilisateur ;
- aucune dépendance NuGet tierce et sources de packages désactivées ;
- diagnostic `--health-check` constant, sans détail d'environnement ;
- arguments inconnus rejetés sans les recopier ;
- aucun lien avec Tauri ou SimConnect.

## Frontière CI T0013

Le code d'une Pull Request est non fiable. Les workflows T0013 utilisent
uniquement `pull_request` et `push` vers `main`, avec `contents: read` et sans
permission d'écriture. `pull_request_target` et les secrets applicatifs sont
interdits. Checkout désactive la persistance des credentials et toutes les
actions sont référencées par un SHA Git complet accompagné du tag contrôlé.

Les runners sont explicites (`windows-2025` et `ubuntu-24.04`). Aucun cache de
dépendances n'est activé. Les audits n'altèrent pas les manifests : pnpm bloque
les vulnérabilités hautes, NuGet inspecte les transitifs et `cargo-audit` 0.22.2
lit le `Cargo.lock`. Gitleaks parcourt l'historique avec les commentaires et
uploads propres à l'action désactivés ; il reçoit seulement le jeton GitHub
éphémère en lecture.

Le dépôt garde les sources NuGet désactivées par défaut. Le job Windows autorise
uniquement `https://api.nuget.org/v3/index.json` pendant un `dotnet restore`
explicite en mode verrouillé pour obtenir les runtime packs Microsoft
`win-x64` absents du SDK nu du runner. Aucun `PackageReference` tiers n'est
introduit et les commandes suivantes reviennent à la configuration du dépôt.

Le backend CI ne lie aucun projet Supabase. Il crée une pile locale jetable sur
un réseau Docker demandé en loopback, masque la sortie de démarrage, inspecte
les ports effectifs et arrête la pile sur toute publication wildcard. Les
artefacts sont non signés, ne sont jamais publiés comme release et expirent sous
30 jours. Le job Windows ajoute l'installateur NSIS T0014 et son manifeste à ces
preuves, sans exécuter l'installateur sur le runner. Signature, provenance et
updater restent hors de cette frontière.

Le lancement authentifié et le contrat local de T0010 considèrent le processus
desktop et le bridge comme mutuellement non fiables.
