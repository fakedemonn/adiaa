-- Silent Aim — no visible camera movement.
-- Camera snaps toward target INSIDE the raycast hook, restores after the call returns.
-- Player never sees it move. Server reads camera angle during raycast call — sees correct aim.
-- Also covers legacy FindPartOnRay + FindPartOnRayWithIgnoreList APIs.

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
local turnSpeed   = 12
local locked      = nil

-- ── FOV ring pool ──────────────────────────────────────────────────────────────
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

local lockDot       = Drawing.new("Circle")
lockDot.Visible     = false
lockDot.Radius      = 4
lockDot.Thickness   = 1
lockDot.Color       = Color3.fromRGB(255, 50, 50)
lockDot.Filled      = true
lockDot.NumSides    = 32
lockDot.Position    = UIS:GetMouseLocation()

-- ── Helpers ────────────────────────────────────────────────────────────────────
local function isEnemy(player)
    if player == lp then return false end
    if teamCheck then
        if player.Team ~= nil and lp.Team ~= nil and player.Team == lp.Team then
            return false
        end
    end
    return true
end

local function getAimPart(player)
    local char = player and player.Character
    if not char then return nil end
    if bodyPart == "Head" then
        return char:FindFirstChild("Head") or char:FindFirstChild("HumanoidRootPart")
    elseif bodyPart == "Torso" then
        return char:FindFirstChild("UpperTorso")
            or char:FindFirstChild("Torso")
            or char:FindFirstChild("HumanoidRootPart")
    end
    return char:FindFirstChild("HumanoidRootPart")
end

local function getTarget()
    local cursor  = UIS:GetMouseLocation()
    local best    = nil
    local minDist = fov
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

-- ── Hook 1: workspace:Raycast (modern) ────────────────────────────────────────
-- Redirects direction AND snaps camera for the duration of the call.
-- Camera restore happens before the next render frame — invisible to player.
local oldRaycast = workspace.Raycast
hookfunction(oldRaycast, newcclosure(function(ws, origin, direction, params)
    if enabled and locked then
        local part = getAimPart(locked)
        if part then
            local newDir = (part.Position - origin).Unit * direction.Magnitude
            local oldCF  = Camera.CFrame
            -- *camera lies to the server for exactly one call, then goes back to sleep*
            Camera.CFrame = CFrame.lookAt(Camera.CFrame.Position, part.Position)
            local result  = oldRaycast(ws, origin, newDir, params)
            Camera.CFrame = oldCF
            return result
        end
    end
    return oldRaycast(ws, origin, direction, params)
end))

-- ── Hook 2: workspace:FindPartOnRay (legacy) ──────────────────────────────────
-- Some games still use the old Ray object API — cover it too.
local oldFindRay = workspace.FindPartOnRay
hookfunction(oldFindRay, newcclosure(function(ws, ray, ...)
    if enabled and locked then
        local part = getAimPart(locked)
        if part then
            local newDir = (part.Position - ray.Origin).Unit * ray.Direction.Magnitude
            local oldCF  = Camera.CFrame
            Camera.CFrame = CFrame.lookAt(Camera.CFrame.Position, part.Position)
            local a, b, c, d = oldFindRay(ws, Ray.new(ray.Origin, newDir), ...)
            Camera.CFrame = oldCF
            return a, b, c, d
        end
    end
    return oldFindRay(ws, ray, ...)
end))

-- ── Hook 3: workspace:FindPartOnRayWithIgnoreList (legacy) ───────────────────
local oldFindRayIL = workspace.FindPartOnRayWithIgnoreList
hookfunction(oldFindRayIL, newcclosure(function(ws, ray, ignoreList, ...)
    if enabled and locked then
        local part = getAimPart(locked)
        if part then
            local newDir = (part.Position - ray.Origin).Unit * ray.Direction.Magnitude
            local oldCF  = Camera.CFrame
            Camera.CFrame = CFrame.lookAt(Camera.CFrame.Position, part.Position)
            local a, b, c, d = oldFindRayIL(ws, Ray.new(ray.Origin, newDir), ignoreList, ...)
            Camera.CFrame = oldCF
            return a, b, c, d
        end
    end
    return oldFindRayIL(ws, ray, ignoreList, ...)
end))

-- ── Hook 4: Mouse.__index ─────────────────────────────────────────────────────
local mt       = getrawmetatable(mouse)
setreadonly(mt, false)
local oldIndex = mt.__index
mt.__index = newcclosure(function(self, key)
    if enabled and locked and (key == "Hit" or key == "UnitRay") then
        local part = getAimPart(locked)
        if part then
            local camPos   = Camera.CFrame.Position
            local toTarget = (part.Position - camPos).Unit
            if key == "Hit" then
                return CFrame.new(part.Position)
            else
                return Ray.new(camPos, toTarget)
            end
        end
    end
    return oldIndex(self, key)
end)
setreadonly(mt, true)

-- ── Main loop ─────────────────────────────────────────────────────────────────
RunService.RenderStepped:Connect(function(dt)
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

    local targetPos = part.Position

    -- body pivot — server reads character facing on hit validation
    local char = lp.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if root then
        local flatTarget = Vector3.new(targetPos.X, root.Position.Y, targetPos.Z)
        root.CFrame = root.CFrame:Lerp(
            CFrame.lookAt(root.Position, flatTarget),
            math.min(dt * turnSpeed, 1)
        )
    end

    local sp, onScreen = Camera:WorldToViewportPoint(targetPos)
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

function M:SetSmoothing(v)
    turnSpeed = 4 + ((v - 1) / 99) * 16
end

function M:SetBodyPart(v)
    bodyPart = v == "Torso" and "Torso" or "Head"
end

function M:SetTeamCheck(v)
    teamCheck = v
end

function M:Destroy()
    enabled = false
    for _, c in ipairs(fovCircles) do c:Remove() end
    fovCircles = {}
    lockDot:Remove()
    setreadonly(mt, false)
    mt.__index = oldIndex
    setreadonly(mt, true)
end

return M

