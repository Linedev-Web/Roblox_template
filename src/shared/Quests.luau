-- Objectifs guides (ReplicatedStorage.Shared.Quests)
-- Suivis un par un dans le cadre "Objectif" du HUD. Types d'objectif :
--   taps (count) : taper n fois
--   earn (amount) : total gagne depuis le debut
--   upgrade (id, level) : amelioration au niveau voulu
--   chest (count) : ouvrir n coffres
--   level (level) : atteindre un niveau
-- reward : coins (minutes de gains), gems, boost + minutes, chest (rarete)
local Quests = {
	{ title = "Premiers pas", text = "Tape sur le bouton TAPER pour gagner des pièces.", objective = { type = "taps", count = 20 }, reward = { gems = 5 } },
	{ title = "Plus fort", text = "Ouvre les Améliorations et monte Doigts d'acier.", objective = { type = "upgrade", id = "Force", level = 3 }, reward = { gems = 5 } },
	{ title = "Ça tourne tout seul", text = "Achète un Petit ouvrier : il gagne pour toi.", objective = { type = "upgrade", id = "Ouvrier", level = 1 }, reward = { coins = 2 } },
	{ title = "Petite fortune", text = "Gagne 1 000 pièces au total.", objective = { type = "earn", amount = 1000 }, reward = { chest = "Commun" } },
	{ title = "Chasseur de trésor", text = "Ouvre un coffre dans la fenêtre Coffres.", objective = { type = "chest", count = 1 }, reward = { gems = 10 } },
	{ title = "Niveau 4", text = "Chaque niveau augmente tous tes gains.", objective = { type = "level", level = 4 }, reward = { boost = "Coins", minutes = 10 } },
	{ title = "L'atelier", text = "Achète un Atelier.", objective = { type = "upgrade", id = "Usine", level = 1 }, reward = { gems = 15 } },
	{ title = "Collectionneur", text = "Ouvre 5 coffres.", objective = { type = "chest", count = 5 }, reward = { chest = "Rare" } },
	{ title = "Riche", text = "Gagne 100 000 pièces au total.", objective = { type = "earn", amount = 100000 }, reward = { gems = 25 } },
	{ title = "Expert", text = "Atteins le niveau 8.", objective = { type = "level", level = 8 }, reward = { chest = "Epique" } },
}

Quests.Final = { title = "Bravo !", text = "Tous les objectifs sont faits. Continue de monter de niveau !" }

return Quests
