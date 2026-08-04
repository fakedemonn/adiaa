-- [Context: Silent Aim | Camera rotation method | No remote hook | Volt]
-- *camera moves to target. server sees a real aim. hit counts.*

local Players    = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS        = game:GetService("UserInputService")
local localPlayer = Players.LocalPlayer
local camera     = workspace.CurrentCamera

-- ── CONFIG ───────────────────────────────────────────────────────────────────
local CFG = {
    Enabled         = false,
    FOVRadius       = 120,       -- pixels from screen center
    Smoothing       = 0.15,      -- 0.05 = near instant | 0.3 = smooth
    MaxDistance     = 2500,      -- studs
    MaxRedirectAngle = 89,       -- degrees max camera rotation per shot
    TeamCheck       = true,
}

local AIM_PRIORITY = {"Head", "UpperTorso", "HumanoidRootPart"}
-- ─────────────────────────────────────────────────────────────────────────────

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

-- ── GET NEAREST TARGET IN FOV ────────────────────────────────────────────────
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

        -- Walk priority list — head first
        local committed = nil
        for _, partName in ipairs(AIM_PRIORITY) do
            local part = char:FindFirstChild(partName)
            if not part then continue end

            local sp, onScreen = w2s(part.Position)
            if not onScreen then continue end

            local screenDist = (sp - center).Magnitude
            if screenDist <= CFG.FOVRadius then
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

-- ── AIM LOOP ─────────────────────────────────────────────────────────────────
-- Runs every RenderStepped — rotates camera toward target smoothly
-- *camera lerps. target fills crosshair. shot fires. server confirms.*
RunService.RenderStepped:Connect(function(dt)
    if not CFG.Enabled then return end

    local target = getNearestTarget()
    if not target then return end

    local origin    = camera.CFrame.Position
    local targetPos = target.Position

    -- Angle check — don't rotate more than MaxRedirectAngle
    local currentLook = camera.CFrame.LookVector
    local desiredLook = (targetPos - origin).Unit
    local dot         = math.clamp(currentLook:Dot(desiredLook), -1, 1)
    local angleDeg    = math.deg(math.acos(dot))

    if angleDeg > CFG.MaxRedirectAngle then return end

    -- Smooth camera lerp toward target
    local targetCF = CFrame.lookAt(origin, targetPos)
    camera.CFrame  = camera.CFrame:Lerp(targetCF, math.min(dt / CFG.Smoothing, 1))
end)

-- ── PUBLIC API ────────────────────────────────────────────────────────────────
return {
    SetEnabled = function(_, value)
        CFG.Enabled = value
    end,

    SetFOV = function(_, value)
        CFG.FOVRadius = value
    end,

    SetSmoothing = function(_, value)
        -- slider 1-100 → smoothing 0.3-0.05
        CFG.Smoothing = 0.3 - ((value - 1) / 99) * 0.25
    end,

    SetBodyPart = function(_, value)
        if value == "Head" then
            AIM_PRIORITY = {"Head", "UpperTorso", "HumanoidRootPart"}
        elseif value == "Upper Body" then
            AIM_PRIORITY = {"UpperTorso", "Torso", "HumanoidRootPart"}
        elseif value == "Legs" then
            AIM_PRIORITY = {"LeftUpperLeg", "RightUpperLeg", "HumanoidRootPart"}
        end
    end,

    SetTeamCheck = function(_, value)
        CFG.TeamCheck = value
    end,
}
