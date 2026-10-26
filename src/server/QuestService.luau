-- Objectifs guides (ServerScriptService.Server.QuestService)
-- Les objectifs a compter (taps, coffres) avancent avec QuestService.record ; les autres
-- (total gagne, amelioration, niveau) sont verifies a chaque changement du profil.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Quests = require(ReplicatedStorage.Shared.Quests)
local PlayerData = require(script.Parent.PlayerData)
local Remotes = require(script.Parent.Remotes)
local Rewards = require(script.Parent.Rewards)

local QuestService = {}

local function done(profile, quest): boolean
	local objective = quest.objective
	if objective.type == "taps" or objective.type == "chest" then
		return profile.quest.progress >= objective.count
	elseif objective.type == "earn" then
		return profile.totalEarned >= objective.amount
	elseif objective.type == "upgrade" then
		return (profile.upgrades[objective.id] or 0) >= objective.level
	elseif objective.type == "level" then
		return profile.level >= objective.level
	end
	return false
end

local function check(player: Player)
	local profile = PlayerData.get(player)
	local quest = profile and Quests[profile.quest.index]
	if not quest or not done(profile, quest) then
		return
	end
	PlayerData.update(player, function(p)
		p.quest.index += 1
		p.quest.progress = 0
	end, true)
	local reward = Rewards.concrete(profile, quest.reward or {})
	Rewards.grant(player, reward, true)
	Remotes.Effect:FireClient(player, "quest", { title = quest.title, reward = Rewards.describe(reward) })
end

-- kind : "taps" ou "chest"
function QuestService.record(player: Player, kind: string, amount: number?)
	local profile = PlayerData.get(player)
	local quest = profile and Quests[profile.quest.index]
	if quest and quest.objective.type == kind then
		PlayerData.update(player, function(p)
			p.quest.progress += amount or 1
		end)
	end
end

function QuestService.start()
	PlayerData.onChanged(check)
	PlayerData.onReady(check)
end

return QuestService
