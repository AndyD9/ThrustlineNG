# F0007 — Mesurer un vol sans harnais externe

Status: Draft
Owner: Unassigned
Branch: `feature/f0007-mesurer-un-vol-sans-harnais-externe`
Phase: 3–4
Risk: Medium
Security-sensitive: Yes
Autonomous: No

## Goal

La personne qui installe l'alpha et déroule le golden path voit un temps de bloc
mesuré **sans rien lancer d'autre que l'application** — aujourd'hui la mesure
n'apparaît qu'avec un harnais externe.

## Context

KI-027, constatée le 7 août 2026 pendant la vérification manuelle de F0004 J3.
Trois maillons manquent au câblage, et il suffit d'un seul pour que la chaîne
reste morte :

- `apps/desktop/src-tauri/src/bridge.rs` lance le bridge avec `--port` et rien
  d'autre : aucune `--telemetry-trace`, aucune `--telemetry-source` ;
- `TelemetryAdapterFactory.TryCreate` rend `null` sans `--telemetry-trace`,
  donc aucun adaptateur n'existe ;
- `TelemetryPublisher.PublishAsync` attend `_firstSubscriber`
  (`apps/bridge/Telemetry/TelemetryPublisher.cs:168`) avant de lire la trace, et
  rien dans l'application ne crée cet abonné SignalR.

Résultat : le résumé de vol reste `idle` dans l'alpha telle qu'assemblée, et
l'affichage F0004 J3 n'a rien à montrer. Le parcours manuel du 7 août n'a abouti
qu'avec un wrapper `THRUSTLINE_BRIDGE_PATH` injectant
`tests/traces/synthetic-golden-flight.jsonl` **et** un abonné WebSocket externe.

F0006 a rendu le tracker réarmable et rattaché la mesure à son vol ; F0002
consomme cette mesure pour la clôture. Le seul trou restant entre « l'alpha
cliquable » et « l'alpha qui mesure » est celui-ci.

## Décisions réservées à Andy

Aucun jalon ne démarre avant la première : elle détermine les deux autres.

1. **D'où vient la trace de l'alpha ?** Trois options, exclusives :
   - **A — trace dorée embarquée** : `synthetic-golden-flight.jsonl` devient une
     ressource du package, le superviseur la passe au bridge. L'alpha mesure
     toujours le même vol synthétique. Le plus simple, le moins réaliste.
   - **B — trace choisie par la personne** : l'application ouvre un sélecteur de
     fichier. Réaliste, mais ouvre une frontière d'entrée utilisateur vers le
     bridge et un accès au système de fichiers que le shell n'a pas aujourd'hui
     (capability vide, aucun plugin Tauri).
   - **C — pas de trace du tout** : l'alpha assume `idle` et n'affiche la mesure
     que sous MSFS réel (F0003/T0059). Repousse la capacité hors de l'alpha.
2. **Qui crée le premier abonné** : le superviseur Rust, ou la WebView via une
   commande ? Le superviseur garde le jeton et le port privés — c'est l'option
   qui n'élargit pas la surface IPC.
3. **La trace se rejoue-t-elle en temps réel ou accéléré ?** Un vol synthétique
   d'une minute de temps de bloc ne doit pas immobiliser la personne une minute
   à chaque essai — mais une cadence accélérée change ce que la mesure prouve.

## Dependencies

- F0004 fusionnée — mesure, contrat local, commande `flight_summary` ;
- F0006 fusionnée — générations réarmables et rattachement au dispatch ;
- **décision d'Andy sur l'origine de la trace : non prise** — veto d'autonomie ;
- T0054 : l'invariant « le bridge ne connaît ni compagnie, ni dispatch, ni grand
  livre » ne bouge pas.

## Allowed areas

- `apps/desktop/src-tauri/src/bridge.rs` et le superviseur ;
- `apps/bridge/` — publication de télémétrie et adaptateur replay ;
- `tests/bridge/`, `tests/desktop-shell/run.ps1`, `apps/desktop/src/test/` ;
- `apps/desktop/src-tauri/tauri.package.conf.json` si la trace devient ressource ;
- `docs/SECURITY.md`, `docs/ARCHITECTURE.md`, `docs/QUALITY.md`,
  `docs/CURRENT_STATE.md`, `docs/KNOWN_ISSUES.md` pour clore KI-027 ;
- ce fichier et `docs/features/README.md`.

## Do not touch

- La CSP par canal de F0005 : aucune origine nouvelle ;
- le jeton et le port du contrat local : ils restent privés au superviseur ;
- l'autorité serveur : la mesure reste informative, le serveur conserve
  `min(déclaré, écoulé)` (T0051).

## Non-goals

- MSFS réel et SimConnect natif : F0003 et T0059 ;
- la détection de phases de vol, la reprise après crash ;
- la persistance du rattachement au redémarrage (limite connue de F0006).

## Jalons

### J1 — Le bridge produit une mesure sans abonné externe

Status: Draft
Risk: Medium
Security-sensitive: No
Autonomous: No

- résultat : lancé avec une trace, le bridge mesure sans attendre qu'un abonné
  SignalR externe se présente. La diffusion `telemetry.v1` reste inchangée pour
  les abonnés réels ; c'est l'attente bloquante de `_firstSubscriber` sur le
  chemin de la mesure qui disparaît.
- frontière : `TelemetryPublisher`, adaptateur replay.
- validations : `pnpm bridge:test`, `pnpm bridge:build`.
- revue : chercher toute régression de la borne de cadence, de l'abandon d'un
  abonné lent, et tout échantillon émis hors des bornes T0054.

### J2 — Le superviseur fournit la trace du canal

Status: Draft
Risk: Medium
Security-sensitive: Yes
Autonomous: No

- résultat : le superviseur Tauri lance le bridge avec la source de trace
  décidée en décision 1, sans exposer ni jeton ni chemin à la WebView. Un
  contrôle déterministe échoue si la WebView peut influencer ce chemin.
- frontière : superviseur Rust, packaging si la trace devient une ressource.
- validations : `pnpm desktop:check`, `pnpm desktop:test`,
  `pnpm windows:package:check`.
- revue : chercher tout chemin par lequel une entrée utilisateur atteindrait
  l'argument de trace, et toute lecture de fichier hors du périmètre décidé.

### J3 — L'alpha installée mesure son vol

Status: Draft
Risk: Low
Security-sensitive: No
Autonomous: No

- résultat : le golden path déroulé dans l'application installée affiche un
  temps de bloc mesuré et clôture dessus, sans aucun processus externe. Clôt
  KI-027.
- frontière : parcours humain.
- validations : parcours manuel consigné, `pnpm maintenance:check`.
- revue : vérifier que la mesure affichée est bien celle du vol clôturé, deux
  vols d'affilée (invariant F0006).

## Acceptance criteria

- [ ] Le golden path dans l'alpha installée affiche un temps de bloc mesuré sans
      harnais externe.
- [ ] La clôture consomme cette mesure, rattachée au vol clôturé.
- [ ] La WebView ne peut influencer ni le chemin de trace, ni le jeton, ni le
      port, prouvé par un contrôle déterministe.
- [ ] Deux vols d'affilée restent correctement attribués.
- [ ] KI-027 passe `Resolved` en référençant F0007.

## Security review

Jalon concerné : **J2**.

- actifs/données : chemin de trace, jeton et port du contrat local ;
- frontière : WebView ↔ superviseur Tauri ↔ bridge ;
- abus : une WebView compromise qui ferait lire un fichier arbitraire au bridge
  en influençant l'argument de trace ; une trace pointant hors du périmètre ;
- validation/autorisation : le chemin de trace est décidé par le superviseur,
  jamais reçu de la WebView ; contrôle déterministe avec mutation négative ;
- atomicité/idempotence : sans objet (lecture) ;
- logs/vie privée : aucun chemin local ni jeton journalisé.

## Maintenance review

- dettes et problèmes connus applicables : KI-027 (close par cette unité) ;
- dette créée ou aggravée : si l'option A est retenue, l'alpha embarque une
  trace synthétique qu'il faudra retirer quand MSFS réel arrivera ;
- règle de sécurité ajoutée : origine du chemin de trace dans `SECURITY.md` ;
- contrôle manuel à automatiser : la preuve qu'aucun abonné externe n'est requis ;
- risque résiduel : une mesure synthétique peut être prise pour une mesure
  réelle — l'affichage doit dire ce qu'il mesure.

## Automated validation

```powershell
pnpm bridge:build
pnpm bridge:test
pnpm desktop:check
pnpm desktop:test
pnpm windows:package:check
pnpm maintenance:check
```

## Manual verification

1. J1 : lancer le bridge avec une trace, sans abonné, et constater que
   `GET /api/v1/flight-summary` atteint `completed`.
2. J2 : lancer l'application, constater que le bridge reçoit la trace décidée et
   qu'aucun chemin ne traverse vers la WebView.
3. Bout en bout : dérouler le golden path dans l'alpha installée, deux vols
   d'affilée, sans processus externe.

## Rollback

Retirer l'argument de trace du superviseur rend l'alpha à son état actuel :
résumé `idle`, aucune mesure sans harnais. Aucune donnée concernée.

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
