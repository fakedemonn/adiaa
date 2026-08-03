local plr     = game:GetService("Players").LocalPlayer
local enabled = false
local charConn = nil

local function isMagTable(t)
    if type(t) ~= "table" then return false end
    return type(rawget(t, "Mag"))    == "number"
       and type(rawget(t, "Ammo"))   == "number"
       and type(rawget(t, "ShotID")) == "number"
end

local function lockMagOnly(t)
    rawset(t, "Mag", nil)
    setmetatable(t, {
        -- enabled checked at call-time — toggle off = instant pass-through
        __index = function(self, k)
            if enabled and k == "Mag" then return 9999 end
            return rawget(self, k)
        end,
        __newindex = function(self, k, v)
            if enabled and k == "Mag" then return end
            rawset(self, k, v)
        end,
    })
end

local function scanGC()
    for _, v in ipairs(getgc(true)) do
        if isMagTable(v) then lockMagOnly(v) end
    end
end

local function applyToGun(gun)
    scanGC()
    for _, v in ipairs(gun:GetDescendants()) do
        if (v:IsA("IntValue") or v:IsA("NumberValue")) and v.Name == "Mag" then
            v.Value = 9999
        end
    end
end

local function hookChar(char)
    -- always disconnect the old char connection first
    if charConn then charConn:Disconnect() charConn = nil end

    charConn = char.ChildAdded:Connect(function(v)
        if not enabled then return end
        if v:IsA("Tool") then
            task.wait(0.5)
            applyToGun(v)
        end
    end)

    -- patch tools that are already in the character at respawn
    if enabled then
        for _, v in ipairs(char:GetChildren()) do
            if v:IsA("Tool") then applyToGun(v) end
        end
    end
end

-- fires on every respawn — the real fix
plr.CharacterAdded:Connect(hookChar)

-- cover the case where the script loads mid-life
local initChar = plr.Character
if initChar then hookChar(initChar) end

-- ─── module returned to the UI ────────────────────────────────────────────────
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
