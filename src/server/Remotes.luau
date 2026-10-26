-- Evenements reseau (ServerScriptService.Server.Remotes)
-- Crees a l'execution dans ReplicatedStorage.Remotes
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local folder = Instance.new("Folder")
folder.Name = "Remotes"

local function event(name: string): RemoteEvent
	local remote = Instance.new("RemoteEvent")
	remote.Name = name
	remote.Parent = folder
	return remote
end

local Remotes = {
	-- client -> serveur : (action, ...) voir Server.Actions
	Action = event("Action"),
	-- serveur -> client : (profil) instantane complet du profil
	Profile = event("Profile"),
	-- serveur -> client : (texte, type) type : info, success, error, quest
	Notify = event("Notify"),
	-- serveur -> client : (nom de fenetre, donnees)
	OpenWindow = event("OpenWindow"),
	-- serveur -> client : (type, donnees) effets : level, quest, reward, chest
	Effect = event("Effect"),
}

folder.Parent = ReplicatedStorage

function Remotes.notify(player: Player, text: string, kind: string?)
	Remotes.Notify:FireClient(player, text, kind or "info")
end

return Remotes
