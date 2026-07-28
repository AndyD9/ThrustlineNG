# T0004 — Définir la matrice de support Windows et MSFS

Status: Done
Owner: Andy
Branch: `docs/t0004-matrice-support`
Phase: 0
Risk: High
Security-sensitive: No

## Goal

Définir les plateformes officiellement supportées par la nouvelle version de
Thrustline et la manière de prouver leur compatibilité.

Le résultat doit fixer :

- les versions et architectures Windows ;
- les versions de Microsoft Flight Simulator ;
- les canaux d'installation MSFS concernés ;
- les prérequis système et runtimes ;
- les configurations minimales, recommandées et de test ;
- les niveaux de support ;
- le protocole de validation SimConnect ;
- la politique lorsqu'une mise à jour Windows ou MSFS casse la compatibilité.

La décision sera enregistrée dans
`docs/decisions/ADR-0003-matrice-support-windows-msfs.md` et résumée dans
`docs/SUPPORT.md`.

## Context

ADR-0002 retient une réécriture totale isolée dans un nouveau dépôt, avec un
nouveau backend et aucune migration des données de développement actuelles.

Avant de sélectionner les versions de Tauri, .NET, Rust, Node et des bibliothèques
SimConnect, il faut savoir quelles plateformes la refonte doit réellement
supporter. Annoncer « Windows et MSFS » ne suffit pas :

- les versions Windows n'ont pas la même durée de support ;
- MSFS 2020 et MSFS 2024 peuvent exposer des comportements SimConnect différents ;
- les éditions Microsoft Store/Xbox App et Steam peuvent installer les composants
  et données dans des emplacements différents ;
- x64 et ARM64 n'ont pas les mêmes contraintes ;
- WebView2, SimConnect et l'installateur ont leurs propres prérequis ;
- les mises à jour du simulateur peuvent provoquer des régressions indépendantes
  de Thrustline.

La baseline T0001 ne contient ni replay SimConnect automatisé ni validation réelle
avec MSFS. T0004 définit donc aussi le minimum de preuve nécessaire pour déclarer
une combinaison « supportée ».

## Research requirement

L'exécution de ce ticket nécessite une recherche web actualisée à la date du
ticket. Utiliser en priorité les sources officielles :

- Microsoft Lifecycle et documentation Windows ;
- documentation officielle MSFS/SimConnect ;
- documentation Microsoft Store/Xbox App et Steam lorsque pertinente ;
- documentation officielle Tauri, WebView2 et .NET ;
- notes de version et exigences système officielles.

Pour chaque fait susceptible de changer, conserver :

- URL directe ;
- titre de la source ;
- date de consultation ;
- version/date publiée si disponible ;
- distinction entre fait officiel et inférence.

Ne pas utiliser un article communautaire comme seule preuve d'une compatibilité.

## Inputs required from Andy

1. Possèdes-tu MSFS 2020, MSFS 2024 ou les deux ?
2. Les utilises-tu via Microsoft Store/Xbox App, Steam ou plusieurs canaux ?
3. Souhaites-tu officiellement supporter Windows 10 malgré sa situation de
   support en 2026, ou cibler Windows 11 uniquement ?
4. Veux-tu supporter Windows ARM64 ou seulement x64 ?
5. Quelles machines réelles sont disponibles pour les tests ?
6. Acceptes-tu qu'une combinaison soit `Experimental` tant qu'aucun testeur ne
   peut la valider ?
7. Thrustline doit-il fonctionner lorsque MSFS est installé via un autre compte
   Windows ou uniquement dans la session utilisateur courante ?
8. Le support des versions bêta/Insider de Windows ou MSFS est-il exclu ?
9. Quelle durée maximale après une mise à jour MSFS est acceptable avant
   confirmation de compatibilité ?
10. Souhaites-tu bloquer le lancement sur une plateforme non supportée ou afficher
    seulement un avertissement ?

Une combinaison ne peut pas être déclarée officiellement supportée sans moyen
réaliste de la tester.

### Answers received on 2026-07-24

1. MSFS 2024 uniquement.
2. Microsoft Store/Xbox App et Steam.
3. Windows 11 uniquement.
4. x64 uniquement.
5. Une machine : Ryzen 7 5800X, 32 Go de RAM et GPU déclaré `RX 6070 XT`
   (modèle exact, build Windows, écran/DPI et installations à confirmer).
6. Aucun classement `Experimental` accepté en attente d'un testeur.
7. Oui au fonctionnement lorsque le compte d'installation/achat diffère, sous
   réserve que MSFS et SimConnect soient accessibles normalement dans la session
   courante sans contournement des permissions.
8. Windows Insider, MSFS Beta et Sim Update Preview exclus.
9. Aucun engagement de délai après une mise à jour MSFS.
10. Lancement autorisé avec avertissement ; blocage réservé à un risque réel de
    corruption ou de sécurité. Confirmé par Andy le 24 juillet 2026.

## Dependencies

- T0001 terminé.
- T0002 terminé.
- T0003 terminé.
- `docs/decisions/ADR-0001-modele-produit.md`
- `docs/decisions/ADR-0002-strategie-de-refonte.md`
- `docs/CURRENT_STATE.md`
- `docs/PRODUCT.md`
- `docs/ARCHITECTURE.md`
- `docs/QUALITY.md`

## Allowed areas

- `docs/SUPPORT.md`
- `docs/PRODUCT.md`
- `docs/ARCHITECTURE.md`
- `docs/QUALITY.md`
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
- scripts, manifests, lockfiles et dépendances
- installation Windows ou MSFS de la machine
- registre Windows et fichiers du simulateur
- modification utilisateur existante dans `app/src-tauri/Cargo.toml`

## Requirements

### 1. Définir les niveaux de support

Utiliser quatre niveaux explicites :

- **Supported** : combinaison couverte par CI lorsque possible, test manuel réel,
  documentation et support des incidents ;
- **Compatible** : test concluant, mais pas de garantie à chaque release ;
- **Experimental** : devrait fonctionner, couverture insuffisante et aucune
  garantie ;
- **Unsupported** : volontairement exclue ou incompatible.

Une plateforme non testée ne peut pas être classée `Supported`.

### 2. Construire la matrice Windows

Pour chaque combinaison pertinente :

| Windows | Édition/build | Architecture | Niveau | Preuve | Fréquence de test |
| --- | --- | --- | --- | --- | --- |

Analyser au minimum :

- Windows 11 x64 sur les versions encore supportées par Microsoft ;
- Windows 10 x64 si Andy souhaite le conserver ;
- Windows ARM64 si envisagé ;
- versions Insider/Preview ;
- installation standard sans privilèges administrateur permanents.

Documenter :

- politique de fin de support ;
- WebView2 Evergreen ou runtime embarqué ;
- prérequis Visual C++/Windows App SDK si nécessaires ;
- emplacement des données utilisateur ;
- règles installateur, update et désinstallation.

### 3. Construire la matrice MSFS

Pour chaque combinaison pertinente :

| Simulateur | Canal | Version/build | Niveau | SimConnect testé | Dernier test |
| --- | --- | --- | --- | --- | --- |

Analyser au minimum :

- Microsoft Flight Simulator 2020 ;
- Microsoft Flight Simulator 2024 ;
- Microsoft Store/Xbox App ;
- Steam ;
- versions publiques stables ;
- versions bêta/Sim Update Preview si elles existent.

Ne pas promettre Xbox console : Thrustline est une application desktop Windows et
nécessite un accès local à SimConnect.

### 4. Définir la matrice matérielle

Créer trois profils :

- **Minimum supporté** : machine la plus faible sur laquelle la stabilité est
  vérifiée ;
- **Recommandé** : expérience normale ;
- **CI/test sans MSFS** : machine permettant builds et replays.

Pour chaque profil, préciser :

- CPU et architecture ;
- RAM ;
- espace disque ;
- version Windows ;
- disponibilité WebView2 ;
- réseau ;
- écran/DPI ;
- présence ou absence de MSFS.

Les exigences matérielles de MSFS ne doivent pas être présentées comme celles de
Thrustline. Séparer clairement les deux.

### 5. Définir le protocole SimConnect

Le protocole doit couvrir :

1. MSFS fermé au lancement ;
2. MSFS lancé avant et après Thrustline ;
3. connexion, déconnexion et reconnexion ;
4. menu principal, chargement et vol actif ;
5. cold-and-dark, taxi, décollage, croisière et atterrissage ;
6. go-around et touch-and-go ;
7. pause, active pause et accélération temporelle ;
8. slew/téléportation ;
9. retour au menu et changement d'appareil ;
10. crash MSFS ou fermeture forcée ;
11. perte réseau sans perte de connexion locale ;
12. vol long et consommation mémoire ;
13. avions natifs et au moins un add-on représentatif ;
14. absence ou corruption d'une variable SimConnect attendue.

Pour chaque scénario, définir :

- état initial ;
- action ;
- événements attendus ;
- comportement dégradé ;
- logs autorisés ;
- critère de réussite ;
- trace de replay à conserver.

### 6. Définir le système de preuves

Chaque ligne `Supported` doit référencer une fiche de validation indiquant :

- version exacte de Thrustline ;
- commit ;
- Windows/build ;
- MSFS/build et canal ;
- appareil utilisé ;
- scénario exécuté ;
- résultat ;
- date ;
- testeur ;
- anomalies liées.

Prévoir un emplacement futur tel que `docs/validation/platforms/`, sans créer des
dizaines de fiches vides dans ce ticket.

### 7. Définir la politique après mise à jour

Pour Windows, MSFS et SimConnect :

- détecter ou relever la version active ;
- passer temporairement une combinaison en `Compatibility pending` si nécessaire ;
- exécuter smoke tests et golden path ;
- communiquer les limitations connues ;
- définir qui peut rétablir le statut `Supported` ;
- ne jamais bloquer arbitrairement une version sans mécanisme de récupération ;
- prévoir un kill switch seulement pour un risque réel de corruption/sécurité.

### 8. Propager la décision

Après validation :

- créer `docs/decisions/ADR-0003-matrice-support-windows-msfs.md` ;
- créer `docs/SUPPORT.md` avec la matrice lisible par les utilisateurs ;
- mettre `PRODUCT.md`, `ARCHITECTURE.md` et `QUALITY.md` en cohérence ;
- adapter les gates de `ROADMAP.md` ;
- consigner les combinaisons non testables dans `KNOWN_ISSUES.md` ;
- actualiser `CURRENT_STATE.md` et le prochain ticket.

## Non-goals

- Installer ou désinstaller Windows/MSFS.
- Tester réellement toutes les combinaisons dans ce ticket documentaire.
- Choisir toutes les versions de la stack technique.
- Mettre à niveau Tauri, .NET, Rust, Node ou SimConnect.NET.
- Implémenter la détection de version.
- Créer le moteur de replay SimConnect.
- Construire l'installateur.
- Promettre le support d'une plateforme sans preuve.

## Acceptance criteria

- [x] Les dix questions d'Andy sont résolues ou le ticket est `Blocked`.
- [x] Les sources officielles sont datées et liées.
- [x] Windows, architecture CPU et cycle de support sont explicitement décidés.
- [x] MSFS 2020/2024 et Store/Steam ont chacun un niveau de support.
- [x] Les versions Preview/Insider ont une politique explicite.
- [x] Les profils matériel minimum, recommandé et CI sont définis.
- [x] Les quatorze scénarios SimConnect possèdent des critères de réussite.
- [x] Chaque niveau `Supported` a une preuve réalisable.
- [x] La politique après mise à jour Windows/MSFS est définie.
- [x] `ADR-0003` est acceptée.
- [x] `docs/SUPPORT.md` est compréhensible sans lire l'ADR.
- [x] Aucun fichier applicatif, workflow, manifeste ou dépendance n'est modifié.
- [x] Le prochain ticket recommandé est identifié.

## Security review

Ce ticket ne modifie aucun contrôle de sécurité, mais la matrice doit préserver :

- aucune exécution permanente en administrateur ;
- aucune désactivation de TLS, antivirus ou protection Windows ;
- bridge limité à la session locale ;
- données utilisateur hors du dossier d'installation ;
- installateur et updates signés ;
- diagnostics sans secret ni donnée personnelle ;
- aucune modification des fichiers MSFS sans consentement explicite.

Une plateforme nécessitant d'affaiblir ces contrôles doit être classée
`Unsupported`.

## Automated validation

Ticket documentaire : aucun build applicatif requis.

```powershell
# Vérifier les livrables
Test-Path docs/SUPPORT.md
Test-Path docs/decisions/ADR-0003-matrice-support-windows-msfs.md

# Vérifier que les catégories principales sont présentes
rg -n "Supported|Compatible|Experimental|Unsupported|Windows 11|MSFS 2020|MSFS 2024|SimConnect" `
  docs/SUPPORT.md docs/decisions/ADR-0003-matrice-support-windows-msfs.md

# Examiner la portée réelle du ticket
git diff --name-only
```

La validité des sources et des choix reste une revue humaine obligatoire.

## Manual verification

1. Choisir une combinaison Windows/MSFS réelle.
2. Trouver immédiatement son niveau de support dans `docs/SUPPORT.md`.
3. Identifier le scénario de test et la preuve nécessaires.
4. Simuler une mise à jour MSFS non encore testée.
5. Vérifier que la politique indique clairement ce qui reste utilisable.
6. Vérifier qu'aucune combinaison non testable n'est annoncée comme supportée.

Temps cible : 10–15 minutes.

## Rollback

Une nouvelle ADR peut remplacer ADR-0003 lorsque Microsoft modifie ses cycles de
support ou que de nouvelles preuves deviennent disponibles. Conserver l'historique
des matrices pour savoir quelles versions de Thrustline supportaient quelles
plateformes.

## Completion Report

ADR-0003 acceptée explicitement par Andy le 24 juillet 2026.

### Summary

Proposition de matrice Windows 11 x64/MSFS 2024 rédigée, avec Store et Steam
comme cibles distinctes. Aucun niveau `Supported` n'est attribué sans test réel.

### Supported platform decision

Accepté : Windows 11 x64 public et maintenu ; MSFS 2024 stable Store et Steam.
Windows 10, ARM64, MSFS 2020, Insider/Preview, consoles et cloud sont exclus.
Les cibles non encore testées restent `Unsupported — validation requise` puisque
le niveau `Experimental` est refusé.

### Official sources consulted

Microsoft Lifecycle/Windows release health, documentation officielle
MSFS 2024/SimConnect et release notes, Microsoft WebView2/.NET/Visual C++, Tauri
v2 et fiche officielle Steam. URLs, dates et distinction fait/inférence sont
conservées dans ADR-0003.

### Validation coverage and gaps

Aucun test MSFS réel n'a été exécuté. La version/build Windows, les deux
installations Store/Steam, le modèle exact du GPU et l'écran/DPI ne sont pas
confirmés. Les profils minimum et CI restent à mesurer.

### Files changed

- `docs/decisions/ADR-0003-matrice-support-windows-msfs.md`
- `docs/SUPPORT.md`
- `docs/PRODUCT.md`
- `docs/ARCHITECTURE.md`
- `docs/QUALITY.md`
- `docs/ROADMAP.md`
- `docs/CURRENT_STATE.md`
- `docs/tickets/T0004-matrice-support-windows-msfs.md`
- `docs/tickets/README.md`
- `docs/KNOWN_ISSUES.md`

### Commands and results

- Lecture des sources de vérité et des deux ADR précédentes : réussie.
- Recherche web officielle datée du 24 juillet 2026 : réussie.
- `Test-Path` des deux livrables : réussi.
- `rg` des niveaux, plateformes et SimConnect : réussi.
- Comptage des scénarios : 14 lignes.
- `git diff --check` : réussi.
- Contrôle de portée `app/`, `sim-bridge/`, `supabase/`, `legacy/`, `.github/`
  et `scripts/` : aucune modification.
- Aucun build applicatif requis ou exécuté.

### Manual verification result

Réussie sur documentation : une combinaison se retrouve immédiatement dans
`SUPPORT.md`, son niveau et sa preuve sont explicites, et une mise à jour MSFS
place une ligne supportée en `Compatibility pending`. Aucun test MSFS réel n'a
été exécuté, conformément au non-goal.

### Risks and limitations

Une seule machine, aucune preuve distincte Store/Steam et minimum matériel non
mesuré. Les deux canaux restent donc `Unsupported — validation requise`.

### Follow-ups

Tester chaque canal, créer les fiches de preuve et implémenter le replay lors du
vertical slice SimConnect. Mesurer les budgets et le minimum dans T0005.

### Documentation updated

ADR-0003, SUPPORT, PRODUCT, ARCHITECTURE, QUALITY, ROADMAP, CURRENT_STATE,
KNOWN_ISSUES et l'index des tickets sont cohérents.

### Git handoff

Branche constatée : `docs/t0003-strategie-refonte`, upstream
`origin/docs/t0003-strategie-refonte`, cible distante par défaut `origin/main`.

Le handoff de publication est bloqué : `docs/CURRENT_STATE.md` et
`docs/tickets/README.md` contenaient déjà des changements T0003 avant T0004.
`AGENTS.md`, `CONTRIBUTING.md`, `docs/WORKFLOW.md` et
`docs/templates/TICKET.md` sont également modifiés hors ticket. Un `git add --`
des fichiers partagés inclurait silencieusement du travail préexistant, ce qui
est interdit. Finaliser/committer T0003 ou isoler ses changements avant de
construire le bloc de publication T0004.

À remplir avec la branche constatée, les fichiers exacts du ticket, les
modifications hors ticket à préserver, le message de commit et les commandes
PowerShell de vérification, commit, push et création de PR. Ne jamais utiliser
`git add .`.
