-- Fenetres : ameliorations, coffres, cadeaux, boutique (StarterPlayerScripts.Client.Windows)
-- Une seule fenetre ouverte a la fois, avec un voile sombre et un flou derriere. Pour en
-- ajouter une : une fonction build..., enregistree dans openers, puis un bouton dans
-- Client.HUD (MENU) ; ou Windows.register depuis un autre module.
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Chests = require(ReplicatedStorage.Shared.Chests)
local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local Progression = require(ReplicatedStorage.Shared.Progression)
local Shop = require(ReplicatedStorage.Shared.Shop)
local State = require(script.Parent.State)
local UI = require(script.Parent.UI)

local Theme = UI.Theme

local Windows = {}

local openers = {}
local veil, blur

local function clear(frame: Instance)
	for _, child in frame:GetChildren() do
		if not child:IsA("UIListLayout") and not child:IsA("UIGridLayout") and not child:IsA("UIPadding") then
			child:Destroy()
		end
	end
end

local function anyOpen(): boolean
	for _, opener in openers do
		if opener.window.Visible then
			return true
		end
	end
	return false
end

-- Voile sombre et flou derriere les fenetres
local function refreshVeil()
	local open = anyOpen()
	if veil then
		veil.Visible = open
	end
	if blur then
		TweenService:Create(blur, TweenInfo.new(0.2), { Size = if open then 10 else 0 }):Play()
	end
end

local function show(name: string, data)
	for other, opener in openers do
		if other ~= name then
			opener.setOpen(false)
		end
	end
	local opener = openers[name]
	if opener then
		opener.setOpen(true)
		opener.refresh(data or {})
	end
	refreshVeil()
end

local function hide()
	for _, opener in openers do
		opener.setOpen(false)
	end
	refreshVeil()
end

local function isOpen(name: string): boolean
	local opener = openers[name]
	return opener ~= nil and opener.window.Visible
end

local function scroller(parent: Instance, props)
	props.BackgroundTransparency = 1
	props.BorderSizePixel = 0
	props.CanvasSize = UDim2.new()
	props.AutomaticCanvasSize = Enum.AutomaticSize.Y
	props.ScrollBarThickness = 8
	props.ScrollBarImageColor3 = Theme.Gold
	props.ScrollingDirection = Enum.ScrollingDirection.Y
	props.Parent = parent
	local frame = UI.create("ScrollingFrame", props)
	UI.create("UIPadding", { PaddingTop = UDim.new(0, 6), PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 14), PaddingBottom = UDim.new(0, 10), Parent = frame })
	return frame
end

-- Limite une mise a jour a une fois par seconde (le profil change a chaque tap)
local function throttled(fn)
	local pending, last = false, 0
	return function()
		if pending then
			return
		end
		local wait = math.max(0, last + 1 - os.clock())
		pending = true
		task.delay(wait, function()
			pending = false
			last = os.clock()
			fn()
		end)
	end
end

-- Titre de section avec ruban
local function section(parent: Instance, order: number, text: string, color: Color3)
	local ribbon = UI.create("Frame", { LayoutOrder = order, Size = UDim2.new(1, -6, 0, 40), BackgroundTransparency = 1, Parent = parent })
	local tag = UI.create("Frame", { Size = UDim2.fromOffset(0, 36), AutomaticSize = Enum.AutomaticSize.X, BackgroundColor3 = color, Parent = ribbon }, {
		UI.corner(10),
		UI.stroke(Theme.Outline, 3),
		UI.gradient(0.35),
		UI.create("UIPadding", { PaddingLeft = UDim.new(0, 16), PaddingRight = UDim.new(0, 16) }),
	})
	UI.text({ Text = text, Font = Theme.Fonts.Title, TextSize = 20, Size = UDim2.fromScale(0, 1), AutomaticSize = Enum.AutomaticSize.X, Outline = 2.5, Parent = tag })
	return ribbon
end

-- Ameliorations : une ligne par amelioration, achat a l'unite ou au maximum
local function buildUpgrades(gui: ScreenGui)
	local window, content, setOpen = UI.window(gui, "Améliorations", Vector2.new(820, 580), "Ameliorer", Color3.fromRGB(80, 170, 255))
	local list = scroller(content, { Size = UDim2.fromScale(1, 1) })
	UI.create("UIListLayout", { Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder, Parent = list })

	local function refresh()
		local profile = State.profile
		if not profile then
			return
		end
		clear(list)
		for index, upgrade in Config.Upgrades do
			local level = profile.upgrades[upgrade.id] or 0
			local cost = Progression.upgradeCost(upgrade, level)
			local affordable = cost ~= nil and profile.coins >= cost
			local row = UI.card({ LayoutOrder = index, Size = UDim2.new(1, -6, 0, 92), Parent = list }, { UI.padding(10) })
			UI.icon(upgrade.icon, { Position = UDim2.fromOffset(0, -4), Size = UDim2.fromOffset(80, 80), Parent = row })
			UI.text({ Text = upgrade.name, TextSize = 22, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromOffset(92, 0), Size = UDim2.new(1, -370, 0, 28), Outline = 2.5, Parent = row })
			UI.text({ Text = upgrade.description, Font = Theme.Fonts.Body, TextSize = 16, TextColor3 = Theme.Muted, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, Position = UDim2.fromOffset(92, 30), Size = UDim2.new(1, -370, 0, 40), Parent = row })
			-- Niveau
			local badge = UI.create("Frame", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -250, 0.5, 0), Size = UDim2.fromOffset(84, 40), BackgroundColor3 = Theme.Accent, Parent = row }, { UI.corner(10), UI.stroke(Theme.Outline, 2.5), UI.gradient(0.35) })
			UI.text({ Text = if upgrade.max then ("%d / %d"):format(level, upgrade.max) else ("Niv. %d"):format(level), Font = Theme.Fonts.Number, TextSize = 17, Size = UDim2.fromScale(1, 1), Outline = 2, Parent = badge })
			local buy = UI.button({
				Text = if cost then Format.short(cost) else "MAX",
				Icon = if cost then Config.Currency.icon else nil,
				TextSize = 20,
				Variant = if affordable then "success" else "ghost",
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -86, 0.5, 0),
				Size = UDim2.fromOffset(150, 52),
				Parent = row,
			}, function()
				State.send("BuyUpgrade", upgrade.id, false)
			end)
			UI.setEnabled(buy, affordable)
			local max = UI.button({ Text = "Max", TextSize = 18, Variant = if affordable then "gold" else "ghost", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.fromOffset(76, 52), Parent = row }, function()
				State.send("BuyUpgrade", upgrade.id, true)
			end)
			UI.setEnabled(max, affordable)
		end
	end
	State.observe(throttled(function()
		if window.Visible then
			refresh()
		end
	end))
	openers.Upgrades = { window = window, setOpen = setOpen, refresh = refresh }
end

-- Coffres : prix, chances et coffres gagnes en reserve
local function buildChests(gui: ScreenGui)
	local window, content, setOpen = UI.window(gui, "Coffres", Vector2.new(940, 560), "Coffre", Color3.fromRGB(150, 95, 255))
	local list = scroller(content, { Size = UDim2.fromScale(1, 1) })
	UI.create("UIGridLayout", { CellSize = UDim2.fromOffset(206, 420), CellPadding = UDim2.fromOffset(12, 12), SortOrder = Enum.SortOrder.LayoutOrder, Parent = list })

	local function refresh()
		local profile = State.profile
		if not profile then
			return
		end
		clear(list)
		local now = State.serverTime()
		for index, chest in Chests.List do
			local rarity = Config.ChestRarities[chest.index]
			local owned = profile.chests[chest.id] or 0
			local cost, currency = Chests.cost(profile, chest, now)
			local wallet = if currency == "gems" then profile.gems else profile.coins
			local card = UI.card({ LayoutOrder = index, BackgroundColor3 = rarity.color:Lerp(Theme.Background, 0.45), Parent = list }, { UI.padding(10) })
			local icon = UI.icon("Coffre", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0), Size = UDim2.fromOffset(96, 96), Parent = card })
			icon.ImageColor3 = rarity.color:Lerp(Color3.new(1, 1, 1), 0.45)
			UI.text({ Text = "Coffre " .. rarity.label:lower(), TextSize = 20, TextWrapped = true, Position = UDim2.fromOffset(0, 98), Size = UDim2.new(1, 0, 0, 26), Outline = 2.5, Parent = card })
			-- Chances (avec la chance du joueur)
			local odds = Chests.odds(chest.contents, profile.stats.luck)
			local lines = UI.create("Frame", { Position = UDim2.fromOffset(0, 130), Size = UDim2.new(1, 0, 0, 170), BackgroundTransparency = 1, Parent = card }, {
				UI.create("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }),
			})
			for entryIndex, entry in chest.contents do
				local line = UI.create("Frame", { LayoutOrder = entryIndex, Size = UDim2.new(1, 0, 0, 38), BackgroundColor3 = Theme.Background, BackgroundTransparency = 0.35, Parent = lines }, { UI.corner(8) })
				local entryIcon = if entry.kind == "coins" then Config.Currency.icon elseif entry.kind == "gems" then Config.Premium.icon else (Progression.Boosts[entry.boost] or { icon = "Boost" }).icon
				UI.icon(entryIcon, { Position = UDim2.fromOffset(2, 3), Size = UDim2.fromOffset(32, 32), Parent = line })
				UI.text({ Text = entry.label, Font = Theme.Fonts.Body, TextSize = 13, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromOffset(38, 0), Size = UDim2.new(1, -92, 1, 0), Parent = line })
				UI.text({ Text = Format.percent(odds[entryIndex]), Font = Theme.Fonts.Number, TextSize = 14, TextColor3 = if entry.rare then Theme.Gold else Theme.Text, TextXAlignment = Enum.TextXAlignment.Right, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -6, 0, 0), Size = UDim2.new(0, 52, 1, 0), Outline = 1.5, Parent = line })
			end
			local free = owned > 0
			local affordable = free or wallet >= cost
			local button = UI.button({
				Text = if free then ("Ouvrir (%d)"):format(owned) else Format.short(cost),
				Icon = if free then "Valider" elseif currency == "gems" then Config.Premium.icon else Config.Currency.icon,
				TextSize = 20,
				Variant = if free then "gold" elseif affordable then "success" else "ghost",
				AnchorPoint = Vector2.new(0.5, 1),
				Position = UDim2.new(0.5, 0, 1, 0),
				Size = UDim2.new(1, 0, 0, 50),
				Parent = card,
			}, function()
				State.send("OpenChest", chest.id)
			end)
			UI.setEnabled(button, affordable)
		end
	end
	State.observe(throttled(function()
		if window.Visible then
			refresh()
		end
	end))
	openers.Chests = { window = window, setOpen = setOpen, refresh = refresh }
end

-- Boutique : passes et produits en cartes
local function buildShop(gui: ScreenGui)
	local window, content, setOpen = UI.window(gui, "Boutique", Vector2.new(940, 600), "Boutique", Color3.fromRGB(255, 180, 40))
	local list = scroller(content, { Size = UDim2.fromScale(1, 1) })
	UI.create("UIListLayout", { Padding = UDim.new(0, 12), SortOrder = Enum.SortOrder.LayoutOrder, Parent = list })

	local function grid(order: number)
		return UI.create("Frame", { LayoutOrder = order, Size = UDim2.new(1, -6, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, Parent = list }, {
			UI.create("UIGridLayout", { CellSize = UDim2.fromOffset(206, 262), CellPadding = UDim2.fromOffset(12, 12), SortOrder = Enum.SortOrder.LayoutOrder }),
		})
	end

	local function card(parent: Instance, order: number, item, kind: string, focus: string?)
		local profile = State.profile
		local owned = kind == "pass" and profile and profile.passes[item.id]
		local color = if kind == "pass" then Color3.fromRGB(255, 190, 50) else Color3.fromRGB(120, 90, 230)
		local frame = UI.card({ LayoutOrder = order, BackgroundColor3 = color:Lerp(Theme.Background, 0.45), Parent = parent }, { UI.padding(10) })
		if focus == item.id then
			frame:FindFirstChildOfClass("UIStroke").Color = Color3.new(1, 1, 1)
			frame:FindFirstChildOfClass("UIStroke").Thickness = 4
		end
		UI.icon(item.icon or "Etoile", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0), Size = UDim2.fromOffset(86, 86), Parent = frame })
		UI.text({ Text = item.name, TextSize = 19, TextWrapped = true, Position = UDim2.fromOffset(0, 88), Size = UDim2.new(1, 0, 0, 24), Outline = 2.5, Parent = frame })
		local description = item.description
		-- Coffre payant : chances affichees sur la carte
		if item.grant and item.grant.chest and Chests.ById[item.grant.chest] then
			local contents = Chests.ById[item.grant.chest].contents
			local odds = Chests.odds(contents, profile and profile.stats.luck or 0)
			local parts = {}
			for index, entry in contents do
				table.insert(parts, ("%s %s"):format(entry.label, Format.percent(odds[index])))
			end
			description = "Chances : " .. table.concat(parts, ", ")
		end
		local desc = UI.text({ Text = description, Font = Theme.Fonts.Body, TextSize = 14, TextColor3 = Theme.Muted, TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top, Position = UDim2.fromOffset(0, 114), Size = UDim2.new(1, 0, 0, 84), Parent = frame })
		desc.TextScaled = #description > 120
		if desc.TextScaled then
			UI.create("UITextSizeConstraint", { MaxTextSize = 14, MinTextSize = 9, Parent = desc })
		end
		local button = UI.button({
			Text = if owned then "Possédé" else ("R$ %d"):format(item.price),
			Icon = if owned then "Valider" else nil,
			TextSize = 22,
			Variant = if owned then "ghost" else "success",
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, 0),
			Size = UDim2.new(1, 0, 0, 46),
			Parent = frame,
		}, function()
			if not owned then
				State.send("Buy", kind, item.id)
			end
		end)
		UI.setEnabled(button, not owned)
		if kind == "pass" and not owned then
			local ribbon = UI.create("Frame", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 6, 0, -6), Size = UDim2.fromOffset(0, 24), AutomaticSize = Enum.AutomaticSize.X, BackgroundColor3 = Theme.Red, ZIndex = 3, Parent = frame }, {
				UI.corner(8),
				UI.stroke(Theme.Outline, 2),
				UI.create("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8) }),
			})
			UI.text({ Text = "À VIE", Font = Theme.Fonts.Number, TextSize = 14, Size = UDim2.fromScale(0, 1), AutomaticSize = Enum.AutomaticSize.X, ZIndex = 4, Outline = 2, Parent = ribbon })
		end
	end

	local lastFocus
	local function refresh(data)
		if data and data.focus then
			lastFocus = data.focus
		end
		clear(list)
		section(list, 1, "PASSES : POUR TOUJOURS", Color3.fromRGB(235, 160, 30))
		local passes = grid(2)
		for index, pass in Shop.Passes do
			card(passes, index, pass, "pass", lastFocus)
		end
		section(list, 3, "BOOSTS ET PACKS", Color3.fromRGB(130, 90, 235))
		local products = grid(4)
		local restricted = Shop.paidRandomBlocked(Players.LocalPlayer)
		for index, product in Shop.Products do
			if not (restricted and Shop.isPaidRandom(product)) then
				card(products, index, product, "product", lastFocus)
			end
		end
		UI.text({ LayoutOrder = 5, Text = "Les chances des coffres sont toujours affichées avant l'achat.", Font = Theme.Fonts.Body, TextSize = 14, TextColor3 = Theme.Muted, Size = UDim2.new(1, 0, 0, 24), Parent = list })
		if restricted then
			UI.text({ LayoutOrder = 6, Text = Shop.RestrictedMessage, Font = Theme.Fonts.Body, TextSize = 14, TextColor3 = Theme.Muted, TextWrapped = true, Size = UDim2.new(1, 0, 0, 24), Parent = list })
		end
	end
	State.observe(throttled(function()
		if window.Visible then
			refresh()
		end
	end))
	Players.LocalPlayer:GetAttributeChangedSignal(Shop.RestrictedAttribute):Connect(function()
		if window.Visible then
			refresh()
		end
	end)
	openers.Shop = { window = window, setOpen = setOpen, refresh = refresh }
end

-- Cadeaux : recompense quotidienne et cadeaux de temps de jeu
local function buildGifts(gui: ScreenGui)
	local window, content, setOpen = UI.window(gui, "Cadeaux", Vector2.new(820, 540), "Cadeau", Color3.fromRGB(255, 95, 165))

	local function refresh()
		local profile = State.profile
		if not profile then
			return
		end
		clear(content)
		section(content, 0, "RÉCOMPENSE QUOTIDIENNE", Color3.fromRGB(235, 160, 30))
		local today = math.floor(State.serverTime() / 86400)
		local available = profile.daily.day < today
		local streak = if profile.daily.day == today - 1 or profile.daily.day == today then profile.daily.streak else 0
		local nextDay = if available then streak + 1 else streak
		local row = UI.create("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 48), Size = UDim2.new(1, 0, 0, 120), Parent = content }, {
			UI.create("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8) }),
		})
		for index, gift in Progression.Daily do
			local dayNumber = (math.max(nextDay, 1) - 1) % #Progression.Daily + 1
			local current = index == dayNumber
			local done = index < dayNumber or (not available and index == dayNumber)
			local cell = UI.card({ Size = UDim2.fromOffset(102, 118), BackgroundColor3 = if current and available then Color3.fromRGB(255, 180, 50) elseif done then Color3.fromRGB(60, 160, 90) else Theme.Surface, Parent = row }, { UI.padding(6) })
			if current and available then
				cell:FindFirstChildOfClass("UIStroke").Color = Color3.new(1, 1, 1)
			end
			UI.text({ Text = ("Jour %d"):format(index), Font = Theme.Fonts.Number, TextSize = 16, Size = UDim2.new(1, 0, 0, 18), Outline = 2, Parent = cell })
			UI.icon(if done then "Valider" else "Cadeau", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 20), Size = UDim2.fromOffset(46, 46), Parent = cell })
			UI.text({ Text = gift.label, Font = Theme.Fonts.Body, TextSize = 13, TextWrapped = true, Position = UDim2.fromOffset(0, 66), Size = UDim2.new(1, 0, 1, -66), Parent = cell })
		end
		local claim = UI.button({ Text = if available then "Récupérer la récompense du jour" else "Reviens demain !", Icon = "Cadeau", TextSize = 19, Variant = if available then "success" else "ghost", Position = UDim2.fromOffset(0, 178), Size = UDim2.fromOffset(400, 50), Parent = content }, function()
			State.send("ClaimDaily")
		end)
		UI.setEnabled(claim, available)

		local header = section(content, 0, "CADEAUX DE TEMPS DE JEU", Color3.fromRGB(255, 95, 165))
		header.Position = UDim2.fromOffset(0, 246)
		local gifts = UI.create("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 294), Size = UDim2.new(1, 0, 0, 150), Parent = content }, {
			UI.create("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 10) }),
		})
		local minutes = profile.sessionMinutes + (os.clock() - State.receivedAt) / 60
		for index, needed in Config.PlaytimeGifts do
			local gift = Progression.PlaytimeGifts[index]
			local claimed = profile.gifts[tostring(index)]
			local ready = not claimed and minutes >= needed
			local cell = UI.card({ Size = UDim2.fromOffset(142, 150), BackgroundColor3 = if ready then Color3.fromRGB(255, 120, 190) elseif claimed then Color3.fromRGB(60, 160, 90) else Theme.Surface, Parent = gifts }, { UI.padding(8) })
			UI.icon(if claimed then "Valider" elseif ready then "Cadeau" else "Horloge", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0), Size = UDim2.fromOffset(44, 44), Parent = cell })
			UI.text({ Text = gift.label, TextSize = 15, TextWrapped = true, Position = UDim2.fromOffset(0, 44), Size = UDim2.new(1, 0, 0, 34), Outline = 2, Parent = cell })
			UI.text({ Text = if claimed then "Récupéré" elseif ready then "Prêt !" else Format.duration((needed - minutes) * 60), Font = Theme.Fonts.Number, TextSize = 15, TextColor3 = if ready then Color3.fromRGB(200, 255, 210) else Theme.Muted, Position = UDim2.fromOffset(0, 78), Size = UDim2.new(1, 0, 0, 18), Outline = 2, Parent = cell })
			local button = UI.button({ Text = "Ouvrir", TextSize = 16, Variant = "success", AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 0, 1, 0), Size = UDim2.new(1, 0, 0, 36), Parent = cell }, function()
				State.send("ClaimGift", index)
			end)
			UI.setEnabled(button, ready)
		end
	end
	-- Les minuteries avancent pendant que la fenetre est ouverte
	task.spawn(function()
		while true do
			task.wait(1)
			if window.Visible then
				refresh()
			end
		end
	end)
	openers.Gifts = { window = window, setOpen = setOpen, refresh = refresh }
end

-- Fenetre construite par un autre module : meme voile, meme fermeture
function Windows.register(name: string, window: GuiObject, setOpen, refresh)
	openers[name] = { window = window, setOpen = setOpen, refresh = refresh }
end

Windows.scroller = scroller
Windows.section = section
Windows.clear = clear
Windows.throttled = throttled

function Windows.open(name: string, data)
	if isOpen(name) and not data then
		hide()
	else
		show(name, data)
	end
end

function Windows.start(gui: ScreenGui)
	veil = UI.create("TextButton", {
		Name = "Voile",
		Text = "",
		AutoButtonColor = false,
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(10, 5, 25),
		BackgroundTransparency = 0.5,
		Visible = false,
		ZIndex = 9,
		Parent = gui,
	})
	veil.Activated:Connect(hide)
	blur = Lighting:FindFirstChild("FlouFenetres") or Instance.new("BlurEffect")
	blur.Name = "FlouFenetres"
	blur.Size = 0
	blur.Parent = Lighting
	UI.onWindowClosed = refreshVeil

	buildUpgrades(gui)
	buildChests(gui)
	buildShop(gui)
	buildGifts(gui)

	State.remotes:WaitForChild("OpenWindow").OnClientEvent:Connect(function(name, data)
		show(name, data)
	end)
	UserInputService.InputBegan:Connect(function(input, processed)
		if not processed and input.KeyCode == Enum.KeyCode.Escape then
			hide()
		end
	end)
end

return Windows
