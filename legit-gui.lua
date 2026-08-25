local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local LocalPlayer = Players.LocalPlayer

if _G.LegitGUI and _G.LegitGUI.ScreenGui then
	_G.LegitGUI.ScreenGui:Destroy()
end

local theme = {
	background = Color3.fromRGB(24, 24, 34),
	element = Color3.fromRGB(32, 32, 45),
	elementHover = Color3.fromRGB(42, 42, 60),
	text = Color3.fromRGB(220, 220, 235),
	subText = Color3.fromRGB(150, 150, 175),
	accent = Color3.fromRGB(88, 101, 242),
}

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "LegitGUI"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

local ok = pcall(function()
	screenGui.Parent = game:GetService("CoreGui")
end)
if not ok then
	screenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
end

local main = Instance.new("Frame")
main.Name = "Main"
main.AnchorPoint = Vector2.new(0.5, 0.5)
main.Position = UDim2.fromScale(0.5, 0.5)
main.Size = UDim2.fromOffset(420, 300)
main.BackgroundColor3 = theme.background
main.BorderSizePixel = 0
main.Active = true
main.Parent = screenGui

Instance.new("UICorner", main).CornerRadius = UDim.new(0, 10)

local stroke = Instance.new("UIStroke")
stroke.Color = Color3.fromRGB(60, 60, 85)
stroke.Thickness = 1
stroke.Parent = main

local topbar = Instance.new("Frame")
topbar.Name = "Topbar"
topbar.Size = UDim2.new(1, 0, 0, 38)
topbar.BackgroundTransparency = 1
topbar.Active = true
topbar.Parent = main

local title = Instance.new("TextLabel")
title.BackgroundTransparency = 1
title.Position = UDim2.fromOffset(14, 0)
title.Size = UDim2.new(1, -110, 1, 0)
title.Font = Enum.Font.GothamBold
title.Text = "Legit GUI"
title.TextColor3 = theme.text
title.TextSize = 15
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = topbar

local minimizeBtn = Instance.new("TextButton")
minimizeBtn.Size = UDim2.fromOffset(26, 26)
minimizeBtn.Position = UDim2.new(1, -64, 0, 6)
minimizeBtn.BackgroundColor3 = theme.element
minimizeBtn.Text = "-"
minimizeBtn.Font = Enum.Font.GothamBold
minimizeBtn.TextColor3 = theme.text
minimizeBtn.TextSize = 14
minimizeBtn.Parent = topbar
Instance.new("UICorner", minimizeBtn).CornerRadius = UDim.new(0, 6)

local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.fromOffset(26, 26)
closeBtn.Position = UDim2.new(1, -32, 0, 6)
closeBtn.BackgroundColor3 = theme.element
closeBtn.Text = "X"
closeBtn.Font = Enum.Font.GothamBold
closeBtn.TextColor3 = Color3.fromRGB(255, 110, 110)
closeBtn.TextSize = 12
closeBtn.Parent = topbar
Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 6)

local content = Instance.new("ScrollingFrame")
content.Name = "Content"
content.Position = UDim2.fromOffset(10, 44)
content.Size = UDim2.new(1, -20, 1, -62)
content.BackgroundTransparency = 1
content.BorderSizePixel = 0
content.ScrollBarThickness = 3
content.ScrollBarImageColor3 = Color3.fromRGB(90, 90, 130)
content.CanvasSize = UDim2.new()
content.AutomaticCanvasSize = Enum.AutomaticSize.Y
content.Parent = main

local listLayout = Instance.new("UIListLayout")
listLayout.Padding = UDim.new(0, 6)
listLayout.SortOrder = Enum.SortOrder.LayoutOrder
listLayout.Parent = content

local footer = Instance.new("TextLabel")
footer.AnchorPoint = Vector2.new(0, 1)
footer.Position = UDim2.new(0, 0, 1, 0)
footer.Size = UDim2.new(1, 0, 0, 18)
footer.BackgroundTransparency = 1
footer.Font = Enum.Font.Gotham
footer.TextSize = 11
footer.TextColor3 = theme.subText
footer.Text = "RightShift abre/fecha a janela"
footer.Parent = main

local order = 0
local function nextOrder()
	order += 1
	return order
end

local function newElement(className, height)
	local element = Instance.new(className)
	element.Size = UDim2.new(1, 0, 0, height)
	element.BackgroundColor3 = theme.element
	element.BorderSizePixel = 0
	element.LayoutOrder = nextOrder()
	element.Parent = content
	Instance.new("UICorner", element).CornerRadius = UDim.new(0, 6)
	return element
end

local function addSection(name)
	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 0, 22)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.Text = string.upper(name)
	label.TextColor3 = theme.subText
	label.TextSize = 12
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.LayoutOrder = nextOrder()
	label.Parent = content
end

local function addButton(text, callback)
	local btn = newElement("TextButton", 36)
	btn.Font = Enum.Font.Gotham
	btn.TextSize = 14
	btn.TextColor3 = theme.text
	btn.Text = "   " .. text
	btn.MouseEnter:Connect(function()
		btn.BackgroundColor3 = theme.elementHover
	end)
	btn.MouseLeave:Connect(function()
		btn.BackgroundColor3 = theme.element
	end)
	btn.MouseButton1Click:Connect(function()
		task.spawn(callback)
	end)
	return btn
end

local function addToggle(text, default, callback)
	local btn = newElement("TextButton", 36)
	btn.Text = ""

	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Position = UDim2.fromOffset(12, 0)
	label.Size = UDim2.new(1, -70, 1, 0)
	label.Font = Enum.Font.Gotham
	label.TextSize = 14
	label.TextColor3 = theme.text
	label.Text = text
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Parent = btn

	local switchBg = Instance.new("Frame")
	switchBg.AnchorPoint = Vector2.new(1, 0.5)
	switchBg.Position = UDim2.new(1, -10, 0.5, 0)
	switchBg.Size = UDim2.fromOffset(38, 20)
	switchBg.BackgroundColor3 = theme.elementHover
	switchBg.BorderSizePixel = 0
	switchBg.Parent = btn
	Instance.new("UICorner", switchBg).CornerRadius = UDim.new(1, 0)

	local switchDot = Instance.new("Frame")
	switchDot.AnchorPoint = Vector2.new(0, 0.5)
	switchDot.Position = UDim2.new(0, 3, 0.5, 0)
	switchDot.Size = UDim2.fromOffset(14, 14)
	switchDot.BackgroundColor3 = theme.subText
	switchDot.BorderSizePixel = 0
	switchDot.Parent = switchBg
	Instance.new("UICorner", switchDot).CornerRadius = UDim.new(1, 0)

	local state = false

	local function render()
		local pos = state and UDim2.new(1, -17, 0.5, 0) or UDim2.new(0, 3, 0.5, 0)
		TweenService:Create(switchDot, TweenInfo.new(0.15), { Position = pos }):Play()
		TweenService:Create(switchBg, TweenInfo.new(0.15), {
			BackgroundColor3 = state and theme.accent or theme.elementHover,
		}):Play()
	end

	if default then
		state = true
		render()
	end

	btn.MouseButton1Click:Connect(function()
		state = not state
		render()
		task.spawn(callback, state)
	end)

	return {
		Set = function(value)
			state = value and true or false
			render()
		end,
		Get = function() return state end,
	}
end

local function addSlider(text, min, max, default, callback)
	local holder = newElement("Frame", 48)

	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Position = UDim2.fromOffset(12, 4)
	label.Size = UDim2.new(1, -24, 0, 18)
	label.Font = Enum.Font.Gotham
	label.TextSize = 13
	label.TextColor3 = theme.text
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Text = text .. ": " .. tostring(default)
	label.Parent = holder

	local bar = Instance.new("Frame")
	bar.Position = UDim2.new(0, 12, 0, 30)
	bar.Size = UDim2.new(1, -24, 0, 8)
	bar.BackgroundColor3 = theme.elementHover
	bar.BorderSizePixel = 0
	bar.Parent = holder
	Instance.new("UICorner", bar).CornerRadius = UDim.new(1, 0)

	local fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale(0, 1)
	fill.BackgroundColor3 = theme.accent
	fill.BorderSizePixel = 0
	fill.Parent = bar
	Instance.new("UICorner", fill).CornerRadius = UDim.new(1, 0)

	local sliding = false

	local function update(inputPos)
		local alpha = math.clamp((inputPos.X - bar.AbsolutePosition.X) / bar.AbsoluteSize.X, 0, 1)
		local value = math.floor(min + (max - min) * alpha + 0.5)
		fill.Size = UDim2.fromScale(alpha, 1)
		label.Text = text .. ": " .. value
		task.spawn(callback, value)
	end

	bar.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			sliding = true
			update(input.Position)
		end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if sliding and input.UserInputType == Enum.UserInputType.MouseMovement then
			update(input.Position)
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			sliding = false
		end
	end)

	local alpha = ((default or min) - min) / (max - min)
	fill.Size = UDim2.fromScale(alpha, 1)
end

local dragging = false
local dragStart, startPos

topbar.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		dragging = true
		dragStart = input.Position
		startPos = main.Position
		input.Changed:Connect(function()
			if input.UserInputState == Enum.UserInputState.End then
				dragging = false
			end
		end)
	end
end)

UserInputService.InputChanged:Connect(function(input)
	if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
		local delta = input.Position - dragStart
		main.Position = UDim2.new(
			startPos.X.Scale, startPos.X.Offset + delta.X,
			startPos.Y.Scale, startPos.Y.Offset + delta.Y
		)
	end
end)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	if input.KeyCode == Enum.KeyCode.RightShift then
		screenGui.Enabled = not screenGui.Enabled
	end
end)

local minimized = false
minimizeBtn.MouseButton1Click:Connect(function()
	minimized = not minimized
	content.Visible = not minimized
	main.Size = minimized and UDim2.fromOffset(420, 38) or UDim2.fromOffset(420, 300)
end)

closeBtn.MouseButton1Click:Connect(function()
	screenGui:Destroy()
	_G.LegitGUI = nil
end)

addSection("Player")

addSlider("FOV da câmera", 60, 120, 70, function(value)
	workspace.CurrentCamera.FieldOfView = value
end)

_G.LegitInfiniteJump = false
UserInputService.JumpRequest:Connect(function()
	if not _G.LegitInfiniteJump then return end
	local character = LocalPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
	end
end)

addToggle("Pulo infinito", false, function(state)
	_G.LegitInfiniteJump = state
end)

addSection("Utilidades")

addToggle("Fullbright", false, function(state)
	local lighting = game:GetService("Lighting")
	lighting.Brightness = state and 2 or 1
	lighting.ClockTime = state and 14 or lighting.ClockTime
	lighting.FogEnd = state and 1000000 or 100000
	lighting.GlobalShadows = not state
end)

addButton("Copiar JobId do servidor", function()
	if setclipboard then
		setclipboard(game.JobId)
	end
end)

addButton("Reentrar no servidor", function()
	game:GetService("TeleportService"):Teleport(game.PlaceId, LocalPlayer)
end)

_G.LegitGUI = { ScreenGui = screenGui }

print("[LegitGUI] carregado com sucesso!")
