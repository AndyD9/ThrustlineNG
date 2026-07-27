# Qualité du shell desktop

Depuis la racine :

```powershell
pnpm desktop:check
pnpm desktop:test
pnpm desktop:build
pnpm desktop:measure
```

Le contrôle combine format Rust, `cargo check --locked`, Clippy avec les
avertissements refusés, tests Rust et invariants Tauri. Le build release est
effectué sans bundle : packaging, signature et installateur restent hors T0007.

La mesure exige une fenêtre réellement visible, cinq lancements froids, cinq
lancements chauds et dix cycles de fermeture. Un échec de fenêtre ou un
processus orphelin rend le script non conforme.
