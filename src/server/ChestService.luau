-- Coffres (ServerScriptService.Server.ChestService)
-- Un coffre gagne (profile.chests) s'ouvre gratuitement ; sinon il est paye en pieces ou en
-- gemmes. Le tirage tient compte de la chance du joueur ; le client joue la roulette.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Chests = require(ReplicatedStorage.Shared.Chests)
local Config = require(ReplicatedStorage.Shared.Config)
local PlayerData = require(script.Parent.PlayerData)
local QuestService = require(script.Parent.QuestService)
local Remotes = require(script.Parent.Remotes)
local Rewards = require(script.Parent.Rewards)

local ChestService = {}

local rng = Random.new()

function ChestService.open(player: Player, id: string)
	local chest = Chests.ById[id]
	local profile = PlayerData.get(player)
	if not chest or not profile then
		return
	end
	local now = os.time()
	local paid = PlayerData.update(player, function(p)
		if (p.chests[id] or 0) > 0 then
			p.chests[id] -= 1
		else
			local cost, currency = Chests.cost(p, chest, now)
			local field = if currency == "gems" then "gems" else "coins"
			if p[field] < cost then
				return false
			end
			p[field] -= cost
		end
		p.records.chests += 1
	end)
	if not paid then
		local currency = if chest.currency == "gems" then Config.Premium.short else Config.Currency.short
		Remotes.notify(player, ("Il te manque des %s pour ce coffre."):format(currency), "error")
		return
	end
	local luck = PlayerData.stats(player).luck
	local entry, index = Chests.roll(chest.contents, luck, rng)
	local reward = Rewards.concrete(profile, { coins = if entry.kind == "coins" then entry.amount else nil, gems = if entry.kind == "gems" then entry.amount else nil, boost = entry.boost, minutes = entry.amount })
	Rewards.grant(player, reward, true)
	Remotes.Effect:FireClient(player, "chest", { id = id, index = index, luck = luck, reward = Rewards.describe(reward) })
	QuestService.record(player, "chest")
end

return ChestService
