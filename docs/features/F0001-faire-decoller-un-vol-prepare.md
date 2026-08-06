# F0001 — Faire décoller un vol préparé depuis l'application

Status: Verify
Owner: Claude (session interactive du 6 août 2026)
Branch: `feature/f0001-faire-decoller-un-vol-prepare`
Phase: 2–4
Risk: Medium
Security-sensitive: Yes
Autonomous: No

## Goal

Depuis l'application, la personne qui a préparé un dispatch peut faire décoller ce
vol : elle voit son vol passer de préparé à en cours, avec son heure de départ
serveur, et un second clic ne fait jamais partir deux fois.

## Context

`public.start_flight_from_dispatch` est livrée dans `main` depuis T0050 : elle est
`security definer`, réservée à `service_role`, dérive compagnie et avion du serveur,
n'autorise que la transition `draft` → `active`, refuse un compte en suppression et
tient son registre d'idempotence `private.flight_start_commands`. T0060 y ajoute la
garde d'usage de l'avion et T0065 la restitution exacte du rejeu.

Il lui manque exactement ce que cette fonctionnalité livre : **une frontière
authentifiée et un appelant**. C'est aujourd'hui la seule étape du golden path
serveur qui n'a ni Edge Function ni consommateur desktop, alors que la préparation
(T0052) et la relecture (T0053) des dispatchs sont déjà composées côté desktop.

Le format de cette fonctionnalité est celui décidé par Andy le 5 août 2026 (T0068) :
un slice vertical complet, une branche, une Pull Request, des jalons ordonnés. La
migration et la RPC existant déjà, le slice vertical de cette capacité est
frontière Edge → validation runtime réelle → composition desktop.

Trois frontières Edge livrées servent de modèle strict et ne doivent pas être
réinventées : `company-onboarding` (T0023), `aircraft-purchase` (T0035) et
`dispatch-draft` (T0048). Leur forme est déjà gardée par le gate backend : corps
borné à 4 Kio, appels amont bornés à 5 secondes, vérification du bearer auprès de
`/auth/v1/user`, refus d'une session anonyme, `owner_id` dérivé de cette réponse et
jamais du client, réponse allowlistée `no-store`, refus redigés sans détail SQL.

## Dependencies

- T0050 — départ de vol autoritaire et son registre (`Done`, dans `main`) ;
- T0048 — frontière `dispatch-draft`, modèle de forme et de gate (`Done`) ;
- T0052 et T0053 — préparation et relecture des dispatchs desktop (`Done`) ;
- T0065 — restitution du rejeu : **la PR #121 doit être fusionnée avant J1**, sinon
  la projection publique de J1 serait écrite sur un contrat de rejeu que T0065
  change. Dépendance d'ordre d'intégration, pas de contenu ;
- T0049 et T0036 — méthode de validation sur l'Edge Runtime local réel, à reprendre
  pour J2 sans la réinventer.

Aucune décision d'Andy n'est en attente : cette capacité n'introduit ni règle
économique, ni champ déclaré par la personne, ni valeur de politique. `Autonomous:
No` en en-tête vient du seul jalon J1, qui est `Security-sensitive`.

## Allowed areas

- `supabase/functions/flight-start/` (nouveau : `handler.ts`, `index.ts`,
  `handler.test.ts`, `package.json`) ;
- `supabase/config.toml` — déclaration de la fonction, sur le modèle des trois
  existantes ;
- `tests/backend/run.ps1` — invariants et mutations négatives de la nouvelle
  frontière ;
- `scripts/validate-flight-start-runtime.ps1` (nouveau, J2) ;
- `package.json` — script de validation runtime et entrée `backend:functions:test` ;
- `apps/desktop/src/features/flight-dispatch/` — transport et panneau (J3) ;
- `eng/authority-inventory.json` — l'étape `flight-runtime` gagne sa frontière ;
- `docs/SECURITY.md`, `docs/ARCHITECTURE.md`, `docs/QUALITY.md`,
  `docs/CURRENT_STATE.md`, `docs/KNOWN_ISSUES.md` ;
- ce fichier et `docs/features/README.md`.

## Do not touch

- `supabase/migrations/` : aucune migration n'est nécessaire, la RPC est livrée.
  Toute envie d'en écrire une est le signe d'un périmètre qui dérive ;
- `public.close_flight`, le règlement, la réputation et le grand livre : la clôture
  est portée par F0002 ;
- la garde d'usage T0060, ses messages publics et la restitution T0065 ;
- les trois Edge Functions existantes et leurs tests ;
- les statuts et Completion Reports des tickets d'archive ;
- toute cible distante, tout projet Supabase managé, toute donnée réelle.

## Non-goals

- clôturer un vol, produire un rapport ou encaisser un revenu : F0002 ;
- télémétrie MSFS, détection de phases ou reprise après crash : T0059 et la suite du
  flux moteur de vol ;
- annulation d'un dispatch, replanification ou libération d'un avion ;
- SimBrief, plan de vol, carburant ou charge utile ;
- ordonnanceur d'échéances de location.

## Jalons

Ordonnés. Un commit par jalon, une revue adversariale par jalon sur le diff poussé.

### J1 — Le départ de vol derrière une frontière authentifiée

Status: Done
Risk: Medium
Security-sensitive: Yes
Autonomous: No

- résultat : `POST /functions/v1/flight-start` accepte un bearer et un corps de
  4 Kio contenant exactement `dispatchId` et `idempotencyKey`, vérifie la session
  auprès d'Auth, refuse l'anonyme, dérive `owner_id` de cette réponse, appelle
  `start_flight_from_dispatch` avec le credential serveur sous timeout, puis rend
  une projection allowlistée `no-store` des cinq champs publics. Tout refus est
  redigé : ni détail SQL, ni existence, ni propriétaire, ni état d'un dispatch.
- frontière : Edge Function.
- validations : `pnpm backend:functions:test` étendu à la nouvelle fonction,
  `pnpm backend:check` avec ses mutations nouvelles — corps non borné, timeout
  retiré, `owner_id` accepté du client, session anonyme admise, champ hors
  allowlist rendu, refus bavard — puis `authority:check` et `data-policy:check`.
- revue : le client ne doit pouvoir influencer que `dispatchId` et
  `idempotencyKey` ; vérifier qu'aucun chemin ne renvoie un message distinguant un
  dispatch inconnu, étranger, déjà actif ou porté par un avion hors contrat.

### J2 — La frontière prouvée sur l'Edge Runtime local réel

Status: Done
Risk: Low
Security-sensitive: No
Autonomous: Yes

- résultat : un script de validation enchaîne, sur la pile locale réelle, Auth →
  `flight-start` → RPC pour un avion réellement acheté et un dispatch réellement
  préparé : réponse à cinq champs `no-store`, rejeu convergent qui ne crée pas de
  second départ, refus sans JWT, refus d'un dispatch étranger, refus d'un dispatch
  déjà actif, puis état SQL relevé et pile détruite. Le script n'ajoute ni handler,
  ni migration, ni contrat, et ne consigne aucun secret, JWT ni email.
- frontière : Edge Runtime local, sur le modèle de
  `scripts/validate-dispatch-draft-runtime.ps1` (T0049).
- validations : le script lui-même, échouant fermé, plus les gates statiques
  inchangés.
- revue : chercher un contrôle qui conclurait sur un code de sortie sans vérifier
  le motif du refus — c'est exactement `KI-025`, et ce jalon ne doit pas l'ajouter.

### J3 — Le départ composé depuis le desktop

Status: Done
Risk: Low
Security-sensitive: No
Autonomous: Yes

- résultat : dans la liste de dispatchs déjà lue par T0053, un dispatch `draft`
  possédé peut être démarré. Le bearer est obtenu du gestionnaire de session au
  moment de la soumission, la clé d'idempotence est conservée pour un retry, un
  double clic est bloqué, un refus Auth efface la session, et la liste est relue
  après un départ réussi. Aucun appel réseau au rendu. Aucun prix, compagnie,
  propriétaire, état ni horodatage n'entre dans le payload.
- frontière : desktop React, transport `fetch` injecté, sur le modèle de
  `flightDispatch.ts` et `dispatchList.ts`.
- validations : `pnpm frontend:typecheck`, `pnpm frontend:test`,
  `pnpm frontend:coverage`, `pnpm frontend:build`, `pnpm authority:check`.
- revue : vérifier qu'un retry après réponse perdue ne crée pas un second départ et
  que l'état affiché vient du serveur, jamais d'une supposition cliente.

## Acceptance criteria

- [x] Un dispatch `draft` possédé peut être démarré depuis l'application, et la
      liste montre ensuite le vol `active` avec son heure de départ serveur
      (preuve jsdom ; le parcours WebView live reste en vérification manuelle).
- [x] Le client ne fournit jamais que `dispatchId` et `idempotencyKey` ; aucun
      `owner_id`, état ni horodatage n'est accepté d'un appelant.
- [x] Un dispatch inconnu, étranger, déjà actif ou porté par un avion hors contrat
      rend le même refus public indistinguable (corps comparés entre eux en J2).
- [x] Un double clic et un retry de la même clé ne créent ni second départ, ni
      seconde ligne de registre.
- [x] La frontière est prouvée sur l'Edge Runtime local réel, pas seulement contre
      un `fetch` injecté (46 contrôles, 6 août 2026).
- [x] `eng/authority-inventory.json` reflète la frontière ajoutée sans élargir
      `clientDataApiReads`.
- [x] Chaque règle nouvelle du gate est prouvée par au moins une mutation négative
      (9 mutations flight-start sur les 67 du gate backend).
- [x] `SECURITY.md`, `ARCHITECTURE.md`, `QUALITY.md` et `CURRENT_STATE.md` décrivent
      la capacité livrée et ce qui reste absent (`CURRENT_STATE.md` via la version
      courte de la PR #125, à synchroniser après sa fusion).

## Security review

Jalon concerné : **J1**.

- actifs/données : transition d'état d'un vol, propriété du dispatch et de l'avion,
  session Auth, credential `service_role` ;
- frontière : Edge Function authentifiée devant une commande `service_role` ;
- abus : démarrer le vol d'un autre propriétaire, forger `owner_id`, un état ou un
  horodatage, sonder l'existence d'un dispatch par la forme du refus, rejouer une
  clé pour créer un second départ, exfiltrer le credential serveur par un message
  d'erreur ;
- validation/autorisation : bearer vérifié auprès d'Auth, session anonyme refusée,
  `owner_id` dérivé de la réponse Auth, corps borné et strictement à deux clés ;
- atomicité/idempotence : appartiennent à la RPC T0050 ; la frontière ne doit ni
  réessayer, ni dédupliquer, ni réécrire sa réponse ;
- logs/vie privée : aucun JWT, email, identifiant Auth ni détail SQL journalisé ;
  réponses `no-store`.

## Maintenance review

- dettes et problèmes connus applicables : `KI-025` — ne pas ajouter de contrôle
  concurrent qui conclut sur un seul code de sortie ; `KI-021` — aucune donnée
  réelle ;
- dette créée ou aggravée : une quatrième Edge Function partage la forme des trois
  autres sans mutualisation. Si J1 la duplique une fois de plus, consigner le
  candidat de factorisation plutôt que de refactorer les trois existantes ici ;
- règle de sécurité ajoutée, modifiée ou à revalider : `SECURITY.md` gagne la
  section de la frontière de départ de vol ;
- contrôle manuel à automatiser : la validation runtime de J2 est précisément
  l'automatisation du contrôle manuel ;
- risque résiduel ou exception approuvée : aucune exception demandée.

## Automated validation

```powershell
pnpm backend:check
pnpm backend:functions:test
pnpm backend:start
pnpm backend:reset
pnpm backend:test
pnpm backend:types:check
pwsh -NoProfile -File .\scripts\validate-flight-start-runtime.ps1
pnpm backend:stop
pnpm frontend:typecheck
pnpm frontend:test
pnpm frontend:coverage
pnpm frontend:build
pnpm authority:check
pnpm data-policy:check
pnpm maintenance:check
```

## Manual verification

Une vérification par jalon, 5–10 minutes chacune.

1. J1 : appeler la fonction avec un bearer valide, sans bearer, avec un
   `owner_id` ajouté au corps et avec un corps de 5 Kio ; confirmer les quatre
   réponses attendues et l'absence de tout détail interne.
2. J2 : exécuter le script de validation sur une pile fraîche, relever son décompte
   de contrôles et l'état SQL final, puis détruire la pile.
3. J3 : dans l'application, préparer un dispatch, le démarrer, double-cliquer,
   vérifier un seul vol `active`, forcer un refus Auth et confirmer que la session
   est effacée.
4. Bout en bout : login → compagnie → catalogue → achat → dispatch → départ, sur la
   pile locale, en relevant l'état SQL final.

## Rollback

Avant fusion, abandonner la branche : aucune migration n'est écrite, donc aucun
état de base n'est à défaire. Après fusion, retirer la fonction et son appelant
laisse la RPC T0050 exactement dans l'état où elle est aujourd'hui — utilisable par
`service_role` seul. Un retour partiel est cohérent après n'importe quel jalon :
J1 sans J2 est une frontière non prouvée en runtime, J2 sans J3 est une frontière
prouvée sans appelant.

## Completion Report

Un bloc par jalon, rempli au moment de son commit, puis une synthèse.

### J1

- résultat obtenu : `POST /functions/v1/flight-start` accepte un bearer et un
  corps de 4 Kio strictement limité à `dispatchId` et `idempotencyKey`, vérifie
  la session auprès d'Auth, refuse l'anonyme, dérive `owner_id` de la réponse
  Auth, appelle `start_flight_from_dispatch` avec le credential serveur sous
  timeout de 5 s, et rend la projection `no-store` des cinq champs publics
  (`aircraftId`, `dispatchId`, `schemaVersion`, `startedAt`, `state`). Tout refus
  amont rend le même `flight_start_rejected` redigé, sans détail SQL ni
  distinction inconnu/étranger/déjà actif/avion hors contrat.
- fichiers modifiés : `supabase/functions/flight-start/{handler.ts,index.ts,handler.test.ts,package.json}`
  (nouveaux), `supabase/config.toml`, `package.json` (`backend:functions:test`),
  `tests/backend/run.ps1` (invariants + 8 mutations), `eng/authority-inventory.json`
  (frontière du domaine `flight-runtime`), `docs/SECURITY.md`, ce fichier et
  `docs/features/README.md`.
- commandes et résultats (6 août 2026) : `node --test` sur les quatre handlers —
  62 tests, 0 échec, dont 16 nouveaux pour `flight-start` ; `tests/backend/run.ps1`
  — passed, 66 mutations dont 8 nouvelles (owner client, credential non privilégié,
  état client, corps non borné, timeout retiré, anonyme admis, réponse hors
  allowlist, scénario de test retiré) ; `tests/authority/run.ps1` — passed ;
  `tests/data-policy/run.ps1` — passed ; `tests/maintenance/run.ps1` — passed.
- vérification manuelle : exécutée le 6 août 2026 par le script J2 sur l'Edge
  Runtime local réel — bearer valide (200, cinq champs), sans bearer (401 sans
  détail interne), `owner_id` injecté (400 `invalid_request`), corps de 5 Kio
  (413 `request_too_large`) ; les quatre réponses attendues sont observées.
- revue et constats traités : revue adversariale du 6 août 2026 par un agent
  séparé, sur le commit `6de4c8e` — **J1 approuvé, aucun bloquant**. Le seul
  constat majeur est corrigé dans le jalon : la mutation « refus bavard »
  promise manquait et l'invariant `flight_start_rejected` était infalsifiable ;
  l'invariant exige désormais la ligne exacte du refus redigé et une neuvième
  mutation le rend bavard (`await response.text()`), détectée par le gate
  (67 mutations). Le reviewer a aussi vérifié le gate sous Windows PowerShell
  5.1 et pwsh 7 (verts tous les deux) et confirmé chaîne par chaîne que les
  mutations mordent. Cinq constats mineurs sont consignés en follow-ups.

### J2

- résultat obtenu : `scripts/validate-flight-start-runtime.ps1` enchaîne, sur la
  pile locale réelle démarrée par T0021, Auth → Edge → RPC pour un avion
  réellement acheté et un dispatch réellement préparé. Le 6 août 2026, ses
  **46 contrôles passent sans échec** (run final après remédiation de revue) :
  bindings loopback avant/après, baseline `0|0|0`, onboarding des deux
  identités, achat, brouillon, refus redigés et indistinguables — les corps des
  trois refus (étranger, inconnu, déjà actif) sont comparés entre eux et non
  vides —, départ nominal à cinq champs `no-store`, `startedAt` parsable, rejeu
  restituant la réponse acquise octet pour octet sans second départ ni seconde
  commande (`1|1`), 401 sans bearer sans fuite, 400 champ injecté, 413 corps de
  5 Kio, état SQL final `1|1|0|1|1` (un vol actif, une commande, possédés par le
  sujet Auth), refus d'orphaner une compagnie par l'Admin API, identités
  confinées à la pile jetable. Deux sondes du modèle T0049 sont volontairement
  absentes — signup public fermé et refus verbeux 23503 derrière la clé
  privilégiée : propriétés de la pile Auth, hors de cette frontière, déjà
  prouvées par `validate-dispatch-draft-runtime.ps1` qui reste au dépôt.
  Le script échoue fermé (baseline non vide → arrêt), ne consigne aucun secret,
  JWT, email ni détail SQL, et n'ajoute ni handler, ni migration, ni contrat.
- fichiers modifiés : `scripts/validate-flight-start-runtime.ps1` (nouveau) et ce
  fichier.
- commandes et résultats (6 août 2026) : `backend:start` → pile isolée sur
  127.0.0.1 ; `backend:reset` → 12 migrations + seed ; le script → 46 contrôles,
  0 échec ; `backend:stop` → pile détruite, seul le cache d'images source-free
  retenu. Chaque motif de refus est comparé au code public exact, jamais déduit
  d'un code de sortie (`KI-025` non aggravé).
- vérification manuelle : le relevé des 45 lignes `PASS`, du décompte final et de
  l'état SQL a été fait sur la sortie du script pendant le run ; la pile a été
  détruite ensuite.
- revue et constats traités : revue adversariale du 6 août 2026 par un agent
  séparé, sur le commit `6e7467b` — **J2 approuvé, aucun bloquant**. Les deux
  constats majeurs sont corrigés dans le jalon : le refus « déjà actif » est
  désormais comparé aux deux autres corps (M1) et le rejeu est comparé octet
  pour octet à la réponse nominale (M2), avec garde de non-vacuité (m1) ; le
  script durci repasse à 46 contrôles sans échec sur pile fraîche. L'écart au
  modèle T0049 (deux sondes hors frontière) est motivé ci-dessus (m2). Restent
  consignés sans changement : quatre contrôles d'échafaudage `-Condition $true`
  hérités du modèle (m3) et le 401 sans code public épinglé, corps passerelle
  hors contrat du handler (m4).

### J3

- résultat obtenu : dans la liste de dispatchs T0053, chaque ligne `draft`
  porte un contrôle « démarrer ». Le transport `flightStart.ts` est calqué sur
  `flightDispatch.ts` : cible loopback `http:` uniquement, UUID canoniques
  validés avant tout réseau, corps strictement `{dispatchId, idempotencyKey}`,
  timeout 5 s, réponse bornée à 16 Kio et validée par jeu de clés exact des
  cinq champs publics avec recoupement du `dispatchId`. Le contrôle n'exécute
  aucun appel au rendu, obtient le bearer à la soumission, conserve la clé
  d'idempotence pour un retry et la renouvelle si le dispatch change, bloque le
  double clic, efface la session sur refus Auth, annule sa requête au démontage
  et relit la liste autoritaire après un départ réussi — l'état affiché vient
  toujours du serveur. Implémenté par un agent délégué en lecture/écriture sur
  les seuls chemins desktop ; diff inspecté et validations rejouées par le
  coordinateur.
- fichiers modifiés : `apps/desktop/src/features/flight-dispatch/flightStart.ts`,
  `DispatchStartControl.tsx`, leurs trois fichiers de tests (nouveaux),
  `DispatchListPanel.tsx` et son test (câblage minimal),
  `eng/authority-inventory.json` (appelant desktop classé, limitation mise à
  jour), ce fichier.
- commandes et résultats (6 août 2026, rejoués par le coordinateur après
  intégration) : `pnpm frontend:typecheck` — 0 erreur ;
  `pnpm frontend:test` — 359 tests passés, 2 skipped (57 nouveaux au commit du
  jalon — le rapport initial disait 48 par erreur, corrigé en revue — plus deux
  tests de lecture ajoutés en remédiation) ; `pnpm frontend:coverage` —
  `flightStart.ts` 100 % lignes, global 94,77 % statements ;
  `pnpm frontend:build` — vert ; `tests/authority/run.ps1` — vert (9 mutations).
- vérification manuelle : le parcours réel dans l'application (préparer,
  démarrer, double-cliquer, refus Auth) reste à faire sur la pile locale — il
  rejoint la vérification de bout en bout de la fonctionnalité, avec T0055.
- revue et constats traités : revue adversariale du 6 août 2026 par un agent
  séparé de l'implémenteur, sur le commit `c5586c5` — **J3 approuvé, aucun
  bloquant**. Le constat majeur est corrigé dans le jalon : l'heure de départ
  serveur n'était jamais visible en composition réelle (message du contrôle
  démonté au même commit React que la relecture, et projection de lecture sans
  `started_at`). La projection T0053 expose désormais `started_at` — validé
  horodaté pour un vol `active`, nul pour un brouillon, l'invariant serveur
  T0050 — et la ligne active affiche « départ … UTC » depuis la relecture
  autoritaire, prouvé par le test de composition. Les constats mineurs sont
  consignés en follow-ups.

### Synthèse

La capacité est complète côté code et preuves automatisées : la commande
`start_flight_from_dispatch` (T0050/T0060/T0065) a gagné sa frontière Edge
authentifiée (J1, revue et durcie à 67 mutations de gate), la preuve sur l'Edge
Runtime local réel (J2, 46 contrôles dont rejeu octet pour octet et refus
comparés entre eux) et son appelant desktop (J3, 359 tests frontend, heure de
départ serveur relue et affichée). Chaque jalon a été revu adversarialement par
un agent distinct et ses constats majeurs corrigés avant clôture.
`SECURITY.md`, `ARCHITECTURE.md`, `QUALITY.md` et l'inventaire d'autorité
décrivent la capacité et ses limites ; `CURRENT_STATE.md` est mis à jour par la
PR #125 (version courte) et devra refléter la fusion de cette fonctionnalité.

### Risks and limitations

- La preuve desktop reste jsdom à `fetch` injecté : le parcours WebView live
  (préparer → démarrer → double clic → refus Auth) est la vérification humaine
  restante, à faire avec le parcours T0055.
- La clé d'idempotence cliente ne survit pas au démontage du contrôle entre un
  échec et son retry ; le serveur garantit seul l'unicité du départ dans ce cas.
- La lecture du corps de réponse du transport de départ n'est pas bornée en
  streaming (héritage du modèle T0052) ; durcissement commun aux quatre
  frontières consigné en follow-up.

### Follow-ups

Constats mineurs de la revue adversariale J1 du 6 août 2026, non bloquants :

- une panne Auth 5xx est rendue `401 authentication_required` au lieu de `503`
  dans les **quatre** frontières Edge ; à corriger d'un coup, pas ici ;
- les contrôles `config.toml` du gate (`[functions.*] … verify_jwt`) ne sont pas
  bornés à leur section ; candidat de durcissement commun aux quatre frontières ;
- test manquant : corps sur-dimensionné en streaming sans `content-length` ;
- test manquant : variantes de statut amont (403/404/500) dans la preuve
  d'indistinguabilité des refus ;
- `ARCHITECTURE.md`, `QUALITY.md` et `CURRENT_STATE.md` restent à mettre à jour
  à la synthèse de la fonctionnalité (seul `SECURITY.md` est à jour après J1).
  — Fait à la synthèse pour `ARCHITECTURE.md` et `QUALITY.md` ;
  `CURRENT_STATE.md` se synchronise après la fusion de la PR #125.

Constats mineurs de la revue adversariale J3 du 6 août 2026, non bloquants :

- borner en streaming la lecture du corps de réponse des transports de mutation
  (`flightDispatch.ts`, `flightStart.ts`), comme `dispatchList.ts` le fait déjà ;
- conserver l'intention d'idempotence au-delà du démontage du contrôle (ou
  accepter la garantie serveur seule, ce qui est l'état actuel documenté) ;
- exercer la garde `pendingRef` par un test réellement concurrent ;
- relire la liste autoritaire aussi sur un refus `rejected` (UX) ;
- retirer l'assertion redondante `queryByText("private-user-token")`.

### Documentation updated
