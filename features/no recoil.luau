local plr      = game:GetService("Players").LocalPlayer
local enabled  = false
local charConn = nil

local RECOIL_KEYS = { "Recoil", "RecoilX", "RecoilY", "Kickback", "Spread", "Deviation" }

local function isRecoilTable(t)
    if type(t) ~= "table" then return false end
    for _, k in ipairs(RECOIL_KEYS) do
        if rawget(t, k) ~= nil then return true end
    end
    return false
end

local function isRecoilKey(k)
    for _, rk in ipairs(RECOIL_KEYS) do
        if k == rk then return true end
    end
    return false
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

local function lockRecoilTable(t)
    for _, k in ipairs(RECOIL_KEYS) do
        if rawget(t, k) ~= nil then safeSet(t, k, 0) end
    end
    safeMeta(t, {
        __index = function(self, k)
            if enabled and isRecoilKey(k) then return 0 end
            return rawget(self, k)
        end,
        __newindex = function(self, k, v)
            if enabled and isRecoilKey(k) then
                rawset(self, k, 0)
            else
                rawset(self, k, v)
            end
        end,
    })
end

local function scanGC()
    for _, t in ipairs(getgc(true)) do
        if isRecoilTable(t) then lockRecoilTable(t) end
    end
end

local function applyToGun(gun)
    scanGC()
    for _, v in ipairs(gun:GetDescendants()) do
        if v:IsA("NumberValue") or v:IsA("IntValue") then
            local n = v.Name:lower()
            if n:find("recoil") or n:find("kickback")
            or n:find("spread") or n:find("deviation") then
                pcall(function() v.Value = 0 end)
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

