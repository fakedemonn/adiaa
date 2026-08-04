-- [Roblox exploit | client-side | Luau]
-- Silent Aim — no remotes, no camera movement.
-- Hook 1: workspace:Raycast   → bends direction toward target, keeps magnitude
-- Hook 2: Mouse.__index       → fakes Hit/UnitRay toward target
-- Executor deps: hookfunction, newcclosure, getrawmetatable, setreadonly, Drawing

local Players    = game:GetService("Players")
local RunService = game:GetService("RunService")
local Camera     = workspace.CurrentCamera
local lp         = Players.LocalPlayer
local mouse      = lp:GetMouse()

-- ── State ──────────────────────────────────────────────────────────────────────
local M           = {}
local enabled     = false
local fov         = 120
local circleCount = 1
local bodyPart    = "Head"
local teamCheck   = true

-- ── FOV ring pool ──────────────────────────────────────────────────────────────
-- ring[i].Radius = fov * i / circleCount
-- outermost ring always lands exactly on the fov boundary

local fovCircles = {}

local function buildCircles()
    -- *tear down before rebuilding — orphaned Drawing objects leak into the frame buffer*
    for _, c in ipairs(fovCircles) do c:Remove() end
    fovCircles = {}
    local center = Camera.ViewportSize / 2
    for i = 1, circleCount do
        local c       = Drawing.new("Circle")
        c.Visible     = enabled
        c.Radius      = fov * i / circleCount
        c.Thickness   = 1
        c.Color       = Color3.fromRGB(255, 255, 255)
        c.Filled      = false
        c.NumSides    = 64
        c.Position    = center
        fovCircles[i] = c
    end
end

buildCircles()

-- ── Target resolution ──────────────────────────────────────────────────────────
local function isTeammate(player)
    if not teamCheck then return false end
    return player.Team ~= nil
        and lp.Team   ~= nil
        and player.Team == lp.Team
end

local function getPart(player)
    local char = player and player.Character
    if not char then return nil end
    return char:FindFirstChild(bodyPart)
        or char:FindFirstChild("HumanoidRootPart")
end

local function getTarget()
    -- *scans viewport, picks the skull closest to crosshair within the outermost ring*
    local center  = Camera.ViewportSize / 2
    local best    = nil
    local minDist = fov

    for _, player in ipairs(Players:GetPlayers()) do
        if player == lp         then continue end
        if isTeammate(player)   then continue end
        local char = player.Character
        if not char             then continue end
        local hum  = char:FindFirstChildOfClass("Humanoid")
        if not hum or hum.Health <= 0 then continue end
        local part = getPart(player)
        if not part             then continue end

        local screenPos, onScreen = Camera:WorldToViewportPoint(part.Position)
        if not onScreen         then continue end

        local d = (Vector2.new(screenPos.X, screenPos.Y) - center).Magnitude
        if d < minDist then
            minDist = d
            best    = player
        end
    end

    return best
end

-- ── Hook 1: workspace:Raycast ──────────────────────────────────────────────────
-- Keeps origin and direction.Magnitude intact — server range checks survive.
-- Only the unit vector gets rotated toward the target part.

local oldRaycast = workspace.Raycast
hookfunction(oldRaycast, newcclosure(function(ws, origin, direction, params)
    if enabled then
        local t = getTarget()
        if t then
            local part = getPart(t)
            if part then
                -- *physics bends — barrel still thinks it fired straight*
                direction = (part.Position - origin).Unit * direction.Magnitude
            end
        end
    end
    return oldRaycast(ws, origin, direction, params)
end))

-- ── Hook 2: Mouse.__index ──────────────────────────────────────────────────────
-- Intercepts Hit and UnitRay at the metamethod level.
-- Everything else on the mouse falls through to the real __index untouched.

local mt       = getrawmetatable(mouse)
setreadonly(mt, false)
local oldIndex = mt.__index

mt.__index = newcclosure(function(self, key)
    if enabled and (key == "Hit" or key == "UnitRay") then
        local t = getTarget()
        if t then
            local part = getPart(t)
            if part then
                -- *the mouse is a liar; it reports the target, not the cursor*
                local camPos   = Camera.CFrame.Position
                local toTarget = (part.Position - camPos).Unit
                if key == "Hit" then
                    return CFrame.new(part.Position)
                else
                    return Ray.new(camPos, toTarget)
                end
            end
        end
    end
    return oldIndex(self, key)
end)

setreadonly(mt, true)

-- ── Heartbeat: keep rings centered ────────────────────────────────────────────
local heartbeatConn = RunService.Heartbeat:Connect(function()
    local center = Camera.ViewportSize / 2
    for _, c in ipairs(fovCircles) do
        c.Position = center
    end
end)

-- ── Public API ─────────────────────────────────────────────────────────────────
function M:SetEnabled(v)
    enabled = v
    for _, c in ipairs(fovCircles) do c.Visible = v end
end

function M:SetFOV(v)
    fov = v
    for i, c in ipairs(fovCircles) do
        c.Radius = fov * i / circleCount
    end
end

function M:SetCircleCount(v)
    circleCount = v
    buildCircles()
end

function M:SetBodyPart(v)
    bodyPart = v
end

function M:SetTeamCheck(v)
    teamCheck = v
end

function M:Destroy()
    enabled = false
    for _, c in ipairs(fovCircles) do c:Remove() end
    fovCircles = {}
    heartbeatConn:Disconnect()
    setreadonly(mt, false)
    mt.__index = oldIndex
    setreadonly(mt, true)
    -- workspace:Raycast patch clears with executor session end
end

return M

