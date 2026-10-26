-- Acces aux DataStores (ServerScriptService.Server.DataAccess)
-- Dans Studio, Roblox refuse les DataStores tant que "Enable Studio Access to API Services"
-- n'est pas coche (Parametres du jeu > Securite) : chaque appel affiche alors une erreur.
-- On teste l'acces une seule fois et, s'il est refuse, la sauvegarde est coupee pour la
-- session, avec un seul message. En ligne, l'acces est toujours autorise.
local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")

local DataAccess = {}

local state = nil -- nil (pas encore teste), "pending", true ou false

function DataAccess.allowed(): boolean
	if not RunService:IsStudio() then
		return true
	end
	while state == "pending" do
		task.wait()
	end
	if state ~= nil then
		return state == true
	end
	state = "pending"
	local ok = pcall(function()
		DataStoreService:GetDataStore("TestAcces"):GetAsync("test")
	end)
	state = ok
	if not ok then
		print("[Jeu] Test dans Studio sans accès aux API : progression non sauvegardée. Pour la tester, coche « Enable Studio Access to API Services » dans Paramètres du jeu > Sécurité.")
	end
	return ok
end

return DataAccess
