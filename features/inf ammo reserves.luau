local plr      = game:GetService("Players").LocalPlayer
local enabled  = false
local charConn = nil

local function isMagTable(t)
    if type(t) ~= "table" then return false end
    return type(rawget(t, "Mag"))    == "number"
       and type(rawget(t, "Ammo"))   == "number"
       and type(rawget(t, "ShotID")) == "number"
end

local function lockMagTable(t)
    rawset(t, "Mag",  9999)
    rawset(t, "Ammo", 9999)
    setmetatable(t, {
        __index = function(self, k)
            if enabled and (k == "Mag" or k == "Ammo") then return 9999 end
            return rawget(self, k)
        end,
        __newindex = function(self, k, v)
            if enabled and (k == "Mag" or k == "Ammo") then
                rawset(self, k, 9999)
            else
                rawset(self, k, v)
            end
        end,
    })
end

local function scanGC()
    for _, v in ipairs(getgc(true)) do
        if isMagTable(v) then lockMagTable(v) end
    end
end

local function applyToGun(gun)
    scanGC()
    for _, v in ipairs(gun:GetDescendants()) do
        if (v:IsA("IntValue") or v:IsA("NumberValue"))
        and (v.Name == "Mag" or v.Name == "Ammo") then
            v.Value = 9999
        end
    end
end

local function hookChar(char)
    if charConn then charConn:Disconnect() charConn = nil end

    charConn = char.ChildAdded:Connect(function(v)
        if not enabled then return end
        if v:IsA("Tool") then
            task.wait(0.5)
            applyToGun(v)
        end
    end)

    if enabled then
        for _, v in ipairs(char:GetChildren()) do
            if v:IsA("Tool") then applyToGun(v) end
        end
    end
end

plr.CharacterAdded:Connect(hookChar)

local initChar = plr.Character
if initChar then hookChar(initChar) end

return {
    SetEnabled = function(_, value)
        enabled = value
        if value then
            local c = plr.Character
            if c then
                scanGC()
                for _, v in ipairs(c:GetChildren()) do
                    if v:IsA("Tool") then applyToGun(v) end
                end
            end
        end
    end,
}
