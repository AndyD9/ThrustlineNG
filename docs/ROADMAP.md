# Roadmap de la refonte

La roadmap est ordonnée par réduction du risque. Elle décrit des résultats ; les
détails d'exécution appartiennent aux tickets.

## Phase 0 — Baseline et décisions

Objectif : rendre l'existant mesurable et décider ce que l'on reconstruit.

- Inventaire reproductible, tests/builds et matrice de dépendances.
- Décision du modèle produit : MVP solo connecté préparé pour une collaboration
  ultérieure (`ADR-0001`, acceptée).
- Matrice Windows/MSFS acceptée (`ADR-0003`) : Windows 11 x64 et MSFS 2024
  stable, Store et Steam prouvés séparément.
- Stack cible acceptée (`ADR-0004`) : Tauri/WebView2, React, .NET 10,
  SimConnect officiel abstrait et Supabase/PostgreSQL 17.
- Budgets stabilité/performance (`T0015`) et politique de données (`T0017`).
- Stratégie acceptée : réécriture totale isolée dans un nouveau dépôt
  (`ADR-0002`), sans migration des données de développement.
- Environnements local/CI/staging/production documentés (`T0017`) ; leur
  provisionnement distant reste interdit tant qu'un ticket dédié ne le contrôle
  pas.

Gate : baseline verte ou écarts connus, ADR majeures acceptées, périmètre MVP
gelé, golden path à caractériser identifié et protocole de preuve plateforme
défini. La promotion effective d'un canal MSFS vers `Supported` peut intervenir
avec les tests réels du vertical slice.

## Phase 1 — Socle reproductible

Objectif : créer dans le nouveau dépôt un socle reconstruisible et testable à
tout moment.

- Nouveau dépôt, historique neuf, règles de branches courtes et CI obligatoire.
- Versions/outils supportés selon `docs/STACK.md` et bootstrap automatisé.
- Source de version unique.
- CI consolidée et actions épinglées.
- Lint/format/types/tests cohérents.
- Supabase local jetable et données de test.
- Contrats versionnés et génération des types.

Gate : clone propre → setup → tests/build sans étape secrète non documentée.

## Phase 2 — Noyau métier autoritaire

Objectif : empêcher corruption, doubles opérations et calculs client autoritaires.

- Modèle de domaine et grand livre immuable.
- Commandes transactionnelles/idempotentes.
- RLS A/B/anonyme.
- Concurrence optimiste et audit.
- Nouveau schéma créé depuis zéro avec seeds synthétiques et restauration testée.

Gate : aucune mutation sensible directe depuis un composant client.

## Phase 3 — Bridge et moteur de vol stables

Objectif : rendre la détection de vol déterministe et récupérable.

- Premier vertical slice critique de la réécriture.
- Domaine indépendant de SimConnect.
- Replays de traces et projet de tests .NET.
- Reconnexion, pause, slew, go-around, touch-and-go et crash.
- Canal local durci et cycle de vie robuste.
- Rapport de vol versionné et outbox de reprise.

Gate : traces représentatives rejouées sans MSFS jusqu'à un rapport versionné.

## Phase 4 — Application cliente maintenable

Objectif : reconstruire l'UX sur des fondations testables.

- Architecture par fonctionnalités.
- Couche queries/commands.
- Auth et onboarding résilients.
- Flotte, routes, dispatch, vol live, finances.
- États offline/pending/rejected explicites.
- Accessibilité et design system.

Gate : golden path E2E auth → compagnie → flotte → dispatch → vol → rapport →
grand livre stable et aucun écran critique monolithique.

## Phase 5 — Opérations passives et progression

Objectif : réintroduire la profondeur de jeu côté serveur.

- Horaires/rotations atomiques.
- Jobs serveur temporels et déterministes.
- Maintenance, équipage, prêts, réputation et événements.
- Tests de simulation longue et cohérence économique.

Gate : simulation accélérée sans création/destruction inexpliquée de valeur.

## Phase 6 — Distribution sûre

Objectif : produire une bêta installable et récupérable.

- Authenticode, installateur, SBOM, checksums et provenance.
- Updater signé, canaux stable/bêta et rollback.
- Logs redigés, diagnostics consentis et crash reporting.
- Politique sécurité, confidentialité, licence et support.
- Tests Windows 11 x64/MSFS 2024 sur Store et Steam, avec fiches ADR-0003.

Gate : installation, upgrade N-1, rollback et désinstallation validés.

## Phase 7 — Bêta fermée et stabilisation

Objectif : mesurer en conditions réelles sans ajouter de fonctionnalités.

- Cohorte limitée et procédure d'incident.
- SLO, triage et retour utilisateur.
- Tests longue durée et correction des régressions.
- Sauvegarde/restauration.

Gate : deux releases consécutives respectent les objectifs de stabilité.

## Bascule et archivage de l'ancien dépôt

Il n'y a qu'une bascule publique, après validation des gates de caractérisation,
socle, SimConnect, parité du golden path, recréation/restauration des données et
distribution signée. L'ancien client n'accède jamais au nouveau backend. Le dépôt
actuel est archivé seulement après acceptation de cette parité par Andy.

## Phase 8 — Après stabilité

- Nouvelle ADR puis collaboration multi-rôle si le besoin probable est confirmé ;
  aucun parcours collaboratif ne fait partie du MVP.
- Tableau de bord web.
- Import/export avancé.
- Administration et audit étendu.
- Modding avec permissions/signatures dédiées.
