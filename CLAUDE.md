# Template de jeu incrémental Roblox (Linedev)

Ce dossier est le **socle commun** de tous les petits jeux incrémentaux de Yoan (marque Linedev).
Il ne se lance pas tel quel en production : on le **copie** pour créer un nouveau jeu
(`nouveau-jeu.ps1`), puis on adapte le thème et le contenu. Tout ce qui est ici a été
validé sur le premier jeu (Rappelz / « Tap & Tame ») : disposition des boutons ordinateur et
mobile, style de l'interface, boutique, cadeaux, boosts, roulette des coffres.

Lis ce fichier en entier avant d'agir, dans le template comme dans un jeu créé à partir de lui.

## 1. Règles de travail permanentes

- Communication en français clair et professionnel, accents compris, sans emoji.
- Préfixer les commandes shell par `rtk` (voir le CLAUDE.md global).
- Les fichiers de `src/` font foi : ne jamais modifier les scripts directement dans Studio,
  ils seraient écrasés par Rojo.
- La carte, les décors et les modèles se construisent dans Studio (MCP Roblox Studio), puis
  « Fichier > Sauvegarder sur Roblox ». Ne jamais modifier ni supprimer le `.rbxl` de sauvegarde
  d'un jeu (seulement le remplacer par une copie téléchargée depuis Studio, à la demande).
- Commits réguliers, petits et clairs, messages en français. Ne jamais pousser de secrets.
- Toute amélioration générique faite dans un jeu (bug corrigé, composant utile à tous) doit
  être reportée dans ce template, avec un commit dédié.

## 2. Créer un nouveau jeu

```powershell
cd C:\workspace\Roblox\Template
.\nouveau-jeu.ps1 -Nom "MonJeu" -Titre "Mon Super Jeu"
```

Le script copie le template dans `C:\workspace\Roblox\MonJeu`, renomme le projet Rojo,
le nom affiché (`Config.GameName`) et le DataStore, construit `MonJeu.rbxl` (sol, point
d'apparition et scripts) et initialise Git. Ensuite :

1. Ouvrir `MonJeu.rbxl` dans Studio, puis « Fichier > Sauvegarder sur Roblox » (nouvelle expérience).
2. `rojo serve` dans le dossier du jeu, puis plugin Rojo > Connect dans Studio.
3. Paramètres du jeu > Sécurité : cocher « Enable Studio Access to API Services » pour tester la sauvegarde.
4. Adapter le thème (section 4), construire la carte dans Studio.
5. Avant la mise en ligne : créer les passes et produits sur le Creator Hub (Monétisation) et
   reporter leurs identifiants dans `src/shared/Shop.luau` (`assetId`).

## 3. Ce que contient le socle

| Fichier | Rôle |
|---|---|
| `shared/Config.luau` | Nom du jeu, DataStore, monnaies, améliorations, raretés : **premier fichier à adapter** |
| `shared/Progression.luau` | Prix des améliorations, gains par tap et par seconde, niveaux, cadeaux quotidiens et de temps de jeu, boosts |
| `shared/Chests.luau` | Coffres : prix, contenus, chances (affichées partout), bonus de chance |
| `shared/Quests.luau` | Objectifs guidés affichés à droite (taps, total gagné, amélioration, coffres, niveau) |
| `shared/Shop.luau` | Boutique Robux : passes (à vie) et produits (boosts, packs, coffre payant) |
| `shared/Icons.luau` | Identifiants Roblox des icônes (déjà envoyées sur le compte, réutilisables) |
| `shared/Format.luau` | Nombres courts (« 1,2 k », « 3,5 M »), durées, pourcentages |
| `server/PlayerData.luau` | Profil joueur : chargement, sauvegarde auto, envoi regroupé au client |
| `server/Rewards.luau` | Gains (`earn`, niveaux), récompenses décrites ou concrètes |
| `server/TapService.luau` | Taps (anti-triche), revenu par seconde, gains hors ligne |
| `server/UpgradeService.luau`, `ChestService.luau`, `GiftService.luau`, `QuestService.luau`, `ShopService.luau` | Un service par système |
| `server/Actions.luau` | Seule porte d'entrée des actions du client, toutes vérifiées ; crochet de test Studio |
| `client/UI.luau` | Thème et composants : boutons, fenêtres, barres, icônes, échelle d'écran, disposition tactile |
| `client/HUD.luau` | Interface permanente, menu (`MENU` en haut du fichier), TAPER, objectif, notifications, annonces |
| `client/Windows.luau` | Fenêtres Améliorations, Coffres, Cadeaux, Boutique |
| `client/Reveal.luau` | Roulette d'ouverture des coffres (chances affichées) |
| `client/Effects.luau`, `Sons.luau` | Chiffres de gain, sons et musique |

Boucle de jeu : taper → pièces → améliorations (par tap, par seconde, multiplicateur, hors
ligne) → niveaux (bonus de gains + gemmes) → coffres en roulette → boosts. Cadeaux quotidiens et
de temps de jeu, objectifs guidés, gains hors ligne : le joueur a toujours quelque chose à faire
et voit sa progression.

## 4. Adapter le socle à un nouveau jeu

- **Thème** : `Config.GameName`, `Config.Currency`, `Config.Premium` (nom + icône).
- **Améliorations** : liste `Config.Upgrades` (effets `tap`, `income`, `multiplier`, `offline`).
  Un nouvel effet s'ajoute dans `Progression.stats`.
- **Coffres** : `Chests.List` (prix en minutes de gains ou en gemmes, contenus, `rare`).
- **Objectifs** : `Quests` ; un nouveau type s'ajoute dans `QuestService.done` et dans le suivi du HUD.
- **Boutique** : `Shop.Passes` / `Shop.Products` ; l'effet d'un pass se lit dans `profile.passes`.
- **Menu** : table `MENU` en haut de `HUD.luau` (fenêtre, libellé, icône, raccourci, couleur),
  pastilles rouges dans `BADGES`. La disposition ordinateur / tactile se recalcule seule.
- **Nouvelle fenêtre** : une fonction `build...` dans `Windows.luau` enregistrée dans `openers`.
- **Nouvelle action client** : un gestionnaire dans `Actions.luau` (vérifier chaque argument).
- **Nouvelle donnée de profil** : `defaultProfile` dans `PlayerData.luau` (les anciens profils
  sont complétés automatiquement) puis l'ajouter à l'envoi `publish` si le client en a besoin.
- **Nouvelle icône** : `tools/icones/generer_icones.py`, envoi sur Roblox, identifiant dans `Icons.luau`.

## 5. Interface : ce qui est validé (ne pas changer sans maquette)

- Police **FredokaOne** pour les titres et nombres, BuilderSansBold pour les textes ; couleurs
  vives, contours sombres épais, dégradés, reflets sur les boutons. Public jeune : de la couleur,
  des choses qui accrochent l'œil.
- Disposition **ordinateur** : ressources en haut à gauche, monnaie principale + niveau + bonus
  en haut au centre, menu en grille de 2 colonnes à gauche avec raccourcis clavier, TAPER en bas
  au centre (auto à droite, musique à gauche), objectif à droite, notifications en bas à droite.
- Disposition **tactile** : menu en rangée en haut à droite (sans raccourcis), objectif dessous,
  TAPER en bas à droite à côté du saut, moitié gauche libre pour le joystick.
- Toute l'interface suit la taille de l'écran (`UI.autoScale`) et le passage souris / tactile
  (`UI.onLayout`).
- Pas de zoom ni de montée au survol des **cartes** (les boutons, eux, réagissent).
- Chances toujours affichées avant un achat aléatoire ; roulette pour chaque ouverture.
- Toute action doit être animée et se voir (« il faut voir ce qu'on a fait »).
- **Avant tout changement visuel important** : montrer une maquette HTML avec 2 ou 3 variantes
  et n'appliquer que celle choisie. Une refonte « Empire » (bois sombre, serif, losanges) a été
  rejetée sur Rappelz.
- Piège : dans un cadre qui a un `UIListLayout` ou `UIGridLayout`, tout enfant ajouté devient
  un élément de la liste (décorations comprises).

## 6. Tester

- Dans Studio, les achats sans identifiant sont offerts (`Config.StudioFreePurchases`).
- Crochet de test (Studio seulement), depuis la barre de commande côté serveur :
  `game.ServerStorage.Debug:Invoke("Give", { coins = 1e6, gems = 500 })`,
  `Invoke("Profile")`, ou toute action (`Invoke("OpenChest", "Rare")`).
- Linter : `selene src` (configuration `selene.toml` + `roblox.yml` à la racine).
- Le MCP Studio ne peut pas faire de capture d'écran sur ce PC : vérifier par le code
  (contenu de PlayerGui, profil, console).

## 7. Conformité Roblox

- Coffres payés en Robux = achats aléatoires payants : bloqués automatiquement dans les pays
  qui les interdisent (`PolicyService`), chances affichées.
- Produits accordés une seule fois par achat (`ProcessReceipt` + reçus mémorisés).
- Aucun identifiant secret dans le dépôt.
