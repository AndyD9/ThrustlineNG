# T0064 — Réduire le coût en tokens des charges JSON de la boucle de tickets

Status: Review
Owner: Unassigned
Branch: `chore/T0064-cout-charges-boucle`
Phase: Gouvernance
Risk: Low
Security-sensitive: No
Autonomous: Yes

## Goal

Les charges JSON que la boucle de tickets injecte dans ses prompts ne coûtent plus
de tokens d'indentation, sans qu'aucune preuve disparaisse du prompt.

## Context

Les workflows `.claude/workflows/ticket-plan.js` et `.claude/workflows/ticket-run.js`
sérialisaient chaque charge passée aux agents avec `JSON.stringify(x, null, 2)`.
L'indentation est du texte facturé qui ne prouve rien.

Mesure sur un échantillon calibré sur les Completion Reports réels de T0060 à T0063,
soit une vague de trois tickets avec sept commandes par ticket, un constat de revue
bloquant et une remédiation : la charge du prompt `Apprentissage` fait 10 298
caractères indentée contre 7 357 caractères compacte, soit environ 800 tokens de
différence, 29 % de cette charge. Les prompts `Remediation` de `ticket-run.js` et
`Consolidation` de `ticket-plan.js` portent le même défaut à plus petite échelle.

Ce ticket ne touche ni le texte des prompts, ni les schémas de sortie, ni les
limites de `HARD_LIMITS` et `NON_NEGOTIABLE` : ces interdictions encodent des
contraintes d'autorité réelles, pas du remplissage.

Découverte hors périmètre consignée en `KI-023` : le poste de coût dominant de la
boucle n'est pas le texte des prompts mais la liste de lecture que la constante
`SOURCES` impose à chaque agent. La restreindre par rôle touche l'ordre de lecture
d'`AGENTS.md`, donc une décision d'Andy, et reste hors de ce ticket.

## Dependencies

- T0061 fusionné : la boucle et ses deux workflows existent.
- T0062 fusionné dans `c0f16dc` (PR #109) : le gate `ticket-automation` s'exécute.
- T0063 non fusionné : sa branche modifie les deux mêmes fichiers et ajoute sa
  propre ligne d'index après T0062. Un ordre d'intégration est requis, T0063
  d'abord, sinon `docs/tickets/README.md` et `ticket-run.js` entrent en conflit.

## Allowed areas

- `.claude/workflows/ticket-run.js`
- `.claude/workflows/ticket-plan.js`
- `docs/tickets/T0064-cout-charges-json-boucle.md`
- `docs/tickets/README.md`
- `docs/KNOWN_ISSUES.md`

## Do not touch

- `AGENTS.md`, et en particulier son ordre de lecture des sources de vérité.
- La constante `SOURCES` des deux workflows.
- `HARD_LIMITS`, `NON_NEGOTIABLE` et le texte des consignes données aux agents.
- Les schémas de sortie des agents.
- La ligne d'index de T0063 et celle de tout autre ticket.

## Requirements

- Toute charge JSON qui est un tableau d'enregistrements est sérialisée en une
  ligne compacte par enregistrement, séparées par des retours à la ligne, et le
  prompt annonce ce format à l'agent.
- Aucun champ n'est retiré d'aucune charge. Un tableau vide reste écrit `[]` :
  c'est une affirmation d'absence, alors qu'un champ manquant est ambigu.
- La charge du prompt `Redaction` de `ticket-plan.js` reste indentée, parce que le
  rédacteur recopie ces champs section par section dans un fichier de ticket, et un
  commentaire dans le code dit pourquoi.
- Les deux scripts restent analysables comme modules ES.

## Non-goals

- Réduire ou réécrire le texte des prompts.
- Restreindre la liste de lecture d'un agent, quel que soit son rôle.
- Retirer des lignes de commandes réussies des preuves passées à l'apprentissage,
  ce qui économiserait environ 685 tokens de plus au prix d'une preuve.
- Toucher au prompt caching de l'API Messages : le dépôt n'appelle pas l'API Claude.

## Acceptance criteria

- [x] Aucune occurrence de `JSON.stringify(..., null, 2)` ne subsiste dans les deux
      workflows, sauf celle du prompt `Redaction`, qui porte un commentaire.
- [x] Les charges de `Apprentissage`, `Remediation` et `Consolidation` rendent une
      ligne JSON compacte par enregistrement.
- [x] La liste des champs passés à l'agent d'apprentissage est identique à celle
      d'avant le changement, champ pour champ.
- [x] `pnpm ticket-automation:check` et `pnpm maintenance:check` passent.
- [x] `KI-023` est consignée avec sa mesure.

## Security review

Non applicable : `Security-sensitive: No`. Aucune frontière de confiance, aucune
donnée, aucune autorité déplacée. Les limites d'autorité données aux agents sont
explicitement hors périmètre.

## Maintenance review

- dettes et problèmes connus applicables : aucune dette existante ne porte sur le
  coût en tokens de la boucle avant ce ticket.
- dette créée ou aggravée : aucune.
- règle de sécurité ajoutée, modifiée ou à revalider : aucune.
- contrôle manuel à automatiser : aucun gate ne couvre `.claude/workflows/`. Un
  contrôle du format des charges resterait à écrire si ce coût redevient un sujet.
- risque résiduel ou exception approuvée : `KI-023` reste ouverte et nomme la
  décision d'Andy qui la débloquerait.

## Automated validation

```powershell
pnpm ticket-automation:check
pnpm maintenance:check
```

## Manual verification

1. Lancer `/ticket-run` en mode sélection seule pour confirmer que le workflow se
   charge et s'exécute sans erreur d'analyse.
2. Sur une vague réelle, confirmer dans la trace du prompt `Apprentissage` que les
   résultats apparaissent à raison d'une ligne JSON par ticket.
3. Confirmer que l'agent d'apprentissage cite toujours les commandes, les constats
   de revue et les remédiations de chaque ticket.
4. Tester la limite : sur une vague dont un ticket sort en `blocked`, confirmer que
   sa ligne est bien présente avec ses champs vides.

Temps cible : 5–10 minutes.

## Rollback

Revenir au commit précédent sur ce fichier et sur les deux workflows. Aucun état
persistant, aucune migration, aucune donnée n'est en jeu : les workflows sont lus à
chaque invocation.

## Completion Report

### Summary

Les tableaux d'enregistrements passés aux agents sont désormais sérialisés en une
ligne JSON compacte par enregistrement, avec le format annoncé dans le prompt. Trois
charges sont concernées : les résultats de vague du prompt `Apprentissage` et les
constats bloquants du prompt `Remediation` dans `ticket-run.js`, les tickets écrits
et les décisions relevées du prompt `Consolidation` dans `ticket-plan.js`. La charge
du prompt `Redaction` reste indentée, avec un commentaire qui dit pourquoi.

Aucun champ n'a été retiré. La liste des quatorze champs passés à l'apprentissage
est identique à celle d'avant le changement.

### Files changed

- `.claude/workflows/ticket-run.js`
- `.claude/workflows/ticket-plan.js`
- `docs/tickets/T0064-cout-charges-json-boucle.md`
- `docs/tickets/README.md`
- `docs/KNOWN_ISSUES.md`

### Commands and results

Exécutées le 5 août 2026 depuis le worktree `.worktrees/t0064`, sur `chore/T0064-cout-charges-boucle`
partie de `origin/main` `c0f16dc`.

- `pwsh -NoProfile -File ./tests/ticket-automation/run.ps1` : passed, 34 assertions et
  10 mutations négatives. La branche T0063 en rapporte 50 et 15 parce qu'elle étend
  les tests du sélecteur ; ces chiffres ne sont pas ceux de cette branche.
- `pwsh -NoProfile -File ./tests/maintenance/run.ps1` : passed, registre, index des
  tickets, marqueurs de dette et 8 scénarios de mutation.
- Analyse des deux workflows comme modules ES, globales du harness neutralisées :
  passed pour `ticket-run.js` et `ticket-plan.js`.
- Contrôle du critère 1 : `grep -n "null, 2" .claude/workflows/*.js` ne rend que
  `ticket-plan.js:333`, la charge du prompt `Redaction`.
- Contrôle du critère 3 : les listes de champs avant et après le changement, extraites
  de `origin/main` et de la branche, comptent 14 entrées et `diff` les déclare
  identiques.
- Contrôle du critère 2 : l'expression exacte du workflow, exécutée sur trois entrées,
  rend 3 lignes ; sur une entrée sans implémentation elle rend `outcome: "inconnu"` et
  `commands: []` au lieu d'omettre les champs.

### Manual verification result

Partielle. L'étape 1 est couverte par l'analyse des deux modules. Les étapes 2 à 4
exigent une vague réelle, donc un run de `/ticket-run` en mode `execute` qui crée des
branches et ouvre des Pull Requests : elles reviennent à Andy sur son poste Windows.
Le comportement attendu aux étapes 2 et 4 est prouvé au niveau de l'expression, hors
vague réelle, et non sur une trace de prompt réelle. Le ticket reste en `Review` pour
cette raison.

### Risks and limitations

- La mesure de 800 tokens vient d'un échantillon calibré sur des Completion Reports
  réels, pas d'un run instrumenté. L'ordre de grandeur est sûr, la valeur exacte
  dépend de la vague.
- Aucun gate ne couvre `.claude/workflows/`. Une régression de format ne serait vue
  qu'au prochain run.
- Conflit d'intégration attendu avec T0063 sur les deux workflows et sur l'index.

### Follow-ups

- `KI-023` : le coût de la liste de lecture par agent, qui domine celui corrigé ici
  d'environ deux ordres de grandeur, attend une décision d'Andy.
- La taille de `docs/CURRENT_STATE.md`, 66 Ko, et de `docs/QUALITY.md`, 51 Ko, est
  la cause racine de ce coût : chaque agent les paie intégralement.

### Documentation updated

- `docs/KNOWN_ISSUES.md` : ajout de `KI-023`.
- `docs/tickets/README.md` : ligne d'index de T0064.
