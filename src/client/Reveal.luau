-- Ouverture des coffres en roulette (StarterPlayerScripts.Client.Reveal)
-- Le coffre tremble et s'ouvre, puis une bande de cartes defile, ralentit et s'arrete sur le
-- gain (les chances sont affichees dessous). Un clic accelere jusqu'a la fin ; une nouvelle
-- ouverture interrompt celle en cours.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Chests = require(ReplicatedStorage.Shared.Chests)
local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local Progression = require(ReplicatedStorage.Shared.Progression)
local Sons = require(script.Parent.Sons)
local State = require(script.Parent.State)
local UI = require(script.Parent.UI)

local Theme = UI.Theme

local Reveal = {}

local CARD_W, CARD_H, GAP = 150, 190, 12
local STRIP_COUNT, WIN_INDEX = 44, 38
local WINDOW_W = 860

-- Couleur d'une carte selon sa chance : plus elle est rare, plus elle brille
local function chanceColor(chance: number): Color3
	if chance <= 15 then
		return Theme.Gold
	elseif chance <= 25 then
		return Color3.fromRGB(170, 95, 200)
	elseif chance <= 35 then
		return Theme.Blue
	end
	return Color3.fromRGB(150, 150, 170)
end

function Reveal.entryIcon(entry): string
	if entry.kind == "coins" then
		return Config.Currency.icon
	elseif entry.kind == "gems" then
		return Config.Premium.icon
	elseif entry.kind == "boost" then
		local boost = Progression.Boosts[entry.boost]
		return if boost then boost.icon else "Boost"
	end
	return "Butin"
end

-- Carte de recompense teintee de sa rarete, avec un voile pour les cartes non gagnees
local function rewardCard(parent: Instance, color: Color3, zindex: number)
	local card = UI.card({ Size = UDim2.fromOffset(CARD_W, CARD_H), BackgroundColor3 = color:Lerp(Theme.Background, 0.4), ZIndex = zindex, Parent = parent })
	local veil = UI.create("Frame", { Name = "Voile", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = zindex + 3, Parent = card }, { UI.corner(14) })
	return card, veil
end

local function buildOverlay(gui: ScreenGui)
	local overlay = UI.create("TextButton", {
		Name = "Revelation",
		Text = "",
		AutoButtonColor = false,
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(10, 6, 4),
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = 40,
		Parent = gui,
	})
	local center = UI.create("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(WINDOW_W + 40, 640), BackgroundTransparency = 1, ZIndex = 41, Parent = overlay })
	UI.autoScale(center)
	local rays = UI.icon("Rayons", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.3), Size = UDim2.fromOffset(560, 560), ImageTransparency = 0.5, ZIndex = 41, Parent = center })
	local title = UI.text({ Text = "", TextSize = 40, TextColor3 = Color3.new(1, 1, 1), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0), Size = UDim2.new(1, 0, 0, 50), ZIndex = 45, Outline = 3, Parent = center })
	UI.colorGradient(Color3.fromRGB(255, 240, 190), Color3.fromRGB(215, 160, 70)).Parent = title
	local chest = UI.icon("Coffre", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.3), Size = UDim2.fromOffset(200, 200), ZIndex = 43, Parent = center })
	local flash = UI.create("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(255, 240, 200), BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 60, Parent = overlay })

	-- Fenetre de la bande de cartes, avec le repere central (trait dore)
	local frame = UI.panel({ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 250), Size = UDim2.fromOffset(WINDOW_W, CARD_H + 36), ZIndex = 42, Visible = false, Parent = center })
	local clip = UI.create("Frame", { Position = UDim2.fromOffset(8, 18), Size = UDim2.new(1, -16, 0, CARD_H), BackgroundTransparency = 1, ClipsDescendants = true, ZIndex = 42, Parent = frame })
	local strip = UI.create("Frame", { Size = UDim2.fromOffset(0, CARD_H), BackgroundTransparency = 1, ZIndex = 43, Parent = clip })
	UI.create("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 6), Size = UDim2.new(0, 5, 1, -12), BackgroundColor3 = Theme.Gold, BorderSizePixel = 0, ZIndex = 47, Parent = frame }, { UI.corner(), UI.stroke(Theme.Outline, 2) })

	local odds = UI.text({ Text = "", RichText = true, Font = Theme.Fonts.Body, TextSize = 16, TextColor3 = Theme.Muted, TextWrapped = true, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 250 + CARD_H + 44), Size = UDim2.fromOffset(WINDOW_W, 40), ZIndex = 45, Parent = center })
	UI.textOutline(odds, 1.5)
	local result = UI.text({ Text = "", RichText = true, TextSize = 28, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 250 + CARD_H + 90), Size = UDim2.fromOffset(WINDOW_W, 36), ZIndex = 45, Outline = 2.5, Parent = center })
	local collect = UI.button({ Text = "Récupérer", Icon = "Valider", TextSize = 22, Variant = "success", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 250 + CARD_H + 136), Size = UDim2.fromOffset(240, 52), ZIndex = 46, Visible = false, Parent = center })

	task.spawn(function()
		while true do
			local dt = task.wait()
			if overlay.Visible and rays.Visible then
				rays.Rotation = (rays.Rotation + dt * 20) % 360
			end
		end
	end)

	return {
		overlay = overlay,
		rays = rays,
		title = title,
		chest = chest,
		flash = flash,
		frame = frame,
		strip = strip,
		odds = odds,
		result = result,
		collect = collect,
	}
end

local view
local token = 0
local skipRequested = false
local chestsOpened = 0

local function current(mine: number): boolean
	return token == mine
end

-- Attend `duration` secondes, ou moins si le joueur clique pour passer
local function pause(mine: number, duration: number): boolean
	local finish = os.clock() + duration
	while os.clock() < finish do
		if skipRequested or not current(mine) then
			break
		end
		task.wait()
	end
	return current(mine)
end

local function flash(strength: number?)
	view.flash.BackgroundTransparency = 1 - (strength or 0.7)
	TweenService:Create(view.flash, TweenInfo.new(0.45, Enum.EasingStyle.Quad), { BackgroundTransparency = 1 }):Play()
end

local function hide()
	token += 1
	local overlay = view.overlay
	TweenService:Create(overlay, TweenInfo.new(0.18), { BackgroundTransparency = 1 }):Play()
	task.delay(0.18, function()
		if overlay.BackgroundTransparency >= 0.99 then
			overlay.Visible = false
		end
	end)
end

local function begin(): number
	token += 1
	skipRequested = false
	local overlay = view.overlay
	overlay.Visible = true
	TweenService:Create(overlay, TweenInfo.new(0.2), { BackgroundTransparency = 0.35 }):Play()
	for _, child in view.strip:GetChildren() do
		child:Destroy()
	end
	view.frame.Visible = false
	view.collect.Visible = false
	view.odds.Text = ""
	view.result.Text = ""
	view.chest.Visible = false
	view.chest.Rotation = 0
	view.rays.Visible = false
	return token
end

-- Ouverture d'un coffre : data = { id, index, luck, reward }
local function playChest(data)
	local mine = begin()
	local chest = Chests.ById[data.id]
	local rarity = chest and Config.ChestRarities[chest.index]
	if not chest or not rarity then
		hide()
		return
	end
	local contents = chest.contents
	local odds = Chests.odds(contents, data.luck)
	chestsOpened += 1
	-- La premiere ouverture prend son temps, les suivantes vont plus vite
	local long = chestsOpened == 1
	local winner = contents[data.index or 1] or contents[1]
	local winnerChance = odds[data.index or 1] or winner.chance

	view.title.Text = "COFFRE " .. UI.upper(rarity.label)
	view.chest.Visible = true
	view.chest.ImageColor3 = rarity.color:Lerp(Color3.new(1, 1, 1), 0.45)
	view.rays.Visible = true
	view.rays.ImageColor3 = rarity.color

	-- Le coffre tremble de plus en plus, puis s'ouvre dans un eclair
	for step = 1, if long then 7 else 4 do
		view.chest.Rotation = (if step % 2 == 0 then 1 else -1) * (3 + step * 1.6)
		Sons.play("Piece", 0.8 + step * 0.05)
		if not pause(mine, 0.09) then
			break
		end
	end
	if not current(mine) then
		return
	end
	view.chest.Rotation = 0
	view.chest.Visible = false
	flash(0.8)
	Sons.play("Niveau")

	-- Bande de cartes : tirage aleatoire selon les chances, la carte gagnante a sa place
	local cards = {}
	local rng = Random.new()
	for index = 1, STRIP_COUNT do
		local entry, entryIndex = winner, data.index or 1
		if index ~= WIN_INDEX then
			entry, entryIndex = Chests.roll(contents, data.luck, rng)
		end
		local chance = odds[entryIndex] or entry.chance
		local card, veil = rewardCard(view.strip, chanceColor(chance), 44)
		card.Position = UDim2.fromOffset((index - 1) * (CARD_W + GAP), 0)
		UI.icon(Reveal.entryIcon(entry), { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 16), Size = UDim2.fromOffset(92, 92), ZIndex = 45, Parent = card })
		UI.text({ Text = entry.label, TextSize = 16, TextWrapped = true, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 114), Size = UDim2.new(1, -14, 0, 42), ZIndex = 45, Outline = 2, Parent = card })
		UI.text({ Text = Format.percent(chance), Font = Theme.Fonts.Body, TextSize = 13, TextColor3 = Theme.Muted, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -10), Size = UDim2.new(1, 0, 0, 16), ZIndex = 45, Parent = card })
		cards[index] = { card = card, veil = veil }
	end
	local parts = {}
	for index, entry in contents do
		table.insert(parts, ("%s <b>%s</b>"):format(entry.label, Format.percent(odds[index])))
	end
	view.odds.Text = "Chances : " .. table.concat(parts, "  ·  ")
	view.frame.Visible = true

	-- Defilement : vite au debut, ralentit longuement jusqu'a la carte gagnante (arret
	-- legerement decale du centre, comme une vraie roue)
	local half = (WINDOW_W - 16) / 2
	local function offsetFor(index: number, jitter: number): number
		return half - CARD_W / 2 - (index - 1) * (CARD_W + GAP) + jitter
	end
	local startX = offsetFor(3, 0)
	local finalX = offsetFor(WIN_INDEX, rng:NextNumber(-CARD_W * 0.32, CARD_W * 0.32))
	view.strip.Position = UDim2.fromOffset(startX, 0)
	local duration = if long then 4.6 else 2.6
	local value = Instance.new("NumberValue")
	value.Value = 0
	local tween = TweenService:Create(value, TweenInfo.new(duration, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), { Value = 1 })
	tween:Play()
	local lastIndex = 0
	while current(mine) and value.Value < 1 do
		if skipRequested then
			tween:Cancel()
			value.Value = 1
		end
		local x = startX + (finalX - startX) * value.Value
		view.strip.Position = UDim2.fromOffset(x, 0)
		-- Un petit clic a chaque carte qui passe sous le repere
		local under = math.floor((half - x) / (CARD_W + GAP)) + 1
		if under ~= lastIndex then
			lastIndex = under
			Sons.play("Tap", 1.25 + math.random() * 0.1)
		end
		RunService.RenderStepped:Wait()
	end
	value:Destroy()
	if not current(mine) then
		return
	end
	view.strip.Position = UDim2.fromOffset(finalX, 0)

	-- Revelation : les autres cartes s'assombrissent, la gagnante s'illumine
	for index, entry in cards do
		if index ~= WIN_INDEX then
			TweenService:Create(entry.veil, TweenInfo.new(0.3), { BackgroundTransparency = 0.45 }):Play()
		end
	end
	local won = cards[WIN_INDEX].card
	local stroke = won:FindFirstChildOfClass("UIStroke") :: UIStroke
	stroke.Color = Color3.new(1, 1, 1)
	stroke.Thickness = 4
	flash(0.35)
	Sons.play(if winnerChance <= 15 then "Rare" else "Recompense")
	view.result.Text = ('Tu obtiens : <font color="#FFE296">%s</font>'):format(data.reward or winner.label)
	view.collect.Visible = true
end

function Reveal.start(gui: ScreenGui)
	view = buildOverlay(gui)
	view.collect.Activated:Connect(hide)
	-- Un clic pendant l'animation la fait aller a la fin
	view.overlay.Activated:Connect(function()
		if view.collect.Visible then
			hide()
		else
			skipRequested = true
		end
	end)
	State.remotes:WaitForChild("Effect").OnClientEvent:Connect(function(kind, data)
		if kind == "chest" then
			task.spawn(playChest, data)
		end
	end)
end

return Reveal
