-- Copie locale du profil envoye par le serveur (StarterPlayerScripts.Client.State)
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local State = {
	profile = nil,
	remotes = ReplicatedStorage:WaitForChild("Remotes"),
	-- Ecart entre l'horloge du serveur et celle du client (os.time)
	clockOffset = 0,
	-- os.clock() a la reception du dernier profil (compteurs qui avancent entre deux envois)
	receivedAt = os.clock(),
}

local changed = Instance.new("BindableEvent")
State.Changed = changed.Event

State.remotes:WaitForChild("Profile").OnClientEvent:Connect(function(profile)
	State.profile = profile
	State.clockOffset = profile.serverTime - os.time()
	State.receivedAt = os.clock()
	changed:Fire(profile)
end)

-- Appelle fn tout de suite si le profil est deja connu, puis a chaque changement
function State.observe(fn)
	if State.profile then
		task.spawn(fn, State.profile)
	end
	return State.Changed:Connect(fn)
end

function State.send(action: string, ...)
	State.remotes.Action:FireServer(action, ...)
end

function State.serverTime(): number
	return os.time() + State.clockOffset
end

return State
