-- [Context: Silent Aim v3 | 3rd person / shift lock | Auto-lock, no auto-fire]
-- *enemy enters fov. character turns. camera locks. you pull the trigger.*

local Players     = game:GetService("Players")
local RunService  = game:GetService("RunService")
local Camera      = workspace.CurrentCamera
local lp          = Players.LocalPlayer
local mouse       = lp:GetMouse()

local M         = {}
local enabled   = false
local fov       = 120
local bodyPart  = "Head"
local teamCheck = true
local smoothing = 0.15
local locked    = nil

-- ── FOV CIRCLE ────────────────────────────────────────────────────────────────
local fovCircle        = Drawing.new("Circle")
fovCircle.Visible      = false
fovCircle.Radius       = fov
fovCircle.Thickness    = 1
fovCircle.Color        = Color3.fromRGB(255, 255, 255)
fovCircle.Filled       = false
fovCircle.NumSides     = 64
fovCircle.Position     = Camera.ViewportSize / 2

-- Lock dot — shows who's locked
local lockDot          = Drawing.new("Circle")
lockDot.Visible        = false
lockDot.Radius         = 4
lockDot.Thickness      = 1
lockDot.Color          = Color3.fromRGB(255, 50, 50)
lockDot.Filled         = true
lockDot.NumSides       = 32
lockDot.Position       = Camera.ViewportSize / 2

-- ── UTILS ────────────────────────────────────────────────────────────────────
local function isEnemy(player)
    if player == lp then return false end
    if not teamCheck then return true end
    if lp.Team and player.Team then
        return lp.Team ~= player.Team
    end
    if lp.TeamColor and player.TeamColor then
        return lp.TeamColor ~= player.TeamColor
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

local function screenCenter()
    return Camera.ViewportSize / 2
end

-- ── TARGET RESOLUTION ────────────────────────────────────────────────────────
local function getTarget()
    local center  = screenCenter()
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
        local d = (Vector2.new(sp.X, sp.Y) - center).Magnitude
        if d < minDist then
            minDist = d
            best    = player
        end
    end

    return best
end

-- ── RAYCAST HOOK ─────────────────────────────────────────────────────────────
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

-- ── MOUSE HOOK ───────────────────────────────────────────────────────────────
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
    local center = screenCenter()

    fovCircle.Position = center
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
    local origin    = Camera.CFrame.Position

    -- Camera lock toward target
    -- *server validates from camera direction. this is what makes the hit count.*
    local targetCF = CFrame.lookAt(origin, targetPos)
    Camera.CFrame  = Camera.CFrame:Lerp(targetCF, math.min(dt / smoothing, 1))

    -- Character body faces target (3rd person / shift lock)
    -- *body turns. shift lock follows. shot registers from real character facing.*
    local char = lp.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if root then
        local flatTarget = Vector3.new(targetPos.X, root.Position.Y, targetPos.Z)
        local faceCF     = CFrame.lookAt(root.Position, flatTarget)
        root.CFrame      = root.CFrame:Lerp(faceCF, math.min(dt * 12, 1))
    end

    -- Lock dot on target
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

function M:SetSmoothing(v)
    smoothing = 0.3 - ((v - 1) / 99) * 0.25
end

function M:SetBodyPart(v)
    bodyPart = v == "Torso" and "Torso" or "Head"
end

function M:SetTeamCheck(v)
    teamCheck = v
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
