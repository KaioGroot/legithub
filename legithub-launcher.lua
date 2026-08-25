-- =====================================================
--  LegitHub Launcher v1.0
--
--  Este e o UNICO script que voce precisa distribuir.
--  Ele baixa o hub do GitHub, guarda copia local e se
--  atualiza sozinho quando voce sobe versao nova.
--
--  COMO CONFIGURAR (uma vez so):
--   1) Ja configurado! Repo: github.com/KaioGroot/legithub
--   2) Para atualizar: edite o legithub-v2.lua local e suba
--      a nova versao no repositorio substituindo o arquivo.
--      Todos que usam o launcher recebem automaticamente.
-- =====================================================

local RAW_URL = "https://raw.githubusercontent.com/KaioGroot/legithub/main/legithub-v2.lua"
local CACHE_FILE = "legithub_main.lua"

_G.LegitHubUpdateURL = RAW_URL

local Players = game:GetService("Players")

-- Mostra erros fatais NA TELA (nao depende do console do executor).
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
		local canto = Instance.new("UICorner")
		canto.CornerRadius = UDim.new(0, 12)
		canto.Parent = fundo
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

local function extractVersion(code)
	if type(code) ~= "string" then return nil end
	return string.match(code, 'local VERSION = "(.-)"')
end

print("[LegitHub] Verificando atualizacoes...")
local remote = httpGet(RAW_URL)

if remote and #remote > 200 then
	local remoteVer = extractVersion(remote) or "?"
	local localVer = nil
	if isfile and isfile(CACHE_FILE) then
		localVer = extractVersion(readfile(CACHE_FILE))
	end
	if localVer == remoteVer then
		print("[LegitHub] Ja esta na versao mais recente (" .. remoteVer .. "). Carregando da copia local.")
	else
		print("[LegitHub] Atualizando: " .. tostring(localVer or "nova instalacao") .. " -> " .. remoteVer)
		writefile(CACHE_FILE, remote)
	end
elseif isfile and isfile(CACHE_FILE) then
	warn("[LegitHub] Sem conexao com o GitHub. Carregando copia salva (" ..
		tostring(extractVersion(readfile(CACHE_FILE)) or "?") .. ").")
else
	error("[LegitHub] Nao foi possivel baixar o hub e nao existe copia salva. Confira a RAW_URL no launcher.", 0)
end

local function runHub()
	local code = readfile(CACHE_FILE)
	local loader, err = loadstring(code)
	if not loader and remote and #remote > 200 then
		warn("[LegitHub] Copia local corrompida, baixando novamente...")
		writefile(CACHE_FILE, remote)
		loader, err = loadstring(remote)
	end
	if not loader then
		error("[LegitHub] Falha ao compilar o hub: " .. tostring(err), 0)
	end
	local okExec, errExec = xpcall(loader, function(e)
		return debug.traceback(tostring(e), 2)
	end)
	if not okExec then
		ShowFatal("O hub travou durante a execucao. Detalhes tecnicos:\n\n" .. tostring(errExec))
	end
end

local okHub, errHub = xpcall(runHub, function(e)
	return debug.traceback(tostring(e), 2)
end)
if not okHub then
	ShowFatal(tostring(errHub))
end
