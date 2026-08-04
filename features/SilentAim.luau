-- [Roblox exploit | client-side | Luau]
-- UIS:GetMouseLocation() = true screen coords. no GuiInset gap. circle sits on crosshair.
-- Hooks: workspace:Raycast + Mouse.__index. Camera untouched. Character pivots to register hits.

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
local turnSpeed   = 12      -- SetSmoothing drives this
local locked      = nil

-- ── FOV ring pool ──────────────────────────────────────────────────────────────
-- rings sit on the actual crosshair via UIS:GetMouseLocation()
-- ring[i].Radius = fov * i / circleCount — outermost always at fov boundary

local fovCircles = {}

local function buildCircles()
    -- *tear down before rebuild — orphaned Drawing objects bleed into the frame buffer*
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

-- Red pip on the locked target
local lockDot         = Drawing.new("Circle")
lockDot.Visible       = false
lockDot.Radius        = 4
lockDot.Thickness     = 1
lockDot.Color         = Color3.fromRGB(255, 50, 50)
lockDot.Filled        = true
lockDot.NumSides      = 32
lockDot.Position      = UIS:GetMouseLocation()

-- ── Helpers ────────────────────────────────────────────────────────────────────
-- UIS:GetMouseLocation() → true screen position, no GuiInset offset
-- mouse.X/Y             → 58px off in LockCenter games, never use for Drawing
local function getCursor()
    return UIS:GetMouseLocation()
end

local function isEnemy(player)
    -- *respect the flag only if teamCheck is on*
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
        return char:FindFirstChild("Head")
            or char:FindFirstChild("HumanoidRootPart")
    elseif bodyPart == "Torso" then
        return char:FindFirstChild("UpperTorso")
            or char:FindFirstChild("Torso")
            or char:FindFirstChild("HumanoidRootPart")
    end
    return char:FindFirstChild("HumanoidRootPart")
end

local function getTarget()
    -- *measures screen distance from cursor — in LockCenter games cursor == crosshair*
    local cursor  = getCursor()
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
        if d < minDist then
            minDist = d
            best    = player
        end
    end

    return best
end

-- ── Hook 1: workspace:Raycast ──────────────────────────────────────────────────
-- Origin and magnitude preserved. Only direction unit vector rotated toward locked target.
local oldRaycast = workspace.Raycast
hookfunction(oldRaycast, newcclosure(function(ws, origin, direction, params)
    if enabled and locked then
        local part = getAimPart(locked)
        if part then
            -- *barrel still thinks it fired straight — direction just quietly changed*
            direction = (part.Position - origin).Unit * direction.Magnitude
        end
    end
    return oldRaycast(ws, origin, direction, params)
end))

-- ── Hook 2: Mouse.__index ──────────────────────────────────────────────────────
-- Games reading mouse.Hit.Position or mouse.UnitRay to build shot direction
-- get a fake value pointing at the locked target. Everything else falls through.
local mt       = getrawmetatable(mouse)
setreadonly(mt, false)
local oldIndex = mt.__index

mt.__index = newcclosure(function(self, key)
    if enabled and locked and (key == "Hit" or key == "UnitRay") then
        local part = getAimPart(locked)
        if part then
            -- *mouse thinks it's pointing at the wall*
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
    local cursor = getCursor()

    -- anchor every ring to crosshair
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
    if not part then
        lockDot.Visible = false
        return
    end

    local targetPos = part.Position

    -- character body pivots flat on Y to face target
    -- server reads facing on bullet cast — registers hits on games that validate from character direction
    local char = lp.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if root then
        local flatTarget = Vector3.new(targetPos.X, root.Position.Y, targetPos.Z)
        local faceCF     = CFrame.lookAt(root.Position, flatTarget)
        root.CFrame      = root.CFrame:Lerp(faceCF, math.min(dt * turnSpeed, 1))
    end

    -- red pip follows the locked part in screen space
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
    if not v then
        lockDot.Visible = false
        locked = nil
    end
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

-- slider 1 → turnSpeed ~4 (slow lazy pivot)
-- slider 100 → turnSpeed ~20 (near-instant snap)
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
