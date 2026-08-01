# Politique d'ingénierie des données

Dernière mise à jour : 31 juillet 2026

Source machine : `eng/data-policy.json`

Périmètre : MVP solo connecté, avant toute donnée utilisateur réelle

Cette politique fixe les contraintes techniques minimales de ThrustlineNG. Elle
ne remplace ni l'analyse du responsable de traitement, ni un registre des
traitements, ni une notice de confidentialité, ni un avis juridique. Toute
contradiction avec une obligation validée doit être traitée par un ticket et une
revue explicite ; elle ne doit pas être contournée dans le code.

## Statut d'application

| Contrôle | Statut prouvé au 31 juillet 2026 |
| --- | --- |
| Source JSON versionnée et gate à mutations | Enforced par T0017 |
| Seeds locaux synthétiques uniquement | Enforced par T0012 et T0017 |
| Données réelles en local, CI ou staging | Forbidden |
| Admission de données utilisateur réelles | Blocked |
| Export de compte | Enforced local/CI par T0018 |
| Suppression de compte | Enforced local/CI par T0018 |
| Purges de rétention | Not implemented |
| Anonymisation du grand livre | Enforced local/CI par T0020 |
| Sauvegardes managées | Not implemented |
| Restauration isolée synthétique | Enforced local/CI par T0019 |
| Replay des suppressions après restauration | Enforced local/CI par T0019 |

`Enforced` signifie qu'un contrôle reproductible existe dans le dépôt.
`Forbidden` est une règle contrôlée ou revue. `Blocked` signifie que le produit
ne doit pas accepter ce type de donnée tant que les prérequis manquent.
`Not implemented` ne doit jamais être présenté comme une capacité livrée.

## Principes

1. La collecte est refusée par défaut. Une nouvelle donnée exige une finalité,
   une catégorie, une durée, une action de fin de vie et un propriétaire.
2. Le serveur est autoritaire pour l'état métier ; cette autorité n'autorise pas
   une conservation sans limite.
3. Les clients, journaux et diagnostics ne contiennent ni secret, JWT, payload
   d'authentification, donnée personnelle inutile, ni télémétrie brute durable.
4. Les données de l'ancien dépôt ne sont jamais importées dans le nouveau
   backend.
5. Une donnée pseudonymisée reste traitée comme personnelle. Seule une
   anonymisation irréversible permet de la sortir de ce périmètre.
6. Les durées ci-dessous sont des maxima d'ingénierie initiaux. Elles sont
   réduites lorsque la finalité le permet et revues avant la bêta fermée.

## Classification et rétention

| Catégorie | Finalité minimale | Conservation maximale | Fin de vie |
| --- | --- | --- | --- |
| Identité Auth | Authentifier le compte | Compte actif, puis 30 jours après demande vérifiée | Effacement |
| État de compagnie | Exploiter la compagnie virtuelle | Compte actif, puis 30 jours après demande vérifiée | Effacement ou anonymisation irréversible |
| Grand livre financier | Préserver l'intégrité économique | Lien personnel utile pendant le compte, puis anonymisé sous 30 jours | Conserver seulement l'écriture non personnelle nécessaire à l'intégrité |
| Télémétrie brute de vol | Produire et diagnostiquer un rapport | 7 jours après création du rapport | Effacement |
| Rapport de vol | Historique et progression autoritaire | Compte actif, puis 30 jours après demande vérifiée | Effacement ou anonymisation irréversible |
| Journaux sécurité | Détecter et analyser un incident | 90 jours glissants | Effacement |
| Diagnostics facultatifs | Diagnostiquer un défaut signalé | 30 jours glissants, avec consentement explicite | Effacement |
| Sauvegardes | Reprise après perte ou corruption | 30 jours glissants | Expiration automatique |

Une obligation de conservation légale ou un litige peut imposer une exception,
mais elle exige avant application : motif validé, périmètre minimal, accès
restreint, date de fin et preuve de suppression. T0017 ne détermine aucune base
légale définitive.

## Séparation des environnements

| Environnement | Données admises | Projet distant cible | Règle |
| --- | --- | --- | --- |
| Local | Synthétiques uniquement | Interdit | Pile jetable, loopback et reset local |
| CI | Synthétiques uniquement | Interdit | Pile jetable sans secret applicatif |
| Staging | Synthétiques ou irréversiblement anonymisées | Dédié, non provisionné | Aucun clone ou dump de production |
| Production | Fournies par l'utilisateur ou dérivées côté serveur | Dédié, non provisionné | Accès de moindre privilège et changements promus |

Les futurs projets staging et production doivent être physiquement distincts. Les
migrations append-only sont testées localement et en CI, puis promues vers
staging avant production. Un identifiant, mot de passe, token ou dump ne doit
jamais être partagé entre environnements.

Une exception future pour analyser un incident de production doit privilégier
une extraction minimale et irréversiblement anonymisée. Si l'anonymisation ne
peut être démontrée, la donnée reste en production sous accès restreint ; elle
n'est pas copiée dans un environnement de développement ou de test.

## Suppression, anonymisation et export

Le workflow cible de suppression doit :

1. authentifier de nouveau le propriétaire et créer une commande idempotente ;
2. bloquer les nouvelles mutations sensibles ;
3. exporter les données portables demandées sans secret ni données d'un tiers ;
4. effacer ou anonymiser transactionnellement les liens personnels ;
5. conserver un marqueur non personnel de suppression pour les restaurations ;
6. inscrire une preuve expurgée sans recopier les données supprimées ;
7. terminer sous 30 jours, sauf exception validée et bornée.

Le grand livre futur reste append-only pour empêcher la réécriture économique.
Son identifiant de propriétaire ne doit toutefois pas être l'identité Auth
directe conservée indéfiniment : après suppression, seules les écritures
nécessaires à l'intégrité peuvent rester, sans permettre de réidentifier la
personne.

Avant T0018,
`companies.owner_id references auth.users(id) on delete restrict` empêchait la
suppression directe de l'utilisateur Auth tant que sa compagnie existait. La
migration T0012 reste inchangée et cette limite est suivie par `KI-021` jusqu'à
la preuve de sauvegarde, restauration et replay.

T0018 ajoute cette migration append-only et implémente la tranche locale/CI du
workflow pour l'identité Auth et la compagnie actuelles. Une session créée depuis
5 minutes au plus et une méthode `amr` de connexion récente sont exigées côté
serveur. La demande prépare un export JSON versionné avec SHA-256, bloque les
mutations de compagnie pendant 7 jours, reste récupérable et annulable durant ce
délai, puis une commande réservée au rôle serveur supprime transactionnellement
la compagnie, l'identité et les liens temporaires. Le marqueur final ne conserve
qu'un UUID aléatoire, un hash de jeton de requête aléatoire, une date et la
version d'export.

Les 4 fichiers pgTAP et leurs 70 assertions passent sur PostgreSQL 17 en CI.
Deux transactions réellement concurrentes convergent vers une demande et deux
enregistrements d'idempotence. Cette preuve n'ajoute ni interface utilisateur,
ni projet distant, ni sauvegarde, ni restauration, ni replay post-restauration.
L'admission de données utilisateur réelles reste donc bloquée.

## Sauvegarde et restauration

Avant admission de données réelles, la production doit disposer de sauvegardes
chiffrées, isolées, surveillées et expirant sous 30 jours. Le plan sélectionné
doit réellement fournir cette fenêtre ; la disponibilité commerciale d'une
fonction Supabase n'est pas une preuve de configuration.

Une campagne de restauration doit :

1. restaurer vers une cible isolée et fermée aux utilisateurs ;
2. vérifier intégrité, migrations et contrôles d'accès ;
3. rejouer les suppressions et anonymisations intervenues après le point choisi ;
4. confirmer qu'aucune donnée expirée n'est remise en service ;
5. consigner RPO, RTO, date, environnement, résultat et limites sans secret ;
6. détruire la cible de test ou la promouvoir seulement par une procédure
   d'incident approuvée.

Les sauvegardes PostgreSQL n'incluent pas nécessairement les objets Supabase
Storage. Toute adoption future de Storage exige donc une stratégie et une preuve
de restauration propres aux objets.

T0019 exécute cette mécanique uniquement sur PostgreSQL 17 CI avec des identités
synthétiques. Un dump logique pris avant une demande de suppression est restauré
dans une base distincte, non servie par PostgREST. Un journal pseudonyme
postérieur au point de sauvegarde supprime A sans affecter B ; son rejeu est
idempotent et les événements altéré ou inconnu sont refusés.

## Grand livre financier

T0020 crée une correspondance privée entre la compagnie et un sujet financier
opaque. Les écritures append-only référencent seulement ce sujet et conservent
montant, devise, type et dates techniques nécessaires à l'intégrité économique.
Elles ne contiennent ni identité Auth, ni identifiant ou nom de compagnie.

La suppression T0018 et son replay T0019 détachent et datent la correspondance
dans la même transaction sans réécrire l'historique. Cette anonymisation est
bornée aux données synthétiques local/CI. L'export financier version 2, la purge
des autres catégories, les sauvegardes managées et l'admission de données
réelles restent absents.

La preuve couvre `auth`, `public`, `private`, `extensions` et
`supabase_migrations`. Elle réinstalle `pgcrypto` 1.3 depuis la même image et
restaure les ACL d'objets, mais exclut les `DEFAULT ACL` appartenant aux rôles
internes Supabase. Elle ne couvre ni Vault, Storage, une sauvegarde managée,
le chiffrement fournisseur, la rétention/purge du journal pseudonyme, un RPO/RTO
de production ou la promotion de la cible. L'admission de données réelles reste
donc bloquée.

## Évolution et revue

Une nouvelle catégorie ou un relèvement de durée exige une PR contenant :

- finalité et nécessité ;
- champs exacts et niveau de sensibilité ;
- environnement, accès et destinataires ;
- durée, purge, export, suppression et restauration ;
- tests positifs et négatifs ;
- revue sécurité et, avant données réelles, validation du responsable de
  traitement.

La prochaine revue est requise avant le 30 octobre 2026 et immédiatement avant
la bêta fermée, l'admission de données réelles, l'ajout de télémétrie/diagnostics
ou un changement de fournisseur/région de données.

## Validation

Depuis la racine :

```powershell
pnpm data-policy:check
```

Le harnais valide la source, les environnements, les catégories, les durées, les
seeds synthétiques et l'intégration CI. Il se teste avec trois mutations :
catégorie absente, données de production autorisées en staging et rétention des
journaux portée à 91 jours. Il ne prouve ni suppression, ni export, ni backup,
ni restauration réels.

## Sources officielles

Consultées le 30 juillet 2026 :

- [Règlement (UE) 2016/679, notamment articles 5 et 17](https://eur-lex.europa.eu/legal-content/FR-EN/TXT/?uri=CELEX%3A32016R0679) ;
- [Commission européenne — principes du RGPD](https://commission.europa.eu/law/law-topic/data-protection/information-business-and-organisations/principles-gdpr_en) ;
- [CNIL — minimiser les données collectées](https://www.cnil.fr/fr/minimiser-les-donnees-collectees) ;
- [CNIL — durées de conservation](https://www.cnil.fr/fr/passer-laction/les-durees-de-conservation-des-donnees) ;
- [CNIL — tester vos applications](https://www.cnil.fr/fr/tester-vos-applications) ;
- [CNIL — sauvegarder](https://www.cnil.fr/fr/securite-sauvegarder) ;
- [Supabase — gérer les environnements](https://supabase.com/docs/guides/deployment/managing-environments) ;
- [Supabase — sauvegardes de base de données](https://supabase.com/docs/guides/platform/backups).
