-- Retours visuels (StarterPlayerScripts.Client.Effects)
-- Chiffres de gain qui jaillissent d'un bouton et s'effacent en montant.
local TweenService = game:GetService("TweenService")

local UI = require(script.Parent.UI)

local Theme = UI.Theme

local Effects = {}

local layer = nil

-- Texte qui part du bouton, monte en s'ecartant un peu et s'efface
function Effects.gain(from: GuiObject, text: string, color: Color3?)
	if not layer then
		return
	end
	local center = from.AbsolutePosition + from.AbsoluteSize / 2
	local scale = UI.screenScale()
	local start = center + Vector2.new(math.random(-60, 60), -from.AbsoluteSize.Y * 0.4) * scale
	local label = UI.text({
		Text = text,
		Font = Theme.Fonts.Number,
		TextSize = math.floor(30 * scale),
		TextColor3 = color or Theme.Gold,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(start.X, start.Y),
		Size = UDim2.fromOffset(200, 40),
		ZIndex = 30,
		Outline = 2.5,
		Parent = layer,
	})
	label.Rotation = math.random(-12, 12)
	local stroke = label:FindFirstChildOfClass("UIStroke")
	local finish = start + Vector2.new(math.random(-30, 30), -110) * scale
	local info = TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(label, info, { Position = UDim2.fromOffset(finish.X, finish.Y), Rotation = 0 }):Play()
	TweenService:Create(label, TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { TextTransparency = 1 }):Play()
	if stroke then
		TweenService:Create(stroke, TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Transparency = 1 }):Play()
	end
	task.delay(0.8, label.Destroy, label)
end

function Effects.start(gui: ScreenGui)
	-- Calque sans echelle d'ecran : les positions sont celles des pixels a l'ecran
	layer = UI.create("Frame", { Name = "Gains", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 30, Parent = gui })
end

return Effects
