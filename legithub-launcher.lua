-- =====================================================
--  LegitHub Launcher v2.1
--
--  Validação de key + carregamento do hub.
--  Versão robusta com tratamento de erros.
-- =====================================================

local RAW_URL = "https://raw.githubusercontent.com/KaioGroot/legithub/main/legithub-v2.lua"
local CACHE_FILE = "legithub_main.lua"
local LICENSE_CACHE = "legithub_license.json"

-- Firebase Firestore REST API
local FIREBASE_API_KEY = "AIzaSyAubOqbL3_pNU9F3tCDVboN_9MCwitjXCQ"
local FIREBASE_PROJECT_ID = "legithub-20dd6"
local FIRESTORE_URL = "https://firestore.googleapis.com/v1/projects/"
	.. FIREBASE_PROJECT_ID
	.. "/databases/(default)/documents/licenses/"

_G.LegitHubUpdateURL = RAW_URL

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")

-- =====================================================
--  Funções HTTP
-- =====================================================

local function httpGet(url)
	local ok, result = pcall(function()
		return game:HttpGet(url, true)
	end)
	if ok and type(result) == "string" then
		return result
	end
	local req = http_request or request or (http and http.request)
	if req then
		local okReq, resp = pcall(req, { Url = url, Method = "GET" })
		if okReq and resp and type(resp.Body) == "string" then
			return resp.Body
		end
	end
	return nil
end

-- =====================================================
--  HWID
-- =====================================================

local function GetHWID()
	local player = Players.LocalPlayer
	local hwid = ""
	pcall(function()
		hwid = game.PlaceId .. "_" .. player.UserId .. "_" .. player.Name
	end)
	if hwid == "" then
		hwid = "fallback_" .. tostring(tick())
	end
	return hwid
end

-- =====================================================
--  Sistema de Key (cache local)
-- =====================================================

local function LoadSavedKey()
	local ok, data = pcall(function()
		if isfile and isfile(LICENSE_CACHE) then
			return HttpService:JSONDecode(readfile(LICENSE_CACHE))
		end
		return nil
	end)
	if ok and data then return data end
	return nil
end

local function SaveKey(key, plan, expiresAt)
	local data = {
		key = key,
		plan = plan,
		expiresAt = expiresAt,
		savedAt = os.time(),
	}
	pcall(function()
		writefile(LICENSE_CACHE, HttpService:JSONEncode(data))
	end)
end

local function ClearSavedKey()
	pcall(function()
		if isfile and isfile(LICENSE_CACHE) then
			delfile(LICENSE_CACHE)
		end
	end)
end

-- =====================================================
--  Validação da key (Firestore REST API)
-- =====================================================

local function ValidateKey(key)
	if not key or key == "" then
		return { valid = false, error = "Key vazia" }
	end

	local hwid = GetHWID()
	local url = FIRESTORE_URL .. key .. "?key=" .. FIREBASE_API_KEY

	print("[LegitHub] Validando key: " .. key)

	local response = httpGet(url)
	if not response then
		print("[LegitHub] Sem conexão com Firestore")
		return { valid = false, error = "Sem conexão com o servidor" }
	end

	-- Key não existe
	if string.find(response, "NOT_FOUND") or string.find(response, "not found") then
		print("[LegitHub] Key não encontrada no Firestore")
		return { valid = false, error = "Key não encontrada" }
	end

	-- Parse da resposta
	local ok, doc = pcall(function()
		return HttpService:JSONDecode(response)
	end)

	if not ok or not doc or not doc.fields then
		print("[LegitHub] Resposta inválida do Firestore")
		return { valid = false, error = "Resposta inválida do servidor" }
	end

	local fields = doc.fields

	local function getStr(name)
		return fields[name] and fields[name].stringValue
	end

	local status = getStr("status")
	local plan = getStr("plan")
	local hwidStored = getStr("hwid")
	local expiresAt = getStr("expiresAt")

	-- Verificar status
	if status == "revoked" then
		return { valid = false, error = "Key revogada" }
	end

	if status == "expired" then
		return { valid = false, error = "Key expirada" }
	end

	-- Verificar expiração
	if expiresAt then
		local pattern = "(%d+)%-(%d+)%-(%d+)T(%d+):(%d+):(%d+)"
		local y, m, d, h, min, s = string.match(expiresAt, pattern)
		if y then
			local okT, expiresAtTime = pcall(function()
				return os.time({
					year = tonumber(y), month = tonumber(m), day = tonumber(d),
					hour = tonumber(h), min = tonumber(min), sec = tonumber(s),
				})
			end)
			if okT and expiresAtTime and expiresAtTime < os.time() then
				return { valid = false, error = "Key expirada" }
			end
		end
	end

	-- Verificar HWID
	if hwidStored and hwidStored ~= "" and hwidStored ~= hwid then
		return { valid = false, error = "Key associada a outro dispositivo" }
	end

	print("[LegitHub] Key válida! Plano: " .. tostring(plan))

	return {
		valid = true,
		plan = plan or "weekly",
		expiresAt = expiresAt,
	}
end

-- =====================================================
--  Tela de Key (simplificada)
-- =====================================================

local function ShowKeyScreen()
	local player = Players.LocalPlayer
	local playerGui = player:FindFirstChildOfClass("PlayerGui")
	if not playerGui then return false, "PlayerGui não encontrado" end

	-- Destruir tela antiga se existir
	local old = playerGui:FindFirstChild("LegitHubKeyScreen")
	if old then old:Destroy() end

	local gui = Instance.new("ScreenGui")
	gui.Name = "LegitHubKeyScreen"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 999999
	gui.Parent = playerGui

	-- Fundo
	local overlay = Instance.new("Frame")
	overlay.Size = UDim2.fromScale(1, 1)
	overlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	overlay.BackgroundTransparency = 0.3
	overlay.BorderSizePixel = 0
	overlay.Parent = gui

	-- Card
	local card = Instance.new("Frame")
	card.Size = UDim2.fromOffset(420, 320)
	card.Position = UDim2.new(0.5, -210, 0.5, -160)
	card.BackgroundColor3 = Color3.fromRGB(22, 18, 26)
	card.BorderSizePixel = 0
	card.Parent = gui

	Instance.new("UICorner", card).CornerRadius = UDim.new(0, 14)

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(212, 175, 55)
	stroke.Thickness = 1
	stroke.Transparency = 0.6
	stroke.Parent = card

	-- Título
	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, -40, 0, 36)
	title.Position = UDim2.fromOffset(20, 18)
	title.BackgroundTransparency = 1
	title.Text = "LEGIT HUB"
	title.TextColor3 = Color3.fromRGB(212, 175, 55)
	title.TextSize = 22
	title.Font = Enum.Font.GothamBold
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Parent = card

	local subtitle = Instance.new("TextLabel")
	subtitle.Size = UDim2.new(1, -40, 0, 18)
	subtitle.Position = UDim2.fromOffset(20, 52)
	subtitle.BackgroundTransparency = 1
	subtitle.Text = "Ative sua key para acessar o VIP"
	subtitle.TextColor3 = Color3.fromRGB(160, 155, 170)
	subtitle.TextSize = 13
	subtitle.Font = Enum.Font.Gotham
	subtitle.TextXAlignment = Enum.TextXAlignment.Left
	subtitle.Parent = card

	-- Label
	local keyLabel = Instance.new("TextLabel")
	keyLabel.Size = UDim2.new(1, -40, 0, 16)
	keyLabel.Position = UDim2.fromOffset(20, 82)
	keyLabel.BackgroundTransparency = 1
	keyLabel.Text = "SUA KEY"
	keyLabel.TextColor3 = Color3.fromRGB(120, 115, 135)
	keyLabel.TextSize = 11
	keyLabel.Font = Enum.Font.GothamBold
	keyLabel.TextXAlignment = Enum.TextXAlignment.Left
	keyLabel.Parent = card

	-- Input
	local inputBg = Instance.new("Frame")
	inputBg.Size = UDim2.new(1, -40, 0, 40)
	inputBg.Position = UDim2.fromOffset(20, 100)
	inputBg.BackgroundColor3 = Color3.fromRGB(30, 26, 38)
	inputBg.BorderSizePixel = 0
	inputBg.Parent = card

	Instance.new("UICorner", inputBg).CornerRadius = UDim.new(0, 8)

	local inputStroke = Instance.new("UIStroke")
	inputStroke.Color = Color3.fromRGB(60, 55, 75)
	inputStroke.Thickness = 1
	inputStroke.Transparency = 0.3
	inputStroke.Parent = inputBg

	local input = Instance.new("TextBox")
	input.Size = UDim2.new(1, -20, 1, 0)
	input.Position = UDim2.fromOffset(10, 0)
	input.BackgroundTransparency = 1
	input.Text = ""
	input.PlaceholderText = "LH-XXXX-XXXX-XXXX"
	input.PlaceholderColor3 = Color3.fromRGB(80, 75, 95)
	input.TextColor3 = Color3.fromRGB(240, 235, 250)
	input.TextSize = 14
	input.Font = Enum.Font.Code
	input.ClearTextOnFocus = false
	input.TextXAlignment = Enum.TextXAlignment.Left
	input.Parent = inputBg

	-- Botão Ativar
	local btnAtivar = Instance.new("TextButton")
	btnAtivar.Size = UDim2.new(1, -40, 0, 40)
	btnAtivar.Position = UDim2.fromOffset(20, 152)
	btnAtivar.BackgroundColor3 = Color3.fromRGB(212, 175, 55)
	btnAtivar.BorderSizePixel = 0
	btnAtivar.Text = "ATIVAR KEY"
	btnAtivar.TextColor3 = Color3.fromRGB(18, 15, 19)
	btnAtivar.TextSize = 14
	btnAtivar.Font = Enum.Font.GothamBold
	btnAtivar.AutoButtonColor = true
	btnAtivar.Parent = card

	Instance.new("UICorner", btnAtivar).CornerRadius = UDim.new(0, 8)

	-- Status
	local status = Instance.new("TextLabel")
	status.Size = UDim2.new(1, -40, 0, 16)
	status.Position = UDim2.fromOffset(20, 200)
	status.BackgroundTransparency = 1
	status.Text = ""
	status.TextColor3 = Color3.fromRGB(255, 100, 100)
	status.TextSize = 12
	status.Font = Enum.Font.Gotham
	status.TextXAlignment = Enum.TextXAlignment.Left
	status.Parent = card

	-- Link de compra
	local buyFrame = Instance.new("Frame")
	buyFrame.Size = UDim2.new(1, -40, 0, 60)
	buyFrame.Position = UDim2.fromOffset(20, 228)
	buyFrame.BackgroundColor3 = Color3.fromRGB(28, 24, 34)
	buyFrame.BorderSizePixel = 0
	buyFrame.Parent = card

	Instance.new("UICorner", buyFrame).CornerRadius = UDim.new(0, 8)

	local buyTitle = Instance.new("TextLabel")
	buyTitle.Size = UDim2.new(1, -20, 0, 18)
	buyTitle.Position = UDim2.fromOffset(10, 6)
	buyTitle.BackgroundTransparency = 1
	buyTitle.Text = "Não tem key?"
	buyTitle.TextColor3 = Color3.fromRGB(160, 155, 170)
	buyTitle.TextSize = 12
	buyTitle.Font = Enum.Font.Gotham
	buyTitle.TextXAlignment = Enum.TextXAlignment.Left
	buyTitle.Parent = buyFrame

	local buyLink = Instance.new("TextLabel")
	buyLink.Size = UDim2.new(1, -20, 0, 18)
	buyLink.Position = UDim2.fromOffset(10, 24)
	buyLink.BackgroundTransparency = 1
	buyLink.Text = "Compre em: https://landing-page-omega-sable-27.vercel.app"
	buyLink.TextColor3 = Color3.fromRGB(212, 175, 55)
	buyLink.TextSize = 12
	buyLink.Font = Enum.Font.GothamBold
	buyLink.TextXAlignment = Enum.TextXAlignment.Left
	buyLink.Parent = buyFrame

	local buyDesc = Instance.new("TextLabel")
	buyDesc.Size = UDim2.new(1, -20, 0, 14)
	buyDesc.Position = UDim2.fromOffset(10, 42)
	buyDesc.BackgroundTransparency = 1
	buyDesc.Text = "Semanal R$9,90 | Mensal R$24,90 | Anual R$149,90"
	buyDesc.TextColor3 = Color3.fromRGB(120, 115, 135)
	buyDesc.TextSize = 10
	buyDesc.Font = Enum.Font.Gotham
	buyDesc.TextXAlignment = Enum.TextXAlignment.Left
	buyDesc.Parent = buyFrame

	-- Botão grátis
	local btnFree = Instance.new("TextButton")
	btnFree.Size = UDim2.new(1, -40, 0, 28)
	btnFree.Position = UDim2.fromOffset(20, 292)
	btnFree.BackgroundTransparency = 1
	btnFree.Text = "Continuar grátis →"
	btnFree.TextColor3 = Color3.fromRGB(100, 95, 115)
	btnFree.TextSize = 11
	btnFree.Font = Enum.Font.Gotham
	btnFree.Parent = card

	-- Variáveis de controle
	local result = nil
	local validated = false
	local validating = false

	-- Função de validação
	local function DoValidate(key)
		if validating then return end
		if not key or key == "" then
			status.Text = "Digite uma key válida"
			status.TextColor3 = Color3.fromRGB(255, 100, 100)
			return
		end

		validating = true
		btnAtivar.Text = "VALIDANDO..."
		btnAtivar.BackgroundColor3 = Color3.fromRGB(80, 75, 95)
		status.Text = "Conectando ao servidor..."
		status.TextColor3 = Color3.fromRGB(160, 155, 170)

		-- Valida em thread separada pra não travar UI
		task.spawn(function()
			local res = ValidateKey(key)

			validating = false

			if res.valid then
				SaveKey(key, res.plan, res.expiresAt)
				status.Text = "✓ Key ativada! Plano: " .. string.upper(res.plan)
				status.TextColor3 = Color3.fromRGB(80, 220, 120)
				result = res
				validated = true

				task.delay(1.5, function()
					gui:Destroy()
				end)
			else
				status.Text = "✗ " .. (res.error or "Key inválida")
				status.TextColor3 = Color3.fromRGB(255, 100, 100)
				btnAtivar.Text = "ATIVAR KEY"
				btnAtivar.BackgroundColor3 = Color3.fromRGB(212, 175, 55)
			end
		end)
	end

	-- Conexões
	btnAtivar.MouseButton1Click:Connect(function()
		DoValidate(input.Text)
	end)

	input.FocusLost:Connect(function(enterPressed)
		if enterPressed then
			DoValidate(input.Text)
		end
	end)

	btnFree.MouseButton1Click:Connect(function()
		result = { valid = true, plan = "free" }
		validated = true
		gui:Destroy()
	end)

	-- Espera até validar ou pular
	while not validated do
		task.wait(0.1)
	end

	return validated, result
end

-- =====================================================
--  Erro Fatal
-- =====================================================

local function ShowFatal(msg)
	msg = "[LegitHub] ERRO AO INICIAR\n\n" .. msg
	print(msg)
	pcall(function()
		local pg = Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
		if not pg then return end
		local velho = pg:FindFirstChild("LegitHubFatal")
		if velho then velho:Destroy() end
		local gui = Instance.new("ScreenGui")
		gui.Name = "LegitHubFatal"
		gui.ResetOnSpawn = false
		gui.DisplayOrder = 999999
		gui.Parent = pg
		local fundo = Instance.new("Frame")
		fundo.Size = UDim2.fromOffset(680, 300)
		fundo.Position = UDim2.new(0.5, -340, 0.5, -150)
		fundo.BackgroundColor3 = Color3.fromRGB(18, 15, 19)
		fundo.BorderSizePixel = 0
		fundo.Parent = gui
		Instance.new("UICorner", fundo).CornerRadius = UDim.new(0, 12)
		local texto = Instance.new("TextLabel")
		texto.Size = UDim2.new(1, -28, 1, -24)
		texto.Position = UDim2.fromOffset(14, 12)
		texto.BackgroundTransparency = 1
		texto.TextColor3 = Color3.fromRGB(255, 120, 130)
		texto.TextSize = 13
		texto.Font = Enum.Font.Code
		texto.TextWrapped = true
		texto.TextXAlignment = Enum.TextXAlignment.Left
		texto.TextYAlignment = Enum.TextYAlignment.Top
		texto.Text = msg
		texto.Parent = fundo
	end)
end

-- =====================================================
--  FLUXO PRINCIPAL
-- =====================================================

print("[LegitHub] Launcher v2.1 iniciado")

-- 1. Verificar key salva
local savedKey = LoadSavedKey()
local plan = "free"
local keyValid = false

if savedKey and savedKey.key then
	print("[LegitHub] Key salva encontrada: " .. savedKey.key)

	-- Validar em thread separada
	task.spawn(function()
		local res = ValidateKey(savedKey.key)
		if res.valid then
			plan = res.plan or savedKey.plan or "free"
			keyValid = true
			SaveKey(savedKey.key, plan, res.expiresAt)
			print("[LegitHub] Key válida! Plano: " .. plan)
		else
			print("[LegitHub] Key salva inválida: " .. tostring(res.error))
			ClearSavedKey()
		end
	end)

	-- Esperar um pouco pela validação
	task.wait(2)
end

-- 2. Se não tem key válida → tela de ativação
if not keyValid then
	print("[LegitHub] Mostrando tela de ativação...")
	local ok, res = ShowKeyScreen()
	if ok and res then
		plan = res.plan or "free"
		print("[LegitHub] Plano selecionado: " .. plan)
	else
		plan = "free"
		print("[LegitHub] Modo grátis")
	end
end

-- 3. Passar plano pro hub via _G
_G.LegitHubPlan = plan
print("[LegitHub] Plano final: " .. plan)

-- 4. Baixar/atualizar hub
print("[LegitHub] Baixando hub...")
local remote = httpGet(RAW_URL)

if remote and #remote > 200 then
	local remoteVer = nil
	pcall(function()
		remoteVer = string.match(remote, 'local VERSION = "(.-)"')
	end)
	local localVer = nil
	if isfile and isfile(CACHE_FILE) then
		pcall(function()
			localVer = string.match(readfile(CACHE_FILE), 'local VERSION = "(.-)"')
		end)
	end
	if localVer == remoteVer then
		print("[LegitHub] Versão atual (" .. tostring(remoteVer) .. ")")
	else
		print("[LegitHub] Atualizando: " .. tostring(localVer or "nova") .. " -> " .. tostring(remoteVer))
		writefile(CACHE_FILE, remote)
	end
elseif isfile and isfile(CACHE_FILE) then
	warn("[LegitHub] Sem conexão. Usando cópia local.")
else
	ShowFatal("Não foi possível baixar o hub e não existe cópia salva.")
	return
end

-- 5. Carregar hub
print("[LegitHub] Carregando hub...")
local function runHub()
	local code = readfile(CACHE_FILE)
	local loader, err = loadstring(code)
	if not loader and remote and #remote > 200 then
		warn("[LegitHub] Cópina corrompida, baixando novamente...")
		writefile(CACHE_FILE, remote)
		loader, err = loadstring(remote)
	end
	if not loader then
		error("[LegitHub] Falha ao compilar: " .. tostring(err), 0)
	end
	local okExec, errExec = xpcall(loader, function(e)
		return debug.traceback(tostring(e), 2)
	end)
	if not okExec then
		ShowFatal("O hub travou.\n\n" .. tostring(errExec))
	end
end

local okHub, errHub = xpcall(runHub, function(e)
	return debug.traceback(tostring(e), 2)
end)
if not okHub then
	ShowFatal(tostring(errHub))
end
