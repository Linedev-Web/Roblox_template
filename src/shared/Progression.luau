-- Calculs de progression (ReplicatedStorage.Shared.Progression)
-- Partages par le serveur (source de verite) et le client (affichage) : prix des
-- ameliorations, gains par tap et par seconde, niveaux, cadeaux quotidiens.
local Config = require(script.Parent.Config)

local Progression = {}

-- Prix du prochain niveau d'une amelioration (nil si le maximum est atteint)
function Progression.upgradeCost(upgrade, level: number): number?
	if upgrade.max and level >= upgrade.max then
		return nil
	end
	return math.floor(upgrade.cost * upgrade.growth ^ level)
end

-- Niveau atteint avec le total gagne depuis le debut. Le niveau 2 demande 100, puis chaque
-- niveau coute trois fois plus que le precedent.
function Progression.levelThreshold(level: number): number
	if level <= 1 then
		return 0
	end
	return math.floor(100 * 3 ^ (level - 2))
end

function Progression.level(totalEarned: number): number
	local level = 1
	while totalEarned >= Progression.levelThreshold(level + 1) do
		level += 1
	end
	return level
end

-- Gemmes offertes en atteignant un niveau
function Progression.levelReward(level: number): number
	return 5 + level * 2
end

function Progression.boostActive(profile, boost: string, now: number): boolean
	return (profile.boosts[boost] or 0) > now
end

-- Gains courants. now : os.time()
function Progression.stats(profile, now: number)
	local tap, income, percent, offline = 1, 0, 0, Config.OfflineHours
	for _, upgrade in Config.Upgrades do
		local level = profile.upgrades[upgrade.id] or 0
		if level > 0 then
			if upgrade.effect == "tap" then
				tap += upgrade.amount * level
			elseif upgrade.effect == "income" then
				income += upgrade.amount * level
			elseif upgrade.effect == "multiplier" then
				percent += upgrade.amount * level
			elseif upgrade.effect == "offline" then
				offline += upgrade.amount * level
			end
		end
	end
	local level = Progression.level(profile.totalEarned)
	local multiplier = (1 + percent / 100) * (1 + (level - 1) * Config.LevelBonus / 100)
	if profile.passes.DoubleCoins then
		multiplier *= 2
	end
	if Progression.boostActive(profile, "Coins", now) then
		multiplier *= 2
	end
	local luck = 0
	if profile.passes.Lucky then
		luck += 50
	end
	if Progression.boostActive(profile, "Luck", now) then
		luck += 100
	end
	return {
		tap = tap * multiplier,
		income = income * multiplier,
		multiplier = multiplier,
		offlineHours = offline,
		luck = luck,
		level = level,
	}
end

-- Valeur en monnaie principale de quelques minutes de jeu : les recompenses suivent ainsi
-- la progression du joueur
function Progression.minutesOfCoins(profile, minutes: number, now: number): number
	local stats = Progression.stats(profile, now)
	local perSecond = math.max(stats.income + stats.tap * 3, 5)
	return math.floor(perSecond * 60 * minutes)
end

-- Recompenses : coins (minutes de gains), gems, boost + minutes, chest (rarete)
-- Recompenses quotidiennes (7 jours, puis la serie recommence)
Progression.Daily = {
	{ label = "Bourse", coins = 5 },
	{ label = "10 gemmes", gems = 10 },
	{ label = "Gains x2 (15 min)", boost = "Coins", minutes = 15 },
	{ label = "Coffre rare", chest = "Rare" },
	{ label = "Trésor", coins = 30 },
	{ label = "Chance x2 (20 min)", boost = "Luck", minutes = 20 },
	{ label = "Coffre épique", chest = "Epique" },
}

-- Cadeaux de temps de jeu de la session (dans l'ordre de Config.PlaytimeGifts)
Progression.PlaytimeGifts = {
	{ label = "Bourse", coins = 3 },
	{ label = "5 gemmes", gems = 5 },
	{ label = "Coffre commun", chest = "Commun" },
	{ label = "Gains x2 (10 min)", boost = "Coins", minutes = 10 },
	{ label = "Coffre rare", chest = "Rare" },
}

-- Libelles des boosts (puces du HUD, boutique, recompenses)
Progression.Boosts = {
	Coins = { label = "Gains x2", icon = "Boost", color = Color3.fromRGB(230, 80, 170) },
	Luck = { label = "Chance x2", icon = "Etoile", color = Color3.fromRGB(70, 170, 240) },
}

return Progression
