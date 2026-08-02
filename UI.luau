local repo    = 'https://raw.githubusercontent.com/violin-suzutsuki/LinoriaLib/main/'
local featRepo = 'https://raw.githubusercontent.com/fakedemonn/thiswasapracticehubsoicanstartmakingscriptsandmakeitpaidthisisforfree/main/features/'

-- ─── Feature modules ──────────────────────────────────────────────────────────
local FlyCar       = loadstring(game:HttpGet('https://raw.githubusercontent.com/fakedemonn/adiaa/main/features/FlyCar.luau'))()
local ESP          = loadstring(game:HttpGet('https://raw.githubusercontent.com/fakedemonn/adiaa/main/features/ESP.luau'))()
local InfMag       = loadstring(game:HttpGet(featRepo .. 'Inf%20mag.luau'))()
local InfAmmo      = loadstring(game:HttpGet(featRepo .. 'inf%20ammo%20reserves.luau'))()
local NoRecoil     = loadstring(game:HttpGet(featRepo .. 'no%20recoil.luau'))()
local RapidShoot   = loadstring(game:HttpGet(featRepo .. 'rapid%20shoot.luau'))()
local BuyWeapons = loadstring(game:HttpGet(featRepo .. 'BuyWeapons.luau'))()

-- ─── LinoriaLib ───────────────────────────────────────────────────────────────
local Library      = loadstring(game:HttpGet(repo .. 'Library.lua'))()
local ThemeManager = loadstring(game:HttpGet(repo .. 'addons/ThemeManager.lua'))()
local SaveManager  = loadstring(game:HttpGet(repo .. 'addons/SaveManager.lua'))()

-- ─── Window ───────────────────────────────────────────────────────────────────
local Window = Library:CreateWindow({
    Title        = 'Average Day in America',
    Center       = true,
    AutoShow     = true,
    TabPadding   = 8,
    MenuFadeTime = 0.2
})

local Tabs = {
    Main            = Window:AddTab('Main'),
    Visual          = Window:AddTab('Visual'),
    ['UI Settings'] = Window:AddTab('UI Settings'),
}

-- ─── MISCELLANEOUS (left) ─────────────────────────────────────────────────────
local MiscGroup = Tabs.Main:AddLeftGroupbox('Miscellaneous')

-- Aimbot
MiscGroup:AddToggle('Aimbot', {
    Text    = 'Aimbot',
    Default = false,
    Tooltip = 'Enables aimbot',
    Callback = function(Value)
        print('[Aimbot]', Value)
    end
}):AddKeyPicker('AimbotKeybind', {
    Default  = 'None',
    NoUI     = false,
    Mode     = 'Toggle',
    Text     = 'Aimbot',
    Callback = function(Value)
        Toggles.Aimbot:SetValue(Value)
    end
})

MiscGroup:AddDropdown('AimbotBodyPart', {
    Values   = { 'Head', 'Torso' },
    Default  = 1,
    Multi    = false,
    Text     = 'Body Part',
    Tooltip  = 'Select which body part to aim at',
    Callback = function(Value)
        print('[AimbotBodyPart]', Value)
    end
})

MiscGroup:AddDivider()

-- Inf Mag
MiscGroup:AddToggle('InfMag', {
    Text    = 'Inf Mag',
    Default = false,
    Tooltip = 'Infinite magazine — clip never empties',
    Callback = function(Value)
        InfMag:SetEnabled(Value)
    end
})

-- Inf Ammo Reserves
MiscGroup:AddToggle('InfAmmo', {
    Text    = 'Inf Ammo Reserves',
    Default = false,
    Tooltip = 'Infinite reserve ammo — never need to scavenge',
    Callback = function(Value)
        InfAmmo:SetEnabled(Value)
    end
})

-- No Recoil
MiscGroup:AddToggle('NoRecoil', {
    Text    = 'No Recoil',
    Default = false,
    Tooltip = 'Removes weapon recoil entirely',
    Callback = function(Value)
        NoRecoil:SetEnabled(Value)
    end
})

-- Rapid Shoot
MiscGroup:AddToggle('RapidShoot', {
    Text    = 'Rapid Shoot',
    Default = false,
    Tooltip = 'Removes firerate cap on all weapons',
    Callback = function(Value)
        RapidShoot:SetEnabled(Value)
    end
})

-- ─── FUN (right) ──────────────────────────────────────────────────────────────
local FunGroup = Tabs.Main:AddRightGroupbox('Fun')

-- Fly Car — keybind chained directly onto the toggle, no separate label row
FunGroup:AddToggle('FlyCar', {
    Text    = 'Fly Car',
    Default = false,
    Tooltip = 'Makes your current vehicle fly',
    Callback = function(Value)
        FlyCar:SetEnabled(Value)
    end
}):AddKeyPicker('FlyCarKeybind', {
    Default  = 'F',
    NoUI     = false,
    Mode     = 'Toggle',
    Text     = 'Fly Car',
    Callback = function(Value)
        Toggles.FlyCar:SetValue(Value)
        FlyCar:SetEnabled(Value)
    end
})

FunGroup:AddLabel('WASD move | E up | Q down | RShift boost', true)

FunGroup:AddButton({
    Text = 'Teleport to Car',
    Func = function()
        local char = game:GetService('Players').LocalPlayer.Character
        local hrp  = char and char:FindFirstChild('HumanoidRootPart')
        if not hrp then return end

        local nearest, dist = nil, math.huge
        for _, v in ipairs(workspace:GetDescendants()) do
            if v:IsA('VehicleSeat') then
                local d = (v.Position - hrp.Position).Magnitude
                if d < dist then dist = d; nearest = v end
            end
        end

        if nearest then hrp.CFrame = nearest.CFrame + Vector3.new(0, 4, 0) end
    end,
    DoubleClick = false,
    Tooltip     = 'Teleports you to the nearest car'
})

FunGroup:AddButton({
    Text = 'Respawn',
    Func = function()
        game:GetService('Players').LocalPlayer.Character
            :FindFirstChildOfClass('Humanoid').Health = 0
    end,
    DoubleClick = false,
    Tooltip     = 'Respawns your character'
})

-- ─── VISUAL TAB ───────────────────────────────────────────────────────────────
local VisualGroup = Tabs.Visual:AddLeftGroupbox('Visualization')

VisualGroup:AddToggle('Esp', {
    Text    = 'ESP',
    Default = false,
    Tooltip = 'Renders ESP overlays on players',
    Callback = function(Value)
        ESP:SetEnabled(Value)
    end
})

VisualGroup:AddToggle('Box', {
    Text    = 'Box',
    Default = false,
    Tooltip = 'Draws a box around players',
    Callback = function(Value)
        if Toggles.Esp.Value then ESP:SetBox(Value) end
    end
})

VisualGroup:AddToggle('Names', {
    Text    = 'Names',
    Default = false,
    Tooltip = 'Displays player names above their character',
    Callback = function(Value)
        if Toggles.Esp.Value then ESP:SetNames(Value) end
    end
})

VisualGroup:AddToggle('DistanceEnabled', {
    Text    = 'Distance',
    Default = false,
    Tooltip = 'Enable distance-based ESP filtering',
    Callback = function(Value)
        if Toggles.Esp.Value then ESP:SetDistanceEnabled(Value) end
    end
})

local DistanceDepbox = VisualGroup:AddDependencyBox()
DistanceDepbox:AddSlider('EspDistance', {
    Text     = 'Distance',
    Default  = 0,
    Min      = 0,
    Max      = 5000,
    Rounding = 0,
    Compact  = false,
    Tooltip  = 'Max distance to render ESP',
    Callback = function(Value)
        if Toggles.Esp.Value then ESP:SetDistance(Value) end
    end
})
DistanceDepbox:SetupDependencies({ { Toggles.DistanceEnabled, true } })

VisualGroup:AddToggle('GlowCharacter', {
    Text    = 'Glow Character',
    Default = false,
    Tooltip = 'Applies a glow effect to player characters',
    Callback = function(Value)
        if Toggles.Esp.Value then ESP:SetGlow(Value) end
    end
})

VisualGroup:AddToggle('FullBrightness', {
    Text    = 'Full Brightness',
    Default = false,
    Tooltip = 'Removes darkness and lighting effects',
    Callback = function(Value)
        local Lighting = game:GetService('Lighting')
        if Value then
            Lighting.Brightness = 2
            Lighting.ClockTime  = 14
        else
            Lighting.Brightness = 1
        end
    end
})

-- ─── UI SETTINGS TAB ──────────────────────────────────────────────────────────
local MenuGroup = Tabs['UI Settings']:AddLeftGroupbox('Menu')

MenuGroup:AddButton('Unload', function() Library:Unload() end)
MenuGroup:AddLabel('Menu bind'):AddKeyPicker('MenuKeybind', {
    Default = 'End',
    NoUI    = true,
    Text    = 'Menu keybind'
})

Library.ToggleKeybind = Options.MenuKeybind
Library:SetWatermarkVisibility(true)

-- ─── FPS / Ping watermark ─────────────────────────────────────────────────────
local FrameTimer   = tick()
local FrameCounter = 0
local FPS          = 60

local WatermarkConnection = game:GetService('RunService').RenderStepped:Connect(function()
    FrameCounter += 1
    if (tick() - FrameTimer) >= 1 then
        FPS          = FrameCounter
        FrameTimer   = tick()
        FrameCounter = 0
    end
    Library:SetWatermark(('Average Day in America | %s fps | %s ms'):format(
        math.floor(FPS),
        math.floor(game:GetService('Stats').Network.ServerStatsItem['Data Ping']:GetValue())
    ))
end)

-- ─── Unload cleanup ───────────────────────────────────────────────────────────
Library:OnUnload(function()
    WatermarkConnection:Disconnect()
    FlyCar:SetEnabled(false)
    ESP:SetEnabled(false)
    InfMag:SetEnabled(false)
    InfAmmo:SetEnabled(false)
    NoRecoil:SetEnabled(false)
    RapidShoot:SetEnabled(false)
    Library.Unloaded = true
end)

-- ─── Theme / Save ─────────────────────────────────────────────────────────────
ThemeManager:SetLibrary(Library)
SaveManager:SetLibrary(Library)

SaveManager:IgnoreThemeSettings()
SaveManager:SetIgnoreIndexes({ 'MenuKeybind' })

ThemeManager:SetFolder('ADIA')
SaveManager:SetFolder('ADIA/config')

SaveManager:BuildConfigSection(Tabs['UI Settings'])
ThemeManager:ApplyToTab(Tabs['UI Settings'])

SaveManager:LoadAutoloadConfig()
