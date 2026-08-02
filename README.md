# ThrustlineNG

ThrustlineNG est la réécriture Windows distribuable d'un gestionnaire de
compagnie aérienne virtuelle pour Microsoft Flight Simulator. Le projet vise un
MVP solo connecté, avec un serveur autoritaire pour l'économie et les
transitions métier sensibles.

## État du projet

Le dépôt est une alpha de reconstruction, pas une version publique stable.

- Phase 0 terminée : produit, stratégie de refonte, support cible et stack sont
  décidés.
- Phase 1 franchie conditionnellement : socle reproductible, desktop Tauri,
  frontend React, bridge .NET, Supabase local, CI et packaging Windows non signé
  sont en place.
- Phase 2 active : cycle de compte, grand livre immuable, onboarding autoritaire,
  politique d'ouverture à 430 000 EUR et achat d'un avion sont implémentés côté
  serveur.
- Prochain domaine fonctionnel : location d'avion. Le ticket T0032 reste en
  `Draft` jusqu'aux décisions produit sur contrat, échéances, défaut,
  résiliation et autorité temporelle.

Aucune donnée utilisateur réelle n'est autorisée. Le support MSFS 2024 réel,
les environnements Supabase distants, la signature, l'updater et le rollback de
release ne sont pas encore prouvés.

## Stack

- Tauri 2 / Rust et WebView2 pour le desktop Windows ;
- React 19, TypeScript 6 et Vite 8 pour l'interface ;
- .NET 10 pour le bridge local et l'adaptateur SimConnect ;
- Supabase CLI et PostgreSQL 17 pour le backend local autoritaire ;
- Node.js 24 et pnpm 11 pour le workspace et les gates.

Les versions exactes sont épinglées dans `eng/versions.json` et les lockfiles du
dépôt.

## Démarrage

Suivre [docs/SETUP.md](docs/SETUP.md) depuis Windows 11 avec les versions
épinglées, puis lancer le bootstrap :

```powershell
pwsh -NoProfile -File .\scripts\check-toolchain.ps1
pwsh -NoProfile -File .\scripts\bootstrap.ps1
```

Commandes usuelles :

```powershell
pnpm desktop:dev
pnpm frontend:test
pnpm bridge:test
pnpm backend:check
pnpm maintenance:check
```

Le backend PostgreSQL réel nécessite Docker Desktop et s'exécute dans une pile
locale isolée :

```powershell
pnpm backend:start
pnpm backend:reset
pnpm backend:test
pnpm backend:stop
```

## Organisation

- `apps/desktop/` — shell Tauri et frontend React ;
- `apps/bridge/` — bridge .NET et frontière locale ;
- `supabase/` — migrations append-only, fonctions et tests PostgreSQL ;
- `eng/` — versions, politiques et inventaires canoniques ;
- `tests/` et `scripts/` — validations reproductibles et CI ;
- `docs/` — produit, architecture, sécurité, roadmap, état et tickets.

## Documentation de référence

- [État réellement prouvé](docs/CURRENT_STATE.md)
- [Roadmap](docs/ROADMAP.md)
- [Architecture](docs/ARCHITECTURE.md)
- [Sécurité](docs/SECURITY.md)
- [Qualité et validations](docs/QUALITY.md)
- [Tickets](docs/tickets/README.md)
- [Problèmes connus](docs/KNOWN_ISSUES.md)

Les contributions doivent suivre `AGENTS.md` et `docs/WORKFLOW.md` : un ticket
fonctionnel par branche ou worktree, périmètre explicite, validations
proportionnées et aucune mutation métier sensible autoritaire côté client.
