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
3. Déterminer la branche `type/TXXXX-slug`, puis la créer ou y basculer après
   avoir préservé et signalé les changements préexistants. Si elle est déjà
   active, ne pas la recréer.
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
4. Traiter les candidats d'apprentissage selon `LEARNINGS.md`, sans dépasser les
   zones autorisées du ticket.
5. Mettre à jour une ADR seulement par une nouvelle ADR qui la remplace.
6. Préparer le handoff Git avec les fichiers exacts du ticket.
7. Vérifier le diff indexé, committer, pousser et ouvrir ou mettre à jour la PR.
8. Faire relire la PR à Andy ; lui seul peut décider et effectuer le merge.
9. Choisir le prochain ticket Ready.

## Boucle d'apprentissage

L'apprentissage du dépôt porte sur des faits observables, jamais sur une mémoire
implicite de l'agent. Une difficulté rencontrée pendant un ticket suit cette
boucle :

1. **Capturer** : décrire le symptôme, le contexte, la conclusion erronée à
   éviter et les diagnostics non destructifs exécutés.
2. **Qualifier** : séparer `Observed`, `Reproduced`, `Codified`, `Enforced` et
   `Stale` selon les définitions de `LEARNINGS.md`.
3. **Reproduire** : chercher un second contexte indépendant ou une reproduction
   déterministe, avec au moins un contre-exemple lorsque cela apporte une preuve.
4. **Classer** : choisir la destination la plus étroite : Completion Report,
   `KNOWN_ISSUES.md`, document spécialisé, script/test, puis seulement
   `AGENTS.md` pour un invariant global.
5. **Promouvoir** : relire la preuve, la portée, les risques et la date de
   revalidation. Une promotion ne permet jamais de contourner `Allowed areas`.
6. **Automatiser** : lorsqu'un contrôle déterministe est possible, créer un
   ticket borné pour le script ou le test au lieu de conserver durablement une
   consigne manuelle.
7. **Revalider** : lors de la date prévue ou d'un changement de version,
   confirmer, remplacer ou marquer `Stale` sans effacer l'historique.

La capture d'une première occurrence est immédiate. La promotion exige deux
occurrences indépendantes ou une reproduction déterministe. Une exception est
admise pour un risque élevé de sécurité, de perte de données ou de faux succès :
une occurrence reproductible peut alors être promue après revue explicite.

Un candidat n'est pas un problème connu par défaut. Il rejoint
`KNOWN_ISSUES.md` seulement s'il décrit un défaut réel hors périmètre nécessitant
un suivi produit ou technique.

## Handoff Git de fin de ticket

Codex termine chaque ticket avec des commandes adaptées à l'état réel du dépôt.
Après revue du diff indexé, il exécute de manière autonome le commit, le push et
la création ou mise à jour de la Pull Request. Il annonce la branche, le remote,
la base réelle de la PR et le message de commit exacts. Il ne doit jamais
proposer ni exécuter une commande globale qui embarquerait des changements sans
rapport.

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

Codex inclut les résultats du commit, du push et de la Pull Request dans le
rapport final. Seule la fusion exige une confirmation explicite d'Andy et ne doit
jamais être exécutée par l'agent.

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

Enregistrer une première observation sans attendre sa répétition. Modifier le
workflow uniquement après avoir satisfait les seuils de promotion de
`LEARNINGS.md`.
