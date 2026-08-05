# T0067 — Rendre récupérable la pile Supabase locale après un arrêt brutal du moteur

Status: Draft
Owner: Unassigned
Branch: `chore/T0067-cache-moteur-supabase-local`
Phase: 1
Risk: Medium
Security-sensitive: Yes

## Goal

Un arrêt brutal du moteur Docker isolé ne bloque plus `pnpm backend:start`, et la
documentation décrit le contenu réel du volume conservé, sans affaiblir l'isolation
loopback prouvée par T0021.

## Context

`KI-026`. Dans `origin/main` au commit `c0f16dc`,
`scripts/start-supabase-local.ps1` ligne 50 monte le volume
`thrustline-local-engine-cache` sur `/var/lib/docker` du moteur DinD. Ce chemin
contient l'ensemble de l'état du moteur interne : images, mais aussi conteneurs,
volumes et réseaux de la pile Supabase interne. Le nom du volume, les messages
« isolated Supabase image cache » de `scripts/start-supabase-local.ps1` et de
`scripts/supabase-local-runtime.ps1`, et l'inventaire de `docs/CURRENT_STATE.md`
annoncent pourtant un simple cache d'images, et c'est cette description qui a servi
à décider de le conserver. L'inventaire est corrigé le 5 août 2026 par la clôture
d'apprentissage de la vague T0060 ; le nom et les messages du runtime restent à
traiter ici.

Conséquence observée le 5 août 2026 pendant T0060 : après un arrêt non propre du
moteur, la pile interne est retrouvée « already running » au démarrage suivant et
`pnpm backend:start` échoue jusqu'au retrait complet du volume, ce qui détruit aussi
le cache d'images et ramène le démarrage à un téléchargement complet. Le blocage a
été levé par les seules commandes du dépôt, sans manipulation Docker directe.

Le compromis est réel : conserver l'état interne accélère un redémarrage à froid,
mesuré à 45,5 s par T0021, mais le rend fragile. Le supprimer rend le démarrage
déterministe et plus lent.

## Décision réservée à Andy

Trois issues, qui ne coûtent pas la même chose :

- **A — séparer.** Conserver seulement un cache d'images réutilisable et repartir
  d'un état de conteneurs vide à chaque démarrage. Démarrage déterministe, coût en
  durée à mesurer contre les 45,5 s de référence.
- **B — conserver et récupérer.** Garder le volume tel quel et ajouter une reprise
  explicite qui détecte l'état « already running » et le résout sans détruire le
  cache d'images.
- **C — accepter.** Documenter le contenu réel du volume et la procédure de retrait
  complet, sans changer le runtime.

Condition de sortie : ce ticket reste `Draft` jusqu'à ce qu'Andy choisisse A, B ou
C. La réponse est reportée datée ici, et le ticket passe `Ready` seulement ensuite.
Ce choix touche l'outillage de preuve backend et la durée de toute validation
locale, donc il ne revient pas à un agent. L'issue C n'autorise aucune modification
de `scripts/`.

## Dependencies

- T0012 et T0021 — pile Supabase locale isolée, ports 54321 à 54323 publiés
  uniquement sur `127.0.0.1` (`Done`, présents dans `main`) ;
- `KI-017` — résolu par T0021 : son invariant loopback ne doit pas être affaibli ;
- `LC-2026-007` — un résidu n'est pas une pile occupée ; le diagnostic écrit dans
  `docs/QUALITY.md` reste valable et ce ticket ne le remplace pas ;
- décision d'Andy ci-dessus.

## Allowed areas

- `scripts/start-supabase-local.ps1`, `scripts/supabase-local-runtime.ps1` et
  `scripts/docker-tools.ps1` — seulement pour les issues A ou B ;
- `docs/QUALITY.md`, `docs/CURRENT_STATE.md`, `docs/KNOWN_ISSUES.md` ;
- ce ticket et `docs/tickets/README.md`.

## Do not touch

- publication des ports : elle reste explicitement limitée à `127.0.0.1` ;
- montage d'un socket Docker hôte, d'un dépôt complet ou d'une donnée réelle :
  interdits, quelle que soit l'issue ;
- migrations, fonctions SQL, pgTAP, types générés et Edge Functions ;
- `scripts/ci/test-backend.ps1` et les workflows GitHub ;
- frontend, desktop, bridge, packaging, toolchain, lockfiles ;
- projet Supabase distant, données réelles, secrets.

## Requirements

- L'issue retenue est appliquée entièrement, et le contenu réel du volume est
  décrit sans ambiguïté dans `docs/QUALITY.md` comme dans les messages du runtime,
  quelle que soit l'issue. Pour l'issue C, seuls les documents changent.
- Pour A ou B, deux `pnpm backend:start` successifs après un arrêt non propre du
  moteur réussissent sans intervention Docker manuelle, et la preuve est un relevé,
  pas une intention.
- L'isolation prouvée par T0021 est revérifiée après le changement : trois ports
  publiés uniquement sur `127.0.0.1`, aucun socket Docker hôte monté.
- La durée de démarrage à froid et à chaud est mesurée et comparée aux 45,5 s de
  T0021 ; une régression est consignée, pas dissimulée.
- Aucun contrôle n'est déclaré réussi s'il n'a pas tourné : un contrôle empêché par
  une pile réellement occupée est `bloqué par l'environnement`.

## Non-goals

- parité avec une pile Supabase managée ou un staging ;
- changement de version de Supabase CLI, de PostgreSQL ou de Docker Desktop ;
- accélération du démarrage au-delà de la mesure de non-régression ;
- nouvelle capacité produit, migration ou contrat.

## Acceptance criteria

- [ ] La décision d'Andy est reportée datée dans ce ticket avant toute
      implémentation.
- [ ] `docs/QUALITY.md` et les messages du runtime décrivent le contenu réel du
      volume conservé, sans le réduire à un cache d'images.
- [ ] Pour A ou B, un arrêt brutal simulé du moteur est suivi d'un
      `pnpm backend:start` réussi, avec le relevé des commandes.
- [ ] Les trois ports restent publiés uniquement sur `127.0.0.1` après le
      changement, relevé Docker et `Get-NetTCPConnection` à l'appui.
- [ ] Les durées de démarrage sont mesurées et comparées à la référence T0021.
- [ ] `KI-026` passe `Resolved` en citant ce ticket, ou `Accepted` avec le risque
      explicitement accepté par Andy si l'issue C est retenue.

## Security review

- actifs/données : état du moteur Docker isolé, base locale synthétique, ports
  loopback ;
- frontière : hôte Windows, moteur DinD privilégié, pile Supabase interne ;
- abus : élargir l'exposition réseau en refaisant le démarrage, monter le socket
  Docker hôte pour simplifier la reprise, conserver une base entre deux
  vérifications qui se croient isolées ;
- validation/autorisation : les invariants de T0021 restent contrôlés par le gate
  backend et par un relevé de sockets ;
- atomicité/idempotence : deux démarrages successifs doivent aboutir au même état
  observable ;
- logs/vie privée : aucune donnée réelle, aucun secret, aucun chemin utilisateur
  dans une sortie conservée.

## Maintenance review

- dettes et problèmes connus applicables : `KI-026` ouvre ce ticket ; `KI-017` fixe
  l'invariant loopback à préserver ; `KI-014` rappelle l'absence de parité cloud ;
- dette créée ou aggravée : l'issue B ajoute un chemin de reprise, donc du code de
  démarrage à maintenir ; l'issue A rallonge probablement le démarrage à froid ;
- règle de sécurité ajoutée, modifiée ou à revalider : aucune nouvelle, mais
  l'invariant loopback de T0021 doit être revalidé par ce ticket ;
- contrôle manuel à automatiser : la simulation d'un arrêt brutal du moteur mérite
  un scénario rejouable si l'issue B est retenue ;
- risque résiduel ou exception approuvée : à consigner selon l'issue retenue.

## Automated validation

```powershell
pnpm.cmd backend:check
pnpm.cmd backend:start
pnpm.cmd backend:reset
pnpm.cmd backend:test
pnpm.cmd backend:stop
pnpm.cmd maintenance:check
git diff --check
```

## Manual verification

1. Relever l'état du moteur et des ports 54321 à 54323 avant tout démarrage, selon
   la règle `LC-2026-007` de `docs/QUALITY.md`.
2. Démarrer la pile, mesurer la durée à froid puis à chaud.
3. Arrêter brutalement le moteur, puis relancer `pnpm backend:start` et consigner le
   résultat exact.
4. Confirmer que les trois ports restent publiés uniquement sur `127.0.0.1`.
5. Arrêter la pile et vérifier l'absence de conteneur résiduel.

Temps cible : 10–15 minutes, dominées par les démarrages.

## Rollback

Avant fusion, abandonner la branche. Après fusion, le retour en arrière est une
révision des seuls scripts de démarrage ; aucune donnée réelle ni migration n'est
concernée. Un retrait complet du volume reste toujours possible et ne détruit que
des données de développement synthétiques.

## Completion Report

À remplir après implémentation.

### Summary

### Files changed

### Commands and results

### Manual verification result

### Risks and limitations

### Follow-ups

### Documentation updated
