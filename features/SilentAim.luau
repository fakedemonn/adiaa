-- [Roblox exploit | client-side | Luau]
-- Silent Aim — no camera movement.
-- Character body rotates horizontally toward target (HRP pivot).
-- Arm + gun pitch toward target via Motor6D.Transform override.
-- Runs at RenderPriority.Last+1 — fires AFTER game animator. Our write wins.

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

-- ── Mouse hook ─────────────────────────────────────────────────────────────────
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

-- ── Raycast hook ───────────────────────────────────────────────────────────────
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

-- ── Arm pivot via Motor6D.Transform ───────────────────────────────────────────
-- Runs at RenderPriority.Last + 1 = after game's animator writes Transform.
-- Overrides Waist and RightShoulder to pitch the arm toward the locked target.
--
-- If the arm swings the WRONG direction, flip the sign on rShoulder pitch line.
-- If it over/under-rotates, adjust the 0.35 / 1.0 multipliers.

local function aimArm(targetPos)
    local char = lp.Character
    if not char then return end

    local root   = char:FindFirstChild("HumanoidRootPart")
    local lTorso = char:FindFirstChild("LowerTorso")
    local uTorso = char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso")
    if not root or not uTorso then return end

    -- pitch angle: how far above/below the root is the target
    local toTarget = targetPos - root.Position
    local hDist    = math.sqrt(toTarget.X ^ 2 + toTarget.Z ^ 2)
    local pitch    = math.atan2(toTarget.Y, hDist)  -- positive = target is above

    -- Waist: upper-body tilts partially toward target elevation
    local waist = lTorso and lTorso:FindFirstChild("Waist")
    if waist then
        -- *upper body leans into the shot — waist carries 35% of the pitch*
        waist.Transform = CFrame.Angles(-pitch * 0.35, 0, 0)
    end

    -- RightShoulder: arm raises or lowers to match target pitch
    -- Negative sign: R15 arm needs to go up when target is above (Z-axis on shoulder)
    local rShoulder = uTorso:FindFirstChild("RightShoulder")
    if rShoulder then
        -- *the arm swings like it knows exactly where the head is*
        rShoulder.Transform = CFrame.Angles(0, 0, -pitch)
    end

    -- Neck: head tilts naturally toward target (subtle, looks less robotic)
    local neck = uTorso:FindFirstChild("Neck")
    if neck then
        neck.Transform = CFrame.Angles(-pitch * 0.5, 0, 0)
    end
end

-- ── Main loop — body + FOV rings ───────────────────────────────────────────────
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

    -- HRP horizontal pivot — body faces target, camera stays yours
    local char = lp.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if root then
        local flat = Vector3.new(targetPos.X, root.Position.Y, targetPos.Z)
        root.CFrame = root.CFrame:Lerp(
            CFrame.lookAt(root.Position, flat),
            math.min(dt * turnSpeed, 1)
        )
    end

    -- lock dot on screen
    local sp, onScreen = Camera:WorldToViewportPoint(targetPos)
    if onScreen then
        lockDot.Position = Vector2.new(sp.X, sp.Y)
        lockDot.Visible  = true
    else
        lockDot.Visible = false
    end
end)

-- Arm Motor6D step — runs AFTER game animator, wins the write
RunService:BindToRenderStep(
    "SilentAimArm",
    Enum.RenderPriority.Last.Value + 1,
    function()
        if not enabled or not locked then return end
        local part = getAimPart(locked)
        if part then aimArm(part.Position) end
    end
)

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
    setreadonly(mouseMT, false)
    mouseMT.__index = oldMouseMT
    setreadonly(mouseMT, true)
end

return M
