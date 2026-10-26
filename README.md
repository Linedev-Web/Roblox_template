# Template de jeu incrémental Roblox

Socle commun des jeux incrémentaux Linedev : interface validée (ordinateur et mobile),
taps, revenus, améliorations, niveaux, coffres en roulette, boosts, cadeaux, objectifs,
boutique Robux et sauvegarde.

## Créer un jeu

```powershell
.\nouveau-jeu.ps1 -Nom "MonJeu" -Titre "Mon Super Jeu"
```

Puis ouvrir `..\MonJeu\MonJeu.rbxl` dans Studio, « Sauvegarder sur Roblox », `rojo serve`
et plugin Rojo > Connect. Détails dans `CLAUDE.md`.

## Organisation

- `src/server` : scripts serveur (ServerScriptService.Server)
- `src/client` : scripts client (StarterPlayerScripts.Client)
- `src/shared` : modules partagés (ReplicatedStorage.Shared)
- `default.project.json` : synchronisation Rojo des scripts
- `place.project.json` : place de départ (sol, point d'apparition, scripts) pour `rojo build`
- `assets/icones`, `tools/icones` : icônes du jeu et leur générateur
