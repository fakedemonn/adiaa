local plr = game:GetService("Players").LocalPlayer

local function isStateTable(t)
    if type(t) ~= "table" then return false end
    return type(rawget(t, "ElapsedCooldownTime")) == "number"
       and type(rawget(t, "ShotID")) == "number"
       and type(rawget(t, "Mag")) == "number"
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

local function nukeFireRate(gun)
    for _, t in ipairs(getgc(true)) do
        if type(t) ~= "table" then continue end
        if isStateTable(t) then
            safeSet(t, "ElapsedCooldownTime", 0)
            safeMeta(t, {
                __newindex = function(self, k, v)
                    if k == "ElapsedCooldownTime" then
                        rawset(self, k, 0)
                    elseif k == "Mag" or k == "Ammo" then
                        rawset(self, k, 9999)
                    else
                        rawset(self, k, v)
                    end
                end,
                __index = function(self, k)
                    if k == "ElapsedCooldownTime" then return 0 end
                    if k == "Mag" or k == "Ammo" then return 9999 end
                    return rawget(self, k)
                end
            })
        end
        local fireRate    = rawget(t, "FireRate")
        local fireDelay   = rawget(t, "FireDelay") or rawget(t, "Firerate")
        local shootCounts = rawget(t, "ShootCounts")
        if fireRate ~= nil or fireDelay ~= nil or shootCounts ~= nil then
            if fireRate    ~= nil then safeSet(t, "FireRate",    0.01) end
            if fireDelay   ~= nil then safeSet(t, "FireDelay",   0.01) end
            if shootCounts ~= nil then safeSet(t, "ShootCounts", 1)    end
            safeMeta(t, {
                __newindex = function(self, k, v)
                    if k == "FireRate" or k == "FireDelay" or k == "Firerate" then
                        rawset(self, k, 0.01)
                    else
                        rawset(self, k, v)
                    end
                end,
                __index = function(self, k)
                    if k == "FireRate" or k == "FireDelay" or k == "Firerate" then
                        return 0.01
                    end
                    return rawget(self, k)
                end
            })
        end
    end
end

local char = plr.Character or plr.CharacterAdded:Wait()
char.ChildAdded:Connect(function(v)
    if v:IsA("Tool") then
        task.wait(0.5)
        nukeFireRate(v)
    end
end)
for _, v in ipairs(char:GetChildren()) do
    if v:IsA("Tool") then nukeFireRate(v) end
end
