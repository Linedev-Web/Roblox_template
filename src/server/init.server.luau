-- Point d'entree serveur (ServerScriptService.Server)
-- La carte est construite dans Studio ; ce script ne demarre que la logique du jeu.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Actions = require(script.Actions)
local GiftService = require(script.GiftService)
local PlayerData = require(script.PlayerData)
local QuestService = require(script.QuestService)
local ShopService = require(script.ShopService)
local TapService = require(script.TapService)

print(("[%s] Serveur demarre"):format(Config.GameName))

QuestService.start()
TapService.start()
ShopService.start()
GiftService.start()
Actions.start()
-- En dernier : les joueurs deja connectes declenchent les rappels des services
PlayerData.start()

print(("[%s] Serveur pret"):format(Config.GameName))
