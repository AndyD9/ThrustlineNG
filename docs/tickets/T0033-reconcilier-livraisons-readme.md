# T0033 — Réconcilier les livraisons récentes et le README

Status: Review
Owner: Andy
Branch: `docs/T0033-reconcile-delivery-readme`
Phase: Gouvernance
Risk: Medium
Security-sensitive: No

## Goal

Aligner le suivi du dépôt et sa page d'accueil sur les capacités réellement
présentes dans `main` après les fusions T0027 à T0032, sans fermer T0032 ni
revendiquer une capacité non vérifiée.

## Context

`origin/main` contient désormais les implémentations et preuves de T0027 à T0031
ainsi que le cadrage `Draft` de T0032. Leurs documents décrivent encore les
branches empilées comme absentes de `main`, `CURRENT_STATE.md` compte cinq
migrations au lieu de six et le README affirme que le dépôt ne contient que les
versions d'outils et les scripts de préparation.

Les Completion Reports T0027 à T0031 consignent déjà leurs validations
automatisées et manuelles. La réconciliation ne réécrit pas ces preuves : elle
ajoute uniquement la preuve de livraison et ferme les tickets dont les critères
sont satisfaits.

## Workflow evidence

- 2 août 2026 — `Ready` : `origin/main` est synchronisé au commit `dc3584e` ;
  les commits d'implémentation T0027 à T0031 sont dans son ascendance et les
  rapports existants consignent les vérifications manuelles réussies.
- 2 août 2026 — `In progress` : branche
  `docs/T0033-reconcile-delivery-readme` créée depuis `main` propre et à jour.
- 2 août 2026 — revue de maintenance : la tentative de résoudre KI-022 fait
  échouer l'auto-test qui l'utilise comme fixture active ; l'entrée reste
  `Scheduled` vers T0034 et T0033 ne modifie pas le script hors périmètre.

## Dependencies

- T0027 à T0031 — implémentations, validations et vérifications manuelles
  terminées ;
- PR #51, #54 et fusions empilées #55–#57 — présentes dans `origin/main` ;
- T0032 — cadrage seulement, conservé en `Draft` jusqu'aux décisions d'Andy.

## Allowed areas

- `README.md` ;
- `docs/CURRENT_STATE.md` ;
- `docs/KNOWN_ISSUES.md` — état résiduel de KI-022 uniquement ;
- `docs/tickets/README.md` ;
- tickets T0027 à T0031 pour leur preuve de livraison et leur statut ;
- ticket T0032 pour corriger uniquement ses références de livraison ;
- ce ticket.

## Do not touch

- code applicatif, migrations, seeds, tests, scripts et workflows ;
- contenu historique des Completion Reports T0027 à T0031 ;
- statut, exigences ou décisions produit de T0032 ;
- roadmap, architecture, sécurité, politique de données ou toolchain ;
- données réelles, environnement distant et Pull Requests existantes.

## Requirements

- Prouver l'ascendance dans `origin/main` des commits T0027 à T0031.
- Passer T0027 à T0031 à `Done` seulement si livraison, critères automatisés et
  vérification manuelle sont déjà consignés.
- Mettre à jour l'index dans le même changement et conserver T0032 en `Draft`.
- Corriger `CURRENT_STATE.md` uniquement pour l'état réellement changé : six
  migrations, politique T0028 et achat T0029 présents dans `main`, garde-fou de
  maintenance actif et T0032 en attente de décisions.
- Remplacer le README obsolète par une vue d'ensemble concise : statut, stack,
  démarrage, validations, limites et documentation de référence.

## Non-goals

- implémenter la location T0032 ou choisir ses règles économiques ;
- modifier une capacité produit ou une frontière de confiance ;
- rejouer les validations PostgreSQL ou applicatives déjà consignées ;
- déclarer une release, un support MSFS réel ou l'admission de données réelles.

## Acceptance criteria

- [x] T0027 à T0031 portent une preuve datée de présence dans `main` et un statut
      cohérent avec l'index.
- [x] T0032 reste `Draft` avec ses décisions requises visibles.
- [x] `CURRENT_STATE.md` ne présente plus T0028/T0029 comme absents de `main`.
- [x] Le README décrit fidèlement le projet, son démarrage, ses gates et ses
      limites actuelles.
- [x] Le gate de maintenance, les contrôles documentaires et
      `git diff --check` réussissent sans changement applicatif.

## Security review

Non applicable : le ticket réconcilie uniquement des preuves et de la
documentation. Il ne modifie aucune autorité, donnée, commande ou exposition.

## Maintenance review

- dettes et problèmes connus applicables : incohérence documentaire détectée
  par comparaison entre `origin/main`, les tickets, `CURRENT_STATE.md` et le
  README ;
- dette créée ou aggravée : aucune attendue ;
- règle de sécurité ajoutée, modifiée ou à revalider : aucune ;
- contrôle manuel à automatiser : le gate couvre ticket/index mais pas encore
  les affirmations libres de `CURRENT_STATE.md` et du README ; son auto-test
  doit aussi être découplé d'une entrée KI active réelle ;
- risque résiduel : les statuts de support et les preuves externes restent
  volontairement inchangés.

## Automated validation

```powershell
pnpm.cmd maintenance:check
git diff --check
git diff --name-only origin/main...HEAD
```

## Manual verification

1. Comparer chaque commit T0027 à T0031 avec l'ascendance de `origin/main`.
2. Relire leurs critères et résultats de vérification manuelle.
3. Comparer les statuts des fichiers avec l'index.
4. Vérifier que README et `CURRENT_STATE.md` distinguent livré, non livré et
   bloqué par décision ou environnement.

Temps cible : 10 minutes.

## Rollback

Revenir uniquement sur les fichiers documentaires du ticket. Aucune donnée,
migration ou capacité applicative n'est modifiée.

## Completion Report

### Summary

T0027 à T0031 sont réconciliés avec leur présence prouvée dans `main` et passent
à `Done` sans altérer leurs preuves historiques. T0032 reste `Draft`. L'état
courant compte désormais six migrations et décrit T0028, T0029 et T0030 comme
livrés. Le README obsolète est remplacé par une vue fidèle de l'alpha, de sa
stack, de son démarrage, de ses gates et de ses limites.

### Files changed

- `README.md`, `docs/CURRENT_STATE.md` et `docs/KNOWN_ISSUES.md` ;
- index des tickets et tickets T0027 à T0033 ;
- aucun code, test, script, workflow, migration, seed, manifest ou lockfile.

### Commands and results

- `git fetch --prune origin` — réussi ; `origin/main` synchronisé à `dc3584e` ;
- tests d'ascendance `git merge-base --is-ancestor` pour `2ef9343`, `7584bcc`,
  `1ede937`, `909f494` et `581f698` — cinq codes 0 ;
- première exécution directe de `tests/maintenance/run.ps1` — échec utile après
  passage prématuré de KI-022 à `Resolved` : l'auto-test dépend de cette fixture
  active ; aucune preuve annoncée comme réussie ;
- après maintien de KI-022 en `Scheduled` vers T0034,
  `pnpm.cmd maintenance:check` — réussi : registre, index, marqueurs et huit
  mutations ;
- `git diff --check` — réussi, aucune erreur d'espacement ;
- recherche des anciennes affirmations dans README, état courant, index et
  T0032 — aucune affirmation active ne présente encore T0028/T0029 comme absents
  de `main` ; les mentions historiques restent dans les rapports datés.

### Manual verification result

Réussie le 2 août 2026 : les cinq commits d'implémentation sont ancêtres de
`origin/main`; chaque ticket T0027 à T0031 avait déjà ses critères cochés et sa
vérification manuelle réussie. Les statuts fichier/index concordent, T0032 reste
`Draft`, et la relecture du README et de `CURRENT_STATE.md` distingue capacité
livrée, absence d'endpoint, données réelles interdites et preuves MSFS/distantes
non exécutées.

### Risks and limitations

- T0033 ne rejoue pas PostgreSQL, les courses ou les tests applicatifs déjà
  consignés par T0027 à T0031 ; il prouve leur livraison et la cohérence
  documentaire ;
- KI-022 reste `Scheduled` car l'auto-test du gate utilise une entrée réelle
  active comme fixture ; le gate passe, mais la dette de couplage subsiste ;
- T0032 ne peut pas entrer en `Ready` sans les décisions produit d'Andy ;
- aucune donnée réelle, plateforme MSFS, Supabase distante, signature ou release
  n'est validée.

### Follow-ups

- T0034 : découpler la fixture du gate de maintenance de KI-022, puis résoudre
  l'entrée avec un auto-test toujours vert ;
- Andy : fixer les décisions économiques et temporelles listées dans T0032 avant
  toute implémentation de location ;
- conserver T0011 en `Verify` jusqu'aux essais réels MSFS 2024 prévus par
  ADR-0003.

### Documentation updated

README, état courant, registre de maintenance, index, preuves de livraison
T0027–T0031, dépendances T0032 et Completion Report T0033.

### Git status

- branche : `docs/T0033-reconcile-delivery-readme` ;
- commit d'implémentation : `21a4dfa` ;
- PR #60 : brouillon, base `main`, head
  `docs/T0033-reconcile-delivery-readme` ;
- aucune dépendance empilée ; fusion finale réservée à Andy.
