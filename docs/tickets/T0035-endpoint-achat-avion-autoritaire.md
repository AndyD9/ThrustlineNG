# T0035 — Exposer l'achat d'avion derrière une frontière serveur authentifiée

Status: Review
Owner: Andy
Branch: `feature/T0035-aircraft-purchase-endpoint`
Phase: 2
Risk: High
Security-sensitive: Yes

## Goal

Exposer la commande d'achat T0029 derrière une Edge Function authentifiée qui
dérive le propriétaire de la session et ne permet au client de fournir ni
compagnie, ni prix, ni devise, ni credential privilégié.

## Context

T0029 livre dans `main` une commande `purchase_aircraft` atomique, idempotente
et réservée à `service_role`, mais aucun appelant applicatif. T0023 fournit déjà
le modèle durci d'une frontière Auth vers RPC privilégiée. Le golden path reste
donc incomplet entre la lecture d'une offre et l'achat serveur.

T0032 reste `Draft` faute de décisions produit sur la location. T0035 n'utilise
ni ne modifie ces décisions : il expose uniquement l'achat comptant déjà validé.

## Workflow evidence

- 2 août 2026 — `Ready` : T0023, T0024, T0029 et T0034 sont livrés dans
  `origin/main`; la signature RPC et le contrat d'achat sont stables, aucune
  décision produit supplémentaire n'est nécessaire.
- 2 août 2026 — `In progress` : branche
  `feature/T0035-aircraft-purchase-endpoint` créée depuis `origin/main` au
  commit `3b839bc`, worktree propre.
- 2 août 2026 — `Review` : handler, 15 scénarios d'achat, trois mutations du
  gate, inventaire et documentation terminés ; toutes les validations locales
  prévues passent.
- 2 août 2026 — publication : commit `083ccad` poussé sur
  `feature/T0035-aircraft-purchase-endpoint`; PR #62 ouverte prête pour revue,
  base `main`, head T0035. Les trois checks GitHub sont démarrés.

## Dependencies

- T0023 — frontière Edge Auth → RPC privilégiée livrée dans `main` ;
- T0024 — inventaire et gate d'autorité livrés dans `main` ;
- T0029 — achat atomique et idempotent livré dans `main` ;
- T0034 / PR #61 — gate de maintenance livré, checks verts.

## Allowed areas

- `supabase/functions/aircraft-purchase/` ;
- `supabase/config.toml` pour enregistrer cette fonction uniquement ;
- `package.json` pour le script de tests des fonctions uniquement ;
- `tests/backend/run.ps1`, `scripts/ci/test-backend.ps1` ;
- `eng/authority-inventory.json` ;
- `docs/PRODUCT.md`, `docs/ARCHITECTURE.md`, `docs/SECURITY.md`,
  `docs/QUALITY.md`, `docs/CURRENT_STATE.md` ;
- T0034 pour sa seule réconciliation de livraison, ce ticket et l'index.

## Do not touch

- migrations, seed, types générés, tables, RLS et fonction SQL T0029 ;
- onboarding T0023 et politique économique T0028 ;
- location T0032, crédit, remboursement, revente ou marché dynamique ;
- desktop, UX, bridge, SimConnect ou appel réseau client ;
- projet Supabase distant, secrets, données réelles, workflows et lockfiles ;
- autres tickets, problèmes connus ou Completion Reports.

## Requirements

### 1. Contrat client minimal

- Accepter uniquement `POST` avec un bearer token, `offerId` et
  `idempotencyKey` UUID canoniques dans un corps borné à 4 Kio.
- Refuser tout champ supplémentaire, notamment propriétaire, compagnie, prix,
  devise ou état d'achat, avant tout appel amont.
- Retourner uniquement `aircraftId`, `ledgerEntryId`, `offerId`,
  `schemaVersion: 1` et `state: owned`, avec `Cache-Control: no-store`.

### 2. Autorité et credentials

- Vérifier le bearer token auprès de Supabase Auth avec la clé anon et refuser
  les sessions absentes, invalides ou anonymes.
- Dériver `owner_id` exclusivement de l'identité Auth ; transmettre seulement
  `owner_id`, `offer_id` et `idempotency_key` à `purchase_aircraft`.
- Appeler la RPC avec le credential `service_role` conservé uniquement dans
  l'environnement serveur et borner les appels amont à 5 secondes.

### 3. Échec fermé et redaction

- Refuser une configuration incomplète, une réponse Auth/RPC indisponible ou
  malformée et ne jamais répercuter le détail SQL, un JWT ou un credential.
- Mapper un rejet métier vers une erreur publique stable sans distinguer solde,
  offre, suppression ou collision.
- Ne journaliser aucune donnée personnelle ni secret.

### 4. Preuves

- Des tests Node sans dépendance tierce couvrent méthode, corps borné, payload
  exact, UUID, Auth, dérivation du propriétaire, credential serveur, redaction,
  réponse versionnée et `no-store`.
- Le gate backend détecte une dérivation depuis le payload, un appel RPC sans
  credential serveur ou un champ économique client réintroduit.
- L'inventaire d'autorité nomme la nouvelle frontière pour la flotte sans
  présenter un appel desktop, la location ou un déploiement comme livrés.

## Non-goals

- modifier la transaction, l'idempotence, la concurrence ou les RLS T0029 ;
- ajouter un catalogue réel ou une autre devise ;
- consommer l'endpoint depuis le desktop ;
- déployer ou valider un projet Supabase distant ;
- implémenter la location ou toute autorité temporelle.

## Acceptance criteria

- [x] Seuls offre et clé d'idempotence sont acceptés du client ; le propriétaire
      est dérivé d'une session non anonyme vérifiée.
- [x] La RPC privilégiée reçoit exactement les trois paramètres attendus et la
      réponse publique est minimale, versionnée et non mise en cache.
- [x] Les pannes, rejets et réponses malformées échouent fermé sans détail
      sensible.
- [x] Les tests de handler, le gate backend et ses mutations négatives passent.
- [x] Autorité, architecture, sécurité, qualité, état et index restent cohérents
      avec une capacité locale non consommée et non déployée.

## Security review

- actifs : session, identifiant propriétaire, offre, avion, débit et credential
  `service_role` ;
- frontière : client non fiable → Edge Function → Auth → RPC privilégiée ;
- abus : propriétaire/prix forgé, appel anonyme, vol de credential, rejeu,
  fuite d'erreur SQL et réponse privilégiée excessive ;
- contrôles : schéma fermé, Auth serveur, identité dérivée, timeout, RPC exacte,
  redaction et réponse allowlistée ;
- risque résiduel : aucun rate limiting applicatif ni consommation desktop ; les
  protections de plateforme et le déploiement distant ne sont pas prouvés.

## Maintenance review

- problème applicable : KI-021 interdit toujours toute donnée réelle ;
- dette créée ou aggravée : aucune attendue ;
- règle revalidée : une commande économique sensible n'est appelée qu'après
  Auth serveur et sans entrée économique client ;
- contrôle automatisé : mutations sur propriétaire et credential ;
- revalidation : à tout changement de contrat RPC ou de stratégie Auth.

## Automated validation

```powershell
pnpm.cmd backend:functions:test
pnpm.cmd backend:check
pnpm.cmd authority:check
pnpm.cmd data-policy:check
pnpm.cmd maintenance:check
git diff --check
```

## Manual verification

1. Inspecter un appel réussi synthétique et confirmer Auth puis RPC, avec le
   propriétaire Auth et aucun prix/devise/compagnie dans le payload.
2. Rejouer la clé et confirmer la même réponse simulée sans champ additionnel.
3. Essayer un champ interdit, une session anonyme, un rejet RPC détaillé et une
   réponse privilégiée enrichie ; confirmer refus/redaction/allowlist.

Temps cible : 5–10 minutes.

## Rollback

Retirer la nouvelle Edge Function, son enregistrement et ses tests. La migration
et les données T0029 ne sont pas modifiées.

## Completion Report

### Summary

Ajout d'une Edge Function `aircraft-purchase` qui valide un payload fermé,
vérifie la session Supabase Auth, dérive le propriétaire et appelle la commande
T0029 avec le credential serveur. La réponse publique est allowlistée, liée à
l'offre demandée et `no-store`; les rejets restent génériques.

### Files changed

- nouveau handler, entrypoint, manifeste local et 15 tests Node d'achat ;
- configuration Supabase et script racine pour enregistrer/tester la fonction ;
- gate backend et CI backend pour trois mutations et les deux handlers ;
- inventaire d'autorité et documentation produit, architecture, sécurité,
  qualité et état ;
- T0034 réconcilié `Done`, ticket T0035 et index synchronisés.

### Commands and results

- premier `pnpm.cmd backend:functions:test` — 29/30 tests ; le contre-test UUID
  utilisait une valeur sans lettre, corrigée avant toute réussite revendiquée ;
- `pnpm.cmd backend:functions:test` final — PASS, 30 tests dont 15 T0035 ;
- `pnpm.cmd backend:check` — PASS, 18 mutations dont propriétaire, credential
  et prix client T0035 ;
- `pnpm.cmd authority:check` — PASS, 10 étapes, 13 domaines, 3 surfaces et
  5 mutations ;
- `pnpm.cmd data-policy:check` — PASS, 6 mutations ;
- `pnpm.cmd maintenance:check` — PASS, registre, index, marqueurs et 8 mutations ;
- `powershell -NoProfile -ExecutionPolicy Bypass -File .\tests\ci\run.ps1` —
  PASS, invariants CI et 2 mutations ;
- `git diff --check` — PASS avant finalisation du rapport.

### Manual verification result

PASS le 2 août 2026 sur appels synthétiques : l'ordre Auth puis RPC, les headers
anon/service, le propriétaire dérivé et les trois paramètres RPC ont été
inspectés. Champs interdits, session anonyme, rejet SQL détaillé, réponse enrichie
et `offerId` discordant sont refusés ou redigés ; seul le contrat public est
retourné. Aucun runtime Deno réel ni projet distant n'a été lancé.

### Risks and limitations

- la preuve du handler repose sur Node/fetch simulé ; le chargement Edge Runtime
  réel, le JWT local complet et un déploiement distant ne sont pas prouvés ;
- aucun appelant desktop, rate limiting applicatif ou catalogue réel n'est livré ;
- la transaction et la concurrence SQL T0029 ne changent pas et n'ont pas été
  rejouées, car aucune migration, seed ni signature RPC n'est modifiée ;
- la location T0032 reste `Draft` et les données réelles restent interdites par
  KI-021.

### Follow-ups

- valider le chargement Deno/Auth/RPC réel dans une preuve locale ou staging
  avant toute consommation applicative ;
- ajouter l'appel desktop dans un ticket séparé sans exposer `service_role` ;
- obtenir les décisions d'Andy avant tout travail de location T0032.

### Documentation updated

`PRODUCT.md`, `ARCHITECTURE.md`, `SECURITY.md`, `QUALITY.md`,
`CURRENT_STATE.md`, `eng/authority-inventory.json`, T0034, ce ticket et l'index.

### Git status

- branche : `feature/T0035-aircraft-purchase-endpoint` ;
- commit d'implémentation : `083ccad` ;
- PR #62 : ouverte et prête, base `main`, head T0035 ;
- checks locaux : 30 tests Node, backend, autorité, données, maintenance, CI
  ciblée et diff verts ;
- checks GitHub : Windows multi-stack, PostgreSQL 17 et supply-chain en cours au
  moment du handoff ;
- fusion finale réservée à Andy.
