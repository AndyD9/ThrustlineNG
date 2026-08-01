# T0018 — Exporter puis supprimer un compte sans perte ni double opération

Status: Verify
Owner: Andy
Branch: `security/T0018-account-lifecycle`
Phase: 2
Risk: High
Security-sensitive: Yes

## Goal

Fournir une commande backend autoritaire qui prépare un export portable puis
exécute le cycle de suppression d'un compte de façon transactionnelle,
idempotente et isolée entre propriétaires.

## Context

La phase 2 est active conditionnellement depuis la fusion de la revue de phase 1
par la PR #29. Aucune donnée utilisateur réelle n'est admise.

T0012 a créé `public.companies` avec
`owner_id references auth.users(id) on delete restrict`. Cette contrainte évite
une compagnie orpheline mais bloque la suppression directe du propriétaire.
T0017 impose un export sans données tierces, une demande vérifiée, un blocage des
nouvelles mutations sensibles, un effacement ou une anonymisation
transactionnels, un marqueur non personnel et une preuve expurgée.

Décisions validées par Andy le 31 juillet 2026 :

- délai de récupération de 7 jours, avec annulation possible après une nouvelle
  réauthentification ;
- nouvelle session Supabase créée depuis 5 minutes au plus, vérifiée côté serveur
  par `session_id`, `auth.sessions` et une méthode `amr` non issue d'un simple
  rafraîchissement de jeton ;
- export versionné préparé lors de la demande, récupérable pendant les 7 jours
  puis supprimé avec le compte.

Références :

- `docs/reviews/PHASE-1.md` ;
- `docs/DATA_POLICY.md` ;
- `docs/SECURITY.md` ;
- `docs/ARCHITECTURE.md` ;
- `docs/decisions/ADR-0001-modele-produit.md` ;
- `docs/KNOWN_ISSUES.md` (`KI-021`).

## Dependencies

- T0012 — schéma Supabase local et preuves RLS (`Verify`, implémentation
  fusionnée dans `main`) ;
- T0017 — politique de données (`Done`) ;
- revue de phase 1 — passage conditionnel fusionné par la PR #29 ;
- validation des paramètres de cycle de vie par Andy le 31 juillet 2026.

## Allowed areas

- `supabase/migrations/` — nouvelle migration append-only uniquement ;
- `supabase/tests/database/` — pgTAP T0018 ;
- `supabase/seed.sql` — données synthétiques strictement nécessaires ;
- `packages/database/` — types régénérés ;
- `tests/backend/` — invariants statiques et mutations négatives T0018 ;
- `scripts/ci/test-backend.ps1` — découverte explicite des nouvelles preuves si
  nécessaire ;
- `eng/data-policy.json` et `tests/data-policy/` — statut des seules capacités
  effectivement prouvées ;
- `docs/ARCHITECTURE.md`, `docs/SECURITY.md`, `docs/DATA_POLICY.md`,
  `docs/QUALITY.md`, `docs/CURRENT_STATE.md`, `docs/KNOWN_ISSUES.md` ;
- `docs/tickets/T0018-export-suppression-compte.md` et
  `docs/tickets/README.md`.

## Do not touch

- migrations existantes, notamment
  `supabase/migrations/20260728000100_create_companies.sql` ;
- `apps/desktop/`, `apps/bridge/` et le contrat local ;
- modèle économique, grand livre, flotte, vols et progression ;
- staging, production, projet Supabase lié, secrets ou données utilisateur
  réelles ;
- sauvegarde distante, restauration et replay post-restauration ;
- workflow de collaboration, rôle supplémentaire ou transfert de propriété ;
- workflows GitHub, sauf ticket séparé si l'infrastructure actuelle ne peut pas
  exécuter les preuves PostgreSQL 17 requises.

## Requirements

### 1. Frontière autoritaire et réauthentification

- La WebView, le desktop, les rôles `anon`/`authenticated` et tout paramètre
  fourni par le client restent non fiables.
- L'identité ciblée est déduite d'une identité authentifiée par le serveur ; un
  identifiant de propriétaire fourni par le client ne fait jamais autorité.
- La commande destructive exige une réauthentification récente prouvée par une
  frontière serveur. Une date ou un booléen déclaré par le client est refusé.
- Les fonctions internes privilégiées ne sont pas exécutables par `anon` ou
  directement par `authenticated`.

### 2. Export portable

- L'export possède un format et une version de schéma explicites.
- Il contient uniquement les données portables du propriétaire courant et de sa
  compagnie, sans mot de passe, secret, JWT, métadonnée interne Auth ni donnée
  d'un tiers.
- L'export est préparé avant toute suppression irréversible.
- Une perte de la première réponse ne doit pas entraîner la perte silencieuse de
  l'export ; le propriétaire peut récupérer le même résultat pendant la fenêtre
  approuvée.
- L'intégrité de l'export est vérifiable sans journaliser son contenu.

### 3. Cycle de suppression

- Une demande vérifiée fait passer le compte de `active` à
  `deletion_pending` dans une transaction et bloque les nouvelles mutations
  sensibles.
- Le délai de récupération exact, son point de départ et la règle d'annulation
  sont approuvés avant implémentation.
- Après expiration, une commande serveur efface ou anonymise
  transactionnellement les liens personnels, supprime l'identité Auth sans créer
  de compagnie orpheline et conserve seulement le minimum non personnel exigé.
- Toute erreur avant commit laisse l'état précédent exploitable ; aucun état
  partiellement supprimé n'est observable.
- Le ticket ne revendique pas le replay des suppressions après restauration.

### 4. Idempotence, concurrence et audit

- Chaque commande destructive porte une clé d'idempotence UUID, liée au
  propriétaire et au type d'opération.
- Le rejeu de la même clé et du même payload rend le même résultat logique sans
  double effet.
- La réutilisation d'une clé avec un payload différent est rejetée.
- Deux demandes concurrentes pour un même compte convergent vers un seul cycle
  de suppression.
- Le marqueur et l'audit ne contiennent ni email, nom de compagnie, payload
  exporté, identifiant Auth direct ni secret.

### 5. Schéma, autorisations et preuves

- Toute évolution utilise une nouvelle migration append-only.
- Les tables ajoutées activent et forcent la RLS ; `anon` ne reçoit aucun
  privilège.
- Les tests réels PostgreSQL 17 couvrent propriétaire A, propriétaire B,
  anonyme, rejeu, concurrence et rollback transactionnel.
- Les types générés sont stables après deux resets.
- Local et CI restent limités aux identités et compagnies synthétiques.

## Non-goals

- Interface de paramètres, téléchargement desktop ou UX d'annulation ;
- admission de données utilisateur réelles ;
- sauvegarde, restauration ou replay des suppressions ;
- purge générique des catégories à durée glissante ;
- grand livre et anonymisation d'écritures financières inexistantes ;
- conformité juridique complète ou choix définitif de base légale ;
- provisioning staging/production.

## Acceptance criteria

- [x] Les trois décisions ouvertes sont approuvées et consignées dans ce ticket.
- [x] Une migration append-only résout le blocage `on delete restrict` sans
      modifier la migration T0012 ni permettre une compagnie orpheline.
- [x] L'export versionné de A exclut B et toute donnée Auth sensible.
- [x] La demande vérifiée bloque les mutations sensibles pendant le délai
      approuvé et reste récupérable après perte de réponse.
- [x] Le rejeu et deux appels concurrents n'entraînent ni double export logique,
      ni double suppression, ni état partiel.
- [x] B et l'anonyme ne peuvent ni lire l'export de A, ni demander, annuler ou
      exécuter sa suppression.
- [x] Une panne injectée avant commit conserve intégralement l'état actif.
- [x] Après expiration simulée, l'identité Auth et les liens personnels sont
      absents et le marqueur restant ne permet pas de réidentifier le
      propriétaire.
- [x] Les pgTAP sont découverts explicitement et passent sur PostgreSQL 17 en
      CI ; deux resets et le contrôle des types sont stables.
- [x] Les documents et `KI-021` décrivent uniquement les capacités réellement
      prouvées ; l'admission de données réelles reste bloquée tant que sauvegarde,
      restauration et replay ne sont pas implémentés.

## Security review

- actifs/données : identité Auth, état de compagnie, export portable, demande et
  preuve de suppression ;
- frontière : appelant non fiable vers commande serveur privilégiée, puis
  transaction PostgreSQL/Auth ;
- abus : suppression de B par A, export croisé, contournement de
  réauthentification, rejeu, collision de clé, course demande/annulation/purge,
  fuite dans logs ou marqueur ;
- validation/autorisation : identité issue du contexte serveur,
  réauthentification récente non déclarative, RLS forcée et privilèges minimaux ;
- atomicité/idempotence : transaction unique par transition, verrouillage du
  compte, clé liée à l'acteur/opération/payload et rollback injecté ;
- logs/vie privée : codes et identifiants techniques aléatoires uniquement,
  jamais contenu exporté, email, JWT, nom de compagnie ou identifiant Auth
  durable dans le marqueur final.

## Automated validation

Commandes attendues après passage en `Ready` :

```powershell
pnpm backend:check
pnpm data-policy:check
pnpm backend:start
pnpm backend:reset
pnpm backend:reset
pnpm backend:test
pnpm backend:types:check
pnpm backend:stop
```

La preuve finale doit inclure le nombre exact de fichiers pgTAP découverts et le
résultat `PASS`. Le démarrage Windows peut rester bloqué par `KI-017`, mais les
preuves PostgreSQL 17 de CI sont obligatoires avant `Review`.

## Manual verification

1. Sur une pile PostgreSQL 17 jetable avec seeds synthétiques, demander l'export
   et la suppression de A après la réauthentification approuvée.
2. Simuler la perte de réponse, rejouer la même clé et confirmer le même résultat
   logique sans double effet.
3. Confirmer que B et l'anonyme ne voient aucune donnée ou existence exploitable
   concernant A.
4. Tester l'annulation pendant le délai, puis une nouvelle demande et
   l'expiration simulée.
5. Injecter une erreur avant commit et confirmer que l'identité, la compagnie et
   l'état de cycle de vie restent cohérents.

Temps cible : 10 minutes.

## Rollback

Avant fusion, abandonner la branche. Après application de la migration dans un
environnement jetable, recréer la pile depuis zéro. Une migration fusionnée ne
sera jamais modifiée ou supprimée : toute correction utilisera une nouvelle
migration append-only. Aucun rollback destructif n'est autorisé sur une pile
contenant des données réelles.

## Completion Report

### Summary

Implémentation terminée et validations automatisées prêtes à revoir. La
migration append-only ajoute un cycle récupérable de 7 jours, un export JSON
versionné avec SHA-256, une réauthentification serveur de 5 minutes, une
annulation et une finalisation service-only. Le ticket passe en `Verify` le
31 juillet 2026 : la checklist manuelle Windows reste bloquée par `KI-017`.

### Files changed

- `supabase/migrations/20260731000100_account_lifecycle.sql` ;
- `supabase/tests/database/account_lifecycle.test.sql` ;
- `supabase/tests/database/account_lifecycle_structure.test.sql` ;
- `packages/database/src/database.types.ts` ;
- `scripts/ci/test-backend.ps1` ;
- `tests/backend/run.ps1` ;
- `eng/data-policy.json` et `tests/data-policy/run.ps1` ;
- documents de politique, architecture, sécurité, qualité, état et suivi.

### Commands and results

- `pnpm backend:check` — réussi ; dépôt T0012/T0018 et 3 mutations négatives,
  dont une finalisation rendue exécutable par `authenticated`.
- `pnpm data-policy:check` — réussi après synchronisation ; dépôt T0017/T0018 et
  4 mutations négatives, dont une dérive du statut `accountDeletion`.
- analyse syntaxique PowerShell 7.6 de `scripts/ci/test-backend.ps1` — réussie.
- `pnpm backend:start` avant démarrage Docker — échoué, moteur Linux absent.
- Docker Desktop 29.6.2 démarré, puis `pnpm backend:start` — fail-safe réussi :
  publication hors loopback détectée, pile arrêtée et 0 conteneur Supabase actif.
- GitHub `30616958479`, job `Supabase PostgreSQL 17` — réussi : 2 resets,
  migrations rejouées, 4 fichiers pgTAP, 70 assertions, `Result: PASS`, deux
  sessions concurrentes → 1 demande/2 enregistrements d'idempotence, types
  stables et arrêt garanti.
- GitHub `30616958489`, job `Audits, licences and SBOM` — réussi.
- `git diff --check` et `git diff --cached --check` — réussis aux publications
  intermédiaires.

### Manual verification result

Non exécutée sur Windows. Docker Desktop 29.6.2 reproduit `KI-017` et le
fail-safe interdit correctement de conserver la pile exposée. Les cinq scénarios
de la checklist sont automatisés sur PostgreSQL 17 CI, mais cette preuve ne doit
pas être requalifiée en vérification manuelle. Le ticket reste `Verify`.

### Risks and limitations

- aucun appelant applicatif ou écran desktop n'est livré ;
- staging/production ne sont pas provisionnés et aucune donnée réelle n'est
  admise ;
- sauvegarde managée, restauration isolée et replay des suppressions restent
  absents ;
- le marqueur final permet l'idempotence du finaliseur à partir d'un jeton de
  requête aléatoire, mais T0018 ne prétend pas restaurer une base antérieure ;
- le contrôle manuel dépend d'un runtime Docker Windows respectant le loopback.

### Follow-ups

- T0019 : restauration PostgreSQL 17 isolée et replay des suppressions T0018 ;
- KI-017/T0012 : runtime Windows loopback, Studio et redémarrage sûr ;
- futur ticket frontend : UX d'export, confirmation et annulation, après
  stabilisation de la frontière backend.

### Documentation updated

- `docs/DATA_POLICY.md`, `docs/ARCHITECTURE.md`, `docs/SECURITY.md` et
  `docs/QUALITY.md` décrivent la frontière prouvée et ses limites ;
- `docs/CURRENT_STATE.md` distingue local/CI, PR, vérification manuelle et
  admission de données ;
- `docs/KNOWN_ISSUES.md` conserve `KI-021` ouvert uniquement pour
  sauvegarde/restauration/replay ;
- `docs/tickets/README.md` synchronisé avec le statut `Verify`.

### Mise à jour T0021 — 31 juillet 2026

`KI-017` est résolu. Les quatre fichiers et 70 assertions T0018 sont inclus dans
le run local Windows de 8 fichiers/148 assertions, avec deux resets et types
stables. La checklist humaine export/suppression/annulation n'a pas été exécutée
et T0018 reste `Verify`.
