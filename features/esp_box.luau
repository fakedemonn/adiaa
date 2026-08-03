local Players    = game:GetService("Players")
local RunService = game:GetService("RunService")
local Camera     = workspace.CurrentCamera

local plr     = Players.LocalPlayer
local enabled = false
local boxes   = {}   -- [player] = { top, bottom, left, right : Drawing Line }
local conn    = nil

-- ─── helpers ──────────────────────────────────────────────────────────────────
local function getBounds(char)
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hrp or not hum then return nil end

    local hip    = hum.HipHeight + 0.5
    local top3   = hrp.Position + Vector3.new(0,  hip + 1.5, 0)
    local bot3   = hrp.Position - Vector3.new(0,  hip,       0)

    local topV, topVis = Camera:WorldToViewportPoint(top3)
    local botV, botVis = Camera:WorldToViewportPoint(bot3)
    if not topVis or topV.Z < 0 then return nil end

    local h = math.abs(botV.Y - topV.Y)
    local w = h * 0.55
    local cx = topV.X

    return {
        x = cx - w / 2,
        y = topV.Y,
        w = w,
        h = h,
    }
end

local function newBox()
    local lines = {}
    for i = 1, 4 do
        local l         = Drawing.new("Line")
        l.Thickness     = 1.5
        l.Color         = Color3.fromRGB(255, 50, 50)
        l.Transparency  = 1
        l.Visible       = false
        lines[i] = l
    end
    return lines   -- top, bottom, left, right
end

local function drawBox(lines, b)
    -- top
    lines[1].From    = Vector2.new(b.x,       b.y)
    lines[1].To      = Vector2.new(b.x + b.w, b.y)
    -- bottom
    lines[2].From    = Vector2.new(b.x,       b.y + b.h)
    lines[2].To      = Vector2.new(b.x + b.w, b.y + b.h)
    -- left
    lines[3].From    = Vector2.new(b.x,       b.y)
    lines[3].To      = Vector2.new(b.x,       b.y + b.h)
    -- right
    lines[4].From    = Vector2.new(b.x + b.w, b.y)
    lines[4].To      = Vector2.new(b.x + b.w, b.y + b.h)
    for _, l in ipairs(lines) do l.Visible = true end
end

local function hideBox(lines)
    for _, l in ipairs(lines) do l.Visible = false end
end

local function removeBox(p)
    if boxes[p] then
        for _, l in ipairs(boxes[p]) do l:Remove() end
        boxes[p] = nil
    end
end

-- ─── per-player setup ─────────────────────────────────────────────────────────
local function addPlayer(p)
    if p == plr then return end
    boxes[p] = newBox()
end

local function removePlayer(p)
    removeBox(p)
end

-- ─── render loop ──────────────────────────────────────────────────────────────
local function startLoop()
    if conn then return end
    conn = RunService.RenderStepped:Connect(function()
        if not enabled then return end
        for p, lines in pairs(boxes) do
            local char = p.Character
            local b    = char and getBounds(char)
            if b then
                drawBox(lines, b)
            else
                hideBox(lines)
            end
        end
    end)
end

local function stopLoop()
    if conn then conn:Disconnect() conn = nil end
    for _, lines in pairs(boxes) do hideBox(lines) end
end

-- ─── module ───────────────────────────────────────────────────────────────────
Players.PlayerAdded:Connect(addPlayer)
Players.PlayerRemoving:Connect(removePlayer)

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
}
