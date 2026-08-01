-- SilentAim.lua
local Players    = game:GetService("Players")
local RunService = game:GetService("RunService")
local localPlayer = Players.LocalPlayer
local camera = workspace.CurrentCamera

local enabled  = false
local fov      = 100
local bodyPart = "Head"

-- FOV circle via Drawing API
local fovCircle = Drawing.new("Circle")
fovCircle.Visible   = false
fovCircle.Radius    = fov
fovCircle.Color     = Color3.fromRGB(255, 255, 255)
fovCircle.Thickness = 1
fovCircle.Filled    = false
fovCircle.NumSides  = 64

-- update circle pos every frame
RunService.RenderStepped:Connect(function()
    fovCircle.Position = Vector2.new(
        camera.ViewportSize.X / 2,
        camera.ViewportSize.Y / 2
    )
    fovCircle.Radius  = fov
    fovCircle.Visible = enabled
end)

-- map dropdown value to actual part name
local function getPartName()
    if bodyPart == "Head"       then return "Head"
    elseif bodyPart == "Upper Body" then return "UpperTorso"
    elseif bodyPart == "Legs"   then return "LeftFoot"
    end
    return "Head"
end

-- closest player within fov circle
local function getTarget()
    local closestPlayer = nil
    local closestDist   = fov
    local center = Vector2.new(camera.ViewportSize.X / 2, camera.ViewportSize.Y / 2)

    for _, player in ipairs(Players:GetPlayers()) do
        if player == localPlayer then continue end
        local char = player.Character
        if not char then continue end
        local hum = char:FindFirstChildOfClass("Humanoid")
        if not hum or hum.Health <= 0 then continue end

        local part = char:FindFirstChild(getPartName())
            or char:FindFirstChild("HumanoidRootPart")
        if not part then continue end

        local screenPos, onScreen = camera:WorldToViewportPoint(part.Position)
        if not onScreen then continue end

        local dist = (Vector2.new(screenPos.X, screenPos.Y) - center).Magnitude
        if dist < closestDist then
            closestDist   = dist
            closestPlayer = player
        end
    end

    return closestPlayer
end

-- __namecall hook — intercepts raycast calls and bends them toward target
local mt = getrawmetatable(game)
setreadonly(mt, false)

local oldNamecall = mt.__namecall
mt.__namecall = newcclosure(function(self, ...)
    local method = getnamecallmethod()
    local args   = {...}

    if enabled then
        if method == "FindPartOnRayWithIgnoreList"
        or method == "FindPartOnRayWithWhitelist" then
            local target = getTarget()
            if target then
                local char = target.Character
                local part = char and (
                    char:FindFirstChild(getPartName())
                    or char:FindFirstChild("HumanoidRootPart")
                )
                if part then
                    local ray    = args[1]
                    local origin = ray.Origin
                    local mag    = ray.Direction.Magnitude
                    args[1] = Ray.new(origin, (part.Position - origin).Unit * mag)
                end
            end

        elseif method == "Raycast" then
            local target = getTarget()
            if target then
                local char = target.Character
                local part = char and (
                    char:FindFirstChild(getPartName())
                    or char:FindFirstChild("HumanoidRootPart")
                )
                if part then
                    local origin = args[1]
                    local mag    = args[2].Magnitude
                    args[2] = (part.Position - origin).Unit * mag
                end
            end
        end
    end

    return oldNamecall(self, table.unpack(args))
end)

setreadonly(mt, true)

-- return module so UI.luau can control it
return {
    SetEnabled = function(val)
        enabled = val
        fovCircle.Visible = val
    end,
    SetFov = function(val)
        fov = val
    end,
    SetBodyPart = function(val)
        bodyPart = val
    end,
}
