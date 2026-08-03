local Players    = game:GetService("Players")
local RunService = game:GetService("RunService")
local Camera     = workspace.CurrentCamera

local plr     = Players.LocalPlayer
local enabled = false
local maxDist = 0
local labels  = {}
local conn    = nil

local function getBottomAndDist(char)
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return nil, nil end

    local minX, maxX = math.huge, -math.huge
    local maxY       = -math.huge
    local valid      = false

    for _, part in ipairs(char:GetDescendants()) do
        if part:IsA("BasePart") then
            local sv, vis = Camera:WorldToViewportPoint(part.Position)
            if vis and sv.Z > 0 then
                valid = true
                if sv.X < minX then minX = sv.X end
                if sv.X > maxX then maxX = sv.X end
                if sv.Y > maxY then maxY = sv.Y end
            end
        end
    end

    if not valid then return nil, nil end

    local cx   = (minX + maxX) / 2
    local dist = (Camera.CFrame.Position - hrp.Position).Magnitude
    return Vector2.new(cx, maxY + 4), dist
end

local function newLabel()
    local t        = Drawing.new("Text")
    t.Size         = 11
    t.Center       = true
    t.Outline      = true
    t.OutlineColor = Color3.new(0, 0, 0)
    t.Color        = Color3.fromRGB(200, 230, 255)
    t.Font         = Drawing.Fonts.UI
    t.Transparency = 1
    t.Visible      = false
    return t
end

local function removeLabel(p)
    if labels[p] then labels[p]:Remove(); labels[p] = nil end
end

local function addPlayer(p)
    if p == plr then return end
    labels[p] = newLabel()
end

local function startLoop()
    if conn then return end
    conn = RunService.RenderStepped:Connect(function()
        if not enabled then return end
        for p, lbl in pairs(labels) do
            local pos, dist
            if p.Character then
                pos, dist = getBottomAndDist(p.Character)
            end
            if pos and dist then
                if maxDist > 0 and dist > maxDist then
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

Players.PlayerAdded:Connect(function(p) if p ~= plr then labels[p] = newLabel() end end)
Players.PlayerRemoving:Connect(removeLabel)
for _, p in ipairs(Players:GetPlayers()) do addPlayer(p) end

return {
    SetEnabled = function(_, value)
        enabled = value
        if value then startLoop() else stopLoop() end
    end,
    SetMaxDistance = function(_, value)
        maxDist = value
    end,
}
