local repo = 'https://raw.githubusercontent.com/violin-suzutsuki/LinoriaLib/main/'
local FlyCar = loadstring(game:HttpGet('https://raw.githubusercontent.com/fakedemonn/adiaa/main/features/FlyCar.luau'))()

local Library = loadstring(game:HttpGet(repo .. 'Library.lua'))()
local ThemeManager = loadstring(game:HttpGet(repo .. 'addons/ThemeManager.lua'))()
local SaveManager = loadstring(game:HttpGet(repo .. 'addons/SaveManager.lua'))()

local Window = Library:CreateWindow({
    Title = 'Average Day in America',
    Center = true,
    AutoShow = true,
    TabPadding = 8,
    MenuFadeTime = 0.2
})

local Tabs = {
    Main = Window:AddTab('Main'),
    Visual = Window:AddTab('Visual'),
    ['UI Settings'] = Window:AddTab('UI Settings'),
}

local AimbotGroup = Tabs.Main:AddLeftGroupbox('Aimbot')

AimbotGroup:AddToggle('Aimbot', {
    Text = 'Aimbot',
    Default = false,
    Tooltip = 'Enables aimbot',
    Callback = function(Value)
        print('[Aimbot]', Value)
    end
})

AimbotGroup:AddToggle('SilentAim', {
    Text = 'Silent Aim',
    Default = false,
    Tooltip = 'Silently redirects your shots toward the target',
    Callback = function(Value)
        print('[SilentAim]', Value)
    end
})

AimbotGroup:AddSlider('AimbotFov', {
    Text = 'Fov',
    Default = 0,
    Min = 0,
    Max = 500,
    Rounding = 0,
    Compact = false,
    Callback = function(Value)
        print('[AimbotFov]', Value)
    end
})

AimbotGroup:AddDropdown('AimbotBodyPart', {
    Values = { 'Head', 'Upper Body', 'Legs' },
    Default = 1,
    Multi = false,
    Text = 'Choose A Body Part',
    Tooltip = 'Select which body part to aim at',
    Callback = function(Value)
        print('[AimbotBodyPart]', Value)
    end
})

local FunGroup = Tabs.Main:AddRightGroupbox('Fun')

FunGroup:AddToggle('FlyCar', {
    Text = 'Fly Car',
    Default = false,
    Tooltip = 'Makes your current vehicle fly',
    Callback = function(Value)
        FlyCar:SetEnabled(Value)
    end
})

FunGroup:AddKeybind('FlyCarKeybind', {
    Text = 'Fly Car Keybind',
    Default = 'F',
    Callback = function()
        local newVal = not Toggles.FlyCar.Value
        Toggles.FlyCar:SetValue(newVal)
        FlyCar:SetEnabled(newVal)
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
    Tooltip = 'Teleports you to the nearest car'
})

FunGroup:AddButton({
    Text = 'Respawn',
    Func = function()
        game:GetService('Players').LocalPlayer.Character:FindFirstChildOfClass('Humanoid').Health = 0
    end,
    DoubleClick = false,
    Tooltip = 'Respawns your character'
})

local VisualGroup = Tabs.Visual:AddLeftGroupbox('Visualization')

VisualGroup:AddToggle('Esp', {
    Text = 'Esp',
    Default = false,
    Tooltip = 'Renders ESP overlays on players',
    Callback = function(Value)
        print('[Esp]', Value)
    end
})

local EspDepbox = VisualGroup:AddDependencyBox()

EspDepbox:AddToggle('Box', {
    Text = 'Box',
    Default = false,
    Tooltip = 'Draws a box around players',
    Callback = function(Value)
        print('[Box]', Value)
    end
})

EspDepbox:AddToggle('Names', {
    Text = 'Names',
    Default = false,
    Tooltip = 'Displays player names above their character',
    Callback = function(Value)
        print('[Names]', Value)
    end
})

EspDepbox:AddToggle('DistanceEnabled', {
    Text = 'Distance',
    Default = false,
    Tooltip = 'Enable distance-based ESP filtering',
    Callback = function(Value)
        print('[DistanceEnabled]', Value)
    end
})

local DistanceDepbox = EspDepbox:AddDependencyBox()

DistanceDepbox:AddSlider('EspDistance', {
    Text = 'Distance',
    Default = 0,
    Min = 0,
    Max = 5000,
    Rounding = 0,
    Compact = false,
    Tooltip = 'Max distance to render ESP',
    Callback = function(Value)
        print('[EspDistance]', Value)
    end
})

DistanceDepbox:SetupDependencies({
    { Toggles.DistanceEnabled, true }
})

EspDepbox:AddToggle('GlowCharacter', {
    Text = 'Glow Character',
    Default = false,
    Tooltip = 'Applies a glow effect to player characters',
    Callback = function(Value)
        print('[GlowCharacter]', Value)
    end
})

EspDepbox:AddToggle('FullBrightness', {
    Text = 'Full Brightness',
    Default = false,
    Tooltip = 'Removes darkness and lighting effects',
    Callback = function(Value)
        if Value then
            game:GetService('Lighting').Brightness = 2
            game:GetService('Lighting').ClockTime  = 14
        else
            game:GetService('Lighting').Brightness = 1
        end
    end
})

EspDepbox:SetupDependencies({
    { Toggles.Esp, true }
})

local MenuGroup = Tabs['UI Settings']:AddLeftGroupbox('Menu')
MenuGroup:AddButton('Unload', function() Library:Unload() end)
MenuGroup:AddLabel('Menu bind'):AddKeyPicker('MenuKeybind', { Default = 'End', NoUI = true, Text = 'Menu keybind' })

Library.ToggleKeybind = Options.MenuKeybind

Library:SetWatermarkVisibility(true)

local FrameTimer = tick()
local FrameCounter = 0
local FPS = 60

local WatermarkConnection = game:GetService('RunService').RenderStepped:Connect(function()
    FrameCounter += 1
    if (tick() - FrameTimer) >= 1 then
        FPS = FrameCounter
        FrameTimer = tick()
        FrameCounter = 0
    end
    Library:SetWatermark(('Average Day in America | %s fps | %s ms'):format(
        math.floor(FPS),
        math.floor(game:GetService('Stats').Network.ServerStatsItem['Data Ping']:GetValue())
    ))
end)

Library:OnUnload(function()
    WatermarkConnection:Disconnect()
    FlyCar:SetEnabled(false)
    Library.Unloaded = true
end)

ThemeManager:SetLibrary(Library)
SaveManager:SetLibrary(Library)

SaveManager:IgnoreThemeSettings()
SaveManager:SetIgnoreIndexes({ 'MenuKeybind' })

ThemeManager:SetFolder('ADIA')
SaveManager:SetFolder('ADIA/config')

SaveManager:BuildConfigSection(Tabs['UI Settings'])
ThemeManager:ApplyToTab(Tabs['UI Settings'])

SaveManager:LoadAutoloadConfig()
