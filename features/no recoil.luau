local plr = game:GetService("Players").LocalPlayer

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

local function noRecoilOnGun(gun)
    for _, t in ipairs(getgc(true)) do
        if type(t) ~= "table" then continue end
        local recoil    = rawget(t, "Recoil")
        local recoilX   = rawget(t, "RecoilX")
        local recoilY   = rawget(t, "RecoilY")
        local kickback  = rawget(t, "Kickback")
        local spread    = rawget(t, "Spread")
        local deviation = rawget(t, "Deviation")
        if recoil ~= nil or recoilX ~= nil or recoilY ~= nil
        or kickback ~= nil or spread ~= nil or deviation ~= nil then
            if recoil    ~= nil then safeSet(t, "Recoil",    0) end
            if recoilX   ~= nil then safeSet(t, "RecoilX",   0) end
            if recoilY   ~= nil then safeSet(t, "RecoilY",   0) end
            if kickback  ~= nil then safeSet(t, "Kickback",  0) end
            if spread    ~= nil then safeSet(t, "Spread",    0) end
            if deviation ~= nil then safeSet(t, "Deviation", 0) end
            safeMeta(t, {
                __newindex = function(self, k, v)
                    if k == "Recoil" or k == "RecoilX" or k == "RecoilY"
                    or k == "Kickback" or k == "Spread" or k == "Deviation" then
                        rawset(self, k, 0)
                    else
                        rawset(self, k, v)
                    end
                end,
                __index = function(self, k)
                    if k == "Recoil" or k == "RecoilX" or k == "RecoilY"
                    or k == "Kickback" or k == "Spread" or k == "Deviation" then
                        return 0
                    end
                    return rawget(self, k)
                end
            })
        end
    end
    for _, v in ipairs(gun:GetDescendants()) do
        local n = string.lower(v.Name)
        if v:IsA("NumberValue") or v:IsA("IntValue") then
            if string.find(n, "recoil") or string.find(n, "kickback")
            or string.find(n, "spread") or string.find(n, "deviation") then
                pcall(function() v.Value = 0 end)
            end
        end
    end
end

local char = plr.Character or plr.CharacterAdded:Wait()
char.ChildAdded:Connect(function(v)
    if v:IsA("Tool") then
        task.wait(0.5)
        noRecoilOnGun(v)
    end
end)
for _, v in ipairs(char:GetChildren()) do
    if v:IsA("Tool") then noRecoilOnGun(v) end
end
