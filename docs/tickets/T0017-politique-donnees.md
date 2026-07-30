# T0017 — Définir et contrôler la politique de données

Status: Review
Owner: Andy
Branch: `docs/t0017-data-policy`
Phase: 0
Risk: High
Security-sensitive: Yes

## Goal

Fournir une politique de données versionnée et contrôlable qui fixe, avant toute
donnée utilisateur réelle, les catégories minimales du MVP, leur cycle de vie,
la séparation des environnements, les règles de suppression et les exigences de
sauvegarde/restauration.

## Context

La roadmap exige une politique de données en phase 0, mais le dépôt ne contient
encore ni source canonique de rétention, ni règles complètes pour
dev/staging/prod, ni contrat de suppression/restauration.

T0012 ne contient que deux identités et deux compagnies synthétiques. Sa clé
étrangère `companies.owner_id ... on delete restrict` protège l'intégrité mais
empêche aujourd'hui de supprimer directement un utilisateur Auth qui possède
une compagnie. Le futur grand livre immuable devra lui aussi préserver
l'intégrité économique sans conserver indéfiniment un lien personnel.

Ce ticket définit et contrôle la cible d'ingénierie. Il ne constitue pas un avis
juridique, une politique de confidentialité publique ni la preuve qu'un workflow
de suppression, export ou restauration existe déjà.

## Dependencies

- T0002 et `ADR-0001` pour le MVP solo ;
- T0003 et `ADR-0002` pour la réécriture sans migration des données historiques ;
- T0012 pour le schéma local, les seeds synthétiques et la RLS ;
- `docs/PRODUCT.md`, `docs/ARCHITECTURE.md`, `docs/SECURITY.md` et
  `docs/ROADMAP.md` ;
- principes de minimisation, limitation de conservation et effacement du RGPD ;
- recommandations CNIL sur les données de test et les sauvegardes ;
- documentation Supabase sur les environnements et sauvegardes.

## Allowed areas

- `eng/data-policy.json` ;
- `tests/data-policy/` ;
- `package.json` ;
- `.github/workflows/ci.yml` et `tests/ci/run.ps1` ;
- `.gitignore` si une sortie locale doit être exclue ;
- `docs/DATA_POLICY.md` ;
- `docs/README.md` ;
- `docs/ARCHITECTURE.md` ;
- `docs/SECURITY.md` ;
- `docs/QUALITY.md` ;
- `docs/SETUP.md` ;
- `docs/ROADMAP.md` ;
- `docs/CURRENT_STATE.md` ;
- `docs/KNOWN_ISSUES.md` ;
- ce ticket et `docs/tickets/README.md`.

## Do not touch

- migrations, seed, configuration Supabase et types générés ;
- données ou projet Supabase distant ;
- code runtime frontend, Tauri ou bridge ;
- Auth, RLS, contrats REST/SignalR et SimConnect ;
- modèle économique, montants ou schéma du grand livre ;
- télémétrie, crash reporting, support ou collecte analytique ;
- secrets, environnements GitHub et déploiement ;
- packaging, signature et updater ;
- avis juridique, base légale définitive ou politique de confidentialité
  publique.

## Requirements

### 1. Créer une source canonique

Créer un JSON strict et versionné contenant :

- version de schéma, date et contexte de révision ;
- environnements local, CI, staging et production ;
- interdiction des données de production en local, CI et staging ;
- catégories minimales : identité Auth, état de compagnie, grand livre, données
  brutes de vol, rapports de vol, journaux sécurité, diagnostics facultatifs et
  sauvegardes ;
- finalité, caractère personnel, collecte, rétention active, action de fin de
  vie et traitement en sauvegarde pour chaque catégorie ;
- délais exprimés en jours ou événement explicite, sans durée implicite ;
- objectifs de suppression, restauration, export et revue humaine.

### 2. Définir les règles de cycle de vie

- Collecter uniquement ce qui est nécessaire au parcours MVP.
- Ne jamais copier de donnée de production vers local, CI ou staging ; utiliser
  des données fictives, ou anonymisées de manière irréversible si une exception
  future est approuvée.
- Séparer état actif, suppression restreinte, effacement/anonymisation et
  expiration des sauvegardes.
- Une restauration doit rejouer les suppressions intervenues après le point
  restauré avant réouverture aux utilisateurs.
- Le grand livre futur peut rester append-only, mais doit pouvoir perdre tout
  lien personnel après suppression sans casser l'intégrité économique.
- Aucun délai ne devient une promesse juridique ou produit avant revue du
  responsable de traitement et publication de la notice correspondante.

### 3. Borner rétention et suppression

- Données brutes de vol : maximum 7 jours après production du rapport.
- Journaux de sécurité : maximum 90 jours.
- Diagnostics facultatifs : maximum 30 jours et consentement explicite.
- Sauvegardes : fenêtre maximale de 30 jours.
- Identité, compagnie et rapports : pendant le compte actif, puis suppression
  ou anonymisation sous 30 jours après demande vérifiée, hors obligation de
  conservation validée.
- Grand livre : conservation non personnelle possible pour l'intégrité ; le lien
  à une personne doit être anonymisé sous 30 jours après demande vérifiée.
- Les durées sont des maxima d'ingénierie initiaux, à réduire si la finalité le
  permet et à faire valider avant bêta.

### 4. Rendre les limites explicites

- Marquer export, suppression, purge, anonymisation, sauvegarde distante,
  restauration et replay des suppressions comme non implémentés tant qu'aucune
  preuve ne les couvre.
- Consigner le blocage `on delete restrict` comme problème connu.
- Interdire toute donnée utilisateur réelle avant qu'un prochain ticket
  implémente et teste ces workflows.

### 5. Ajouter un contrôle déterministe

Le harnais PowerShell doit :

- refuser un JSON absent, invalide ou d'une version inconnue ;
- vérifier les environnements, catégories, unités et maxima obligatoires ;
- refuser toute autorisation de données de production hors production ;
- vérifier que les seeds présents restent synthétiques ;
- vérifier la présence du statut d'implémentation des capacités sensibles ;
- réussir sur le dépôt et échouer sur au moins trois mutations négatives :
  catégorie absente, donnée de production autorisée hors production et délai
  dépassé ;
- ne lancer aucun service, n'accéder à aucun réseau et ne lire aucun secret.

### 6. Intégrer le gate et documenter

- Exposer `pnpm data-policy:check`.
- Exécuter ce gate dans la CI en lecture seule.
- Documenter les catégories, environnements, procédures attendues, limites et
  sources officielles.
- Synchroniser roadmap, qualité, sécurité, architecture, état et suivi.

## Non-goals

- Implémenter la suppression de compte, l'export ou la portabilité.
- Ajouter une migration de purge, anonymisation ou grand livre.
- Configurer un projet Supabase dev/staging/prod.
- Créer ou restaurer une sauvegarde distante.
- Collecter des logs, diagnostics, données de vol ou données analytiques.
- Fixer une base légale définitive ou remplacer une revue juridique.
- Résoudre l'exposition Docker Desktop suivie par `KI-017`.

## Acceptance criteria

- [x] La source JSON unique couvre catégories, environnements et cycle de vie.
- [x] Les maxima 7/30/90 jours et la fenêtre de sauvegarde sont explicites.
- [x] Local, CI et staging refusent les données de production.
- [x] La politique distingue règles cibles, contrôles présents et capacités non
      implémentées.
- [x] Le grand livre immuable reste compatible avec l'anonymisation future.
- [x] Le blocage actuel de suppression est consigné sans réécrire T0012.
- [x] Le harnais passe sur le dépôt et détecte les trois mutations requises.
- [x] La CI et son harnais exigent `pnpm data-policy:check`.
- [x] Les documents et le Completion Report reflètent uniquement les preuves
      exécutées.

## Security review

- actifs/données : identité Auth, propriété de compagnie, état de jeu, grand
  livre, télémétrie de vol, rapports, journaux, diagnostics et sauvegardes ;
- frontière : clients distribués et contributeurs non fiables vers environnements
  locaux, CI et futur backend Supabase ;
- abus : collecte excessive, copie de production en test, conservation infinie,
  suppression incomplète, restauration ressuscitant des données supprimées,
  grand livre conservant un identifiant personnel ;
- validation/autorisation : source versionnée, gate à mutations, données
  synthétiques et future commande serveur réservée au propriétaire vérifié ;
- atomicité/idempotence : suppression et replay après restauration devront être
  transactionnels, idempotents et auditables ; ils ne sont pas implémentés ici ;
- logs/vie privée : aucun contenu personnel, secret, JWT, adresse réelle ou
  donnée de vol n'est ajouté au dépôt ou aux sorties du harnais.

## Automated validation

```powershell
pnpm data-policy:check
pnpm ci:check
pnpm backend:check
git diff --check
```

## Manual verification

1. Relire chaque catégorie, finalité, durée et action de fin de vie.
2. Confirmer que local, CI et staging interdisent les données de production.
3. Confirmer que les capacités non implémentées ne sont pas présentées comme
   disponibles.
4. Modifier une copie du JSON pour autoriser la production en staging et
   confirmer l'échec du harnais.
5. Vérifier qu'aucun secret, identifiant réel ou donnée personnelle n'est ajouté.

Temps cible : 10 minutes.

## Rollback

Abandonner la branche avant fusion. Après fusion, revenir par une PR ciblée qui
retire le gate et la politique ensemble. Ne jamais supprimer seulement le gate
pour contourner un échec et ne jamais réintroduire de données réelles de test.

## Completion Report

### Summary

Une source JSON versionnée décrit huit catégories, quatre environnements, les
maxima 7/30/90 jours et l'état réel des capacités. La collecte est refusée par
défaut et l'admission de données utilisateur réelles reste bloquée.

Un harnais compatible Windows PowerShell et PowerShell 7 valide la politique,
les seeds synthétiques, `KI-021` et l'intégration CI. Il se teste sur trois
mutations négatives. Aucun schéma, runtime, projet distant ou donnée réelle
n'est modifié.

### Files changed

- source et gate : `eng/data-policy.json`, `tests/data-policy/run.ps1`,
  `package.json`, `.github/workflows/ci.yml` et `tests/ci/run.ps1` ;
- politique et index : `docs/DATA_POLICY.md` et `docs/README.md` ;
- architecture/exploitation : `ARCHITECTURE`, `SECURITY`, `QUALITY`, `SETUP`,
  `ROADMAP`, `CURRENT_STATE` et `KNOWN_ISSUES` ;
- suivi : ce ticket et `docs/tickets/README.md`.

### Commands and results

- premier lancement du harnais T0017 : échec réel, car deux titres accentués
  étaient lus avec l'encodage Windows PowerShell 5.1 et la mutation de catégorie
  déclenchait `PropertyNotFoundStrict` ;
- après correction, `pnpm data-policy:check` : réussi ; dépôt conforme et
  3 mutations négatives détectées ;
- `powershell.exe -NoProfile -ExecutionPolicy Bypass -File
  .\tests\ci\run.ps1` : réussi ; dépôt et 2 mutations T0013 ;
- `powershell.exe -NoProfile -ExecutionPolicy Bypass -File
  .\tests\backend\run.ps1` : réussi ; dépôt et 2 mutations T0012 ;
- `pnpm ci:check` : bloqué par l'environnement, car `pwsh` n'est pas dans le
  `PATH` du shell sandboxé ;
- `Get-Command pwsh.exe` : aucun résultat dans le `PATH` sandboxé ;
- contrôle du chemin `%LOCALAPPDATA%\Microsoft\WindowsApps\pwsh.exe` dans le
  bac à sable : accès refusé, donc aucune conclusion d'absence ;
- même exécutable avec accès autorisé : PowerShell `7.6.4` ;
- harnais T0017 et T0013 avec ce chemin PowerShell 7 explicite : réussis ;
- `git diff --check` : réussi ; avertissement LF/CRLF informatif sur le script
  T0013 existant.

### Manual verification result

Les huit catégories, leurs finalités, les durées et actions de fin de vie ont été
relues. Local, CI et staging interdisent les données de production. Les projets
staging/production sont explicitement non provisionnés.

Les statuts `Blocked` et `Not implemented` sont visibles dans la politique. Les
trois mutations prouvent l'échec sur catégorie absente, production autorisée en
staging et délai supérieur à 90 jours. Aucun secret, identifiant réel, dump,
payload ou donnée de vol n'est ajouté.

### Risks and limitations

- les maxima sont des garde-fous d'ingénierie, pas une validation juridique ni
  une base légale définitive ;
- export, suppression, purge, anonymisation, backup, restauration et replay des
  suppressions ne sont pas implémentés ;
- la FK T0012 bloque la suppression d'un propriétaire Auth et exige une migration
  append-only future ;
- aucun environnement Supabase distant ni plan de sauvegarde n'est configuré ou
  testé ;
- le gate statique ne prouve pas une purge ou une restauration réelle.

### Follow-ups

- créer le prochain ticket pour l'export et la suppression
  transactionnelle/idempotente du compte, avec migration append-only et tests
  A/B/anonyme ;
- provisionner séparément staging/production dans un ticket ultérieur, sans
  données réelles en staging ;
- configurer puis tester sauvegarde, restauration isolée et replay des
  suppressions avant admission de données réelles ;
- faire valider durées, finalités et notice par le responsable de traitement
  avant bêta fermée.

### Documentation updated

`DATA_POLICY`, index documentaire, `ARCHITECTURE`, `SECURITY`, `QUALITY`,
`SETUP`, `ROADMAP`, `CURRENT_STATE`, `KNOWN_ISSUES`, index des tickets et ce
Completion Report.

### Git and GitHub result

- branche : `docs/t0017-data-policy` ;
- base : `origin/main` à `99b87c3` au démarrage ;
- commit : en attente ;
- push : en attente ;
- Pull Request : en attente.
