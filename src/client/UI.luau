-- Theme et composants d'interface communs (StarterPlayerScripts.Client.UI)
-- Style "simulateur" : couleurs vives, contours sombres epais, degrades, icones dessinees,
-- boutons qui reagissent au survol et au clic.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Icons = require(ReplicatedStorage.Shared.Icons)

local UI = {}

UI.Theme = {
	Background = Color3.fromRGB(30, 22, 58),
	Surface = Color3.fromRGB(56, 44, 100),
	Outline = Color3.fromRGB(20, 12, 38),
	Accent = Color3.fromRGB(150, 95, 255),
	Blue = Color3.fromRGB(60, 150, 255),
	Gold = Color3.fromRGB(255, 205, 60),
	Orange = Color3.fromRGB(255, 145, 40),
	Green = Color3.fromRGB(70, 210, 100),
	Red = Color3.fromRGB(240, 70, 90),
	Pink = Color3.fromRGB(255, 105, 180),
	Text = Color3.fromRGB(255, 255, 255),
	Muted = Color3.fromRGB(200, 190, 235),
	Fonts = {
		Number = Enum.Font.FredokaOne,
		Title = Enum.Font.FredokaOne,
		Body = Enum.Font.BuilderSansBold,
	},
}

local Theme = UI.Theme

-- Couleurs des variantes de boutons
UI.Variants = {
	primary = Color3.fromRGB(60, 150, 255),
	success = Color3.fromRGB(60, 200, 95),
	danger = Color3.fromRGB(235, 65, 85),
	gold = Color3.fromRGB(255, 195, 45),
	purple = Color3.fromRGB(150, 95, 255),
	pink = Color3.fromRGB(255, 100, 175),
	ghost = Color3.fromRGB(70, 58, 120),
}

-- Majuscules, accents compris (string.upper ignore les lettres accentuees)
local ACCENTS = { ["é"] = "É", ["è"] = "È", ["ê"] = "Ê", ["à"] = "À", ["â"] = "Â", ["ç"] = "Ç", ["ô"] = "Ô", ["î"] = "Î", ["û"] = "Û", ["ù"] = "Ù", ["ë"] = "Ë", ["ï"] = "Ï", ["œ"] = "Œ" }
function UI.upper(text: string): string
	local result = text:upper()
	for lower, upper in ACCENTS do
		result = result:gsub(lower, upper)
	end
	return result
end

function UI.create(className: string, props, children)
	local instance = Instance.new(className)
	for key, value in props do
		if key ~= "Parent" then
			instance[key] = value
		end
	end
	for _, child in children or {} do
		child.Parent = instance
	end
	instance.Parent = props.Parent
	return instance
end

function UI.corner(radius: number?)
	return UI.create("UICorner", { CornerRadius = if radius then UDim.new(0, radius) else UDim.new(1, 0) })
end

function UI.stroke(color: Color3, thickness: number?, transparency: number?)
	return UI.create("UIStroke", {
		Color = color,
		Thickness = thickness or 1,
		Transparency = transparency or 0,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
end

function UI.padding(pixels: number)
	local offset = UDim.new(0, pixels)
	return UI.create("UIPadding", { PaddingTop = offset, PaddingBottom = offset, PaddingLeft = offset, PaddingRight = offset })
end

-- Degrade vertical : garde le haut de la couleur de fond et assombrit le bas
function UI.gradient(bottom: number?)
	return UI.create("UIGradient", {
		Rotation = 90,
		Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.new(1, 1, 1):Lerp(Color3.new(0, 0, 0), bottom or 0.22)),
	})
end

-- Degrade de couleur explicite (texte dore, rubans...)
function UI.colorGradient(top: Color3, bottom: Color3, rotation: number?)
	return UI.create("UIGradient", { Rotation = rotation or 90, Color = ColorSequence.new(top, bottom) })
end

-- Contour epais autour du texte d'une etiquette
function UI.textOutline(label: TextLabel, thickness: number?)
	return UI.create("UIStroke", {
		Color = Theme.Outline,
		Thickness = thickness or math.max(1.5, label.TextSize / 11),
		ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
		LineJoinMode = Enum.LineJoinMode.Round,
		Parent = label,
	})
end

-- Panneau sombre arrondi, style commun a toute l'interface
function UI.panel(props, children)
	props.BackgroundColor3 = props.BackgroundColor3 or Theme.Background
	props.BackgroundTransparency = props.BackgroundTransparency or 0.05
	props.BorderSizePixel = 0
	local list = {
		UI.corner(16),
		UI.stroke(Theme.Outline, 3, 0),
		UI.create("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(175, 170, 200)) }),
	}
	for _, child in children or {} do
		table.insert(list, child)
	end
	return UI.create("Frame", props, list)
end

-- Etiquette. Les polices d'affichage (titres, nombres) recoivent un contour epais.
function UI.text(props)
	props.BackgroundTransparency = 1
	props.Font = props.Font or Theme.Fonts.Title
	props.TextColor3 = props.TextColor3 or Theme.Text
	local outline = props.Outline
	props.Outline = nil
	local label = UI.create("TextLabel", props)
	if outline ~= false and (label.Font == Theme.Fonts.Title or label.Font == Theme.Fonts.Number) then
		label.TextStrokeTransparency = 1
		UI.textOutline(label, if type(outline) == "number" then outline else nil)
	end
	return label
end

-- Image d'une icone (Shared.Icons). Sans identifiant, une pastille de couleur la remplace.
function UI.icon(name: string, props)
	props = props or {}
	props.BackgroundTransparency = 1
	props.ScaleType = Enum.ScaleType.Fit
	local id = Icons.get(name)
	local image = UI.create("ImageLabel", props)
	image.Name = props.Name or ("Icone" .. name)
	if id then
		image.Image = id
	else
		local color = Icons.Colors[name] or Theme.Gold
		local dot = UI.create("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(0.78, 0.78),
			BackgroundColor3 = color,
			ZIndex = image.ZIndex,
			Parent = image,
		}, { UI.corner(), UI.stroke(Theme.Outline, 2.5), UI.gradient(0.3) })
		UI.create("UIAspectRatioConstraint", { Parent = dot })
	end
	return image
end

-- Change l'icone affichee par une image creee avec UI.icon
function UI.setIcon(image: ImageLabel, name: string)
	local id = Icons.get(name)
	for _, child in image:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	image.Image = id or ""
	if not id then
		local dot = UI.create("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(0.78, 0.78),
			BackgroundColor3 = Icons.Colors[name] or Theme.Gold,
			ZIndex = image.ZIndex,
			Parent = image,
		}, { UI.corner(), UI.stroke(Theme.Outline, 2.5), UI.gradient(0.3) })
		UI.create("UIAspectRatioConstraint", { Parent = dot })
	end
end

-- Petit son d'interface
local clickSound = Instance.new("Sound")
clickSound.Name = "ClicInterface"
clickSound.SoundId = "rbxassetid://117649901456711"
clickSound.Volume = 0.4
clickSound.Parent = SoundService
function UI.click()
	clickSound.PlaybackSpeed = 0.95 + math.random() * 0.15
	SoundService:PlayLocalSound(clickSound)
end

-- Echelle d'animation d'un element (cree au besoin)
function UI.scaleOf(instance: GuiObject): UIScale
	local scale = instance:FindFirstChild("Animation")
	if not scale then
		scale = UI.create("UIScale", { Name = "Animation", Parent = instance })
	end
	return scale :: UIScale
end

-- Petit rebond (apparition, gain)
function UI.pop(instance: GuiObject, from: number?)
	local scale = UI.scaleOf(instance)
	scale.Scale = from or 0.8
	TweenService:Create(scale, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
end

-- Adapte la taille de l'interface a l'ecran (telephone, tablette, ordinateur). Chaque groupe
-- de l'interface recoit une UIScale qui suit la taille de la fenetre de jeu.
local scales = {}
local function screenScale(): number
	local camera = Workspace.CurrentCamera
	local size = if camera then camera.ViewportSize else Vector2.new(1280, 720)
	return math.clamp(math.min(size.X / 1280, size.Y / 760), 0.55, 1.15)
end
function UI.autoScale(instance: GuiObject)
	local scale = UI.create("UIScale", { Name = "Ecran", Scale = screenScale(), Parent = instance })
	table.insert(scales, scale)
	return scale
end
local function watchCamera(camera: Camera?)
	if camera then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
			local value = screenScale()
			for _, scale in scales do
				scale.Scale = value
			end
		end)
	end
end
watchCamera(Workspace.CurrentCamera)
Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
	watchCamera(Workspace.CurrentCamera)
end)
UI.screenScale = screenScale

-- Disposition tactile (telephone, tablette sans clavier) : le pouce gauche deplace le
-- personnage (joystick de Roblox), le pouce droit tape. Les modules qui placent leurs elements
-- differemment s'abonnent avec UI.onLayout ; le rappel est aussi appele quand la taille de
-- l'ecran change ou quand le joueur passe du clavier au tactile (tablette avec clavier).
local layoutCallbacks = {}
local touchMode = false
-- Seuls le toucher et la souris decident : le clavier seul ne fait pas basculer (tablette avec
-- clavier, emulateur de Studio ou l'on se deplace avec les touches)
local function computeTouch(): boolean
	local last = UserInputService:GetLastInputType()
	if last == Enum.UserInputType.Touch then
		return true
	elseif last == Enum.UserInputType.MouseMovement or last == Enum.UserInputType.MouseButton1 or last == Enum.UserInputType.MouseButton2 or last == Enum.UserInputType.MouseWheel then
		return false
	end
	return touchMode
end
touchMode = UserInputService.TouchEnabled and not UserInputService.MouseEnabled
touchMode = computeTouch()
function UI.isTouch(): boolean
	return touchMode
end
local function relayout()
	for _, callback in layoutCallbacks do
		task.spawn(callback, touchMode, screenScale())
	end
end
function UI.onLayout(callback)
	table.insert(layoutCallbacks, callback)
	task.spawn(callback, touchMode, screenScale())
end
UserInputService.LastInputTypeChanged:Connect(function()
	local value = computeTouch()
	if value ~= touchMode then
		touchMode = value
		relayout()
	end
end)
local function watchSize(camera: Camera?)
	if camera then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(relayout)
	end
end
watchSize(Workspace.CurrentCamera)
Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
	watchSize(Workspace.CurrentCamera)
end)

-- Barre de progression avec trainee (la partie perdue s'efface doucement)
-- et texte centre. Renvoie un objet avec :set(ratio, texte, couleur).
function UI.bar(props)
	local height = props.Height or 16
	local frame = UI.create("Frame", {
		Name = props.Name or "Barre",
		Position = props.Position or UDim2.new(),
		Size = props.Size or UDim2.new(1, 0, 0, height),
		AnchorPoint = props.AnchorPoint or Vector2.zero,
		BackgroundColor3 = Color3.fromRGB(25, 18, 45),
		BorderSizePixel = 0,
		ClipsDescendants = true,
		Parent = props.Parent,
	}, { UI.corner(math.floor(height / 2)), UI.stroke(Theme.Outline, 2.5) })
	local trail = UI.create("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0.4,
		BorderSizePixel = 0,
		Parent = frame,
	}, { UI.corner(math.floor(height / 2)) })
	local fill = UI.create("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = props.Color or Theme.Green,
		BorderSizePixel = 0,
		Parent = frame,
	}, {
		UI.corner(math.floor(height / 2)),
		UI.create("UIGradient", {
			Rotation = 90,
			Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
				ColorSequenceKeypoint.new(0.45, Color3.fromRGB(235, 235, 235)),
				ColorSequenceKeypoint.new(1, Color3.fromRGB(165, 165, 165)),
			}),
		}),
	})
	-- Reflet sur le haut de la barre
	UI.create("Frame", {
		Position = UDim2.new(0, 4, 0, 2),
		Size = UDim2.new(1, -8, 0.32, 0),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0.72,
		BorderSizePixel = 0,
		ZIndex = 2,
		Parent = fill,
	}, { UI.corner() })
	local label = UI.text({
		Size = UDim2.fromScale(1, 1),
		Font = Theme.Fonts.Number,
		TextSize = props.TextSize or math.max(12, height - 4),
		Text = "",
		ZIndex = 3,
		Parent = frame,
	})

	local bar = { frame = frame, fill = fill, label = label, ratio = 1 }

	function bar:set(ratio: number, text: string?, color: Color3?)
		ratio = math.clamp(ratio, 0, 1)
		if color then
			fill.BackgroundColor3 = color
		end
		if text then
			label.Text = text
		end
		local target = UDim2.fromScale(ratio, 1)
		TweenService:Create(fill, TweenInfo.new(0.15, Enum.EasingStyle.Quad), { Size = target }):Play()
		if ratio < self.ratio then
			TweenService:Create(trail, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, 0.25), {
				Size = target,
			}):Play()
		else
			trail.Size = target
		end
		self.ratio = ratio
	end

	return bar
end

-- Bouton colore avec contour, degrade et rebond. props.Variant : "primary" (bleu),
-- "success" (vert), "danger" (rouge), "gold", "purple", "pink" ou "ghost".
-- props.Icon : nom d'une icone affichee a gauche du texte.
function UI.button(props, onClick)
	local variant = props.Variant or "primary"
	local iconName = props.Icon
	props.Variant = nil
	props.Icon = nil
	local base = props.BackgroundColor3 or UI.Variants[variant] or UI.Variants.primary
	props.BackgroundColor3 = base
	props.AutoButtonColor = false
	props.Font = props.Font or Theme.Fonts.Title
	props.TextColor3 = props.TextColor3 or Theme.Text
	props.TextSize = props.TextSize or 18
	props.TextStrokeColor3 = Theme.Outline
	props.TextStrokeTransparency = props.TextStrokeTransparency or 0.25
	props.BorderSizePixel = 0
	local button = UI.create("TextButton", props, {
		UI.corner(12),
		UI.stroke(Theme.Outline, 3),
		UI.create("UIGradient", {
			Rotation = 90,
			Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
				ColorSequenceKeypoint.new(0.5, Color3.fromRGB(240, 240, 240)),
				ColorSequenceKeypoint.new(1, Color3.fromRGB(170, 170, 180)),
			}),
		}),
	})
	-- Reflet en haut du bouton
	UI.create("Frame", {
		Name = "Reflet",
		Position = UDim2.new(0, 6, 0, 3),
		Size = UDim2.new(1, -12, 0.3, 0),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0.8,
		BorderSizePixel = 0,
		Parent = button,
	}, { UI.corner(8) })
	if iconName then
		local icon = UI.icon(iconName, {
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 6, 0.5, 0),
			Size = UDim2.new(1, 0, 1, -8),
			SizeConstraint = Enum.SizeConstraint.RelativeYY,
			ZIndex = button.ZIndex + 1,
			Parent = button,
		})
		icon.Name = "Icone"
		-- Le texte se decale de la largeur de l'icone
		local padding = UI.create("UIPadding", { Parent = button })
		local function fit()
			-- Hauteur en pixels de reference (hors echelles d'ecran et d'animation)
			local height = if button.Size.Y.Scale == 0 then button.Size.Y.Offset else button.AbsoluteSize.Y
			padding.PaddingLeft = UDim.new(0, height)
			icon.Position = UDim2.new(0, 6 - height, 0.5, 0)
		end
		button:GetPropertyChangedSignal("Size"):Connect(fit)
		button:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
		fit()
	end
	local scale = UI.scaleOf(button)
	button.MouseEnter:Connect(function()
		if button.Active then
			TweenService:Create(scale, TweenInfo.new(0.12, Enum.EasingStyle.Back), { Scale = 1.05 }):Play()
		end
	end)
	button.MouseLeave:Connect(function()
		TweenService:Create(scale, TweenInfo.new(0.12), { Scale = 1 }):Play()
	end)
	button.MouseButton1Down:Connect(function()
		if button.Active then
			TweenService:Create(scale, TweenInfo.new(0.06), { Scale = 0.93 }):Play()
		end
	end)
	button.MouseButton1Up:Connect(function()
		TweenService:Create(scale, TweenInfo.new(0.15, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	end)
	button.Activated:Connect(function()
		if button.Active then
			-- Boutons avec leur propre son (TAPER) : attribut "Muet"
			if not button:GetAttribute("Muet") then
				UI.click()
			end
			if onClick then
				onClick()
			end
		end
	end)
	return button
end

-- Active ou grise un bouton
function UI.setEnabled(button: GuiButton, enabled: boolean)
	button.Active = enabled
	button.AutoButtonColor = false
	if button:IsA("TextButton") then
		button.TextTransparency = if enabled then 0 else 0.45
	end
	button.BackgroundTransparency = if enabled then 0 else 0.55
	local icon = button:FindFirstChild("Icone")
	if icon then
		icon.ImageTransparency = if enabled then 0 else 0.5
	end
end

-- Fenetre centrale : bandeau de titre colore avec icone, bouton de fermeture rond.
-- Renvoie (fenetre, contenu, ouvrir/fermer)
function UI.window(parent: Instance, title: string, size: Vector2, iconName: string?, color: Color3?)
	color = color or Theme.Accent
	local holder = UI.create("Frame", {
		Name = "Fenetre_" .. title:gsub("[^%w]", ""),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.53),
		Size = UDim2.fromOffset(size.X, size.Y),
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = 10,
		Parent = parent,
	})
	UI.autoScale(holder)
	local window = UI.panel({
		Name = "Cadre",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Theme.Background,
		BackgroundTransparency = 0,
		ZIndex = 10,
		Parent = holder,
	})
	window:FindFirstChildOfClass("UIStroke").Thickness = 4

	-- Bandeau du titre
	local header = UI.create("Frame", {
		Name = "Bandeau",
		Size = UDim2.new(1, 0, 0, 64),
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		ZIndex = 11,
		Parent = window,
	}, { UI.corner(16), UI.gradient(0.35) })
	-- Bas du bandeau droit (le coin arrondi ne concerne que le haut)
	UI.create("Frame", {
		Position = UDim2.new(0, 0, 1, -16),
		Size = UDim2.new(1, 0, 0, 16),
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		ZIndex = 11,
		Parent = header,
	}, { UI.create("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(200, 200, 200), Color3.fromRGB(166, 166, 166)) }) })
	UI.create("Frame", { Position = UDim2.new(0, 0, 1, 0), Size = UDim2.new(1, 0, 0, 3), BackgroundColor3 = Theme.Outline, BorderSizePixel = 0, ZIndex = 12, Parent = header })

	local titleOffset = 24
	if iconName then
		local icon = UI.icon(iconName, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset(34, 26),
			Size = UDim2.fromOffset(84, 84),
			Rotation = -8,
			ZIndex = 14,
			Parent = holder,
		})
		icon.Name = "IconeTitre"
		titleOffset = 84
	end
	UI.text({
		Text = UI.upper(title),
		Font = Theme.Fonts.Title,
		TextSize = 32,
		TextXAlignment = Enum.TextXAlignment.Left,
		Position = UDim2.fromOffset(titleOffset, 0),
		Size = UDim2.new(1, -titleOffset - 70, 0, 64),
		ZIndex = 13,
		Outline = 3,
		Parent = window,
	})
	local close = UI.button({
		Name = "Fermer",
		Text = "",
		Variant = "danger",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(1, -14, 0, 14),
		Size = UDim2.fromOffset(54, 54),
		ZIndex = 15,
		Parent = holder,
	})
	close:FindFirstChildOfClass("UICorner").CornerRadius = UDim.new(1, 0)
	close:FindFirstChild("Reflet"):Destroy()
	UI.icon("Fermer", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.62, 0.62), ZIndex = 16, Parent = close })

	local content = UI.create("Frame", {
		Name = "Contenu",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(22, 82),
		Size = UDim2.new(1, -44, 1, -100),
		ZIndex = 11,
		Parent = window,
	})
	local popScale = UI.scaleOf(window)
	local function setOpen(open: boolean)
		if open and not holder.Visible then
			popScale.Scale = 0.82
			TweenService:Create(popScale, TweenInfo.new(0.28, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
		end
		holder.Visible = open
	end
	close.Activated:Connect(function()
		setOpen(false)
		if UI.onWindowClosed then
			UI.onWindowClosed()
		end
	end)
	return holder, content, setOpen
end

-- Carte claire posee dans une fenetre (fiche, ligne de liste)
function UI.card(props, children)
	props.BackgroundColor3 = props.BackgroundColor3 or Theme.Surface
	props.BorderSizePixel = 0
	local list = {
		UI.corner(14),
		UI.stroke(Theme.Outline, 3),
		UI.create("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(190, 185, 210)) }),
	}
	for _, child in children or {} do
		table.insert(list, child)
	end
	return UI.create("Frame", props, list)
end

-- Vert quand la vie est pleine, jaune a mi-vie, rouge quand elle est basse
function UI.healthColor(ratio: number): Color3
	return Color3.fromHSV(math.clamp(ratio, 0, 1) * 0.33, 0.75, 0.95)
end

UI.player = Players.LocalPlayer

return UI
