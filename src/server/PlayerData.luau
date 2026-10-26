-- Profils des joueurs : chargement, sauvegarde et acces (ServerScriptService.Server.PlayerData)
-- Le profil est la seule source de verite cote serveur. Chaque modification passe par
-- PlayerData.update ; l'instantane envoye au client est regroupe (4 envois par seconde au
-- plus) pour que les taps ne saturent pas le reseau.
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Progression = require(ReplicatedStorage.Shared.Progression)
local DataAccess = require(script.Parent.DataAccess)
local Remotes = require(script.Parent.Remotes)

local PlayerData = {}

local store = nil
do
	local ok, result = pcall(DataStoreService.GetDataStore, DataStoreService, Config.DataStoreName)
	if ok then
		store = result
	else
		warn("[Jeu] DataStore indisponible, les profils ne seront pas sauvegardes :", result)
	end
end

local profiles = {}
local loaded = {}
local dirty = {}
local joinedAt = {}
local sessionStart = {}
local changedCallbacks = {}
local readyCallbacks = {}

local function defaultProfile()
	return {
		version = 1,
		coins = 0,
		gems = 0,
		totalEarned = 0,
		level = 1,
		-- [id] = niveau (Config.Upgrades)
		upgrades = {},
		-- coffres gagnes, a ouvrir gratuitement : [id] = nombre
		chests = {},
		quest = { index = 1, progress = 0 },
		records = { taps = 0, chests = 0, playtime = 0 },
		passes = {},
		-- passes offerts par un admin : [id] = fin (os.time), 0 = permanent
		adminPasses = {},
		-- [id] = fin (os.time)
		boosts = {},
		daily = { day = 0, streak = 0 },
		gifts = {},
		receipts = {},
		lastSeen = 0,
	}
end

-- Complete un profil charge avec les champs ajoutes depuis sa creation
local function reconcile(profile)
	for key, value in defaultProfile() do
		if profile[key] == nil then
			profile[key] = value
		elseif type(value) == "table" and type(profile[key]) == "table" then
			for subKey, subValue in value do
				if profile[key][subKey] == nil then
					profile[key][subKey] = subValue
				end
			end
		end
	end
	return profile
end

local function load(player: Player)
	if not store then
		return defaultProfile(), false
	end
	-- Studio sans acces aux API : profil neuf, sans erreur ni nouvel essai
	if not DataAccess.allowed() then
		return defaultProfile(), false, true
	end
	for attempt = 1, 3 do
		local ok, result = pcall(store.GetAsync, store, "u_" .. player.UserId)
		if ok then
			return reconcile(result or defaultProfile()), true
		end
		warn(("[Jeu] Echec du chargement (%d/3) pour %s : %s"):format(attempt, player.Name, tostring(result)))
		task.wait(2)
	end
	return defaultProfile(), false
end

local function addPlaytime(player: Player)
	local profile = profiles[player]
	if profile and joinedAt[player] then
		local now = os.clock()
		profile.records.playtime += math.floor(now - joinedAt[player])
		joinedAt[player] = now - (now - joinedAt[player]) % 1
	end
end

local function save(player: Player)
	local profile = profiles[player]
	if not profile or not store or not loaded[player] then
		return
	end
	addPlaytime(player)
	profile.lastSeen = os.time()
	local ok, err = pcall(store.SetAsync, store, "u_" .. player.UserId, profile)
	if not ok then
		warn("[Jeu] Echec de la sauvegarde pour " .. player.Name .. " : " .. tostring(err))
	end
end

function PlayerData.get(player: Player)
	return profiles[player]
end

function PlayerData.players()
	return profiles
end

function PlayerData.stats(player: Player)
	local profile = profiles[player]
	return profile and Progression.stats(profile, os.time())
end

function PlayerData.sessionMinutes(player: Player): number
	return (os.clock() - (sessionStart[player] or os.clock())) / 60
end

-- Envoie le profil complet au client, avec les valeurs calculees pour l'affichage
local function publish(player: Player)
	local profile = profiles[player]
	if not profile then
		return
	end
	dirty[player] = nil
	local now = os.time()
	local stats = Progression.stats(profile, now)

	local leaderstats = player:FindFirstChild("leaderstats")
	if leaderstats then
		leaderstats.Niveau.Value = stats.level
		leaderstats[Config.Currency.name].Value = math.floor(profile.coins)
	end

	local boosts = {}
	for boost, expires in profile.boosts do
		if expires > now then
			boosts[boost] = expires - now
		end
	end

	Remotes.Profile:FireClient(player, {
		coins = profile.coins,
		gems = profile.gems,
		totalEarned = profile.totalEarned,
		upgrades = profile.upgrades,
		chests = profile.chests,
		quest = profile.quest,
		records = profile.records,
		passes = profile.passes,
		boosts = boosts,
		daily = profile.daily,
		gifts = profile.gifts,
		sessionMinutes = PlayerData.sessionMinutes(player),
		stats = stats,
		level = stats.level,
		serverTime = now,
	})
end

-- Modifie le profil puis programme sa publication. fn(profile) peut renvoyer false pour annuler.
-- immediate : publie tout de suite (fenetres ouvertes, achats)
function PlayerData.update(player: Player, fn, immediate: boolean?)
	local profile = profiles[player]
	if not profile then
		return false
	end
	if fn(profile) == false then
		return false
	end
	if immediate then
		publish(player)
	else
		dirty[player] = true
	end
	for _, callback in changedCallbacks do
		task.spawn(callback, player, profile)
	end
	return true
end

function PlayerData.onChanged(callback)
	table.insert(changedCallbacks, callback)
end

-- Appele pour chaque joueur dont le profil est charge (et ceux deja connectes)
function PlayerData.onReady(callback)
	table.insert(readyCallbacks, callback)
	for player in profiles do
		task.spawn(callback, player, profiles[player])
	end
end

local function onPlayerAdded(player: Player)
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	local level = Instance.new("IntValue")
	level.Name = "Niveau"
	level.Value = 1
	level.Parent = leaderstats
	local coins = Instance.new("NumberValue")
	coins.Name = Config.Currency.name
	coins.Parent = leaderstats
	leaderstats.Parent = player

	local profile, ok, studioOnly = load(player)
	if not player.Parent then
		return
	end
	profiles[player] = profile
	loaded[player] = ok
	joinedAt[player] = os.clock()
	sessionStart[player] = os.clock()
	-- Les cadeaux de temps de jeu repartent a chaque session
	profile.gifts = {}
	if not ok and store and not studioOnly then
		Remotes.notify(player, "Ta progression n'a pas pu être chargée : elle ne sera pas sauvegardée pendant cette partie.", "error")
	end
	publish(player)
	for _, callback in readyCallbacks do
		task.spawn(callback, player, profile)
	end
end

local function onPlayerRemoving(player: Player)
	save(player)
	profiles[player] = nil
	loaded[player] = nil
	dirty[player] = nil
	joinedAt[player] = nil
	sessionStart[player] = nil
end

function PlayerData.start()
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end

	-- Publication regroupee
	task.spawn(function()
		while true do
			task.wait(0.25)
			for player in dirty do
				if player.Parent then
					publish(player)
				else
					dirty[player] = nil
				end
			end
		end
	end)

	task.spawn(function()
		while true do
			task.wait(Config.AutosaveInterval)
			for player in profiles do
				task.spawn(save, player)
			end
		end
	end)

	game:BindToClose(function()
		for player in profiles do
			task.spawn(save, player)
		end
		task.wait(3)
	end)
end

PlayerData.publish = publish

return PlayerData
