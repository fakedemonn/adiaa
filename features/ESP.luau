-- [Context: ESP Module | LinoriaLib compatible | Box + Glow + Names + Distance]
-- *module returns a table. SetEnabled and feature flags drive rendering.*

local Players     = game:GetService("Players")
local RunService  = game:GetService("RunService")
local localPlayer = Players.LocalPlayer
local camera      = workspace.CurrentCamera

local ESP = {}

-- ── STATE ─────────────────────────────────────────────────────────────────────
local enabled         = false
local showBox         = true
local showNames       = false
local showDist        = false
local showGlow        = true
local maxDist         = 5000
local distEnabled     = false

-- ── CONFIG ───────────────────────────────────────────────────────────────────
local BoxThickness = 1
local DistSize     = 11
local NameSize     = 13

-- ── UTILS ────────────────────────────────────────────────────────────────────
local function w2s(worldPos)
    local sp, inBounds = camera:WorldToViewportPoint(worldPos)
    return Vector2.new(sp.X, sp.Y), inBounds
end

local function getBB(char)
    local root = char:FindFirstChild("HumanoidRootPart")
    local head = char:FindFirstChild("Head")
    if not root or not head then return nil end

    local footPos = root.Position - Vector3.new(0, 3.0, 0)
    local headPos = head.Position + Vector3.new(0, 0.6, 0)

    local topSP, topVis = w2s(headPos)
    local botSP, botVis = w2s(footPos)
    local rootSP        = w2s(root.Position)

    if not topVis and not botVis then return nil end

    local h = math.abs(topSP.Y - botSP.Y)
    local w = h * 0.45

    return {
        TL  = Vector2.new(rootSP.X - w, topSP.Y),
        TR  = Vector2.new(rootSP.X + w, topSP.Y),
        BL  = Vector2.new(rootSP.X - w, botSP.Y),
        BR  = Vector2.new(rootSP.X + w, botSP.Y),
        Top = topSP,
        Bot = botSP,
    }
end

-- ── HIGHLIGHT ────────────────────────────────────────────────────────────────
local function createHighlight(char)
    local old = char:FindFirstChildOfClass("Highlight")
    if old then old:Destroy() end
    local h               = Instance.new("Highlight")
    h.FillColor           = Color3.fromRGB(255, 255, 255)
    h.OutlineColor        = Color3.fromRGB(255, 255, 255)
    h.FillTransparency    = 0.6
    h.OutlineTransparency = 0
    h.DepthMode           = Enum.HighlightDepthMode.AlwaysOnTop
    h.Adornee             = char
    h.Parent              = char
    return h
end

local function removeHighlight(char)
    if not char then return end
    local h = char:FindFirstChildOfClass("Highlight")
    if h then h:Destroy() end
end

-- ── DRAWING FACTORY ───────────────────────────────────────────────────────────
local function newLine()
    local d        = Drawing.new("Line")
    d.Visible      = false
    d.Color        = Color3.fromRGB(255, 255, 255)
    d.Thickness    = BoxThickness
    d.Transparency = 1
    return d
end

local function newText(size)
    local d        = Drawing.new("Text")
    d.Visible      = false
    d.Color        = Color3.fromRGB(255, 255, 255)
    d.Size         = size or DistSize
    d.Outline      = true
    d.OutlineColor = Color3.fromRGB(0, 0, 0)
    d.Font         = Drawing.Fonts.UI
    d.Center       = true
    return d
end

-- ── ESP POOL ─────────────────────────────────────────────────────────────────
local ESPObjects = {}

local function createESP(player)
    ESPObjects[player] = {
        BoxTop   = newLine(),
        BoxBot   = newLine(),
        BoxLeft  = newLine(),
        BoxRight = newLine(),
        Distance = newText(DistSize),
        Name     = newText(NameSize),
    }
    local char = player.Character
    if char and showGlow then createHighlight(char) end
    player.CharacterAdded:Connect(function(newChar)
        task.wait(0.1)
        if enabled and showGlow then createHighlight(newChar) end
    end)
end

local function removeESP(player)
    local obj = ESPObjects[player]
    if not obj then return end
    for _, d in pairs(obj) do d:Remove() end
    ESPObjects[player] = nil
    removeHighlight(player.Character)
end

local function hideESP(obj)
    for _, d in pairs(obj) do d.Visible = false end
end

-- ── RENDER LOOP ───────────────────────────────────────────────────────────────
RunService.RenderStepped:Connect(function()
    for player, obj in pairs(ESPObjects) do
        if not player or not player.Parent then
            removeESP(player)
            continue
        end

        if player == localPlayer or not enabled then
            hideESP(obj)
            continue
        end

        local char = player.Character
        local hum  = char and char:FindFirstChildOfClass("Humanoid")

        if not char or not hum or hum.Health <= 0 then
            hideESP(obj)
            continue
        end

        local root = char:FindFirstChild("HumanoidRootPart")
        if not root then hideESP(obj) continue end

        local dist = (root.Position - camera.CFrame.Position).Magnitude

        if distEnabled and dist > maxDist then
            hideESP(obj)
            continue
        end

        local bb = getBB(char)
        if not bb then hideESP(obj) continue end

        -- Glow
        if showGlow then
            if not char:FindFirstChildOfClass("Highlight") then
                createHighlight(char)
            end
        else
            removeHighlight(char)
        end

        -- Box
        if showBox then
            obj.BoxTop.From    = bb.TL  obj.BoxTop.To    = bb.TR  obj.BoxTop.Visible    = true
            obj.BoxBot.From    = bb.BL  obj.BoxBot.To    = bb.BR  obj.BoxBot.Visible    = true
            obj.BoxLeft.From   = bb.TL  obj.BoxLeft.To   = bb.BL  obj.BoxLeft.Visible   = true
            obj.BoxRight.From  = bb.TR  obj.BoxRight.To  = bb.BR  obj.BoxRight.Visible  = true
        else
            obj.BoxTop.Visible = false obj.BoxBot.Visible  = false
            obj.BoxLeft.Visible= false obj.BoxRight.Visible= false
        end

        -- Distance
        if showDist then
            obj.Distance.Text     = ("[%d]"):format(math.floor(dist))
            obj.Distance.Position = Vector2.new(
                (bb.BL.X + bb.BR.X) / 2,
                bb.BL.Y + 4
            )
            obj.Distance.Visible = true
        else
            obj.Distance.Visible = false
        end

        -- Name
        if showNames then
            obj.Name.Text     = player.Name
            obj.Name.Position = Vector2.new(bb.Top.X, bb.TL.Y - 16)
            obj.Name.Visible  = true
        else
            obj.Name.Visible = false
        end
    end
end)

-- ── PLAYER LIFECYCLE ──────────────────────────────────────────────────────────
Players.PlayerAdded:Connect(function(p)
    if p ~= localPlayer then createESP(p) end
end)

Players.PlayerRemoving:Connect(function(p)
    removeESP(p)
end)

for _, p in ipairs(Players:GetPlayers()) do
    if p ~= localPlayer then createESP(p) end
end

-- ── PUBLIC API ────────────────────────────────────────────────────────────────
function ESP:SetEnabled(value)
    enabled = value
    if not value then
        for _, obj in pairs(ESPObjects) do hideESP(obj) end
        for _, p in ipairs(Players:GetPlayers()) do
            if p.Character then removeHighlight(p.Character) end
        end
    end
end

function ESP:SetBox(value)         showBox   = value end
function ESP:SetNames(value)       showNames = value end
function ESP:SetDistanceEnabled(v) distEnabled = v   end
function ESP:SetDistance(value)    maxDist   = value end

function ESP:SetGlow(value)
    showGlow = value
    for _, p in ipairs(Players:GetPlayers()) do
        if p == localPlayer then continue end
        local char = p.Character
        if not char then continue end
        if value and enabled then
            createHighlight(char)
        else
            removeHighlight(char)
        end
    end
end

return ESP
