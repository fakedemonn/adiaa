-- [Roblox exploit | client-side | Luau]
-- Silent Aim — no camera movement.
-- Body + arm pivot toward target visually.
-- Shot direction intercepted at ScreenPointToRay / ViewportPointToRay level.
-- workspace and Camera __namecall hooks catch method calls even on cached refs.

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

-- ── Hook 1: Camera __namecall — ScreenPointToRay + ViewportPointToRay ─────────
-- Game calls Camera:ScreenPointToRay(x, y) to convert mouse pos → world ray.
-- We return a ray pointing at the locked target instead.
-- __namecall catches method syntax calls even if the game cached Camera methods.

local camMT    = getrawmetatable(Camera)
setreadonly(camMT, false)
local oldCamNC = camMT.__namecall

camMT.__namecall = newcclosure(function(self, ...)
    local method = getnamecallmethod()

    if enabled and locked and self == Camera
        and (method == "ScreenPointToRay" or method == "ViewportPointToRay")
    then
        local part = getAimPart(locked)
        if part then
            -- *the camera lies about the ray — it points at the target, not the cursor*
            local origin = self.CFrame.Position
            local dir    = (part.Position - origin).Unit
            return Ray.new(origin, dir)
        end
    end

    return oldCamNC(self, ...)
end)

setreadonly(camMT, true)

-- ── Hook 2: workspace __namecall — Raycast + FindPartOnRay family ─────────────
-- Catches workspace:Raycast() method calls including when the game cached the ref.
-- Bends direction toward target, keeps magnitude so range checks pass.

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
                    -- *direction bends silently — origin and magnitude stay honest*
                    local newDir = (part.Position - origin).Unit * direction.Magnitude
                    return oldWsNC(self, origin, newDir, params)
                end

            elseif method == "FindPartOnRay" then
                local ray, a, b, c = ...
                if ray then
                    local newDir = (part.Position - ray.Origin).Unit * ray.Direction.Magnitude
                    return oldWsNC(self, Ray.new(ray.Origin, newDir), a, b, c)
                end

            elseif method == "FindPartOnRayWithIgnoreList" then
                local ray, list, a, b = ...
                if ray then
                    local newDir = (part.Position - ray.Origin).Unit * ray.Direction.Magnitude
                    return oldWsNC(self, Ray.new(ray.Origin, newDir), list, a, b)
                end
            end
        end
    end

    return oldWsNC(self, ...)
end)

setreadonly(wsMT, true)

-- ── Hook 3: Mouse.__index — Hit + UnitRay ─────────────────────────────────────
local mouseMT    = getrawmetatable(mouse)
setreadonly(mouseMT, false)
local oldMouseMT = mouseMT.__index

mouseMT.__index = newcclosure(function(self, key)
    if enabled and locked and (key == "Hit" or key == "UnitRay") then
        local part = getAimPart(locked)
        if part then
            local camPos = Camera.CFrame.Position
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

-- ── Arm pitch via Motor6D.Transform ───────────────────────────────────────────
local function aimArm(targetPos)
    local char = lp.Character
    if not char then return end
    local root   = char:FindFirstChild("HumanoidRootPart")
    local lTorso = char:FindFirstChild("LowerTorso")
    local uTorso = char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso")
    if not root or not uTorso then return end

    local toTarget = targetPos - root.Position
    local hDist    = math.sqrt(toTarget.X ^ 2 + toTarget.Z ^ 2)
    local pitch    = math.atan2(toTarget.Y, hDist)

    local waist = lTorso and lTorso:FindFirstChild("Waist")
    if waist then
        waist.Transform = CFrame.Angles(-pitch * 0.35, 0, 0)
    end

    local rShoulder = uTorso:FindFirstChild("RightShoulder")
    if rShoulder then
        rShoulder.Transform = CFrame.Angles(0, 0, -pitch)
    end

    local neck = uTorso:FindFirstChild("Neck")
    if neck then
        neck.Transform = CFrame.Angles(-pitch * 0.5, 0, 0)
    end
end

-- ── Main render loop ───────────────────────────────────────────────────────────
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

    -- body horizontal pivot
    local char = lp.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if root then
        local flat = Vector3.new(targetPos.X, root.Position.Y, targetPos.Z)
        root.CFrame = root.CFrame:Lerp(
            CFrame.lookAt(root.Position, flat),
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

-- Arm Motor6D step — after animator
RunService:BindToRenderStep("SilentAimArm", Enum.RenderPriority.Last.Value + 1, function()
    if not enabled or not locked then return end
    local part = getAimPart(locked)
    if part then aimArm(part.Position) end
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
    RunService:UnbindFromRenderStep("SilentAimArm")
    for _, c in ipairs(fovCircles) do c:Remove() end
    fovCircles = {}
    lockDot:Remove()
    setreadonly(camMT, false)
    camMT.__namecall = oldCamNC
    setreadonly(camMT, true)
    setreadonly(wsMT, false)
    wsMT.__namecall = oldWsNC
    setreadonly(wsMT, true)
    setreadonly(mouseMT, false)
    mouseMT.__index = oldMouseMT
    setreadonly(mouseMT, true)
end

return M
