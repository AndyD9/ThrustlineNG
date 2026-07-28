# T0011 — Créer l'adaptateur SimConnect et le replay

Status: Verify
Owner: Andy
Branch: `foundation/t0011-simconnect-adapter`
Phase: 1–3
Risk: High
Security-sensitive: Yes

## Goal

Isoler le SDK SimConnect officiel derrière une frontière .NET testable et fournir
un replay de traces synthétiques versionnées qui fonctionne sans MSFS.

## Context

T0009 fournit le processus .NET 10 et T0010 le contrat local authentifié. Le
bridge ne possède encore aucune source de télémétrie. ADR-0004 impose que les
types du SDK restent confinés et qu'un replay existe avant le premier scénario
MSFS réel.

Le SDK MSFS 2024 n'est pas installé avec une provenance vérifiable sur la machine
de développement. Un ancien build contient des binaires SimConnect, mais ils ne
doivent être ni copiés ni publiés. Le ticket compile donc contre les signatures
natives documentées et charge `SimConnect.dll` uniquement à l'exécution.

## Dependencies

- T0009 et T0010 terminés.
- ADR-0003 et ADR-0004.
- `docs/ARCHITECTURE.md`, `docs/SECURITY.md` et `docs/QUALITY.md`.

## Allowed areas

- `apps/bridge/SimConnect/`.
- `tests/bridge/` et `tests/traces/`.
- projet bridge, solution et scripts racine strictement nécessaires.
- documentation et fichiers d'état du ticket.

## Do not touch

- frontend React, Tauri, capabilities et contrat local v1.
- Supabase, économie, rapport de vol et transitions métier.
- ancien dépôt ou binaires issus de l'ancien build.
- redistribution du SDK ou de `SimConnect.dll`.
- packaging, signature et updater.

## Requirements

1. Définir `ISimConnectAdapter` sans type SDK et un `FlightSample` immuable,
   borné, horodaté en UTC et séquencé.
2. Confiner tous les appels natifs dans `NativeSimConnectAdapter`.
3. Ouvrir SimConnect avec un handle d'événement et traiter les messages sur une
   boucle dédiée ; ne jamais appeler l'API depuis plusieurs threads.
4. Demander uniquement un jeu minimal de variables en lecture seule, une fois
   par seconde, pour l'objet utilisateur.
5. Fermer le handle même après annulation, déconnexion ou erreur.
6. Échouer de façon actionnable si Windows, MSFS ou `SimConnect.dll` manque,
   sans révéler de chemin local.
7. Créer un format JSON Lines `thrustline.simconnect.trace`, schéma `1`, avec
   en-tête obligatoire, offsets monotones et limites de taille.
8. Rejeter les traces invalides sans recopier leur contenu dans l'erreur.
9. Fournir un replay immédiat ou cadencé, annulable et sans réseau.
10. Livrer au moins une trace synthétique couvrant sol, décollage, montée,
    croisière, descente et retour au sol.
11. Tester la validation du domaine, le format, l'ordre, l'annulation, le faux
    adaptateur et l'absence de dépendance SDK dans les contrats publics.
12. Ne connecter encore la télémétrie ni à SignalR, ni au frontend, ni à une
    logique de vol.

## Non-goals

- Valider MSFS 2024 Store ou Steam sur une vraie session.
- Détecter toutes les phases de vol.
- Gérer pause, slew, go-around, touch-and-go ou crash.
- Publier un rapport de vol.
- Copier ou redistribuer une DLL SimConnect.
- Exposer la télémétrie sur le contrat local.
- Ajouter un package NuGet ou un wrapper communautaire.

## Acceptance criteria

- [x] La branche est `foundation/t0011-simconnect-adapter`.
- [x] Les contrats publics ne référencent aucun type SDK.
- [x] L'adaptateur natif compile en .NET 10 sans package tiers.
- [x] Les appels SimConnect sont confinés à une boucle dédiée.
- [x] La fermeture et l'annulation sont déterministes.
- [x] Le replay synthétique passe sans MSFS ni DLL SimConnect.
- [x] Les traces malformées, surdimensionnées ou non monotones sont refusées.
- [x] Les tests couvrent le faux adaptateur et le replay.
- [x] Le build et la publication self-contained `win-x64` passent.
- [x] Aucun changement du frontend, de Tauri, de SignalR ou des données métier.
- [x] La vérification réelle MSFS est exécutée ou clairement déléguée.
- [x] Documentation, état et Completion Report sont synchronisés.

## Security review

- actifs : stabilité du bridge, intégrité de la télémétrie et disponibilité de
  MSFS ; aucune donnée autoritaire.
- frontières : DLL native locale et fichiers de trace non fiables.
- abus : DLL substituée via la recherche Windows, trace géante, valeurs NaN,
  cadence abusive, callbacks après fermeture et fuite de chemins.
- contrôles : nom de DLL constant, aucune recherche configurable, lecture seule,
  bornes strictes, taille de ligne limitée, schéma/version obligatoires,
  annulation et messages d'erreur constants.
- logs : aucune valeur de trace, chemin, stack ou donnée utilisateur.

## Automated validation

```powershell
dotnet build .\ThrustlineNG.slnx --configuration Release
dotnet run --project .\tests\bridge\Thrustline.Bridge.Tests.csproj `
  --configuration Release --no-build
dotnet publish .\apps\bridge\Thrustline.Bridge.csproj `
  --configuration Release --runtime win-x64 --self-contained true
pnpm frontend:typecheck
pnpm frontend:test
pnpm desktop:check
pnpm desktop:test
git diff --check
```

## Manual verification

1. Rejouer la trace synthétique sans MSFS et vérifier l'ordre des échantillons.
2. Sur Windows 11 avec MSFS 2024 stable, lancer l'adaptateur natif.
3. Vérifier connexion, télémétrie à 1 Hz, annulation et absence de processus.
4. Répéter séparément sur Microsoft Store/Xbox App et Steam.

La vérification MSFS exige une installation réelle et ne peut pas être remplacée
par la présence d'une DLL issue d'un ancien build.

## Rollback

Abandonner la branche. Aucun état, paramètre machine ou donnée persistante n'est
créé ; aucune DLL n'est installée ou copiée.

## Completion Report

### Summary

Une frontière de télémétrie indépendante du SDK, un adaptateur natif et un
replay JSONL strict sont disponibles. L'adaptateur utilise uniquement les
signatures officielles documentées, sans package NuGet, copie de DLL ou type SDK
dans le domaine. La télémétrie n'est exposée à aucun consommateur.

### Files changed

- `apps/bridge/SimConnect/` : domaine, interface, adaptateur natif, lecteur et
  replay.
- `tests/bridge/` : sept scénarios supplémentaires et copie de la fixture.
- `tests/traces/synthetic-golden-flight.jsonl` : huit points synthétiques.
- documentation : architecture, état, sécurité, qualité, problèmes connus,
  backlog et présent ticket.

### Commands and results

- contrôle toolchain : Node 24.18.0, pnpm 11.17.0, Rust 1.97.1, .NET 10.0.201,
  PowerShell et Git conformes ;
- `dotnet build ... Release` : réussi, 0 avertissement/erreur ;
- harnais bridge : 13/13 scénarios réussis ;
- `dotnet publish ... --self-contained true` : réussi ;
- restauration pnpm figée : réussie ;
- frontend : typecheck, 8/8 tests et build Vite réussis ;
- desktop : format/check/Clippy, 2/2 tests Rust, invariants et build Tauri
  Release réussis ;
- `git diff --check` : réussi, avertissements informatifs LF/CRLF pour deux
  fichiers existants modifiés.

Les premiers builds ont détecté un namespace JSON manquant, une règle CA1859 et
la casse du contrat JSON ; tous ont été corrigés. Une tentative a été bloquée par
l'accès sandbox à `NuGet.Config`, puis la même commande a réussi avec l'accès
autorisé.

### Replay verification

La fixture s'est rejouée dans l'ordre avec huit séquences et des timestamps
strictement croissants. Départ/arrivée au sol et présence d'échantillons en vol
ont été vérifiés. Les tests refusent un offset décroissant, une ligne de plus de
16 Kio et une valeur NaN, et vérifient l'annulation.

### MSFS verification

Non exécutée : aucun SDK MSFS 2024 installé avec provenance vérifiable et aucune
session MSFS disponible. Le smoke test natif a confirmé un échec sûr sur cette
machine, sans chemin local dans le message. Les essais Windows 11/MSFS 2024
Microsoft Store/Xbox App puis Steam sont délégués à la revue ; le ticket reste
`Verify`.

### Security review result

Conforme au périmètre : chargement par nom constant dans les répertoires sûrs,
lecture seule, buffer borné, boucle native unique, fermeture en `finally`, format
strict et aucune valeur de télémétrie ou chemin dans les erreurs. Aucun binaire
de l'ancien dépôt n'a été copié.

### Risks and limitations

- L'ABI et les valeurs réelles de MSFS ne sont pas encore prouvées par une
  session Store ou Steam.
- La fixture synthétique ne caractérise ni un avion, ni les cas pause/slew,
  go-around, touch-and-go ou crash.
- La file bornée abandonne les plus anciens échantillons si un futur consommateur
  ne suit pas ; aucune politique produit n'est encore attachée à ces données.
- La télémétrie n'est volontairement raccordée ni au contrat local, ni au moteur
  de vol.

### Follow-ups

- exécuter les deux fiches plateforme ADR-0003 avec MSFS 2024 stable ;
- capturer ensuite des traces réelles avec provenance et données minimisées ;
- traiter les états de vol et la reprise dans le premier vertical slice ;
- T0012 peut avancer indépendamment sur Supabase/RLS.

### Documentation updated

`ARCHITECTURE`, `SECURITY`, `QUALITY`, `CURRENT_STATE`, `KNOWN_ISSUES`, backlog
et ticket.

### Git and GitHub result

- branche : `foundation/t0011-simconnect-adapter` ;
- commit d'implémentation : `454fe1e` ;
- remote et branche principale : `origin`, `main` ;
- push : réussi, suivi distant configuré ;
- PR T0011 : https://github.com/AndyD9/ThrustlineNG/pull/11, brouillon,
  `MERGEABLE`, base `foundation/t0010-local-contract`, 15 fichiers strictement
  T0011 et aucun check GitHub déclaré au relevé ;
- PR de rattrapage T0010 : https://github.com/AndyD9/ThrustlineNG/pull/10,
  prête, `MERGEABLE`, base `main` ;
- raison de l'empilement : la PR T0010 précédente avait été fusionnée dans T0009
  après l'intégration de T0009 à `main`, donc ses commits n'étaient pas dans
  `main` ;
- modifications préexistantes exclues : aucune ;
- merge non effectué, réservé à Andy.
