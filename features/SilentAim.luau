-- [Context: Silent Aim v3 | Cursor-tracked FOV | No camera lock | Character faces, camera roams]
-- *circle hugs the cursor. enemy steps inside. body pivots. camera stays yours. pull.*

local Players    = game:GetService("Players")
local RunService = game:GetService("RunService")
local Camera     = workspace.CurrentCamera
local lp         = Players.LocalPlayer
local mouse      = lp:GetMouse()

local M          = {}
local enabled    = false
local fov        = 120
local bodyPart   = "Head"
local turnSpeed  = 12        -- controlled by SetSmoothing; higher = snappier body pivot
local locked     = nil

-- ── FOV CIRCLE — lives on the cursor ─────────────────────────────────────────
local fovCircle       = Drawing.new("Circle")
fovCircle.Visible     = false
fovCircle.Radius      = fov
fovCircle.Thickness   = 1
fovCircle.Color       = Color3.fromRGB(255, 255, 255)
fovCircle.Filled      = false
fovCircle.NumSides    = 64
fovCircle.Position    = Vector2.new(mouse.X, mouse.Y)

-- Lock dot — red pip that sits on the locked part in screen space
local lockDot         = Drawing.new("Circle")
lockDot.Visible       = false
lockDot.Radius        = 4
lockDot.Thickness     = 1
lockDot.Color         = Color3.fromRGB(255, 50, 50)
lockDot.Filled        = true
lockDot.NumSides      = 32
lockDot.Position      = Vector2.new(mouse.X, mouse.Y)

-- ── UTILS ─────────────────────────────────────────────────────────────────────
local function isEnemy(player)
    return player ~= lp  -- no mercy. no teammates. everyone is a target.
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

local function getCursor()
    return Vector2.new(mouse.X, mouse.Y)
end

-- ── TARGET RESOLUTION — measured from cursor, not screen center ───────────────
local function getTarget()
    local cursor  = getCursor()
    local best    = nil
    local minDist = fov   -- anything outside the FOV radius is ignored

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

-- ── RAYCAST HOOK — bends the bullet toward locked part ───────────────────────
-- *workspace.Raycast is what the gun actually fires. intercept here, aim there.*
local oldRaycast = workspace.Raycast
hookfunction(oldRaycast, newcclosure(function(ws, origin, direction, params)
    if enabled and locked then
        local part = getAimPart(locked)
        if part then
            direction = (part.Position - origin).Unit * direction.Magnitude
        end
    end
    return oldRaycast(ws, origin, direction, params)
end))

-- ── MOUSE HOOK — Hit and UnitRay both point at the locked part ────────────────
-- *gun reads mouse.Hit to know where to shoot. we lie to the gun.*
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

-- ── MAIN LOOP ─────────────────────────────────────────────────────────────────
RunService.RenderStepped:Connect(function(dt)
    local cursor = getCursor()

    -- FOV circle trails the cursor every frame
    fovCircle.Position = cursor
    fovCircle.Visible  = enabled

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

    -- Camera is completely untouched — player owns their view the whole time.
    -- Character body pivots to face the target flat on Y axis.
    -- *body turns. shift lock syncs. server reads facing on bullet cast. hit registers.*
    local char = lp.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if root then
        local flatTarget = Vector3.new(targetPos.X, root.Position.Y, targetPos.Z)
        local faceCF     = CFrame.lookAt(root.Position, flatTarget)
        root.CFrame      = root.CFrame:Lerp(faceCF, math.min(dt * turnSpeed, 1))
    end

    -- Red pip on the locked part's screen position
    local sp, onScreen = Camera:WorldToViewportPoint(targetPos)
    if onScreen then
        lockDot.Position = Vector2.new(sp.X, sp.Y)
        lockDot.Visible  = true
    else
        lockDot.Visible = false
    end
end)

-- ── PUBLIC API ────────────────────────────────────────────────────────────────
function M:SetEnabled(v)
    enabled           = v
    fovCircle.Visible = v
    if not v then
        lockDot.Visible = false
        locked = nil
    end
end

function M:SetFOV(v)
    fov              = v
    fovCircle.Radius = v
end

-- Smoothing slider now drives body turn speed.
-- slider 1  → turnSpeed ~4  (slow, gradual pivot)
-- slider 100 → turnSpeed ~20 (near-instant snap)
function M:SetSmoothing(v)
    turnSpeed = 4 + ((v - 1) / 99) * 16
end

function M:SetBodyPart(v)
    bodyPart = v == "Torso" and "Torso" or "Head"
end

function M:Destroy()
    enabled = false
    fovCircle:Remove()
    lockDot:Remove()
    setreadonly(mt, false)
    mt.__index = oldIndex
    setreadonly(mt, true)
end

return M
