--[[
	LegitHub - Companheiro de Servidor (v2)
	Onde instalar: Roblox Studio > ServerScriptService > Script (normal, nao LocalScript)

	Funcoes:
	1. Copia de ferramentas 100% funcional (clone roda no servidor de verdade).
	2. Hitbox expansiva REAL nos outros jogadores: cria uma parte invisivel
	   soldada ao personagem (sem deformar ninguem). Scripts de dano que usam
	   Touched resolvem hit.Parent.Humanoid normalmente -> dano registra de longe,
	   mesmo em jogos que ignoram o HumanoidRootPart.
	3. Alcance de arma REAL (Handle da sua tool redimensionado no servidor).

	Protocolo LegitHubTools:
		FireServer(nomeAlvo)                      -> copia ferramentas
		FireServer("SetHitbox", tamanho)          -> liga hitbox global (2-50)
		FireServer("ResetHitbox")                 -> desliga hitbox
		FireServer("SetReach", comprimento)       -> liga alcance do proprio (5-100)
		FireServer("ResetReach")                  -> desliga alcance

	OBS: para mudar o tamanho com a hitbox ligada, basta mandar SetHitbox de novo.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local remote = ReplicatedStorage:FindFirstChild("LegitHubTools")
if not remote then
	remote = Instance.new("RemoteEvent")
	remote.Name = "LegitHubTools"
	remote.Parent = ReplicatedStorage
end

local rateLimit = {}

local function RateOk(player)
	local now = os.clock()
	if now - (rateLimit[player] or 0) < 0.5 then
		return false
	end
	rateLimit[player] = now
	return true
end

Players.PlayerRemoving:Connect(function(player)
	rateLimit[player] = nil
end)

local HITBOX_NAME = "LegitHubHitbox"

local hitboxEnabled = false
local hitboxSize = 10
local hitboxParts = {} -- [player] = parte criada no character atual

local reachState = {}
local reachSaved = {}

Players.PlayerRemoving:Connect(function(player)
	reachState[player] = nil
	hitboxParts[player] = nil
end)

local function RemoveHitboxPart(player)
	local part = hitboxParts[player]
	if part then
		pcall(function() part:Destroy() end)
		hitboxParts[player] = nil
	end
end

local function ApplyHitboxToCharacter(player)
	local character = player.Character
	if not character then return end
	local hrp = character:FindFirstChild("HumanoidRootPart")

	if not hitboxEnabled then
		RemoveHitboxPart(player)
		return
	end
	if not hrp then return end

	local part = hitboxParts[player]
	if part and (not part.Parent or part.Parent ~= character) then
		part = nil
		hitboxParts[player] = nil
	end

	if not part then
		part = Instance.new("Part")
		part.Name = HITBOX_NAME
		part.Transparency = 1
		part.CanCollide = false
		part.CanTouch = true
		part.CanQuery = true
		part.Massless = true
		part.Size = Vector3.new(hitboxSize, hitboxSize, hitboxSize)
		part.CFrame = hrp.CFrame
		part.Parent = character
		local weld = Instance.new("WeldConstraint")
		weld.Name = "LegitHubHitboxWeld"
		weld.Part0 = part
		weld.Part1 = hrp
		weld.Parent = part
		hitboxParts[player] = part
	else
		part.Size = Vector3.new(hitboxSize, hitboxSize, hitboxSize)
	end
end

local function ApplyAllHitboxes()
	for _, player in ipairs(Players:GetPlayers()) do
		pcall(function() ApplyHitboxToCharacter(player) end)
	end
end

local function ApplyReachToTool(player, tool)
	local length = reachState[player]
	if not length then return end
	pcall(function()
		local handle = tool:FindFirstChild("Handle")
		if not handle or not handle:IsA("BasePart") then return end
		if not reachSaved[handle] then
			reachSaved[handle] = {
				size = handle.Size,
				massless = handle.Massless,
				grip = tool.GripPos,
			}
		end
		handle.Massless = true
		handle.Size = Vector3.new(0.5, 0.5, length)
		tool.GripPos = Vector3.new(0, 0, 0)
	end)
end

local function ApplyReachToPlayer(player)
	local character = player.Character
	if not character then return end
	for _, obj in ipairs(character:GetChildren()) do
		if obj:IsA("Tool") then
			ApplyReachToTool(player, obj)
		end
	end
end

local function ResetAllReaches()
	for handle, saved in pairs(reachSaved) do
		pcall(function()
			if handle.Parent then
				handle.Size = saved.size
				handle.Massless = saved.massless
				local tool = handle:FindFirstAncestorOfClass("Tool")
				if tool then
					tool.GripPos = saved.grip
				end
			end
		end)
	end
	table.clear(reachSaved)
	table.clear(reachState)
end

local function SetupPlayer(player)
	player.CharacterAdded:Connect(function(character)
		task.defer(function()
			ApplyHitboxToCharacter(player)
			ApplyReachToPlayer(player)
		end)
		character.ChildAdded:Connect(function(child)
			if child:IsA("Tool") then
				task.defer(function()
					ApplyReachToTool(player, child)
				end)
			end
		end)
	end)
	player.Backpack.ChildAdded:Connect(function(child)
		if child:IsA("Tool") then
			task.defer(function()
				ApplyReachToTool(player, child)
			end)
		end
	end)
	if player.Character then
		ApplyHitboxToCharacter(player)
		ApplyReachToPlayer(player)
	end
end

for _, player in ipairs(Players:GetPlayers()) do
	SetupPlayer(player)
end
Players.PlayerAdded:Connect(SetupPlayer)

local function CollectSources(target)
	local sources = {}
	if target.Backpack then
		for _, tool in ipairs(target.Backpack:GetChildren()) do
			if tool:IsA("Tool") then
				table.insert(sources, tool)
			end
		end
	end
	if target.Character then
		for _, tool in ipairs(target.Character:GetChildren()) do
			if tool:IsA("Tool") then
				table.insert(sources, tool)
			end
		end
	end
	return sources
end

local function HandleCopy(requester, targetName)
	if type(targetName) ~= "string" then return end
	if not RateOk(requester) then return end
	if not requester:FindFirstChild("Backpack") then return end

	local target = nil
	for _, player in ipairs(Players:GetPlayers()) do
		if player.Name == targetName or player.DisplayName == targetName then
			target = player
			break
		end
	end
	if not target then return end

	for _, tool in ipairs(CollectSources(target)) do
		tool.Archivable = true
		pcall(function()
			local clone = tool:Clone()
			if clone then
				clone.Parent = requester.Backpack
			end
		end)
	end
end

remote.OnServerEvent:Connect(function(requester, command, value)
	if typeof(command) == "Instance" or type(command) == "userdata" then
		return
	end

	if type(command) == "string" and value == nil and command ~= "ResetHitbox" and command ~= "ResetReach" then
		HandleCopy(requester, command)
		return
	end

	if requester.Parent ~= Players then return end

	if command == "SetHitbox" and type(value) == "number" then
		hitboxSize = math.clamp(math.floor(value + 0.5), 2, 50)
		hitboxEnabled = true
		ApplyAllHitboxes()
	elseif command == "ResetHitbox" then
		hitboxEnabled = false
		for _, player in ipairs(Players:GetPlayers()) do
			RemoveHitboxPart(player)
		end
	elseif command == "SetReach" and type(value) == "number" then
		reachState[requester] = math.clamp(math.floor(value + 0.5), 5, 100)
		ApplyReachToPlayer(requester)
	elseif command == "ResetReach" then
		reachState[requester] = nil
		for handle, saved in pairs(reachSaved) do
			pcall(function()
				local tool = handle and handle:FindFirstAncestorOfClass("Tool")
				if tool and tool.Parent and tool.Parent.Parent == requester then
					if handle.Parent then
						handle.Size = saved.size
						handle.Massless = saved.massless
					end
					tool.GripPos = saved.grip
					reachSaved[handle] = nil
				end
			end)
		end
	end
end)

print("[LegitHub] Companheiro de servidor v2 ativo: copia de ferramentas, hitbox REAL (parte soldada invisivel) e alcance REAL.")
