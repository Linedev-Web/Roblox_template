-- Ameliorations (ServerScriptService.Server.UpgradeService)
-- Achetees avec la monnaie principale, une a la fois ou autant que possible (max).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Progression = require(ReplicatedStorage.Shared.Progression)
local PlayerData = require(script.Parent.PlayerData)
local Remotes = require(script.Parent.Remotes)

local UpgradeService = {}

function UpgradeService.buy(player: Player, id: string, max: boolean)
	local upgrade = Config.UpgradeById[id]
	if not upgrade then
		return
	end
	local bought = 0
	PlayerData.update(player, function(profile)
		while true do
			local level = profile.upgrades[id] or 0
			local cost = Progression.upgradeCost(upgrade, level)
			if not cost or profile.coins < cost then
				break
			end
			profile.coins -= cost
			profile.upgrades[id] = level + 1
			bought += 1
			if not max or bought >= 1000 then
				break
			end
		end
		return bought > 0
	end, true)
	if bought == 0 then
		local level = (PlayerData.get(player) and PlayerData.get(player).upgrades[id]) or 0
		local text = if Progression.upgradeCost(upgrade, level) then ("Il te manque des %s."):format(Config.Currency.short) else "Niveau maximum atteint."
		Remotes.notify(player, text, "error")
	end
end

return UpgradeService
