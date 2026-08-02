-- features/FlyCar.luau
local Players    = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS        = game:GetService("UserInputService")
local localPlayer = Players.LocalPlayer
local camera     = workspace.CurrentCamera

local CFG = {
    Speed     = 160,
    LiftSpeed = 60,
    UpKey     = Enum.KeyCode.E,
    DownKey   = Enum.KeyCode.Q,
    BoostKey  = Enum.KeyCode.RightShift,
    BoostMult = 2.0,
    YawSpeed  = 10,
}

local FlyCar = {}

local flying, bv, bg, vehicleRoot, vehicle, yaw = false, nil, nil, nil, nil, 0
local prevCamType = Enum.CameraType.Custom
local heartbeat   = nil

local function getVehicle()
    local char = localPlayer.Character
    local hum  = char and char:FindFirstChildOfClass("Humanoid")
    local seat = hum and hum.SeatPart
    if not seat then return nil, nil end
    local v    = seat.Parent
    local root = v:FindFirstChildOfClass("VehicleSeat")
        or v.PrimaryPart
        or v:FindFirstChildOfClass("BasePart")
    return root, v
end

local function attachFly(root, v)
    if bv then bv:Destroy() end
    if bg then bg:Destroy() end

    local seat = v:FindFirstChildOfClass("VehicleSeat")
    if seat then
        seat.Throttle  = 0
        seat.Steer     = 0
        seat.MaxSpeed  = 0
        seat.TurnSpeed = 0
    end

    prevCamType          = camera.CameraType
    camera.CameraType    = Enum.CameraType.Custom
    camera.CameraSubject = localPlayer.Character
        and localPlayer.Character:FindFirstChild("HumanoidRootPart")
        or camera.CameraSubject

    bv          = Instance.new("BodyVelocity")
    bv.Velocity = Vector3.zero
    bv.MaxForce = Vector3.new(1e9, 1e9, 1e9)
    bv.P        = 1e5
    bv.Parent   = root

    bg           = Instance.new("BodyGyro")
    bg.MaxTorque = Vector3.new(1e9, 1e9, 1e9)
    bg.P         = 1e6
    bg.D         = 1e4
    bg.CFrame    = CFrame.new(root.Position) * CFrame.Angles(0, yaw, 0)
    bg.Parent    = root

    vehicleRoot = root
    vehicle     = v
end

local function detachFly()
    if bv then bv:Destroy() bv = nil end
    if bg then bg:Destroy() bg = nil end

    camera.CameraType    = prevCamType
    camera.CameraSubject = localPlayer.Character
        and localPlayer.Character:FindFirstChild("Humanoid")
        or camera.CameraSubject

    if vehicle then
        local seat = vehicle:FindFirstChildOfClass("VehicleSeat")
        if seat then
            seat.MaxSpeed  = 100
            seat.TurnSpeed = 1
        end
    end

    vehicleRoot = nil
    vehicle     = nil
end

local function startLoop()
    if heartbeat then heartbeat:Disconnect() end
    heartbeat = RunService.Heartbeat:Connect(function(dt)
        if not flying or not bv or not vehicleRoot then return end

        local char = localPlayer.Character
        local hum  = char and char:FindFirstChildOfClass("Humanoid")
        if not hum or not hum.SeatPart then
            flying = false
            detachFly()
            return
        end

        for _, part in ipairs(vehicle:GetDescendants()) do
            if part:IsA("BasePart") then
                part.AssemblyAngularVelocity = Vector3.zero
            end
        end
        vehicleRoot.AssemblyAngularVelocity = Vector3.zero

        local camCF    = camera.CFrame
        local look     = camCF.LookVector
        local right    = camCF.RightVector
        local flatLook = Vector3.new(look.X, 0, look.Z)

        if flatLook.Magnitude > 0.01 then
            local targetYaw = math.atan2(-flatLook.Unit.X, -flatLook.Unit.Z)
            local diff      = targetYaw - yaw
            if diff >  math.pi then diff = diff - 2 * math.pi end
            if diff < -math.pi then diff = diff + 2 * math.pi end
            yaw = yaw + diff * math.min(dt * CFG.YawSpeed, 1)
        end

        local flatForward = Vector3.new(look.X, 0, look.Z)
        local flatRight   = Vector3.new(right.X, 0, right.Z)
        local dir, moving = Vector3.zero, false

        if UIS:IsKeyDown(Enum.KeyCode.W) then
            dir = dir + (flatForward.Magnitude > 0 and flatForward.Unit or Vector3.zero)
            moving = true
        end
        if UIS:IsKeyDown(Enum.KeyCode.S) then
            dir = dir - (flatForward.Magnitude > 0 and flatForward.Unit or Vector3.zero)
            moving = true
        end
        if UIS:IsKeyDown(Enum.KeyCode.A) then
            dir = dir - (flatRight.Magnitude > 0 and flatRight.Unit or Vector3.zero)
            moving = true
        end
        if UIS:IsKeyDown(Enum.KeyCode.D) then
            dir = dir + (flatRight.Magnitude > 0 and flatRight.Unit or Vector3.zero)
            moving = true
        end

        local vertical = 0
        if UIS:IsKeyDown(CFG.UpKey)   then vertical =  CFG.LiftSpeed end
        if UIS:IsKeyDown(CFG.DownKey) then vertical = -CFG.LiftSpeed end

        local speed = CFG.Speed
        if UIS:IsKeyDown(CFG.BoostKey) then speed = speed * CFG.BoostMult end

        local hVel = (moving and dir.Magnitude > 0)
            and dir.Unit * speed
            or Vector3.zero

        bv.Velocity = Vector3.new(hVel.X, vertical, hVel.Z)

        local flatCF = CFrame.new(vehicleRoot.Position) * CFrame.Angles(0, yaw, 0)
        bg.CFrame          = flatCF
        vehicleRoot.CFrame = flatCF
    end)
end

function FlyCar:SetEnabled(value)
    if value then
        local root, v = getVehicle()
        if not root then
            warn("get in the car dude")
            return
        end
        yaw    = math.atan2(-root.CFrame.LookVector.X, -root.CFrame.LookVector.Z)
        flying = true
        attachFly(root, v)
        startLoop()
    else
        flying = false
        detachFly()
        if heartbeat then
            heartbeat:Disconnect()
            heartbeat = nil
        end
    end
end

function FlyCar:SetSpeed(v)  CFG.Speed     = v end
function FlyCar:SetLift(v)   CFG.LiftSpeed = v end
function FlyCar:SetBoost(v)  CFG.BoostMult = v end

return FlyCar
