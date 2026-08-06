# F0004 — Voir le temps de bloc mesuré de son vol en replay

Status: Draft
Owner: Unassigned
Branch: `feature/f0004-mesurer-le-temps-de-bloc-du-vol-replay`
Phase: 3–4
Risk: Medium
Security-sensitive: Yes
Autonomous: No

## Goal

À la fin d'un vol joué en replay, la personne voit dans l'application le temps
de bloc mesuré par la télémétrie — la valeur qui alimentera le rapport de
clôture, au lieu d'une saisie manuelle.

## Context

La décision d'Andy du 6 août 2026 (option C, consignée dans F0002) : le temps de
vol d'un rapport de clôture vient de la télémétrie, jamais d'une saisie ni d'une
migration. Or rien ne relie aujourd'hui la télémétrie au cycle de vol : T0054
publie `telemetry.v1` sur le contrat local du bridge (SignalR loopback, jeton
d'instance détenu par Tauri et jamais exposé à la WebView), et F0001 fait
décoller un vol sans rien savoir de la télémétrie. F0002 est `Blocked` sur ce
chaînon : cette fonctionnalité est le chemin critique du jalon « alpha
cliquable ».

Le serveur reste l'autorité finale : `close_flight` retient
`min(temps déclaré, temps écoulé serveur)` (T0051). Le temps de bloc mesuré ici
est donc une **déclaration mieux fondée**, pas une autorité nouvelle — un client
trafiqué qui surdéclare ne gagne rien, exactement comme pour une saisie.

Trois frontières existantes cadrent la solution : le bridge voit les
échantillons (c'est lui qui mesure) ; le processus Tauri détient le jeton du
contrat local (c'est lui qui interroge le bridge) ; la WebView n'a jamais accès
ni au jeton ni au port (elle reçoit un résumé typé par commande Tauri).

## Décision attendue d'Andy

**Comment le temps de bloc est-il mesuré sur une trace replay ?** Proposition :
du premier échantillon en mouvement (vitesse sol non nulle ou airborne) au
dernier retour au sol de la trace, arrondi à la minute supérieure, minimum une
minute ; une trace sans retour au sol rend un état « incomplet » sans temps de
bloc. Condition de sortie : la décision est reportée datée ici, puis le statut
passe `Ready`.

## Dependencies

- T0054 — télémétrie replay bornée sur le contrat local (`Done`) ;
- T0010 — contrat local REST/SignalR à jeton (`Done`) ;
- F0001 — départ de vol depuis l'application (fusionnée, PR #124/#126) ;
- décision d'Andy ci-dessus : non prise.

## Allowed areas

- `apps/bridge/` — mesure du temps de bloc et exposition additive sur le
  contrat local, avec ses tests ;
- `apps/desktop/src-tauri/` — commande Tauri de lecture du résumé, le jeton
  restant côté Rust ;
- `apps/desktop/src/features/flight-dispatch/` — affichage du résumé rattaché
  au vol actif ;
- `tests/backend/run.ps1` seulement si une règle de gate est ajoutée ;
- `docs/SECURITY.md`, `docs/ARCHITECTURE.md`, `docs/QUALITY.md`,
  `docs/CURRENT_STATE.md`, `docs/KNOWN_ISSUES.md` ;
- ce fichier et `docs/features/README.md`.

## Do not touch

- `public.close_flight`, le barème de règlement et le grand livre : la
  consommation du temps mesuré dans un rapport de clôture appartient à F0002 ;
- le protocole `telemetry.v1`, sa cadence et ses bornes T0054 ;
- l'adaptateur SimConnect natif et T0059/F0003 ;
- toute cible distante, toute donnée réelle.

## Non-goals

- clôturer le vol ou créer le rapport : F0002, débloquée par cette capacité ;
- détection fine des phases de vol, reprise après crash, persistance d'un vol ;
- télémétrie MSFS réelle : la source replay est le périmètre de l'alpha ;
- associer plusieurs vols ou plusieurs sources : un vol actif, une trace, un
  résumé — l'alpha est mono-vol par construction (contrainte T0050).

## Jalons

### J1 — Le bridge mesure le temps de bloc d'une trace replay

Status: Draft
Risk: Medium
Security-sensitive: No
Autonomous: Yes

- résultat : le bridge dérive des échantillons replay un résumé de vol —
  état (`idle`, `running`, `completed`, `incomplete`), temps de bloc en
  minutes selon la règle décidée par Andy — et l'expose en lecture seule,
  additive et versionnée, sur le contrat local existant, derrière le même
  jeton. Aucun échantillon n'est persisté.
- frontière : contrat local du bridge (T0010/T0054).
- validations : `pnpm bridge:build`, `pnpm bridge:test` (scénarios : trace
  nominale, trace sans retour au sol, trace vide, arrondi et minimum),
  `pnpm bridge:health`, budgets de performance.
- revue : chercher une divergence entre la règle décidée et la mesure, et
  toute fuite du chemin de trace ou du jeton dans le résumé.

### J2 — Tauri relaie le résumé sans exposer le contrat local

Status: Draft
Risk: Medium
Security-sensitive: Yes
Autonomous: No

- résultat : une commande Tauri lit le résumé sur le contrat local — le jeton
  et le port restent côté Rust — et rend à la WebView un objet typé strictement
  validé. La WebView n'apprend ni le port, ni le jeton, ni le chemin de trace.
- frontière : frontière de confiance Tauri ↔ WebView.
- validations : `pnpm desktop:check`, `pnpm desktop:test` (dont un test qui
  prouve que le jeton ne traverse pas), `pnpm frontend:typecheck`.
- revue : chercher tout chemin par lequel la WebView atteindrait le contrat
  local directement ou apprendrait le jeton.

### J3 — L'application affiche le temps de bloc du vol actif

Status: Draft
Risk: Low
Security-sensitive: No
Autonomous: Yes

- résultat : quand un vol est `active` et que le replay est terminé, la ligne
  du vol affiche le temps de bloc mesuré, prêt pour la clôture F0002 ; aucun
  appel au rendu, états explicites (en cours, terminé, incomplet,
  indisponible).
- frontière : desktop React.
- validations : `pnpm frontend:typecheck`, `pnpm frontend:test`,
  `pnpm frontend:coverage`, `pnpm frontend:build`, `pnpm authority:check`.
- revue : vérifier que l'affichage vient exclusivement du résumé typé et
  qu'aucun temps n'est calculé dans la WebView.

## Acceptance criteria

- [ ] Une trace replay jouée de bout en bout produit un temps de bloc conforme
      à la règle décidée, visible dans l'application sur le vol actif.
- [ ] Une trace sans retour au sol rend un état « incomplet » explicite, sans
      temps de bloc inventé.
- [ ] Le jeton d'instance et le port du contrat local ne traversent jamais la
      frontière WebView, prouvé par un test.
- [ ] Le résumé est additif sur le contrat local : les consommateurs T0054
      existants sont inchangés.
- [ ] La documentation décrit la capacité et ses limites (mesure replay
      uniquement, un vol à la fois, serveur toujours autorité du règlement).

## Security review

Jalon concerné : **J2**.

- actifs/données : jeton d'instance du contrat local, port loopback ;
- frontière : Tauri ↔ WebView (la WebView est un client non fiable) ;
- abus : exfiltrer le jeton ou le port par la commande, faire interroger une
  autre cible que le bridge de l'instance, injecter un résumé forgé ;
- validation/autorisation : commande sans paramètre de cible, réponse validée
  par jeu de clés strict avant de traverser ;
- atomicité/idempotence : lecture seule, sans effet ;
- logs/vie privée : ni jeton, ni port, ni chemin de trace dans les logs ou la
  WebView.

## Maintenance review

- dettes et problèmes connus applicables : `KI-009`, `KI-011`, `KI-015`
  (télémétrie réelle absente — inchangés, cette capacité est replay) ;
- dette créée ou aggravée : le résumé de vol est une deuxième lecture dérivée
  de la même trace ; si T0059 introduit la source native, la règle de mesure
  doit être revalidée sur des échantillons réels ;
- règle de sécurité ajoutée : la frontière Tauri ↔ WebView du résumé dans
  `SECURITY.md` ;
- contrôle manuel à automatiser : la mesure sur trace nominale est un test
  unitaire dès J1 ;
- risque résiduel : le temps mesuré reste une déclaration côté client du point
  de vue du serveur ; `min(déclaré, écoulé)` de T0051 reste la borne.

## Automated validation

```powershell
pnpm bridge:build
pnpm bridge:test
pnpm bridge:health
pnpm desktop:check
pnpm desktop:test
pnpm frontend:typecheck
pnpm frontend:test
pnpm frontend:coverage
pnpm frontend:build
pnpm authority:check
pnpm maintenance:check
```

## Manual verification

1. J1 : rejouer la trace synthétique T0011 et relever le résumé sur le contrat
   local (jeton requis) ; vérifier l'état `incomplete` sur une trace tronquée.
2. J2 : depuis la WebView dev, appeler la commande et confirmer qu'aucun jeton
   ni port n'apparaît dans le résultat ni dans les outils réseau.
3. J3 : parcours complet — départ F0001, replay joué, temps de bloc affiché
   sur le vol actif.

## Rollback

Avant fusion, abandonner la branche. Après fusion, retirer le résumé, la
commande et l'affichage laisse T0054 et F0001 exactement dans leur état
actuel ; aucune donnée n'est persistée par cette capacité. Retour partiel
cohérent après chaque jalon.

## Completion Report

Un bloc par jalon, rempli au moment de son commit, puis une synthèse.

### J1

- résultat obtenu :
- fichiers modifiés :
- commandes et résultats :
- vérification manuelle :
- revue et constats traités :

### J2

- résultat obtenu :
- fichiers modifiés :
- commandes et résultats :
- vérification manuelle :
- revue et constats traités :

### J3

- résultat obtenu :
- fichiers modifiés :
- commandes et résultats :
- vérification manuelle :
- revue et constats traités :

### Synthèse

### Risks and limitations

### Follow-ups

### Documentation updated
