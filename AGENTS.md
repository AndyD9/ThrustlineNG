# AGENTS.md — Loi du dépôt Thrustline

Ce fichier s'applique à tout le dépôt. Toute instruction plus locale doit être
compatible avec ces règles.

## Mission

Thrustline est une application Windows distribuable de gestion de compagnie
aérienne virtuelle pour Microsoft Flight Simulator. La refonte vise en priorité :

1. stabilité et récupération après erreur ;
2. sécurité d'un client distribué et modifiable ;
3. intégrité de l'économie et des données ;
4. compatibilité MSFS/SimConnect ;
5. maintenabilité, testabilité et mises à jour sûres.

## Sources de vérité

Lire avant tout travail :

1. `docs/CURRENT_STATE.md` — ce qui existe réellement ;
2. `docs/ROADMAP.md` — ordre des phases ;
3. le ticket concerné dans `docs/tickets/` ;
4. les documents spécialisés indiqués par le ticket.

Références permanentes :

- `docs/PRODUCT.md` — périmètre et règles produit ;
- `docs/ARCHITECTURE.md` — architecture cible et frontières ;
- `docs/SECURITY.md` — règles de sécurité ;
- `docs/QUALITY.md` — stratégie de tests et critères de qualité ;
- `docs/WORKFLOW.md` — cycle complet d'un ticket.

Le code et les migrations appliquées priment sur une documentation périmée.
Signaler et corriger les divergences dans le même ticket si elles sont directement
liées au changement.

## Règles de travail

- Implémenter un seul ticket à la fois.
- Avant d'exécuter un ticket, vérifier l'état Git et déterminer la branche
  `type/TXXXX-slug` adaptée. L'agent peut créer cette branche ou basculer dessus
  sans confirmation, après avoir préservé et signalé les modifications
  préexistantes. Si la branche du ticket est déjà active, ne pas la recréer.
- Ne pas anticiper les tickets futurs.
- Ne pas refactorer un système sans rapport.
- Respecter strictement `Allowed areas` et `Do not touch`.
- Préserver les modifications utilisateur non liées.
- Ne pas changer l'architecture sans ADR accepté.
- Éviter toute dépendance nouvelle si une solution simple existe déjà.
- Arrêter et demander une décision si une ambiguïté change le produit, la
  sécurité, les données ou l'architecture.
- Un problème découvert hors périmètre devient un follow-up dans
  `docs/KNOWN_ISSUES.md`, pas une modification opportuniste.

## Frontières techniques

- `app/` : Tauri v2, React, TypeScript, Vite, UI et orchestration cliente.
- `sim-bridge/` : .NET 8, SimConnect, télémétrie locale, REST/SignalR.
- `supabase/` : Auth, PostgreSQL, RLS, Realtime, RPC et Edge Functions.
- `legacy/` : lecture seule jusqu'à son archivage explicite.

Le desktop, le sidecar et MSFS sont des clients non fiables. Le serveur est
autoritaire pour l'argent, la propriété, la réputation, la progression et les
transitions sensibles. Aucun secret backend ne doit être livré au client.

## Qualité d'implémentation

- TypeScript strict, C# nullable et Rust sans avertissement introduit.
- Pages React minces ; règles métier et accès données hors des composants.
- Mutations sensibles via commande serveur transactionnelle et idempotente.
- Migrations Supabase append-only.
- Contrats partagés versionnés et consommateurs mis à jour ensemble.
- Erreurs actionnables pour l'utilisateur, détails techniques dans des logs
  redigés.
- Aucun secret, JWT, donnée personnelle ou header d'authentification dans Git ou
  les logs.

## Validation

Exécuter les contrôles proportionnés au ticket, puis consigner les résultats :

```powershell
# Frontend
Set-Location app
npm test
npm run build

# Sidecar
Set-Location ..\sim-bridge
dotnet build --configuration Release
dotnet test --configuration Release

# Tauri
Set-Location ..\app\src-tauri
cargo check --locked

# Invariants du dépôt
Set-Location ..\..
.\scripts\security-check.ps1
```

Les changements SQL exigent des tests locaux/staging d'isolation entre deux
utilisateurs. Les changements SimConnect exigent un replay de trace ou un test
manuel MSFS documenté. Ne jamais annoncer comme réussi un contrôle non exécuté.

## Fin de ticket

Un ticket n'est `Done` que si :

- ses critères d'acceptation sont satisfaits ;
- les tests automatisés pertinents passent ;
- sa vérification manuelle a été effectuée ou clairement déléguée ;
- les risques et limites sont consignés ;
- `docs/CURRENT_STATE.md` est mis à jour si l'état réel change ;
- le ticket contient son Completion Report ;
- aucun changement hors périmètre n'est inclus.

Le rapport final doit donner : résumé, fichiers modifiés, commandes exécutées,
résultats, vérification manuelle, risques, follow-ups et documentation mise à jour.

## Gestion Git et GitHub

L'agent gère de manière autonome le cycle Git d'un ticket : création ou bascule
de branche, indexation ciblée, commit, push et création ou mise à jour de la Pull
Request. Aucune confirmation intermédiaire d'Andy n'est requise pour ces actions.

Avant toute publication, l'agent doit :

1. relever la branche courante et la branche distante par défaut ;
2. distinguer les fichiers du ticket des modifications préexistantes ;
3. indexer uniquement les fichiers du ticket avec une liste explicite ;
4. vérifier le diff indexé et exécuter `git diff --cached --check` ;
5. utiliser un message Conventional Commits adapté ;
6. exécuter les validations proportionnées au ticket ;
7. créer la Pull Request en brouillon tant que le ticket ou ses validations ne
   sont pas terminés, puis la déclarer prête pour revue lorsqu'il est publiable.

Règles :

- ne jamais utiliser `git add .` ou `git add -A` ;
- ne jamais inclure, écraser ou publier une modification utilisateur
  préexistante sans rapport avec le ticket ;
- ne jamais inventer le nom de la branche ou la cible de PR : les relever ;
- utiliser Git pour Windows/PowerShell pour ce dépôt, pas Git WSL sur `/mnt/c` ;
- ne jamais demander le mot de passe GitHub ; recommander `gh auth login` si
  l'authentification manque ;
- ne jamais effectuer de force-push, modifier directement une branche protégée
  ou contourner une protection de branche ;
- ne jamais merger une Pull Request : la décision et l'action de merge sont
  exclusivement réservées à Andy et exigent sa confirmation explicite ;
- si le ticket n'est pas prêt à publier, conserver la PR en brouillon et
  expliquer clairement les blocages.

À la fin du ticket, fournir le lien de la Pull Request ainsi qu'un résumé du
diff, des validations, de la vérification manuelle, des risques et des
follow-ups. Andy ne doit être sollicité que pour la revue et le merge final, ou
plus tôt si une décision produit, sécurité, données ou architecture est requise.
