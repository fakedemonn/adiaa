-- [Context: ESP Module v3 | Glow decoupled from render loop | Corner brackets]
-- *glow only fires when you flip the toggle. render loop doesn't touch it.*

local Players     = game:GetService("Players")
local RunService  = game:GetService("RunService")
local localPlayer = Players.LocalPlayer
local camera      = workspace.CurrentCamera

local ESP = {}

-- ── STATE ─────────────────────────────────────────────────────────────────────
local enabled     = false
local showBox     = true
local showNames   = false
local showDist    = false
local showGlow    = false   -- OFF by default. render loop never reads this.
local maxDist     = 5000
local distFilter  = false

local CORNER_LEN  = 0.25
local THICKNESS   = 1.5
local DIST_SIZE   = 11
local NAME_SIZE   = 13

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
        W   = w * 2,
        H   = h,
    }
end

-- ── HIGHLIGHT ────────────────────────────────────────────────────────────────
-- Glow is ONLY created/removed by SetGlow and SetEnabled.
-- The render loop never calls createHighlight or removeHighlight.
local function createHighlight(char)
    if not char then return end
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
end

local function removeHighlight(char)
    if not char then return end
    local h = char:FindFirstChildOfClass("Highlight")
    if h then h:Destroy() end
end

local function removeAllHighlights()
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= localPlayer and p.Character then
            removeHighlight(p.Character)
        end
    end
end

local function applyAllHighlights()
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= localPlayer and p.Character then
            createHighlight(p.Character)
        end
    end
end

-- ── DRAWING FACTORY ───────────────────────────────────────────────────────────
local function newLine()
    local d        = Drawing.new("Line")
    d.Visible      = false
    d.Color        = Color3.fromRGB(255, 255, 255)
    d.Thickness    = THICKNESS
    d.Transparency = 1
    return d
end

local function newText(size)
    local d        = Drawing.new("Text")
    d.Visible      = false
    d.Color        = Color3.fromRGB(255, 255, 255)
    d.Size         = size
    d.Outline      = true
    d.OutlineColor = Color3.fromRGB(0, 0, 0)
    d.Font         = Drawing.Fonts.UI
    d.Center       = true
    return d
end

-- ── ESP POOL ─────────────────────────────────────────────────────────────────
local ESPObjects = {}

local function createESP(player)
    -- *no highlight created here. glow is SetGlow's job.*
    ESPObjects[player] = {
        TL_H = newLine(), TL_V = newLine(),
        TR_H = newLine(), TR_V = newLine(),
        BL_H = newLine(), BL_V = newLine(),
        BR_H = newLine(), BR_V = newLine(),
        Distance = newText(DIST_SIZE),
        Name     = newText(NAME_SIZE),
    }

    -- On respawn: re-apply glow only if both flags are live
    player.CharacterAdded:Connect(function(newChar)
        task.wait(0.1)
        if enabled and showGlow then
            createHighlight(newChar)
        end
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

-- ── CORNER BRACKET RENDERER ───────────────────────────────────────────────────
local function drawCorners(obj, bb)
    local TL, TR, BL, BR = bb.TL, bb.TR, bb.BL, bb.BR
    local cw = bb.W * CORNER_LEN
    local ch = bb.H * CORNER_LEN

    obj.TL_H.From = TL  obj.TL_H.To = Vector2.new(TL.X + cw, TL.Y)
    obj.TL_V.From = TL  obj.TL_V.To = Vector2.new(TL.X, TL.Y + ch)
    obj.TR_H.From = TR  obj.TR_H.To = Vector2.new(TR.X - cw, TR.Y)
    obj.TR_V.From = TR  obj.TR_V.To = Vector2.new(TR.X, TR.Y + ch)
    obj.BL_H.From = BL  obj.BL_H.To = Vector2.new(BL.X + cw, BL.Y)
    obj.BL_V.From = BL  obj.BL_V.To = Vector2.new(BL.X, BL.Y - ch)
    obj.BR_H.From = BR  obj.BR_H.To = Vector2.new(BR.X - cw, BR.Y)
    obj.BR_V.From = BR  obj.BR_V.To = Vector2.new(BR.X, BR.Y - ch)

    obj.TL_H.Visible = true  obj.TL_V.Visible = true
    obj.TR_H.Visible = true  obj.TR_V.Visible = true
    obj.BL_H.Visible = true  obj.BL_V.Visible = true
    obj.BR_H.Visible = true  obj.BR_V.Visible = true
end

local function hideCorners(obj)
    obj.TL_H.Visible = false  obj.TL_V.Visible = false
    obj.TR_H.Visible = false  obj.TR_V.Visible = false
    obj.BL_H.Visible = false  obj.BL_V.Visible = false
    obj.BR_H.Visible = false  obj.BR_V.Visible = false
end

-- ── RENDER LOOP — no glow logic here at all ───────────────────────────────────
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

        if distFilter and dist > maxDist then
            hideESP(obj)
            continue
        end

        local bb = getBB(char)
        if not bb then hideESP(obj) continue end

        -- Box
        if showBox then
            drawCorners(obj, bb)
        else
            hideCorners(obj)
        end

        -- Distance label
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
        -- Kill all highlights when ESP turns off regardless of glow toggle
        removeAllHighlights()
    else
        -- ESP turned on — only apply glow if the toggle is already on
        if showGlow then applyAllHighlights() end
    end
end

function ESP:SetBox(value)
    showBox = value
end

function ESP:SetNames(value)
    showNames = value
end

function ESP:SetDistanceEnabled(value)
    showDist   = value
    distFilter = value
end

function ESP:SetDistance(value)
    maxDist = value
end

function ESP:SetGlow(value)
    -- *glow toggle flipped. apply or strip all highlights right now.*
    showGlow = value
    if not enabled then return end  -- ESP off — don't touch anything
    if value then
        applyAllHighlights()
    else
        removeAllHighlights()
    end
end

return ESP
