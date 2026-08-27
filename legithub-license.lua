-- =====================================================
--  LegitHub License System v2.0
--
--  Validação de keys DIRETO no Firestore via REST API.
--  Não precisa de Cloud Functions nem Blaze plan.
--
--  COMO FUNCIONA:
--   1) Launcher envia GET pra Firestore REST API
--   2) Firestore retorna o documento da key
--   3) Launcher verifica se é válida (expiry, status)
--   4) Tudo acontece no cliente, sem backend custom
-- =====================================================

local License = {}

-- =====================================================
--  CONFIGURAÇÃO — troque pelos seus valores
-- =====================================================

-- Firebase Web App config (pegue no Console > Configurações)
License.API_KEY = "AIzaSyAubOqbL3_pNU9F3tCDVboN_9MCwitjXCQ"
License.PROJECT_ID = "legithub-20dd6"

-- URL base do Firestore REST API
License.FIRESTORE_URL = "https://firestore.googleapis.com/v1/projects/"
	.. License.PROJECT_ID
	.. "/databases/(default)/documents/licenses/"

-- =====================================================
--  HWID (identificador único do dispositivo)
-- =====================================================

function License.GetHWID()
	local Players = game:GetService("Players")
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
--  HTTP helper
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
--  Parse do Firestore REST API response
--  Converte formato Firestore pra tabela simples
-- =====================================================

local function parseFirestoreDoc(json)
	local ok, doc = pcall(function()
		return game:GetService("HttpService"):JSONDecode(json)
	end)
	if not ok or not doc then return nil end

	local fields = doc.fields
	if not fields then return nil end

	local function extractValue(field)
		if field.stringValue then return field.stringValue end
		if field.integerValue then return tonumber(field.integerValue) end
		if field.doubleValue then return field.doubleValue end
		if field.booleanValue then return field.booleanValue end
		if field.timestampValue then return field.timestampValue end
		if field.nullValue then return nil end
		return nil
	end

	local result = {}
	for key, field in pairs(fields) do
		result[key] = extractValue(field)
	end
	return result
end

-- =====================================================
--  Validação da key
-- =====================================================

function License.ValidateKey(key)
	if not key or key == "" then
		return { valid = false, error = "Key vazia" }
	end

	local hwid = License.GetHWID()
	local url = License.FIRESTORE_URL .. key .. "?key=" .. License.API_KEY

	local response = httpGet(url)
	if not response then
		return { valid = false, error = "Sem conexão com o servidor" }
	end

	-- Se retornou erro 404, key não existe
	if string.find(response, "NOT_FOUND") or string.find(response, "not found") then
		return { valid = false, error = "Key não encontrada" }
	end

	-- Parse da resposta
	local license = parseFirestoreDoc(response)
	if not license then
		return { valid = false, error = "Resposta inválida do servidor" }
	end

	-- Verificar status
	if license.status == "revoked" then
		return { valid = false, error = "Key revogada" }
	end

	if license.status == "expired" then
		return { valid = false, error = "Key expirada" }
	end

	-- Verificar expiração
	if license.expiresAt then
		local expiresAt = license.expiresAt
		-- Firestore retorna ISO 8601, converte pra timestamp
		local now = os.time()
		local expiresAtTime = 0

		-- Tenta converter ISO 8601 pra timestamp
		if type(expiresAt) == "string" then
			-- Formato: "2026-09-27T12:00:00Z"
			local pattern = "(%d+)%-(%d+)%-(%d+)T(%d+):(%d+):(%d+)"
			local y, m, d, h, min, s = string.match(expiresAt, pattern)
			if y then
				expiresAtTime = os.time({
					year = tonumber(y), month = tonumber(m), day = tonumber(d),
					hour = tonumber(h), min = tonumber(min), sec = tonumber(s),
				})
			end
		end

		if expiresAtTime > 0 and expiresAtTime < now then
			return { valid = false, error = "Key expirada" }
		end
	end

	-- Verificar HWID
	if license.hwid and license.hwid ~= "" and license.hwid ~= hwid then
		return { valid = false, error = "Key associada a outro dispositivo" }
	end

	return {
		valid = true,
		plan = license.plan or "weekly",
		expiresAt = license.expiresAt,
	}
end

-- =====================================================
--  Cache local
-- =====================================================

function License.SaveKey(key, plan, expiresAt)
	local HttpService = game:GetService("HttpService")
	local data = {
		key = key,
		plan = plan,
		expiresAt = expiresAt,
		savedAt = os.time(),
	}
	pcall(function()
		writefile("legithub_license.json", HttpService:JSONEncode(data))
	end)
end

function License.LoadSaved()
	local HttpService = game:GetService("HttpService")
	local ok, data = pcall(function()
		if isfile("legithub_license.json") then
			return HttpService:JSONDecode(readfile("legithub_license.json"))
		end
		return nil
	end)
	if ok and data then return data end
	return nil
end

function License.ClearSaved()
	pcall(function()
		if isfile("legithub_license.json") then
			delfile("legithub_license.json")
		end
	end)
end

function License.GetPlan()
	local saved = License.LoadSaved()
	if saved and saved.plan then
		return saved.plan, saved.expiresAt
	end
	return "free", nil
end

function License.IsVIP()
	local plan = License.GetPlan()
	return plan == "weekly" or plan == "monthly" or plan == "annual" or plan == "premium"
end

function License.IsPremium()
	local plan = License.GetPlan()
	return plan == "premium"
end

return License
