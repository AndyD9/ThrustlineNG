# T0002 — Choisir le modèle produit solo ou collaboratif

Status: Done
Owner: Andy
Branch: `docs/t0002-modele-produit`
Phase: 0
Risk: High
Security-sensitive: Yes

## Goal

Décider si la refonte de Thrustline cible :

1. un produit **solo connecté**, où un utilisateur possède et gère sa compagnie ;
2. une **VA collaborative**, où plusieurs utilisateurs partagent une compagnie
   avec des rôles et responsabilités ;
3. un **socle solo préparé pour une extension collaborative ultérieure**, sans
   livrer de collaboration dans le MVP.

La décision doit être consignée dans une ADR acceptée et donner une direction
non ambiguë aux tickets d'architecture et de sélection de stack suivants.

## Context

L'application actuelle est principalement conçue autour d'un utilisateur et de
sa compagnie, mais l'expression « gestion de compagnie virtuelle » peut aussi
désigner une VA avec propriétaire, administrateurs, dispatchers et pilotes.

Ce choix modifie fortement :

- le périmètre du MVP ;
- le modèle de données et la propriété des ressources ;
- l'authentification et les autorisations ;
- les politiques RLS Supabase ;
- le niveau d'audit et de concurrence ;
- l'UX d'onboarding et d'administration ;
- les coûts de développement, de support et d'hébergement.

La baseline T0001 est terminée. Aucun schéma cible ni nouveau socle ne doit être
figé avant cette décision.

## Inputs required from Andy

Le ticket doit obtenir des réponses explicites aux questions suivantes :

1. Une compagnie doit-elle pouvoir avoir plusieurs humains membres dès le MVP ?
2. Un pilote peut-il appartenir à plusieurs compagnies ?
3. Les rôles propriétaire, administrateur, dispatcher et pilote sont-ils utiles
   dès la première version publique ?
4. Un pilote doit-il pouvoir effectuer un vol préparé par un autre membre ?
5. Les finances, la flotte et les horaires doivent-ils être partagés en temps réel ?
6. Faut-il inviter, exclure, suspendre et transférer la propriété d'une compagnie ?
7. Le produit doit-il permettre de jouer entièrement seul sans gérer de membres ?
8. Une future collaboration est-elle un objectif certain, probable ou simplement
   possible ?
9. Quel surcoût et quel délai sont acceptables avant la première bêta ?
10. En cas de conflit, la stabilité du mode solo ou la collaboration doit-elle
    être prioritaire ?

Si une réponse essentielle manque, l'ADR reste `Proposed` et le ticket passe en
`Blocked` plutôt que d'inventer une préférence.

## Dependencies

- T0001 terminé.
- `docs/PRODUCT.md`
- `docs/ARCHITECTURE.md`
- `docs/SECURITY.md`
- `docs/CURRENT_STATE.md`

## Allowed areas

- `docs/PRODUCT.md`
- `docs/ARCHITECTURE.md`
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
- manifests, lockfiles et dépendances
- workflows CI
- secrets ou configuration locale
- modification utilisateur existante dans `app/src-tauri/Cargo.toml`

## Requirements

### 1. Décrire les trois options

Pour chaque option, documenter :

- utilisateur et parcours principal ;
- périmètre MVP ;
- fonctionnalités obligatoires ;
- modèle de propriété des compagnies et ressources ;
- rôles et permissions ;
- impact sur le schéma et la RLS ;
- impact UX ;
- besoins d'audit, notifications et concurrence ;
- complexité de test et d'exploitation ;
- risques de sécurité et de perte de données ;
- coût relatif et effet sur le délai de bêta ;
- facilité ou difficulté de migration vers une autre option.

### 2. Produire une matrice de décision

Noter chaque option de 1 à 5 avec une justification pour :

- adéquation à la vision d'Andy ;
- rapidité jusqu'à une bêta stable ;
- simplicité et fiabilité ;
- sécurité et maîtrise des permissions ;
- expérience solo ;
- potentiel communautaire ;
- coût d'hébergement et de support ;
- capacité d'évolution.

Les poids des critères doivent être validés par Andy avant le score final.
La matrice aide à décider ; elle ne remplace pas la décision humaine.

### 3. Définir précisément le modèle retenu

L'ADR doit fixer au minimum :

- cardinalité utilisateur ↔ compagnie ;
- ownership d'une compagnie ;
- rôles disponibles dans le MVP ;
- permissions de chaque rôle ;
- appartenance éventuelle à plusieurs compagnies ;
- invitations et transfert de propriété ;
- visibilité des vols, finances et flotte ;
- comportement lorsque le propriétaire quitte le service ;
- éléments explicitement reportés après le MVP ;
- chemin de migration si la collaboration est différée.

### 4. Propager la décision

Après acceptation :

- créer `docs/decisions/ADR-0001-modele-produit.md` ;
- mettre `docs/PRODUCT.md` en cohérence ;
- ajuster les frontières pertinentes dans `docs/ARCHITECTURE.md` ;
- adapter les phases concernées dans `docs/ROADMAP.md` ;
- résoudre ou mettre à jour `KI-007` dans `docs/KNOWN_ISSUES.md` ;
- actualiser le prochain ticket dans `docs/CURRENT_STATE.md`.

## Non-goals

- Implémenter comptes, compagnies, invitations ou rôles.
- Modifier le schéma Supabase ou les politiques RLS.
- Choisir les versions de la stack.
- Choisir la stratégie technique complète de refonte.
- Concevoir tous les écrans.
- Établir une tarification commerciale.
- Ajouter partiellement du multi-utilisateur « pour plus tard ».

## Acceptance criteria

- [x] Les dix questions produit ont reçu une réponse explicite ou sont marquées
      comme bloquantes.
- [x] Les trois options sont comparées selon les mêmes critères.
- [x] Les poids de la matrice sont approuvés par Andy.
- [x] L'option retenue est formulée en une phrase sans ambiguïté.
- [x] Les cardinalités, rôles, permissions et reports après MVP sont définis.
- [x] Les principaux abus et risques de chaque option sont décrits.
- [x] `ADR-0001` est `Accepted` et indique qui a pris la décision.
- [x] `PRODUCT.md`, `ARCHITECTURE.md` et `ROADMAP.md` ne se contredisent plus.
- [x] Aucun fichier applicatif, migration ou dépendance n'est modifié.
- [x] Le prochain ticket recommandé est identifié.

## Security review

### Assets and data

- comptes utilisateurs ;
- propriété de la compagnie ;
- flotte, finances, horaires et rapports de vol ;
- rôles, invitations et journal d'audit ;
- données potentiellement visibles entre membres.

### Trust boundaries

- desktop public vers Supabase ;
- membre d'une compagnie vers les ressources partagées ;
- administrateur/dispatcher vers les pilotes ;
- utilisateur appartenant éventuellement à plusieurs compagnies.

### Abuse cases to compare

- un membre lit ou modifie une autre compagnie ;
- élévation de rôle côté client ;
- invitation ou transfert de propriété forgé ;
- ancien membre conservant un accès ;
- deux responsables modifiant simultanément une ressource ;
- propriétaire supprimé laissant une compagnie orpheline ;
- fraude sur les vols, finances ou récompenses partagées ;
- exposition excessive des données de vol ou d'identité.

### Required controls in the selected model

- identité et permissions vérifiées côté serveur ;
- RLS fondée sur une appartenance serveur, jamais un rôle client ;
- moindre privilège ;
- révocation immédiate des accès ;
- opérations sensibles transactionnelles et auditées ;
- règles explicites de concurrence et transfert de propriété ;
- tests utilisateur A/utilisateur B/ancien membre.

## Automated validation

Ticket documentaire : aucun build applicatif requis.

```powershell
# Vérifier que l'ADR et les documents attendus existent
Test-Path docs/decisions/ADR-0001-modele-produit.md

# Vérifier qu'aucun fichier applicatif n'a été modifié par ce ticket
git diff --name-only

# Vérifier les références à la décision produit
rg -n "solo|collaboratif|collaboration|multi-utilisateur|rôle" `
  docs/PRODUCT.md docs/ARCHITECTURE.md docs/ROADMAP.md `
  docs/decisions/ADR-0001-modele-produit.md
```

La revue humaine de cohérence reste obligatoire.

## Manual verification

1. Lire uniquement la section `Decision` de l'ADR et reformuler le modèle retenu.
2. Vérifier que cette reformulation correspond à l'intention d'Andy.
3. Contrôler un exemple concret :
   - qui crée la compagnie ;
   - qui peut voir les finances ;
   - qui prépare et effectue un vol ;
   - qui peut acheter ou vendre un avion.
4. Vérifier que le MVP n'inclut aucun rôle ou parcours marqué comme différé.
5. Vérifier que l'architecture cible peut appliquer les permissions sans faire
   confiance au client.

Temps cible : 10 minutes.

## Rollback

Tant qu'aucun code ou schéma ne dépend de l'ADR, la remplacer par une nouvelle ADR
qui la marque `Superseded`. Ne pas réécrire silencieusement une décision acceptée.

## Completion Report

À remplir après décision.

### Product answers recorded

Réponses initiales d'Andy, puis clarification du 24 juillet 2026 :

1. Plusieurs humains dès le MVP : réponse initiale oui, remplacée après
   clarification par **non** ; choix final de l'option solo préparée.
2. Appartenance à plusieurs compagnies : non.
3. Rôles initiaux : propriétaire uniquement.
4. Vol préparé par un autre membre : réponse initiale oui, reportée après le MVP
   par le choix final strictement solo.
5. Données partagées en temps réel : réponse initiale oui, reportée après le MVP.
6. Invitation, exclusion, suspension et transfert dans le MVP : non.
7. Jeu entièrement solo : oui.
8. Collaboration future : probable.
9. Surcoût maximal déclaré avant bêta : aucune limite imposée.
10. Priorité en cas de conflit : stabilité.
11. Nombre de compagnies possédées : une pour le moment.
12. Visibilité collaborative future envisagée : tous les membres.
13. Départ du propriétaire : suppression après un délai.
14. Aucun parcours de membre dans le MVP : oui.
15. Préparer le modèle interne pour une migration future : oui.
16. Poids proposés pour la matrice : approuvés.

La durée de récupération/rétention après le départ du propriétaire est
explicitement renvoyée à un futur ticket. Les réponses initiales 1, 4 et 5
étaient incompatibles avec l'absence de membres ; Andy a tranché en faveur du
MVP solo préparé.

### Summary

Les trois modèles produit ont été comparés avec les poids approuvés par Andy.
ADR-0001 retient un MVP strictement solo dont le modèle persistant distingue la
compagnie de son propriétaire pour préparer une collaboration ultérieure.

### Decision selected

MVP solo connecté : un utilisateur possède au plus une compagnie, une compagnie
a un propriétaire humain unique et aucune fonctionnalité collaborative n'est
livrée. Une future collaboration nécessitera une nouvelle ADR.

### Files changed

- `docs/decisions/ADR-0001-modele-produit.md`
- `docs/PRODUCT.md`
- `docs/ARCHITECTURE.md`
- `docs/ROADMAP.md`
- `docs/KNOWN_ISSUES.md`
- `docs/CURRENT_STATE.md`
- `docs/tickets/README.md`
- `docs/tickets/T0002-modele-produit-solo-ou-collaboratif.md`

### Commands and results

- `Test-Path docs/decisions/ADR-0001-modele-produit.md` : réussi (`True`).
- Recherche des références produit avec `rg` : réussie.
- Contrôle du périmètre avec `git diff --name-only` et `git status --short` :
  uniquement documentation autorisée, y compris la nouvelle ADR.
- Revue de cohérence automatisée des termes structurants : réussie.
- Aucun build applicatif exécuté, conformément au ticket documentaire.

### Manual verification result

Réalisée le 24 juillet 2026 : la section `Decision` définit sans ambiguïté un
propriétaire unique. Lui seul voit les finances, prépare et effectue les vols,
et achète ou vend les avions. Aucun rôle ou parcours différé n'est inclus dans le
MVP. Les contrôles d'autorisation futurs restent côté serveur.

### Risks and limitations

- La durée de récupération et la rétention après suppression du propriétaire
  restent volontairement à définir dans un futur ticket de politique de données.
- La structure préparatoire devra être validée lors du ticket de schéma ; elle ne
  doit conférer aucun accès à un second humain.

### Follow-ups

- Affiner puis exécuter T0003, ADR de stratégie de refonte.
- Créer ultérieurement un ticket de politique de suppression, récupération et
  rétention des données.
- Toute collaboration future exige une nouvelle ADR.

### Documentation updated

`PRODUCT.md`, `ARCHITECTURE.md`, `ROADMAP.md`, `CURRENT_STATE.md`,
`KNOWN_ISSUES.md` et l'index des tickets ont été alignés sur ADR-0001.
