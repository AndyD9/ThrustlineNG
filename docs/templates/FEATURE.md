# FXXXX — Capacité orientée résultat utilisateur

Status: Draft
Owner: Unassigned
Branch: `feature/fxxxx-slug`
Phase: X
Risk: Low / Medium / High
Security-sensitive: Yes / No
Autonomous: Yes / No

Une fonctionnalité est un **slice vertical complet** : migration, RPC, frontière
authentifiée, validation sur le runtime local et composition desktop vivent dans
une seule branche et une seule Pull Request, en un commit par jalon.

Les quatre champs d'en-tête sont les **valeurs par défaut** des jalons. Un jalon
qui redéclare `Risk`, `Security-sensitive` ou `Autonomous` l'emporte sur l'en-tête,
parce que la frontière d'un run non surveillé est évaluée au niveau où elle a un
sens : une migration financière et un panneau de lecture n'ont pas le même risque.
`Autonomous: No` en en-tête interdit en revanche tout run non surveillé, quel que
soit le jalon.

## Goal

Un seul résultat utilisateur observable, énoncé du point de vue de la personne qui
l'utilise. Si le but a besoin d'un « et » entre deux capacités distinctes, ce sont
deux fonctionnalités.

## Context

Pourquoi cette capacité existe, état réellement présent dans `main` et liens utiles.

## Dependencies

- Fonctionnalités, tickets, ADR ou prérequis nécessaires.
- Nommer explicitement une décision d'Andy, MSFS, du matériel ou une vérification
  humaine encore manquante : le sélecteur en fait un veto d'autonomie.

## Allowed areas

- Union des chemins modifiables par tous les jalons.

## Do not touch

- Zones explicitement exclues.

## Non-goals

- Capacités voisines volontairement exclues, et la fonctionnalité qui les portera.

## Jalons

Ordonnés. Chaque jalon est un commit, une frontière principale et ses validations.
Le sélecteur exécute le premier jalon qui n'est pas `Done` et n'en démarre jamais
deux à la fois.

### J1 — Résultat du premier jalon

Status: Draft
Risk: Low
Security-sensitive: No
Autonomous: Yes

- résultat : comportement observable une fois ce jalon commité.
- frontière : la frontière principale touchée — migration, RPC, Edge, desktop.
- validations : commandes exactes qui prouvent ce jalon.
- revue : ce que la revue adversariale de ce jalon doit chercher en premier.

### J2 — Résultat du deuxième jalon

Status: Draft
Risk: Low
Security-sensitive: No
Autonomous: Yes

- résultat :
- frontière :
- validations :
- revue :

## Acceptance criteria

- [ ] Critère observable et testable de la capacité entière.
- [ ] Erreur/limite pertinente couverte.
- [ ] Documentation synchronisée si nécessaire.

## Security review

À remplir si un jalon porte `Security-sensitive: Yes`, en nommant les jalons
concernés :

- actifs/données :
- frontière :
- abus :
- validation/autorisation :
- atomicité/idempotence :
- logs/vie privée :

## Maintenance review

- dettes et problèmes connus applicables :
- dette créée ou aggravée :
- règle de sécurité ajoutée, modifiée ou à revalider :
- contrôle manuel à automatiser :
- risque résiduel ou exception approuvée :

## Automated validation

```powershell
# Commandes exactes attendues sur la capacité entière
```

## Manual verification

Une vérification par jalon, chacune de 5–10 minutes. La vérification finale
parcourt la capacité de bout en bout.

1. J1 : préparer… exécuter… confirmer… tester l'erreur…
2. J2 : …
3. Bout en bout : …

## Rollback

Comment abandonner la fonctionnalité entière sans perte de données, et jusqu'à
quel jalon un retour partiel reste cohérent.

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
