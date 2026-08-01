# Autorité des mutations métier

`eng/authority-inventory.json` est la source canonique de l'autorité des
mutations du golden path. Elle couvre exactement les dix étapes essentielles de
`PRODUCT.md`, même lorsqu'un domaine n'est pas encore implémenté.

## États

- `server-authoritative` : la mutation passe par une commande serveur qui
  valide identité, autorisation et invariants ; `coverage` indique si la tranche
  est complète ou partielle ;
- `external-authority` : l'autorité appartient à un service explicitement
  identifié, actuellement Supabase Auth ;
- `not-implemented` : aucune capacité du nouveau produit n'existe. Cet état ne
  constitue ni une preuve de sécurité fonctionnelle, ni une autorisation de
  l'implémenter côté client.

Une couverture `partial` doit conserver ses limites. Par exemple, le domaine
financier prouve uniquement l'ouverture append-only ; il ne définit aucune
économie de production, clôture de vol, recette ou coût.

## Règle client

La WebView, le processus Tauri et le bridge sont non fiables. Ils peuvent
demander une commande à une frontière serveur authentifiée, mais ne peuvent ni
recevoir le credential `service_role`, ni appeler une commande réservée au
serveur, ni accéder directement à la Data API tant qu'un ticket ne classe pas
cet appel, ni écrire par client Supabase ou SQL embarqué.

`pnpm authority:check` vérifie :

- le schéma fermé de l'inventaire, ses dix étapes et toutes les références de
  domaines ;
- l'existence des preuves, leurs marqueurs d'autorité et les limites des
  couvertures partielles ;
- les trois racines clientes et leurs extensions de source connues ;
- l'absence de credential privilégié, commande service-only ou mutation directe
  dans le code client ;
- cinq mutations négatives déterministes du harnais.

Tout nouveau domaine ou langage client doit mettre à jour l'inventaire et le
gate dans le ticket qui l'introduit. Un domaine passe à `server-authoritative`
uniquement avec sa frontière et ses preuves réelles.
