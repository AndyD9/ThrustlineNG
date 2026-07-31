# T0019 — Restaurer sans ressusciter un compte supprimé

Status: In progress
Owner: Andy
Branch: `security/T0019-isolated-restore-replay`
Phase: 2
Risk: High
Security-sensitive: Yes

## Goal

Prouver sur PostgreSQL 17 qu'une sauvegarde synthétique peut être restaurée dans
une cible isolée, puis recevoir de façon transactionnelle et idempotente les
suppressions T0018 postérieures au point de sauvegarde avant toute réouverture.

## Context

T0018 supprime transactionnellement l'identité Auth et la compagnie, puis
conserve un marqueur non personnel. Ce marqueur ne suffit toutefois pas à
retrouver, dans une sauvegarde antérieure à la demande, le compte qui ne doit pas
être remis en service. T0017 exige une restauration fermée aux utilisateurs, un
contrôle d'intégrité et le replay des suppressions avant réouverture.

T0019 ajoute donc avant sauvegarde un identifiant de restauration aléatoire et
opaque, sans email ni identifiant Auth dans le journal final. Ce jeton reste une
donnée personnelle pseudonymisée tant qu'une sauvegarde couverte permet de le
relier au compte ; le journal doit donc rester protégé et borné par la rétention
des sauvegardes. La finalisation T0018 produit un événement pseudonyme exportable
hors de la sauvegarde. Une commande privilégiée applique cet événement sur la
cible restaurée et échoue fermée s'il est inconnu ou altéré.

La branche est empilée sur `security/T0018-account-lifecycle`, non fusionnée au
début du ticket. La PR T0019 doit donc cibler cette branche jusqu'à intégration de
T0018, puis être rebasée ou changer de base sans force-push.

Références :

- `docs/DATA_POLICY.md` ;
- `docs/SECURITY.md` ;
- `docs/ARCHITECTURE.md` ;
- `docs/QUALITY.md` ;
- `docs/KNOWN_ISSUES.md` (`KI-021`) ;
- `docs/tickets/T0018-export-suppression-compte.md`.

## Dependencies

- T0018 — export et suppression de compte (`Verify`, implémentation présente sur
  la branche parente) ;
- T0017 — politique de données (`Done`) ;
- PostgreSQL 17 réel et pile Supabase jetable de la CI T0013.

## Allowed areas

- `supabase/migrations/` — une nouvelle migration append-only uniquement ;
- `supabase/tests/database/` — pgTAP T0019 ;
- `tests/backend/` — invariants statiques et mutations négatives T0019 ;
- `scripts/ci/test-backend.ps1` — exercice réel dump/restore/replay isolé ;
- `eng/data-policy.json` et `tests/data-policy/` — statut exact des capacités
  prouvées ;
- `docs/ARCHITECTURE.md`, `docs/SECURITY.md`, `docs/DATA_POLICY.md`,
  `docs/QUALITY.md`, `docs/CURRENT_STATE.md`, `docs/KNOWN_ISSUES.md` ;
- ce ticket et `docs/tickets/README.md`.

## Do not touch

- migrations T0012 et T0018 existantes ;
- `supabase/seed.sql` sauf preuve synthétique strictement indispensable ;
- `apps/desktop/`, `apps/bridge/`, SimConnect et le contrat local ;
- grand livre, flotte, vols, économie ou progression ;
- projet Supabase distant, staging, production, secrets ou données réelles ;
- sauvegarde managée, chiffrement fournisseur, rétention automatique ou
  restauration d'objets Storage ;
- réouverture ou promotion automatique d'une cible restaurée ;
- workflows GitHub et permissions CI.

## Requirements

### 1. Identité de restauration antérieure à la sauvegarde

- Chaque compagnie existante et future possède un identifiant de restauration
  généré côté serveur avant toute sauvegarde couverte.
- Cet identifiant n'est ni choisi ni lisible par `anon` ou `authenticated`.
- La correspondance avec l'identité Auth reste privée et disparaît avec le
  compte actif.
- Le journal final ne contient ni email, nom de compagnie, export, JWT, secret,
  identifiant Auth direct ou identifiant de compagnie direct, mais reste classé
  comme donnée personnelle pseudonymisée tant qu'une sauvegarde couverte existe.

### 2. Événement de suppression exportable

- La finalisation T0018 écrit dans la même transaction un événement pseudonyme
  versionné liant l'identifiant opaque, le marqueur T0018 et la date de
  suppression.
- Une erreur avant commit ne laisse ni faux événement ni suppression partielle.
- Une extraction privilégiée peut obtenir les événements strictement postérieurs
  au point de sauvegarde, sans accès des rôles clients.
- Le format exporté est déterministe, borné et validable avant replay.

### 3. Replay fermé, transactionnel et idempotent

- Le replay est réservé à `service_role` et destiné uniquement à une cible
  restaurée fermée aux utilisateurs.
- Un événement valide supprime la correspondance restaurée, la compagnie,
  l'identité Auth et les liens temporaires T0018 dans une transaction.
- Le même événement rejoué rend le même résultat sans double effet.
- Un événement de même identifiant mais au contenu différent est rejeté.
- Un événement inconnu ou incomplet échoue fermé et ne modifie aucune donnée.
- Un autre propriétaire présent dans la sauvegarde reste intact.

### 4. Exercice PostgreSQL 17 réel

- La CI crée une identité et une compagnie synthétiques, prend un dump avant la
  demande de suppression, finalise la suppression dans la source, puis restaure
  le dump dans une base distincte du même moteur PostgreSQL 17.
- Le dump logique est borné aux schémas applicatifs et Auth nécessaires
  (`auth`, `public`, `private`, `extensions`, `supabase_migrations`) ; il exclut
  notamment les secrets Vault et ne prétend pas restaurer tous les services
  Supabase.
- Les ACL des objets existants sont restaurées. Les seules entrées d'archive
  exclues sont les `DEFAULT ACL` appartenant aux rôles internes Supabase, que le
  rôle `postgres` durci ne peut pas modifier ; cette cible fermée n'est donc pas
  apte à créer de futurs objets Auth ni à être promue.
- Les objets appartenant à l'extension `pgcrypto` ne figurent pas dans le dump
  logique. L'exercice réinstalle l'extension depuis la même image PostgreSQL 17
  et refuse le replay si sa version diffère de la source.
- La base restaurée n'est pas servie par l'API Supabase et n'est jamais promue.
- Le journal post-sauvegarde est extrait de la source puis appliqué sur la cible.
- L'exercice confirme migrations, RLS, absence de résurrection, préservation du
  propriétaire témoin, idempotence et rejet d'une altération.
- Le rapport consigne point de sauvegarde, nombre d'événements, durées de dump,
  restauration et replay, résultat et limites, sans credential ni donnée
  personnelle.
- La base restaurée, le dump et le journal temporaire sont détruits même après
  échec.

## Non-goals

- sauvegarde Supabase managée ou preuve de chiffrement fournisseur ;
- RPO/RTO de production, haute disponibilité ou plan de reprise complet ;
- données réelles, staging, production ou projet distant ;
- purge des rétentions glissantes et anonymisation du futur grand livre ;
- restauration Supabase Storage ;
- interface utilisateur, commande desktop ou réouverture automatique ;
- clôture de T0012, T0018 ou admission de données utilisateur réelles.

## Acceptance criteria

- [ ] Une migration append-only attribue une identité opaque aux compagnies
      existantes et futures sans l'exposer aux rôles clients.
- [ ] La finalisation T0018 et son événement de replay restent atomiques.
- [ ] Le journal final est versionné, classé pseudonyme et ne contient aucune
      identité directe ni contenu exporté.
- [ ] Le replay `service_role` est idempotent, rejette une altération et échoue
      fermé sur un événement inconnu.
- [ ] Les pgTAP couvrent privilèges, RLS, A/B, rollback et invariants de format.
- [ ] PostgreSQL 17 restaure un dump pris avant la demande, rejoue l'événement et
      prouve que A ne ressuscite pas tandis que B reste intact.
- [ ] Le harnais détruit la base, le dump et le journal temporaires dans un bloc
      de nettoyage garanti.
- [ ] Deux resets, tous les pgTAP découverts, la concurrence T0018, les types et
      le nouvel exercice de restauration passent en CI.
- [ ] La politique marque restauration/replay comme prouvés uniquement en
      local/CI synthétique ; sauvegardes managées et admission réelle restent
      bloquées.

## Security review

- actifs/données : identité Auth, compagnie, demande/export T0018, correspondance
  opaque de restauration, journal de suppression et dump synthétique ;
- frontière : source PostgreSQL privilégiée vers journal expurgé, puis journal
  vers cible restaurée fermée ;
- abus : résurrection après restauration, événement forgé ou altéré, replay
  croisé, suppression de B, exposition du dump, réouverture avant replay ;
- validation/autorisation : tables privées avec RLS forcée, aucun privilège
  client, fonctions à `search_path` vide et exécution `service_role` seulement ;
- atomicité/idempotence : événement écrit avec la suppression source, replay
  verrouillé avec comparaison exacte et rollback intégral sur échec ;
- logs/vie privée : UUID/hash/date/version et mesures techniques uniquement,
  jamais email, nom, identifiant Auth/compagnie, export, JWT ou credential ; le
  journal pseudonyme reste protégé jusqu'à expiration des sauvegardes couvertes.

## Automated validation

```powershell
pnpm backend:check
pnpm data-policy:check
pnpm backend:start
pnpm backend:reset
pnpm backend:reset
pnpm backend:test
pnpm backend:types:check
pnpm backend:stop
pnpm ci:backend
```

La preuve finale doit donner le nombre exact de fichiers et d'assertions pgTAP,
le résultat `PASS`, puis le résultat explicite de l'exercice
dump/restore/replay. Le démarrage Windows peut rester bloqué par `KI-017` ; la
preuve PostgreSQL 17 CI reste obligatoire avant `Review`.

## Manual verification

1. Sur PostgreSQL 17 jetable et synthétique, créer A et B puis prendre un dump
   avant la demande de suppression de A.
2. Finaliser A dans la source et extraire le journal postérieur au point choisi.
3. Restaurer le dump dans une base distincte non servie par l'API, appliquer le
   journal et confirmer l'absence de A ainsi que la présence intacte de B.
4. Rejouer le même journal, puis un événement altéré et un événement inconnu ;
   confirmer respectivement le même résultat et deux échecs sans mutation.
5. Confirmer la destruction de la cible, du dump et du journal temporaires.

Temps cible : 10 minutes.

## Rollback

Avant fusion, abandonner la branche. Après application sur une pile jetable,
recréer la pile depuis zéro. Une migration fusionnée n'est jamais modifiée ni
supprimée : toute correction utilise une nouvelle migration append-only. Aucun
rollback destructif n'est autorisé sur une pile contenant des données réelles.

## Completion Report

À remplir après implémentation.

### Summary

### Files changed

### Commands and results

### Manual verification result

### Risks and limitations

### Follow-ups

### Documentation updated
