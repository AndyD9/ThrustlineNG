# T0028 — Fixer la politique économique d'ouverture de production

Status: Ready
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
- L'Edge Function consomme cette source canonique et n'accepte plus que le
  déploiement choisisse silencieusement une autre valeur par variables
  d'environnement.
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

- [ ] Andy a validé le montant et la devise consignés sans assimiler la fixture
      existante à une décision implicite.
- [ ] Une source canonique versionnée fixe la politique d'ouverture des nouvelles
      compagnies MVP.
- [ ] L'Edge Function utilise cette source et le déploiement ne peut plus
      substituer silencieusement montant ou devise.
- [ ] Le client reste incapable de fournir propriétaire, montant ou devise.
- [ ] Les tests ciblés, les gates backend et politique de données passent.
- [ ] La documentation distingue décision, preuve locale et déploiement futur.

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

À remplir après validation de la décision puis implémentation.

### Summary

### Files changed

### Commands and results

### Manual verification result

### Risks and limitations

### Follow-ups

### Documentation updated
