# F0005 — Rendre l'alpha installée cliquable

Status: Ready
Owner: Unassigned
Branch: `feature/f0005-rendre-l-alpha-installee-cliquable`
Phase: 4
Risk: High
Security-sensitive: Yes
Autonomous: No

## Goal

La personne qui installe le package `internal-alpha` peut dérouler le golden
path dans l'application installée — la même chose qu'en mode dev aujourd'hui —
sans que la CSP du canal public ne s'ouvre d'un pouce.

## Context

Découvert le 6 août 2026 pendant la vérification live de F0001 : la CSP de
production est `connect-src 'none'` (T0037/T0038), donc l'application
**installée** ne peut pas joindre l'API Supabase locale — le parcours
interactif exigé par T0055 est impossible par conception, et T0055 reste
`Verify`. Andy a tranché le 6 août 2026 : le canal `internal-alpha`
(`eng/product-version.json`, T0055) reçoit une CSP qui autorise **uniquement**
`http://127.0.0.1:54321`, et la CSP publique reste `'none'`.

## Dependencies

- T0014/T0055 — packaging NSIS non signé et canal produit (`Done`) ;
- T0038 — configuration publique bornée et CSP existantes (`Done`) ;
- décision d'Andy du 6 août 2026 : **prise** (build `internal-alpha` avec CSP
  loopback seule) ;
- la vérification finale installée appartient à Andy (vérification humaine).

## Allowed areas

- `apps/desktop/src-tauri/tauri.conf.json` et la mécanique de CSP par canal ;
- `apps/desktop/` configuration de build strictement nécessaire ;
- `scripts/build-windows-package.ps1` et le gate de packaging si le canal
  change la CSP embarquée ;
- `tests/` — la preuve qu'un package public garde `connect-src 'none'` ;
- `docs/SECURITY.md`, `docs/ARCHITECTURE.md`, `docs/QUALITY.md`,
  `docs/CURRENT_STATE.md`, le fichier de T0055 pour sa clôture ;
- ce fichier et `docs/features/README.md`.

## Do not touch

- La CSP du canal public : `connect-src 'none'` ne bouge pas ;
- l'allowlist de configuration T0038 (une seule cible loopback) ;
- signature, updater, distribution publique : phase 6.

## Non-goals

- Ouvrir la CSP à toute autre origine que `http://127.0.0.1:54321` ;
- staging, cloud, ou cible distante ;
- clore les vérifications MSFS (T0059/F0003).

## Jalons

### J1 — La CSP suit le canal produit, prouvée fermée pour le public

Status: Draft
Risk: High
Security-sensitive: Yes
Autonomous: No

- résultat : le build `internal-alpha` embarque une CSP dont `connect-src` est
  exactement `http://127.0.0.1:54321` ; tout autre canal garde `'none'`. Un
  contrôle déterministe échoue si un package public embarque autre chose que
  `'none'`, avec mutation négative.
- frontière : CSP Tauri, gate de packaging.
- validations : `pnpm desktop:check`, `pnpm desktop:test`, gate de packaging,
  `pnpm maintenance:check`.
- revue : chercher tout chemin par lequel la CSP élargie fuirait vers le canal
  public, et toute origine au-delà du loopback exact.

### J2 — Le parcours installé, vérifié par Andy

Status: Draft
Risk: Medium
Security-sensitive: No
Autonomous: No

- résultat : un package `internal-alpha` est produit, installé, et le golden
  path y est déroulé sur la pile locale (login → compagnie → achat → dispatch →
  départ). Ce parcours clôt la vérification interactive de T0055.
- frontière : packaging Windows + vérification humaine.
- validations : `packaging:check`, cycle installation/désinstallation sans
  résidu, parcours humain consigné.
- revue : vérifier que le manifeste et les hashes reflètent le canal, et que
  rien d'autre ne diffère du package public.

## Acceptance criteria

- [ ] Un package `internal-alpha` installé déroule le golden path sur la pile
      locale.
- [ ] Un package du canal public embarque `connect-src 'none'`, prouvé par un
      contrôle à mutation négative.
- [ ] Aucune origine autre que `http://127.0.0.1:54321` n'est autorisée par le
      canal alpha.
- [ ] T0055 est clos par le parcours installé, consigné dans son fichier.
- [ ] `SECURITY.md` décrit la CSP par canal et son risque résiduel.

## Security review

Jalons concernés : **J1**, revalidé en J2 sur l'artefact réel.

- actifs/données : CSP de l'application distribuée, frontière réseau du client ;
- frontière : WebView ↔ réseau ;
- abus : élargissement silencieux de la CSP publique, canal alpha distribué
  au-delà de l'interne, origine non loopback glissée dans l'allowlist ;
- validation/autorisation : contrôle déterministe par canal, mutation négative ;
- atomicité/idempotence : sans objet (configuration) ;
- logs/vie privée : aucun changement.

## Maintenance review

- dettes et problèmes connus applicables : T0055 `Verify` (clos par J2) ;
- dette créée ou aggravée : deux CSP à maintenir ; le gate de packaging en
  devient le garde-fou ;
- règle de sécurité ajoutée : CSP par canal dans `SECURITY.md` ;
- contrôle manuel à automatiser : la comparaison de CSP embarquée par canal ;
- risque résiduel : un package alpha qui fuirait hors de l'interne expose une
  CSP loopback — sans donnée réelle ni cible distante, risque accepté à
  documenter.

## Automated validation

```powershell
pnpm desktop:check
pnpm desktop:test
pnpm frontend:build
pnpm packaging:check
pnpm maintenance:check
```

## Manual verification

1. J1 : inspecter la CSP embarquée des deux canaux dans les artefacts de build.
2. J2 : installer le package alpha, dérouler le golden path sur la pile locale,
   désinstaller, vérifier zéro résidu — appartient à Andy.

## Rollback

Retirer la CSP conditionnelle rend tous les canaux à `connect-src 'none'`,
l'état actuel. Aucune donnée concernée.

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

### Synthèse

### Risks and limitations

### Follow-ups

### Documentation updated
