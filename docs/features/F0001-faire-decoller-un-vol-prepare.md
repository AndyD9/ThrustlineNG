# F0001 — Faire décoller un vol préparé depuis l'application

Status: Ready
Owner: Unassigned
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

Status: Draft
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

Status: Draft
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

Status: Draft
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

- [ ] Un dispatch `draft` possédé peut être démarré depuis l'application, et la
      liste montre ensuite le vol `active` avec son heure de départ serveur.
- [ ] Le client ne fournit jamais que `dispatchId` et `idempotencyKey` ; aucun
      `owner_id`, état ni horodatage n'est accepté d'un appelant.
- [ ] Un dispatch inconnu, étranger, déjà actif ou porté par un avion hors contrat
      rend le même refus public indistinguable.
- [ ] Un double clic et un retry de la même clé ne créent ni second départ, ni
      seconde ligne de registre.
- [ ] La frontière est prouvée sur l'Edge Runtime local réel, pas seulement contre
      un `fetch` injecté.
- [ ] `eng/authority-inventory.json` reflète la frontière ajoutée sans élargir
      `clientDataApiReads`.
- [ ] Chaque règle nouvelle du gate est prouvée par au moins une mutation négative.
- [ ] `SECURITY.md`, `ARCHITECTURE.md`, `QUALITY.md` et `CURRENT_STATE.md` décrivent
      la capacité livrée et ce qui reste absent.

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
