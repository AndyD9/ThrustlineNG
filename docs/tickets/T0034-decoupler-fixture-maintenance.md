# T0034 — Découpler la fixture du gate de maintenance

Status: Review
Owner: Andy
Branch: `chore/T0034-decouple-maintenance-fixture`
Phase: Gouvernance
Risk: Medium
Security-sensitive: No

## Goal

Rendre l'auto-test du gate de maintenance indépendant des tickets et problèmes
réels, afin qu'une mutation non détectée échoue réellement et que KI-022 puisse
être résolu sans affaiblir le contrôle.

## Context

T0033 a prouvé que `tests/maintenance/run.ps1` utilise KI-022 comme fixture
active : passer l'entrée à `Resolved` fait échouer le scénario qui attend un
marqueur relié à une dette `Scheduled`. L'inspection T0034 relève aussi que les
assertions `@(...) -notmatch` ne lèvent pas d'erreur lorsque le gate ne retourne
aucun problème ; un scénario négatif peut donc produire un faux succès.

La PR #60 a livré T0033 dans `main` avec ses checks verts. T0034 réconcilie cette
livraison, corrige uniquement le harnais temporaire et conserve toutes les
règles de production du gate.

## Workflow evidence

- 2 août 2026 — `Ready` : T0030 et T0033 sont livrés dans `origin/main`; KI-022
  désigne explicitement T0034 et aucune décision produit ou environnementale
  n'est requise.
- 2 août 2026 — `In progress` : branche
  `chore/T0034-decouple-maintenance-fixture` créée depuis `origin/main` au commit
  `167e763`, worktree propre.
- 2 août 2026 — `Review` : fixture synthétique et assertions explicites
  implémentées ; Windows PowerShell 5.1, PowerShell 7.6.4, le harnais CI ciblé et
  le contre-test de mutation neutralisée passent.

## Dependencies

- T0030 — gate de maintenance livré dans `main` ;
- T0033 / PR #60 — reproduction de KI-022 et livraison documentaire prouvées.

## Allowed areas

- `tests/maintenance/run.ps1` ;
- `docs/KNOWN_ISSUES.md` pour KI-022 uniquement ;
- `docs/CURRENT_STATE.md` pour l'état du gate et le prochain ticket ;
- `docs/tickets/README.md`, T0033 et ce ticket.

## Do not touch

- règles métier du gate, scripts CI et workflows ;
- code applicatif, migrations, seeds, manifests, lockfiles et toolchain ;
- autres problèmes connus, tickets ou Completion Reports ;
- décisions de location T0032, données réelles et environnements distants.

## Requirements

- Créer dans le répertoire temporaire une KI et un ticket synthétiques dont les
  identifiants ne dépendent d'aucune entrée réelle.
- Utiliser uniquement ces fixtures pour les mutations de sévérité, statut,
  preuve, dérive ticket/index et marqueurs de dette suivis.
- Faire échouer explicitement chaque scénario négatif lorsque le motif attendu
  n'est pas retourné, y compris lorsque la liste de problèmes est vide.
- Conserver les huit familles de mutations et le nettoyage du répertoire
  temporaire.
- Passer KI-022 à `Resolved` seulement après réussite du gate ainsi découplé.

## Non-goals

- ajouter une nouvelle règle de maintenance ou élargir les chemins scannés ;
- corriger une dette produit ou fermer une autre entrée ;
- modifier la CI, la sécurité, l'architecture ou la roadmap.

## Acceptance criteria

- [x] Le gate passe avec KI-022 `Resolved` et sans référence à KI-022/T0030
      dans ses scénarios temporaires.
- [x] Une mutation volontaire rendue inopérante fait échouer l'assertion du
      harnais avec un diagnostic explicite.
- [x] Les huit scénarios négatifs et le cas positif du marqueur suivi passent
      avec des identifiants synthétiques.
- [x] T0033 est réconcilié `Done`; ticket, index, KI-022 et état courant sont
      cohérents.
- [x] `pnpm.cmd maintenance:check`, le contrôle CI ciblé et
      `git diff --check` réussissent.

## Security review

Non applicable : le ticket ne change aucune frontière de confiance. Le harnais
lit les fichiers versionnés, opère uniquement sur un répertoire temporaire et
n'utilise ni secret ni donnée personnelle.

## Maintenance review

- dettes applicables : KI-022 et faux succès possible des assertions négatives ;
- dette créée ou aggravée : aucune attendue ;
- règle de sécurité modifiée : aucune ;
- contrôle automatisé : fixtures synthétiques et assertion positive du motif
  attendu ;
- risque résiduel : le gate garantit la traçabilité des règles qu'il encode,
  pas la découverte ni la correction de toute dette technique.

## Automated validation

```powershell
pnpm.cmd maintenance:check
powershell -NoProfile -ExecutionPolicy Bypass -File .\tests\ci\run.ps1
git diff --check
```

## Manual verification

1. Vérifier que le harnais ne référence plus KI-022 ni T0030.
2. Neutraliser temporairement une mutation dans une copie du script et confirmer
   que `Assert-MaintenanceIssue` échoue avec « no maintenance issue was reported ».
3. Rejouer le script intact et confirmer ses huit scénarios et le cas positif.

Temps cible : 5 minutes.

## Rollback

Revenir uniquement sur le harnais et les documents T0033–T0034/KI-022. Aucun
état applicatif ou persistant n'est modifié.

## Completion Report

### Summary

Le harnais crée désormais une KI et un ticket temporaires avec des identifiants
libres calculés à l'exécution. Les huit mutations n'utilisent plus KI-022 ni
T0030. `Assert-MaintenanceIssue` exige réellement le motif attendu et affiche
les problèmes reçus, y compris le cas vide qui produisait auparavant un faux
succès. KI-022 passe à `Resolved` et T0033 à `Done` après sa fusion #60.

### Files changed

- `tests/maintenance/run.ps1` — fixtures synthétiques et assertions négatives ;
- `docs/KNOWN_ISSUES.md` — résolution prouvée de KI-022 ;
- `docs/CURRENT_STATE.md` — état de la correction ;
- index, T0033 et T0034 — statuts, portée et preuves.

### Commands and results

- `gh pr view docs/T0033-reconcile-delivery-readme --json ...` — PR #60
  `MERGED`, base `main`, trois checks réussis ;
- `pnpm.cmd maintenance:check` avant modification — réussi, ce qui reproduit le
  faux succès possible malgré le couplage constaté par T0033 ;
- premières exécutions après modification — échecs de parsing sous Windows
  PowerShell 5.1 à cause de caractères Unicode dans la fixture ; contenu du
  script rendu strictement ASCII, aucun succès revendiqué pour ces essais ;
- `pnpm.cmd maintenance:check` final — réussi sous Windows PowerShell 5.1 :
  registre, index, marqueurs et huit mutations ;
- `powershell -NoProfile -ExecutionPolicy Bypass -File .\tests\ci\run.ps1` —
  réussi : invariants CI et deux mutations ;
- copie temporaire avec mutation de sévérité neutralisée — sortie 1 attendue et
  diagnostic `no maintenance issue was reported`; deux préparations initiales
  ont d'abord échoué sur l'expansion du wildcard puis la capture d'erreur native,
  sans modifier le dépôt ;
- `%LOCALAPPDATA%\Microsoft\WindowsApps\pwsh.exe -NoProfile -File
  .\tests\maintenance\run.ps1` — réussi sous PowerShell 7.6.4 avec huit
  mutations ;
- recherche `KI-022|T0030` et caractères non ASCII dans le script — aucun
  résultat ;
- `git diff --check` — réussi, avertissement informatif LF vers CRLF pour le
  script PowerShell.

### Manual verification result

Réussie le 2 août 2026 : le diff ne change aucune règle du gate ni aucun chemin
scanné. La copie temporaire neutralisée échoue au premier scénario avec le
diagnostic vide explicite ; le script intact passe ensuite sous les deux moteurs
PowerShell et supprime ses répertoires temporaires.

### Risks and limitations

- les identifiants synthétiques sont choisis parmi les valeurs libres les plus
  hautes et n'entrent jamais dans le worktree ;
- le gate prouve ses huit familles de contrôles, pas l'absence de toute dette
  architecturale ;
- T0034 est présent sur sa branche mais pas encore livré dans `main` ; KI-022 est
  donc résolu par le diff en revue, pas encore par la branche distante par défaut.

### Follow-ups

- aucune dette de maintenance créée ou aggravée ;
- T0032 reste bloqué par les décisions économiques et temporelles d'Andy ;
- les risques `High` ouverts KI-008, KI-009, KI-011, KI-015 et KI-021 restent
  hors périmètre et doivent conserver leur ordre de risque.

### Documentation updated

`CURRENT_STATE.md`, `KNOWN_ISSUES.md`, l'index des tickets, T0033 et T0034.
