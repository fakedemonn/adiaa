-- [Context: Silent Aim | Camera rotation + FOV circle | Volt]
-- *camera moves to target. FOV ring shows the lock radius.*

local Players     = game:GetService("Players")
local RunService  = game:GetService("RunService")
local localPlayer = Players.LocalPlayer
local camera      = workspace.CurrentCamera

local CFG = {
    Enabled          = false,
    FOVRadius        = 120,
    Smoothing        = 0.15,
    MaxDistance      = 2500,
    MaxRedirectAngle = 89,
    TeamCheck        = true,
}

local AIM_PRIORITY = {"Head", "UpperTorso", "HumanoidRootPart"}

-- ── FOV CIRCLE ────────────────────────────────────────────────────────────────
local FOVCircle        = Drawing.new("Circle")
FOVCircle.Visible      = false
FOVCircle.Color        = Color3.fromRGB(255, 255, 255)
FOVCircle.Thickness    = 1
FOVCircle.Filled       = false
FOVCircle.Transparency = 1
FOVCircle.Radius       = CFG.FOVRadius

-- ── TEAM CHECK ───────────────────────────────────────────────────────────────
local function isEnemy(player)
    if player == localPlayer then return false end
    if CFG.TeamCheck then
        if localPlayer.Team and player.Team then
            return localPlayer.Team ~= player.Team
        end
        if localPlayer.TeamColor and player.TeamColor then
            return localPlayer.TeamColor ~= player.TeamColor
        end
    end
    return true
end

-- ── UTILS ────────────────────────────────────────────────────────────────────
local function w2s(worldPos)
    local sp, inBounds = camera:WorldToViewportPoint(worldPos)
    return Vector2.new(sp.X, sp.Y), inBounds
end

local function screenCenter()
    local vp = camera.ViewportSize
    return Vector2.new(vp.X / 2, vp.Y / 2)
end

-- ── GET NEAREST TARGET ───────────────────────────────────────────────────────
local function getNearestTarget()
    local center   = screenCenter()
    local bestPart = nil
    local bestDist = math.huge

    for _, player in ipairs(Players:GetPlayers()) do
        if not isEnemy(player) then continue end

        local char = player.Character
        local hum  = char and char:FindFirstChildOfClass("Humanoid")
        if not char or not hum or hum.Health <= 0 then continue end

        local worldDist = (char:GetPivot().Position - camera.CFrame.Position).Magnitude
        if worldDist > CFG.MaxDistance then continue end

        local committed = nil
        for _, partName in ipairs(AIM_PRIORITY) do
            local part = char:FindFirstChild(partName)
            if not part then continue end
            local sp, onScreen = w2s(part.Position)
            if not onScreen then continue end
            if (sp - center).Magnitude <= CFG.FOVRadius then
                committed = part
                break
            end
        end

        if not committed then continue end

        local headPart = char:FindFirstChild("Head") or committed
        local headSP   = w2s(headPart.Position)
        local rankDist = (headSP - center).Magnitude

        if rankDist < bestDist then
            bestDist = rankDist
            bestPart = committed
        end
    end

    return bestPart
end

-- ── RENDER LOOP ───────────────────────────────────────────────────────────────
RunService.RenderStepped:Connect(function(dt)
    local center = screenCenter()

    -- FOV circle always at screen center when enabled
    FOVCircle.Position = center
    FOVCircle.Visible  = CFG.Enabled

    if not CFG.Enabled then return end

    local target = getNearestTarget()
    if not target then return end

    local origin    = camera.CFrame.Position
    local targetPos = target.Position

    local currentLook = camera.CFrame.LookVector
    local desiredLook = (targetPos - origin).Unit
    local dot         = math.clamp(currentLook:Dot(desiredLook), -1, 1)
    local angleDeg    = math.deg(math.acos(dot))

    if angleDeg > CFG.MaxRedirectAngle then return end

    -- *camera lerps toward target. server sees real aim. hit counts.*
    local targetCF = CFrame.lookAt(origin, targetPos)
    camera.CFrame  = camera.CFrame:Lerp(targetCF, math.min(dt / CFG.Smoothing, 1))
end)

-- ── PUBLIC API ────────────────────────────────────────────────────────────────
return {
    SetEnabled = function(_, value)
        CFG.Enabled       = value
        FOVCircle.Visible = value
    end,

    SetFOV = function(_, value)
        CFG.FOVRadius  = value
        FOVCircle.Radius = value
    end,

    SetSmoothing = function(_, value)
        CFG.Smoothing = 0.3 - ((value - 1) / 99) * 0.25
    end,

    SetBodyPart = function(_, value)
        if value == "Head" then
            AIM_PRIORITY = {"Head", "UpperTorso", "HumanoidRootPart"}
        elseif value == "Torso" then
            AIM_PRIORITY = {"UpperTorso", "Torso", "HumanoidRootPart"}
        end
    end,

    SetTeamCheck = function(_, value)
        CFG.TeamCheck = value
    end,
}
