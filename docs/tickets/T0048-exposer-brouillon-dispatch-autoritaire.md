# T0048 — Exposer le brouillon de dispatch derrière une frontière authentifiée

Status: Review
Owner: Andy
Branch: `feature/T0048-dispatch-draft-endpoint`
Phase: 2–4
Risk: High
Security-sensitive: Yes

## Goal

Exposer la commande T0047 `create_dispatch_draft` derrière une Edge Function
authentifiée et bornée qui dérive le propriétaire de Supabase Auth et ne permet
au client de fournir que l'avion, les deux ICAO et une clé d'idempotence.

## Context

T0047 fournit la transaction, l'isolation, l'idempotence et l'exclusivité du
brouillon, mais sa RPC est réservée à `service_role` et n'a aucun appelant
applicatif. T0023 et T0035 fournissent le modèle de frontière Auth vers RPC
privilégiée. T0048 réutilise ce modèle sans modifier la migration T0047.

T0043–T0047 ne sont pas livrés dans `main`. T0048 est donc une branche empilée
sur T0047 et ne présente pas cette pile comme une capacité livrée.

## Workflow evidence

- 3 août 2026 — `Ready` : la commande T0047 et les modèles Edge T0023/T0035
  sont validés ; aucune décision produit, économique, temporelle ou SimBrief
  supplémentaire n'est nécessaire.
- 3 août 2026 — `In progress` : branche
  `feature/T0048-dispatch-draft-endpoint` créée depuis T0047 au commit
  `74d0421`; dépendance empilée explicite sur T0043–T0047.
- 3 août 2026 — `Review` : handler, 16 scénarios dispatch, quatre mutations du
  gate, inventaire, revue adversariale et documentation terminés ; validations
  locales applicables réussies, publication encore à effectuer sur T0047.

## Dependencies

- T0023 — modèle de frontière Edge Auth vers RPC privilégiée ;
- T0024 — inventaire et gate d'autorité ;
- T0047 — brouillon de dispatch autoritaire, branche parente empilée.

## Allowed areas

- `supabase/functions/dispatch-draft/` ;
- `supabase/config.toml` pour enregistrer cette fonction uniquement ;
- `package.json` pour le script de tests des fonctions uniquement ;
- `tests/backend/run.ps1` et `scripts/ci/test-backend.ps1` ;
- `eng/authority-inventory.json` ;
- `docs/PRODUCT.md`, `docs/ARCHITECTURE.md`, `docs/SECURITY.md`,
  `docs/QUALITY.md`, `docs/CURRENT_STATE.md` ;
- ce ticket et `docs/tickets/README.md`.

## Do not touch

- migrations, seed, types, tables, RLS et commande SQL T0047 ;
- onboarding, achat, politique économique ou location T0032 ;
- desktop, UX, Rust/Tauri, bridge ou SimConnect ;
- SimBrief, OFP, météo, routes détaillées ou cycle de vol ;
- cible distante, données réelles, secrets, workflows, manifests ou lockfiles ;
- statuts et Completion Reports des autres tickets.

## Requirements

### 1. Contrat client minimal

- Accepter uniquement `POST` avec bearer token et un corps de 4 Kio maximum
  contenant `aircraftId`, `departureIcao`, `arrivalIcao` et
  `idempotencyKey`.
- Exiger des UUID canoniques pour l'avion et l'idempotence, normaliser les ICAO
  en majuscules après trim, exiger quatre caractères ASCII alphanumériques et
  refuser deux ICAO identiques.
- Refuser tout champ supplémentaire, notamment propriétaire, compagnie, état,
  temps, route, prix ou résultat SimBrief, avant tout appel amont.

### 2. Autorité et credentials

- Vérifier le bearer auprès de Supabase Auth avec la clé anon et refuser une
  session absente, invalide ou anonyme.
- Dériver `owner_id` exclusivement de l'identité Auth puis appeler
  `create_dispatch_draft` avec le credential `service_role`, sous délai amont
  de cinq secondes.
- Ne transmettre à la RPC que propriétaire dérivé, idempotence, avion et deux
  ICAO normalisés.

### 3. Réponse fermée et redaction

- Retourner uniquement les sept champs publics versionnés de T0047, avec
  `state: draft`, `schemaVersion: 1` et `Cache-Control: no-store`.
- Valider strictement la réponse privilégiée et sa cohérence avec la requête ;
  refuser configuration, Auth, RPC ou réponse indisponibles ou malformées.
- Mapper les rejets métier vers une erreur publique stable sans divulguer SQL,
  JWT, credential, propriété d'avion, compagnie ou état de suppression.

### 4. Preuves

- Des tests Node sans dépendance tierce couvrent méthode, limite du corps,
  allowlist, UUID/ICAO, Auth, dérivation, credential serveur, payload exact,
  redaction, réponse minimale, rejeu et `no-store`.
- Le gate backend détecte propriétaire/compagnie/état client, appel RPC sans
  credential serveur ou contrat de tests incomplet.
- L'inventaire classe la nouvelle frontière sans prétendre fournir desktop,
  SimBrief, transition, déploiement distant ou donnée réelle.

## Non-goals

- modifier la transaction, les verrous, l'idempotence ou les RLS T0047 ;
- consommer l'endpoint depuis le desktop ou lire les dispatchs ;
- préparer SimBrief, démarrer, reprendre, annuler ou finaliser un vol ;
- déployer ou valider un projet Supabase distant.

## Acceptance criteria

- [x] Le client ne fournit que l'avion, deux ICAO et l'idempotence ; le
      propriétaire est dérivé d'une session non anonyme vérifiée.
- [x] La RPC privilégiée reçoit exactement le contrat T0047 normalisé avec le
      credential serveur et un délai amont borné.
- [x] Champs supplémentaires, payload invalide, configuration/Auth/RPC en
      échec et réponse malformée échouent fermés sans fuite sensible.
- [x] La réponse publique est strictement minimale, cohérente, versionnée et
      non mise en cache ; un rejeu conserve le même contrat.
- [x] Tests ciblés et gates applicables passent avec leurs scénarios réellement
      découverts et consignés.
- [x] Documentation et suivi distinguent la branche empilée d'une livraison
      dans `main` et excluent desktop, SimBrief et cycle de vol.

## Security review

- actifs : identité Auth, propriété d'avion, trajet, idempotence, credential
  `service_role` et réponse privilégiée ;
- frontière : client non fiable → Auth → Edge Function → RPC T0047 ;
- abus : propriétaire/compagnie/état forgés, champs cachés, corps excessif,
  rejeu divergent, réponse RPC injectée et fuite d'erreur ;
- contrôles : allowlist stricte, validation avant réseau, Auth non anonyme,
  propriétaire dérivé, credential serveur, timeout, projection et redaction ;
- logs : aucun secret, JWT, email, identifiant réel ou détail SQL.

## Maintenance review

- problèmes applicables : `KI-021` interdit les données réelles ;
- dette attendue : aucune ; la consommation desktop et le runtime local réel
  restent des tickets séparés ;
- règle de sécurité : le propriétaire du dispatch vient uniquement de la
  session vérifiée à la frontière ;
- contrôle répétable : tests Node injectés et gate backend ;
- risque résiduel : pas de preuve Edge Runtime live ni de cible distante.

## Automated validation

```powershell
pnpm.cmd backend:check
pnpm.cmd backend:functions:test
pnpm.cmd authority:check
pnpm.cmd data-policy:check
pnpm.cmd maintenance:check
git diff --check
```

## Manual verification

1. Appeler le handler injecté avec une session synthétique non anonyme.
2. Vérifier l'URL RPC, les headers privilégiés et le payload normalisé exact.
3. Rejouer la même intention puis tester champs interdits, ICAO invalides,
   session anonyme, rejet RPC et réponse malformée.
4. Confirmer que les réponses et erreurs ne contiennent aucun secret ou détail
   privilégié.

Temps cible : 5–10 minutes.

## Rollback

Avant fusion, abandonner la branche. Après fusion, retirer la fonction de sa
configuration dans un ticket correctif sans modifier la migration T0047.

## Completion Report

### Summary

L'Edge Function `dispatch-draft` accepte uniquement avion, deux ICAO et
idempotence dans 4 Kio. Elle vérifie Auth, dérive le propriétaire, normalise les
ICAO, appelle la RPC T0047 avec `service_role` sous timeout et projette une
réponse publique stricte `no-store`.

### Files changed

- nouvelle fonction `supabase/functions/dispatch-draft/` et enregistrement
  local ;
- script de tests des fonctions, gate backend et inventaire d'autorité ;
- produit, architecture, sécurité, qualité, état courant, ticket et index.

Aucune migration, donnée, type généré, application cliente, SimConnect,
workflow, lockfile ou cible distante n'est modifié.

### Commands and results

- `pnpm.cmd backend:functions:test` — PASS, 46 tests dont 16 dispatch ;
- `pnpm.cmd backend:check` — PASS, 26 mutations ;
- `pnpm.cmd authority:check` — PASS, 9 mutations ;
- `pnpm.cmd data-policy:check` — PASS, 6 mutations ;
- `pnpm.cmd maintenance:check` — PASS, 8 mutations ;
- `git diff --check` — PASS, avertissement de conversion LF/CRLF seulement.

### Manual verification result

PASS le 3 août 2026 avec transport injecté et données synthétiques : inspection
de l'URL Auth/RPC, des deux credentials, du payload normalisé exact, de la
projection publique, du rejeu et des erreurs redigées. Le runtime Edge réel est
explicitement hors périmètre et non exécuté.

### Security and maintenance review result

La revue adversariale confirme qu'aucun propriétaire, compagnie, état, temps,
route ou résultat SimBrief client n'atteint la RPC. Le credential privilégié ne
quitte pas le handler, les appels amont sont bornés, les réponses sont recoupées
et aucun secret ou détail SQL n'est rendu. Aucune dette ou exception de sécurité
n'est créée ; `KI-021` reste respecté.

### Risks and limitations

T0048 est empilé sur T0047 et T0043–T0048 sont absents de `main`. La preuve est
Node/fetch injectée, sans Edge Runtime live, desktop, cible distante, donnée
réelle, SimBrief ou transition de vol.

### Follow-ups

- publier T0048 sur T0047 puis propager la pile vers `main` dans l'ordre ;
- valider Auth → Edge Runtime → RPC localement avec des données synthétiques ;
- traiter la composition desktop, SimBrief et le cycle de vol séparément.

### Documentation updated

`PRODUCT.md`, `ARCHITECTURE.md`, `SECURITY.md`, `QUALITY.md`,
`CURRENT_STATE.md`, l'inventaire d'autorité, ce ticket et son index.

### Git status

- branche : `feature/T0048-dispatch-draft-endpoint` ;
- base : T0047 au commit `74d0421` ;
- dépendances empilées : T0043–T0047 restent absents de `main` ;
- commit, push et Pull Request : à effectuer.
