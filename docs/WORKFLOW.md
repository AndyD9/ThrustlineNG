# Workflow de refonte

## Rôles

- **Andy — Product Owner** : tranche la vision, le périmètre et les compromis.
- **Agent planificateur** : analyse le dépôt, propose ADR, roadmap et tickets.
- **Codex implémenteur** : exécute un ticket borné et fournit les preuves.
- **Reviewer** : cherche régressions, failles, dérive architecturale et tests
  manquants avant validation.

Un même outil peut tenir plusieurs rôles, mais pas dans la même étape sans
effectuer une revue adversariale explicite.

## États d'un ticket

`Draft → Ready → In progress → Review → Verify → Done`

États alternatifs : `Blocked`, `Rejected`, `Superseded`.

## 1. Préparer la phase

1. Définir le résultat utilisateur.
2. Écrire/valider les ADR structurantes.
3. Identifier dépendances et risques.
4. Découper en vertical slices.
5. Créer seulement les 3–8 prochains tickets détaillés ; garder le reste au
   niveau roadmap pour éviter un plan périmé de 50 tickets.

## 2. Rendre un ticket Ready

Un ticket Ready contient :

- objectif unique ;
- dépendances satisfaites ;
- zones autorisées et interdites ;
- exigences et non-objectifs ;
- critères d'acceptation observables ;
- tests attendus ;
- vérification manuelle de 5–10 minutes ;
- revue sécurité si nécessaire.

Le reviewer challenge le ticket avant tout code : trop large, ambigu, mauvaise
frontière ou absence de preuve = retour en Draft.

## 3. Implémenter

1. Lire `AGENTS.md`, `CURRENT_STATE.md`, le ticket et les docs liées.
2. Vérifier l'état Git et préserver les changements existants.
3. Déterminer la branche `type/TXXXX-slug`, puis demander à Andy une confirmation
   explicite avant de la créer ou d'y basculer. Si elle est déjà active, le
   signaler sans la recréer.
4. Inspecter le code réel.
5. Implémenter seulement le ticket.
6. Exécuter d'abord les tests ciblés, puis les gates applicables.
7. Ne pas corriger les découvertes hors scope ; les consigner.

Types de branche : `foundation`, `feature`, `fix`, `security`, `refactor`, `docs`.

## 4. Revoir

La revue vérifie dans cet ordre :

1. sécurité et perte de données ;
2. conformité aux critères ;
3. régressions et compatibilité ;
4. architecture et dette créée ;
5. tests et observabilité ;
6. lisibilité et performance.

Une revue ne doit pas demander une réécriture esthétique sans bénéfice mesurable.

## 5. Vérifier

Effectuer la checklist manuelle du ticket. Si elle échoue, le ticket revient en
`In progress`. Si elle est impossible localement, indiquer précisément qui doit
la faire et sur quel environnement ; le ticket reste `Verify`.

## 6. Clore

1. Remplir le Completion Report dans le ticket.
2. Actualiser `CURRENT_STATE.md` si l'état réel a changé.
3. Ajouter les problèmes différés dans `KNOWN_ISSUES.md`.
4. Mettre à jour une ADR seulement par une nouvelle ADR qui la remplace.
5. Préparer le handoff Git avec les fichiers exacts du ticket.
6. Faire relire à Andy le diff indexé avant commit.
7. Fusionner après checks et revue.
8. Choisir le prochain ticket Ready.

## Handoff Git de fin de ticket

Codex doit terminer chaque ticket par des commandes adaptées à l'état réel du
dépôt. Après revue du diff indexé, il peut proposer d'exécuter le commit et le
push, mais doit obtenir la confirmation explicite d'Andy immédiatement avant
ces actions et annoncer la branche, le remote et le message de commit exacts.
L'accord donné pour créer la branche au début du ticket ne vaut pas accord pour
la publier. Il ne doit jamais proposer une commande globale qui embarquerait des
changements sans rapport.

Exemple de structure à adapter :

```powershell
# À exécuter dans PowerShell Windows
Set-Location C:\Users\andyd\Documents\Thrustline

# 1. Vérifier la branche et les changements
git branch --show-current
git status --short

# 2. Ajouter uniquement les fichiers du ticket
git add -- path/to/file-a path/to/file-b

# 3. Relire exactement ce qui sera committé
git diff --cached --check
git diff --cached --stat
git diff --cached

# 4. Créer le commit
git commit -m "type(scope): description du ticket"

# 5. Publier la branche
git push -u origin nom-reel-de-la-branche

# 6. Ouvrir la PR si GitHub CLI est configuré
gh pr create --base branche-cible --head nom-reel-de-la-branche `
  --title "TXXXX — Titre" `
  --body-file docs/tickets/TXXXX-ticket.md
```

Avant de fournir ce bloc, Codex doit remplacer tous les exemples par les valeurs
réelles. S'il existe des fichiers modifiés hors ticket, il doit les lister
séparément et confirmer qu'ils ne figurent pas dans `git add`.

Si Andy confirme la publication, Codex peut exécuter les commandes de commit et
de push correspondantes, puis inclure leur résultat dans le rapport final. Toute
création de PR ou fusion exige une confirmation distincte.

Si GitHub demande un mot de passe HTTPS, ne pas utiliser le mot de passe du
compte. Configurer GitHub CLI depuis PowerShell :

```powershell
gh auth login
gh auth setup-git
```

Pour éviter les erreurs `chmod ... .git/config.lock`, ne pas utiliser Git WSL
sur ce dépôt stocké sous `C:\Users\...`.

## Limites de taille

Un bon ticket :

- vise un résultat ;
- modifie idéalement une frontière principale ;
- produit un diff révisable ;
- se vérifie manuellement en 5–10 minutes ;
- peut être abandonné sans invalider plusieurs jours de travail.

Si le ticket combine migration, nouveau protocole, gros écran et pipeline release,
le diviser.

## Commande de démarrage recommandée

```text
Implémente uniquement le ticket TXXXX.

Lis AGENTS.md, docs/CURRENT_STATE.md et le ticket complet.
Respecte Allowed areas et Do not touch.
Avant de coder, signale toute contradiction bloquante.
Après le changement, exécute les validations du ticket et remplis son
Completion Report avec preuves, risques et follow-ups.
```

## Rétrospective

À la fin de chaque phase :

- quelles règles ont évité une erreur ?
- quels tickets étaient trop grands ou ambigus ?
- quels contrôles manquaient ?
- quels documents ont dérivé ?
- quelle automatisation répétée mérite un script ou une skill ?

Modifier le workflow uniquement sur la base d'un problème répété.
