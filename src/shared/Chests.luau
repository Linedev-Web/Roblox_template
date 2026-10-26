-- Coffres (ReplicatedStorage.Shared.Chests)
-- Achetes dans la fenetre Coffres (ou gagnes en cadeau), ouverts avec la roulette (Client.Reveal).
-- Les chances sont toujours affichees avant l'achat et pendant l'ouverture.
local Progression = require(script.Parent.Progression)

local Chests = {}

-- price : prix d'achat ; currency : "coins" (monnaie principale, en minutes de gains du
-- joueur, voir Progression.minutesOfCoins) ou "gems" (montant fixe)
-- Contenu : kind = coins (minutes de gains), gems, boost (id + minutes) ; chance en % ;
-- rare = true : profite des bonus de chance
Chests.List = {
	{
		id = "Commun",
		currency = "coins",
		price = 2,
		contents = {
			{ kind = "coins", amount = 1, chance = 55, label = "Petite bourse" },
			{ kind = "coins", amount = 4, chance = 30, label = "Bourse" },
			{ kind = "gems", amount = 3, chance = 12, label = "3 gemmes", rare = true },
			{ kind = "boost", boost = "Coins", amount = 5, chance = 3, label = "Gains x2 (5 min)", rare = true },
		},
	},
	{
		id = "Rare",
		currency = "coins",
		price = 10,
		contents = {
			{ kind = "coins", amount = 6, chance = 45, label = "Sac de pièces" },
			{ kind = "coins", amount = 20, chance = 25, label = "Gros sac" },
			{ kind = "gems", amount = 10, chance = 20, label = "10 gemmes", rare = true },
			{ kind = "boost", boost = "Coins", amount = 10, chance = 10, label = "Gains x2 (10 min)", rare = true },
		},
	},
	{
		id = "Epique",
		currency = "gems",
		price = 25,
		contents = {
			{ kind = "coins", amount = 40, chance = 40, label = "Coffret" },
			{ kind = "gems", amount = 30, chance = 30, label = "30 gemmes" },
			{ kind = "boost", boost = "Luck", amount = 15, chance = 20, label = "Chance x2 (15 min)", rare = true },
			{ kind = "coins", amount = 150, chance = 10, label = "Trésor", rare = true },
		},
	},
	{
		id = "Legendaire",
		currency = "gems",
		price = 80,
		contents = {
			{ kind = "coins", amount = 120, chance = 40, label = "Grand trésor" },
			{ kind = "gems", amount = 90, chance = 30, label = "90 gemmes" },
			{ kind = "boost", boost = "Coins", amount = 30, chance = 20, label = "Gains x2 (30 min)", rare = true },
			{ kind = "coins", amount = 600, chance = 10, label = "Fortune", rare = true },
		},
	},
}

Chests.ById = {}
for index, chest in Chests.List do
	chest.index = index
	Chests.ById[chest.id] = chest
end

-- Prix concret d'un coffre pour ce joueur : (montant, "coins" ou "gems")
function Chests.cost(profile, chest, now: number): (number, string)
	if chest.currency == "gems" then
		return chest.price, "gems"
	end
	return Progression.minutesOfCoins(profile, chest.price, now), "coins"
end

-- Chances reelles (en %) avec le bonus de chance du joueur : les entrees "rare" sont
-- multipliees par (1 + luck / 100), puis le tout est ramene a 100 %
function Chests.odds(contents, luck: number?)
	local factor = 1 + (luck or 0) / 100
	local total = 0
	local weights = {}
	for index, entry in contents do
		weights[index] = entry.chance * (if entry.rare then factor else 1)
		total += weights[index]
	end
	for index in weights do
		weights[index] = weights[index] / total * 100
	end
	return weights
end

-- Tire une entree. Renvoie (entree, index).
function Chests.roll(contents, luck: number?, rng: Random)
	local odds = Chests.odds(contents, luck)
	local roll = rng:NextNumber(0, 100)
	for index, entry in contents do
		roll -= odds[index]
		if roll <= 0 then
			return entry, index
		end
	end
	return contents[#contents], #contents
end

return Chests
