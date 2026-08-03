# T0049 — Valider le brouillon de dispatch sur le runtime local réel

Status: Ready
Owner: Andy
Branch: `chore/T0049-validate-dispatch-runtime`
Phase: 2
Risk: Medium
Security-sensitive: Yes

## Goal

Prouver sur la pile locale réelle qu'une session Supabase Auth traverse l'Edge
Function `dispatch-draft` puis la commande `create_dispatch_draft`, avec une
identité, une compagnie, un avion et un brouillon exclusivement synthétiques.

## Context

T0047 prouve la transaction sur PostgreSQL 17 et T0048 prouve le handler avec un
`fetch` injecté. Aucun des deux ne charge la fonction dans l'Edge Runtime réel :
le contrat Deno, la lecture des variables serveur et le chaînage Auth → Edge →
RPC restent non exécutés. T0036 a fourni exactement cette preuve pour l'achat
d'avion ; ce ticket applique le même protocole au dispatch.

Le flux concerné est le flux 2 du mode accéléré (`docs/ROADMAP.md`). La capacité
est déjà présente dans `main` depuis la PR #83 ; ce ticket n'ajoute aucune
capacité produit et ne modifie ni la migration, ni le handler.

## Dependencies

- T0021 — pile Supabase locale isolée sur `127.0.0.1` ;
- T0040 — provider email local et provisionnement d'identité par l'Admin API ;
- T0036 — protocole de preuve runtime Edge de référence ;
- T0047, T0048 — commande et frontière à valider, présentes dans `main`.

## Allowed areas

- `scripts/` pour un script de validation runtime borné, si nécessaire ;
- `docs/QUALITY.md` et `docs/CURRENT_STATE.md` ;
- ce ticket et `docs/tickets/README.md`.

## Do not touch

- migration, tables, RLS et commande SQL T0047 ;
- handler, contrat et tests de `supabase/functions/dispatch-draft/` ;
- onboarding, achat, politique économique ou location T0032 ;
- desktop, Rust/Tauri, bridge, SimConnect et SimBrief ;
- workflows, manifests, lockfiles, cible distante et données réelles.

## Requirements

### 1. Environnement

- Démarrer la pile via `backend:start` et confirmer que 54321–54323 écoutent
  uniquement sur `127.0.0.1` avant tout appel.
- Provisionner une identité `.invalid` par l'Admin API locale, sans ouvrir
  `auth.enable_signup`.
- Créer la compagnie par `company-onboarding` et l'avion par
  `aircraft-purchase`, afin que le dispatch porte sur un avion réellement
  possédé.

### 2. Parcours nominal

- Appeler `POST /functions/v1/dispatch-draft` avec le bearer de la session, un
  avion possédé, deux ICAO distincts et une clé d'idempotence.
- Vérifier que la réponse contient exactement les sept champs publics, avec
  `state: draft`, `schemaVersion: 1` et `Cache-Control: no-store`.
- Rejouer la même intention et exiger le même `dispatchId`.
- Confirmer en SQL exactement un brouillon, une commande d'idempotence, l'état
  `draft` et l'appartenance à la compagnie du sujet Auth.

### 3. Refus

- Appel sans bearer : HTTP 401 sans détail interne.
- Champ supplémentaire, ICAO invalides ou identiques : HTTP 400 redigé.
- Avion appartenant à une seconde identité synthétique : rejet redigé sans
  divulguer l'existence, la compagnie ou le propriétaire de cet avion.
- Deuxième brouillon sur le même avion avec une nouvelle clé : rejet redigé.

### 4. Nettoyage et preuves

- Supprimer les identités synthétiques, arrêter la pile avec `--no-backup` puis
  redémarrer et prouver zéro identité T0049 persistée.
- Consigner chaque commande, son environnement, son résultat et ses limites ;
  distinguer `non exécuté`, `bloqué par l'environnement` et `échoué`.
- Aucun JWT, credential, email ou détail SQL dans le ticket ou les artefacts.

## Non-goals

- modifier le contrat, la transaction, l'idempotence ou les RLS existantes ;
- consommer l'endpoint depuis le desktop ;
- démarrer, reprendre, annuler ou clôturer un vol ;
- préparer SimBrief, déployer ou valider un projet Supabase distant.

## Acceptance criteria

- [ ] L'Edge Runtime local réel charge `dispatch-draft` sans nouveau port hôte.
- [ ] Une session non anonyme obtient un brouillon minimal pour un avion possédé
      et le rejeu rend le même identifiant.
- [ ] Absence de JWT, champ interdit, ICAO invalides, avion d'un autre
      propriétaire et deuxième brouillon échouent fermés et redigés.
- [ ] L'état PostgreSQL final est exactement un brouillon et une commande.
- [ ] L'arrêt sans backup puis le redémarrage prouvent zéro persistance des
      identités synthétiques.
- [ ] `QUALITY.md` et `CURRENT_STATE.md` consignent la preuve datée avec ses
      limites, sans revendiquer de cible distante ou de donnée réelle.

## Security review

- actifs : identité Auth, propriété d'avion, credential `service_role` ;
- frontière : client local non fiable → Auth → Edge Function → RPC T0047 ;
- abus : dispatch sur un avion non possédé, rejeu divergent, fuite d'erreur,
  persistance involontaire d'une identité de test ;
- contrôles : provisionnement Admin API sans signup public, bindings loopback
  vérifiés, refus redigés, destruction sans backup ;
- logs : aucun secret, JWT, email ou détail SQL consigné.

## Maintenance review

- problèmes applicables : `KI-014` parité locale/cloud non prouvée, `KI-021`
  interdiction des données réelles ;
- dette attendue : aucune ; la consommation desktop reste T0052 ;
- règle de sécurité : une preuve runtime locale ne vaut jamais parité managée ;
- contrôle répétable : script de validation runtime si le parcours est
  reproductible sans intervention manuelle ;
- risque résiduel : aucun environnement distant, staging ou production validé.

## Automated validation

```powershell
pnpm.cmd backend:check
pnpm.cmd backend:functions:test
pnpm.cmd backend:start
pnpm.cmd backend:reset
pnpm.cmd backend:test
pnpm.cmd backend:types:check
pnpm.cmd backend:stop
pnpm.cmd maintenance:check
git diff --check
```

## Manual verification

1. Démarrer la pile, relever les trois bindings et provisionner l'identité.
2. Créer compagnie et avion, puis appeler `dispatch-draft` et rejouer l'appel.
3. Tester les quatre refus et confirmer l'absence de détail privilégié.
4. Interroger PostgreSQL, supprimer l'identité, arrêter sans backup, redémarrer
   et confirmer l'absence de résidu.

Temps cible : 10 minutes hors démarrage de la pile.

## Rollback

Aucun changement applicatif n'est requis. En cas d'échec, arrêter la pile sans
backup, consigner l'échec et ouvrir un ticket correctif ciblant la cause réelle.

## Completion Report

À remplir après implémentation.

### Summary

### Files changed

### Commands and results

### Manual verification result

### Risks and limitations

### Follow-ups

### Documentation updated
