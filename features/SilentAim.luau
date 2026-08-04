-- [Roblox exploit | client-side | Luau]
-- Silent Aim v4 — no CFrame writes, no Camera hook.
-- Crash source 1: root.CFrame lerp in Heartbeat — removed entirely.
-- Crash source 2: Camera.__namecall fires on internal engine calls — removed.
-- What remains: workspace.__namecall + Mouse.__index + Drawing only.
-- Both hooks redirect bullet direction without touching physics state.

local Players    = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS        = game:GetService("UserInputService")
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
local locked      = nil

-- ── FOV rings ──────────────────────────────────────────────────────────────────
local fovCircles = {}

local function buildCircles()
    for _, c in ipairs(fovCircles) do c:Remove() end
    fovCircles = {}
    local cursor = UIS:GetMouseLocation()
    for i = 1, circleCount do
        local c       = Drawing.new("Circle")
        c.Visible     = enabled
        c.Radius      = fov * i / circleCount
        c.Thickness   = 1
        c.Color       = Color3.fromRGB(255, 255, 255)
        c.Filled      = false
        c.NumSides    = 64
        c.Position    = cursor
        fovCircles[i] = c
    end
end

buildCircles()

local lockDot         = Drawing.new("Circle")
lockDot.Visible       = false
lockDot.Radius        = 4
lockDot.Thickness     = 1
lockDot.Color         = Color3.fromRGB(255, 50, 50)
lockDot.Filled        = true
lockDot.NumSides      = 32
lockDot.Position      = UIS:GetMouseLocation()

-- ── Helpers ────────────────────────────────────────────────────────────────────
local function isEnemy(player)
    if player == lp then return false end
    if teamCheck
        and player.Team ~= nil
        and lp.Team     ~= nil
        and player.Team == lp.Team
    then return false end
    return true
end

local function getAimPart(player)
    local char = player and player.Character
    if not char then return nil end
    if bodyPart == "Head" then
        return char:FindFirstChild("Head")
            or char:FindFirstChild("HumanoidRootPart")
    end
    return char:FindFirstChild("UpperTorso")
        or char:FindFirstChild("Torso")
        or char:FindFirstChild("HumanoidRootPart")
end

local function getTarget()
    local cursor        = UIS:GetMouseLocation()
    local best, minDist = nil, fov
    for _, player in ipairs(Players:GetPlayers()) do
        if not isEnemy(player) then continue end
        local char = player.Character
        local hum  = char and char:FindFirstChildOfClass("Humanoid")
        if not char or not hum or hum.Health <= 0 then continue end
        local part = getAimPart(player)
        if not part then continue end
        local sp, onScreen = Camera:WorldToViewportPoint(part.Position)
        if not onScreen then continue end
        local d = (Vector2.new(sp.X, sp.Y) - cursor).Magnitude
        if d < minDist then minDist = d; best = player end
    end
    return best
end

-- ── Hook 1: workspace __namecall ───────────────────────────────────────────────
-- Catches workspace:Raycast(), FindPartOnRay, FindPartOnRayWithIgnoreList.
-- Fires even on cached workspace refs the game grabbed before this hook ran.
-- NO Camera hook — fires on internal engine calls too and causes crashes.

local wsMT    = getrawmetatable(workspace)
setreadonly(wsMT, false)
local oldWsNC = wsMT.__namecall

wsMT.__namecall = newcclosure(function(self, ...)
    local method = getnamecallmethod()

    if enabled and locked then
        local part = getAimPart(locked)
        if part then

            if method == "Raycast" then
                local origin, direction, params = ...
                if origin and direction then
                    -- *direction bends at hook level — no physics state touched*
                    local bent = (part.Position - origin).Unit * direction.Magnitude
                    return oldWsNC(self, origin, bent, params)
                end

            elseif method == "FindPartOnRay" then
                local ray, a, b, c = ...
                if ray then
                    local bent = (part.Position - ray.Origin).Unit * ray.Direction.Magnitude
                    return oldWsNC(self, Ray.new(ray.Origin, bent), a, b, c)
                end

            elseif method == "FindPartOnRayWithIgnoreList" then
                local ray, list, a, b = ...
                if ray then
                    local bent = (part.Position - ray.Origin).Unit * ray.Direction.Magnitude
                    return oldWsNC(self, Ray.new(ray.Origin, bent), list, a, b)
                end
            end
        end
    end

    return oldWsNC(self, ...)
end)

setreadonly(wsMT, true)

-- ── Hook 2: Mouse.__index ──────────────────────────────────────────────────────
-- Intercepts Hit (CFrame) and UnitRay (Ray) only.
-- Everything else on the mouse falls through untouched.

local mouseMT    = getrawmetatable(mouse)
setreadonly(mouseMT, false)
local oldMouseNC = mouseMT.__index

mouseMT.__index = newcclosure(function(self, key)
    if enabled and locked and (key == "Hit" or key == "UnitRay") then
        local part = getAimPart(locked)
        if part then
            -- *mouse lies to the game — reports target position, not cursor*
            local camPos = Camera.CFrame.Position
            if key == "Hit" then
                return CFrame.new(part.Position)
            else
                return Ray.new(camPos, (part.Position - camPos).Unit)
            end
        end
    end
    return oldMouseNC(self, key)
end)

setreadonly(mouseMT, true)

-- ── RenderStepped: Drawing only — zero physics writes ─────────────────────────
RunService.RenderStepped:Connect(function()
    local cursor = UIS:GetMouseLocation()

    for _, c in ipairs(fovCircles) do
        c.Position = cursor
        c.Visible  = enabled
    end

    if not enabled then
        lockDot.Visible = false
        locked = nil
        return
    end

    local target = getTarget()
    locked = target

    if not target then
        lockDot.Visible = false
        return
    end

    local part = getAimPart(target)
    if not part then lockDot.Visible = false; return end

    -- Lock dot tracks target on screen — pure Drawing, nothing else
    local sp, onScreen = Camera:WorldToViewportPoint(part.Position)
    if onScreen then
        lockDot.Position = Vector2.new(sp.X, sp.Y)
        lockDot.Visible  = true
    else
        lockDot.Visible = false
    end
end)

-- ── Public API ─────────────────────────────────────────────────────────────────
function M:SetEnabled(v)
    enabled = v
    for _, c in ipairs(fovCircles) do c.Visible = v end
    if not v then lockDot.Visible = false; locked = nil end
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
    bodyPart = v == "Torso" and "Torso" or "Head"
end

function M:SetTeamCheck(v)
    teamCheck = v
end

function M:Destroy()
    enabled = false
    locked  = nil
    for _, c in ipairs(fovCircles) do c:Remove() end
    fovCircles = {}
    lockDot:Remove()
    setreadonly(wsMT, false)
    wsMT.__namecall = oldWsNC
    setreadonly(wsMT, true)
    setreadonly(mouseMT, false)
    mouseMT.__index = oldMouseNC
    setreadonly(mouseMT, true)
end

return M
