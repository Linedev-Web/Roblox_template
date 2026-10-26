-- Interface permanente (StarterPlayerScripts.Client.HUD)
-- Haut gauche : monnaie premium et gains. Haut centre : monnaie principale, niveau et bonus.
-- Gauche (ordinateur) ou haut droite (tactile) : menus. Bas : TAPER, auto-tap et musique.
-- Droite : objectif et notifications. Centre : annonces.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Chests = require(ReplicatedStorage.Shared.Chests)
local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local Icons = require(ReplicatedStorage.Shared.Icons)
local Progression = require(ReplicatedStorage.Shared.Progression)
local Quests = require(ReplicatedStorage.Shared.Quests)
local Shop = require(ReplicatedStorage.Shared.Shop)
local Effects = require(script.Parent.Effects)
local Sons = require(script.Parent.Sons)
local State = require(script.Parent.State)
local UI = require(script.Parent.UI)

local Theme = UI.Theme
local player = Players.LocalPlayer

local HUD = {}

-- Boutons du menu, dans l'ordre. window : nom de la fenetre (Client.Windows) ; key : raccourci
-- clavier (ordinateur) ; badge(profile) : pastille rouge quand il y a quelque chose a faire.
local MENU = {
	{ window = "Upgrades", label = "Améliorer", icon = "Ameliorer", key = "U", color = Color3.fromRGB(80, 170, 255) },
	{ window = "Chests", label = "Coffres", icon = "Coffre", key = "C", color = Color3.fromRGB(150, 95, 255) },
	{ window = "Gifts", label = "Cadeaux", icon = "Cadeau", key = "G", color = Color3.fromRGB(255, 95, 165) },
	{ window = "Shop", label = "Boutique", icon = "Boutique", key = "B", color = Color3.fromRGB(255, 195, 45), breathe = true },
}

local TOASTS = {
	info = { color = Theme.Blue, icon = "Etoile" },
	success = { color = Theme.Green, icon = "Valider" },
	error = { color = Theme.Red, icon = "Fermer" },
	quest = { color = Theme.Gold, icon = "Quete" },
}

HUD.gui = nil
HUD.autoTap = false

-- Minutes de la session, compteur local entre deux profils
local function sessionMinutes(profile): number
	return profile.sessionMinutes + (os.clock() - State.receivedAt) / 60
end

local BADGES = {
	Upgrades = function(profile)
		for _, upgrade in Config.Upgrades do
			local cost = Progression.upgradeCost(upgrade, profile.upgrades[upgrade.id] or 0)
			if cost and profile.coins >= cost then
				return true
			end
		end
		return false
	end,
	Chests = function(profile)
		for _, count in profile.chests do
			if count > 0 then
				return true
			end
		end
		return false
	end,
	Gifts = function(profile)
		local today = math.floor(State.serverTime() / 86400)
		if profile.daily.day < today then
			return true
		end
		local minutes = sessionMinutes(profile)
		for index, needed in Config.PlaytimeGifts do
			if not profile.gifts[tostring(index)] and minutes >= needed then
				return true
			end
		end
		return false
	end,
}

-- Pastille de ressource : icone qui deborde a gauche et montant
local function pill(parent: Instance, order: number, iconName: string, height: number, color: Color3)
	local frame = UI.create("Frame", {
		LayoutOrder = order,
		Size = UDim2.fromOffset(0, height),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = Theme.Background,
		BackgroundTransparency = 0.1,
		Parent = parent,
	}, {
		UI.corner(),
		UI.stroke(Theme.Outline, 3),
		UI.create("UIPadding", { PaddingLeft = UDim.new(0, height + 6), PaddingRight = UDim.new(0, 16) }),
	})
	frame:FindFirstChildOfClass("UIStroke").Color = color:Lerp(Theme.Outline, 0.75)
	UI.icon(iconName, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0, -height / 2 - 4, 0.5, 0),
		Size = UDim2.fromOffset(height * 1.35, height * 1.35),
		ZIndex = 3,
		Parent = frame,
	})
	local label = UI.text({
		RichText = true,
		Font = Theme.Fonts.Number,
		TextSize = math.floor(height * 0.55),
		TextXAlignment = Enum.TextXAlignment.Left,
		Size = UDim2.new(0, 0, 1, 0),
		AutomaticSize = Enum.AutomaticSize.X,
		Parent = frame,
	})
	return frame, label
end

-- Monnaie premium, gains par tap et par seconde, coffres en reserve (haut gauche)
local function buildWallet(gui: ScreenGui)
	local column = UI.create("Frame", {
		Name = "Ressources",
		Position = UDim2.fromOffset(28, 66),
		Size = UDim2.fromOffset(260, 400),
		BackgroundTransparency = 1,
		Parent = gui,
	}, { UI.create("UIListLayout", { Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder }) })
	UI.autoScale(column)
	UI.create("UIPadding", { PaddingLeft = UDim.new(0, 6), Parent = column })

	local gemsPill, gems = pill(column, 1, Config.Premium.icon, 46, Config.Premium.color)
	local _, perTap = pill(column, 2, "Puissance", 32, Theme.Gold)
	local _, perSecond = pill(column, 3, "Auto", 32, Theme.Green)
	local chestsPill, chests = pill(column, 4, "Coffre", 32, Theme.Accent)

	local lastGems
	State.observe(function(profile)
		gems.Text = Format.short(profile.gems)
		if lastGems and profile.gems > lastGems then
			UI.pop(gemsPill, 1.12)
		end
		lastGems = profile.gems
		perTap.Text = Format.short(profile.stats.tap) .. " / tap"
		perSecond.Text = Format.short(profile.stats.income) .. " / s"
		local parts = {}
		for _, chest in Chests.List do
			local count = profile.chests[chest.id] or 0
			if count > 0 then
				local rarity = Config.ChestRarities[chest.index]
				table.insert(parts, ('<font color="#%s">%d</font>'):format(rarity.color:ToHex(), count))
			end
		end
		chestsPill.Visible = #parts > 0
		chests.Text = table.concat(parts, "  ")
	end)
end

-- Monnaie principale, niveau et bonus (haut centre)
local function buildMainPanel(gui: ScreenGui)
	local holder = UI.create("Frame", {
		Name = "Principal",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 12),
		Size = UDim2.fromOffset(420, 150),
		BackgroundTransparency = 1,
		Parent = gui,
	})
	UI.autoScale(holder)
	local panel = UI.panel({ Size = UDim2.fromOffset(420, 96), Parent = holder })
	panel:FindFirstChildOfClass("UIStroke").Thickness = 4
	UI.icon(Config.Currency.icon, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(18, 40), Size = UDim2.fromOffset(86, 86), Rotation = -10, ZIndex = 3, Parent = panel })
	UI.text({ Text = UI.upper(Config.Currency.name), Font = Theme.Fonts.Number, TextSize = 16, TextColor3 = Theme.Gold, Position = UDim2.fromOffset(60, 6), Size = UDim2.new(1, -80, 0, 18), Parent = panel })
	local amount = UI.text({ Text = "0", Font = Theme.Fonts.Number, TextSize = 40, Position = UDim2.fromOffset(60, 22), Size = UDim2.new(1, -80, 0, 40), Outline = 3.5, Parent = panel })
	UI.colorGradient(Color3.fromRGB(255, 250, 200), Color3.fromRGB(255, 190, 40)).Parent = amount
	local levelBar = UI.bar({ Parent = panel, Position = UDim2.fromOffset(60, 66), Size = UDim2.new(1, -76, 0, 22), Height = 22, Color = Theme.Accent, TextSize = 14 })
	UI.icon("Couronne", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(42, 77), Size = UDim2.fromOffset(34, 34), ZIndex = 4, Parent = panel })
	HUD.coinsLabel = amount

	-- Multiplicateurs actifs
	local chips = UI.create("Frame", {
		Name = "Bonus",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 106),
		Size = UDim2.fromOffset(700, 30),
		BackgroundTransparency = 1,
		Parent = holder,
	}, {
		UI.create("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, Padding = UDim.new(0, 8) }),
	})
	local function chip(text: string, color: Color3, iconName: string)
		local frame = UI.create("Frame", { Size = UDim2.fromOffset(0, 30), AutomaticSize = Enum.AutomaticSize.X, BackgroundColor3 = color, Parent = chips }, {
			UI.corner(),
			UI.stroke(Theme.Outline, 2.5),
			UI.gradient(0.35),
			UI.create("UIPadding", { PaddingLeft = UDim.new(0, 34), PaddingRight = UDim.new(0, 12) }),
		})
		UI.icon(iconName, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0, -17, 0.5, 0), Size = UDim2.fromOffset(34, 34), Parent = frame })
		UI.text({ Text = text, Font = Theme.Fonts.Title, TextSize = 16, Size = UDim2.fromScale(0, 1), AutomaticSize = Enum.AutomaticSize.X, Outline = 2, Parent = frame })
	end

	local last = nil
	local function refresh(profile)
		amount.Text = Format.number(profile.coins)
		if last and profile.coins > last then
			UI.pop(amount, 1.06)
		end
		last = profile.coins
		local low = Progression.levelThreshold(profile.level)
		local high = Progression.levelThreshold(profile.level + 1)
		levelBar:set((profile.totalEarned - low) / math.max(1, high - low), ("Niveau %d  ›  %d (%s)"):format(profile.level, profile.level + 1, Format.short(high)))

		for _, child in chips:GetChildren() do
			if child:IsA("Frame") then
				child:Destroy()
			end
		end
		local multiplier = profile.stats.multiplier
		if multiplier > 1.001 then
			chip(("Gains x%s"):format((("%.2f"):format(multiplier):gsub("%.?0+$", ""):gsub("%.", ","))), Color3.fromRGB(60, 185, 95), "Etoile")
		end
		for _, pass in Shop.Passes do
			if profile.passes[pass.id] then
				chip(pass.name, Color3.fromRGB(235, 165, 30), pass.icon)
			end
		end
		local elapsed = os.clock() - State.receivedAt
		for id, remaining in profile.boosts do
			local boost = Progression.Boosts[id]
			if boost and remaining - elapsed > 0 then
				chip(boost.label .. " " .. Format.duration(remaining - elapsed), boost.color, boost.icon)
			end
		end
	end
	State.observe(refresh)
	-- Les comptes a rebours des boosts avancent meme sans changement du profil
	task.spawn(function()
		while true do
			task.wait(1)
			if State.profile and next(State.profile.boosts) then
				refresh(State.profile)
			end
		end
	end)
end

-- Boutons de menu (voir MENU)
local function buildMenu(gui: ScreenGui, open)
	local column = UI.create("Frame", {
		Name = "Menu",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 16, 0.6, 0),
		Size = UDim2.fromOffset(206, 206),
		BackgroundTransparency = 1,
		Parent = gui,
	})
	local grid = UI.create("UIGridLayout", { CellSize = UDim2.fromOffset(98, 98), CellPadding = UDim2.fromOffset(10, 10), SortOrder = Enum.SortOrder.LayoutOrder, Parent = column })
	UI.autoScale(column)

	local badges = {}
	local hints, labels = {}, {}
	for order, entry in MENU do
		local button = UI.button({ LayoutOrder = order, Text = "", BackgroundColor3 = entry.color, Parent = column }, function()
			open(entry.window)
		end)
		button:FindFirstChildOfClass("UICorner").CornerRadius = UDim.new(0, 18)
		local icon = UI.icon(entry.icon, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.42, 0), Size = UDim2.fromScale(0.71, 0.71), Parent = button })
		table.insert(labels, UI.text({ Text = entry.label, Font = Theme.Fonts.Title, TextSize = 17, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -2), Size = UDim2.new(1, 0, 0, 22), Outline = 2.5, Parent = button }))
		if entry.key then
			local hint = UI.create("Frame", { Position = UDim2.fromOffset(-6, -6), Size = UDim2.fromOffset(24, 24), BackgroundColor3 = Theme.Background, Parent = button }, { UI.corner(6), UI.stroke(Theme.Outline, 2) })
			UI.text({ Text = entry.key, Font = Theme.Fonts.Number, TextSize = 14, Size = UDim2.fromScale(1, 1), Outline = false, Parent = hint })
			table.insert(hints, hint)
		end
		local badge = UI.create("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(1, -6, 0, 6), Size = UDim2.fromOffset(28, 28), BackgroundColor3 = Theme.Red, Visible = false, ZIndex = 5, Parent = button }, { UI.corner(), UI.stroke(Theme.Outline, 2.5) })
		UI.text({ Text = "!", Font = Theme.Fonts.Number, TextSize = 20, Size = UDim2.fromScale(1, 1), ZIndex = 6, Outline = false, Parent = badge })
		badges[entry.window] = badge
		-- L'icone se balance doucement quand une pastille est affichee
		task.spawn(function()
			while true do
				task.wait(0.6)
				if badge.Visible then
					TweenService:Create(icon, TweenInfo.new(0.15), { Rotation = 10 }):Play()
					task.wait(0.15)
					TweenService:Create(icon, TweenInfo.new(0.15), { Rotation = -10 }):Play()
					task.wait(0.15)
					TweenService:Create(icon, TweenInfo.new(0.2), { Rotation = 0 }):Play()
				end
			end
		end)
		-- La boutique respire pour attirer l'oeil
		if entry.breathe then
			local breath = UI.create("UIScale", { Name = "Respiration", Parent = icon })
			TweenService:Create(breath, TweenInfo.new(0.9, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Scale = 1.12 }):Play()
		end
	end

	-- Ordinateur : deux colonnes a gauche, avec les raccourcis clavier. Tactile : une ou deux
	-- rangees en haut a droite, loin du joystick (moitie gauche) et du pouce qui tape.
	local columns = 2
	local rows = math.ceil(#MENU / columns)
	UI.onLayout(function(touch: boolean)
		for _, hint in hints do
			hint.Visible = not touch
		end
		for _, label in labels do
			label.TextSize = if touch then 15 else 17
		end
		if touch then
			local perRow = math.min(#MENU, 4)
			local touchRows = math.ceil(#MENU / perRow)
			grid.CellSize = UDim2.fromOffset(80, 80)
			grid.CellPadding = UDim2.fromOffset(8, 8)
			column.AnchorPoint = Vector2.new(1, 0)
			column.Position = UDim2.new(1, -12, 0, 12)
			column.Size = UDim2.fromOffset(perRow * 80 + (perRow - 1) * 8, touchRows * 80 + (touchRows - 1) * 8)
			HUD.menuHeight = touchRows * 80 + (touchRows - 1) * 8
		else
			grid.CellSize = UDim2.fromOffset(98, 98)
			grid.CellPadding = UDim2.fromOffset(10, 10)
			column.AnchorPoint = Vector2.new(0, 0.5)
			column.Position = UDim2.new(0, 16, 0.6, 0)
			column.Size = UDim2.fromOffset(columns * 98 + 10, rows * 98 + (rows - 1) * 10)
		end
	end)

	local function refreshBadges()
		local profile = State.profile
		if not profile then
			return
		end
		for window, badge in badges do
			local check = BADGES[window]
			badge.Visible = check ~= nil and check(profile)
		end
	end
	State.observe(refreshBadges)
	task.spawn(function()
		while true do
			task.wait(5)
			refreshBadges()
		end
	end)
end

-- Bouton TAPER, auto-tap et musique (bas)
local function buildTapBar(gui: ScreenGui)
	local bar = UI.create("Frame", {
		Name = "Taper",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -16),
		Size = UDim2.fromOffset(420, 100),
		BackgroundTransparency = 1,
		Parent = gui,
	})
	UI.autoScale(bar)
	local tap = UI.button({
		Name = "Taper",
		Text = "TAPER",
		Font = Theme.Fonts.Number,
		TextSize = 38,
		Icon = Config.Currency.icon,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, -20, 1, 0),
		Size = UDim2.fromOffset(250, 86),
		Variant = "success",
		Parent = bar,
	}, function()
		HUD.tap()
	end)
	tap:SetAttribute("Muet", true)
	tap:FindFirstChildOfClass("UICorner").CornerRadius = UDim.new(0, 22)
	tap:FindFirstChildOfClass("UIStroke").Thickness = 4
	HUD.tapButton = tap
	HUD.tapScale = UI.scaleOf(tap)

	local auto = UI.button({
		Name = "Auto",
		Text = "",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0.5, 118, 1, 0),
		Size = UDim2.fromOffset(86, 86),
		Variant = "ghost",
		Parent = bar,
	})
	auto:FindFirstChildOfClass("UICorner").CornerRadius = UDim.new(0, 22)
	local gear = UI.icon("Auto", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.42, 0), Size = UDim2.fromOffset(54, 54), Parent = auto })
	local autoLabel = UI.text({ Text = "AUTO", Font = Theme.Fonts.Number, TextSize = 16, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -3), Size = UDim2.new(1, 0, 0, 18), Outline = 2, Parent = auto })
	local function refreshAuto()
		local owned = State.profile and State.profile.passes.AutoTap
		auto.BackgroundColor3 = if HUD.autoTap then UI.Variants.success elseif owned then UI.Variants.ghost else UI.Variants.gold
		autoLabel.Text = if not owned then "PASS" elseif HUD.autoTap then "ON" else "AUTO"
	end
	auto.Activated:Connect(function()
		if State.profile and State.profile.passes.AutoTap then
			HUD.autoTap = not HUD.autoTap
			refreshAuto()
		else
			HUD.openWindow("Shop", { focus = "AutoTap" })
		end
	end)
	State.observe(refreshAuto)
	-- L'engrenage tourne pendant l'auto-tap
	task.spawn(function()
		while true do
			local dt = task.wait()
			if HUD.autoTap then
				gear.Rotation = (gear.Rotation + dt * 180) % 360
			end
		end
	end)

	-- Musique : couper ou remettre
	local music = UI.button({ Name = "Musique", Text = "", AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(0.5, -160, 1, -8), Size = UDim2.fromOffset(70, 70), Variant = "primary", Parent = bar })
	music:FindFirstChildOfClass("UICorner").CornerRadius = UDim.new(0, 20)
	local note = UI.icon("Musique", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(48, 48), Parent = music })
	music.Activated:Connect(function()
		Sons.setMusic(not Sons.musicOn)
		music.BackgroundColor3 = if Sons.musicOn then UI.Variants.primary else UI.Variants.ghost
		note.ImageTransparency = if Sons.musicOn then 0 else 0.55
	end)

	-- Ordinateur : en bas au centre. Tactile : en bas a droite, a gauche du bouton de saut de
	-- Roblox (petit en bas a droite sur telephone, plus grand et plus haut sur tablette)
	UI.onLayout(function(touch: boolean)
		if touch then
			local camera = workspace.CurrentCamera
			local viewport = if camera then camera.ViewportSize else Vector2.new(1280, 720)
			local phone = math.min(viewport.X, viewport.Y) <= 500
			bar.AnchorPoint = Vector2.new(1, 1)
			bar.Position = UDim2.new(1, if phone then -105 else -190, 1, -8)
		else
			bar.AnchorPoint = Vector2.new(0.5, 1)
			bar.Position = UDim2.new(0.5, 0, 1, -16)
		end
	end)

	-- Auto-tap
	task.spawn(function()
		while true do
			task.wait(1 / Config.AutoTapRate)
			if HUD.autoTap and State.profile and State.profile.passes.AutoTap then
				HUD.tap(true)
			end
		end
	end)
end

-- Suivi de l'objectif en cours (droite)
local function buildQuestTracker(gui: ScreenGui)
	local holder = UI.create("Frame", {
		Name = "Objectif",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -20, 0, 190),
		Size = UDim2.fromOffset(310, 10),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Parent = gui,
	})
	UI.autoScale(holder)
	-- Tactile : sous le menu en haut a droite
	UI.onLayout(function(touch: boolean, scale: number)
		holder.Position = if touch then UDim2.new(1, -12, 0, 12 + (HUD.menuHeight or 80) * scale + 12) else UDim2.new(1, -20, 0, 190)
	end)
	local tracker = UI.panel({
		Size = UDim2.fromOffset(310, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Parent = holder,
	}, {
		UI.create("UIPadding", { PaddingTop = UDim.new(0, 14), PaddingBottom = UDim.new(0, 14), PaddingLeft = UDim.new(0, 16), PaddingRight = UDim.new(0, 14) }),
		UI.create("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	tracker:FindFirstChildOfClass("UIStroke").Thickness = 3.5
	UI.icon("Quete", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(4, 6), Size = UDim2.fromOffset(52, 52), Rotation = -12, ZIndex = 4, Parent = holder })
	local heading = UI.text({ Text = "OBJECTIF", LayoutOrder = 1, Font = Theme.Fonts.Number, TextSize = 15, TextColor3 = Theme.Gold, TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.new(1, 0, 0, 16), Parent = tracker })
	UI.create("UIPadding", { PaddingLeft = UDim.new(0, 26), Parent = heading })
	local title = UI.text({ LayoutOrder = 2, TextSize = 21, TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = true, Size = UDim2.fromScale(1, 0), AutomaticSize = Enum.AutomaticSize.Y, Parent = tracker })
	local body = UI.text({ LayoutOrder = 3, Font = Theme.Fonts.Body, TextSize = 16, TextColor3 = Theme.Muted, TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = true, Size = UDim2.fromScale(1, 0), AutomaticSize = Enum.AutomaticSize.Y, Parent = tracker })
	local progressBar = UI.bar({ Parent = tracker, Size = UDim2.new(1, 0, 0, 22), Height = 22, Color = Theme.Gold, TextSize = 14 })
	progressBar.frame.LayoutOrder = 4

	local lastIndex
	State.observe(function(profile)
		local quest = Quests[profile.quest.index]
		if lastIndex and lastIndex ~= profile.quest.index then
			UI.pop(tracker, 0.85)
		end
		lastIndex = profile.quest.index
		if not quest then
			title.Text = Quests.Final.title
			body.Text = Quests.Final.text
			progressBar.frame.Visible = false
			return
		end
		title.Text = quest.title
		body.Text = quest.text
		local objective = quest.objective
		local current, goal, label
		if objective.type == "taps" then
			current, goal, label = profile.quest.progress, objective.count, "Taps"
		elseif objective.type == "chest" then
			current, goal, label = profile.quest.progress, objective.count, "Coffres"
		elseif objective.type == "earn" then
			current, goal, label = profile.totalEarned, objective.amount, Config.Currency.name
		elseif objective.type == "upgrade" then
			local upgrade = Config.UpgradeById[objective.id]
			current, goal, label = profile.upgrades[objective.id] or 0, objective.level, if upgrade then upgrade.name else "Niveau"
		elseif objective.type == "level" then
			current, goal, label = profile.level, objective.level, "Niveau"
		else
			current, goal, label = profile.quest.progress, objective.count or 1, "Progression"
		end
		progressBar.frame.Visible = true
		progressBar:set(math.min(current, goal) / goal, ("%s : %s / %s"):format(label, Format.short(math.min(current, goal)), Format.short(goal)))
	end)
end

-- Notifications empilees en bas a droite
local function buildToasts(gui: ScreenGui)
	local container = UI.create("Frame", {
		Name = "Notifications",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -20, 1, -150),
		Size = UDim2.fromOffset(340, 330),
		BackgroundTransparency = 1,
		Parent = gui,
	}, {
		UI.create("UIListLayout", { VerticalAlignment = Enum.VerticalAlignment.Bottom, HorizontalAlignment = Enum.HorizontalAlignment.Right, Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	UI.autoScale(container)
	-- Tactile : au-dessus du bouton TAPER et du saut
	UI.onLayout(function(touch: boolean, scale: number)
		container.Position = if touch then UDim2.new(1, -12, 1, -(150 * scale + 110)) else UDim2.new(1, -20, 1, -150)
	end)
	local order = 0
	return function(message: string, kind: string)
		order += 1
		local style = TOASTS[kind] or TOASTS.info
		local toast = UI.panel({ Size = UDim2.new(1, -18, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = order, Parent = container }, {
			UI.create("UIPadding", { PaddingTop = UDim.new(0, 12), PaddingBottom = UDim.new(0, 12), PaddingLeft = UDim.new(0, 38), PaddingRight = UDim.new(0, 14) }),
		})
		toast:FindFirstChildOfClass("UIStroke").Color = style.color:Lerp(Theme.Outline, 0.35)
		local badge = UI.create("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0, -38, 0.5, 0), Size = UDim2.fromOffset(46, 46), BackgroundColor3 = style.color, Parent = toast }, { UI.corner(), UI.stroke(Theme.Outline, 3), UI.gradient(0.3) })
		UI.icon(style.icon, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.72, 0.72), Parent = badge })
		UI.text({ Text = message, Font = Theme.Fonts.Body, TextSize = 17, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.fromScale(1, 0), AutomaticSize = Enum.AutomaticSize.Y, Parent = toast })
		local scale = UI.scaleOf(toast)
		scale.Scale = 0.6
		TweenService:Create(scale, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Scale = 1 }):Play()
		task.delay(5, function()
			TweenService:Create(scale, TweenInfo.new(0.2), { Scale = 0 }):Play()
			task.wait(0.2)
			toast:Destroy()
		end)
		-- Pas plus de 4 notifications a l'ecran
		local toasts = {}
		for _, child in container:GetChildren() do
			if child:IsA("Frame") then
				table.insert(toasts, child)
			end
		end
		table.sort(toasts, function(a, b)
			return a.LayoutOrder < b.LayoutOrder
		end)
		for index = 1, #toasts - 4 do
			toasts[index]:Destroy()
		end
	end
end

-- Annonces au centre de l'ecran, avec rayons tournants
local function buildBanner(gui: ScreenGui)
	local banner = UI.create("Frame", {
		Name = "Annonce",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.3),
		Size = UDim2.fromOffset(760, 130),
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = 20,
		Parent = gui,
	})
	UI.autoScale(banner)
	local rays = UI.icon("Rayons", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.4), Size = UDim2.fromOffset(420, 420), ImageTransparency = 0.35, ZIndex = 19, Parent = banner })
	rays.Visible = Icons.get("Rayons") ~= nil
	local title = UI.text({ Font = Theme.Fonts.Number, TextSize = 60, Size = UDim2.new(1, 0, 0, 68), ZIndex = 21, Outline = 5, Parent = banner })
	local titleGradient = UI.colorGradient(Color3.new(1, 1, 1), Theme.Gold)
	titleGradient.Parent = title
	local subtitle = UI.text({ Font = Theme.Fonts.Title, TextSize = 24, TextWrapped = true, Position = UDim2.fromOffset(0, 72), Size = UDim2.new(1, 0, 0, 52), ZIndex = 21, Outline = 3, Parent = banner })
	local scale = UI.scaleOf(banner)
	local queue = {}
	local showing = false
	local function pump()
		if showing or #queue == 0 then
			return
		end
		showing = true
		local entry = table.remove(queue, 1)
		local color = entry.color or Theme.Gold
		title.Text = entry.title
		titleGradient.Color = ColorSequence.new(color:Lerp(Color3.new(1, 1, 1), 0.65), color)
		rays.ImageColor3 = color
		subtitle.Text = entry.subtitle or ""
		banner.Visible = true
		scale.Scale = 0.4
		TweenService:Create(scale, TweenInfo.new(0.4, Enum.EasingStyle.Back), { Scale = 1 }):Play()
		task.delay(2.4, function()
			TweenService:Create(scale, TweenInfo.new(0.18), { Scale = 0 }):Play()
			task.wait(0.18)
			banner.Visible = false
			showing = false
			pump()
		end)
	end
	task.spawn(function()
		while true do
			local dt = task.wait()
			if banner.Visible then
				rays.Rotation = (rays.Rotation + dt * 25) % 360
			end
		end
	end)
	local function show(text: string, sub: string?, color: Color3?)
		if #queue < 4 then
			table.insert(queue, { title = text, subtitle = sub, color = color })
		end
		pump()
	end
	HUD.banner = show
	State.remotes:WaitForChild("Effect").OnClientEvent:Connect(function(kind, data)
		if kind == "level" then
			show(("NIVEAU %d"):format(data.level), ("Tous tes gains augmentent ! +%d %s"):format(data.gems, Config.Premium.short), Theme.Gold)
		elseif kind == "quest" then
			show("OBJECTIF RÉUSSI", data.title .. (if data.reward ~= "" then " : " .. data.reward else ""), Theme.Green)
		elseif kind == "reward" then
			show(data.title or "RÉCOMPENSE", data.text, Theme.Green)
		end
	end)
end

-- Un tap : envoi au serveur et retour visuel immediat (le gain affiche est celui du profil)
function HUD.tap(auto: boolean?)
	State.send("Tap")
	if not auto then
		Sons.tap()
	end
	if HUD.tapScale then
		HUD.tapScale.Scale = 0.9
		TweenService:Create(HUD.tapScale, TweenInfo.new(0.14, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	end
	local profile = State.profile
	if profile and HUD.tapButton then
		Effects.gain(HUD.tapButton, "+" .. Format.short(profile.stats.tap), Theme.Gold)
	end
end

function HUD.start(openWindow)
	pcall(StarterGui.SetCoreGuiEnabled, StarterGui, Enum.CoreGuiType.Backpack, false)
	HUD.openWindow = openWindow

	local gui = UI.create("ScreenGui", {
		Name = "HUD",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = player:WaitForChild("PlayerGui"),
	})
	HUD.gui = gui

	buildWallet(gui)
	buildMainPanel(gui)
	buildMenu(gui, openWindow)
	buildTapBar(gui)
	buildQuestTracker(gui)
	local notify = buildToasts(gui)
	buildBanner(gui)

	State.remotes:WaitForChild("Notify").OnClientEvent:Connect(notify)
	HUD.notify = notify

	-- Raccourcis clavier du menu
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		for _, entry in MENU do
			if entry.key and input.KeyCode == Enum.KeyCode[entry.key] then
				openWindow(entry.window)
			end
		end
	end)
	return gui
end

return HUD
