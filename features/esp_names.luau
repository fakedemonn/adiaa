local Players    = game:GetService("Players")
local RunService = game:GetService("RunService")
local Camera     = workspace.CurrentCamera

local plr     = Players.LocalPlayer
local enabled = false
local labels  = {}
local conn    = nil

local function getBoxTop(char)
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hrp or not hum then return nil end

    local hip  = hum.HipHeight + 0.5
    local top3 = hrp.Position + Vector3.new(0, hip + 1.6, 0)
    local topV, vis = Camera:WorldToViewportPoint(top3)
    if not vis or topV.Z < 0 then return nil end

    return Vector2.new(topV.X, topV.Y - 13)
end

local function newLabel(p)
    local t        = Drawing.new("Text")
    t.Text         = p.DisplayName
    t.Size         = 11
    t.Center       = true
    t.Outline      = true
    t.OutlineColor = Color3.new(0, 0, 0)
    t.Color        = Color3.fromRGB(255, 255, 255)
    t.Font         = Drawing.Fonts.UI
    t.Transparency = 1
    t.Visible      = false
    return t
end

local function removeLabel(p)
    if labels[p] then
        labels[p]:Remove()
        labels[p] = nil
    end
end

local function addPlayer(p)
    if p == plr then return end
    labels[p] = newLabel(p)
end

local function startLoop()
    if conn then return end
    conn = RunService.RenderStepped:Connect(function()
        if not enabled then return end
        for p, lbl in pairs(labels) do
            local char = p.Character
            local pos  = char and getBoxTop(char)
            if pos then
                lbl.Position = pos
                lbl.Visible  = true
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

Players.PlayerAdded:Connect(function(p)
    if p ~= plr then labels[p] = newLabel(p) end
end)
Players.PlayerRemoving:Connect(removeLabel)
for _, p in ipairs(Players:GetPlayers()) do addPlayer(p) end

return {
    SetEnabled = function(_, value)
        enabled = value
        if value then startLoop() else stopLoop() end
    end,
}
