local Players    = game:GetService("Players")
local RunService = game:GetService("RunService")
local Camera     = workspace.CurrentCamera

local plr     = Players.LocalPlayer
local enabled = false
local boxes   = {}
local conn    = nil

local function getBounds(char)
    local minX, minY = math.huge,  math.huge
    local maxX, maxY = -math.huge, -math.huge
    local valid = false

    for _, part in ipairs(char:GetDescendants()) do
        if part:IsA("BasePart") then
            local sv, vis = Camera:WorldToViewportPoint(part.Position)
            if vis and sv.Z > 0 then
                valid = true
                if sv.X < minX then minX = sv.X end
                if sv.Y < minY then minY = sv.Y end
                if sv.X > maxX then maxX = sv.X end
                if sv.Y > maxY then maxY = sv.Y end
            end
        end
    end

    if not valid then return nil end

    local pad = 6
    return {
        x = minX - pad,
        y = minY - pad,
        w = (maxX - minX) + pad * 2,
        h = (maxY - minY) + pad * 2,
    }
end

local function newBox()
    local lines = {}
    for i = 1, 8 do
        local l        = Drawing.new("Line")
        l.Thickness    = 1.5
        l.Color        = Color3.fromRGB(255, 255, 255)
        l.Transparency = 1
        l.Visible      = false
        lines[i] = l
    end
    return lines
end

local function drawBox(lines, b)
    local CL = math.floor(b.w * 0.28)
    local CV = math.floor(b.h * 0.22)

    lines[1].From = Vector2.new(b.x,       b.y);       lines[1].To = Vector2.new(b.x + CL,       b.y)
    lines[2].From = Vector2.new(b.x,       b.y);       lines[2].To = Vector2.new(b.x,             b.y + CV)
    lines[3].From = Vector2.new(b.x + b.w, b.y);       lines[3].To = Vector2.new(b.x + b.w - CL, b.y)
    lines[4].From = Vector2.new(b.x + b.w, b.y);       lines[4].To = Vector2.new(b.x + b.w,      b.y + CV)
    lines[5].From = Vector2.new(b.x,       b.y + b.h); lines[5].To = Vector2.new(b.x + CL,       b.y + b.h)
    lines[6].From = Vector2.new(b.x,       b.y + b.h); lines[6].To = Vector2.new(b.x,             b.y + b.h - CV)
    lines[7].From = Vector2.new(b.x + b.w, b.y + b.h); lines[7].To = Vector2.new(b.x + b.w - CL, b.y + b.h)
    lines[8].From = Vector2.new(b.x + b.w, b.y + b.h); lines[8].To = Vector2.new(b.x + b.w,      b.y + b.h - CV)

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

local function addPlayer(p)
    if p == plr then return end
    boxes[p] = newBox()
end

local function startLoop()
    if conn then return end
    conn = RunService.RenderStepped:Connect(function()
        if not enabled then return end
        for p, lines in pairs(boxes) do
            local b = p.Character and getBounds(p.Character)
            if b then drawBox(lines, b) else hideBox(lines) end
        end
    end)
end

local function stopLoop()
    if conn then conn:Disconnect() conn = nil end
    for _, lines in pairs(boxes) do hideBox(lines) end
end

Players.PlayerAdded:Connect(addPlayer)
Players.PlayerRemoving:Connect(removeBox)
for _, p in ipairs(Players:GetPlayers()) do addPlayer(p) end

return {
    SetEnabled = function(_, value)
        enabled = value
        if value then startLoop() else stopLoop() end
    end,
}
