# T0028 — Fixer la politique économique d'ouverture de production

Status: Done
Owner: Andy
Branch: `docs/T0028-production-economy-policy`
Phase: 2
Risk: High
Security-sensitive: Yes

## Goal

Définir une politique d'ouverture unique, versionnée et autoritaire pour toute
nouvelle compagnie MVP, puis empêcher qu'un client ou une configuration de
déploiement non contrôlée choisisse le montant ou la devise.

## Context

T0020–T0023 livrent une ouverture financière immuable, transactionnelle et
idempotente derrière une frontière serveur. L'Edge Function lit actuellement
`COMPANY_OPENING_BALANCE_MINOR` et `COMPANY_OPENING_CURRENCY` dans son
environnement. Les valeurs locales `43000000`/`EUR`, soit 430 000 EUR, sont
explicitement des fixtures synthétiques et ne constituent pas une décision
produit.

`docs/CURRENT_STATE.md` recommande de décider cette politique avant tout
déploiement ou appel desktop et interdit de détailler une deuxième variation
financière avant cette décision.

### Décision d'Andy

Andy confirme le 2 août 2026 une ouverture unique de **430 000 EUR**, soit
`43000000` unités mineures, pour chaque nouvelle compagnie MVP. Cette décision
rend la valeur normative pour T0028 sans transformer rétroactivement les usages
antérieurs de la même valeur comme fixture en preuve de production.

## Workflow evidence

- 2 août 2026 — `Ready` : T0020, T0022 et T0023 sont `Done` et livrés dans
  `main`; Andy a confirmé montant et devise ; le worktree
  `.worktrees/t0028` est propre sur `docs/T0028-production-economy-policy`.
- 2 août 2026 — `In progress` : implémentation autorisée sur la branche
  `docs/T0028-production-economy-policy`, dans les seules zones `Allowed areas`.
- 2 août 2026 — `Review` : implémentation et documentation terminées ; quinze
  tests Edge, les gates backend/données/autorité et `git diff --check` passent.
- 2 août 2026 — réconciliation de livraison : #51 a fusionné T0027 dans
  `main`, puis #52 a fusionné T0028 dans l'ancienne branche T0027. T0028 est
  resté absent de `origin/main`; la branche a été synchronisée sans réécriture
  et la PR brouillon #54 cible directement `main`.
- T0027 reste une dépendance d'ascendance documentaire non fusionnée dans
  `main`; T0028 reste explicitement empilé et ne présume pas sa livraison.

## Dependencies

- T0020 — grand livre immuable (`Done`, livré dans `main`) ;
- T0022 — création atomique de compagnie (`Done`, livrée dans `main`) ;
- T0023 — frontière serveur authentifiée (`Done`, livrée dans `main`) ;
- validation explicite par Andy du montant et de la devise ;
- T0027 uniquement comme ascendance documentaire de la branche jusqu'à la
  livraison de la PR #51 dans `main`.

## Allowed areas

- `eng/economy-policy.json` ;
- `eng/authority-inventory.json` ;
- `supabase/config.toml` ;
- `supabase/functions/company-onboarding/` ;
- `scripts/supabase-local-runtime.ps1` ;
- `tests/backend/run.ps1` ;
- `docs/PRODUCT.md`, `docs/ARCHITECTURE.md`, `docs/SECURITY.md`,
  `docs/QUALITY.md`, `docs/CURRENT_STATE.md` ;
- ce ticket et `docs/tickets/README.md`.

## Do not touch

- migrations, seeds, tables, RPC et types générés existants ;
- deuxième écriture ou variation financière, revenus, coûts, prix, taxes,
  conversion ou comptabilité en partie double ;
- `apps/desktop/`, `apps/bridge/`, SimConnect et contrat local ;
- projet Supabase distant, staging, production, secret ou donnée réelle ;
- workflows GitHub, lockfiles et toolchain ;
- statut ou Completion Report d'un autre ticket.

## Requirements

### 1. Politique produit bornée

- Une seule version de politique s'applique à toutes les nouvelles compagnies
  du MVP ; aucun choix, bonus, difficulté, aléa ou formule utilisateur.
- La décision fixe un montant strictement positif en unités mineures et une
  devise ISO 4217 majuscule.
- La politique ne réécrit jamais une ouverture existante. Toute future
  modification exige un ticket, une nouvelle version explicite et une règle
  d'entrée en vigueur pour les seules créations futures.
- La décision ne préjuge d'aucune autre source de revenu ou de dépense.

### 2. Source canonique serveur

- `eng/economy-policy.json` porte la version, le montant en unités mineures, la
  devise et la portée `new-company-opening` sans secret ni donnée personnelle.
- L'Edge Function consomme une projection embarquée strictement identique à la
  source canonique ; le gate refuse toute divergence. Le déploiement ne peut
  plus choisir silencieusement une autre valeur par variables d'environnement.
- Le payload client reste exactement limité à `companyName` et
  `idempotencyKey`; le client ne reçoit aucune autorité nouvelle.
- Les fixtures locales et les attentes de test utilisent la politique canonique
  sans présenter un environnement local comme une preuve de production.

### 3. Validation et traçabilité

- Le gate backend refuse une politique absente, une version inconnue, un montant
  nul/hors bornes, une devise invalide ou le retour des variables d'environnement
  supprimées.
- Les tests de handler prouvent le montant/devise exacts transmis à T0022 et le
  rejet persistant de tout champ économique client.
- `PRODUCT`, `ARCHITECTURE`, `SECURITY`, `QUALITY` et `CURRENT_STATE` distinguent
  la décision normative de son futur déploiement, qui reste hors périmètre.

## Non-goals

- équilibrer l'ensemble du jeu ou simuler la rentabilité d'une compagnie ;
- ajouter une deuxième variation financière ou un solde matérialisé ;
- choisir une devise par compagnie, convertir des monnaies ou localiser les
  montants ;
- appeler l'onboarding depuis le desktop ;
- provisionner ou configurer un environnement distant ;
- autoriser des données utilisateur réelles.

## Acceptance criteria

- [x] Andy a validé le montant et la devise consignés sans assimiler la fixture
      existante à une décision implicite.
- [x] Une source canonique versionnée fixe la politique d'ouverture des nouvelles
      compagnies MVP.
- [x] L'Edge Function utilise cette source et le déploiement ne peut plus
      substituer silencieusement montant ou devise.
- [x] Le client reste incapable de fournir propriétaire, montant ou devise.
- [x] Les tests ciblés, les gates backend et politique de données passent.
- [x] La documentation distingue décision, preuve locale et déploiement futur.

## Security review

- actifs/données : politique d'ouverture, écriture immuable, clé
  d'idempotence et intégrité économique ;
- frontière : source versionnée serveur → Edge Function → RPC T0022 ; client
  distribué non fiable en lecture de la réponse seulement ;
- abus : montant/devise forgés par le client, substitution au déploiement,
  double crédit, réécriture rétroactive et confusion fixture/production ;
- validation/autorisation : artefact canonique borné, payload exact T0023,
  appel `service_role` existant et gate de dérive ;
- atomicité/idempotence : inchangées, fournies par T0022 ; une politique
  différente avec la même clé reste une collision de payload ;
- logs/vie privée : aucune nouvelle journalisation, aucun secret ni donnée
  personnelle dans la politique.

## Maintenance review

- dettes et problèmes connus applicables : limitation d'autorité économique
  relevée par T0024 ; `KI-021` continue d'interdire les données réelles ;
- dette créée ou aggravée : aucune attendue ;
- règle de sécurité ajoutée, modifiée ou à revalider : source canonique de
  politique serveur et interdiction de substitution au déploiement ;
- contrôle manuel à automatiser : cohérence artefact/handler/tests ;
- risque résiduel : le montant choisi ne sera pas un équilibrage économique
  complet et aucun environnement distant ne sera validé par ce ticket.

## Automated validation

```powershell
pnpm backend:functions:test
pnpm backend:check
pnpm data-policy:check
pnpm authority:check
git diff --check
```

## Manual verification

1. Relire la valeur approuvée dans la source canonique et les documents produit.
2. Appeler le handler avec une requête synthétique valide et confirmer le montant
   et la devise transmis au RPC simulé.
3. Ajouter `openingAmountMinor` ou `currencyCode` au payload et confirmer le refus.
4. Modifier une copie de la politique avec un montant nul, une devise minuscule
   ou une version inconnue et confirmer l'échec du gate.

Temps cible : 5–10 minutes.

## Rollback

Avant fusion, abandonner la branche. Après fusion et avant toute donnée réelle,
revenir par un ticket dédié qui versionne explicitement la politique suivante.
Ne jamais réécrire ou supprimer une ouverture déjà inscrite au grand livre.

## Completion Report

Implémentation terminée le 2 août 2026 sur
`docs/T0028-production-economy-policy`, dans le worktree isolé
`.worktrees/t0028`. La PR #52 a fusionné la branche dans T0027 après livraison
de ce dernier dans `main`, sans livrer T0028 dans la branche par défaut. La PR
brouillon #54 cible désormais directement `main` après synchronisation non
destructive.

### Summary

Andy fixe l'ouverture des nouvelles compagnies MVP à 430 000 EUR. La politique
v1 est versionnée dans `eng/economy-policy.json`; l'Edge Function embarque une
copie dont le gate exige l'identité stricte. Les anciennes surcharges de montant
et devise par environnement sont supprimées sans modifier les migrations ni les
écritures existantes.

### Files changed

- politique canonique `eng/economy-policy.json` et inventaire d'autorité ;
- copie embarquée, handler et tests `company-onboarding` ;
- configuration/runtime Supabase sans les deux anciennes variables ;
- gate backend et ses trois nouvelles mutations négatives ;
- `PRODUCT`, `ARCHITECTURE`, `SECURITY`, `QUALITY` et `CURRENT_STATE` ;
- ticket T0028 et index des tickets.

### Commands and results

- `pnpm backend:functions:test` — aucun test exécuté : Windows PowerShell a
  bloqué le shim `pnpm.ps1` par sa politique d'exécution ; relance avec
  `pnpm.cmd` ;
- première relance `pnpm.cmd` dans le bac à sable — restauration du worktree
  bloquée par des accès registre/cache `EACCES`; aucun test exécuté ;
- relance autorisée avec `pnpm.cmd` — dépendances exactes restaurées sans
  modification du lockfile, quinze tests Edge réussis ; premier
  `backend:check` en échec utile car le harnais de mutation ne copiait pas les
  deux nouveaux JSON dans sa racine temporaire ;
- après correction du harnais : `pnpm.cmd backend:functions:test` — réussi,
  15/15 ; `pnpm.cmd backend:check` — réussi, quatorze mutations ;
  `pnpm.cmd data-policy:check` — réussi, six mutations ;
- validation finale après documentation : les trois commandes précédentes
  réussissent, puis `pnpm.cmd authority:check` réussit avec dix étapes,
  treize domaines, trois surfaces et cinq mutations ;
- `git diff --check` — réussi ; seuls des avertissements informatifs de future
  normalisation LF vers CRLF sont signalés par Git pour quatre fichiers ;
- `gh pr view 51` — PR T0027 ouverte en brouillon vers `main`, avec Windows,
  PostgreSQL 17 et supply chain réussis ;
- `gh pr view 52` — PR T0028 ouverte en brouillon, base T0027, head T0028 ; les
  trois checks GitHub sont en cours au moment du contrôle ; ils ont ensuite
  réussi sur les runs CI `30739081294` et supply chain `30739081297` ;
- contrôle distant suivant : #51 `MERGED` dans `main`, #52 `MERGED` dans T0027
  mais commit T0028 absent de `origin/main`; fusion non destructive de
  `origin/main` dans la branche et ouverture de #54 vers `main`.

### Manual verification result

Réussie sur données synthétiques : la politique canonique et sa copie
embarquée portent toutes deux `43000000`/`EUR`; le handler transmet exactement
ces valeurs à la RPC simulée. Un payload ajoutant montant, devise ou propriétaire
est refusé avant tout appel réseau. Six copies invalides couvrent objet absent,
version inconnue, zéro, dépassement, devise minuscule et champ inattendu. Le gate
injecte aussi une divergence de copie et le retour d'une variable
d'environnement, puis confirme leur détection.

### Risks and limitations

- la copie JSON embarquée est nécessaire au paquet Edge ; le gate bloque toute
  divergence avec la source canonique mais ne remplace pas une revue de diff ;
- aucun Edge Runtime réel, projet distant ou donnée utilisateur réelle n'a été
  utilisé dans T0028 ; les preuves portent sur l'import Node, le handler et les
  gates statiques ;
- 430 000 EUR est une politique d'ouverture, pas une preuve d'équilibrage
  complet ; revenus, coûts, prix et deuxième commande restent absents ;
- T0028 reste absent de `origin/main` tant que la PR #54 n'est pas fusionnée ;
  l'état `MERGED` de #52 ne constituait pas une livraison sur la branche par
  défaut.

### Follow-ups

- faire relire puis fusionner la PR #54 dans `main` ;
- cadrer ensuite une première acquisition d'avion autoritaire sans anticiper le
  reste de l'économie ;
- conserver l'interdiction de données réelles suivie par `KI-021`.

### Documentation updated

Politique produit, frontière d'architecture, invariant de sécurité et son gate,
commandes de qualité, état courant, inventaire d'autorité et suivi des tickets.

### Git status

- branche : `docs/T0028-production-economy-policy` ;
- commits : `ef502e7` (décision `Ready`) et `7584bcc` (implémentation) ;
- PR #52 : fusionnée dans la branche T0027, sans livrer T0028 dans `main` ;
- PR #54 : brouillon, base `main`, head
  `docs/T0028-production-economy-policy` ;
- fusion finale réservée à Andy.

### Delivery reconciliation

Le 2 août 2026, T0033 confirme que les commits de décision `ef502e7` et
d'implémentation `7584bcc` sont dans l'ascendance de `origin/main` via la PR #54
(`af2ab1b`). Les critères, gates et vérifications manuelles consignés ci-dessus
étant terminés, T0028 passe de `Review` à `Done`.
