# TXXXX — Titre orienté résultat

Status: Draft
Owner: Unassigned
Branch: `type/txxxx-slug`
Phase: X
Risk: Low / Medium / High
Security-sensitive: Yes / No
Autonomous: Yes / No

`Autonomous` est optionnel et ne concerne que la boucle planifiée de
`docs/WORKFLOW.md`. `No` interdit à un run non surveillé de démarrer ce ticket.
En son absence, la boucle classe le ticket elle-même : un ticket
`Security-sensitive: Yes`, `Risk: High`, ou dont une dépendance nomme une décision
d'Andy, MSFS, du matériel ou une vérification humaine, n'est jamais démarré sans
surveillance.

## Goal

Un seul résultat utilisateur ou technique observable.

## Context

Pourquoi ce ticket existe, état actuel et liens utiles.

## Dependencies

- Tickets/ADR/prérequis nécessaires.

## Allowed areas

- Fichiers ou dossiers modifiables.

## Do not touch

- Zones explicitement exclues.

## Requirements

- Comportements obligatoires.
- Contraintes techniques.

## Non-goals

- Fonctionnalités voisines volontairement exclues.

## Acceptance criteria

- [ ] Critère observable et testable.
- [ ] Erreur/limite pertinente couverte.
- [ ] Documentation synchronisée si nécessaire.

## Security review

À remplir si `Security-sensitive: Yes` :

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
# Commandes exactes attendues
```

## Manual verification

1. Préparer…
2. Exécuter…
3. Confirmer…
4. Tester l'erreur…

Temps cible : 5–10 minutes.

## Rollback

Comment abandonner/revenir en arrière sans perte de données.

## Completion Report

À remplir après implémentation.

### Summary

### Files changed

### Commands and results

### Manual verification result

### Risks and limitations

### Follow-ups

### Documentation updated
