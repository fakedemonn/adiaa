local Players    = game:GetService("Players")
local RunService = game:GetService("RunService")
local Camera     = workspace.CurrentCamera

local plr      = Players.LocalPlayer
local enabled  = false
local maxDist  = 0        -- 0 = unlimited
local labels   = {}       -- [player] = Drawing Text
local conn     = nil

-- ─── helpers ──────────────────────────────────────────────────────────────────
local function getLabelPos(char)
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hrp or not hum then return nil, nil end

    local hip    = hum.HipHeight + 0.5
    local bot3   = hrp.Position - Vector3.new(0, hip, 0)
    local pos, vis = Camera:WorldToViewportPoint(bot3)
    if not vis or pos.Z < 0 then return nil, nil end

    local dist = (Camera.CFrame.Position - hrp.Position).Magnitude
    return Vector2.new(pos.X, pos.Y + 2), dist
end

local function newLabel()
    local t         = Drawing.new("Text")
    t.Size          = 13
    t.Center        = true
    t.Outline       = true
    t.OutlineColor  = Color3.new(0, 0, 0)
    t.Color         = Color3.fromRGB(200, 230, 255)
    t.Font          = Drawing.Fonts.UI
    t.Transparency  = 1
    t.Visible       = false
    return t
end

local function removeLabel(p)
    if labels[p] then
        labels[p]:Remove()
        labels[p] = nil
    end
end

-- ─── per-player setup ─────────────────────────────────────────────────────────
local function addPlayer(p)
    if p == plr then return end
    labels[p] = newLabel()
end

-- ─── render loop ──────────────────────────────────────────────────────────────
local function startLoop()
    if conn then return end
    conn = RunService.RenderStepped:Connect(function()
        if not enabled then return end
        for p, lbl in pairs(labels) do
            local char = p.Character
            local pos, dist = char and getLabelPos(char)
            if pos and dist then
                local outOfRange = maxDist > 0 and dist > maxDist
                if outOfRange then
                    lbl.Visible = false
                else
                    lbl.Text     = ("%d studs"):format(math.floor(dist))
                    lbl.Position = pos
                    lbl.Visible  = true
                end
            else
                lbl.Visible = false
            end
        end
    end)
end

local function stopLoop()
    if conn then conn:Disconnect() conn = nil end
    for _, lbl in pairs(labels) do lbl.Visible = false end
end

-- ─── module ───────────────────────────────────────────────────────────────────
Players.PlayerAdded:Connect(function(p)
    if p ~= plr then labels[p] = newLabel() end
end)
Players.PlayerRemoving:Connect(removeLabel)

for _, p in ipairs(Players:GetPlayers()) do addPlayer(p) end

return {
    SetEnabled = function(_, value)
        enabled = value
        if value then
            startLoop()
        else
            stopLoop()
        end
    end,
    -- called by the distance slider
    SetMaxDistance = function(_, value)
        maxDist = value
    end,
}
