-- Boutique Robux (ReplicatedStorage.Shared.Shop)
-- icon : icone affichee dans la boutique (Shared.Icons)
-- assetId : identifiant du pass ou du produit cree sur le Creator Hub (Monetisation).
-- Tant qu'il vaut 0, l'article affiche "bientot disponible" en ligne et il est offert dans
-- Studio pour pouvoir le tester (Config.StudioFreePurchases).
local Shop = {}

-- Passes : achat unique, effet permanent (lus dans profile.passes)
Shop.Passes = {
	{ id = "DoubleCoins", icon = "Or", name = "Gains x2", description = "Double tout ce que tu gagnes, pour toujours.", price = 199, assetId = 0 },
	{ id = "AutoTap", icon = "Auto", name = "Auto-tap", description = "Tape tout seul, 5 fois par seconde.", price = 149, assetId = 0 },
	{ id = "Lucky", icon = "Etoile", name = "Chanceux", description = "+50 % de chance d'obtenir les gains rares des coffres.", price = 149, assetId = 0 },
}

-- Produits : achats repetables. grant : coins (minutes de gains), gems, boost + minutes,
-- chest (rarete, ouvert tout de suite : achat aleatoire, voir plus bas)
Shop.Products = {
	{ id = "BoostCoins", icon = "Boost", name = "Gains x2", description = "Double tous tes gains pendant 15 minutes.", price = 49, assetId = 0, grant = { boost = "Coins", minutes = 15 } },
	{ id = "BoostLuck", icon = "Etoile", name = "Chance x2", description = "Double la chance des coffres pendant 15 minutes.", price = 49, assetId = 0, grant = { boost = "Luck", minutes = 15 } },
	{ id = "Coins", icon = "Or", name = "Sac de pièces", description = "L'équivalent de 2 heures de gains.", price = 79, assetId = 0, grant = { coins = 120 } },
	{ id = "Gems", icon = "Neant", name = "Poignée de gemmes", description = "150 gemmes.", price = 99, assetId = 0, grant = { gems = 150 } },
	{ id = "LegendChest", icon = "Coffre", name = "Coffre légendaire", description = "Un coffre légendaire ouvert tout de suite. Chances affichées dans Coffres.", price = 99, assetId = 0, grant = { chest = "Legendaire" } },
}

-- Achats aleatoires payants (coffre achete en Robux) : interdits dans certains pays
-- (Belgique, Pays-Bas...). Le serveur pose cet attribut sur le joueur d'apres PolicyService.
Shop.RestrictedAttribute = "PaidRandomRestricted"
Shop.RestrictedMessage = "Les coffres payants ne sont pas disponibles dans ton pays. Tu peux toujours les acheter avec des pièces ou des gemmes !"

function Shop.isPaidRandom(item): boolean
	return item.grant ~= nil and item.grant.chest ~= nil
end

-- Vrai tant que la verification n'a pas confirme que l'achat est autorise
function Shop.paidRandomBlocked(player: Player): boolean
	return player:GetAttribute(Shop.RestrictedAttribute) ~= false
end

Shop.PassById = {}
for _, pass in Shop.Passes do
	Shop.PassById[pass.id] = pass
end
Shop.ProductById = {}
for _, product in Shop.Products do
	Shop.ProductById[product.id] = product
end

return Shop
