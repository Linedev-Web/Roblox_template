-- Boutique Robux (ServerScriptService.Server.ShopService)
-- Passes verifies a chaque connexion, produits accordes par ProcessReceipt (une seule fois
-- par achat). Dans Studio, un article sans identifiant est offert pour pouvoir le tester.
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local PolicyService = game:GetService("PolicyService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Shop = require(ReplicatedStorage.Shared.Shop)
local ChestService = require(script.Parent.ChestService)
local PlayerData = require(script.Parent.PlayerData)
local Remotes = require(script.Parent.Remotes)
local Rewards = require(script.Parent.Rewards)

local ShopService = {}

-- Passes achetes avec des Robux (verifies aupres de Roblox), par joueur
local ownedPasses = {}

local function testMode(): boolean
	return RunService:IsStudio() and Config.StudioFreePurchases
end

-- Pays du joueur : achats aleatoires payants autorises ou non. En cas d'echec de la
-- verification, l'achat reste bloque par prudence.
local function checkPolicy(player: Player)
	local restricted = true
	if RunService:IsStudio() then
		restricted = Config.StudioPaidRandomRestricted
	else
		local ok, info = pcall(PolicyService.GetPolicyInfoForPlayerAsync, PolicyService, player)
		if ok and info then
			restricted = info.ArePaidRandomItemsRestricted
		end
	end
	if player.Parent then
		player:SetAttribute(Shop.RestrictedAttribute, restricted)
	end
end

local function grantPass(player: Player, passId: string)
	local pass = Shop.PassById[passId]
	if not RunService:IsStudio() then
		ownedPasses[player] = ownedPasses[player] or {}
		ownedPasses[player][passId] = true
	end
	PlayerData.update(player, function(profile)
		profile.passes[passId] = true
	end, true)
	Remotes.Effect:FireClient(player, "reward", { title = "MERCI !", text = pass.name .. " est activé." })
end

local function grantProduct(player: Player, product): boolean
	local profile = PlayerData.get(player)
	if not profile then
		return false
	end
	local reward = Rewards.concrete(profile, product.grant)
	Rewards.grant(player, reward, true)
	if reward.chest then
		-- Coffre achete : ouvert tout de suite avec la roulette
		ChestService.open(player, reward.chest)
	else
		Remotes.Effect:FireClient(player, "reward", { title = "MERCI !", text = Rewards.describe(reward) })
	end
	return true
end

-- Demande d'achat depuis la boutique du client
function ShopService.buy(player: Player, kind: string, id: string)
	if kind == "pass" then
		local pass = Shop.PassById[id]
		if not pass then
			return
		end
		local profile = PlayerData.get(player)
		if profile and profile.passes[id] then
			Remotes.notify(player, "Tu possèdes déjà ce pass.", "info")
			return
		end
		if pass.assetId > 0 then
			MarketplaceService:PromptGamePassPurchase(player, pass.assetId)
		elseif testMode() then
			grantPass(player, id)
			Remotes.notify(player, "Test Studio : pass offert (aucun Robux dépensé).", "info")
		else
			Remotes.notify(player, "Cet article sera bientôt disponible.", "info")
		end
	elseif kind == "product" then
		local product = Shop.ProductById[id]
		if not product then
			return
		end
		if Shop.isPaidRandom(product) and Shop.paidRandomBlocked(player) then
			Remotes.notify(player, Shop.RestrictedMessage, "info")
			return
		end
		if product.assetId > 0 then
			MarketplaceService:PromptProductPurchase(player, product.assetId)
		elseif testMode() then
			grantProduct(player, product)
			Remotes.notify(player, "Test Studio : article offert (aucun Robux dépensé).", "info")
		else
			Remotes.notify(player, "Cet article sera bientôt disponible.", "info")
		end
	end
end

function ShopService.ownsPass(player: Player, passId: string): boolean
	return ownedPasses[player] ~= nil and ownedPasses[player][passId] == true
end

local function checkPasses(player: Player)
	if RunService:IsStudio() then
		return
	end
	-- En ligne : passes achetes sur Roblox, plus ceux offerts par un admin encore valables
	local owned = {}
	for _, pass in Shop.Passes do
		if pass.assetId > 0 then
			local ok, result = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, player.UserId, pass.assetId)
			if ok and result then
				owned[pass.id] = true
			end
		end
	end
	ownedPasses[player] = owned
	local now = os.time()
	PlayerData.update(player, function(profile)
		local passes = table.clone(owned)
		for id, ends in profile.adminPasses or {} do
			if ends == 0 or ends > now then
				passes[id] = true
			end
		end
		profile.passes = passes
	end)
end

function ShopService.start()
	PlayerData.onReady(checkPasses)
	Players.PlayerAdded:Connect(checkPolicy)
	for _, player in Players:GetPlayers() do
		task.spawn(checkPolicy, player)
	end
	Players.PlayerRemoving:Connect(function(player)
		ownedPasses[player] = nil
	end)

	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, assetId, purchased)
		if not purchased then
			return
		end
		for _, pass in Shop.Passes do
			if pass.assetId == assetId then
				grantPass(player, pass.id)
			end
		end
	end)

	MarketplaceService.ProcessReceipt = function(info)
		local player = Players:GetPlayerByUserId(info.PlayerId)
		local profile = player and PlayerData.get(player)
		if not profile then
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		if table.find(profile.receipts, info.PurchaseId) then
			return Enum.ProductPurchaseDecision.PurchaseGranted
		end
		for _, product in Shop.Products do
			if product.assetId == info.ProductId then
				if not grantProduct(player, product) then
					return Enum.ProductPurchaseDecision.NotProcessedYet
				end
				table.insert(profile.receipts, info.PurchaseId)
				if #profile.receipts > 50 then
					table.remove(profile.receipts, 1)
				end
				return Enum.ProductPurchaseDecision.PurchaseGranted
			end
		end
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
end

return ShopService
