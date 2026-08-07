# F0002 — Clôturer son vol et encaisser son revenu depuis l'application

Status: In progress
Owner: Agent (session du 7 août 2026)
Branch: `feature/f0002-cloturer-son-vol-et-encaisser-son-revenu`
PR: [#131](https://github.com/AndyD9/ThrustlineNG/pull/131) (brouillon, base
`main` ; J1–J3 implémentés, restent le parcours manuel, la revue et la fusion
par Andy)
Phase: 2–4
Risk: High
Security-sensitive: Yes
Autonomous: No

## Goal

Depuis l'application, la personne dont le vol est en cours peut le clôturer une
seule fois et voir le revenu net crédité à sa compagnie, son avion redevenu
disponible et sa réputation mise à jour.

## Context

`public.close_flight` est livrée dans `main` depuis T0051 : elle est `security
definer`, réservée à `service_role`, valide strictement le jeu de clés du rapport,
verrouille compagnie, sujet financier puis dispatch, retient
`min(temps déclaré, temps écoulé serveur)`, dérive la distance du référentiel T0057,
applique plancher et plafond, puis écrit dans une seule transaction l'état terminal,
le rapport, l'écriture nette `flight_settlement`, l'événement de réputation et son
registre d'idempotence. `get_company_reputation` rend un score borné informatif.

Comme le départ de vol avant F0001, cette commande n'a **ni frontière Auth ni
appelant**. C'est la dernière étape du golden path serveur dans ce cas.

Elle porte en plus une question que le départ de vol n'a pas : le rapport contient
`blockMinutes`, obligatoire, plus `landingVerticalSpeedFpm` et `fuelUsedKg`
facultatifs. Aucune télémétrie n'alimente ces champs aujourd'hui — T0054 publie une
télémétrie bornée sur le contrat local du bridge, mais rien ne la relie au cycle de
vol, et T0059 attend un MSFS réel. **D'où vient donc le rapport ?** C'est une
décision produit, pas un choix d'implémentation, et c'est la raison du statut
`Draft`.

## Décision attendue d'Andy

**Décision prise le 6 août 2026 : option C — attendre la télémétrie.** Le temps
de vol d'un rapport de clôture ne sera pas saisi par la personne ni déduit par
une migration : il viendra de la télémétrie reliée au cycle de vol. En
conséquence, cette fonctionnalité passe `Blocked` — motif : aucune télémétrie
n'alimente encore `blockMinutes` ; condition de sortie : une fonctionnalité
dédiée relie la télémétrie du bridge (source replay T0054 d'abord, MSFS réel via
F0003/T0059 ensuite) au cycle de vol et au rapport de clôture, après quoi les
jalons ci-dessous sont ajustés et le statut passe `Ready`. Cette fonctionnalité
de liaison reste à ouvrir ; elle devient le chemin critique du jalon « alpha
cliquable » après F0001.

**Condition de sortie levée le 7 août 2026.** La fonctionnalité de liaison est
F0004, fusionnée dans `main` par la PR #128 : le bridge mesure le temps de bloc
du replay et l'expose sur `GET /api/v1/flight-summary`, l'unique commande Tauri
`flight_summary` relaie le résumé revalidé à la WebView, et l'application
affiche le temps de bloc mesuré du vol actif. Le rapport de clôture de l'alpha
est donc fixé par l'option C : `outcome: "completed"` et `blockMinutes` issu du
résumé mesuré (`state: "completed"` côté bridge), jamais d'une saisie. Une
clôture `interrupted` depuis l'application n'a pas de déclencheur télémétrique
décidé : elle reste hors périmètre de l'alpha et `close_flight` la garde côté
serveur. Les jalons ci-dessous sont ajustés en conséquence et le statut passe
`In progress` sur demande d'Andy du 7 août 2026 (« IMPLEMENTE F0002 »).

Le texte original de la décision est conservé ci-dessous pour référence.

**Qui déclare le temps de vol d'un rapport de clôture, dans l'alpha, tant qu'aucune
télémétrie n'est reliée au cycle de vol ?**

- **A — la personne le saisit.** Le panneau demande un temps de bloc en minutes, et
  éventuellement le taux de descente à l'atterrissage et le carburant consommé. Le
  serveur retient déjà `min(déclaré, écoulé)`, donc une surdéclaration ne paie pas ;
  une sous-déclaration réduit le revenu de la personne elle-même. Coût : un champ à
  remplir que la télémétrie rendra caduc, et une UX à jeter en partie.
- **B — le serveur déduit tout.** Le rapport envoyé ne contient que l'issue
  (`completed` ou `interrupted`) et le temps de bloc devient le temps écoulé serveur.
  Coût : `close_flight` n'accepte pas aujourd'hui un rapport sans `blockMinutes`, donc
  cette option demande une migration append-only de plus sur une commande financière
  — exactement ce que F0001 n'a pas eu besoin de faire.
- **C — attendre la télémétrie.** La clôture depuis l'application attend que le
  cycle de vol consomme la source T0054/T0059. Coût : le golden path reste
  inachevable depuis l'application jusqu'à un MSFS réel, alors que tout le reste est
  livré.

Condition de sortie : la décision est reportée datée dans cette section, puis le
statut passe `Ready` et les jalons ci-dessous sont ajustés à l'option retenue.

## Dependencies

- T0051 — clôture autoritaire, règlement, réputation (`Done`, dans `main`) ;
- T0057 — référentiel d'aérodromes dont la distance est dérivée (`Done`) ;
- F0001 — la capacité de faire décoller un vol depuis l'application : sans elle,
  aucun vol `active` n'existe côté application à clôturer. **F0001 doit être fusionnée
  avant J1** ;
- décision d'Andy ci-dessus : **prise le 6 août 2026, option C** ;
- F0004 — la liaison télémétrie → cycle de vol qui alimente `blockMinutes`
  (mesure du replay T0054, résumé `flight_summary` relayé à l'application) :
  **fusionnée dans `main` par la PR #128, le blocage est levé**.

## Allowed areas

Confirmées le 7 août 2026 : l'option C n'exige aucune migration, le périmètre
prévu est retenu tel quel (plus `tests/backend/run.ps1` qui y figurait déjà
pour les mutations nouvelles du gate) :

- `supabase/functions/flight-close/` (nouveau) ;
- `supabase/config.toml` ;
- `tests/backend/run.ps1` ;
- `scripts/validate-flight-close-runtime.ps1` (nouveau) ;
- `package.json` ;
- `apps/desktop/src/features/flight-dispatch/` et, si la lecture du solde est
  nécessaire, `apps/desktop/src/features/` d'un panneau de finances borné ;
- `eng/authority-inventory.json` ;
- `docs/SECURITY.md`, `docs/ARCHITECTURE.md`, `docs/QUALITY.md`,
  `docs/CURRENT_STATE.md`, `docs/KNOWN_ISSUES.md` ;
- ce fichier et `docs/features/README.md`.

L'option B ajouterait `supabase/migrations/` et `supabase/tests/database/`, ce qui
change la nature du travail : une commande financière redéfinie, pas seulement une
frontière ajoutée.

## Do not touch

- `eng/flight-settlement-policy.json` et le barème décidé le 3 août 2026 : cette
  fonctionnalité expose la clôture, elle ne rediscute pas son économie ;
- le grand livre, ses écritures append-only et l'anonymisation T0020 ;
- la garde d'usage T0060 et la restitution T0065 ;
- toute cible distante, tout projet managé, toute donnée réelle.

## Non-goals

- télémétrie reliée au cycle de vol, détection de phases, reprise après crash ;
- annulation d'un vol en cours, ou clôture par un tiers ;
- historique de vols, statistiques ou classements ;
- effets de réputation sur une capacité : elle reste informative par T0051.

## Jalons

Ajustés le 7 août 2026 à l'option C : le rapport envoyé par l'application est
`{ outcome: "completed", blockMinutes }` où `blockMinutes` vient du résumé
mesuré F0004 ; la frontière J1 accepte le contrat complet de `close_flight`
(issue fermée, mesures facultatives bornées) mais l'alpha n'a qu'un appelant.

### J1 — La clôture derrière une frontière authentifiée

Status: Done
Risk: High
Security-sensitive: Yes
Autonomous: No

- résultat : `POST /functions/v1/flight-close` accepte un bearer et un corps borné
  contenant le dispatch, la clé d'idempotence et le rapport strictement allowlisté,
  vérifie la session, dérive `owner_id`, appelle `close_flight` sous timeout et rend
  une projection `no-store` des champs publics, montant réglé compris. Aucun montant,
  distance, multiplicateur ni devise n'est accepté d'un client.
- frontière : Edge Function devant une commande financière.
- validations : tests de la fonction, `backend:check` avec ses mutations nouvelles,
  `authority:check`, `data-policy:check`.
- revue : chercher tout chemin par lequel un client influencerait le montant, et
  tout refus qui révélerait l'état ou le solde.

### J2 — La frontière prouvée sur l'Edge Runtime local réel

Status: Done
Risk: Low
Security-sensitive: No
Autonomous: Yes

- résultat : un script enchaîne Auth → `flight-close` → RPC sur un vol réellement
  démarré : réglage unique, rejeu convergent sans seconde écriture, refus sans JWT,
  refus d'un vol étranger, refus d'un vol déjà clôturé, état SQL relevé et pile
  détruite.
- frontière : Edge Runtime local.
- validations : le script, échouant fermé.
- revue : vérifier qu'un rejeu ne produit pas une seconde écriture financière et que
  le motif de chaque refus est comparé, pas déduit d'un code de sortie.

### J3 — La clôture composée depuis le desktop

Status: Done
Risk: Medium
Security-sensitive: No
Autonomous: No

- résultat : un vol `active` possédé peut être clôturé depuis l'application, avec
  le rapport fixé par l'option C : `outcome: "completed"` et `blockMinutes` issu
  du résumé mesuré F0004 (`state: "completed"`), la clôture restant impossible
  tant que la mesure n'existe pas ; le montant réglé et le nouvel état sont
  affichés depuis la réponse serveur, la flotte et la liste des dispatchs sont
  relues, un double clic et un retry ne règlent jamais deux fois.
- frontière : desktop React.
- validations : typecheck, tests, couverture, build, `authority:check`.
- revue : vérifier qu'aucun montant n'est calculé côté client, même pour affichage.

## Acceptance criteria

- [x] Un vol `active` possédé peut être clôturé une seule fois depuis l'application
      (preuve jsdom J3 ; le parcours WebView réel reste la vérification manuelle).
- [x] Le montant, la distance, le multiplicateur et la devise viennent exclusivement
      du serveur, y compris à l'affichage.
- [x] Un rejeu, un double clic ou un vol déjà clôturé ne produisent ni seconde
      écriture financière, ni second rapport, ni second événement de réputation.
- [x] Un vol inconnu, étranger ou déjà terminal rend le même refus indistinguable.
- [x] La frontière est prouvée sur l'Edge Runtime local réel (56 contrôles).
- [x] L'avion redevient dispatchable après la clôture, et la liste le montre.
- [x] Chaque règle nouvelle du gate est prouvée par au moins une mutation négative.
- [x] La documentation décrit la capacité livrée et ce qui reste absent.

## Security review

Jalon concerné : **J1**, et à revalider en J3 pour l'affichage.

- actifs/données : argent, réputation, état terminal d'un vol, credential serveur ;
- frontière : Edge Function authentifiée devant une commande financière ;
- abus : clôturer le vol d'un autre, régler deux fois la même clé, influencer le
  montant par le rapport, sonder un solde par la forme d'un refus ;
- validation/autorisation : bearer vérifié auprès d'Auth, anonyme refusé, `owner_id`
  dérivé de la réponse Auth, jeu de clés du rapport strictement allowlisté et borné ;
- atomicité/idempotence : appartiennent à `close_flight` ; la frontière ne réessaie
  pas et ne réécrit pas sa réponse ;
- logs/vie privée : aucun montant, JWT, email ni détail SQL journalisé.

## Maintenance review

- dettes et problèmes connus applicables : `KI-025`, `KI-021` ;
- dette créée ou aggravée : à évaluer selon l'option retenue ; l'option B redéfinit
  une commande financière et hérite du coût de `LC-2026-002` ;
- règle de sécurité ajoutée : la frontière de clôture dans `SECURITY.md` ;
- contrôle manuel à automatiser : la validation runtime de J2 ;
- risque résiduel : un temps de vol déclaré par la personne reste une donnée non
  vérifiée, bornée seulement par `min(déclaré, écoulé)`. À consigner explicitement si
  l'option A est retenue.

## Automated validation

L'option C n'impose aucune migration : la forme est identique à celle de F0001.

- `pnpm backend:functions:test` — tests unitaires du handler `flight-close` ;
- `pnpm backend:check` — invariants statiques, dont les mutations nouvelles de
  la frontière de clôture ;
- `pnpm authority:check` — l'inventaire d'autorité gagne la frontière ;
- `pnpm data-policy:check` — aucune donnée réelle, aucun secret ;
- `pnpm maintenance:check` — documentation et dettes cohérentes ;
- J2 : `scripts/validate-flight-close-runtime.ps1` sur la pile locale réelle
  (`pnpm backend:start`/`backend:reset` avant, `pnpm backend:stop` après) ;
- J3 : `pnpm frontend:typecheck`, `pnpm frontend:test`, `pnpm frontend:coverage`,
  `pnpm frontend:build`.

## Manual verification

Une vérification par jalon, plus un parcours de bout en bout login → compagnie →
catalogue → achat → dispatch → départ → clôture, avec relevé du solde avant et après.

## Rollback

Avant fusion, abandonner la branche. Après fusion, retirer la frontière et son
appelant laisse `close_flight` réservée à `service_role`. Aucune écriture de grand
livre déjà produite n'est réversible : c'est la raison pour laquelle le règlement
reste serveur et unique.

## Completion Report

Un bloc par jalon, rempli au moment de son commit, puis une synthèse.

### J1

- résultat obtenu : `POST /functions/v1/flight-close` accepte un bearer et un
  corps borné de 4 Kio strictement allowlisté (`dispatchId`, `idempotencyKey`,
  `report{outcome, blockMinutes, landingVerticalSpeedFpm?, fuelUsedKg?}`),
  vérifie la session non anonyme, dérive `owner_id` de la réponse Auth, appelle
  `close_flight` en `service_role` sous timeout et projette dix champs publics
  `no-store` sans `ledgerEntryId`. Aucun montant, distance, multiplicateur ni
  devise n'est accepté d'un client.
- fichiers modifiés : `supabase/functions/flight-close/` (nouveau, 4 fichiers),
  `supabase/config.toml`, `package.json`, `tests/backend/run.ps1`,
  `eng/authority-inventory.json`.
- commandes et résultats : 18/18 tests du handler ; `backend:check`,
  `authority:check`, `data-policy:check` verts ; six mutations négatives
  prouvées (verify_jwt désactivé, code de refus renommé, `ledgerEntryId`
  projeté, scénario de test retiré, fonction retirée du script de tests, champ
  monétaire client lu) — chacune fait échouer le gate, l'arbre restauré passe.
- vérification manuelle : sondes 401 (et non 404) sur la pile fraîchement
  démarrée, conformément à la leçon « copie du démarrage ».
- revue et constats traités : auto-revue sur les deux axes du jalon — le seul
  chemin client vers le montant est `blockMinutes`, plafonné par
  `min(déclaré, écoulé)` côté serveur (T0051) ; les refus RPC sont réduits à un
  unique `409 flight_close_rejected` sans corps amont.

### J2

- résultat obtenu : la frontière est prouvée sur l'Edge Runtime local réel par
  un scénario complet Auth → onboarding → achat → brouillon → départ → clôture.
- fichiers modifiés : `scripts/validate-flight-close-runtime.ps1` (nouveau).
- commandes et résultats : 56 contrôles, 0 échec, le 7 août 2026 — règlement
  unique apparié en SQL (commande, rapport, réputation `+1`, crédit net égal à
  la réponse), rejeu octet pour octet sans seconde écriture, refus étranger /
  inconnu / déjà clos indistinguables, montant forgé refusé `invalid_report`,
  401 sans bearer, 413 à 5 Kio, avion re-dispatchable par un nouveau brouillon
  réel, pile détruite ensuite (`pnpm backend:stop`).
- vérification manuelle : lecture du relevé des 56 contrôles ; les motifs de
  refus sont comparés entre eux, pas déduits d'un code de sortie (leçon KI-025).
- revue et constats traités : le rejeu est vérifié à la fois sur la réponse
  (octet pour octet) et sur l'état SQL (aucune seconde écriture financière).

### J3

- résultat obtenu : un vol `active` possédé se clôture depuis l'application avec
  le rapport fixé par l'option C — `outcome: "completed"` et `blockMinutes` issu
  du résumé mesuré F0004 ; sans mesure complète, la clôture est refusée
  localement. Montant, devise et temps retenu sont affichés depuis la seule
  réponse serveur ; la flotte et la liste des dispatchs sont relues ; la clé
  d'idempotence est épinglée au rapport exact qu'elle a signé, donc un double
  clic ou un retry ne règlent jamais deux fois et une nouvelle mesure ouvre une
  nouvelle intention.
- fichiers modifiés : `flightClose.ts`, `FlightCloseControl.tsx` (nouveaux, avec
  tests et invariants), `DispatchListPanel.tsx`, `dispatchList.ts` (+ tests),
  `HomePage.tsx`, `eng/authority-inventory.json`.
- commandes et résultats : typecheck vert, 467 tests frontend verts (35
  fichiers), couverture 94,59 % lignes / 90,37 % branches, build vert,
  `authority:check` vert.
- vérification manuelle : à faire par Andy — parcours complet login → compagnie
  → catalogue → achat → dispatch → départ → clôture dans l'application réelle,
  avec relevé du solde avant et après (voir Manual verification).
- revue et constats traités : aucun montant n'est calculé côté client — la seule
  opération est la présentation `settledAmountMinor / 100` par
  `Intl.NumberFormat`, l'idiome déjà utilisé par le catalogue, et un invariant
  de test l'épingle. Constat d'intégration corrigé dans le périmètre : la
  liste des dispatchs rejetait tout état terminal (`invalid-response` après une
  clôture) ; elle filtre désormais les états ouverts côté requête, la sélection
  par ligne restant à la RLS.

### Synthèse

Le golden path serveur a maintenant sa dernière frontière et son dernier
appelant : la clôture et l'encaissement se font depuis l'application, sur la
mesure télémétrique de F0004, jamais sur une saisie. Trois jalons, trois
commits, une PR ; 18 tests de handler, 56 contrôles runtime, 467 tests
frontend, six mutations négatives de gate.

### Risks and limitations

- **KI-027 / KI-028 (relevées par la revue F0004, fusionnées le 7 août 2026
  après l'implémentation des jalons)** : l'application intégrée ne produit pas
  encore de mesure par elle-même (KI-027 : pas de trace ni d'abonné sans
  harnais externe), et le résumé du bridge ne porte aucune identité de vol avec
  un tracker non réarmable (KI-028). La clôture suit la garde de la PR #130 —
  résumé et clôture ne sont rendus que lorsqu'un seul vol est actif — mais des
  vols successifs dans la même session du bridge peuvent encore relire la
  mesure du vol précédent, bornée par `min(déclaré, écoulé)` côté serveur.
  KI-028 consigne la décision d'Andy du 7 août 2026 : le rattachement
  résumé ↔ vol et le réarmement du tracker sont des prérequis de F0002 —
  **la fusion de cette PR attend donc la décision d'Andy sur le séquencement**
  (câblage du cycle de vol d'abord, ou clôture livrée sous la garde d'un seul
  vol par session avec le câblage en unité suivante).
- La clôture depuis l'application exige un résumé mesuré `completed` : un replay
  interrompu ou une trace incomplète laisse le vol `active`, et la clôture
  `interrupted` reste réservée au serveur — un déclencheur télémétrique pour ce
  cas est une décision produit encore ouverte.
- Le temps de bloc mesuré reste une déclaration mieux fondée, bornée par
  `min(déclaré, écoulé serveur)` : un client trafiqué ne gagne rien, comme
  documenté par F0004.
- La preuve desktop est jsdom à `fetch` injecté ; le parcours WebView réel
  appartient à la vérification manuelle d'Andy.

### Follow-ups

- Fonctionnalité future : clôture `interrupted` déclenchée par la télémétrie
  (crash, fin de session), décision produit à prendre.
- F0004 est fusionnée mais son fichier et l'index la disent encore
  `In progress` : sa clôture documentaire appartient à sa propre unité.

### Documentation updated

`docs/SECURITY.md` (frontière de clôture et appelant option C),
`docs/ARCHITECTURE.md` (cinquième frontière Edge), `docs/QUALITY.md` (preuve J2,
80 tests de fonctions), `docs/CURRENT_STATE.md` et `docs/features/README.md`
(statut), ce fichier.
