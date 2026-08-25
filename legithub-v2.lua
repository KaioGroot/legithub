local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")
local TextService = game:GetService("TextService")

local LocalPlayer = Players.LocalPlayer

if _G.LegitHub then
	pcall(function() _G.LegitHub.Unload() end)
end

local VERSION = "v3.0"
local UPDATE_URL = _G.LegitHubUpdateURL or ""
local CONFIG_FILE = "legithub_config.json"
local LEGACY_CONFIG_FILE = "legithub_config.json"
CONFIG_FILE = "legithub_config_" .. tostring(game.PlaceId) .. ".json"

local Connections = {}
local Options = {}
local Flags = {}
local Keybinds = {} -- [nomeDaOpcao] = nomeDoKeyCode

local Originals = {
	Brightness = Lighting.Brightness,
	FogEnd = Lighting.FogEnd,
	FogStart = Lighting.FogStart,
	ClockTime = Lighting.ClockTime,
	GlobalShadows = Lighting.GlobalShadows,
	Gravity = workspace.Gravity,
	FOV = workspace.CurrentCamera and workspace.CurrentCamera.FieldOfView or 70,
}

local function Connect(signal, fn)
	local conn = signal:Connect(fn)
	table.insert(Connections, conn)
	return conn
end

local function Create(className, props, parent)
	local inst = Instance.new(className)
	for k, v in pairs(props) do
		inst[k] = v
	end
	inst.Parent = parent
	return inst
end

local function Tween(obj, time, props, style, direction)
	local tween = TweenService:Create(obj, TweenInfo.new(
		time,
		style or Enum.EasingStyle.Quint,
		direction or Enum.EasingDirection.Out
	), props)
	tween:Play()
	return tween
end

local function Corner(parent, radius)
	return Create("UICorner", { CornerRadius = UDim.new(0, radius or 8) }, parent)
end

local function Outline(parent, color, transparency, thickness)
	return Create("UIStroke", {
		Color = color or Color3.fromRGB(96, 104, 126),
		Transparency = transparency or 0,
		Thickness = thickness or 1,
	}, parent)
end

local Theme = {
	Background = Color3.fromRGB(23, 20, 26),
	Surface = Color3.fromRGB(32, 28, 36),
	Card = Color3.fromRGB(44, 39, 49),
	CardHover = Color3.fromRGB(58, 51, 63),
	CardActive = Color3.fromRGB(74, 65, 79),
	TrackOff = Color3.fromRGB(63, 55, 68),
	Stroke = Color3.fromRGB(255, 255, 255),
	Text = Color3.fromRGB(248, 246, 251),
	SubText = Color3.fromRGB(160, 151, 168),
	Accent = Color3.fromRGB(255, 64, 84),
	Accent2 = Color3.fromRGB(255, 138, 76),
	Success = Color3.fromRGB(80, 220, 150),
	Danger = Color3.fromRGB(255, 49, 60),
}

local GradientRegistry = {}
local AccentRegistry = {}
local TintRegistry = {}

local function AccentGradient(parent, rotation)
	local grad = Create("UIGradient", {
		Color = ColorSequence.new(Theme.Accent, Theme.Accent2),
		Rotation = rotation or 0,
	}, parent)
	table.insert(GradientRegistry, grad)
	return grad
end

local SaveScheduled = false
local function ScheduleSave()
	if not (writefile and isfile and readfile and HttpService) then return end
	if SaveScheduled then return end
	SaveScheduled = true
	task.delay(0.6, function()
		SaveScheduled = false
		pcall(function()
			local data = {}
			for name, opt in pairs(Options) do
				data[name] = opt.Get()
			end
			writefile(CONFIG_FILE, HttpService:JSONEncode({ flags = data, keys = Keybinds }))
		end)
	end)
end

local function ApplyConfigData(decoded)
	for name, value in pairs(decoded.flags or {}) do
		if Options[name] then
			Options[name].Set(value, true)
		end
	end
	if type(decoded.keys) == "table" then
		table.clear(Keybinds)
		for name, key in pairs(decoded.keys) do
			if type(key) == "string" then
				Keybinds[name] = key
			end
		end
		if RefreshKeybindUI then
			RefreshKeybindUI()
		end
		if RebuildKeymapFn then
			RebuildKeymapFn()
		end
	end
end

local function LoadConfig()
	if not (writefile and isfile and readfile) then return end
	pcall(function()
		if isfile(CONFIG_FILE) then
			ApplyConfigData(HttpService:JSONDecode(readfile(CONFIG_FILE)))
		elseif isfile(LEGACY_CONFIG_FILE) then
			ApplyConfigData(HttpService:JSONDecode(readfile(LEGACY_CONFIG_FILE)))
		end
	end)
end

-- ============ Motor de cor de destaque ============
local RebuildWpDrawings = nil
local RefreshSwatches = nil
local RefreshKeybindUI = nil
local RebuildKeymapFn = nil

local ACCENT_PRESETS = {
	{ name = "Vermelho", a = Color3.fromRGB(255, 64, 84),  b = Color3.fromRGB(255, 138, 76) },
	{ name = "Roxo",     a = Color3.fromRGB(124, 92, 255), b = Color3.fromRGB(0, 190, 255) },
	{ name = "Azul",     a = Color3.fromRGB(64, 140, 255), b = Color3.fromRGB(0, 225, 255) },
	{ name = "Verde",    a = Color3.fromRGB(52, 199, 123), b = Color3.fromRGB(160, 255, 120) },
	{ name = "Ouro",     a = Color3.fromRGB(255, 170, 40), b = Color3.fromRGB(255, 220, 90) },
	{ name = "Rosa",     a = Color3.fromRGB(255, 80, 170), b = Color3.fromRGB(255, 150, 210) },
}
local CurrentAccentName = "Vermelho"

local function ApplyAccentPair(a, b)
	Theme.Accent = a
	Theme.Accent2 = b
	for _, grad in ipairs(GradientRegistry) do
		grad.Color = ColorSequence.new(a, b)
	end
	for _, reg in ipairs(AccentRegistry) do
		reg.inst[reg.prop] = (reg.key == "Accent2") and b or a
	end
	for _, tint in ipairs(TintRegistry) do
		tint.bg.BackgroundColor3 = a:Lerp(Color3.new(0, 0, 0), 0.52)
		tint.grad.Color = ColorSequence.new(
			a:Lerp(Color3.new(1, 1, 1), 0.87),
			a:Lerp(Color3.new(1, 1, 1), 0.58)
		)
	end
	if RebuildWpDrawings then
		RebuildWpDrawings()
	end
	ScheduleSave()
end

local function ApplyAccentPreset(name)
	for _, preset in ipairs(ACCENT_PRESETS) do
		if preset.name == name then
			CurrentAccentName = name
			ApplyAccentPair(preset.a, preset.b)
			if RefreshSwatches then
				RefreshSwatches()
			end
			return true
		end
	end
	return false
end
-- ============ fim motor de cor ============

local screenGui = Create("ScreenGui", {
	Name = "LegitHub",
	ResetOnSpawn = false,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	IgnoreGuiInset = true,
}, nil)

local guiParentOk = pcall(function()
	screenGui.Parent = game:GetService("CoreGui")
end)
if not guiParentOk then
	screenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
end

local blur = Create("BlurEffect", { Name = "LegitHubBlur", Size = 0 }, Lighting)

local root = Create("CanvasGroup", {
	Name = "Root",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(660, 460),
	BackgroundColor3 = Theme.Background,
	BorderSizePixel = 0,
	GroupTransparency = 1,
	Active = true,
}, screenGui)

local rootShadow = Create("ImageLabel", {
	Name = "RootShadow",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.new(1, 140, 1, 140),
	BackgroundTransparency = 1,
	Image = "rbxassetid://6014261993",
	ImageColor3 = Color3.new(0, 0, 0),
	ImageTransparency = 0.32,
	ScaleType = Enum.ScaleType.Slice,
	SliceCenter = Rect.new(49, 49, 450, 450),
	ZIndex = 0,
}, root)

Corner(root, 16)
local rootStroke = Outline(root, Theme.Stroke, 0.25, 1)
	Create("UIGradient", {
		Color = ColorSequence.new(Color3.fromRGB(242, 230, 234), Color3.fromRGB(168, 152, 160)),
		Rotation = 115,
	}, rootStroke)

	Create("UIGradient", {
		Color = ColorSequence.new(Color3.fromRGB(236, 226, 232), Color3.fromRGB(255, 252, 250)),
		Rotation = 90,
	}, root)

local function AuroraWash(name, pos, size, color, rot)
	local wash = Create("Frame", {
		Name = name,
		Position = pos,
		Size = size,
		BackgroundColor3 = color,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Rotation = rot,
		ZIndex = 0,
	}, root)
	Create("UIGradient", {
		Color = ColorSequence.new(color, color),
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.5, 0.8),
			NumberSequenceKeypoint.new(1, 1),
		}),
		Rotation = 0,
	}, wash)
	return wash
end

local auroraA = AuroraWash("AuroraA", UDim2.fromOffset(-90, -70), UDim2.fromOffset(430, 270), Theme.Accent, 25)
local auroraB = AuroraWash("AuroraB", UDim2.new(1, -120, 1, -200), UDim2.fromOffset(380, 240), Theme.Accent2, -30)

task.spawn(function()
	while screenGui.Parent do
		Tween(auroraA, 7, { Rotation = -20 }, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
		Tween(auroraB, 9, { Rotation = 30 }, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
		task.wait(7)
		Tween(auroraA, 7, { Rotation = 25 }, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
		Tween(auroraB, 9, { Rotation = -30 }, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
		task.wait(7)
	end
end)

local uiScale = Create("UIScale", { Scale = 0.88 }, root)

local headerBar = Create("Frame", {
	Name = "HeaderBar",
	Size = UDim2.new(1, 0, 0, 58),
	BackgroundTransparency = 1,
	Active = true,
}, root)

local headerDivider = Create("Frame", {
	Name = "HeaderDivider",
	Position = UDim2.new(0, 0, 1, -1),
	Size = UDim2.new(1, 0, 0, 1),
	BackgroundColor3 = Theme.Stroke,
	BackgroundTransparency = 0.45,
	BorderSizePixel = 0,
}, headerBar)
Create("UIGradient", {
	Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.18, 0),
		NumberSequenceKeypoint.new(0.82, 0),
		NumberSequenceKeypoint.new(1, 1),
	}),
	Rotation = 0,
}, headerDivider)

local logoGlow = Create("Frame", {
	Name = "LogoGlow",
	AnchorPoint = Vector2.new(0, 0.5),
	Position = UDim2.new(0, 15, 0.5, 0),
	Size = UDim2.fromOffset(36, 36),
	BackgroundColor3 = Theme.Accent,
	BackgroundTransparency = 0.86,
	BorderSizePixel = 0,
}, headerBar)
Corner(logoGlow, 12)
AccentGradient(logoGlow, 135)
table.insert(AccentRegistry, { inst = logoGlow, prop = "BackgroundColor3", key = "Accent" })

local logoMark = Create("CanvasGroup", {
	Name = "LogoMark",
	AnchorPoint = Vector2.new(0, 0.5),
	Position = UDim2.new(0, 19, 0.5, 0),
	Size = UDim2.fromOffset(28, 28),
	BackgroundColor3 = Theme.Accent,
	BorderSizePixel = 0,
}, headerBar)
	Corner(logoMark, 9)
	table.insert(AccentRegistry, { inst = logoMark, prop = "BackgroundColor3", key = "Accent" })
	local logoGradient = AccentGradient(logoMark, 135)

	task.spawn(function()
		while screenGui.Parent do
			Tween(logoGradient, 5, { Rotation = 225 }, Enum.EasingStyle.Linear)
			task.wait(5)
			Tween(logoGradient, 5, { Rotation = 135 }, Enum.EasingStyle.Linear)
			task.wait(5)
		end
	end)

Create("TextLabel", {
	BackgroundTransparency = 1,
	Size = UDim2.fromScale(1, 1),
	Font = Enum.Font.GothamBlack,
	Text = "L",
	TextColor3 = Color3.new(1, 1, 1),
	TextSize = 16,
}, logoMark)

local titleGradient = Create("TextLabel", {
	Name = "Title",
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(62, 11),
	Size = UDim2.fromOffset(180, 20),
	Font = Enum.Font.GothamBold,
	Text = "LegitHub",
	TextColor3 = Theme.Text,
	TextSize = 17,
	TextXAlignment = Enum.TextXAlignment.Left,
}, headerBar)

Create("UIGradient", {
	Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(210, 196, 202)),
	Rotation = 90,
}, titleGradient)

Create("TextLabel", {
	Name = "Tagline",
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(62, 32),
	Size = UDim2.fromOffset(200, 12),
	Font = Enum.Font.GothamBold,
	Text = "UNIVERSAL TOOLKIT",
	TextColor3 = Theme.SubText,
	TextSize = 9,
	TextXAlignment = Enum.TextXAlignment.Left,
}, headerBar)

local versionPill = Create("Frame", {
	Name = "VersionPill",
	AnchorPoint = Vector2.new(0, 0.5),
	Position = UDim2.new(0, 168, 0.5, 0),
	Size = UDim2.fromOffset(54, 20),
	BackgroundColor3 = Theme.Card,
	BorderSizePixel = 0,
}, headerBar)
Corner(versionPill, 10)

	Create("TextLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Font = Enum.Font.GothamBold,
		Text = VERSION,
		TextColor3 = Theme.Accent2,
		TextSize = 10,
	}, versionPill)
	for _, child in ipairs(versionPill:GetChildren()) do
		if child:IsA("TextLabel") then
			table.insert(AccentRegistry, { inst = child, prop = "TextColor3", key = "Accent2" })
		end
	end

local closeBtn = Create("TextButton", {
	Name = "Close",
	AnchorPoint = Vector2.new(1, 0.5),
	Position = UDim2.new(1, -14, 0.5, 0),
	Size = UDim2.fromOffset(30, 30),
	BackgroundColor3 = Theme.Card,
	Font = Enum.Font.GothamBold,
	Text = "X",
	TextColor3 = Theme.Danger,
	TextSize = 12,
	AutoButtonColor = false,
}, headerBar)
Corner(closeBtn, 10)

local minimizeBtn = Create("TextButton", {
	Name = "Minimize",
	AnchorPoint = Vector2.new(1, 0.5),
	Position = UDim2.new(1, -52, 0.5, 0),
	Size = UDim2.fromOffset(30, 30),
	BackgroundColor3 = Theme.Card,
	Font = Enum.Font.GothamBold,
	Text = "-",
	TextColor3 = Theme.SubText,
	TextSize = 16,
	AutoButtonColor = false,
}, headerBar)
Corner(minimizeBtn, 10)

local statusDot = Create("Frame", {
	Name = "StatusDot",
	AnchorPoint = Vector2.new(1, 0.5),
	Position = UDim2.new(1, -104, 0.5, 0),
	Size = UDim2.fromOffset(8, 8),
	BackgroundColor3 = Theme.Success,
	BorderSizePixel = 0,
}, headerBar)
Corner(statusDot, 4)

Create("TextLabel", {
	Name = "StatusLabel",
	AnchorPoint = Vector2.new(1, 0.5),
	Position = UDim2.new(1, -118, 0.5, 0),
	Size = UDim2.fromOffset(70, 20),
	BackgroundTransparency = 1,
	Font = Enum.Font.GothamMedium,
	Text = "online",
	TextColor3 = Theme.SubText,
	TextSize = 10,
	TextXAlignment = Enum.TextXAlignment.Right,
}, headerBar)

task.spawn(function()
	while screenGui.Parent do
		Tween(statusDot, 1.4, { BackgroundTransparency = 0.65 }, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
		task.wait(1.4)
		Tween(statusDot, 1.4, { BackgroundTransparency = 0 }, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
		task.wait(1.4)
	end
end)

local searchBoxHolder = Create("Frame", {
	Name = "SearchHolder",
	AnchorPoint = Vector2.new(0, 0.5),
	Position = UDim2.new(1, -330, 0.5, 0),
	Size = UDim2.fromOffset(190, 28),
	BackgroundColor3 = Theme.Card,
	BorderSizePixel = 0,
}, headerBar)
Corner(searchBoxHolder, 8)
local searchStroke = Outline(searchBoxHolder, Theme.Stroke, 0.55)

Create("TextLabel", {
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(9, 0),
	Size = UDim2.fromOffset(18, 28),
	Font = Enum.Font.GothamBold,
	Text = "🔍",
	TextSize = 11,
	TextColor3 = Theme.SubText,
}, searchBoxHolder)

local searchBox = Create("TextBox", {
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(30, 0),
	Size = UDim2.new(1, -38, 1, 0),
	Font = Enum.Font.GothamMedium,
	Text = "",
	PlaceholderText = "Buscar função...",
	PlaceholderColor3 = Theme.SubText,
	TextColor3 = Theme.Text,
	TextSize = 12,
	TextXAlignment = Enum.TextXAlignment.Left,
	ClearTextOnFocus = false,
}, searchBoxHolder)

searchBox.Focused:Connect(function()
	Tween(searchStroke, 0.2, { Color = Theme.Accent, Transparency = 0.2 })
end)
searchBox.FocusLost:Connect(function()
	Tween(searchStroke, 0.3, { Color = Theme.Stroke, Transparency = 0.55 })
end)

-- Bolha flutuante (modo minimizado)
local bubble = Create("TextButton", {
	Name = "HubBubble",
	Position = UDim2.new(0, 46, 0.5, -26),
	Size = UDim2.fromOffset(52, 52),
	BackgroundColor3 = Theme.Accent,
	Text = "L",
	Font = Enum.Font.GothamBlack,
	TextColor3 = Color3.new(1, 1, 1),
	TextSize = 22,
	AutoButtonColor = false,
	Visible = false,
}, screenGui)
Corner(bubble, 26)
table.insert(AccentRegistry, { inst = bubble, prop = "BackgroundColor3", key = "Accent" })
AccentGradient(bubble, 135)

local bubbleShadow = Create("ImageLabel", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.new(1, 46, 1, 46),
	BackgroundTransparency = 1,
	Image = "rbxassetid://6014261993",
	ImageColor3 = Color3.new(0, 0, 0),
	ImageTransparency = 0.5,
	ScaleType = Enum.ScaleType.Slice,
	SliceCenter = Rect.new(49, 49, 450, 450),
	ZIndex = 0,
}, bubble)

task.spawn(function()
	while screenGui.Parent do
		if bubble.Visible then
			Tween(bubble, 1.6, { Size = UDim2.fromOffset(56, 56) }, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
			task.wait(1.6)
			Tween(bubble, 1.6, { Size = UDim2.fromOffset(52, 52) }, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
			task.wait(1.6)
		else
			task.wait(1)
		end
	end
end)

local body = Create("Frame", {
	Name = "Body",
	Position = UDim2.fromOffset(0, 58),
	Size = UDim2.new(1, 0, 1, -58 - 28),
	BackgroundTransparency = 1,
}, root)

local sidebar = Create("Frame", {
	Name = "Sidebar",
	Size = UDim2.new(0, 172, 1, 0),
	BackgroundColor3 = Theme.Surface,
	BorderSizePixel = 0,
}, body)

Outline(sidebar, Theme.Stroke, 0.5, 1)

local tabLayout = Create("UIListLayout", {
	Padding = UDim.new(0, 4),
	SortOrder = Enum.SortOrder.LayoutOrder,
}, sidebar)

Create("UIPadding", {
	PaddingTop = UDim.new(0, 12),
	PaddingLeft = UDim.new(0, 8),
	PaddingRight = UDim.new(0, 8),
	PaddingBottom = UDim.new(0, 12),
}, sidebar)

Create("Frame", {
	Name = "SidebarDivider",
	Position = UDim2.fromOffset(171, 0),
	Size = UDim2.new(0, 1, 1, 0),
	BackgroundColor3 = Theme.Stroke,
	BackgroundTransparency = 0.45,
	BorderSizePixel = 0,
}, body)

local footer = Create("Frame", {
	Name = "Footer",
	AnchorPoint = Vector2.new(0, 1),
	Position = UDim2.new(0, 0, 1, 0),
	Size = UDim2.new(1, 0, 0, 28),
	BackgroundTransparency = 1,
}, root)

local fpsLabel = Create("TextLabel", {
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(16, 0),
	Size = UDim2.new(0, 220, 1, 0),
	Font = Enum.Font.GothamMedium,
	Text = "FPS: --   ·   Ping: --ms",
	TextColor3 = Theme.SubText,
	TextSize = 11,
	TextXAlignment = Enum.TextXAlignment.Left,
}, footer)

Create("TextLabel", {
	BackgroundTransparency = 1,
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -16, 0, 0),
	Size = UDim2.new(0, 220, 1, 0),
	Font = Enum.Font.GothamMedium,
	Text = "RightShift para abrir/fechar",
	TextColor3 = Theme.SubText,
	TextSize = 11,
	TextXAlignment = Enum.TextXAlignment.Right,
}, footer)

local pagesFolder = Create("Frame", {
	Name = "Pages",
	Position = UDim2.fromOffset(172, 0),
	Size = UDim2.new(1, -172, 1, 0),
	BackgroundTransparency = 1,
	ClipsDescendants = true,
}, body)

local Pages = {}
local TabButtons = {}
local CurrentTab = nil

local function Ripple(button, inputPos)
	local relX = inputPos.X - button.AbsolutePosition.X
	local relY = inputPos.Y - button.AbsolutePosition.Y
	local circle = Create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(relX, relY),
		Size = UDim2.fromOffset(0, 0),
		BackgroundTransparency = 0.55,
		BackgroundColor3 = Theme.Text,
		BorderSizePixel = 0,
		ZIndex = button.ZIndex + 2,
	}, button)
	Corner(circle, 999)
	local target = math.max(button.AbsoluteSize.X, button.AbsoluteSize.Y) * 2.2
	Tween(circle, 0.45, { Size = UDim2.fromOffset(target, target), BackgroundTransparency = 1 })
	task.delay(0.5, function()
		circle:Destroy()
	end)
end

local TAB_ICONS = {
	Player = "🏃",
	Visuals = "👁",
	Mundo = "🌍",
	Misc = "🛠",
}

local function MakePage(name, layoutOrder)
	local page = Create("CanvasGroup", {
		Name = name,
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Visible = false,
		GroupTransparency = 1,
		LayoutOrder = layoutOrder,
	}, pagesFolder)

	local scroll = Create("ScrollingFrame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 3,
		ScrollBarImageColor3 = Theme.Accent,
		ScrollBarImageTransparency = 0.55,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
	}, page)
	table.insert(AccentRegistry, { inst = scroll, prop = "ScrollBarImageColor3", key = "Accent" })

	Create("UIPadding", {
		PaddingTop = UDim.new(0, 12),
		PaddingLeft = UDim.new(0, 14),
		PaddingRight = UDim.new(0, 14),
		PaddingBottom = UDim.new(0, 12),
	}, scroll)

	Create("UIListLayout", {
		Padding = UDim.new(0, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, scroll)

	local tabBtn = Create("TextButton", {
		Name = name,
		Size = UDim2.new(1, 0, 0, 34),
		BackgroundColor3 = Theme.Card,
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamMedium,
		Text = "",
		TextColor3 = Theme.SubText,
		TextSize = 13,
		AutoButtonColor = false,
		LayoutOrder = layoutOrder,
		ClipsDescendants = true,
	}, sidebar)
	Corner(tabBtn, 9)

	local indicator = Create("Frame", {
		Name = "Indicator",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 0, 0.5, 0),
		Size = UDim2.new(0, 3, 0, 0),
		BackgroundColor3 = Theme.Accent,
		BorderSizePixel = 0,
		ZIndex = 2,
	}, tabBtn)
	Corner(indicator, 2)
	AccentGradient(indicator, 90)
	table.insert(AccentRegistry, { inst = indicator, prop = "BackgroundColor3", key = "Accent" })

	local activeGlow = Create("Frame", {
		Name = "ActiveGlow",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(126, 44, 58),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 0,
	}, tabBtn)
	Corner(activeGlow, 9)
	local glowGrad = Create("UIGradient", {
		Color = ColorSequence.new(Color3.fromRGB(252, 226, 233), Color3.fromRGB(206, 156, 168)),
		Rotation = 115,
	}, activeGlow)
	table.insert(TintRegistry, { bg = activeGlow, grad = glowGrad })

	local tabIcon = Create("TextLabel", {
		Name = "TabIcon",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(13, 0),
		Size = UDim2.fromOffset(22, 34),
		Font = Enum.Font.GothamBold,
		Text = TAB_ICONS[name] or "◆",
		TextSize = 15,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextYAlignment = Enum.TextYAlignment.Center,
		ZIndex = 2,
	}, tabBtn)
	local iconScale = Create("UIScale", { Scale = 1 }, tabIcon)

	Create("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(42, 0),
		Size = UDim2.new(1, -50, 1, 0),
		Font = Enum.Font.GothamBold,
		Text = name,
		TextColor3 = Theme.SubText,
		TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, tabBtn)

	local orderCounter = 0
	local pageApi = { Page = page, Scroll = scroll, Button = tabBtn, Indicator = indicator, Glow = activeGlow, IconScale = iconScale }

	pageApi.Add = function(orderFn)
		orderCounter += 1
		return orderFn(orderCounter)
	end

	Pages[name] = pageApi
	TabButtons[name] = tabBtn

	tabBtn.MouseEnter:Connect(function()
		if CurrentTab ~= name then
			Tween(tabBtn, 0.15, { BackgroundTransparency = 0.5 })
		end
	end)
	tabBtn.MouseLeave:Connect(function()
		if CurrentTab ~= name then
			Tween(tabBtn, 0.15, { BackgroundTransparency = 1 })
		end
	end)

	return pageApi
end

local function SelectTab(name)
	if CurrentTab == name then return end
	local previous = CurrentTab
	CurrentTab = name
	local newPage = Pages[name]

	for tabName, api in pairs(Pages) do
		local active = tabName == name
		Tween(api.Button, 0.2, {
			BackgroundTransparency = active and 0 or 1,
			TextColor3 = active and Theme.Text or Theme.SubText,
		})
		Tween(api.Glow, 0.25, {
			BackgroundTransparency = active and 0.35 or 1,
		})
		Tween(api.Indicator, 0.25, {
			Size = active and UDim2.new(0, 3, 0, 16) or UDim2.new(0, 3, 0, 0),
		}, Enum.EasingStyle.Back)
		if active then
			task.spawn(function()
				Tween(api.IconScale, 0.16, { Scale = 1.3 }, Enum.EasingStyle.Quart)
				task.wait(0.16)
				Tween(api.IconScale, 0.26, { Scale = 1 }, Enum.EasingStyle.Back)
			end)
		end
	end

	if previous and Pages[previous] then
		local oldPage = Pages[previous].Page
		local oldName = previous
		Tween(oldPage, 0.12, { GroupTransparency = 1 }).Completed:Once(function()
			if CurrentTab ~= oldName then
				oldPage.Visible = false
			end
		end)
	end

	newPage.Page.Visible = true
	newPage.Page.GroupTransparency = 1
	newPage.Scroll.Position = UDim2.fromOffset(0, 26)
	task.defer(function()
		Tween(newPage.Page, 0.22, { GroupTransparency = 0 })
		Tween(newPage.Scroll, 0.34, { Position = UDim2.fromScale(0, 0) }, Enum.EasingStyle.Back)
	end)
end

for i, tabName in ipairs({ "Player", "Visuals", "Mundo", "Misc" }) do
	MakePage(tabName, i)
end

-- ============ Busca de configuracoes ============
do
local searchPanel = Create("Frame", {
	Name = "SearchResults",
	Position = UDim2.new(0, 12, 0, 62),
	Size = UDim2.new(0, 330, 0, 0),
	BackgroundColor3 = Theme.Surface,
	BorderSizePixel = 0,
	Visible = false,
	ZIndex = 40,
}, root)
Corner(searchPanel, 10)
Outline(searchPanel, Theme.Stroke, 0.4)

local function FlashWidget(widget)
	if not widget then return end
	local stroke = widget:FindFirstChildOfClass("UIStroke")
	if not stroke then return end
	local origColor = stroke.Color
	local origT = stroke.Transparency
	Tween(stroke, 0.18, { Color = Theme.Accent, Transparency = 0 })
	task.delay(1.1, function()
		if stroke.Parent then
			Tween(stroke, 0.5, { Color = origColor, Transparency = origT })
		end
	end)
end

local currentResults = {}

local function HideSearchPanel()
	searchPanel.Visible = false
	table.clear(currentResults)
end

local function PickSearchResult(opt)
	HideSearchPanel()
	searchBox.Text = ""
	SelectTab(opt.PageName)
	task.delay(0.25, function()
		FlashWidget(opt.Widget)
	end)
end

local function BuildSearchResultRow(opt, order)
	local rowBtn = Create("TextButton", {
		Size = UDim2.new(1, -12, 0, 30),
		BackgroundColor3 = Theme.Card,
		BorderSizePixel = 0,
		Text = "",
		AutoButtonColor = false,
		ZIndex = 41,
		LayoutOrder = order,
	}, searchPanel)
	Corner(rowBtn, 7)

	Create("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(10, 0),
		Size = UDim2.new(1, -110, 1, 0),
		Font = Enum.Font.GothamMedium,
		Text = tostring(opt.Label),
		TextColor3 = Theme.Text,
		TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		ZIndex = 42,
	}, rowBtn)

	local tabBadge = Create("TextLabel", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -8, 0.5, 0),
		Size = UDim2.fromOffset(86, 20),
		BackgroundColor3 = Theme.Background,
		Font = Enum.Font.GothamBold,
		Text = "Aba " .. tostring(opt.PageName),
		TextColor3 = Theme.SubText,
		TextSize = 10,
		ZIndex = 42,
	}, rowBtn)
	Corner(tabBadge, 6)

	rowBtn.MouseEnter:Connect(function()
		Tween(rowBtn, 0.12, { BackgroundColor3 = Theme.CardHover })
	end)
	rowBtn.MouseLeave:Connect(function()
		Tween(rowBtn, 0.15, { BackgroundColor3 = Theme.Card })
	end)
	rowBtn.MouseButton1Click:Connect(function()
		PickSearchResult(opt)
	end)
end

searchBox:GetPropertyChangedSignal("Text"):Connect(function()
	for _, child in ipairs(searchPanel:GetChildren()) do
		if child:IsA("TextButton") or child:IsA("TextLabel") or child:IsA("UIListLayout") then
			child:Destroy()
		end
	end
	local query = string.lower(searchBox.Text)
	if query == "" then
		HideSearchPanel()
		return
	end

	table.clear(currentResults)
	for _, opt in pairs(Options) do
		local hay = string.lower(tostring(opt.Label) .. " " .. tostring(opt.PageName))
		if string.find(hay, query, 1, true) then
			table.insert(currentResults, opt)
		end
	end
	table.sort(currentResults, function(a, b)
		return tostring(a.Label) < tostring(b.Label)
	end)

	Create("UIListLayout", {
		Padding = UDim.new(0, 5),
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Top,
	}, searchPanel)

	if #currentResults == 0 then
		Create("TextLabel", {
			Size = UDim2.new(1, -12, 0, 28),
			BackgroundTransparency = 1,
			Font = Enum.Font.GothamMedium,
			Text = "Nada encontrado para \"" .. searchBox.Text .. "\"",
			TextColor3 = Theme.SubText,
			TextSize = 12,
			ZIndex = 42,
			LayoutOrder = 1,
		}, searchPanel)
		searchPanel.Size = UDim2.new(0, 330, 0, 40)
	else
		local shown = math.min(#currentResults, 10)
		for idx = 1, shown do
			BuildSearchResultRow(currentResults[idx], idx)
		end
		local extra = #currentResults > shown and ("  +" .. (#currentResults - shown) .. " mais... refine a busca") or ""
		if extra ~= "" then
			Create("TextLabel", {
				Size = UDim2.new(1, -12, 0, 20),
				BackgroundTransparency = 1,
				Font = Enum.Font.Gotham,
				Text = extra,
				TextColor3 = Theme.SubText,
				TextSize = 11,
				ZIndex = 42,
				LayoutOrder = shown + 1,
			}, searchPanel)
			searchPanel.Size = UDim2.new(0, 330, 0, shown * 35 + 32)
		else
			searchPanel.Size = UDim2.new(0, 330, 0, shown * 35 + 12)
		end
	end
	searchPanel.Visible = true
end)

searchBox.FocusLost:Connect(function(enterPressed)
	if enterPressed and currentResults[1] then
		PickSearchResult(currentResults[1])
	end
end)
end

local function SectionLabel(page, text)
	local container = Create("Frame", {
		Size = UDim2.new(1, 0, 0, 24),
		BackgroundTransparency = 1,
		LayoutOrder = page.Add(function(o) return o end),
	}, page.Scroll)

	local tick = Create("Frame", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 0, 0.5, 0),
		Size = UDim2.fromOffset(3, 13),
		BackgroundColor3 = Theme.Accent,
		BorderSizePixel = 0,
	}, container)
	Corner(tick, 2)
	AccentGradient(tick, 90)
	table.insert(AccentRegistry, { inst = tick, prop = "BackgroundColor3", key = "Accent" })

	local upperText = string.upper(text)
	Create("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(11, 0),
		Size = UDim2.new(1, -11, 1, 0),
		Font = Enum.Font.GothamBold,
		Text = upperText,
		TextColor3 = Theme.SubText,
		TextSize = 10,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, container)

	local okW, measured = pcall(function()
		return TextService:GetTextSize(upperText, 10, Enum.Font.GothamBold, Vector2.new(10000, 10000))
	end)
	if okW and measured then
		local hairX = 11 + measured.X + 12
		Create("Frame", {
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, hairX, 0.5, 0),
			Size = UDim2.new(1, -(hairX + 2), 0, 1),
			BackgroundColor3 = Theme.Stroke,
			BackgroundTransparency = 0.86,
			BorderSizePixel = 0,
		}, container)
	end
	return container
end

local function Paragraph(page, title, body)
	local holder = Create("Frame", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Theme.Surface,
		BorderSizePixel = 0,
		LayoutOrder = page.Add(function(o) return o end),
	}, page.Scroll)
	Corner(holder, 10)
	Outline(holder, Theme.Stroke, 0.55)

	Create("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(14, 8),
		Size = UDim2.new(1, -28, 0, 18),
		Font = Enum.Font.GothamBold,
		Text = title,
		TextColor3 = Theme.Text,
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextWrapped = true,
	}, holder)

	Create("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(14, 28),
		Size = UDim2.new(1, -28, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Font = Enum.Font.Gotham,
		Text = body,
		TextColor3 = Theme.SubText,
		TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextWrapped = true,
	}, holder)

	Create("UIPadding", { PaddingBottom = UDim.new(0, 10) }, holder)
	return holder
end

local function PageNameOf(page)
	for name, p in pairs(Pages) do
		if p == page then
			return name
		end
	end
	return "?"
end

local function RegisterOption(name, option, page, label, widget)
	Options[name] = option
	option.Label = label or name
	option.PageName = PageNameOf(page)
	option.Widget = widget
end

local BTN_ICONS = {
	{ "Teleportar", "⚡" },
	{ "Reentrar", "🔄" },
	{ "Copiar JobId", "🆔" },
	{ "Copiar ferramentas", "🧰" },
	{ "Salvar configura", "💾" },
	{ "Descarregar", "⏏" },
	{ "Verificar agora", "🔎" },
	{ "Marcar posicao", "📌" },
	{ "Voltar a posicao", "🧭" },
	{ "Marcar jogador como ADM", "🚩" },
	{ "Remover marcacao", "🚫" },
	{ "Exportar perfil", "📤" },
	{ "Importar perfil", "📥" },
}

local function BtnIcon(text)
	for _, pair in ipairs(BTN_ICONS) do
		if string.find(text, pair[1], 1, true) then
			return pair[2] .. " "
		end
	end
	return ""
end

local function AddButton(page, text, color, callback)
	local btn = Create("TextButton", {
		Size = UDim2.new(1, 0, 0, 40),
		BackgroundColor3 = Theme.Card,
		BorderSizePixel = 0,
		Font = Enum.Font.GothamMedium,
		Text = "   " .. BtnIcon(text) .. text,
		TextColor3 = color or Theme.Text,
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Left,
		AutoButtonColor = false,
		ClipsDescendants = true,
		LayoutOrder = page.Add(function(o) return o end),
	}, page.Scroll)
	Corner(btn, 10)
	local btnScale = Create("UIScale", { Scale = 1 }, btn)
	local btnStroke = Outline(btn, Theme.Stroke, 0.72)

	local sheen = Create("Frame", {
		Size = UDim2.new(1, 0, 0, 19),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		ZIndex = 0,
	}, btn)
	Corner(sheen, 9)
	Create("UIGradient", {
		Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.new(1, 1, 1)),
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.94),
			NumberSequenceKeypoint.new(1, 1),
		}),
		Rotation = 90,
	}, sheen)

	local chevChip = Create("Frame", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -9, 0.5, 0),
		Size = UDim2.fromOffset(22, 22),
		BackgroundColor3 = Theme.Background,
		BackgroundTransparency = 0.35,
		BorderSizePixel = 0,
		ZIndex = 1,
	}, btn)
	Corner(chevChip, 11)

	local chevron = Create("TextLabel", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(12, 16),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		Text = ">",
		TextColor3 = Theme.SubText,
		TextSize = 11,
		ZIndex = 2,
	}, chevChip)

	btn.MouseEnter:Connect(function()
		Tween(btn, 0.15, { BackgroundColor3 = Theme.CardHover, Size = UDim2.new(1, 0, 0, 43) })
		Tween(btnStroke, 0.15, { Transparency = 0.45 })
		Tween(chevChip, 0.18, { Position = UDim2.new(1, -6, 0.5, 0) }, Enum.EasingStyle.Quart)
		Tween(chevron, 0.18, { TextColor3 = Theme.Text }, Enum.EasingStyle.Quart)
	end)
	btn.MouseLeave:Connect(function()
		Tween(btn, 0.18, { BackgroundColor3 = Theme.Card, Size = UDim2.new(1, 0, 0, 40) })
		Tween(btnStroke, 0.15, { Transparency = 0.72 })
		Tween(chevChip, 0.18, { Position = UDim2.new(1, -9, 0.5, 0) }, Enum.EasingStyle.Quart)
		Tween(chevron, 0.18, { TextColor3 = Theme.SubText }, Enum.EasingStyle.Quart)
	end)
	btn.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			Ripple(btn, input.Position)
			Tween(btnScale, 0.07, { Scale = 0.975 }, Enum.EasingStyle.Quart)
		end
	end)
	btn.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			Tween(btnScale, 0.2, { Scale = 1 }, Enum.EasingStyle.Back)
		end
	end)
	btn.MouseButton1Click:Connect(function()
		task.spawn(callback)
	end)
	return btn
end

local function AddToggle(page, name, text, default, callback)
	local state = default and true or false

	local btn = Create("TextButton", {
		Size = UDim2.new(1, 0, 0, 42),
		BackgroundColor3 = Theme.Card,
		BorderSizePixel = 0,
		Text = "",
		AutoButtonColor = false,
		ClipsDescendants = true,
		LayoutOrder = page.Add(function(o) return o end),
	}, page.Scroll)
	Corner(btn, 10)
	local btnScale = Create("UIScale", { Scale = 1 }, btn)
	local rowStroke = Outline(btn, Theme.Stroke, 0.6)

	Create("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(16, 0),
		Size = UDim2.new(1, -84, 1, 0),
		Font = Enum.Font.GothamMedium,
		Text = text,
		TextColor3 = Theme.Text,
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, btn)

	local switchBg = Create("Frame", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -12, 0.5, 0),
		Size = UDim2.fromOffset(42, 24),
		BackgroundColor3 = Theme.TrackOff,
		BorderSizePixel = 0,
	}, btn)
	Corner(switchBg, 12)
	local switchRing = Outline(switchBg, Theme.Stroke, 0.55)

	local dot = Create("Frame", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 3, 0.5, 0),
		Size = UDim2.fromOffset(18, 18),
		BackgroundColor3 = Theme.SubText,
		BorderSizePixel = 0,
	}, switchBg)
	Corner(dot, 9)
	Outline(dot, Color3.fromRGB(9, 10, 15), 0.4, 1)

	local gradient = AccentGradient(switchBg, 0)
	gradient.Enabled = false

	local function Render(instant)
		gradient.Enabled = state
		switchBg.BackgroundColor3 = state and Theme.Accent or Theme.TrackOff
		Tween(rowStroke, 0.22, {
			Color = state and Theme.Accent or Theme.Stroke,
			Transparency = state and 0.4 or 0.6,
		})
		Tween(switchRing, 0.22, { Transparency = state and 0.2 or 0.55 })
		local goal = { Position = state and UDim2.new(1, -21, 0.5, 0) or UDim2.new(0, 3, 0.5, 0) }
		if instant then
			dot.Position = goal.Position
			dot.BackgroundColor3 = state and Color3.new(1, 1, 1) or Theme.SubText
		else
			dot.BackgroundColor3 = state and Color3.new(1, 1, 1) or Theme.SubText
			dot.Size = UDim2.fromOffset(21, 21)
			Tween(dot, 0.24, goal, Enum.EasingStyle.Back)
			task.delay(0.13, function()
				if dot.Parent then
					Tween(dot, 0.18, { Size = UDim2.fromOffset(18, 18) }, Enum.EasingStyle.Quart)
				end
			end)
		end
	end

	btn.MouseEnter:Connect(function()
		Tween(btn, 0.15, { BackgroundColor3 = Theme.CardHover, Size = UDim2.new(1, 0, 0, 45) })
	end)
	btn.MouseLeave:Connect(function()
		Tween(btn, 0.18, { BackgroundColor3 = Theme.Card, Size = UDim2.new(1, 0, 0, 42) })
	end)

	btn.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			Ripple(btn, input.Position)
			Tween(btnScale, 0.07, { Scale = 0.975 }, Enum.EasingStyle.Quart)
		end
	end)
	btn.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			Tween(btnScale, 0.2, { Scale = 1 }, Enum.EasingStyle.Back)
		end
	end)
	btn.MouseButton1Click:Connect(function()
		state = not state
		Render(false)
		task.spawn(callback, state)
		ScheduleSave()
	end)

	if state then Render(true) end

	local option = {
		Type = "Toggle",
		Set = function(value, silent)
			state = value and true or false
			Render(true)
			task.spawn(callback, state)
			if not silent then ScheduleSave() end
		end,
		Get = function() return state end,
	}
	RegisterOption(name, option, page, text, btn)
	return option
end

local function AddSlider(page, name, text, min, max, default, callback, suffix)
	local suffixStr = suffix or ""
	local value = default

	local holder = Create("Frame", {
		Size = UDim2.new(1, 0, 0, 62),
		BackgroundColor3 = Theme.Card,
		BorderSizePixel = 0,
		LayoutOrder = page.Add(function(o) return o end),
	}, page.Scroll)
	Corner(holder, 10)
	Outline(holder, Theme.Stroke, 0.6)

	local label = Create("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(14, 6),
		Size = UDim2.new(1, -28, 0, 18),
		Font = Enum.Font.GothamMedium,
		Text = text,
		TextColor3 = Theme.Text,
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, holder)

	local valuePill = Create("TextLabel", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -14, 0, 7),
		Size = UDim2.fromOffset(68, 20),
		BackgroundColor3 = Theme.Background,
		Font = Enum.Font.GothamBold,
		Text = tostring(math.floor(value + 0.5)) .. suffixStr,
		TextColor3 = Theme.Text,
		TextSize = 11,
		BorderSizePixel = 0,
	}, holder)
	Corner(valuePill, 6)
	Outline(valuePill, Theme.Stroke, 0.8)

	local track = Create("Frame", {
		Position = UDim2.new(0, 14, 0, 37),
		Size = UDim2.new(1, -28, 0, 8),
		BackgroundColor3 = Theme.Background,
		BorderSizePixel = 0,
	}, holder)
	Corner(track, 4)
	Outline(track, Color3.fromRGB(0, 0, 0), 0.62)

	local fill = Create("Frame", {
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = Theme.Accent,
		BorderSizePixel = 0,
	}, track)
	Corner(fill, 4)
	AccentGradient(fill, 0)
	table.insert(AccentRegistry, { inst = fill, prop = "BackgroundColor3", key = "Accent" })

	local thumb = Create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0, 0, 0.5, 0),
		Size = UDim2.fromOffset(16, 16),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		ZIndex = 2,
	}, track)
	Corner(thumb, 8)
	local thumbStroke = Outline(thumb, Color3.fromRGB(9, 10, 15), 0.35, 2)

	local sliding = false

	local function Update(inputPosX)
		local alpha = math.clamp((inputPosX - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
		value = min + (max - min) * alpha
		value = math.floor(value * 10 + 0.5) / 10
		fill.Size = UDim2.fromScale(alpha, 1)
		thumb.Position = UDim2.new(alpha, 0, 0.5, 0)
		valuePill.Text = (value % 1 == 0 and tostring(math.floor(value)) or tostring(value)) .. suffixStr
		task.spawn(callback, value)
	end

	holder.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			sliding = true
			Tween(thumb, 0.15, { Size = UDim2.fromOffset(18, 18) })
			Tween(thumbStroke, 0.15, { Color = Theme.Accent, Transparency = 0 })
			Tween(valuePill, 0.15, { BackgroundColor3 = Theme.Accent:Lerp(Color3.new(0, 0, 0), 0.55) })
			Update(input.Position.X)
		end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if sliding and input.UserInputType == Enum.UserInputType.MouseMovement then
			Update(input.Position.X)
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 and sliding then
			sliding = false
			Tween(thumb, 0.15, { Size = UDim2.fromOffset(16, 16) })
			Tween(thumbStroke, 0.2, { Color = Color3.fromRGB(9, 10, 15), Transparency = 0.35 })
			Tween(valuePill, 0.2, { BackgroundColor3 = Theme.Background })
			ScheduleSave()
		end
	end)

	local alpha = (default - min) / (max - min)
	fill.Size = UDim2.fromScale(alpha, 1)
	thumb.Position = UDim2.new(alpha, 0, 0.5, 0)
	valuePill.Text = tostring(default) .. suffixStr

	local option = {
		Type = "Slider",
		Set = function(v, silent)
			v = math.clamp(v, min, max)
			value = v
			local a = (v - min) / (max - min)
			fill.Size = UDim2.fromScale(a, 1)
			thumb.Position = UDim2.new(a, 0, 0.5, 0)
			valuePill.Text = (v % 1 == 0 and tostring(math.floor(v)) or tostring(v)) .. suffixStr
			task.spawn(callback, v)
			if not silent then ScheduleSave() end
		end,
		Get = function() return value end,
	}
	RegisterOption(name, option, page, text, holder)
	return option
end

local function AddDropdown(page, name, text, options, default, callback)
	local selected = default
	local expanded = false

	local holder = Create("Frame", {
		Size = UDim2.new(1, 0, 0, 42),
		BackgroundColor3 = Theme.Card,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		LayoutOrder = page.Add(function(o) return o end),
	}, page.Scroll)
	Corner(holder, 10)
	Outline(holder, Theme.Stroke, 0.6)

	local btn = Create("TextButton", {
		Size = UDim2.new(1, 0, 0, 42),
		BackgroundColor3 = Theme.Card,
		BorderSizePixel = 0,
		Text = "",
		AutoButtonColor = false,
	}, holder)

	Create("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(14, 0),
		Size = UDim2.new(0, 110, 1, 0),
		Font = Enum.Font.GothamMedium,
		Text = text,
		TextColor3 = Theme.Text,
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, btn)

	local currentLabel = Create("TextLabel", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -34, 0, 0),
		Size = UDim2.new(1, -160, 1, 0),
		Font = Enum.Font.Gotham,
		Text = tostring(selected),
		TextColor3 = Theme.SubText,
		TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Right,
		TextTruncate = Enum.TextTruncate.AtEnd,
	}, btn)

	local chevron = Create("TextLabel", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -14, 0, 0),
		Size = UDim2.fromOffset(16, 42),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		Text = "v",
		TextColor3 = Theme.SubText,
		TextSize = 11,
		Rotation = 0,
	}, btn)

	local listHolder = Create("Frame", {
		Position = UDim2.fromOffset(8, 46),
		Size = UDim2.new(1, -16, 0, #options * 30 + 6),
		BackgroundTransparency = 1,
	}, holder)

	local listLayout = Create("UIListLayout", {
		Padding = UDim.new(0, 4),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, listHolder)

	local optionButtons = {}

	local function BuildOptions(opts)
		for _, ob in pairs(optionButtons) do
			ob:Destroy()
		end
		table.clear(optionButtons)
		listHolder.Size = UDim2.new(1, -16, 0, #opts * 30 + 6)
		if expanded then
			holder.Size = UDim2.new(1, 0, 0, 42 + #opts * 34 + 6)
		end

		for i, optName in ipairs(opts) do
		local optBtn = Create("TextButton", {
			Size = UDim2.new(1, 0, 0, 30),
			BackgroundColor3 = Theme.Surface,
			BorderSizePixel = 0,
			Font = Enum.Font.Gotham,
			Text = "   " .. optName,
			TextColor3 = optName == selected and Theme.Accent or Theme.SubText,
			TextSize = 12,
			TextXAlignment = Enum.TextXAlignment.Left,
			AutoButtonColor = false,
			LayoutOrder = i,
			ZIndex = 3,
		}, listHolder)
		Corner(optBtn, 6)
		optionButtons[optName] = optBtn

		optBtn.MouseEnter:Connect(function()
			Tween(optBtn, 0.12, { BackgroundColor3 = Theme.CardHover })
		end)
		optBtn.MouseLeave:Connect(function()
			Tween(optBtn, 0.12, { BackgroundColor3 = Theme.Background })
		end)
		optBtn.MouseButton1Click:Connect(function()
			selected = optName
			currentLabel.Text = optName
			for other, ob in pairs(optionButtons) do
				ob.TextColor3 = other == selected and Theme.Accent or Theme.SubText
			end
			expanded = false
			Tween(chevron, 0.25, { Rotation = 0 }, Enum.EasingStyle.Back)
			Tween(holder, 0.25, { Size = UDim2.new(1, 0, 0, 42) }, Enum.EasingStyle.Quart)
			task.spawn(callback, selected)
			ScheduleSave()
		end)
	end
	end

	BuildOptions(options)

	local function OptionCount()
		local n = 0
		for _ in pairs(optionButtons) do
			n = n + 1
		end
		return n
	end

	btn.MouseEnter:Connect(function()
		Tween(btn, 0.15, { BackgroundColor3 = Theme.CardHover })
	end)
	btn.MouseLeave:Connect(function()
		Tween(btn, 0.15, { BackgroundColor3 = Theme.Card })
	end)
	local ddScale = Create("UIScale", { Scale = 1 }, btn)
	btn.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			Ripple(btn, input.Position)
			Tween(ddScale, 0.07, { Scale = 0.985 }, Enum.EasingStyle.Quart)
		end
	end)
	btn.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			Tween(ddScale, 0.2, { Scale = 1 }, Enum.EasingStyle.Back)
		end
	end)
	btn.MouseButton1Click:Connect(function()
		expanded = not expanded
		if expanded then
			Tween(chevron, 0.25, { Rotation = 180 }, Enum.EasingStyle.Back)
			Tween(holder, 0.28, { Size = UDim2.new(1, 0, 0, 42 + OptionCount() * 34 + 6) }, Enum.EasingStyle.Quart)
		else
			Tween(chevron, 0.25, { Rotation = 0 }, Enum.EasingStyle.Back)
			Tween(holder, 0.28, { Size = UDim2.new(1, 0, 0, 42) }, Enum.EasingStyle.Quart)
		end
	end)

	local option = {
		Type = "Dropdown",
		Set = function(v, silent)
			if optionButtons[v] then
				selected = v
				currentLabel.Text = v
				for other, ob in pairs(optionButtons) do
					ob.TextColor3 = other == selected and Theme.Accent or Theme.SubText
				end
				task.spawn(callback, selected)
				if not silent then ScheduleSave() end
			end
		end,
		Get = function() return selected end,
		SetOptions = function(newOpts)
			BuildOptions(newOpts)
			if selected ~= nil and not optionButtons[selected] then
				selected = nil
				currentLabel.Text = "--"
			end
		end,
	}
	RegisterOption(name, option, page, text, btn)
	return option
end

local notifyHolder = Create("Frame", {
	Name = "Notifications",
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -16, 0, 16),
	Size = UDim2.fromOffset(280, 400),
	BackgroundTransparency = 1,
}, screenGui)

Create("UIListLayout", {
	Padding = UDim.new(0, 8),
	SortOrder = Enum.SortOrder.LayoutOrder,
	HorizontalAlignment = Enum.HorizontalAlignment.Right,
}, notifyHolder)

local function Notify(title, message, kind)
	local color = Theme.Accent
	local icon = "◆"
	if kind == "success" then
		color = Theme.Success
		icon = "✓"
	end
	if kind == "danger" then
		color = Theme.Danger
		icon = "!"
	end

	local toast = Create("CanvasGroup", {
		Size = UDim2.new(1, 0, 0, 66),
		BackgroundColor3 = Theme.Surface,
		BorderSizePixel = 0,
		GroupTransparency = 1,
	}, notifyHolder)
	Corner(toast, 10)
	Outline(toast, Theme.Stroke, 0.4)

	local bar = Create("Frame", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 8, 0.5, 0),
		Size = UDim2.new(0, 3, 1, -18),
		BackgroundColor3 = color,
		BorderSizePixel = 0,
	}, toast)
	Corner(bar, 2)

	Create("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(20, 8),
		Size = UDim2.new(1, -32, 0, 18),
		Font = Enum.Font.GothamBold,
		Text = icon .. "  " .. title,
		TextColor3 = Theme.Text,
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
	}, toast)

	Create("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(20, 28),
		Size = UDim2.new(1, -32, 0, 30),
		Font = Enum.Font.Gotham,
		Text = message,
		TextColor3 = Theme.SubText,
		TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextWrapped = true,
	}, toast)

	local progress = Create("Frame", {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 12, 1, -6),
		Size = UDim2.new(1, -24, 0, 2),
		BackgroundColor3 = Theme.Stroke,
		BackgroundTransparency = 0.35,
		BorderSizePixel = 0,
	}, toast)
	Corner(progress, 2)

	local progressFill = Create("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = color,
		BorderSizePixel = 0,
	}, progress)
	Corner(progressFill, 2)

	toast.Position = UDim2.new(1, 320, 0, 0)
	task.defer(function()
		Tween(toast, 0.45, { GroupTransparency = 0, Position = UDim2.new(0, 0, 0, 0) }, Enum.EasingStyle.Back)
		Tween(progressFill, 3.4, { Size = UDim2.fromScale(0, 1) }, Enum.EasingStyle.Linear)
	end)

	task.delay(3.2, function()
		Tween(toast, 0.3, { GroupTransparency = 1, Position = UDim2.new(1, 300, 0, 0) }).Completed:Wait()
		toast:Destroy()
	end)
end

-- ============ Motor de teclas de atalho ============
local KEYBINDABLE = {
	{ "Hitbox", "Hitbox" },
	{ "Reach", "Alcance" },
	{ "Noclip", "Noclip" },
	{ "Fly", "Fly" },
	{ "InfiniteJump", "Pulo infinito" },
	{ "Invisible", "Invisibilidade" },
	{ "ESP", "ESP" },
	{ "Fullbright", "Fullbright" },
	{ "NoFog", "Sem neblina" },
	{ "AntiAFK", "Anti-AFK" },
	{ "AutoPrompt", "Interacao automatica" },
	{ "WaypointESP", "Waypoints no mundo" },
}

local KeybindRows = {} -- [nome] = pillLabel
local KeycodeToName = {}
local CaptureTarget = nil

local function RebuildKeymap()
	table.clear(KeycodeToName)
	for name, keyName in pairs(Keybinds) do
		local ok, keycode = pcall(function()
			return Enum.KeyCode[keyName]
		end)
		if ok and keycode then
			KeycodeToName[keycode] = name
		end
	end
end
RebuildKeymapFn = RebuildKeymap

local function SetKeybind(name, keyName)
	if keyName then
		Keybinds[name] = keyName
	else
		Keybinds[name] = nil
	end
	RebuildKeymap()
	if RefreshKeybindUI then
		RefreshKeybindUI()
	end
	ScheduleSave()
end

local function StartKeyCapture(name)
	CaptureTarget = name
	local label = KeybindRows[name]
	if label then
		label.Text = "..."
	end
	Notify("Teclas", "Pressione uma tecla para '" .. tostring(name) .. "'. ESC cancela.", nil)
end

Connect(UserInputService.InputBegan, function(input, gameProcessed)
	local isKey = input.UserInputType == Enum.UserInputType.Keyboard
	if not isKey then return end
	if CaptureTarget then
		local target = CaptureTarget
		local keyCode = input.KeyCode
		CaptureTarget = nil
		if keyCode ~= Enum.KeyCode.Escape then
			SetKeybind(target, keyCode.Name)
			Notify("Teclas", "'" .. target .. "' agora usa a tecla " .. keyCode.Name .. ".", "success")
		else
			if RefreshKeybindUI then
				RefreshKeybindUI()
			end
			Notify("Teclas", "Captura cancelada.", nil)
		end
		return
	end
	if gameProcessed then return end
	local targetName = KeycodeToName[input.KeyCode]
	if targetName then
		local opt = Options[targetName]
		if opt and opt.Type == "Toggle" then
			opt.Set(not opt.Get())
		end
	end
end)

local function GetCharacterParts()
	local char = LocalPlayer.Character
	if not char then return nil, nil end
	return char, char:FindFirstChildOfClass("Humanoid")
end

Flags.WalkSpeed = 16
Flags.JumpPower = 50
Flags.InfiniteJump = false
Flags.ClickTP = false
Flags.Noclip = false
Flags.Invisible = false

Connect(RunService.Stepped, function()
	local _, hum = GetCharacterParts()
	if hum then
		hum.WalkSpeed = Flags.WalkSpeed
		hum.UseJumpPower = true
		hum.JumpPower = Flags.JumpPower
	end
	if Flags.Noclip then
		local char = LocalPlayer.Character
		if char then
			for _, part in ipairs(char:GetDescendants()) do
				if part:IsA("BasePart") then
					part.CanCollide = false
				end
			end
		end
	end
end)

Connect(UserInputService.JumpRequest, function()
	if not Flags.InfiniteJump then return end
	local _, hum = GetCharacterParts()
	if hum then
		hum:ChangeState(Enum.HumanoidStateType.Jumping)
	end
end)

Flags.Fly = false
Flags.FlySpeed = 50

local flyObjects = nil

local function StopFly()
	if flyObjects then
		pcall(function() flyObjects.bv:Destroy() end)
		pcall(function() flyObjects.bg:Destroy() end)
		flyObjects = nil
	end
end

local function EnsureFlyObjects(root)
	if flyObjects and flyObjects.root == root and flyObjects.bv.Parent and flyObjects.bg.Parent then
		return flyObjects
	end
	StopFly()

	local bv = Create("BodyVelocity", {
		Name = "LegitHubFly",
		Velocity = Vector3.zero,
		MaxForce = Vector3.new(4000000, 4000000, 4000000),
		P = 10000,
	}, root)

	local bg = Create("BodyGyro", {
		Name = "LegitHubFlyGyro",
		MaxTorque = Vector3.new(4000000, 4000000, 4000000),
		P = 10000,
		D = 500,
		CFrame = root.CFrame,
	}, root)

	flyObjects = { bv = bv, bg = bg, root = root }
	return flyObjects
end

Connect(RunService.Stepped, function()
	if not Flags.Fly then return end

	local char = LocalPlayer.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not root then return end

	local objs = EnsureFlyObjects(root)

	local cam = workspace.CurrentCamera
	if not cam then return end

	objs.bg.CFrame = CFrame.lookAt(root.Position, root.Position + cam.CFrame.LookVector)

	local move = Vector3.zero
	if not UserInputService:GetFocusedTextBox() then
		if UserInputService:IsKeyDown(Enum.KeyCode.W) then move += cam.CFrame.LookVector end
		if UserInputService:IsKeyDown(Enum.KeyCode.S) then move -= cam.CFrame.LookVector end
		if UserInputService:IsKeyDown(Enum.KeyCode.D) then move += cam.CFrame.RightVector end
		if UserInputService:IsKeyDown(Enum.KeyCode.A) then move -= cam.CFrame.RightVector end
		if UserInputService:IsKeyDown(Enum.KeyCode.Space) then move += Vector3.new(0, 1, 0) end
		if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then move -= Vector3.new(0, 1, 0) end
	end

	if move.Magnitude > 0 then
		move = move.Unit * Flags.FlySpeed
	end

	objs.bv.Velocity = move
end)

local invisBusy = false
local invisActive = false
local invisRealChar = nil
local invisCloneChar = nil
local invisConns = {}

local function StopInvisWatchers()
	for _, conn in ipairs(invisConns) do
		pcall(function() conn:Disconnect() end)
	end
	table.clear(invisConns)
end

local function RestoreCamera(character)
	local cam = workspace.CurrentCamera
	local hum = character and character:FindFirstChildOfClass("Humanoid")
	if cam and hum then
		cam.CameraSubject = hum
		cam.CameraType = Enum.CameraType.Custom
	end
end

local function RestartAnimate(character)
	local animate = character and character:FindFirstChild("Animate")
	if animate then
		animate.Disabled = true
		animate.Disabled = false
	end
end

local function SetInvisOption(state, silent)
	local opt = Options["Invisible"]
	if opt then opt.Set(state, silent) end
end

local function InvisResetState()
	StopInvisWatchers()
	invisRealChar = nil
	invisCloneChar = nil
	invisActive = false
	Flags.Invisible = false
end

local function IyForceRespawn()
	local real = invisRealChar
	local clone = invisCloneChar
	InvisResetState()

	pcall(function()
		if real and not real.Destroyed then
			LocalPlayer.Character = real
			task.wait()
			real.Parent = workspace
			local hum = real:FindFirstChildOfClass("Humanoid")
			if hum then
				hum:Destroy()
			end
		end
	end)

	if clone then
		pcall(function() clone:Destroy() end)
	end

	SetInvisOption(false, true)
end

local function IyTurnVisible()
	if not invisActive then return end
	local real = invisRealChar
	local clone = invisCloneChar

	InvisResetState()

	if not (real and clone and not real.Destroyed) then
		if clone then
			pcall(function() clone:Destroy() end)
		end
		SetInvisOption(false, true)
		Notify("Invisibilidade", "Personagem original perdido. Use o reset.", "danger")
		return
	end

	local targetCF = nil
	pcall(function()
		local cloneRoot = clone:FindFirstChild("HumanoidRootPart")
		if cloneRoot then
			targetCF = cloneRoot.CFrame
		end
	end)

	LocalPlayer.Character = real
	pcall(function() real.Parent = workspace end)

	task.wait()

	if targetCF then
		pcall(function()
			real:PivotTo(targetCF)
		end)
	end

	pcall(function() clone:Destroy() end)

	pcall(function()
		local anim = real:FindFirstChild("Animate")
		if anim then
			anim.Disabled = true
			anim.Disabled = false
		end
	end)

	RestoreCamera(real)

	if targetCF then
		task.spawn(function()
			for _ = 1, 20 do
				if real.Destroyed or LocalPlayer.Character ~= real then break end
				pcall(function()
					local rr = real:FindFirstChild("HumanoidRootPart")
					if rr and (rr.CFrame.Position - targetCF.Position).Magnitude > 3 then
						real:PivotTo(targetCF)
					end
				end)
				task.wait(0.05)
			end
		end)
	end
end

local function IyStartInvisibility()
	if invisBusy or invisActive then return false end
	invisBusy = true

	local result = false
	local startPos = nil

	local ok, err = pcall(function()
		local real = LocalPlayer.Character
		local realHumanoid = real and real:FindFirstChildOfClass("Humanoid")
		local realRoot = real and real:FindFirstChild("HumanoidRootPart")
		if not (real and realHumanoid and realRoot) or realHumanoid.Health <= 0 then
			error("personagem invalido ou morto", 0)
		end

		real.Archivable = true

		local clone = real:Clone()
		if not clone then
			error("nao foi possivel clonar o personagem", 0)
		end

		clone.Name = ""
		clone.Parent = Lighting

		for _, obj in ipairs(clone:GetDescendants()) do
			if obj:IsA("BasePart") then
				obj.Transparency = (obj.Name == "HumanoidRootPart") and 1 or 0.5
			end
		end

		local voidHeight = -500
		pcall(function()
			voidHeight = workspace.FallenPartsDestroyHeight
		end)

		table.insert(invisConns, RunService.Stepped:Connect(function()
			if not invisActive then return end
			pcall(function()
				local current = LocalPlayer.Character
				local root = current and current:FindFirstChild("HumanoidRootPart")
				if not root then return end
				local y = root.Position.Y
				local fell
				if voidHeight < 0 then
					fell = y <= voidHeight
				else
					fell = y >= voidHeight
				end
				if fell then
					IyForceRespawn()
					Notify("Invisibilidade", "Voce caiu no void. Respawnando...", "danger")
				end
			end)
		end))

		local cloneHumanoid = clone:FindFirstChildOfClass("Humanoid")
		if cloneHumanoid then
			table.insert(invisConns, cloneHumanoid.Died:Connect(function()
				task.spawn(function()
					if invisActive then
						IyForceRespawn()
						Notify("Invisibilidade", "Desligada (personagem morreu).", "danger")
					end
				end)
			end))
		end

		table.insert(invisConns, LocalPlayer.CharacterAdded:Connect(function(newChar)
			task.defer(function()
				if not invisActive or invisBusy then return end
				if newChar == invisCloneChar then return end
				local realRef = invisRealChar
				local cloneRef = invisCloneChar
				InvisResetState()
				if cloneRef then
					pcall(function() cloneRef:Destroy() end)
				end
				if realRef then
					pcall(function() realRef:Destroy() end)
				end
				SetInvisOption(false, true)
				Notify("Invisibilidade", "Desligada (respawn detectado).", "danger")
			end)
		end))

		startPos = realRoot.CFrame
		local cam = workspace.CurrentCamera

		invisRealChar = real
		invisCloneChar = clone
		invisActive = true
		Flags.Invisible = true

		real:MoveTo(Vector3.new(0, math.pi * 1000000, 0))

		if cam then
			cam.CameraType = Enum.CameraType.Scriptable
		end
		task.wait(0.2)
		if cam then
			cam.CameraType = Enum.CameraType.Custom
		end

		real.Parent = Lighting
		clone.Parent = workspace

		local cloneRoot = clone:FindFirstChild("HumanoidRootPart")
		if cloneRoot then
			cloneRoot.CFrame = startPos
		end

		LocalPlayer.Character = clone

		RestoreCamera(clone)
		RestartAnimate(clone)

		result = true
	end)

	if not ok then
		local realRef = invisRealChar
		local cloneRef = invisCloneChar
		InvisResetState()

		pcall(function()
			local c = workspace.CurrentCamera
			if c then
				c.CameraType = Enum.CameraType.Custom
			end
		end)

		if cloneRef then
			pcall(function() cloneRef:Destroy() end)
		end

		if realRef and not realRef.Destroyed then
			pcall(function()
				LocalPlayer.Character = realRef
				if not realRef.Parent then
					realRef.Parent = workspace
				end
				if startPos then
					local rr = realRef:FindFirstChild("HumanoidRootPart")
					if rr then
						rr.CFrame = startPos
					end
				end
				RestoreCamera(realRef)
				RestartAnimate(realRef)
			end)
		end

		SetInvisOption(false, true)
		Notify("Invisibilidade", "Erro: " .. tostring(err), "danger")
	end

	invisBusy = false
	return result
end

Flags.AntiAFK = false
	Flags.AutoPrompt = false


local VirtualUser = game:GetService("VirtualUser")
Connect(LocalPlayer.Idled, function()
	if not Flags.AntiAFK then return end
	pcall(function()
		VirtualUser:CaptureController()
		VirtualUser:ClickButton2(Vector2.new())
	end)
end)

local promptCooldown = {}

task.spawn(function()
	while true do
		task.wait(0.25)
		if Flags.AutoPrompt then
			local char = LocalPlayer.Character
			local root = char and char:FindFirstChild("HumanoidRootPart")
			if root then
				local radius = Flags.AutoPromptRadius or 25
				local params = OverlapParams.new()
				params.FilterType = Enum.RaycastFilterType.Exclude
				params.FilterDescendantsInstances = { char }

				local now = os.clock()
				local function TryFire(prompt)
					if not prompt.Enabled then return end
					if now - (promptCooldown[prompt] or 0) < 1 then return end
					promptCooldown[prompt] = now
					pcall(function()
						if typeof(fireproximityprompt) == "function" then
							fireproximityprompt(prompt)
						else
							prompt:InputHoldBegin()
							task.wait(math.max(prompt.HoldDuration, 0))
							prompt:InputHoldEnd()
						end
					end)
				end

				local seenHolders = {}
				local parts = workspace:GetPartBoundsInRadius(root.Position, radius, params)
				for _, part in ipairs(parts) do
					for _, prompt in ipairs(part:GetChildren()) do
						if prompt:IsA("ProximityPrompt") then
							TryFire(prompt)
						end
					end
					local holder = part.Parent
					if holder and not seenHolders[holder] then
						seenHolders[holder] = true
						for _, prompt in ipairs(holder:GetChildren()) do
							if prompt:IsA("ProximityPrompt") then
								TryFire(prompt)
							end
						end
					end
				end

				if #parts > 0 then
					for promptKey in pairs(promptCooldown) do
						if not promptKey.Parent then
							promptCooldown[promptKey] = nil
						end
					end
				end
			end
		end
	end
end)

local function GetHubRemote()
	return game:GetService("ReplicatedStorage"):FindFirstChild("LegitHubTools")
end

local hitboxSaved = {}

local function StopHitbox()
	Flags.Hitbox = false
	for hrp, saved in pairs(hitboxSaved) do
		pcall(function()
			if hrp.Parent then
				hrp.Size = saved.size
				hrp.Transparency = saved.transparency
				hrp.CanCollide = saved.canCollide
			end
		end)
	end
	table.clear(hitboxSaved)
end

task.spawn(function()
	while true do
		task.wait(0.25)
		if Flags.Hitbox and not GetHubRemote() then
			for hrp in pairs(hitboxSaved) do
				if not hrp.Parent then
					hitboxSaved[hrp] = nil
				end
			end
			local size = Flags.HitboxSize or 10
			for _, plr in ipairs(Players:GetPlayers()) do
				if plr ~= LocalPlayer then
					pcall(function()
						local char = plr.Character
						local hrp = char and char:FindFirstChild("HumanoidRootPart")
						if hrp and hrp:IsA("BasePart") then
							if not hitboxSaved[hrp] then
								hitboxSaved[hrp] = {
									size = hrp.Size,
									transparency = hrp.Transparency,
									canCollide = hrp.CanCollide
								}
							end
							hrp.CanCollide = false
							hrp.Size = Vector3.new(size, size, size)
							hrp.Transparency = Flags.HitboxInvisible and 1 or 0.4
						end
					end)
				end
			end
		end
	end
end)

local reachSaved = {}

local function ApplyReach(handle)
	pcall(function()
		local tool = handle.Parent
		local len = Flags.ReachSize or 30
		if not reachSaved[handle] then
			reachSaved[handle] = {
				size = handle.Size,
				grip = tool and tool.GripPos or Vector3.new(),
				massless = handle.Massless
			}
		end
		handle.Massless = true
		handle.Size = Vector3.new(0.5, 0.5, len)
		if tool and tool:IsA("Tool") then
			tool.GripPos = Vector3.new(0, 0, 0)
		end
		local box = handle:FindFirstChild("LegitHubReach")
		if not box then
			box = Instance.new("SelectionBox")
			box.Name = "LegitHubReach"
			box.Adornee = handle
			box.LineThickness = 0.02
			box.Color3 = Color3.fromRGB(255, 64, 84)
			box.Parent = handle
		end
	end)
end

local function StopReach()
	Flags.Reach = false
	for handle, saved in pairs(reachSaved) do
		pcall(function()
			if handle.Parent then
				handle.Size = saved.size
				handle.Massless = saved.massless
				local tool = handle:FindFirstAncestorOfClass("Tool")
				if tool then
					tool.GripPos = saved.grip
				end
				local box = handle:FindFirstChild("LegitHubReach")
				if box then
					box:Destroy()
				end
			end
		end)
	end
	table.clear(reachSaved)
end

task.spawn(function()
	while true do
		task.wait(0.15)
		if Flags.Reach and not GetHubRemote() then
			for handle in pairs(reachSaved) do
				if not handle.Parent then
					reachSaved[handle] = nil
				end
			end
			local char = LocalPlayer.Character
			if char then
				for _, tool in ipairs(char:GetChildren()) do
					if tool:IsA("Tool") then
						local handle = tool:FindFirstChild("Handle")
						if handle and handle:IsA("BasePart") then
							ApplyReach(handle)
						end
					end
				end
			end
		end
	end
end)

local function GetNearestPlayer(maxDist)
	maxDist = maxDist or math.huge
	local char = LocalPlayer.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not root then return nil end

	local nearest = nil
	local nearestDist = maxDist

	for _, player in ipairs(Players:GetPlayers()) do
		if player ~= LocalPlayer then
			local pchar = player.Character
			local proot = pchar and pchar:FindFirstChild("HumanoidRootPart")
			if proot then
				local dist = (proot.Position - root.Position).Magnitude
				if dist < nearestDist then
					nearest = player
					nearestDist = dist
				end
			end
		end
	end

	return nearest
end

local function CaptureVisualProfile(tool)
	local profile = {}
	for _, obj in ipairs(tool:GetDescendants()) do
		if obj:IsA("BasePart") or obj:IsA("Decal") then
			table.insert(profile, { class = obj.ClassName, transparency = obj.Transparency })
		end
	end
	return profile
end

local function ApplyVisualProfile(profile, clone)
	local descendants = clone:GetDescendants()
	for i, info in ipairs(profile) do
		local obj = descendants[i]
		if obj and obj.ClassName == info.class then
			obj.Transparency = info.transparency
			if obj:IsA("BasePart") then
				obj.Anchored = false
				obj.LocalTransparencyModifier = 0
			end
		end
	end
end

local function WatchCopiedTools(copied)
	task.spawn(function()
		while #copied > 0 do
			for i = #copied, 1, -1 do
				local item = copied[i]
				local clone = item.clone
				if clone and clone.Parent then
					pcall(function()
						ApplyVisualProfile(item.profile, clone)
					end)
				else
					table.remove(copied, i)
				end
			end
			task.wait(0.05)
		end
	end)
end

local function CopyToolsFrom(target)
	if not target then
		Notify("Copiar ferramentas", "Nenhum jogador selecionado.", "danger")
		return
	end

	local remote = game:GetService("ReplicatedStorage"):FindFirstChild("LegitHubTools")
	if remote then
		remote:FireServer(target.Name)
		Notify("Copiar ferramentas", "Servidor copiando " .. target.DisplayName .. "... (100% funcionais)", nil)
		return
	end

	local backpack = LocalPlayer:FindFirstChild("Backpack")
	local character = LocalPlayer.Character
	local hum = character and character:FindFirstChildOfClass("Humanoid")
	if not (backpack and character and hum) then
		Notify("Copiar ferramentas", "Personagem indisponivel.", "danger")
		return
	end

	local sources = {}
	local tchar = target.Character
	if tchar then
		for _, obj in ipairs(tchar:GetChildren()) do
			if obj:IsA("Tool") then
				table.insert(sources, obj)
			end
		end
	end
	local tbackpack = target:FindFirstChildOfClass("Backpack")
	if tbackpack then
		for _, obj in ipairs(tbackpack:GetChildren()) do
			if obj:IsA("Tool") then
				table.insert(sources, obj)
			end
		end
	end

	if #sources == 0 then
		Notify("Copiar ferramentas", target.DisplayName .. " nao tem ferramentas (mao nem mochila).", "danger")
		return
	end

	local copied = {}
	local firstClone = nil

	for _, tool in ipairs(sources) do
		local ok, clone = pcall(function()
			tool.Archivable = true
			return tool:Clone()
		end)
		if ok and clone then
			local profile = CaptureVisualProfile(tool)
			pcall(function()
				ApplyVisualProfile(profile, clone)
			end)
			clone.Parent = backpack
			table.insert(copied, { clone = clone, profile = profile })
			if not firstClone then
				firstClone = clone
			end
		end
	end

	if #copied == 0 then
		Notify("Copiar ferramentas", "Nao foi possivel clonar as ferramentas.", "danger")
		return
	end

	task.spawn(function()
		local equippedOk = false
		for _ = 1, 3 do
			if not firstClone.Parent then break end
			pcall(function() hum:EquipTool(firstClone) end)
			task.wait(0.3)
			if firstClone.Parent == character then
				equippedOk = true
				break
			end
		end

		if not equippedOk and firstClone.Parent then
			firstClone.Parent = backpack
			task.wait(0.1)
			pcall(function() hum:EquipTool(firstClone) end)
			equippedOk = firstClone.Parent == character
		end

		if equippedOk then
			task.wait(0.4)
			local hrp = character:FindFirstChild("HumanoidRootPart")
			local handle = firstClone:FindFirstChild("Handle")
			if hrp and handle and handle:IsA("BasePart") then
				if (handle.Position - hrp.Position).Magnitude > 60 then
					firstClone.Parent = backpack
					task.wait(0.1)
					pcall(function() hum:EquipTool(firstClone) end)
					equippedOk = firstClone.Parent == character
				end
			end
		end

		if equippedOk then
			Notify("Copiar ferramentas", #copied .. " copiada(s), visibilidade garantida.", "success")
		else
			Notify("Copiar ferramentas", #copied .. " copiada(s) para a mochila.", nil)
		end
	end)

	WatchCopiedTools(copied)
end

local function CopyNearestTools()
	local target = GetNearestPlayer(1000)
	if not target then
		Notify("Copiar ferramentas", "Nenhum jogador por perto.", "danger")
		return
	end
	CopyToolsFrom(target)
end

Flags.ESP = false
Flags.ESPBoxes = true
Flags.ESPFill = true
Flags.ESPNames = true
Flags.ESPDistance = true
Flags.ESPHealth = true
Flags.ESPTool = false
Flags.ESPTracers = false
Flags.ESPTeamColors = false
Flags.ESPTeamCheck = false
Flags.ESPVisibilityColor = false
	Flags.ESPMaxDistance = 1000

	-- ============ Monitor de ADMs ============
	local HubAlive = true
	_G.LegitHubAlive = function() return HubAlive end

	Flags.AdmMonitor = true
	Flags.AdmNotifyJoin = true
	Flags.AdmNotifyLeave = false
	Flags.AdmSound = false
	Flags.AdmMinRank = 250

	local EspAdminColor = Color3.fromRGB(255, 70, 90)

	local AdmMon = {
		Info = {},
		Custom = {},
		OnUpdate = nil,
	}
	_G.LegitHubAdmins = AdmMon

	local RefreshPanel -- definido adiante (painel lateral)
	Flags.AdmPanel = false
	Flags.AdmEspOnly = false

	local admPing
	local function PlayAdmPing()
		if not admPing then
			admPing = Create("Sound", {
				SoundId = "rbxasset://sounds/electronicpingshort.wav",
				Volume = 0.6,
			}, screenGui)
		end
		pcall(function()
			admPing:Play()
		end)
	end

	local function BuildListText()
		local parts = {}
		for plr, info in pairs(AdmMon.Info) do
			table.insert(parts, plr.DisplayName .. " (@" .. plr.Name .. ") - " .. info.Role)
		end
		table.sort(parts)
		if #parts == 0 then
			return "Nenhum ADM detectado neste servidor."
		end
		local shown = {}
		for i = 1, math.min(#parts, 6) do
			table.insert(shown, parts[i])
		end
		local txt = table.concat(shown, "\n")
		if #parts > 6 then
			txt = txt .. "\n(+" .. (#parts - 6) .. " outros)"
		end
		return txt
	end

	local function ApplyAdm(plr, info)
		local prev = AdmMon.Info[plr]
		if prev and prev.Role == info.Role and prev.Rank == info.Rank then
			return
		end
		local isNew = AdmMon.Info[plr] == nil
		AdmMon.Info[plr] = info
		if isNew then
			if Flags.AdmMonitor then
				if Flags.AdmNotifyJoin then
					Notify("ADM detectado", plr.DisplayName .. " (@" .. plr.Name .. ") - " .. info.Role, "danger")
				end
				if Flags.AdmSound then
					PlayAdmPing()
				end
			end
		end
		if AdmMon.OnUpdate then
			AdmMon.OnUpdate()
		end
		if RefreshPanel then
			RefreshPanel()
		end
	end

	local function RemoveAdm(plr, announce)
		local info = AdmMon.Info[plr]
		if info then
			AdmMon.Info[plr] = nil
			if announce and Flags.AdmMonitor and Flags.AdmNotifyLeave then
				Notify("ADM saiu", plr.DisplayName .. " (" .. info.Role .. ") saiu do servidor.", "success")
			end
			if AdmMon.OnUpdate then
				AdmMon.OnUpdate()
			end
			if RefreshPanel then
				RefreshPanel()
			end
		end
	end

	local function ClassifyPlayer(plr)
		local marked = AdmMon.Custom[plr.UserId]
		if marked then
			return { Role = "ADM (marcado)", Rank = -1 }
		end
		if game.CreatorType == Enum.CreatorType.User and plr.UserId == game.CreatorId then
			return { Role = "Dono do jogo", Rank = 255 }
		end
		if game.CreatorType == Enum.CreatorType.Group and tonumber(game.CreatorId) then
			local groupId = tonumber(game.CreatorId)
			local ok, rank = pcall(function()
				return plr:GetRankInGroup(groupId)
			end)
			if ok and rank and rank >= (Flags.AdmMinRank or 250) then
				local okRole, roleName = pcall(function()
					return plr:GetRoleInGroup(groupId)
				end)
				return { Role = (okRole and roleName or "Rank " .. rank) .. " [grupo]", Rank = rank }
			end
		end
		return nil
	end

	local function ScanPlayer(plr)
		if plr == LocalPlayer or not plr.Parent then return end
		task.spawn(function()
			local info = ClassifyPlayer(plr)
			if info then
				ApplyAdm(plr, info)
			elseif not AdmMon.Info[plr] then
				RemoveAdm(plr, false)
			end
		end)
	end

	local function ScanAll()
		for _, plr in ipairs(Players:GetPlayers()) do
			ScanPlayer(plr)
		end
	end
	_G.LegitHubScanAdmins = ScanAll

	-- ============ Spectate ============
	local spectTarget = nil
	local spectConn = nil
	local spectLeaveConn = nil
	local spectBar = nil
	local spectNameLabel = nil
	local StartSpectate, StopSpectate
	_G.LegitHubSpectating = function() return spectTarget end

	local function EnsureSpectateBar()
		if spectBar then return end
		spectBar = Create("CanvasGroup", {
			Name = "SpectateBar",
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, 14),
			Size = UDim2.fromOffset(250, 40),
			BackgroundColor3 = Theme.Surface,
			BorderSizePixel = 0,
			GroupTransparency = 1,
			Visible = false,
			ZIndex = 60,
		}, screenGui)
		Corner(spectBar, 12)
		Outline(spectBar, Theme.Stroke, 0.35)

		Create("TextLabel", {
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(12, 0),
			Size = UDim2.fromOffset(22, 40),
			Font = Enum.Font.GothamBold,
			Text = "👁",
			TextSize = 15,
			TextYAlignment = Enum.TextYAlignment.Center,
			ZIndex = 61,
		}, spectBar)

		spectNameLabel = Create("TextLabel", {
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(38, 0),
			Size = UDim2.new(1, -84, 1, 0),
			Font = Enum.Font.GothamMedium,
			Text = "",
			TextColor3 = Theme.Text,
			TextSize = 13,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			ZIndex = 61,
		}, spectBar)

		local stopBtn = Create("TextButton", {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -8, 0.5, 0),
			Size = UDim2.fromOffset(26, 26),
			BackgroundColor3 = Theme.Card,
			Font = Enum.Font.GothamBold,
			Text = "✕",
			TextColor3 = Theme.Danger,
			TextSize = 12,
			AutoButtonColor = false,
			ZIndex = 61,
		}, spectBar)
		Corner(stopBtn, 8)
		stopBtn.MouseEnter:Connect(function()
			Tween(stopBtn, 0.15, { BackgroundColor3 = Theme.CardHover })
		end)
		stopBtn.MouseLeave:Connect(function()
			Tween(stopBtn, 0.15, { BackgroundColor3 = Theme.Card })
		end)
		stopBtn.MouseButton1Click:Connect(function()
			StopSpectate(false)
		end)
	end

	StopSpectate = function(silent)
		local was = spectTarget
		if not was then return end
		spectTarget = nil
		if spectConn then
			spectConn:Disconnect()
			spectConn = nil
		end
		if spectLeaveConn then
			spectLeaveConn:Disconnect()
			spectLeaveConn = nil
		end
		pcall(function()
			local char = LocalPlayer.Character
			local hum = char and char:FindFirstChildOfClass("Humanoid")
			if hum and workspace.CurrentCamera then
				workspace.CurrentCamera.CameraSubject = hum
			end
		end)
		if spectBar then
			Tween(spectBar, 0.25, { GroupTransparency = 1 }).Completed:Once(function()
				if not spectTarget and spectBar then
					spectBar.Visible = false
				end
			end)
		end
		if Flags.SpectateSelected and Options["SpectateSelected"] then
			Options["SpectateSelected"].Set(false, true)
		end
		if RefreshPanel then
			RefreshPanel()
		end
		if not silent then
			Notify("Spectate", "Parou de espiar " .. was.DisplayName .. ".", nil)
		end
	end

	StartSpectate = function(plr)
		if plr == LocalPlayer then return end
		if spectTarget == plr then return end
		if spectTarget then
			StopSpectate(true)
		end
		EnsureSpectateBar()
		spectTarget = plr
		spectNameLabel.Text = "Espiando: " .. plr.DisplayName
		spectBar.Visible = true
		Tween(spectBar, 0.3, { GroupTransparency = 0 }, Enum.EasingStyle.Quart)
		spectConn = RunService.RenderStepped:Connect(function()
			local t = spectTarget
			if not t then return end
			local cam = workspace.CurrentCamera
			local char = t.Character
			local hum = char and char:FindFirstChildOfClass("Humanoid")
			if cam and hum then
				cam.CameraSubject = hum
			end
		end)
		table.insert(Connections, spectConn)
		spectLeaveConn = Players.PlayerRemoving:Connect(function(leaving)
			if leaving == spectTarget then
				StopSpectate(true)
				Notify("Spectate", leaving.DisplayName .. " saiu do servidor.", "danger")
			end
		end)
		table.insert(Connections, spectLeaveConn)
		if RefreshPanel then
			RefreshPanel()
		end
		Notify("Spectate", "Espiando " .. plr.DisplayName .. ". Clique no painel ou ✕ para parar.", "success")
	end

	-- Painel lateral fixo de ADMs
	local PANEL_MAX_ROWS = 6
	local admPanel = nil
	local admPanelBody = nil
	local admPanelCount = nil

	local function EnsurePanel()
		if admPanel then return end

		admPanel = Create("CanvasGroup", {
			Name = "AdmSidePanel",
			Position = UDim2.new(0, 12, 0, 120),
			Size = UDim2.fromOffset(190, 34),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundColor3 = Theme.Surface,
			BorderSizePixel = 0,
			GroupTransparency = 1,
			Visible = false,
			ZIndex = 50,
		}, screenGui)
		Corner(admPanel, 12)
		Outline(admPanel, Theme.Stroke, 0.35)

		local titleBar = Create("Frame", {
			Size = UDim2.new(1, 0, 0, 32),
			BackgroundTransparency = 1,
			ZIndex = 51,
		}, admPanel)

		local dot = Create("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0, 16, 0.5, 0),
			Size = UDim2.fromOffset(8, 8),
			BackgroundColor3 = EspAdminColor,
			BorderSizePixel = 0,
			ZIndex = 51,
		}, titleBar)
		Corner(dot, 4)

		Create("TextLabel", {
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(26, 0),
			Size = UDim2.new(1, -80, 1, 0),
			Font = Enum.Font.GothamBold,
			Text = "ADMs",
			TextColor3 = Theme.Text,
			TextSize = 13,
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 51,
		}, titleBar)

		admPanelCount = Create("TextLabel", {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -10, 0.5, 0),
			Size = UDim2.new(0, 26, 0, 18),
			BackgroundColor3 = Theme.Card,
			Font = Enum.Font.GothamBold,
			Text = "0",
			TextColor3 = EspAdminColor,
			TextSize = 11,
			ZIndex = 51,
		}, titleBar)
		Corner(admPanelCount, 9)
		Outline(admPanelCount, Theme.Stroke, 0.5)

		admPanelBody = Create("Frame", {
			Position = UDim2.fromOffset(0, 32),
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			ZIndex = 51,
		}, admPanel)
		Create("UIListLayout", {
			Padding = UDim.new(0, 6),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}, admPanelBody)
		Create("UIPadding", {
			PaddingLeft = UDim.new(0, 10),
			PaddingRight = UDim.new(0, 10),
			PaddingBottom = UDim.new(0, 10),
		}, admPanelBody)

		local pDragging = false
		local pDragStart, pStartPos
		titleBar.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 then
				pDragging = true
				pDragStart = input.Position
				pStartPos = admPanel.Position
				input.Changed:Connect(function()
					if input.UserInputState == Enum.UserInputState.End then
						pDragging = false
					end
				end)
			end
		end)
		table.insert(Connections, UserInputService.InputChanged:Connect(function(input)
			if pDragging and input.UserInputType == Enum.UserInputType.MouseMovement then
				local delta = input.Position - pDragStart
				admPanel.Position = UDim2.new(
					pStartPos.X.Scale, pStartPos.X.Offset + delta.X,
					pStartPos.Y.Scale, pStartPos.Y.Offset + delta.Y
				)
			end
		end))

		task.spawn(function()
			while screenGui.Parent do
				if admPanel.Visible then
					Tween(dot, 0.75, { Size = UDim2.fromOffset(11, 11), BackgroundTransparency = 0.5 }, Enum.EasingStyle.Sine)
					task.wait(0.75)
					Tween(dot, 0.75, { Size = UDim2.fromOffset(8, 8), BackgroundTransparency = 0 }, Enum.EasingStyle.Sine)
					task.wait(0.75)
				else
					task.wait(0.5)
				end
			end
		end)
	end

	RefreshPanel = function()
		if not (admPanel and admPanel.Visible) then return end

		for _, child in ipairs(admPanelBody:GetChildren()) do
			if not (child:IsA("UIListLayout") or child:IsA("UIPadding")) then
				child:Destroy()
			end
		end

		local entries = {}
		for plr, info in pairs(AdmMon.Info) do
			table.insert(entries, { plr = plr, info = info })
		end
		table.sort(entries, function(a, b)
			return a.plr.Name < b.plr.Name
		end)
		admPanelCount.Text = tostring(#entries)

		if #entries == 0 then
			Create("TextLabel", {
				Size = UDim2.new(1, 0, 0, 16),
				BackgroundTransparency = 1,
				Font = Enum.Font.Gotham,
				Text = Flags.AdmMonitor and "Nenhum ADM no servidor." or "Monitor desligado.",
				TextColor3 = Theme.SubText,
				TextSize = 11,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextWrapped = true,
				ZIndex = 51,
				LayoutOrder = 999,
			}, admPanelBody)
			return
		end

		for i, entry in ipairs(entries) do
			if i > PANEL_MAX_ROWS then
				Create("TextLabel", {
					Size = UDim2.new(1, 0, 0, 14),
					BackgroundTransparency = 1,
					Font = Enum.Font.GothamBold,
					Text = "+" .. (#entries - PANEL_MAX_ROWS) .. " mais...",
					TextColor3 = Theme.SubText,
					TextSize = 11,
					TextXAlignment = Enum.TextXAlignment.Left,
					ZIndex = 51,
					LayoutOrder = i,
				}, admPanelBody)
				break
			end
			local isSpectating = spectTarget == entry.plr
			local row = Create("TextButton", {
				Size = UDim2.new(1, 0, 0, 30),
				BackgroundColor3 = Theme.Card,
				BackgroundTransparency = 0.35,
				BorderSizePixel = 0,
				Text = "",
				AutoButtonColor = false,
				ZIndex = 51,
				LayoutOrder = i,
			}, admPanelBody)
			Corner(row, 8)
			local rowStroke = Outline(row, Theme.Stroke, 0.55)
			if isSpectating then
				rowStroke.Color = Theme.Accent
				rowStroke.Transparency = 0.15
			end
			row.MouseEnter:Connect(function()
				Tween(row, 0.12, { BackgroundTransparency = 0.05 })
			end)
			row.MouseLeave:Connect(function()
				Tween(row, 0.15, { BackgroundTransparency = 0.35 })
			end)
			row.MouseButton1Click:Connect(function()
				if spectTarget == entry.plr then
					StopSpectate(false)
				else
					StartSpectate(entry.plr)
				end
			end)
			Create("TextLabel", {
				BackgroundTransparency = 1,
				Position = UDim2.fromOffset(8, 3),
				Size = UDim2.new(1, -14, 0, 14),
				Font = Enum.Font.GothamMedium,
				Text = entry.plr.DisplayName,
				TextColor3 = Theme.Text,
				TextSize = 12,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextTruncate = Enum.TextTruncate.AtEnd,
				ZIndex = 52,
			}, row)
			Create("TextLabel", {
				BackgroundTransparency = 1,
				Position = UDim2.fromOffset(8, 16),
				Size = UDim2.new(1, -14, 0, 12),
				Font = Enum.Font.Gotham,
				Text = entry.info.Role .. " (@" .. entry.plr.Name .. ")",
				TextColor3 = Theme.SubText,
				TextSize = 10,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextTruncate = Enum.TextTruncate.AtEnd,
				ZIndex = 52,
			}, row)
		end
	end

	local function SetAdmPanel(state)
		EnsurePanel()
		Flags.AdmPanel = state and true or false
		admPanel.Visible = state
		if state then
			RefreshPanel()
			Tween(admPanel, 0.35, { GroupTransparency = 0 }, Enum.EasingStyle.Quart)
		else
			Tween(admPanel, 0.25, { GroupTransparency = 1 }, Enum.EasingStyle.Quart)
		end
	end
	AdmMon.SetPanel = SetAdmPanel

	-- ============ Waypoints ============
	local Waypoints = {}
	local waypointDrawings = {}
	local wpEspBind = "LegitHub_WaypointESP"
	local wpUIRefresh = nil

	Flags.WaypointESP = false

	local function WpForCurrentPlace()
		local out = {}
		for i, wp in ipairs(Waypoints) do
			if wp.pid == game.PlaceId then
				table.insert(out, { name = wp.name, index = i })
			end
		end
		return out
	end

	local function ClearWpDrawings()
		for _, d in pairs(waypointDrawings) do
			pcall(function() d:Remove() end)
		end
		table.clear(waypointDrawings)
	end

	RebuildWpDrawings = function()
		ClearWpDrawings()
		if not (Flags.WaypointESP and Drawing) then return end
		for _, item in ipairs(WpForCurrentPlace()) do
			pcall(function()
				local txt = Drawing.new("Text")
				txt.Text = item.name
				txt.Size = 14
				txt.Center = true
				txt.Outline = true
				txt.Color = Theme.Accent2
				txt.Visible = false
				waypointDrawings[item.index] = txt
			end)
		end
	end

	RegisterOption("Waypoints", {
		Type = "Custom",
		Get = function()
			local arr = {}
			for _, wp in ipairs(Waypoints) do
				table.insert(arr, { name = wp.name, x = wp.x, y = wp.y, z = wp.z, pid = wp.pid })
			end
			return arr
		end,
		Set = function(arr)
			table.clear(Waypoints)
			if type(arr) == "table" then
				for _, item in ipairs(arr) do
					if type(item) == "table" and type(item.name) == "string"
						and type(item.x) == "number" and type(item.y) == "number" and type(item.z) == "number" then
						table.insert(Waypoints, {
							name = tostring(item.name),
							x = item.x,
							y = item.y,
							z = item.z,
							pid = tonumber(item.pid) or 0,
						})
					end
				end
			end
			RebuildWpDrawings()
			if wpUIRefresh then
				wpUIRefresh()
			end
		end,
	})

	RunService:BindToRenderStep(wpEspBind, Enum.RenderPriority.Last.Value + 2, function()
		if not Flags.WaypointESP then return end
		local cam = workspace.CurrentCamera
		if not cam then return end
		for idx, txt in pairs(waypointDrawings) do
			local wp = Waypoints[idx]
			if wp then
				local pos = Vector3.new(wp.x, wp.y, wp.z)
				local sp, onScreen = cam:WorldToViewportPoint(pos)
				if onScreen and sp.Z > 0 then
					local dist = math.floor((cam.CFrame.Position - pos).Magnitude)
					txt.Text = wp.name .. " (" .. dist .. "m)"
					txt.Position = Vector2.new(sp.X, sp.Y - 10)
					txt.Visible = true
				else
					txt.Visible = false
				end
			else
				txt.Visible = false
			end
		end
	end)
	-- ============ fim Waypoints ============

	RegisterOption("AdmCustom", {
		Type = "Custom",
		Get = function()
			local arr = {}
			for uid, nm in pairs(AdmMon.Custom) do
				table.insert(arr, { id = uid, name = nm })
			end
			return arr
		end,
		Set = function(arr)
			table.clear(AdmMon.Custom)
			if type(arr) == "table" then
				for _, item in ipairs(arr) do
					if type(item) == "table" and type(item.id) == "number" then
						AdmMon.Custom[item.id] = tostring(item.name or "?")
					end
				end
			end
			ScanAll()
		end,
	})

	table.insert(Connections, Players.PlayerAdded:Connect(function(plr)
		task.delay(2, function()
			if HubAlive and Flags.AdmMonitor then
				ScanPlayer(plr)
			end
		end)
	end))

	table.insert(Connections, Players.PlayerRemoving:Connect(function(plr)
		RemoveAdm(plr, true)
	end))

	task.spawn(function()
		while HubAlive do
			if Flags.AdmMonitor then
				ScanAll()
			end
			task.wait(30)
		end
	end)

	task.delay(3, function()
		if HubAlive and Flags.AdmMonitor then
			ScanAll()
		end
	end)
	-- ============ fim Monitor de ADMs ============

local espCache = {}
local espSupported = Drawing ~= nil
local ESP_RENDER_NAME = "LegitHub_ESP"

local function NewDrawing(class, props)
	local ok, obj = pcall(function()
		local drawing = Drawing.new(class)
		for k, v in pairs(props) do
			drawing[k] = v
		end
		return drawing
	end)
	return ok and obj or nil
end

local PoolKeys = { "fill", "name", "distance", "toolText", "healthBg", "healthFill", "healthText", "tracer" }

local function RemoveDrawing(obj)
	if obj then
		pcall(function() obj:Remove() end)
	end
end

local function DestroyEspPool(pool)
	if not pool then return end
	for i = 1, 8 do
		RemoveDrawing(pool.corners[i])
	end
	for _, key in ipairs(PoolKeys) do
		RemoveDrawing(pool[key])
	end
end

local function HideEsp(pool)
	if not pool then return end
	for i = 1, 8 do
		local seg = pool.corners[i]
		if seg then seg.Visible = false end
	end
	for _, key in ipairs(PoolKeys) do
		local obj = pool[key]
		if obj then obj.Visible = false end
	end
end

local function PoolValid(pool)
	if not (pool.fill and pool.name and pool.distance and pool.toolText
		and pool.healthBg and pool.healthFill and pool.healthText and pool.tracer) then
		return false
	end
	for i = 1, 8 do
		if not pool.corners[i] then return false end
	end
	return true
end

local function GetEspPool(player)
	local pool = espCache[player]
	if pool then
		if PoolValid(pool) then
			return pool
		end
		DestroyEspPool(pool)
		espCache[player] = nil
	end

	pool = { corners = {} }
	pool.fill = NewDrawing("Square", { Thickness = 1, Filled = true, Transparency = 0.65 })
	pool.name = NewDrawing("Text", { Size = 13, Center = true, Outline = true })
	pool.distance = NewDrawing("Text", { Size = 11, Center = true, Outline = true })
	pool.toolText = NewDrawing("Text", { Size = 11, Center = true, Outline = true })
	pool.healthBg = NewDrawing("Square", { Thickness = 1, Filled = true })
	pool.healthFill = NewDrawing("Square", { Thickness = 1, Filled = true })
	pool.healthText = NewDrawing("Text", { Size = 11, Center = true, Outline = true })
	pool.tracer = NewDrawing("Line", { Thickness = 1 })
	pool.visible = true
	pool.visTime = 0

	for i = 1, 8 do
		pool.corners[i] = NewDrawing("Line", { Thickness = 1 })
	end

	if not PoolValid(pool) then
		DestroyEspPool(pool)
		return nil
	end

	espCache[player] = pool
	return pool
end

local function RemoveEsp(player)
	local pool = espCache[player]
	if not pool then return end
	HideEsp(pool)
	DestroyEspPool(pool)
	espCache[player] = nil
end

Connect(Players.PlayerRemoving, RemoveEsp)

local EspWhite = Color3.fromRGB(255, 255, 255)
local EspGray = Color3.fromRGB(175, 175, 195)
local EspDark = Color3.fromRGB(12, 12, 18)
local EspAlly = Color3.fromRGB(90, 255, 140)
local EspEnemy = Color3.fromRGB(255, 90, 105)

local function DimColor(color, factor)
	return Color3.new(color.R * factor, color.G * factor, color.B * factor)
end

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
rayParams.IgnoreWater = true

local function CheckVisible(camera, character, root)
	local exclude = { character }
	local myChar = LocalPlayer.Character
	if myChar then
		table.insert(exclude, myChar)
	end
	rayParams.FilterDescendantsInstances = exclude

	local origin = camera.CFrame.Position
	local direction = root.Position - origin
	if direction.Magnitude < 2 then
		return true
	end

	local result = workspace:Raycast(origin, direction, rayParams)
	return result == nil or result.Instance:IsDescendantOf(character)
end

local function GetBaseColor(player)
	if AdmMon.Info[player] then
		return EspAdminColor
	end
	if Flags.ESPTeamColors and LocalPlayer.Team ~= nil then
		if player.Team == LocalPlayer.Team then
			return EspAlly
		end
		return EspEnemy
	end
	return EspWhite
end

local function EspRender()
	if not (Flags.ESP and espSupported) then
		for _, pool in pairs(espCache) do
			HideEsp(pool)
		end
		return
	end

	local camera = workspace.CurrentCamera
	if not camera then
		for _, pool in pairs(espCache) do
			HideEsp(pool)
		end
		return
	end

	local viewport = camera.ViewportSize
	local myTeam = LocalPlayer.Team
	local now = os.clock()

	for _, player in ipairs(Players:GetPlayers()) do
		pcall(function()
			local skip = player == LocalPlayer
			if not skip and Flags.ESPTeamCheck and myTeam ~= nil and player.Team == myTeam then
				skip = true
			end
			if not skip and Flags.AdmEspOnly and not AdmMon.Info[player] then
				skip = true
			end

			local cached = espCache[player]

			if skip then
				HideEsp(cached)
				return
			end

			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")

			if not root or not humanoid or humanoid.Health <= 0 then
				HideEsp(cached)
				return
			end

			local delta = (root.Position - camera.CFrame.Position).Magnitude
			if delta > Flags.ESPMaxDistance then
				HideEsp(cached)
				return
			end

			local screenPos, onScreen = camera:WorldToViewportPoint(root.Position)
			if not onScreen or screenPos.Z <= 0 then
				HideEsp(cached)
				return
			end

			local pool = GetEspPool(player)
			if not pool then return end

			if now - pool.visTime > 0.12 then
				pool.visTime = now
				pool.visible = CheckVisible(camera, character, root)
			end

			local baseColor = GetBaseColor(player)
			if Flags.ESPVisibilityColor and not pool.visible then
				baseColor = DimColor(baseColor, 0.45)
			end

			local topPoint = camera:WorldToViewportPoint(root.Position + Vector3.new(0, 2.9, 0))
			local bottomPoint = camera:WorldToViewportPoint(root.Position - Vector3.new(0, 2.5, 0))

			local height = math.abs(bottomPoint.Y - topPoint.Y)
			if height < 4 then height = 4 end
			local width = height / 2
			local x = math.floor(screenPos.X - width / 2)
			local y = math.floor(topPoint.Y)
			local right = x + width
			local bottom = y + height

			pool.fill.Visible = Flags.ESPBoxes and Flags.ESPFill
			pool.fill.Position = Vector2.new(x, y)
			pool.fill.Size = Vector2.new(width, height)
			pool.fill.Color = EspDark

			local cornerLen = math.clamp(height * 0.22, 5, math.max(width / 2, 5))

			local segments = {
				{ x, y, x + cornerLen, y },
				{ x, y, x, y + cornerLen },
				{ right - cornerLen, y, right, y },
				{ right, y, right, y + cornerLen },
				{ x, bottom - cornerLen, x, bottom },
				{ x, bottom, x + cornerLen, bottom },
				{ right, bottom - cornerLen, right, bottom },
				{ right - cornerLen, bottom, right, bottom },
			}

			for i = 1, 8 do
				local seg = segments[i]
				local line = pool.corners[i]
				line.Visible = Flags.ESPBoxes
				line.Color = baseColor
				line.From = Vector2.new(seg[1], seg[2])
				line.To = Vector2.new(seg[3], seg[4])
			end

			pool.name.Visible = Flags.ESPNames
			local admEntry = AdmMon.Info[player]
			pool.name.Text = admEntry and ("[ADM] " .. player.DisplayName) or player.DisplayName
			pool.name.Position = Vector2.new(x + width / 2, y - 18)
			pool.name.Color = baseColor

			pool.distance.Visible = Flags.ESPDistance
			pool.distance.Text = tostring(math.floor(delta)) .. "m"
			pool.distance.Position = Vector2.new(x + width / 2, bottom + 2)
			pool.distance.Color = EspGray

			local heldTool = character:FindFirstChildOfClass("Tool")
			pool.toolText.Visible = Flags.ESPTool and heldTool ~= nil
			if heldTool then
				pool.toolText.Text = "[" .. heldTool.Name .. "]"
				pool.toolText.Position = Vector2.new(x + width / 2, bottom + 16)
				pool.toolText.Color = EspGray
			end

			local ratio = math.clamp(humanoid.Health / math.max(humanoid.MaxHealth, 1), 0, 1)
			local hpColor = Color3.fromRGB(
				math.floor(255 * (1 - ratio)),
				math.floor(235 * ratio),
				60
			)

			pool.healthBg.Visible = Flags.ESPHealth
			pool.healthBg.Position = Vector2.new(x - 7, y)
			pool.healthBg.Size = Vector2.new(3, height)
			pool.healthBg.Color = EspDark

			pool.healthFill.Visible = Flags.ESPHealth and ratio > 0
			pool.healthFill.Position = Vector2.new(x - 6, y + height * (1 - ratio))
			pool.healthFill.Size = Vector2.new(1, height * ratio)
			pool.healthFill.Color = hpColor

			pool.healthText.Visible = Flags.ESPHealth
			pool.healthText.Text = tostring(math.floor(humanoid.Health))
			local hpY = math.clamp(y + height * (1 - ratio) - 6, y - 6, bottom - 6)
			pool.healthText.Position = Vector2.new(x - 17, hpY)
			pool.healthText.Color = hpColor

			pool.tracer.Visible = Flags.ESPTracers
			pool.tracer.Color = baseColor
			pool.tracer.From = Vector2.new(viewport.X / 2, viewport.Y)
			pool.tracer.To = Vector2.new(x + width / 2, bottom)
		end)
	end
end

if espSupported then
	pcall(function()
		RunService:UnbindFromRenderStep(ESP_RENDER_NAME)
	end)
	RunService:BindToRenderStep(ESP_RENDER_NAME, Enum.RenderPriority.Camera.Value + 2, function()
		local ok = pcall(EspRender)
		if not ok then
			for _, pool in pairs(espCache) do
				pcall(function() HideEsp(pool) end)
			end
		end
	end)
end
local mouse = LocalPlayer:GetMouse()

local minimized = false
local restoreToken = 0
local function SetMinimized(state)
	minimized = state
	if state then
		restoreToken += 1
		root.Visible = false
		bubble.Visible = true
		bubble.Position = UDim2.new(0, 46, 0.5, -26)
	else
		restoreToken += 1
		local myToken = restoreToken
		bubble.Visible = false
		body.Visible = false
		footer.Visible = false
		root.Size = UDim2.fromOffset(660, 58)
		root.Visible = true
		Tween(root, 0.35, { Size = UDim2.fromOffset(660, 460) }, Enum.EasingStyle.Back).Completed:Once(function()
			if myToken == restoreToken and not minimized then
				body.Visible = true
				footer.Visible = true
			end
		end)
	end
end

minimizeBtn.MouseButton1Click:Connect(function()
	SetMinimized(true)
end)

Connect(UserInputService.InputBegan, function(input, gameProcessed)
	if gameProcessed then return end
	if input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode == Enum.KeyCode.RightShift then
		local isOpen = root.Visible
		root.Visible = not isOpen
		if not isOpen then
			minimized = false
			bubble.Visible = false
			body.Visible = true
			footer.Visible = true
			root.Size = UDim2.fromOffset(660, 460)
			Tween(blur, 0.3, { Size = 12 })
			root.Rotation = -1.6
			uiScale.Scale = 0.92
			root.GroupTransparency = 1
			Tween(uiScale, 0.45, { Scale = 1 }, Enum.EasingStyle.Back)
			Tween(root, 0.4, { Rotation = 0 }, Enum.EasingStyle.Back)
			Tween(root, 0.3, { GroupTransparency = 0 })
		else
			Tween(blur, 0.25, { Size = 0 })
			Tween(uiScale, 0.25, { Scale = 0.94 })
			Tween(root, 0.24, { Rotation = -1.6 })
			Tween(root, 0.22, { GroupTransparency = 1 })
		end
	elseif input.UserInputType == Enum.UserInputType.MouseButton1 and Flags.ClickTP then
		local char = LocalPlayer.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		if hrp and mouse.Hit then
			char:PivotTo(CFrame.new(mouse.Hit.Position + Vector3.new(0, 4, 0)))
		end
	end
end)

local dragging = false
local dragStart, startPos

headerBar.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		dragging = true
		dragStart = input.Position
		startPos = root.Position
		input.Changed:Connect(function()
			if input.UserInputState == Enum.UserInputState.End then
				dragging = false
			end
		end)
	end
end)

Connect(UserInputService.InputChanged, function(input)
	if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
		local delta = input.Position - dragStart
		root.Position = UDim2.new(
			startPos.X.Scale, startPos.X.Offset + delta.X,
			startPos.Y.Scale, startPos.Y.Offset + delta.Y
		)
	end
end)

closeBtn.MouseEnter:Connect(function()
	Tween(closeBtn, 0.15, { BackgroundColor3 = Color3.fromRGB(96, 48, 60), Rotation = 90 })
end)
closeBtn.MouseLeave:Connect(function()
	Tween(closeBtn, 0.15, { BackgroundColor3 = Theme.Card, Rotation = 0 })
end)

minimizeBtn.MouseEnter:Connect(function()
	Tween(minimizeBtn, 0.15, { BackgroundColor3 = Theme.CardHover })
end)
minimizeBtn.MouseLeave:Connect(function()
	Tween(minimizeBtn, 0.15, { BackgroundColor3 = Theme.Card })
end)

local bubbleDragging = false
local bubbleMoved = false
local bubbleDragStart, bubbleStartPos

bubble.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		bubbleDragging = true
		bubbleMoved = false
		bubbleDragStart = input.Position
		bubbleStartPos = bubble.Position
	end
end)

bubble.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		bubbleDragging = false
		if not bubbleMoved then
			SetMinimized(false)
		end
		bubbleMoved = false
	end
end)

Connect(UserInputService.InputChanged, function(input)
	if bubbleDragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
		local delta = input.Position - bubbleDragStart
		if math.abs(delta.X) + math.abs(delta.Y) > 4 then
			bubbleMoved = true
		end
		bubble.Position = UDim2.new(
			bubbleStartPos.X.Scale, bubbleStartPos.X.Offset + delta.X,
			bubbleStartPos.Y.Scale, bubbleStartPos.Y.Offset + delta.Y
		)
	end
end)

closeBtn.MouseButton1Click:Connect(function()
	Tween(blur, 0.25, { Size = 0 })
	Tween(uiScale, 0.25, { Scale = 0.94 })
	Tween(root, 0.24, { Rotation = -1.6 })
	Tween(root, 0.22, { GroupTransparency = 1 }).Completed:Once(function()
		root.Visible = false
		root.Rotation = 0
	end)
end)

task.spawn(function()
	local frames = 0
	local elapsed = 0
	Connect(RunService.Heartbeat, function(dt)
		frames += 1
		elapsed += dt
		if elapsed >= 1 then
			local ping = 0
			pcall(function()
				ping = math.floor(LocalPlayer:GetNetworkPing() * 1000)
			end)
			fpsLabel.Text = ("FPS: %d  |  Ping: %dms"):format(math.floor(frames / elapsed), ping)
			frames = 0
			elapsed = 0
		end
	end)
	end)

;(function()
	local page = Pages["Player"]

	SectionLabel(page, "Movimento")

	AddSlider(page, "WalkSpeed", "Velocidade", 16, 300, 16, function(v)
		Flags.WalkSpeed = v
	end)

	AddSlider(page, "JumpPower", "Força do pulo", 50, 300, 50, function(v)
		Flags.JumpPower = v
	end)

	AddToggle(page, "InfiniteJump", "Pulo infinito", false, function(state)
		Flags.InfiniteJump = state
	end)

	AddToggle(page, "ClickTP", "Teleporte (clique no chao)", false, function(state)
		Flags.ClickTP = state
	end)

	AddToggle(page, "Noclip", "Noclip (atravessar paredes)", false, function(state)
		Flags.Noclip = state
		if not state then
			local char = LocalPlayer.Character
			if char then
				for _, part in ipairs(char:GetDescendants()) do
					if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
						part.CanCollide = true
					end
				end
			end
		end
	end)

	AddToggle(page, "Fly", "Fly (voar - WASD, Espaco e Ctrl)", false, function(state)
		Flags.Fly = state
		if not state then
			StopFly()
		end
	end)

	AddSlider(page, "FlySpeed", "Velocidade do voo", 10, 300, 50, function(v)
		Flags.FlySpeed = v
	end)

	AddToggle(page, "Invisible", "Invisibilidade (estilo IY)", false, function(state)
		if state then
			local started = IyStartInvisibility()
			if started then
				Notify("Invisibilidade", "Voce agora esta invisivel para os outros.", "success")
			else
				Notify("Invisibilidade", "Nao foi possivel iniciar.", "danger")
			end
		elseif invisActive then
			if invisBusy then
				task.spawn(function()
					while invisBusy do
						task.wait(0.05)
					end
					if invisActive then
						IyTurnVisible()
						Notify("Invisibilidade", "Voce esta visivel novamente.", nil)
					end
				end)
			else
				IyTurnVisible()
				Notify("Invisibilidade", "Voce esta visivel novamente.", nil)
			end
		end
	end)

	AddToggle(page, "Hitbox", "Hitbox dos outros (estilo IY)", false, function(state)
		Flags.Hitbox = state
		local remote = GetHubRemote()
		if remote then
			if state then
				remote:FireServer("SetHitbox", Flags.HitboxSize or 10)
				Notify("Hitbox", "Servidor aplicando hitbox REAL (dano funciona).", "success")
			else
				remote:FireServer("ResetHitbox")
			end
		elseif state then
			Notify("Hitbox", "Modo visual apenas (instale o companion p/ dano real).", nil)
		else
			StopHitbox()
		end
	end)

	AddSlider(page, "HitboxSize", "Tamanho da hitbox", 2, 50, 10, function(v)
		Flags.HitboxSize = v
	end)

	AddToggle(page, "HitboxInvisible", "Hitbox invisivel (sem caixa na tela)", false, function(state)
		if not GetHubRemote() then
			Notify("Hitbox", state and "A caixa ficara oculta, o efeito continua." or "Caixa visivel novamente.", nil)
		end
	end)

	Paragraph(page, "Dica anti-falha",
		"Se a caixa fica grande mas o dano nao registra de longe, o jogo valida distancia no servidor deles. Nesse caso ative tambem o Alcance (aba Player), que estende sua arma e costuma resolver. O modo REAL via companion funciona apenas em jogos proprios.")

	AddToggle(page, "Reach", "Alcance da arma (estilo IY)", false, function(state)
		Flags.Reach = state
		local remote = GetHubRemote()
		if remote then
			if state then
				remote:FireServer("SetReach", Flags.ReachSize or 30)
				Notify("Alcance", "Servidor aplicando alcance REAL na sua arma.", "success")
			else
				remote:FireServer("ResetReach")
			end
		elseif state then
			Notify("Alcance", "Equipe uma arma para aplicar (modo local).", nil)
		else
			StopReach()
		end
	end)

	AddSlider(page, "ReachSize", "Comprimento do alcance", 5, 100, 30, function(v)
		Flags.ReachSize = v
		local remote = GetHubRemote()
		if remote and Flags.Reach then
			remote:FireServer("SetReach", v)
		end
	end)

	SectionLabel(page, "Personagem")

	AddButton(page, "Redefinir personagem", nil, function()
		local _, hum = GetCharacterParts()
		if hum then
			Notify("Personagem", "Personagem redefinido.", "success")
			hum.Health = 0
		end
	end)

	SectionLabel(page, "Jogadores")

	local selectedPlayer = nil
	local UpdateAvatarCard = nil

	local tpHolder = Create("Frame", {
		Size = UDim2.new(1, 0, 0, 42),
		BackgroundColor3 = Theme.Card,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		LayoutOrder = page.Add(function(o) return o end),
	}, page.Scroll)
	Corner(tpHolder, 9)

	local tpBtn = Create("TextButton", {
		Size = UDim2.new(1, 0, 0, 42),
		BackgroundColor3 = Theme.Card,
		BorderSizePixel = 0,
		Text = "",
		AutoButtonColor = false,
	}, tpHolder)

	Create("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(14, 0),
		Size = UDim2.new(0, 80, 1, 0),
		Font = Enum.Font.GothamMedium,
		Text = "Jogador",
		TextColor3 = Theme.Text,
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, tpBtn)

	local tpCurrent = Create("TextLabel", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -34, 0, 0),
		Size = UDim2.new(1, -150, 1, 0),
		Font = Enum.Font.Gotham,
		Text = "Selecione...",
		TextColor3 = Theme.SubText,
		TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Right,
		TextTruncate = Enum.TextTruncate.AtEnd,
	}, tpBtn)

	local tpChevron = Create("TextLabel", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -14, 0, 0),
		Size = UDim2.fromOffset(16, 42),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		Text = "v",
		TextColor3 = Theme.SubText,
		TextSize = 11,
		Rotation = 0,
	}, tpBtn)

	local tpBody = Create("Frame", {
		Position = UDim2.fromOffset(8, 46),
		Size = UDim2.new(1, -16, 0, 40),
		BackgroundTransparency = 1,
	}, tpHolder)

	local tpSearchStrokeHolder = Create("Frame", {
		Size = UDim2.new(1, 0, 0, 34),
		BackgroundColor3 = Theme.Background,
		BorderSizePixel = 0,
	}, tpBody)
	Corner(tpSearchStrokeHolder, 8)
	local tpSearchStroke = Outline(tpSearchStrokeHolder, Theme.Stroke, 0.5)

	local tpSearch = Create("TextBox", {
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamMedium,
		Text = "",
		PlaceholderText = "🔍  Pesquisar jogador...",
		PlaceholderColor3 = Theme.SubText,
		TextColor3 = Theme.Text,
		TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Left,
		ClearTextOnFocus = false,
	}, tpSearchStrokeHolder)
	Create("UIPadding", {
		PaddingLeft = UDim.new(0, 10),
		PaddingRight = UDim.new(0, 10),
	}, tpSearch)

	local tpList = Create("Frame", {
		Position = UDim2.fromOffset(0, 40),
		Size = UDim2.new(1, 0, 0, 0),
		BackgroundTransparency = 1,
	}, tpBody)

	Create("UIListLayout", {
		Padding = UDim.new(0, 4),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, tpList)

	local tpExpanded = false
	local tpOptionButtons = {}
	local lastMatches = {}

	local function TpResize(count, animated)
		local target = UDim2.new(1, 0, 0, 92 + count * 34)
		if animated then
			Tween(tpHolder, 0.28, { Size = target }, Enum.EasingStyle.Quart)
		else
			tpHolder.Size = target
		end
	end

	local function TpCollapse()
		tpExpanded = false
		tpSearch.Text = ""
		Tween(tpChevron, 0.25, { Rotation = 0 }, Enum.EasingStyle.Back)
		Tween(tpHolder, 0.25, { Size = UDim2.new(1, 0, 0, 42) }, Enum.EasingStyle.Quart)
	end

	local function PlayerMatches(plr, query)
		if query == "" then return true end
		local dn = string.lower(plr.DisplayName)
		local un = string.lower(plr.Name)
		return string.find(dn, query, 1, true) ~= nil or string.find(un, query, 1, true) ~= nil
	end

	local function SelectTpPlayer(plr)
		selectedPlayer = plr
		tpCurrent.Text = plr.DisplayName .. " (@" .. plr.Name .. ")"
		for other, btn in pairs(tpOptionButtons) do
			btn.TextColor3 = (other == selectedPlayer) and Theme.Accent or Theme.SubText
		end
		if Flags.SpectateSelected and spectTarget ~= plr then
			StartSpectate(plr)
		end
		if UpdateAvatarCard then
			pcall(UpdateAvatarCard, plr)
		end
	end

	local function TpRebuild()
		for _, child in ipairs(tpList:GetChildren()) do
			if child:IsA("TextButton") then
				child:Destroy()
			end
		end
		table.clear(tpOptionButtons)
		table.clear(lastMatches)

		local query = string.lower(tpSearch.Text)
		local count = 0
		for _, plr in ipairs(Players:GetPlayers()) do
			if plr ~= LocalPlayer and PlayerMatches(plr, query) then
				count = count + 1
				local index = count
				table.insert(lastMatches, plr)
				local optBtn = Create("TextButton", {
					Size = UDim2.new(1, 0, 0, 30),
					BackgroundColor3 = Theme.Background,
					BorderSizePixel = 0,
					Font = Enum.Font.Gotham,
					Text = "   " .. plr.DisplayName .. " (@" .. plr.Name .. ")",
					TextColor3 = (selectedPlayer == plr) and Theme.Accent or Theme.SubText,
					TextSize = 12,
					TextXAlignment = Enum.TextXAlignment.Left,
					TextTruncate = Enum.TextTruncate.AtEnd,
					AutoButtonColor = false,
					ZIndex = 3,
					LayoutOrder = index,
				}, tpList)
				Corner(optBtn, 6)
				tpOptionButtons[plr] = optBtn

				optBtn.MouseButton1Click:Connect(function()
					SelectTpPlayer(plr)
					TpCollapse()
				end)
			end
		end

		tpList.Size = UDim2.new(1, 0, 0, count * 34)
		return count
	end

	tpBtn.MouseEnter:Connect(function()
		Tween(tpBtn, 0.15, { BackgroundColor3 = Theme.CardHover })
	end)
	tpBtn.MouseLeave:Connect(function()
		Tween(tpBtn, 0.15, { BackgroundColor3 = Theme.Card })
	end)
	tpBtn.MouseButton1Click:Connect(function()
		tpExpanded = not tpExpanded
		if tpExpanded then
			local count = TpRebuild()
			Tween(tpChevron, 0.25, { Rotation = 180 }, Enum.EasingStyle.Back)
			TpResize(count, true)
			task.delay(0.05, function()
				pcall(function() tpSearch:CaptureFocus() end)
			end)
		else
			TpCollapse()
		end
	end)

	tpSearch.Focused:Connect(function()
		Tween(tpSearchStroke, 0.15, { Transparency = 0.1, Color = Theme.Accent })
	end)
	tpSearch.FocusLost:Connect(function(enterPressed)
		Tween(tpSearchStroke, 0.2, { Transparency = 0.5, Color = Theme.Stroke })
		if enterPressed and tpExpanded then
			local target = lastMatches[1]
			if target then
				SelectTpPlayer(target)
				TpCollapse()
			end
		end
	end)

	tpSearch:GetPropertyChangedSignal("Text"):Connect(function()
		if not tpExpanded then return end
		local count = TpRebuild()
		TpResize(count, false)
	end)

	Connect(Players.PlayerAdded, function()
		if tpExpanded then
			task.defer(function()
				local count = TpRebuild()
				TpResize(count, false)
			end)
		end
	end)

	Connect(Players.PlayerRemoving, function(left)
		if selectedPlayer == left then
			selectedPlayer = nil
			tpCurrent.Text = "Selecione..."
			if UpdateAvatarCard then
				pcall(UpdateAvatarCard, nil)
			end
		end
		if tpExpanded then
			task.defer(function()
				local count = TpRebuild()
				TpResize(count, false)
			end)
		end
	end)

	AddButton(page, "Teleportar ate o alvo selecionado", nil, function()
		if not selectedPlayer then
			Notify("Teleporte", "Selecione um jogador na lista acima.", "danger")
			return
		end

		local tchar = selectedPlayer.Character
		local troot = tchar and tchar:FindFirstChild("HumanoidRootPart")
		local mchar = LocalPlayer.Character
		local mroot = mchar and mchar:FindFirstChild("HumanoidRootPart")

		if troot and mroot then
			mroot.CFrame = troot.CFrame * CFrame.new(0, 0, 3)
			Notify("Teleporte", "Teleportado para " .. selectedPlayer.DisplayName .. ".", "success")
		else
			Notify("Teleporte", "Jogador sem personagem no momento.", "danger")
		end
	end)

	AddButton(page, "Copiar ferramentas do alvo selecionado", nil, function()
		CopyToolsFrom(selectedPlayer)
	end)

	AddToggle(page, "SpectateSelected", "Espiar jogador selecionado", false, function(state)
		if state then
			if selectedPlayer then
				StartSpectate(selectedPlayer)
			else
				Notify("Spectate", "Selecione um jogador na lista acima.", "danger")
				Options["SpectateSelected"].Set(false, true)
			end
		else
			StopSpectate()
		end
	end)

	SectionLabel(page, "Avatar")

	local avatarBusy = false
	local savedMyDescription = nil

	local avHolder = Create("Frame", {
		Size = UDim2.new(1, 0, 0, 164),
		BackgroundColor3 = Theme.Card,
		BorderSizePixel = 0,
		LayoutOrder = page.Add(function(o) return o end),
	}, page.Scroll)
	Corner(avHolder, 10)
	Outline(avHolder, Theme.Stroke, 0.75)

	local avThumb = Create("ImageLabel", {
		Position = UDim2.fromOffset(14, 14),
		Size = UDim2.fromOffset(52, 52),
		BackgroundTransparency = 1,
		Image = "",
	}, avHolder)
	Corner(avThumb, 26)
	local avThumbStroke = Outline(avThumb, Theme.Stroke, 0.5)

	local avName = Create("TextLabel", {
		Position = UDim2.fromOffset(78, 16),
		Size = UDim2.new(1, -92, 0, 18),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		Text = "Ninguem selecionado",
		TextColor3 = Theme.Text,
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
	}, avHolder)

	local avUser = Create("TextLabel", {
		Position = UDim2.fromOffset(78, 36),
		Size = UDim2.new(1, -92, 0, 14),
		BackgroundTransparency = 1,
		Font = Enum.Font.Gotham,
		Text = "Escolha um jogador na lista de Jogadores acima",
		TextColor3 = Theme.SubText,
		TextSize = 11,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
	}, avHolder)

	local function AvButton(props)
		local btn = Create("TextButton", props, avHolder)
		Corner(btn, 8)
		return btn
	end

	local avMainBtn = AvButton({
		Position = UDim2.fromOffset(12, 76),
		Size = UDim2.new(1, -24, 0, 34),
		BackgroundColor3 = Theme.Accent,
		BorderSizePixel = 0,
		Font = Enum.Font.GothamBold,
		Text = "Copiar avatar completo",
		TextColor3 = Color3.new(1, 1, 1),
		TextSize = 13,
		AutoButtonColor = false,
	})
	AccentGradient(avMainBtn, 90)

	local avClothesBtn = AvButton({
		Position = UDim2.fromOffset(12, 118),
		Size = UDim2.new(0.5, -18, 0, 32),
		BackgroundColor3 = Theme.CardHover,
		BorderSizePixel = 0,
		Font = Enum.Font.GothamMedium,
		Text = "So as roupas",
		TextColor3 = Theme.Text,
		TextSize = 12,
		AutoButtonColor = false,
	})

	local avRestoreBtn = AvButton({
		Position = UDim2.new(0.5, 6, 0, 118),
		Size = UDim2.new(0.5, -18, 0, 32),
		BackgroundColor3 = Theme.CardHover,
		BorderSizePixel = 0,
		Font = Enum.Font.GothamMedium,
		Text = "Restaurar meu visual",
		TextColor3 = Theme.SubText,
		TextSize = 12,
		AutoButtonColor = false,
	})

	for _, b in ipairs({ avClothesBtn, avRestoreBtn }) do
		b.MouseEnter:Connect(function()
			Tween(b, 0.15, { BackgroundColor3 = Theme.CardActive })
		end)
		b.MouseLeave:Connect(function()
			Tween(b, 0.15, { BackgroundColor3 = Theme.CardHover })
		end)
	end

	local function GetMyHumanoid()
		local char = LocalPlayer.Character
		return char, char and char:FindFirstChildOfClass("Humanoid")
	end

	local function FlashAvatarCard(success)
		local color = success and Theme.Success or Theme.Danger
		avThumbStroke.Color = color
		avThumbStroke.Transparency = 0
		task.delay(0.9, function()
			Tween(avThumbStroke, 0.6, { Color = Theme.Stroke, Transparency = 0.5 })
		end)
	end

	local function EnsureSavedDescription()
		if savedMyDescription then return end
		pcall(function()
			savedMyDescription = Players:GetHumanoidDescriptionFromUserId(LocalPlayer.UserId)
		end)
	end

	local function CloneLook(fromChar, toChar, includeAccessories)
		for _, clsName in ipairs({ "Shirt", "Pants", "ShirtGraphic" }) do
			local mine = toChar:FindFirstChildOfClass(clsName)
			if mine then pcall(function() mine:Destroy() end) end
			local theirs = fromChar:FindFirstChildOfClass(clsName)
			if theirs then
				pcall(function() theirs:Clone().Parent = toChar end)
			end
		end
		if not includeAccessories then return end

		local toHum = toChar:FindFirstChildOfClass("Humanoid")
		local fromHum = fromChar:FindFirstChildOfClass("Humanoid")

		local myColors = toChar:FindFirstChildOfClass("BodyColors")
		if myColors then pcall(function() myColors:Destroy() end) end
		local theirColors = fromChar:FindFirstChildOfClass("BodyColors")
		if theirColors then
			pcall(function() theirColors:Clone().Parent = toChar end)
		end

		local myHead = toChar:FindFirstChild("Head")
		local theirHead = fromChar:FindFirstChild("Head")
		local myFace = myHead and myHead:FindFirstChildOfClass("Decal")
		if myFace then pcall(function() myFace:Destroy() end) end
		local theirFace = theirHead and theirHead:FindFirstChildOfClass("Decal")
		if theirFace and myHead then
			pcall(function() theirFace:Clone().Parent = myHead end)
		end

		if toHum and fromHum then
			for _, scaleName in ipairs({ "BodyHeightScale", "BodyWidthScale", "BodyDepthScale", "HeadScale" }) do
				local fromVal = fromHum:FindFirstChild(scaleName)
				local toVal = toHum:FindFirstChild(scaleName)
				if fromVal and toVal then
					pcall(function() toVal.Value = fromVal.Value end)
				end
			end
		end

		for _, child in ipairs(toChar:GetChildren()) do
			if child:IsA("Accessory") then
				pcall(function() child:Destroy() end)
			end
		end
		for _, child in ipairs(fromChar:GetChildren()) do
			if child:IsA("Accessory") then
				pcall(function()
					local clone = child:Clone()
					if toHum and toHum.AddAccessory then
						toHum:AddAccessory(clone)
					else
						clone.Parent = toChar
					end
				end)
			end
		end
	end

	local function CopyAvatar(plr, clothesOnly)
		if avatarBusy then return end
		if not plr or not plr.Parent then
			Notify("Avatar", "Selecione um jogador na lista de Jogadores.", "danger")
			return
		end
		local mchar, hum = GetMyHumanoid()
		if not hum then
			Notify("Avatar", "Voce nao tem personagem agora.", "danger")
			return
		end
		local tchar = plr.Character
		if not tchar then
			Notify("Avatar", plr.DisplayName .. " esta sem personagem no momento.", "danger")
			return
		end

		avatarBusy = true
		task.spawn(function()
			local done = false
			if clothesOnly then
				done = pcall(CloneLook, tchar, mchar, false)
			else
				if hum.RigType == Enum.HumanoidRigType.R15 then
					EnsureSavedDescription()
					local okD, desc = pcall(Players.GetHumanoidDescriptionFromUserId, Players, plr.UserId)
					if okD and desc then
						done = pcall(hum.ApplyDescription, hum, desc)
					end
				end
				if not done then
					done = pcall(CloneLook, tchar, mchar, true)
				end
			end
			avatarBusy = false
			if done then
				FlashAvatarCard(true)
				local modo = clothesOnly and "Roupas de " or "Avatar de "
				Notify("Avatar", modo .. plr.DisplayName .. " aplicado! Na maioria dos jogos so voce ve a mudanca.", "success")
			else
				FlashAvatarCard(false)
				Notify("Avatar", "Nao foi possivel copiar o visual deste jogo.", "danger")
			end
		end)
	end

	local function RestoreMyAvatar()
		if avatarBusy then return end
		local _, hum = GetMyHumanoid()
		if not hum then
			Notify("Avatar", "Voce nao tem personagem agora.", "danger")
			return
		end
		if savedMyDescription and hum.RigType == Enum.HumanoidRigType.R15 then
			avatarBusy = true
			local ok = pcall(hum.ApplyDescription, hum, savedMyDescription)
			avatarBusy = false
			if ok then
				FlashAvatarCard(true)
				Notify("Avatar", "Seu perfil voltou ao normal!", "success")
				return
			end
		end
		FlashAvatarCard(false)
		Notify("Avatar", "Sem backup local. Use 'Redefinir personagem' para restaurar.", nil)
	end

	avMainBtn.MouseButton1Click:Connect(function()
		CopyAvatar(selectedPlayer, false)
	end)
	avClothesBtn.MouseButton1Click:Connect(function()
		CopyAvatar(selectedPlayer, true)
	end)
	avRestoreBtn.MouseButton1Click:Connect(function()
		RestoreMyAvatar()
	end)

	UpdateAvatarCard = function(plr)
		if plr and plr.Parent then
			avThumb.Image = "rbxthumb://type=AvatarBust&id=" .. tostring(plr.UserId) .. "&w=150&h=150"
			avName.Text = plr.DisplayName
			avUser.Text = "@" .. plr.Name .. "  ·  pronto para copiar o visual"
			avThumb.Size = UDim2.fromOffset(44, 44)
			Tween(avThumb, 0.3, { Size = UDim2.fromOffset(52, 52) }, Enum.EasingStyle.Back)
		else
			avThumb.Image = ""
			avName.Text = "Ninguem selecionado"
			avUser.Text = "Escolha um jogador na lista de Jogadores acima"
		end
	end
	UpdateAvatarCard(nil)
end)()

;(function()
	local page = Pages["Visuals"]

	SectionLabel(page, "Camera")

	AddSlider(page, "FOV", "Campo de visao", 60, 120, 70, function(v)
		local cam = workspace.CurrentCamera
		if cam then cam.FieldOfView = v end
	end)

	SectionLabel(page, "Iluminacao")

	AddToggle(page, "Fullbright", "Fullbright (tudo claro)", false, function(state)
		Lighting.Brightness = state and 3 or Originals.Brightness
		Lighting.GlobalShadows = not state and Originals.GlobalShadows or false
		Lighting.OutdoorAmbient = state and Color3.fromRGB(200, 200, 200) or Color3.fromRGB(128, 128, 128)
	end)

	AddToggle(page, "NoFog", "Sem neblina", false, function(state)
		Lighting.FogEnd = state and 1000000 or Originals.FogEnd
		Lighting.FogStart = state and 0 or Originals.FogStart
	end)

	AddDropdown(page, "QualityLevel", "Qualidade grafica",
		{ "Automatico", "Baixa", "Media", "Alta" }, "Automatico", function(choice)
		pcall(function()
			local map = {
				Automatico = Enum.QualityLevel.Automatic,
				Baixa = 1,
				Media = 10,
				Alta = 21,
			}
			settings().Rendering.QualityLevel = map[choice]
		end)
	end)

	SectionLabel(page, "ESP")

	AddToggle(page, "ESP", "ESP (ver jogadores)", false, function(state)
		Flags.ESP = state
		if state and not espSupported then
			Notify("ESP", "Este executor nao suporta Drawing.", "danger")
		end
	end)

	AddToggle(page, "ESPBoxes", "Caixas nos jogadores", true, function(state)
		Flags.ESPBoxes = state
	end)

	AddToggle(page, "ESPFill", "Fundo escuro nas caixas", true, function(state)
		Flags.ESPFill = state
	end)

	AddToggle(page, "ESPNames", "Nomes", true, function(state)
		Flags.ESPNames = state
	end)

	AddToggle(page, "ESPDistance", "Distancia", true, function(state)
		Flags.ESPDistance = state
	end)

	AddToggle(page, "ESPHealth", "Barra de vida + numero", true, function(state)
		Flags.ESPHealth = state
	end)

	AddToggle(page, "ESPTool", "Ferramenta na mao", false, function(state)
		Flags.ESPTool = state
	end)

	AddToggle(page, "ESPTracers", "Linhas ate os jogadores", false, function(state)
		Flags.ESPTracers = state
	end)

	AddToggle(page, "ESPTeamColors", "Cores por time (verde/vermelho)", false, function(state)
		Flags.ESPTeamColors = state
	end)

	AddToggle(page, "ESPVisibilityColor", "Escurecer quando atras de parede", false, function(state)
		Flags.ESPVisibilityColor = state
	end)

	AddToggle(page, "ESPTeamCheck", "Ignorar aliados (times)", false, function(state)
		Flags.ESPTeamCheck = state
	end)

	AddToggle(page, "AdmEspOnly", "ESP apenas em ADMs", false, function(state)
		Flags.AdmEspOnly = state
		if state then
			if not Flags.ESP and Options["ESP"] then
				Options["ESP"].Set(true)
			end
			Notify("ESP", "Mostrando somente ADMs no ESP.", "success")
		end
	end)

	AddSlider(page, "ESPMaxDistance", "Alcance maximo", 100, 5000, 1000, function(v)
		Flags.ESPMaxDistance = v
	end, "m")
end)()

;(function()
	local page = Pages["Mundo"]

	SectionLabel(page, "Fisica")

	AddSlider(page, "Gravity", "Gravidade", 20, 400, 196.2, function(v)
		workspace.Gravity = v
	end, "")

	SectionLabel(page, "Tempo")

	AddSlider(page, "ClockTime", "Hora do dia", 0, 24, math.floor(Originals.ClockTime), function(v)
		Lighting.ClockTime = v
	end, "h")

	SectionLabel(page, "Interacao")

	AddToggle(page, "AutoPrompt", "Interacao automatica (Prompts)", false, function(state)
		Flags.AutoPrompt = state
		if state then
			Notify("Interacao", "Acionando portas/loot/alavancas automaticamente.", "success")
		end
	end)

	AddSlider(page, "AutoPromptRadius", "Raio da interacao", 10, 100, 25, function(v)
		Flags.AutoPromptRadius = v
	end, "m")

	SectionLabel(page, "Waypoints")

	local wpNameHolder = Create("Frame", {
		Size = UDim2.new(1, 0, 0, 42),
		BackgroundColor3 = Theme.Card,
		BorderSizePixel = 0,
		LayoutOrder = page.Add(function(o) return o end),
	}, page.Scroll)
	Corner(wpNameHolder, 10)
	local wpNameStroke = Outline(wpNameHolder, Theme.Stroke, 0.6)

	local wpNameInput = Create("TextBox", {
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamMedium,
		Text = "",
		PlaceholderText = "📍  Nome do waypoint (opcional)",
		PlaceholderColor3 = Theme.SubText,
		TextColor3 = Theme.Text,
		TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Left,
		ClearTextOnFocus = false,
	}, wpNameHolder)
	Create("UIPadding", {
		PaddingLeft = UDim.new(0, 14),
		PaddingRight = UDim.new(0, 14),
	}, wpNameInput)
	wpNameInput.Focused:Connect(function()
		Tween(wpNameStroke, 0.15, { Transparency = 0.1, Color = Theme.Accent })
	end)
	wpNameInput.FocusLost:Connect(function()
		Tween(wpNameStroke, 0.2, { Transparency = 0.6, Color = Theme.Stroke })
	end)

	AddButton(page, "Salvar waypoint aqui", nil, function()
		local char = LocalPlayer.Character
		local root = char and char:FindFirstChild("HumanoidRootPart")
		if not root then
			Notify("Waypoints", "Personagem indisponivel.", "danger")
			return
		end
		local trimmed = string.gsub(wpNameInput.Text, "^%s+", ""):gsub("%s+$", "")
		local name = trimmed ~= "" and trimmed or ("Ponto " .. tostring(#Waypoints + 1))
		local p = root.Position
		table.insert(Waypoints, { name = name, x = p.X, y = p.Y, z = p.Z, pid = game.PlaceId })
		ScheduleSave()
		wpNameInput.Text = ""
		RebuildWpDrawings()
		if wpUIRefresh then wpUIRefresh() end
		Notify("Waypoints", "\"" .. name .. "\" salvo nesta posicao.", "success")
	end)

	local wpDropdown = AddDropdown(page, "WaypointTarget", "Waypoint", {}, "--", function() end)

	local function RefreshWpOptions()
		local opts = {}
		for _, item in ipairs(WpForCurrentPlace()) do
			table.insert(opts, item.name)
		end
		if #opts == 0 then
			opts = { "--" }
		end
		wpDropdown.SetOptions(opts)
	end
	wpUIRefresh = RefreshWpOptions
	RefreshWpOptions()

	local function SelectedWaypoint()
		local sel = wpDropdown.Get()
		if not sel or sel == "--" then return nil end
		for _, item in ipairs(WpForCurrentPlace()) do
			if item.name == sel then
				return Waypoints[item.index], item.index
			end
		end
		return nil
	end

	AddButton(page, "Ir ate o waypoint", nil, function()
		local wp = SelectedWaypoint()
		if not wp then
			Notify("Waypoints", "Nenhum waypoint selecionado.", "danger")
			return
		end
		local char = LocalPlayer.Character
		local root = char and char:FindFirstChild("HumanoidRootPart")
		if not root then
			Notify("Waypoints", "Personagem indisponivel.", "danger")
			return
		end
		root.CFrame = CFrame.new(wp.x, wp.y + 3, wp.z)
		Notify("Waypoints", "Teleportado para \"" .. wp.name .. "\".", "success")
	end)

	AddButton(page, "Remover waypoint", Theme.Danger, function()
		local wp, idx = SelectedWaypoint()
		if not wp then
			Notify("Waypoints", "Nenhum waypoint selecionado.", "danger")
			return
		end
		table.remove(Waypoints, idx)
		ScheduleSave()
		RebuildWpDrawings()
		if wpUIRefresh then wpUIRefresh() end
		Notify("Waypoints", "\"" .. wp.name .. "\" removido.", "success")
	end)

	AddToggle(page, "WaypointESP", "Ver waypoints no mundo", false, function(state)
		Flags.WaypointESP = state
		RebuildWpDrawings()
		if state then
			Notify("Waypoints", "Marcadores visiveis no mapa.", "success")
		end
	end)
end)()

;(function()
	local page = Pages["Misc"]

	Paragraph(page, "Legit Hub " .. VERSION,
		"Hub universal feito para os seus jogos. RightShift abre e fecha a janela. As configuracoes sao salvas automaticamente.")

	SectionLabel(page, "Servidor")

	AddToggle(page, "AntiAFK", "Anti-AFK (nunca ser expulso)", false, function(state)
		Flags.AntiAFK = state
		if state then
			Notify("Anti-AFK", "Voce nao sera expulso por inatividade.", "success")
		end
	end)

	AddButton(page, "Reentrar no servidor", nil, function()
		Notify("Servidor", "Reentrando no jogo...", nil)
		task.wait(0.5)
		TeleportService:Teleport(game.PlaceId, LocalPlayer)
	end)

	AddButton(page, "Copiar JobId", nil, function()
		if setclipboard then
			setclipboard(game.JobId)
			Notify("Copiado", "JobId copiado para a area de transferencia.", "success")
		else
			Notify("Erro", "setclipboard nao disponivel neste executor.", "danger")
		end
	end)

	SectionLabel(page, "Sistema")

	AddButton(page, "Checar atualizacao", nil, function()
		if UPDATE_URL == "" then
			Notify("Update", "Sem fonte configurada (rode pelo launcher).", "danger")
			return
		end
		task.spawn(function()
			local ok, body = pcall(function()
				return game:HttpGet(UPDATE_URL, true)
			end)
			if not ok or type(body) ~= "string" then
				Notify("Update", "Falha ao acessar a fonte remota.", "danger")
				return
			end
			local remote = string.match(body, 'local VERSION = "(.-)"')
			if not remote then
				Notify("Update", "Nao consegui ler a versao remota.", "danger")
				return
			end
			if remote == VERSION then
				Notify("Update", "Voce esta na versao mais recente (" .. VERSION .. ").", "success")
			else
				Notify("Update", "Nova versao disponivel: " .. remote .. ". Rode o launcher para atualizar.", "danger")
			end
		end)
	end)

	SectionLabel(page, "Performance")

	AddToggle(page, "PerfMode", "Modo performance (claro + FPS)", false, function(state)
		if state then
			if Options.Fullbright then
				Options.Fullbright.Set(true, true)
			end
			if Options.NoFog then
				Options.NoFog.Set(true, true)
			end
			pcall(function()
				setfpscap(240)
			end)
			Notify("Performance", "Fullbright + sem neblina ativos, FPS liberado ate 240.", "success")
		else
			if Options.Fullbright then
				Options.Fullbright.Set(false, true)
			end
			if Options.NoFog then
				Options.NoFog.Set(false, true)
			end
			pcall(function()
				setfpscap(60)
			end)
			Notify("Performance", "Graficos restaurados ao padrao.", nil)
		end
	end)

	AddButton(page, "Remover texturas do mapa", nil, function()
		Notify("Performance", "Removendo texturas... o jogo pode engasgar por alguns segundos.", nil)
		task.spawn(function()
			local removed = 0
			local processed = 0
			for _, obj in ipairs(workspace:GetDescendants()) do
				if obj:IsA("Decal") or obj:IsA("Texture") then
					obj.Transparency = 1
					removed += 1
				end
				processed += 1
				if processed % 3000 == 0 then
					task.wait()
				end
			end
			Notify("Performance", removed .. " texturas removidas. Reentre no servidor para voltar ao normal.", "success")
		end)
	end)

	SectionLabel(page, "Teclas de atalho")

	local kbHint = Create("TextLabel", {
		Size = UDim2.new(1, 0, 0, 16),
		BackgroundTransparency = 1,
		Font = Enum.Font.Gotham,
		Text = "Clique para definir a tecla  |  clique direito remove",
		TextColor3 = Theme.SubText,
		TextSize = 11,
		TextXAlignment = Enum.TextXAlignment.Left,
		LayoutOrder = page.Add(function(o) return o end),
	}, page.Scroll)

	for _, bind in ipairs(KEYBINDABLE) do
		local optName, optText = bind[1], bind[2]
		local row = Create("TextButton", {
			Size = UDim2.new(1, 0, 0, 38),
			BackgroundColor3 = Theme.Card,
			BorderSizePixel = 0,
			Text = "",
			AutoButtonColor = false,
			ClipsDescendants = true,
			LayoutOrder = page.Add(function(o) return o end),
		}, page.Scroll)
		Corner(row, 10)
		Outline(row, Theme.Stroke, 0.6)

		Create("TextLabel", {
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(14, 0),
			Size = UDim2.new(1, -120, 1, 0),
			Font = Enum.Font.GothamMedium,
			Text = optText,
			TextColor3 = Theme.Text,
			TextSize = 12,
			TextXAlignment = Enum.TextXAlignment.Left,
		}, row)

		local pill = Create("TextLabel", {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -10, 0.5, 0),
			Size = UDim2.fromOffset(84, 24),
			BackgroundColor3 = Theme.Surface,
			Font = Enum.Font.GothamBold,
			Text = Keybinds[optName] or "--",
			TextColor3 = Theme.SubText,
			TextSize = 11,
		}, row)
		Corner(pill, 7)

		KeybindRows[optName] = pill

		row.MouseEnter:Connect(function()
			Tween(row, 0.15, { BackgroundColor3 = Theme.CardHover })
			Tween(kbHint, 0.15, { TextTransparency = 1 })
		end)
		row.MouseLeave:Connect(function()
			Tween(row, 0.18, { BackgroundColor3 = Theme.Card })
			Tween(kbHint, 0.15, { TextTransparency = 0 })
		end)
		row.MouseButton1Click:Connect(function()
			Ripple(row, UserInputService:GetMouseLocation())
			StartKeyCapture(optName)
		end)
		row.MouseButton2Click:Connect(function()
			SetKeybind(optName, nil)
		end)
	end

	RefreshKeybindUI = function()
		for name, label in pairs(KeybindRows) do
			label.Text = Keybinds[name] or "--"
		end
	end

	SectionLabel(page, "Aparencia")

	local swatchHolder = Create("Frame", {
		Size = UDim2.new(1, 0, 0, 46),
		BackgroundColor3 = Theme.Surface,
		BorderSizePixel = 0,
		LayoutOrder = page.Add(function(o) return o end),
	}, page.Scroll)
	Corner(swatchHolder, 10)
	Outline(swatchHolder, Theme.Stroke, 0.55)

	Create("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.new(0, 14, 0, 0),
		Size = UDim2.new(0.5, 0, 1, 0),
		Font = Enum.Font.GothamMedium,
		Text = "Cor de destaque",
		TextColor3 = Theme.Text,
		TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, swatchHolder)

	local swatchRow = Create("Frame", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -12, 0.5, 0),
		Size = UDim2.fromOffset(#ACCENT_PRESETS * 30 + 4, 30),
		BackgroundTransparency = 1,
	}, swatchHolder)
	Create("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 4),
		VerticalAlignment = Enum.VerticalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, swatchRow)

	local swatchRefs = {}
	for idx, preset in ipairs(ACCENT_PRESETS) do
		local dot = Create("TextButton", {
			Size = UDim2.fromOffset(26, 26),
			BackgroundColor3 = preset.a,
			Text = "",
			AutoButtonColor = false,
			BorderSizePixel = 0,
			LayoutOrder = idx,
		}, swatchRow)
		Corner(dot, 13)
		local dotStroke = Outline(dot, Color3.new(1, 1, 1), 1)
		dotStroke.Transparency = 1
		swatchRefs[preset.name] = dotStroke
		Connect(dot.MouseEnter, function()
			Tween(dot, 0.15, { Size = UDim2.fromOffset(29, 29) })
			Tween(dotStroke, 0.15, { Transparency = (CurrentAccentName == preset.name) and 0 or 0.55 })
		end)
		Connect(dot.MouseLeave, function()
			Tween(dot, 0.15, { Size = UDim2.fromOffset(26, 26) })
			Tween(dotStroke, 0.15, { Transparency = (CurrentAccentName == preset.name) and 0 or 1 })
		end)
		Connect(dot.Activated, function()
			if CurrentAccentName ~= preset.name then
				ApplyAccentPreset(preset.name)
				Notify("Aparencia", "Cor de destaque: " .. preset.name .. ".", "success")
			end
			Tween(dot, 0.08, { Size = UDim2.fromOffset(23, 23) })
			task.delay(0.09, function()
				Tween(dot, 0.18, { Size = UDim2.fromOffset(29, 29), EasingStyle = Enum.EasingStyle.Back })
			end)
		end)
	end

	RefreshSwatches = function()
		for name, stroke in pairs(swatchRefs) do
			stroke.Transparency = (name == CurrentAccentName) and 0 or 1
			stroke.Thickness = (name == CurrentAccentName) and 1.6 or 1
		end
	end
	RefreshSwatches()

	RegisterOption("AccentPreset", {
		Type = "Custom",
		Get = function()
			return CurrentAccentName
		end,
		Set = function(v)
			if type(v) == "string" then
				ApplyAccentPreset(v)
			end
		end,
	})

	SectionLabel(page, "Monitor de ADMs")

	local statusHolder = Create("Frame", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Theme.Surface,
		BorderSizePixel = 0,
		LayoutOrder = page.Add(function(o) return o end),
	}, page.Scroll)
	Corner(statusHolder, 10)
	Outline(statusHolder, Theme.Stroke, 0.55)

	Create("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(14, 8),
		Size = UDim2.new(1, -28, 0, 18),
		Font = Enum.Font.GothamBold,
		Text = "ADMs no servidor",
		TextColor3 = Theme.Text,
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, statusHolder)

	local admStatusLabel = Create("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(14, 28),
		Size = UDim2.new(1, -28, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Font = Enum.Font.Gotham,
		Text = "Nenhum ADM detectado neste servidor.",
		TextColor3 = Theme.SubText,
		TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextWrapped = true,
	}, statusHolder)
	Create("UIPadding", { PaddingBottom = UDim.new(0, 10) }, statusHolder)

	AdmMon.OnUpdate = function()
		if Flags.AdmMonitor then
			admStatusLabel.TextColor3 = Theme.SubText
			admStatusLabel.Text = BuildListText()
		end
	end

	AddToggle(page, "AdmMonitor", "Monitorar ADMs", true, function(state)
		Flags.AdmMonitor = state
		if state then
			ScanAll()
			AdmMon.OnUpdate()
			Notify("Monitor de ADMs", "Vigiando dono e staff do jogo.", "success")
		else
			for plr in pairs(AdmMon.Info) do
				RemoveAdm(plr, false)
			end
			admStatusLabel.TextColor3 = Theme.SubText
			admStatusLabel.Text = "Monitor desligado."
		end
	end)

	AddToggle(page, "AdmNotifyJoin", "Avisar quando ADM entrar", true, function(state)
		Flags.AdmNotifyJoin = state
	end)

	AddToggle(page, "AdmNotifyLeave", "Avisar quando ADM sair", false, function(state)
		Flags.AdmNotifyLeave = state
	end)

	AddToggle(page, "AdmSound", "Tocar som ao detectar", false, function(state)
		Flags.AdmSound = state
	end)

	AddToggle(page, "AdmPanel", "Painel lateral fixo de ADMs", false, function(state)
		AdmMon.SetPanel(state)
	end)

	AddSlider(page, "AdmMinRank", "Rank minimo no grupo", 100, 255, 250, function(v)
		Flags.AdmMinRank = v
		if Flags.AdmMonitor then
			ScanAll()
		end
	end)

	AddButton(page, "Verificar agora", nil, function()
		if not Flags.AdmMonitor then
			Notify("Monitor de ADMs", "O monitor esta desligado.", "danger")
			return
		end
		ScanAll()
		task.delay(1.5, AdmMon.OnUpdate)
		Notify("Monitor de ADMs", "Varredura manual concluida.", "success")
	end)

	local targetDropdown = AddDropdown(page, "AdmTarget", "Jogador", {}, "--", function() end)

	local function RefreshTargetOptions()
		local opts = {}
		for _, plr in ipairs(Players:GetPlayers()) do
			if plr ~= LocalPlayer then
				table.insert(opts, plr.Name)
			end
		end
		table.sort(opts)
		targetDropdown.SetOptions(opts)
	end
	table.insert(Connections, Players.PlayerAdded:Connect(RefreshTargetOptions))
	table.insert(Connections, Players.PlayerRemoving:Connect(RefreshTargetOptions))
	RefreshTargetOptions()

	AddButton(page, "Marcar jogador como ADM", nil, function()
		local selName = targetDropdown.Get()
		local plr = selName and Players:FindFirstChild(selName)
		if not plr or plr == LocalPlayer then
			Notify("Monitor de ADMs", "Selecione um jogador na lista acima.", "danger")
			return
		end
		AdmMon.Custom[plr.UserId] = plr.Name
		ScheduleSave()
		ScanPlayer(plr)
		Notify("Marcado", plr.Name .. " agora e tratado como ADM.", "success")
	end)

	AddButton(page, "Remover marcacao de ADM", nil, function()
		local selName = targetDropdown.Get()
		local plr = selName and Players:FindFirstChild(selName)
		if not plr or not AdmMon.Custom[plr.UserId] then
			Notify("Monitor de ADMs", "Esse jogador nao esta marcado.", "danger")
			return
		end
		AdmMon.Custom[plr.UserId] = nil
		ScheduleSave()
		ScanPlayer(plr)
		Notify("Removido", "Marcacao de " .. plr.Name .. " removida.", "success")
	end)

	SectionLabel(page, "Config")

	AddButton(page, "Salvar configuracoes agora", nil, function()
		ScheduleSave()
		Notify("Config", "Configuracoes salvas com sucesso.", "success")
	end)

	local importOverlay
	local importInput

	AddButton(page, "Exportar perfil (copia codigo)", nil, function()
		if not setclipboard then
			Notify("Erro", "setclipboard nao disponivel neste executor.", "danger")
			return
		end
		local data = {}
		for name, opt in pairs(Options) do
			data[name] = opt.Get()
		end
		setclipboard(HttpService:JSONEncode({ flags = data, keys = Keybinds }))
		Notify("Config", "Perfil copiado! Mande pra quem quiser usar seu setup.", "success")
	end)

	AddButton(page, "Importar perfil (colar codigo)", nil, function()
		importOverlay.Visible = true
		importInput.Text = ""
		task.defer(function()
			importInput:CaptureFocus()
		end)
	end)

	importOverlay = Create("Frame", {
		Name = "ImportOverlay",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.45,
		Visible = false,
		ZIndex = 50,
	}, root)

	local importCard = Create("Frame", {
		Name = "ImportCard",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(390, 270),
		BackgroundColor3 = Theme.Surface,
		BorderSizePixel = 0,
		ZIndex = 51,
	}, importOverlay)
	Corner(importCard, 14)
	Outline(importCard, Theme.Stroke, 0.4)

	Create("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(18, 12),
		Size = UDim2.new(1, -36, 0, 20),
		Font = Enum.Font.GothamBold,
		Text = "📥 Importar perfil",
		TextColor3 = Theme.Text,
		TextSize = 15,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 52,
	}, importCard)

	Create("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(18, 36),
		Size = UDim2.new(1, -36, 0, 16),
		Font = Enum.Font.Gotham,
		Text = "Cole abaixo o codigo de perfil exportado:",
		TextColor3 = Theme.SubText,
		TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 52,
	}, importCard)

	importInput = Create("TextBox", {
		Position = UDim2.fromOffset(18, 60),
		Size = UDim2.new(1, -36, 0, 120),
		BackgroundColor3 = Theme.Background,
		BorderSizePixel = 0,
		Font = Enum.Font.Code,
		Text = "",
		PlaceholderText = "{\"flags\":...}",
		PlaceholderColor3 = Theme.SubText,
		TextColor3 = Theme.Text,
		TextSize = 11,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		MultiLine = true,
		ClearTextOnFocus = false,
		ZIndex = 52,
	}, importCard)
	Corner(importInput, 8)
	Outline(importInput, Theme.Stroke, 0.5)

	local importCancel = Create("TextButton", {
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -100, 1, -14),
		Size = UDim2.fromOffset(86, 32),
		BackgroundColor3 = Theme.Card,
		Font = Enum.Font.GothamBold,
		Text = "Cancelar",
		TextColor3 = Theme.SubText,
		TextSize = 12,
		ZIndex = 52,
	}, importCard)
	Corner(importCancel, 8)

	local importOk = Create("TextButton", {
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -14, 1, -14),
		Size = UDim2.fromOffset(86, 32),
		BackgroundColor3 = Theme.Accent,
		Font = Enum.Font.GothamBold,
		Text = "Importar",
		TextColor3 = Color3.new(1, 1, 1),
		TextSize = 12,
		ZIndex = 52,
	}, importCard)
	Corner(importOk, 8)

	importCancel.MouseButton1Click:Connect(function()
		importOverlay.Visible = false
	end)

	importOk.MouseButton1Click:Connect(function()
		local ok, decoded = pcall(function()
			return HttpService:JSONDecode(importInput.Text)
		end)
		if not ok or type(decoded) ~= "table" then
			Notify("Importar", "Codigo invalido (nao parece um perfil do LegitHub).", "danger")
			return
		end
		ApplyConfigData(decoded)
		ScheduleSave()
		importOverlay.Visible = false
		importInput.Text = ""
		Notify("Config", "Perfil importado e aplicado com sucesso!", "success")
	end)

	AddButton(page, "Descarregar Legit Hub", Theme.Danger, function()
		_G.LegitHub.Unload()
	end)
end)()

for name in pairs(Pages) do
	Pages[name].Button.MouseButton1Click:Connect(function()
		SelectTab(name)
	end)
end

SelectTab("Player")

local function Unload()
	for _, conn in ipairs(Connections) do
		pcall(function() conn:Disconnect() end)
	end
	table.clear(Connections)
	HubAlive = false
	table.clear(AdmMon.Info)
	AdmMon.OnUpdate = nil
	pcall(function() blur:Destroy() end)
	Lighting.Brightness = Originals.Brightness
	Lighting.FogEnd = Originals.FogEnd
	Lighting.FogStart = Originals.FogStart
	Lighting.ClockTime = Originals.ClockTime
	Lighting.GlobalShadows = Originals.GlobalShadows
	workspace.Gravity = Originals.Gravity
	if workspace.CurrentCamera then
		workspace.CurrentCamera.FieldOfView = Originals.FOV
	end
	local _, hum = GetCharacterParts()
	if hum then
		hum.WalkSpeed = 16
		hum.UseJumpPower = true
		hum.JumpPower = 50
	end
	pcall(function()
		RunService:UnbindFromRenderStep("LegitHub_ESP")
	end)
	StopFly()
	StopHitbox()
	StopReach()
	StopSpectate(true)
	Flags.WaypointESP = false
	pcall(function()
		RunService:UnbindFromRenderStep(wpEspBind)
	end)
	ClearWpDrawings()
	Flags.AutoPrompt = false
	Flags.AntiAFK = false
	if invisActive then
		IyTurnVisible()
	end
	for player in pairs(espCache) do
		RemoveEsp(player)
	end
	screenGui:Destroy()
	_G.LegitHub = nil
	print("[LegitHub] descarregado.")
end

_G.LegitHub = {
	Version = VERSION,
	Unload = Unload,
	Notify = Notify,
	Flags = Flags,
	Options = Options,
}

root.Visible = false
root.GroupTransparency = 1
uiScale.Scale = 0.9

-- ============ Splash screen ============
do
local splash = Create("CanvasGroup", {
	Name = "Splash",
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = Color3.fromRGB(18, 15, 19),
	BorderSizePixel = 0,
	GroupTransparency = 0,
	ZIndex = 60,
}, screenGui)

local function SplashGlow(pos, size, rot)
	local wash = Create("Frame", {
		Position = pos,
		Size = size,
		BackgroundColor3 = Theme.Accent,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Rotation = rot,
		ZIndex = 60,
	}, splash)
	Create("UIGradient", {
		Color = ColorSequence.new(Theme.Accent, Theme.Accent2),
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.5, 0.82),
			NumberSequenceKeypoint.new(1, 1),
		}),
	}, wash)
	return wash
end

SplashGlow(UDim2.fromOffset(-120, -90), UDim2.fromOffset(520, 340), 20)
SplashGlow(UDim2.new(1, -160, 1, -240), UDim2.fromOffset(460, 300), -25)

local splashLogo = Create("CanvasGroup", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.new(0.5, 0, 0.5, -74),
	Size = UDim2.fromOffset(68, 68),
	BackgroundColor3 = Theme.Accent,
	BorderSizePixel = 0,
	GroupTransparency = 1,
	ZIndex = 61,
}, splash)
Corner(splashLogo, 20)
AccentGradient(splashLogo, 135)

Create("TextLabel", {
	BackgroundTransparency = 1,
	Size = UDim2.fromScale(1, 1),
	Font = Enum.Font.GothamBlack,
	Text = "L",
	TextColor3 = Color3.new(1, 1, 1),
	TextSize = 36,
	ZIndex = 62,
}, splashLogo)

local splashTitle = Create("TextLabel", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.new(0.5, 0, 0.5, -14),
	Size = UDim2.fromOffset(320, 34),
	BackgroundTransparency = 1,
	Font = Enum.Font.GothamBlack,
	Text = "LEGIT HUB",
	TextColor3 = Theme.Text,
	TextSize = 30,
	ZIndex = 61,
}, splash)
	Create("UIGradient", {
		Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(214, 198, 206)),
		Rotation = 90,
	}, splashTitle)

Create("TextLabel", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.new(0.5, 0, 0.5, 12),
	Size = UDim2.fromOffset(320, 16),
	BackgroundTransparency = 1,
	Font = Enum.Font.GothamBold,
	Text = "U N I V E R S A L   T O O L K I T",
	TextColor3 = Theme.SubText,
	TextSize = 10,
	ZIndex = 61,
}, splash)

local splashPill = Create("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.new(0.5, 0, 0.5, 38),
	Size = UDim2.fromOffset(58, 22),
	BackgroundColor3 = Theme.Card,
	BorderSizePixel = 0,
	ZIndex = 61,
}, splash)
Corner(splashPill, 11)
Create("TextLabel", {
	BackgroundTransparency = 1,
	Size = UDim2.fromScale(1, 1),
	Font = Enum.Font.GothamBold,
	Text = VERSION,
	TextColor3 = Theme.Accent2,
	TextSize = 11,
	ZIndex = 62,
}, splashPill)

local splashBarBg = Create("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.new(0.5, 0, 0.5, 84),
	Size = UDim2.fromOffset(230, 4),
	BackgroundColor3 = Theme.TrackOff,
	BorderSizePixel = 0,
	ZIndex = 61,
}, splash)
Corner(splashBarBg, 2)

local splashBarFill = Create("Frame", {
	Size = UDim2.fromScale(0, 1),
	BackgroundColor3 = Theme.Accent,
	BorderSizePixel = 0,
	ZIndex = 62,
}, splashBarBg)
Corner(splashBarFill, 2)

Create("TextLabel", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.new(0.5, 0, 0.5, 108),
	Size = UDim2.fromOffset(420, 16),
	BackgroundTransparency = 1,
	Font = Enum.Font.GothamMedium,
	Text = "v2.6 — teclas de atalho, busca, bolha flutuante, hitbox real e mais",
	TextColor3 = Theme.SubText,
	TextSize = 11,
	TextTransparency = 0.25,
	ZIndex = 61,
}, splash)

splashLogo.GroupTransparency = 1
splashLogo.Size = UDim2.fromOffset(40, 40)
task.defer(function()
	Tween(splashLogo, 0.55, { GroupTransparency = 0 }, Enum.EasingStyle.Quart)
	Tween(splashLogo, 0.6, { Size = UDim2.fromOffset(68, 68) }, Enum.EasingStyle.Back)
	Tween(splashBarFill, 1.7, { Size = UDim2.fromScale(1, 1) }, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
end)

task.delay(2.1, function()
	Tween(splash, 0.45, { GroupTransparency = 1 }).Completed:Once(function()
		splash:Destroy()

		root.Visible = true
		Tween(uiScale, 0.5, { Scale = 1 }, Enum.EasingStyle.Back)
		Tween(root, 0.4, { GroupTransparency = 0 })

		Notify("Bem-vindo!", "Legit Hub " .. VERSION .. " carregado com sucesso.", "success")

		task.delay(2.5, function()
			if root.Visible then
				Tween(blur, 0.4, { Size = 0 })
			end
		end)
		Tween(blur, 0.6, { Size = 10 })
	end)
end)
end

task.delay(0.15, function()
	LoadConfig()
end)

print("[LegitHub] " .. VERSION .. " carregado!")
