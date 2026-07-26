# Règles du dépôt ThrustlineNG

## Travail

- Traiter un seul ticket à la fois.
- Lire le ticket et respecter strictement ses zones autorisées et interdites.
- Obtenir la confirmation d'Andy avant de créer une branche ou d'en changer.
- Ne jamais importer implicitement du code, des manifests ou des lockfiles de
  l'ancien dépôt Thrustline.
- Préserver toute modification utilisateur sans rapport avec le ticket.

## Sécurité et qualité

- Ne jamais versionner de secret, jeton, fichier `.env` ou donnée personnelle.
- Utiliser des versions exactes et des sources officielles.
- Ne pas télécharger puis exécuter de script distant.
- Exécuter les validations prévues par le ticket et rapporter honnêtement les
  contrôles non exécutables.
- Utiliser Git pour Windows et PowerShell, jamais Git WSL sur `/mnt/c`.

## Git

- Examiner le diff et indexer explicitement les seuls fichiers du ticket.
- Ne jamais utiliser `git add .` ou `git add -A` dans le handoff.
- Demander une confirmation explicite distincte avant commit, push, PR ou merge.
