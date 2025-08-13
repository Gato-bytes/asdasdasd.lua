if game.PlaceId == 6403373529 then
local teleportFunc = queueonteleport or queue_on_teleport or syn and syn.queue_on_teleport
if teleportFunc then
    teleportFunc([[
if not game:IsLoaded() then
    game.Loaded:Wait()
end
repeat task.wait() until game.Players.LocalPlayer
wait(0.25)
loadstring(game:HttpGet("https://pastefy.app/305onFwa/raw"))()
    ]])
end
end
-- Espera o jogo carregar
repeat task.wait() until game:IsLoaded()
print("Jogo carregado, aguardando 5 segundos antes de iniciar...")
-- Serviços
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local httpRequest = syn and syn.request or (http and http.request) or http_request or request

-- === Função parseMoney ===
function parseMoney(value)
    if not value or value == "" then return 0, false end
    local originalValue = tostring(value)
    if originalValue:match("%s") then return 0, true end
    value = originalValue:lower()
    local num, suffix = value:match("([%d%.%,]+)([kmb])")
    if num then
        num = num:gsub(",", "")
        local numValue = tonumber(num)
        if numValue then
            local multiplier = 1
            if suffix == "k" then multiplier = 1e3
            elseif suffix == "m" then multiplier = 1e6
            elseif suffix == "b" then multiplier = 1e9 end
            return numValue * multiplier, false
        end
    end
    local numOnly = value:match("([%d%.%,]+)")
    if numOnly then
        numOnly = numOnly:gsub(",", "")
        local numValue = tonumber(numOnly)
        if numValue then return numValue, false end
    end
    return 0, false
end

-- === Configurações ===
local WEBHOOK_URL = "https://discord.com/api/webhooks/1397679957143982120/MHK0JaftUQgqIKXyBknWNiKp_X-_YxjuWCL4JKCw41gYupx1VD-QkA5kBeMhY2BuSFLr"
local WEBHOOK_COOLDOWN = 3      -- segundos entre webhooks
local SERVER_HOP_COOLDOWN = 2   -- segundos entre server hops
local SCAN_DELAY = 0.5          -- segundos entre scans

-- Limites fixos do threshold (1M a 10M)
local minThreshold, _ = parseMoney("1m")
local maxThreshold, _ = parseMoney("10m")

-- Controle
local lastSentAnimal = nil
local lastSentGeneration = 0
local lastWebhookTime = 0
local lastServerHop = 0
local AllIDs = {}
local foundAnything = ""
local PlaceID = game.PlaceId

-- Carrega histórico de servidores
pcall(function()
    AllIDs = HttpService:JSONDecode(readfile("NotSameServers.json") or "[]")
end)

-- === Função webhook ===
local function sendWebhook(name, moneyPerSec, jobId)
    if not httpRequest then return end
    if tick() - lastWebhookTime < WEBHOOK_COOLDOWN then return end

    local playersCount = #Players:GetPlayers()
    local maxPlayers = Players.MaxPlayers or 8

    local payload = HttpService:JSONEncode({
        embeds = {{
            color = 16776960,
            fields = {
                {name = "**🐈 Gato Hub Notify**", value = "", inline = false},
                {name = "**<:sab_logo:1405254628940972193> Nome**", value = name, inline = false},
                {name = "**<:emoji_1:1405256481313521774> Dinheiro por segundo**", value = moneyPerSec, inline = false},
                {name = "**👥 Players**", value = string.format("%d/%d", playersCount, maxPlayers), inline = false},
                {name = "**🔢 Job ID**", value = jobId, inline = false},
                {name = "**🔗 Script Join**", value = string.format('game:GetService("TeleportService"):TeleportToPlaceInstance(%d, "%s", game.Players.LocalPlayer)', PlaceID, jobId), inline = false}
            }
        }}
    })

    pcall(function()
        httpRequest({
            Url = WEBHOOK_URL,
            Method = "POST",
            Headers = { ["Content-Type"] = "application/json" },
            Body = payload
        })
        lastWebhookTime = tick()
        print("📤 [Webhook] Enviado:", name, "Geração:", moneyPerSec)
    end)
end

-- === Scanner de animais ===
local function scanAnimals()
    if not workspace:FindFirstChild("Plots") then return false end

    local foundAnimal = false
    local maxGeneration = 0
    local topAnimalName, topAnimalOverhead

    for _, plot in ipairs(workspace.Plots:GetChildren()) do
        local podiums = plot:FindFirstChild("AnimalPodiums")
        if podiums then
            for _, podium in ipairs(podiums:GetChildren()) do
                local base = podium:FindFirstChild("Base")
                if base and base:FindFirstChild("Spawn") and base.Spawn:FindFirstChild("Attachment") and base.Spawn.Attachment:FindFirstChild("AnimalOverhead") then
                    local overhead = base.Spawn.Attachment.AnimalOverhead
                    local genValue, hasSpace = parseMoney(overhead.Generation.Text)
                    if not hasSpace and genValue >= minThreshold and genValue <= maxThreshold then
                        foundAnimal = true
                        if genValue > maxGeneration then
                            maxGeneration = genValue
                            topAnimalName = overhead.DisplayName.Text or "Desconhecido"
                            topAnimalOverhead = overhead
                        end
                    end
                end
            end
        end
    end

    if foundAnimal and topAnimalOverhead then
        local genValue, _ = parseMoney(topAnimalOverhead.Generation.Text)
        if lastSentAnimal ~= topAnimalName or lastSentGeneration ~= genValue then
            sendWebhook(topAnimalName, topAnimalOverhead.Generation.Text, game.JobId or tostring(math.random(1000000,9999999)))
            lastSentAnimal = topAnimalName
            lastSentGeneration = genValue
        end
        return true
    end

    return false
end

-- === Server hop via API oficial Roblox ===
local function TPReturner()
    if tick() - lastServerHop < SERVER_HOP_COOLDOWN then return end
    lastServerHop = tick()

    local url = 'https://games.roblox.com/v1/games/'..PlaceID..'/servers/Public?sortOrder=Asc&limit=100'
    if foundAnything ~= "" then url = url.."&cursor="..foundAnything end

    local success, result = pcall(function()
        return HttpService:JSONDecode(game:HttpGet(url))
    end)
    if not success or not result then return end

    foundAnything = result.nextPageCursor or ""

    for _, v in pairs(result.data or {}) do
        local ID = tostring(v.id)
        if tonumber(v.maxPlayers) > tonumber(v.playing) then
            if not table.find(AllIDs, ID) then
                table.insert(AllIDs, ID)
                pcall(function()
                    writefile("NotSameServers.json", HttpService:JSONEncode(AllIDs))
                    print("[Server Hop] Indo para:", ID)
                    game:GetService("TeleportService"):TeleportToPlaceInstance(PlaceID, ID, Players.LocalPlayer)
                end)
                return
            end
        end
    end
end

-- === Loop principal ultra agressivo ===
while true do
    scanAnimals()
    wait(10)       -- faz scan e envia webhook se necessário
    TPReturner()        -- server hop sempre
end
