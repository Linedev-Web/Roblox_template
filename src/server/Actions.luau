-- Actions envoyees par le client (ServerScriptService.Server.Actions)
-- Toutes les entrees sont verifiees ici avant d'etre transmises aux services.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local ChestService = require(script.Parent.ChestService)
local GiftService = require(script.Parent.GiftService)
local PlayerData = require(script.Parent.PlayerData)
local Remotes = require(script.Parent.Remotes)
local ShopService = require(script.Parent.ShopService)
local TapService = require(script.Parent.TapService)
local UpgradeService = require(script.Parent.UpgradeService)

local Actions = {}

local LIMIT = 30 -- actions par seconde et par joueur
local budgets = {}

local function isString(value): boolean
	return typeof(value) == "string" and #value < 64
end

local handlers = {
	Tap = function(player)
		TapService.tap(player)
	end,
	BuyUpgrade = function(player, id, max)
		if isString(id) then
			UpgradeService.buy(player, id, max == true)
		end
	end,
	OpenChest = function(player, id)
		if isString(id) then
			ChestService.open(player, id)
		end
	end,
	Buy = function(player, kind, id)
		if isString(kind) and isString(id) then
			ShopService.buy(player, kind, id)
		end
	end,
	ClaimDaily = function(player)
		GiftService.claimDaily(player)
	end,
	ClaimGift = function(player, index)
		if typeof(index) == "number" then
			GiftService.claimGift(player, math.floor(index))
		end
	end,
}

-- Outil de test, uniquement dans Studio : ServerStorage.Debug:Invoke(action, ...)
-- joue une action comme le premier joueur ; "Give" ajoute des valeurs au profil
-- (ex. { coins = 1e6, upgrades = { Force = 5 } }), "Profile" renvoie le profil.
local function debugHook()
	local hook = Instance.new("BindableFunction")
	hook.Name = "Debug"
	hook.OnInvoke = function(action, ...)
		local player = Players:GetPlayers()[1]
		if not player then
			return "aucun joueur"
		end
		if action == "Profile" then
			return PlayerData.get(player)
		elseif action == "Give" then
			local fields = ...
			PlayerData.update(player, function(profile)
				for key, value in fields do
					if type(value) == "table" then
						for subKey, subValue in value do
							profile[key][subKey] = if type(subValue) == "number" then (profile[key][subKey] or 0) + subValue else subValue
						end
					elseif type(value) == "number" then
						profile[key] = (profile[key] or 0) + value
					else
						profile[key] = value
					end
				end
			end, true)
			return true
		end
		local handler = handlers[action]
		if handler then
			handler(player, ...)
			return true
		end
		return "action inconnue"
	end
	hook.Parent = game:GetService("ServerStorage")
end

function Actions.start()
	if RunService:IsStudio() then
		debugHook()
	end
	Remotes.Action.OnServerEvent:Connect(function(player, action, ...)
		local now = os.clock()
		local budget = budgets[player]
		if not budget or now - budget.since >= 1 then
			budget = { since = now, count = 0 }
			budgets[player] = budget
		end
		budget.count += 1
		if budget.count > LIMIT then
			return
		end
		local handler = typeof(action) == "string" and handlers[action]
		if handler then
			handler(player, ...)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		budgets[player] = nil
	end)
end

return Actions
