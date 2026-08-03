# Vision produit — Thrustline Rebuild

Statut : Validé pour la phase 1 le 30 juillet 2026.

Revue de cohérence : le périmètre MVP, le modèle solo connecté, le golden path,
les contraintes de distribution et les mesures de réussite sont cohérents avec
les ADR-0001 à ADR-0004 acceptées. Cette validation ne promeut aucun canal
Windows/MSFS vers `Supported` et ne transforme pas une cible non mesurée en
capacité prouvée.

## Vision

Thrustline transforme les vols MSFS en gestion cohérente d'une compagnie
aérienne virtuelle : planifier, exploiter, suivre, analyser et développer une
compagnie sans perdre les données ni pouvoir falsifier facilement son économie.

## Principes produit

- Windows-first et MSFS-first.
- Fonctionnel même lorsque MSFS est fermé pour la partie gestion.
- Dégradation claire en cas de panne Supabase, SimBrief, météo ou SimConnect.
- Aucune perte silencieuse d'un vol ou d'une transaction.
- Les calculs importants sont explicables à l'utilisateur.
- Les mises à jour sont signées, récupérables et non destructrices.
- Vie privée par défaut ; télémétrie facultative et transparente.

## Utilisateur principal

Un passionné de simulation qui gère sa propre compagnie et effectue lui-même des
vols dans MSFS.

## Modèle produit retenu

Le MVP est **solo connecté, préparé pour une collaboration ultérieure**,
conformément à `ADR-0001`.

- Un utilisateur possède au plus une compagnie.
- Une compagnie a exactement un propriétaire humain.
- Le propriétaire est le seul à voir et gérer les vols, finances, flotte et
  horaires de sa compagnie.
- Aucun membre, rôle supplémentaire, invitation, partage ou transfert de
  propriété n'est livré dans le MVP.
- L'identité de la compagnie reste distincte de celle du propriétaire afin de ne
  pas bloquer une évolution future.

La collaboration est probable après le MVP, mais elle nécessitera une nouvelle
ADR. Ne pas ajouter partiellement du multi-utilisateur.

## Parcours essentiels

1. Installer, lancer et créer/se connecter à un compte.
2. Créer une compagnie sans état partiel.
3. Acheter ou louer un avion.
4. Créer un dispatch et préparer le vol avec SimBrief.
5. Connecter MSFS et suivre les phases du vol.
6. Reprendre après une déconnexion ou un crash.
7. Finaliser le vol une seule fois.
8. Voir les impacts financiers, réputation et maintenance.
9. Planifier des opérations passives sans incohérence temporelle.
10. Mettre à jour ou désinstaller sans perdre les données.

## MVP de la refonte

- Authentification et compagnie.
- Flotte, maintenance et propriété.
- Routes, dispatch et SimBrief.
- SimConnect, phases de vol, ACARS résumé et rapport.
- Grand livre financier autoritaire.
- Réputation et progression minimales.
- Sauvegarde cloud, reprise et diagnostics.
- Installateur et mises à jour signés.

## Politique économique d'ouverture du MVP

Chaque nouvelle compagnie MVP reçoit une unique ouverture de **430 000 EUR**,
soit `43000000` unités mineures. Cette politique v1 est identique pour tous :
aucun choix de devise, difficulté, bonus, aléa ou formule client.

`eng/economy-policy.json` est la source normative. Une future modification
exigera une nouvelle version et une date ou condition d'entrée en vigueur pour
les seules compagnies créées ensuite ; elle ne réécrira jamais une ouverture
existante. Cette décision ne définit ni revenus, ni coûts, ni prix, ni conversion
de devise et ne constitue pas un équilibrage économique complet.

## Brouillon de dispatch minimal du MVP

Le premier dispatch persistant associe un avion possédé à un départ et une
arrivée ICAO distincts. Le client peut proposer l'avion et ces deux codes, mais
le serveur dérive la compagnie, valide la propriété, normalise les codes et crée
seul l'état initial `draft` ainsi que son horodatage. Un même avion ne peut pas
porter deux brouillons actifs et une intention rejouée ne crée pas de doublon.

La frontière applicative n'accepte du client que l'avion, les deux ICAO et
l'idempotence. Elle dérive le propriétaire d'une session non anonyme vérifiée ;
compagnie, état et horodatage restent exclusivement serveur.

Cette tranche ne définit pas encore une route détaillée, un horaire, un appel
SimBrief, un OFP, des passagers, du fret, un coût, un revenu ou le cycle de vie
d'un vol. Ces données et transitions exigent des tickets séparés avant de
devenir des règles produit.

## Référentiel d'aérodromes borné

Les deux codes d'un dispatch ne sont plus n'importe quelle chaîne de quatre
caractères : ils doivent désigner deux aérodromes distincts d'un référentiel
serveur versionné. Ce référentiel porte pour chaque aérodrome un code ICAO
unique, un nom borné, une position et un palier de popularité choisi parmi
quatre valeurs ordonnées, de `regional` à `hub`.

Le référentiel est une donnée de jeu, pas une base aéronautique : il couvre au
plus 200 aérodromes écrits dans le dépôt, sans import d'un jeu de données tiers
ni téléchargement à l'exécution. Ses paliers sont un choix de cadrage de
l'alpha, pas une mesure du trafic réel, et il devra être élargi ou remplacé par
une source maintenue avant toute ouverture externe.

Il est en lecture seule pour un joueur authentifié et aucun rôle client ne peut
le modifier, car un référentiel modifiable permettrait plus tard de gonfler le
revenu d'un vol. Il ne porte lui-même ni montant, ni multiplicateur, ni devise :
un code inconnu est refusé exactement comme un code mal formé, sans révéler le
contenu du référentiel. Cette tranche n'expose pas de sélecteur d'aérodromes au
desktop et ne calcule ni distance, ni durée, ni revenu.

## Hors MVP

- Réseau social, marketplace communautaire et mods.
- Membres de compagnie, rôles collaboratifs, invitations et transfert de
  propriété.
- Vols, finances, flotte ou horaires partagés entre plusieurs humains.
- Application mobile.
- Tableau de bord web public.
- Multi-VA complexe.
- Simulation économique exhaustive.
- Anti-triche présenté comme inviolable.

## Contraintes de distribution

- Windows 11 x64 uniquement, version publique encore maintenue par Microsoft.
- MSFS 2024 stable uniquement ; Microsoft Store/Xbox App et Steam sont deux
  combinaisons distinctes à prouver avant toute déclaration `Supported`.
- Windows 10, ARM64, MSFS 2020, Windows Insider et MSFS Beta/Preview sont exclus
  conformément à `ADR-0003`.
- Aucun privilège administrateur permanent.
- Données utilisateur séparées des fichiers d'installation.
- Politique de confidentialité, support, sécurité et licence avant bêta publique.

## Mesures de réussite

- Sessions sans crash ≥ objectif défini avant bêta.
- Zéro double clôture de vol.
- Zéro variation financière sans écriture de grand livre.
- Zéro acquisition d'avion sans propriété et débit atomiques ; un rejeu
  identique ne crée ni second avion ni second débit.
- Une demande d'achat n'accepte du client que l'offre et l'idempotence ; la
  compagnie est dérivée de la session vérifiée par la frontière serveur.
- Zéro brouillon de dispatch pour un avion hors compagnie ou déjà engagé dans
  un brouillon actif ; un rejeu identique conserve le même dispatch.
- Zéro brouillon de dispatch portant un aérodrome absent du référentiel serveur,
  et zéro mutation de ce référentiel par un rôle client.
- Reprise après coupure testée sur chaque parcours essentiel.
- Temps de démarrage et consommation mémoire budgétés.
- Mise à jour N-1 → N et rollback validés sur VM propre.
