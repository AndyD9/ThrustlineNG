# Sécurité du desktop

## Cycle des règles de sécurité

`SECURITY.md` est la source canonique des invariants de sécurité acceptés. Leur
détection, qualification, ticketisation, application et revalidation suivent
`MAINTENANCE.md`.

Une règle nouvelle ou modifiée doit préciser l'actif protégé, la frontière de
confiance, l'abus refusé, le contrôle attendu et, si elle dépend d'un outil ou
d'une version, sa condition de revalidation. Une décision qui change l'autorité
métier, les données, le support ou l'architecture exige un ticket et, lorsqu'elle
est structurante, une ADR acceptée.

L'agent ne crée pas seul d'exception. Toute exception est approuvée par Andy,
bornée à un ticket et une surface, assortie d'un risque résiduel ainsi que d'une
échéance ou condition d'expiration. Un contrôle déterministe doit être automatisé
dès que le ticket l'autorise ; un contrôle manuel conserve son responsable, son
environnement, sa fréquence et sa preuve attendue.

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

## Frontière d'onboarding T0023

L'Edge Function conserve le gate JWT de la plateforme puis vérifie explicitement
le bearer token auprès de Supabase Auth. Elle exige un UUID non anonyme et
dérive de cette réponse l'unique `owner_id` transmis à T0022. Le corps client
est limité à 4 Kio et contient exactement `companyName` et `idempotencyKey` ; un
propriétaire, montant, devise ou champ inconnu fourni par le client est refusé.

T0028 fixe le montant et la devise dans `eng/economy-policy.json` : la politique
v1 accorde `43000000` unités mineures en `EUR`. La fonction consomme une copie
embarquée dont le gate exige l'identité stricte avec cette source. Le runtime et
`supabase/config.toml` ne peuvent plus substituer ces valeurs par variables
d'environnement. `SUPABASE_SERVICE_ROLE_KEY` n'est utilisé que dans l'appel RPC
interne. Les réponses sont `no-store`, ne journalisent rien et remplacent les
erreurs Auth, SQL ou transport par des codes publics bornés.

Le client reste limité au nom et à la clé d'idempotence. Toute future politique
exige une nouvelle version et ne peut réécrire une ouverture immuable existante.
Cette règle ne déploie aucun projet distant et n'autorise toujours aucune donnée
réelle.

## Acquisition d'avion autoritaire T0029

Les offres d'achat sont des unités serveur en EUR dont le prix n'est jamais lu
dans un payload client. `purchase_aircraft` est une fonction `security definer`
à `search_path` vide exécutable uniquement par `service_role`. Elle verrouille
la compagnie et son sujet financier avant l'offre, refuse un compte en
suppression, une offre consommée, une devise incohérente ou un solde insuffisant,
puis crée avion, débit et commande d'idempotence atomiquement.

Les tables d'offres et d'avions forcent RLS et n'accordent que `select` à
`authenticated`; les mutations directes sont révoquées. Le registre de commande
reste dans `private` sans privilège API. Une même clé et un même payload rendent
les identifiants enregistrés ; toute collision échoue. La location reste hors
périmètre car ses échéances exigent une autorité temporelle distincte.

T0035 place une frontière Edge authentifiée devant cette commande. Le client ne
fournit que `offerId` et `idempotencyKey`; la fonction vérifie une session non
anonyme auprès d'Auth, dérive `owner_id`, puis utilise le credential
`service_role` uniquement côté serveur. Le corps est borné à 4 Kio, les appels
amont à 5 secondes et la réponse est une allowlist versionnée `no-store`. Les
rejets Auth, transport et SQL sont remplacés par des codes publics sans détail
de solde, d'offre, de JWT ou de credential. Aucun appelant desktop ni
déploiement distant n'est couvert.

## Brouillon de dispatch autoritaire T0047–T0048

`create_dispatch_draft` est une fonction `security definer` à `search_path`
vide exécutable uniquement par `service_role`. Elle accepte un propriétaire
dérivé par la frontière Auth T0048, une clé UUID, un avion et
deux codes ICAO. La compagnie, l'état `draft` et l'horodatage ne traversent pas
la frontière comme autorité cliente. Les ICAO sont normalisés en ASCII
alphanumérique sur quatre caractères et doivent être distincts.

La commande verrouille la compagnie puis l'avion, refuse un compte en
suppression et vérifie que l'avion appartient à la compagnie dérivée. Un
registre `private` lie l'intention normalisée au résultat ; rejeu identique,
collision et deux créations concurrentes convergent ou échouent sans second
brouillon. `flight_dispatches` force RLS, n'accorde que `select` à
`authenticated` sous politique propriétaire et interdit toute mutation client.

L'Edge Function `dispatch-draft` refuse tout champ autre que l'avion, les deux
ICAO et l'idempotence dans un corps de 4 Kio. Elle vérifie une session non
anonyme avec la clé anon, dérive le propriétaire et réserve le credential
`service_role` à l'appel RPC sous timeout. Toute réponse privilégiée est validée,
recoupée avec la requête, projetée sur sept champs publics et marquée `no-store` ;
les rejets Auth, transport et SQL sont redigés. La preuve Edge reste injectée et
synthétique : aucun runtime live, desktop, SimBrief, cycle de vol, cible distante
ou donnée réelle n'est couvert.

## Démarrage de vol autoritaire T0050

`start_flight_from_dispatch` est une fonction `security definer` à `search_path`
vide exécutable uniquement par `service_role`. Elle accepte exactement un
propriétaire vérifié en amont, une clé UUID et un dispatch. Compagnie, avion,
état et horodatage de départ ne traversent jamais la frontière comme autorité
cliente : ils sont dérivés du serveur. L'état de vol reste une liste fermée de
deux valeurs et `started_at` vient d'un trigger `clock_timestamp()` qu'aucun
appelant ne peut fournir, remplacer ni antidater, y compris par une écriture
directe sur la table.

La commande verrouille la compagnie du propriétaire puis le dispatch, refuse un
compte en suppression via `private.account_is_active` et n'autorise que la
transition `draft` → `active`. Un dispatch inconnu, appartenant à une autre
compagnie ou déjà actif rend le même message opaque, sans révéler son existence,
son propriétaire ni son état. Aucun identifiant Auth, message SQL ou donnée
personnelle n'est exposé à un appelant.

Le registre `private.flight_start_commands` force RLS, n'accorde aucun privilège
API, lie `(owner_id, idempotency_key)` à l'empreinte SHA-256 du payload et
n'admet qu'un démarrage par dispatch. Un rejeu identique rend la même réponse ;
une collision de clé échoue ; deux sessions concurrentes sur le même dispatch
convergent vers un seul vol actif, une seule commande et un seul horodatage.
`authenticated` conserve une lecture seule filtrée par la compagnie du sujet Auth
et ne reçoit aucun `execute`. Aucune frontière Auth, appelant desktop,
télémétrie, clôture, écriture financière, annulation ou preuve Edge runtime n'est
couverte par ce ticket.

## Clôture de vol et règlement autoritaires T0051

`close_flight` est une fonction `security definer` à `search_path` vide
exécutable uniquement par `service_role`. Elle accepte un propriétaire vérifié en
amont, une clé UUID, un dispatch et un rapport `jsonb` dont le jeu de clés est
validé strictement : `outcome` et `blockMinutes` sont obligatoires,
`landingVerticalSpeedFpm` et `fuelUsedKg` sont facultatifs, toute clé
supplémentaire est refusée. Aucun montant, aucune devise, aucune distance, aucune
compagnie, aucun état et aucun horodatage de clôture ne franchit la frontière
comme autorité cliente.

La règle de sécurité ajoutée est explicite : aucune valeur monétaire, distance ou
durée facturable ne franchit une frontière cliente sans être recalculée ou bornée
par le serveur. Le temps de bloc retenu est `min(temps déclaré, temps réellement
écoulé depuis l'horodatage de départ serveur)`, la distance vient du référentiel
T0057, le multiplicateur des paliers de ce même référentiel, et le montant est
recalculé puis borné par le plafond de la politique. Une fin interrompue reçoit le
plancher de la politique, jamais zéro et jamais le barème complet. Le barème
lui-même vient d'une source canonique versionnée dont la copie embarquée est
comparée texte à texte par le gate backend ; il n'est ni lisible ni surchargeable
par une variable d'environnement, et `private.flight_settlement_policy()`
n'accorde `execute` à aucun rôle d'API.

La commande verrouille la compagnie, puis le sujet financier, puis le dispatch, et
refuse un compte en suppression via `private.account_is_active`. Un dispatch
inconnu, appartenant à une autre compagnie, déjà clôturé ou encore en brouillon
rend le même message opaque. Les trois tables ajoutées — rapports, événements de
réputation et registre de clôture — vivent dans `private`, forcent RLS et
n'accordent aucun privilège à `anon`, `authenticated` ou `service_role`. Les
événements de réputation sont append-only par trigger, comme les écritures du
grand livre : ni `update`, ni `delete`, ni `truncate`. La seule lecture cliente est
`public.get_company_reputation`, qui exige une session `authenticated` non
anonyme, dérive la compagnie de `auth.uid()` et rend un score borné `0–100` sans
identifiant, sans montant et sans effet sur une capacité.

Un rejeu identique rend la même réponse et n'écrit rien de plus ; une clé réutilisée
avec un autre payload échoue ; deux sessions concurrentes sur le même vol
convergent vers un état terminal, un rapport, un événement de réputation et un
seul crédit. Une panne injectée sur le registre annule l'état, le rapport, la
réputation et l'argent ensemble. Aucune frontière Auth, appelant desktop,
annulation, télémétrie de clôture, cible distante ni donnée réelle n'est couverte
par ce ticket.

## Configuration et session desktop T0038

Le bundle n'accepte que deux paramètres explicitement publics : URL Supabase et
clé anonyme. T0038 les borne à `http://127.0.0.1:54321`; aucune origine distante,
clé `service_role` ou variable générique n'est exposée. La CSP de développement
ajoute uniquement cette origine loopback à Vite/HMR. La CSP de production reste
`connect-src 'none'` jusqu'à l'identification et la revue d'une cible distante.

Bearer et refresh token restent en mémoire WebView, sans log, rendu, fichier,
cookie ni stockage Web. Un bearer proche de l'expiration est renouvelé auprès
de Supabase Auth avec une requête et une réponse bornées. Les appels concurrents
partagent un seul refresh ; la rotation remplace les deux tokens seulement après
validation complète. Un refus Auth efface la session, tandis qu'une panne
transitoire la conserve pour un retry. Cette fondation n'acquiert pas la session
initiale et ne prétend pas protéger un bearer contre une WebView compromise.

## Acquisition de session locale T0039

La première méthode choisie explicitement est email/mot de passe contre
Supabase Auth local uniquement. Le desktop envoie exactement ces deux champs à
`/auth/v1/token?grant_type=password` avec la clé anonyme publique, un timeout de
cinq secondes et une réponse lue en streaming jusqu'à 16 Kio. Les identifiants
hors bornes, refus Auth et sessions malformées échouent fermés avec des erreurs
publiques sans détail amont.

Le gestionnaire T0038 reçoit les deux tokens seulement après validation complète
de la réponse. Le panneau bloque les soumissions concurrentes, annule au
démontage et efface le mot de passe de son state dès la soumission. Un invariant
scanne les sources auth et refuse stockage Web, cookie ou journalisation. Cette
tranche ne crée ni route, appel live, inscription, récupération de mot de passe,
OAuth, persistance Windows, cible distante ou donnée réelle. Une WebView
compromise peut toujours lire les secrets présents en mémoire.

## Provider email local T0040

Le grant password T0039 exige que le provider email local soit actif. La
configuration T0040 garde néanmoins `auth.enable_signup = false` : aucune
inscription publique n'est autorisée, et les identités de validation sont
provisionnées uniquement par l'Admin API de la pile locale jetable. SMTP,
confirmations, récupération et cible distante restent désactivés.

Le gate backend refuse simultanément l'ouverture de l'inscription globale et la
désactivation du provider requis. La preuve runtime utilise une adresse
`.invalid`, conserve mot de passe et tokens en mémoire seulement, puis détruit
l'identité et la pile sans backup. Elle ne change pas l'hypothèse de WebView non
fiable et n'autorise aucune donnée réelle.

## Route de connexion locale T0041

La composition desktop lit une fois la configuration publique T0038 et conserve
un seul `DesktopSessionManager` pour la durée de l'application. Sans session,
`/` redirige vers `/login`; après validation et installation atomique par T0039,
le login redirige vers l'accueil. Le booléen React de navigation ne contient
aucun token et ne devient vrai qu'après vérification de `hasSession()`.

La déconnexion efface le gestionnaire avant de rendre à nouveau le formulaire.
Rendu, redirections et déconnexion ne déclenchent aucun appel réseau. L'invariant
de non-persistance couvre aussi la composition, les routes et la page login :
aucun bearer, refresh token ou mot de passe n'est stocké, journalisé ou rendu.
Cette garde d'interface ne remplace pas l'autorité Auth et ne protège pas les
secrets en mémoire contre une WebView compromise. T0041 ne prouve ni persistance,
ni onboarding, ni achat composé, ni cible distante.

## Composition de l'onboarding desktop T0042

Le formulaire protégé envoie exactement un nom normalisé et une clé UUID à
`company-onboarding`. Il obtient le bearer depuis l'unique gestionnaire T0038 au
moment de la soumission ; aucun token n'est copié dans l'état React. Propriétaire,
montant et devise restent absents du client et sont dérivés par T0023 puis T0022.

Une intention conserve sa clé après panne transitoire ou réponse perdue et la
renouvelle lorsque le nom change. Le panneau bloque les soumissions concurrentes,
annule au démontage et valide une réponse allowlistée bornée. Un refus Auth efface
la session avant le retour au login. Les sources onboarding sont scannées contre
stockage Web, cookie, logs et champs métier interdits. Cette composition ne
charge pas une compagnie existante, ne persiste pas l'intention et ne prouve ni
CSP de production ouverte, WebView live, cible distante ou donnée réelle.

## Lecture du catalogue desktop T0043

Le desktop peut demander explicitement au plus vingt lignes de
`aircraft_purchase_offers` via la Data API locale. L'URL, la projection, le
filtre `available`, l'ordre et la limite sont constants. La requête porte la clé
anonyme publique et le bearer obtenu au dernier moment ; la RLS T0029 reste
l'autorité de lecture et aucune mutation Data API n'est autorisée.

Le corps est lu en streaming jusqu'à 32 Kio puis chaque objet et chaque champ
sont strictement validés. Le panneau ne charge rien au rendu, bloque la
concurrence, annule au démontage et efface la session sur refus Auth. Il ne
persiste ni ne journalise token ou catalogue. L'allowlist canonique lie l'unique
chemin source à l'unique ressource ; le gate refuse accès non déclaré, ressource
divergente et entrée orpheline en plus des invariants d'autorité existants.
Production reste fermée par CSP. T0045 compose l'achat sans élargir cette CSP.

## Lecture de présence de compagnie T0044

Le desktop peut demander explicitement au plus deux lignes de `companies` via la
Data API locale, avec une projection limitée à `id`. La clé anonyme publique et
le bearer courant sont obtenus à l'action ; la RLS propriétaire reste l'autorité
et l'absence, une ligne ou une violation d'unicité sont distinguées sans filtre
ou propriétaire fourni par le client.

Le corps est borné à 8 Kio et validé strictement, puis réduit à un booléen :
aucun identifiant ou nom n'est conservé, rendu, persisté ou journalisé. Le
panneau ne charge rien au rendu, bloque la concurrence, annule au démontage et
efface la session sur refus Auth. L'allowlist canonique lie le transport à
`companies`, refuse les chemins dupliqués et ne relâche aucune mutation. La
preuve reste locale et injectée ; elle n'ouvre ni cible distante, ni CSP de
production, ni achat composé.

## Composition catalogue et achat desktop T0045

Seule une offre présente dans la réponse T0043 strictement validée peut être
sélectionnée. Le panneau T0037 n'accepte plus un bearer brut comme prop : il
obtient le bearer courant depuis l'unique gestionnaire de session au moment de
la soumission, l'envoie exclusivement à l'Edge Function et efface la session sur
refus Auth. Aucun token n'est copié dans l'état React, persisté, journalisé ou
rendu.

La commande conserve une clé d'idempotence stable pour les retries de la même
offre, bloque les doubles soumissions et interdit un changement d'offre pendant
une requête. Le payload reste fermé à `offerId` et `idempotencyKey`; prix,
devise, compagnie, propriétaire et solde restent dérivés ou contrôlés côté
serveur. La preuve est locale et injectée ; elle n'ouvre ni CSP de production,
ni cible distante, flotte ou donnée réelle.

## Lecture et actualisation de flotte desktop T0046

Le desktop lit `company_aircraft` avec une projection, un ordre et une limite
constants, sans `company_id`, `owner_id` ou autre filtre choisi par le client.
Le bearer acquis au clic porte le sujet Auth et la RLS propriétaire T0029 reste
l'unique autorité d'isolation. La réponse est bornée à 64 Kio et cinquante
lignes ; champs, UUID, codes, numéros de série, timestamps, version et doublons
sont validés avant rendu.

Le panneau ne charge rien au rendu, bloque les lectures concurrentes, annule au
démontage et efface la session sur refus Auth. Après achat, il relit uniquement
une flotte déjà chargée et ne fabrique jamais un avion depuis l'offre ou la
réponse d'achat. Credential, identifiant interne et détail amont ne sont ni
persistés, ni journalisés, ni rendus. La preuve reste locale et injectée ; elle
n'ouvre ni CSP de production, cible distante, pagination, mutation de flotte ou
donnée réelle.

## Autorité globale du golden path T0024

L'inventaire canonique `eng/authority-inventory.json` couvre les dix étapes de
`PRODUCT.md`. Il ne transforme jamais l'absence de code en contrôle de sécurité :
T0048 classe la frontière Auth du dispatch `server-authoritative` avec une
couverture partielle ;
le suivi et la clôture de vol, la réputation, la maintenance, les opérations
passives et la distribution restent `not-implemented`.

Les tranches compagnie, cycle de compte, flotte, finance et continuité déjà présentes
sont `server-authoritative` avec une couverture partielle et des limites
explicites. Supabase Auth reste la seule `external-authority`. Le gate statique
scanne les sources WebView, Tauri et bridge et échoue fermé sur credential
`service_role`, commande réservée au serveur, accès Data API non allowlisté, mutation
par client Supabase, SQL direct ou nouveau langage client non inventorié.

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

## Canal de télémétrie local T0054

La diffusion `telemetry.v1` reste sous les contrôles de la frontière locale
T0010, sans nouvelle autorité :

- le jeton d'instance est exigé sur la négociation comme sur l'upgrade WebSocket ;
  une connexion sans jeton ou avec un mauvais jeton reçoit `401` et ne crée aucun
  abonné ;
- la liaison reste `127.0.0.1` : toute autre adresse de l'hôte, `::1` inclus, est
  refusée par le socket, jamais par un filtre applicatif ;
- seuls les champs bornés de `FlightSample` sont publiés, sans type SDK, sans
  identifiant de compagnie ou de vol et sans champ métier ;
- chaque échantillon est revalidé avant diffusion, y compris s'il provient d'un
  adaptateur qui contourne la fabrique du domaine ;
- la mémoire est bornée par construction : un seul échantillon en attente par
  abonné, aucun tampon cumulatif, et un abonné qui cesse de drainer est
  abandonné après un délai d'envoi borné ;
- l'état publié se limite à `telemetrySource` et `telemetryState` ; ni chemin de
  trace, ni version de SDK, ni jeton n'apparaît dans une réponse ou une erreur ;
- aucun jeton, échantillon brut ni chemin utilisateur n'est journalisé : le
  processus ne conserve aucun fournisseur de logs.

La source native reste facultative. Son absence donne l'état `unavailable` et
n'ouvre aucun chemin de secours : elle n'est jamais requise par la CI et
n'accorde aucune capacité à la WebView.

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

Un avertissement informatif de `cargo-audit` n'est pas une exception implicite.
`cargo audit` seul ne fait échouer que les vulnérabilités : T0058 ajoute donc un
gate qui compare le rapport à `eng/cargo-advisory-allowlist.json`. La règle est
fail-closed dans les deux sens : toute vulnérabilité échoue, tout avertissement
absent de la liste échoue, un avertissement qui change de crate, de version ou de
nature échoue, une entrée qui n'est plus signalée échoue comme périmée, et la
liste entière expire à sa date `revalidateBefore`. Chaque entrée porte une
justification, sa présence ou non dans le graphe `win-x64` et sa condition de
sortie. Cette liste ne couvre jamais une vulnérabilité et ne remplace pas une
exception de sécurité, qui reste soumise à l'approbation explicite d'Andy.

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

## Location d'avion autoritaire T0032

Les termes de location sont versionnés sur l'offre et recopiés dans le contrat :
le client ne fournit ni prix, devise, compagnie, durée, cadence, grâce, date ou
état. Création, rattrapage temporel et résiliation sont réservés à
`service_role`, avec `search_path` vide et registres d'idempotence privés. Les
échéances utilisent une identité stable par contrat et numéro ; une écriture
`aircraft_lease_rent` immuable correspond à chaque échéance payée, et les frais
de mise en service comme la pénalité de résiliation ajoutent chacun exactement
une écriture débitrice de type dédié.

Le contrat suspend l'usage dès l'entrée en grâce de 72 heures, le rétablit
uniquement si la commande temporelle solde les arriérés, et le retire
transactionnellement au défaut, à l'expiration ou à la prise d'effet du préavis
de résiliation. Une résiliation ne peut ni raccourcir une échéance déjà exigible
ni s'écrire partiellement : sans le solde de la pénalité, la commande est
refusée. Cet état d'usage est désormais opposable : T0060 le fait lire par les
deux commandes de mise en service, donc la réserve « autoritaire dans les données
mais non opposable » de T0032 est levée. Les rôles
client ne reçoivent que `SELECT` sous RLS sur leurs contrats et échéances ;
`anon` ne lit rien et aucune mutation directe n'est accordée. La commande
temporelle accepte une heure uniquement parce que son appelant `service_role`
constitue l'autorité serveur ; toute future frontière doit refuser de reprendre
une heure client. Sans ordonnanceur, l'exécution ponctuelle en production n'est
pas garantie et aucune donnée réelle n'est admise.

## Opposabilité de la fin d'usage T0060

Règle de sécurité ajoutée : **la mise en service d'un avion dépend de son état
d'usage serveur, jamais d'une donnée d'appelant, et l'écriture de cet état reste
réservée aux commandes de location.**

`public.create_dispatch_draft` et `public.start_flight_from_dispatch` sont
redéfinies en bloc par une migration append-only et lisent
`public.company_aircraft.is_usable` sur la ligne dérivée du serveur, verrouillée
`for update`. Aucun paramètre, aucune colonne et aucune valeur d'usage ne franchit
la frontière : les deux signatures sont inchangées, les fonctions restent
`security definer` avec `search_path` vide, et le seul `execute` accordé reste
celui de `service_role`. `anon` et `authenticated` n'obtiennent ni exécution, ni
`update` sur `public.company_aircraft`, et aucun privilège de lecture nouveau
n'est accordé sur les tables de location.

Les deux refus réutilisent **verbatim** les messages déjà livrés,
`Aircraft is unavailable for dispatch.` et
`Dispatch is unavailable for flight start.`, avec le SQLSTATE
`object_not_in_prerequisite_state`. Un avion inutilisable est donc indistinguable
d'un avion inconnu ou appartenant à une autre compagnie ; aucun message, aucun
`detail` et aucun `hint` ne révèle l'existence d'une location, son état, une
échéance ou une grâce. À la création d'un brouillon, la garde précède même le
contrôle d'exclusivité, si bien que le refus ne dit pas non plus si l'avion porte
déjà un dispatch, et les deux refus partent de la même ligne de la fonction. Le
gate backend interdit qu'un message de refus de cette migration nomme une
location, un état ou une échéance.

La garde est évaluée dans la transaction de la commande, sur une ligne verrouillée,
dans un ordre documenté — compagnie, dispatch, avion — compatible avec les
commandes de location, où `public.company_aircraft` est aussi verrouillé en
dernier. Le rejeu d'une commande de départ déjà acquise n'est jamais refusé par la
garde et ne crée pas de second départ, même si l'avion est devenu inutilisable
entre-temps. Depuis T0065, sa réponse est aussi exactement celle de l'acquisition :
voir « Contrat d'idempotence d'une commande privilégiée » ci-dessous.

`public.close_flight` n'est pas gardé, sur décision d'Andy du 4 août 2026 : un vol
déjà parti reste clôturable et réglé, et c'est seulement le brouillon suivant qui
est refusé. Réserve résiduelle : sans ordonnanceur d'échéances, la garde est exacte
par rapport à l'état enregistré et non par rapport à l'heure murale, donc un avion
peut rester utilisable après sa date réelle d'expiration jusqu'au prochain appel de
la commande temporelle. Aucune frontière Auth, aucun endpoint, aucun appelant
desktop, aucune cible distante et aucune donnée réelle ne sont couverts.

## Contrat d'idempotence d'une commande privilégiée T0065

Règle de sécurité, ajoutée le 5 août 2026 sur décision d'Andy — issue A : le rejeu
d'une commande privilégiée déjà acquise **restitue la réponse rendue à
l'acquisition**. Il ne la reconstruit pas depuis l'état vivant, et il ne rend jamais
un état plus récent que celui accordé. Un appelant qui rejoue une clé pour cause de
réponse perdue reçoit donc l'acquisition, pas une observation de l'état courant.

`public.start_flight_from_dispatch` applique cette règle depuis la migration
`20260805000200_flight_start_replay_fidelity.sql`. Le chemin de rejeu reconstruit sa
réponse depuis `private.flight_start_commands` — `aircraft_id`, `dispatch_id` et
`started_at not null`, écrits dans la transaction qui a accordé le départ — plus le
littéral `active`, puisque cette ligne de registre n'existe qu'après une transition
`draft` → `active` réussie. Seul le `schema_version` immuable est encore lu sur la
ligne de dispatch. Aucune colonne nouvelle n'est conservée, donc aucune donnée
supplémentaire n'entre dans la politique de rétention.

Deux conséquences de sécurité sont voulues. Un rejeu ne devient pas un canal
d'observation de l'état courant d'un vol : il ne dit plus si le vol a été clôturé,
ni comment. Et la garde d'usage T0060 reste après ce chemin, donc un départ déjà
accordé garde sa réponse même après la fin d'usage de l'avion, sans jamais créer un
second départ, une seconde ligne de registre ou une écriture financière.

Le gate backend interdit, contre ce nouveau fichier, toute lecture de `state`,
`started_at` ou `closed_at` de la ligne de dispatch vivante dans le chemin de rejeu,
et il exige que la garde d'usage reste placée après lui. Le pgTAP
`flight_start_replay_fidelity.test.sql` place la clôture **avant** le rejeu, ce que le
gate vérifie aussi : le scénario T0050 rejouait avant la clôture et ne pouvait donc
pas échouer sur cet écart. `KI-024` est résolu par ce ticket.

L'écart initial portait sur un seul champ des cinq, pas deux : `KI-024` annonçait un
`startedAt` remis à `null` par `private.set_flight_dispatch_started_at`, mais T0051
avait déjà redéfini ce trigger pour qu'un état terminal conserve son instant de
départ. La règle ne dépend pas de ce trigger : elle interdit la lecture vivante
elle-même, donc un changement futur du trigger ne peut pas rouvrir l'écart.
