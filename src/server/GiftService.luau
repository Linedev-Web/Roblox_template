-- Cadeaux : recompense quotidienne et cadeaux de temps de jeu (ServerScriptService.Server.GiftService)
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Progression = require(ReplicatedStorage.Shared.Progression)
local PlayerData = require(script.Parent.PlayerData)
local Remotes = require(script.Parent.Remotes)
local Rewards = require(script.Parent.Rewards)

local GiftService = {}

local function today(): number
	return math.floor(os.time() / 86400)
end

function GiftService.claimDaily(player: Player)
	local profile = PlayerData.get(player)
	if not profile then
		return
	end
	local day = today()
	if profile.daily.day >= day then
		Remotes.notify(player, "Reviens demain pour la prochaine récompense !", "info")
		return
	end
	local streak = if profile.daily.day == day - 1 then profile.daily.streak + 1 else 1
	local gift = Progression.Daily[(streak - 1) % #Progression.Daily + 1]
	PlayerData.update(player, function(p)
		p.daily.day = day
		p.daily.streak = streak
	end)
	local reward = Rewards.concrete(profile, gift)
	Rewards.grant(player, reward, true)
	Remotes.Effect:FireClient(player, "reward", { title = ("JOUR %d"):format(streak), text = Rewards.describe(reward) })
end

function GiftService.claimGift(player: Player, index: number)
	local profile = PlayerData.get(player)
	local minutes = Config.PlaytimeGifts[index]
	local gift = Progression.PlaytimeGifts[index]
	if not profile or not minutes or not gift or profile.gifts[tostring(index)] then
		return
	end
	if PlayerData.sessionMinutes(player) < minutes then
		return
	end
	PlayerData.update(player, function(p)
		p.gifts[tostring(index)] = true
	end)
	local reward = Rewards.concrete(profile, gift)
	Rewards.grant(player, reward, true)
	Remotes.Effect:FireClient(player, "reward", { title = "CADEAU", text = Rewards.describe(reward) })
end

function GiftService.start()
	-- Rappel de la recompense quotidienne a l'arrivee
	PlayerData.onReady(function(player, profile)
		if profile.daily.day < today() then
			task.delay(6, function()
				if player.Parent then
					Remotes.notify(player, "Ta récompense du jour t'attend : bouton Cadeaux.", "quest")
				end
			end)
		end
	end)
end

return GiftService
