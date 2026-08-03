local plr      = game:GetService("Players").LocalPlayer
local enabled  = false
local charConn = nil

local function isStateTable(t)
    if type(t) ~= "table" then return false end
    return type(rawget(t, "ElapsedCooldownTime")) == "number"
       and type(rawget(t, "ShotID"))              == "number"
       and type(rawget(t, "Mag"))                 == "number"
end

local function isRateTable(t)
    if type(t) ~= "table" then return false end
    return rawget(t, "FireRate")  ~= nil
        or rawget(t, "FireDelay") ~= nil
        or rawget(t, "Firerate")  ~= nil
end

local function safeSet(t, k, v)
    local ok = pcall(rawset, t, k, v)
    if not ok then
        pcall(setreadonly, t, false)
        pcall(rawset, t, k, v)
    end
end

local function safeMeta(t, meta)
    local ok = pcall(setmetatable, t, meta)
    if not ok then
        pcall(setreadonly, t, false)
        pcall(setmetatable, t, meta)
    end
end

local function lockStateTable(t)
    safeSet(t, "ElapsedCooldownTime", 0)
    safeMeta(t, {
        __index = function(self, k)
            if enabled then
                if k == "ElapsedCooldownTime" then return 0 end
                if k == "Mag" or k == "Ammo"  then return 9999 end
            end
            return rawget(self, k)
        end,
        __newindex = function(self, k, v)
            if enabled then
                if k == "ElapsedCooldownTime" then rawset(self, k, 0) return end
                if k == "Mag" or k == "Ammo"  then rawset(self, k, 9999) return end
            end
            rawset(self, k, v)
        end,
    })
end

local function lockRateTable(t)
    if rawget(t, "FireRate")  ~= nil then safeSet(t, "FireRate",  0.01) end
    if rawget(t, "FireDelay") ~= nil then safeSet(t, "FireDelay", 0.01) end
    if rawget(t, "Firerate")  ~= nil then safeSet(t, "Firerate",  0.01) end
    safeMeta(t, {
        __index = function(self, k)
            if enabled and (k == "FireRate" or k == "FireDelay" or k == "Firerate") then
                return 0.01
            end
            return rawget(self, k)
        end,
        __newindex = function(self, k, v)
            if enabled and (k == "FireRate" or k == "FireDelay" or k == "Firerate") then
                rawset(self, k, 0.01)
            else
                rawset(self, k, v)
            end
        end,
    })
end

local function scanGC()
    for _, t in ipairs(getgc(true)) do
        if type(t) ~= "table" then continue end
        if isStateTable(t) then lockStateTable(t) end
        if isRateTable(t)  then lockRateTable(t)  end
    end
end

local function applyToGun(gun)
    scanGC()
    -- belt-and-suspenders: also zero out any Instance values
    for _, v in ipairs(gun:GetDescendants()) do
        if v:IsA("NumberValue") or v:IsA("IntValue") then
            local n = v.Name
            if n == "FireRate" or n == "FireDelay" or n == "Firerate" then
                pcall(function() v.Value = 0.01 end)
            end
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
