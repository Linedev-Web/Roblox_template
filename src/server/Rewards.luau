-- Gains et recompenses (ServerScriptService.Server.Rewards)
-- Deux formes de recompense :
--   description (cadeaux, objectifs, coffres, boutique) : coins = minutes de gains du joueur,
--     gems, boost + minutes, chest = rarete
--   concrete (apres Rewards.concrete) : coins = montant, gems, boost = { id, minutes }, chest
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local Progression = require(ReplicatedStorage.Shared.Progression)
local PlayerData = require(script.Parent.PlayerData)
local Remotes = require(script.Parent.Remotes)

local Rewards = {}

-- Ajoute de la monnaie principale gagnee en jouant (compte pour le niveau) et annonce les
-- niveaux passes, chacun recompense par des gemmes
function Rewards.earn(player: Player, amount: number, immediate: boolean?)
	if amount <= 0 then
		return
	end
	local reached = {}
	PlayerData.update(player, function(profile)
		profile.coins += amount
		profile.totalEarned += amount
		local level = Progression.level(profile.totalEarned)
		while profile.level < level do
			profile.level += 1
			local gems = Progression.levelReward(profile.level)
			profile.gems += gems
			table.insert(reached, { level = profile.level, gems = gems })
		end
	end, immediate)
	if #reached > 0 and not immediate then
		PlayerData.publish(player)
	end
	for _, entry in reached do
		Remotes.Effect:FireClient(player, "level", entry)
	end
end

-- Transforme une description de recompense en montants pour ce joueur
function Rewards.concrete(profile, spec)
	local reward = {}
	if spec.coins then
		reward.coins = Progression.minutesOfCoins(profile, spec.coins, os.time())
	end
	if spec.gems then
		reward.gems = spec.gems
	end
	if spec.boost then
		reward.boost = { id = spec.boost, minutes = spec.minutes or 10 }
	end
	if spec.chest then
		reward.chest = spec.chest
	end
	return reward
end

function Rewards.grant(player: Player, reward, immediate: boolean?)
	if reward.coins then
		Rewards.earn(player, reward.coins)
	end
	PlayerData.update(player, function(profile)
		if reward.gems then
			profile.gems += reward.gems
		end
		if reward.boost then
			local now = os.time()
			profile.boosts[reward.boost.id] = math.max(profile.boosts[reward.boost.id] or 0, now) + reward.boost.minutes * 60
		end
		if reward.chest then
			profile.chests[reward.chest] = (profile.chests[reward.chest] or 0) + 1
		end
	end, immediate)
end

function Rewards.describe(reward): string
	local parts = {}
	if reward.coins then
		table.insert(parts, Format.short(reward.coins) .. " " .. Config.Currency.short)
	end
	if reward.gems then
		table.insert(parts, Format.short(reward.gems) .. " " .. Config.Premium.short)
	end
	if reward.boost then
		local boost = Progression.Boosts[reward.boost.id]
		table.insert(parts, ("%s (%s)"):format(if boost then boost.label else reward.boost.id, Format.duration(reward.boost.minutes * 60)))
	end
	if reward.chest then
		for _, rarity in Config.ChestRarities do
			if rarity.id == reward.chest then
				table.insert(parts, "Coffre " .. rarity.label:lower())
			end
		end
	end
	return table.concat(parts, ", ")
end

return Rewards
