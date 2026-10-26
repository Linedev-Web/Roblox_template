-- Configuration generale (ReplicatedStorage.Shared.Config)
-- C'est le premier fichier a adapter pour un nouveau jeu : nom, monnaies, ameliorations.
local Config = {}

-- Nom affiche dans le jeu (annonces, journaux de la console)
Config.GameName = "Mon Jeu"

-- Sauvegarde des joueurs. Changer le nom repart de profils vierges.
Config.DataStoreName = "MonJeu_Profils_v1"
Config.AutosaveInterval = 120

-- Monnaies : la principale se gagne en tapant et en continu, la premium dans les cadeaux,
-- les objectifs et les coffres. Seuls les noms et les icones sont affiches (Shared.Icons).
Config.Currency = { name = "Pièces", short = "pièces", icon = "Or", color = Color3.fromRGB(255, 205, 60) }
Config.Premium = { name = "Gemmes", short = "gemmes", icon = "Neant", color = Color3.fromRGB(165, 95, 255) }

-- Tap
Config.TapRate = 10 -- taps pris en compte par seconde au maximum (anti-triche)
Config.AutoTapRate = 5 -- taps par seconde avec le pass Auto-tap

-- Gains hors ligne : part du revenu par seconde, plafonnee (les ameliorations "offline"
-- ajoutent des heures au plafond)
Config.OfflineShare = 0.5
Config.OfflineHours = 2

-- Bonus de niveau : chaque niveau ajoute ce pourcentage a tous les gains
Config.LevelBonus = 5

-- Recompenses de temps de jeu (minutes de la session en cours), detail dans Shared.Progression
Config.PlaytimeGifts = { 3, 8, 15, 25, 40 }

-- Achats de test : dans Studio uniquement, un article sans identifiant Roblox (assetId = 0)
-- est offert pour pouvoir le tester
Config.StudioFreePurchases = true
-- Simule dans Studio un pays ou les achats aleatoires payants sont interdits
Config.StudioPaidRandomRestricted = false

-- Ameliorations achetees avec la monnaie principale. Le prix du niveau n vaut
-- cost * growth ^ (n - 1). effect :
--   tap : + amount par tap
--   income : + amount par seconde
--   multiplier : + amount % sur tous les gains
--   offline : + amount heures de gains hors ligne
-- max : niveau maximum (facultatif)
Config.Upgrades = {
	{ id = "Force", name = "Doigts d'acier", description = "+1 pièce par tap.", icon = "Puissance", effect = "tap", amount = 1, cost = 15, growth = 1.15 },
	{ id = "Ouvrier", name = "Petit ouvrier", description = "+1 pièce par seconde, même sans taper.", icon = "Auto", effect = "income", amount = 1, cost = 50, growth = 1.17 },
	{ id = "Usine", name = "Atelier", description = "+8 pièces par seconde.", icon = "Ameliorer", effect = "income", amount = 8, cost = 600, growth = 1.18 },
	{ id = "Banque", name = "Banque", description = "+60 pièces par seconde.", icon = "Coffre", effect = "income", amount = 60, cost = 7500, growth = 1.19 },
	{ id = "Talent", name = "Talent", description = "+10 % sur tous les gains.", icon = "Etoile", effect = "multiplier", amount = 10, cost = 2000, growth = 1.6 },
	{ id = "Sommeil", name = "Coffre de nuit", description = "+1 h de gains hors ligne.", icon = "Horloge", effect = "offline", amount = 1, cost = 5000, growth = 2.2, max = 10 },
}

-- Raretes des coffres (couleur des cartes et des bandeaux)
Config.ChestRarities = {
	{ id = "Commun", label = "Commun", color = Color3.fromRGB(200, 205, 215) },
	{ id = "Rare", label = "Rare", color = Color3.fromRGB(90, 165, 255) },
	{ id = "Epique", label = "Épique", color = Color3.fromRGB(190, 110, 255) },
	{ id = "Legendaire", label = "Légendaire", color = Color3.fromRGB(255, 190, 60) },
}

Config.UpgradeById = {}
for index, upgrade in Config.Upgrades do
	upgrade.index = index
	Config.UpgradeById[upgrade.id] = upgrade
end

return Config
