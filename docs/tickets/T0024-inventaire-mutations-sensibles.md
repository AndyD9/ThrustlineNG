# T0024 — Inventorier les mutations sensibles du golden path

Status: Done
Owner: Andy
Branch: `security/T0024-inventory-sensitive-mutations`
Phase: 2
Risk: High
Security-sensitive: Yes

## Goal

Disposer d'un inventaire exhaustif et vérifié des domaines mutables du golden
path afin de prouver que toute mutation déjà implémentée reste autoritaire côté
serveur et que les domaines absents ne sont pas présentés comme sécurisés.

## Context

T0020 protège le grand livre et T0022–T0023 retirent la création directe de
compagnie. `KI-001` reste toutefois ouvert car aucune source unique ne couvre
les dix étapes du golden path ni ne fait échouer la validation lorsqu'une
mutation directe apparaît dans le desktop, Tauri ou le bridge.

La préparation et la revue du 1er août 2026 confirment que le client actif est
encore un socle local : aucun appel Supabase ou DML métier n'y existe. Les
mutations présentes sont confinées aux migrations et à l'Edge Function ; les
domaines flotte, dispatch, clôture de vol, réputation, maintenance et opérations
passives ne sont pas implémentés.

## Dependencies

- T0018–T0020 — cycle de compte et grand livre (`Done`, dans `main`) ;
- T0022–T0023 — onboarding autoritaire et frontière Edge (`Done`, dans `main`) ;
- ADR-0002 et `PRODUCT.md` — golden path canonique.

## Allowed areas

- `eng/authority-inventory.json` ;
- `tests/authority/` ;
- `package.json` ;
- `.github/workflows/ci.yml`, `tests/ci/run.ps1` ;
- `docs/AUTHORITY.md` ;
- `docs/ARCHITECTURE.md`, `docs/SECURITY.md`, `docs/QUALITY.md` ;
- `docs/CURRENT_STATE.md`, `docs/KNOWN_ISSUES.md` ;
- `docs/tickets/T0024-inventaire-mutations-sensibles.md` ;
- `docs/tickets/README.md`.

## Do not touch

- `apps/`, `packages/` et code client ;
- migrations, seeds, tests SQL et Edge Functions sous `supabase/` ;
- autres workflows, lockfiles, toolchain et politique économique.

## Requirements

- couvrir exactement les dix étapes essentielles de `PRODUCT.md` ;
- classer chaque domaine en `server-authoritative`, `external-authority` ou
  `not-implemented`, avec preuves et limites explicites ;
- distinguer une tranche partielle d'un domaine d'une capacité complète ;
- scanner tous les fichiers sources des trois composants clients actifs ;
- refuser une référence au credential `service_role`, une commande réservée au
  serveur, un accès Data API non classé ou une mutation Supabase/SQL directe ;
- échouer si un nouveau type de source client apparaît sans mise à jour du gate ;
- fournir des mutations négatives déterministes du harnais.

## Non-goals

- implémenter une nouvelle commande métier ou un appelant desktop ;
- décider montants, revenus, coûts ou règles de progression ;
- auditer l'ancien produit hors de ce dépôt ;
- prétendre que les domaines `not-implemented` satisfont le golden path.

## Acceptance criteria

- [x] Les dix étapes du golden path et tous leurs domaines mutables sont
  inventoriés dans une source JSON versionnée.
- [x] Toute mutation présente est liée à une frontière serveur et à une preuve
  existante ; toute capacité absente reste explicitement `not-implemented`.
- [x] Le gate échoue fermé sur dérive d'inventaire et mutation client directe.
- [x] Au moins quatre scénarios négatifs prouvent le harnais.
- [x] `KI-001`, l'architecture, la sécurité, la qualité et l'état courant sont
  synchronisés sans modifier le produit.

## Security review

- actifs/données : propriété, compte, argent, flotte, vols, réputation,
  maintenance et opérations planifiées ;
- frontière : WebView, Tauri et bridge non fiables face aux fonctions serveur ;
- abus : mutation directe, credential privilégié livré, domaine ajouté sans
  classification ou capacité absente annoncée comme sûre ;
- validation/autorisation : inventaire fermé, chemins de preuve existants et
  scan statique des sources clientes ;
- atomicité/idempotence : vérifiées par les tickets serveur existants, non
  redéfinies ici ;
- logs/vie privée : aucune donnée utilisateur, aucun secret et aucune sortie de
  contenu source sensible.

## Automated validation

```powershell
pnpm authority:check
pnpm backend:check
pnpm data-policy:check
pnpm ci:check
git diff --check
```

## Manual verification

1. Lire les dix étapes et leurs domaines dans `eng/authority-inventory.json`.
2. Comparer les capacités implémentées aux migrations et à l'Edge Function.
3. Confirmer que le desktop, Tauri et le bridge ne contiennent aucune mutation.
4. Confirmer que les domaines futurs restent `not-implemented` et bloquants.

Temps cible : 5–10 minutes.

## Rollback

Supprimer uniquement l'inventaire, son gate, sa documentation et le script
`authority:check`. Aucune donnée, migration ou capacité applicative n'est
modifiée.

## Completion Report

Clôturé le 1er août 2026 sur
`security/T0024-inventory-sensitive-mutations`.

### Summary

Une source JSON inventorie exactement les dix étapes produit, 13 domaines et
les trois composants clients. Le gate fail-closed valide les fichiers et
marqueurs de preuve, conserve
les capacités absentes à `not-implemented` et refuse les mutations directes ou
credentials privilégiés dans le client.

### Files changed

- inventaire : `eng/authority-inventory.json` ;
- gate : `tests/authority/run.ps1`, script racine dans `package.json` ;
- exécution obligatoire : `.github/workflows/ci.yml` et invariant
  `tests/ci/run.ps1` ;
- référence : `docs/AUTHORITY.md` ;
- synchronisation : architecture, sécurité, qualité, état, problèmes connus et
  index des tickets.

### Commands and results

- `pnpm.cmd authority:check` — réussi : 10 étapes, 13 domaines, 3 surfaces et
  5 mutations négatives ;
- `pnpm.cmd backend:check` — réussi : T0012–T0023 et 11 mutations ;
- `pnpm.cmd data-policy:check` — réussi : T0017–T0020 et 6 mutations ;
- `pnpm.cmd ci:check` — non exécuté : `pwsh` est installé via WindowsApps mais
  absent du `PATH` du shell et son alias est refusé par le bac à sable ;
- harnais direct `tests/ci/run.ps1` sous Windows PowerShell 5.1 — réussi :
  workflow incluant `authority:check` et 2 mutations CI ;
- inventaire PowerShell — `4` domaines serveur partiels, `1` autorité externe,
  `8` domaines non implémentés ;
- recherche ciblée React/Tauri/bridge — aucune signature de mutation trouvée.

### Manual verification result

Les dix étapes correspondent à `PRODUCT.md`. Les frontières compagnie, cycle de
compte, grand livre et restauration pointent vers leurs migrations/tests. Les
domaines futurs restent absents et aucune source cliente ne contient de DML,
Data API ou credential privilégié.

### Risks and limitations

- le scan est statique et borné aux extensions clientes inventoriées ; toute
  nouvelle extension échoue jusqu'à revue ;
- la preuve couvre le nouveau dépôt, pas les comportements de l'ancien produit ;
- huit domaines ne sont pas implémentés et quatre tranches restent partielles ;
- aucune politique économique, donnée réelle ou cible distante n'est validée ;
- l'interprétation réelle du workflow et PowerShell 7 seront prouvés par les
  checks GitHub de la Pull Request ; le harnais local a passé sous PowerShell
  5.1, pas via la commande canonique sandboxée.

### Follow-ups

- chaque ticket ajoutant une mutation doit mettre à jour l'inventaire et fournir
  une frontière serveur testée ;
- créer séparément la prochaine commande économique seulement après décision de
  sa politique produit ;
- conserver `KI-021` ouvert avant toute donnée réelle.

### Documentation updated

`AUTHORITY.md`, `ARCHITECTURE.md`, `SECURITY.md`, `QUALITY.md`,
`CURRENT_STATE.md`, `KNOWN_ISSUES.md` et l'index des tickets sont synchronisés.
