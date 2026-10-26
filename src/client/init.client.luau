-- Point d'entree client (StarterPlayerScripts.Client)
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Effects = require(script.Effects)
local HUD = require(script.HUD)
local Reveal = require(script.Reveal)
local Sons = require(script.Sons)
local Windows = require(script.Windows)

print(("[%s] Client demarre"):format(Config.GameName))

local gui = HUD.start(Windows.open)
Windows.start(gui)
Effects.start(gui)
Reveal.start(gui)
Sons.start()
