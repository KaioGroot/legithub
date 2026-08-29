-- =====================================================
--  LegitHub Launcher v3.0
--
--  Validação via Cloudflare Worker + hub criptografado.
--  SEM API key do Firebase e SEM raw GitHub no client.
-- =====================================================

local WORKER_URL = "https://legithub-auth.pages.dev"
local API_VALIDATE = WORKER_URL .. "/api/validate"
local API_SCRIPT = WORKER_URL .. "/api/script"

local CACHE_FILE = "legithub_hub.lua"
local LICENSE_CACHE = "legithub_license.json"

-- Chave de decript (XOR). Deve bater com tools/hubcrypto.mjs
local DECRYPT_KEY = "L3g1tH#uB|Pr0t3ct|2026|K3y_!xQ8$vNm@WzKpRcTdYfGhJkLmNpQsUtVwXyZ"

_G.LegitHubUpdateURL = WORKER_URL .. "/"

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")

local VERSION = "v3.0"

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

local function httpGetJson(url)
	local body = httpGet(url)
	if not body then return nil end
	local ok, parsed = pcall(function()
		return HttpService:JSONDecode(body)
	end)
	if not ok then return nil end
	return parsed
end

-- Tenta varias vezes (download de 350KB pode falhar)
local function httpGetRetry(url, tries)
	tries = tries or 3
	for i = 1, tries do
		local body = httpGet(url)
		if body and #body > 100 then
			return body
		end
		task.wait(0.4)
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
--  Decript (base64 + XOR) — mesmo algoritmo do worker
-- =====================================================

local B64_CHARS = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"

local function b64Decode(s)
	local out = {}
	local n = 0
	for i = 1, #s, 4 do
		local sa = string.sub(s, i, i)
		local sb = string.sub(s, i + 1, i + 1)
		local sc = string.sub(s, i + 2, i + 2)
		local sd = string.sub(s, i + 3, i + 3)

		local pa = B64_CHARS:find(sa, 1, true)
		local pb = B64_CHARS:find(sb, 1, true)
		local pc = (sc ~= "" and sc ~= "=") and B64_CHARS:find(sc, 1, true)
		local pd = (sd ~= "" and sd ~= "=") and B64_CHARS:find(sd, 1, true)

		local A = pa and (pa - 1) or 0
		local Bb = pb and (pb - 1) or 0
		local C = pc and (pc - 1) or 0
		local D = pd and (pd - 1) or 0

		local bytes = ((A << 18) | (Bb << 12) | (C << 6) | D)

		n = n + 1
		out[n] = string.char((bytes >> 16) & 0xFF)
		if sc ~= "" then
			n = n + 1
			out[n] = string.char((bytes >> 8) & 0xFF)
		end
		if sd ~= "" then
			n = n + 1
			out[n] = string.char(bytes & 0xFF)
		end
	end
	return table.concat(out)
end

local function decryptHub(b64)
	local raw = b64Decode(b64)
	local kb = {}
	for i = 1, #DECRYPT_KEY do kb[i] = string.byte(DECRYPT_KEY, i) end
	local kn = #DECRYPT_KEY
	local s = {}
	for i = 1, #raw do
		s[i] = string.char(string.byte(raw, i) ~ kb[((i - 1) % kn) + 1])
	end
	return table.concat(s)
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

-- Cache do script (body criptografado ou plain)
local function SaveHubCache(body)
	pcall(function()
		local data = { body = body, savedAt = os.time() }
		writefile(CACHE_FILE, HttpService:JSONEncode(data))
	end)
end

local function LoadHubCache()
	local ok, data = pcall(function()
		if isfile and isfile(CACHE_FILE) then
			return HttpService:JSONDecode(readfile(CACHE_FILE))
		end
		return nil
	end)
	if ok and data and data.body and #data.body > 100 then
		return data.body
	end
	return nil
end

-- =====================================================
--  Validação da key (via Worker)
-- =====================================================

local function ValidateKey(key)
	if not key or key == "" then
		return { valid = false, error = "Key vazia" }
	end

	local hwid = GetHWID()
	local url = API_VALIDATE .. "?key=" .. key .. "&hwid=" .. hwid

	print("[LegitHub] Validando key: " .. key)

	local res = httpGetJson(url)
	if not res then
		print("[LegitHub] Sem conexão com o servidor")
		return { valid = false, error = "Sem conexão com o servidor" }
	end

	if not res.valid then
		print("[LegitHub] Key inválida: " .. tostring(res.error))
	end

	return res
end

-- =====================================================
--  Script do hub (via Worker, criptografado)
-- =====================================================

-- Retorna o codigo pronto pra loadstring
local function FetchHubScript(key, hwid, isFree)
	local url
	if isFree then
		url = API_SCRIPT .. "?mode=free"
	else
		url = API_SCRIPT .. "?key=" .. key .. "&hwid=" .. hwid
	end

	local body = httpGetRetry(url)
	if not body then return nil end

	local ok, res = pcall(function()
		return HttpService:JSONDecode(body)
	end)
	if not ok then return nil end

	if not res.valid then
		print("[LegitHub] Script bloqueado: " .. tostring(res.error))
		return nil
	end

	if isFree then
		return res.script -- plain lua
	end

	local plain = decryptHub(res.script)
	SaveHubCache(res.script)
	return plain
end

-- =====================================================
--  Tela de Key
-- =====================================================

local function ShowKeyScreen()
	local player = Players.LocalPlayer
	local playerGui = player:FindFirstChildOfClass("PlayerGui")
	if not playerGui then return false, "PlayerGui não encontrado" end

	local old = playerGui:FindFirstChild("LegitHubKeyScreen")
	if old then old:Destroy() end

	local gui = Instance.new("ScreenGui")
	gui.Name = "LegitHubKeyScreen"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 999999
	gui.Parent = playerGui

	local overlay = Instance.new("Frame")
	overlay.Size = UDim2.fromScale(1, 1)
	overlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	overlay.BackgroundTransparency = 0.3
	overlay.BorderSizePixel = 0
	overlay.Parent = gui

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

	local btnFree = Instance.new("TextButton")
	btnFree.Size = UDim2.new(1, -40, 0, 28)
	btnFree.Position = UDim2.fromOffset(20, 292)
	btnFree.BackgroundTransparency = 1
	btnFree.Text = "Continuar grátis →"
	btnFree.TextColor3 = Color3.fromRGB(100, 95, 115)
	btnFree.TextSize = 11
	btnFree.Font = Enum.Font.Gotham
	btnFree.Parent = card

	local result = nil
	local validated = false
	local validating = false

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

print("[LegitHub] Launcher " .. VERSION .. " iniciado")

local plan = "free"
local keyValid = false
local myKey = nil

-- 1. Verificar key salva
local savedKey = LoadSavedKey()
if savedKey and savedKey.key then
	print("[LegitHub] Key salva encontrada: " .. savedKey.key)

	task.spawn(function()
		local res = ValidateKey(savedKey.key)
		if res and res.valid then
			plan = res.plan or savedKey.plan or "free"
			keyValid = true
			myKey = savedKey.key
			SaveKey(savedKey.key, plan, res.expiresAt)
			print("[LegitHub] Key válida! Plano: " .. plan)
		else
			local err = (res and res.error) or "erro de conexão"
			print("[LegitHub] Key salva inválida: " .. tostring(err))
			if res and not res.valid then
				ClearSavedKey()
			end
		end
	end)

	task.wait(2)
end

-- 2. Se não tem key válida → tela de ativação
if not keyValid then
	print("[LegitHub] Mostrando tela de ativação...")
	local ok, res = ShowKeyScreen()
	if ok and res then
		plan = res.plan or "free"
		if res.key then myKey = res.key end
		print("[LegitHub] Plano selecionado: " .. plan)
	else
		plan = "free"
		print("[LegitHub] Modo grátis")
	end
end

-- 3. Passar plano pro hub via _G
_G.LegitHubPlan = plan
print("[LegitHub] Plano final: " .. plan)

-- 4. Baixar hub (criptografado via worker) ou usar cache
print("[LegitHub] Baixando hub...")
local hubCode = nil

if plan == "free" or not myKey then
	if plan == "free" then
		hubCode = FetchHubScript(nil, nil, true)
	end
else
	hubCode = FetchHubScript(myKey, GetHWID(), false)
end

if not hubCode then
	local cached = LoadHubCache()
	if cached then
		print("[LegitHub] Sem conexão. Usando hub em cache.")
		local okDec, dec = pcall(decryptHub, cached)
		hubCode = okDec and dec or nil
	end
end

if not hubCode or #hubCode < 500 then
	ShowFatal("Não foi possível baixar o hub e não existe cópia salva.")
	return
end

-- 5. Carregar hub
print("[LegitHub] Carregando hub...")
local function runHub()
	local loader, err = loadstring(hubCode)
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