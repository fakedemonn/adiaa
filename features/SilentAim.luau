-- [Roblox exploit | client-side | Luau]
-- Camera.CFrame __index spoof — game IK reads fake CFrame facing target,
-- positions arms + gun accordingly. Renderer bypasses __index at C++ level.
-- Player view never moves. Body pivot + raycast direction bend still run.

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
local fakingCam   = false   -- re-entrance guard for the camera spoof

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
    if teamCheck and player.Team ~= nil and lp.Team ~= nil
        and player.Team == lp.Team then return false end
    return true
end

local function getAimPart(player)
    local char = player and player.Character
    if not char then return nil end
    if bodyPart == "Head" then
        return char:FindFirstChild("Head") or char:FindFirstChild("HumanoidRootPart")
    end
    return char:FindFirstChild("UpperTorso")
        or char:FindFirstChild("Torso")
        or char:FindFirstChild("HumanoidRootPart")
end

local function getTarget()
    local cursor  = UIS:GetMouseLocation()
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

-- ── Hook 1: Camera.CFrame __index spoof ───────────────────────────────────────
-- Game IK + gun scripts read Camera.CFrame in Lua → see fake CFrame facing target.
-- Renderer reads camera in C++ → __index never fires → real view untouched.
-- fakingCam guard prevents re-entrance when our own code reads Camera.CFrame.

local camMT    = getrawmetatable(Camera)
setreadonly(camMT, false)
local oldCamMT = camMT.__index

camMT.__index = newcclosure(function(self, key)
    if enabled and locked and key == "CFrame" and self == Camera and not fakingCam then
        local part = getAimPart(locked)
        if part then
            -- *the camera tells everyone it's looking at the target — it is not*
            fakingCam = true
            local realCF = oldCamMT(self, "CFrame")
            fakingCam = false
            return CFrame.lookAt(realCF.Position, part.Position)
        end
    end
    return oldCamMT(self, key)
end)

setreadonly(camMT, true)

-- ── Hook 2: workspace:Raycast — direction bend ────────────────────────────────
-- Belt-and-suspenders on top of the CFrame spoof.
-- If the game pre-computed direction before our __index fired, this catches it.
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

-- ── Hook 3: legacy ray APIs ───────────────────────────────────────────────────
local oldFindRay = workspace.FindPartOnRay
hookfunction(oldFindRay, newcclosure(function(ws, ray, ...)
    if enabled and locked then
        local part = getAimPart(locked)
        if part then
            ray = Ray.new(ray.Origin, (part.Position - ray.Origin).Unit * ray.Direction.Magnitude)
        end
    end
    return oldFindRay(ws, ray, ...)
end))

local oldFindRayIL = workspace.FindPartOnRayWithIgnoreList
hookfunction(oldFindRayIL, newcclosure(function(ws, ray, list, ...)
    if enabled and locked then
        local part = getAimPart(locked)
        if part then
            ray = Ray.new(ray.Origin, (part.Position - ray.Origin).Unit * ray.Direction.Magnitude)
        end
    end
    return oldFindRayIL(ws, ray, list, ...)
end))

-- ── Hook 4: Mouse.__index ─────────────────────────────────────────────────────
local mouseMT    = getrawmetatable(mouse)
setreadonly(mouseMT, false)
local oldMouseMT = mouseMT.__index

mouseMT.__index = newcclosure(function(self, key)
    if enabled and locked and (key == "Hit" or key == "UnitRay") then
        local part = getAimPart(locked)
        if part then
            -- use real cam position, not spoofed CFrame
            fakingCam = true
            local camPos = oldCamMT(Camera, "CFrame").Position
            fakingCam = false
            if key == "Hit" then
                return CFrame.new(part.Position)
            else
                return Ray.new(camPos, (part.Position - camPos).Unit)
            end
        end
    end
    return oldMouseMT(self, key)
end)

setreadonly(mouseMT, true)

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

    if not target then lockDot.Visible = false; return end

    local part = getAimPart(target)
    if not part then lockDot.Visible = false; return end

    local targetPos = part.Position

    -- HRP horizontal pivot — server-side hit validation from character facing
    local char = lp.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if root then
        local flatTarget = Vector3.new(targetPos.X, root.Position.Y, targetPos.Z)
        root.CFrame = root.CFrame:Lerp(
            CFrame.lookAt(root.Position, flatTarget),
            math.min(dt * turnSpeed, 1)
        )
    end

    -- red pip on locked part
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
    for i, c in ipairs(fovCircles) do c.Radius = fov * i / circleCount end
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
    setreadonly(camMT, false)
    camMT.__index = oldCamMT
    setreadonly(camMT, true)
    setreadonly(mouseMT, false)
    mouseMT.__index = oldMouseMT
    setreadonly(mouseMT, true)
end

return M

