-- Gains : taps, revenu par seconde et gains hors ligne (ServerScriptService.Server.TapService)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local PlayerData = require(script.Parent.PlayerData)
local QuestService = require(script.Parent.QuestService)
local Remotes = require(script.Parent.Remotes)
local Rewards = require(script.Parent.Rewards)

local TapService = {}

-- Taps acceptes dans la seconde en cours, par joueur
local budgets = {}

function TapService.tap(player: Player)
	local now = os.clock()
	local budget = budgets[player]
	if not budget or now - budget.since >= 1 then
		budget = { since = now, count = 0 }
		budgets[player] = budget
	end
	budget.count += 1
	if budget.count > Config.TapRate then
		return
	end
	local stats = PlayerData.stats(player)
	if not stats then
		return
	end
	Rewards.earn(player, stats.tap)
	PlayerData.update(player, function(profile)
		profile.records.taps += 1
	end)
	QuestService.record(player, "taps")
end

-- Gains pendant l'absence du joueur, annonces a son arrivee
local function offline(player: Player, profile)
	if profile.lastSeen <= 0 then
		return
	end
	local stats = PlayerData.stats(player)
	local elapsed = math.min(os.time() - profile.lastSeen, stats.offlineHours * 3600)
	local amount = math.floor(stats.income * elapsed * Config.OfflineShare)
	if elapsed < 60 or amount <= 0 then
		return
	end
	Rewards.earn(player, amount, true)
	task.delay(2, function()
		if player.Parent then
			Remotes.Effect:FireClient(player, "reward", {
				title = "BON RETOUR !",
				text = ("Pendant ton absence (%s) : +%s %s"):format(Format.duration(elapsed), Format.short(amount), Config.Currency.short),
			})
		end
	end)
end

function TapService.start()
	PlayerData.onReady(offline)
	Players.PlayerRemoving:Connect(function(player)
		budgets[player] = nil
	end)
	-- Revenu par seconde
	task.spawn(function()
		while true do
			task.wait(1)
			for player in PlayerData.players() do
				local stats = PlayerData.stats(player)
				if stats and stats.income > 0 then
					Rewards.earn(player, stats.income)
				end
			end
		end
	end)
end

return TapService
