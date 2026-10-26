-- Sons et musique (StarterPlayerScripts.Client.Sons)
-- Effets sonores des recompenses et musique de fond. Tous les sons viennent du Creator Store
-- de Roblox (gratuits et publics).
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local State = require(script.Parent.State)

local Sons = {}

local EFFECTS = {
	Piece = { id = 135483737426662, volume = 0.35 },
	Niveau = { id = 112485797063762, volume = 0.5 },
	Recompense = { id = 134821092416328, volume = 0.5 },
	Rare = { id = 73774648241042, volume = 0.55 },
	Joie = { id = 105193542038988, volume = 0.45 },
	-- Petit pop du bouton TAPER, plus aigu quand on enchaine
	Tap = { id = 15675055424, volume = 0.5 },
}

local MUSIC = { id = 109013970903424, volume = 0.22 }

local sounds = {}
local music = nil
Sons.musicOn = true

local function make(name: string, entry, looped: boolean?)
	local sound = Instance.new("Sound")
	sound.Name = name
	sound.SoundId = "rbxassetid://" .. entry.id
	sound.Volume = entry.volume
	sound.Looped = looped or false
	sound.Parent = SoundService
	return sound
end

function Sons.play(name: string, pitch: number?)
	local sound = sounds[name]
	if sound then
		sound.PlaybackSpeed = pitch or (0.95 + math.random() * 0.1)
		SoundService:PlayLocalSound(sound)
	end
end

-- Pop du tap : la note monte a chaque coup rapproche (serie), puis redescend
local combo, lastTap = 0, 0
function Sons.tap()
	local now = os.clock()
	combo = if now - lastTap < 0.45 then math.min(combo + 1, 10) else 0
	lastTap = now
	Sons.play("Tap", 1 + combo * 0.035 + math.random() * 0.02)
end

function Sons.setMusic(on: boolean)
	Sons.musicOn = on
	if not music then
		return
	end
	if on then
		music.Volume = 0
		music:Play()
		TweenService:Create(music, TweenInfo.new(1.5), { Volume = MUSIC.volume }):Play()
	else
		music:Stop()
	end
end

function Sons.start()
	for name, entry in EFFECTS do
		sounds[name] = make(name, entry)
	end
	music = make("Musique", MUSIC, true)
	Sons.setMusic(true)

	State.remotes:WaitForChild("Effect").OnClientEvent:Connect(function(kind)
		if kind == "level" or kind == "quest" then
			Sons.play("Niveau")
		elseif kind == "reward" then
			Sons.play("Recompense")
		end
		-- Coffres : sons joues par la roulette (Reveal)
	end)
end

return Sons
