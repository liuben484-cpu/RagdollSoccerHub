--// Universal Hub (Fluent-Custom)
local Fluent = loadstring(game:HttpGet("https://raw.githubusercontent.com/Hund335/Fluent-Custom/main/Fluent.lua"))()
local SaveManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/SaveManager.lua"))()
local InterfaceManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/InterfaceManager.lua"))()

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Lighting = game:GetService("Lighting")

local LocalPlayer = Players.LocalPlayer
local Options = Fluent.Options
local connections = {}

local function track(conn)
    table.insert(connections, conn)
    return conn
end

local function getChar() return LocalPlayer.Character end
local function getHumanoid()
    local char = getChar()
    return char and char:FindFirstChildOfClass("Humanoid")
end
local function getRoot()
    local char = getChar()
    return char and char:FindFirstChild("HumanoidRootPart")
end

--// Window
local Window = Fluent:CreateWindow({
    Title = "Universal Hub",
    SubTitle = "Fluent-Custom",
    TabWidth = 160,
    Size = UDim2.fromOffset(580, 460),
    Acrylic = true,
    Theme = "Dark",
    MinimizeKey = Enum.KeyCode.LeftControl,
})

local Tabs = {
    Player =Window:AddTab({ Title = "Player", Icon = "user" }),
    Visuals = Window:AddTab({ Title = "Visuals", Icon = "eye" }),
    Settings = Window:AddTab({ Title = "Settings", Icon = "settings" }),
}

----------------------------------------------------------------------
-- PLAYER: Movement
----------------------------------------------------------------------
local Movement = Tabs.Player:AddSection("Movement")

Movement:AddToggle("MoveOverride", {
    Title = "Override Movement",
    Description = "Applies Walk Speed and Jump Power below",
    Default = false,
})
Movement:AddSlider("WalkSpeed", {
    Title = "Walk Speed", Min = 16, Max = 200, Default = 16, Increment = 1, Suffix = " studs/s",
})
Movement:AddSlider("JumpPower", {
    Title = "Jump Power", Min = 50, Max = 300, Default = 50, Increment = 5,
})

local function applyMovement()
    local hum = getHumanoid()
    if not hum then return end
    if Options.MoveOverride.Value then
        hum.WalkSpeed = Options.WalkSpeed.Value
        hum.UseJumpPower = true
        hum.JumpPower = Options.JumpPower.Value
    end
end

Options.MoveOverride:OnChanged(function(on)
    local hum = getHumanoid()
    if not on and hum then
        hum.WalkSpeed = 16
        hum.JumpPower = 50
    end
    applyMovement()
end)
Options.WalkSpeed:OnChanged(applyMovement)
Options.JumpPower:OnChanged(applyMovement)

track(LocalPlayer.CharacterAdded:Connect(function(char)
    char:WaitForChild("Humanoid")
    applyMovement()
end))

-- Some games reset WalkSpeed; re-apply periodically
task.spawn(function()
    while not Fluent.Unloaded do
        if Options.MoveOverride.Value then applyMovement() end
        task.wait(0.5)
    end
end)

Movement:AddToggle("InfJump", { Title = "Infinite Jump", Default = false })
track(UserInputService.JumpRequest:Connect(function()
    if Options.InfJump.Value then
        local hum = getHumanoid()
        if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
    end
end))

----------------------------------------------------------------------
-- PLAYER: Noclip
----------------------------------------------------------------------
local Extras = Tabs.Player:AddSection("Extras")

local noclipParts = {}
Extras:AddToggle("Noclip", { Title = "Noclip", Default = false })

track(RunService.Stepped:Connect(function()
    if not Options.Noclip.Value then return end
    local char = getChar()
    if not char then return end
    for _, part in ipairs(char:GetDescendants()) do
        if part:IsA("BasePart") and part.CanCollide then
            part.CanCollide = false
            noclipParts[part] = true
        end
    end
end))

local function restoreNoclip()
    for part in pairs(noclipParts) do
        if part.Parent then part.CanCollide = true end
    end
    table.clear(noclipParts)
end
Options.Noclip:OnChanged(function(on)
    if not on then restoreNoclip() end
end)

----------------------------------------------------------------------
-- PLAYER: Fly
----------------------------------------------------------------------
Extras:AddToggle("Fly", { Title = "Fly", Description = "WASD + Space/Shift", Default = false })
Extras:AddSlider("FlySpeed", {
    Title = "Fly Speed", Min = 10, Max = 300, Default = 60, Increment = 5, Suffix = " studs/s",
})
Extras:AddKeybind("FlyKey", {
    Title = "Fly Key",
    Mode = "Toggle",
    Default = "F",
    Callback = function()
        if UserInputService:GetFocusedTextBox() then return end
        Options.Fly:SetValue(not Options.Fly.Value)
    end,
})

local function stopFly()
    local hum = getHumanoid()
    if hum then hum.PlatformStand = false end
    local root = getRoot()
    if root then root.AssemblyLinearVelocity = Vector3.zero end
end
Options.Fly:OnChanged(function(on)
    if not on then stopFly() end
end)

track(RunService.Heartbeat:Connect(function()
    if not Options.Fly.Value then return end
    local root, hum = getRoot(), getHumanoid()
    if not (root and hum) then return end

    hum.PlatformStand = true
    local cam = workspace.CurrentCamera.CFrame
    local dir = Vector3.zero
    if not UserInputService:GetFocusedTextBox() then
        if UserInputService:IsKeyDown(Enum.KeyCode.W) then dir += cam.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then dir -= cam.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then dir += cam.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then dir -= cam.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) then dir += Vector3.yAxis end
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then dir -= Vector3.yAxis end
    end
    if dir.Magnitude > 0 then dir = dir.Unit end
    root.AssemblyLinearVelocity = dir * Options.FlySpeed.Value
end))

----------------------------------------------------------------------
-- VISUALS: ESP
----------------------------------------------------------------------
local Esp = Tabs.Visuals:AddSection("ESP")
local ESP_NAME = "UniversalHubESP"

Esp:AddToggle("ESP", { Title = "Player ESP", Description = "Highlights other players", Default = false })
Esp:AddColorpicker("EspColor", { Title = "ESP Color", Default = Color3.fromRGB(96, 205, 255) })
Esp:AddToggle("EspTeamCheck", { Title = "Team Check", Description = "Skip teammates", Default = false })

local function clearESP()
    for _, plr in ipairs(Players:GetPlayers()) do
        local h = plr.Character and plr.Character:FindFirstChild(ESP_NAME)
        if h then h:Destroy() end
    end
end

local function updateESP()
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and plr.Character then
            local char = plr.Character
            local h = char:FindFirstChild(ESP_NAME)
            local skip = Options.EspTeamCheck.Value and plr.Team ~= nil and plr.Team == LocalPlayer.Team
            if Options.ESP.Value and not skip then
                if not h then
                    h = Instance.new("Highlight")
                    h.Name = ESP_NAME
                    h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
                    h.Adornee = char
                    h.Parent = char
                end
                h.FillColor = Options.EspColor.Value
                h.OutlineColor = Color3.new(1, 1, 1)
                h.FillTransparency = 0.6
            elseif h then
                h:Destroy()
            end
        end
    end
end

Options.ESP:OnChanged(function(on)
    if on then updateESP() else clearESP() end
end)
Options.EspColor:OnChanged(updateESP)
Options.EspTeamCheck:OnChanged(updateESP)

task.spawn(function()
    while not Fluent.Unloaded do
        if Options.ESP.Value then updateESP() end
        task.wait(0.5)
    end
end)

----------------------------------------------------------------------
-- VISUALS: FullBright
----------------------------------------------------------------------
local World = Tabs.Visuals:AddSection("World")
local savedLighting

World:AddToggle("FullBright", { Title = "FullBright", Default = false })
Options.FullBright:OnChanged(function(on)
    if on then
        savedLighting = savedLighting or {
            Brightness = Lighting.Brightness,
            ClockTime = Lighting.ClockTime,
            FogEnd = Lighting.FogEnd,
            GlobalShadows = Lighting.GlobalShadows,
            Ambient = Lighting.Ambient,
        }
        Lighting.Brightness = 2
        Lighting.ClockTime = 14
        Lighting.FogEnd = 1e5
        Lighting.GlobalShadows = false
        Lighting.Ambient = Color3.new(1, 1, 1)
    elseif savedLighting then
        for prop, value in pairs(savedLighting) do Lighting[prop] = value end
        savedLighting = nil
    end
end)

----------------------------------------------------------------------
-- Player tab: Unload button
----------------------------------------------------------------------
Tabs.Player:AddButton({
    Title = "Unload Script",
    Description = "Turns everything off and closes the UI",
    Callback = function()
        Window:Dialog({
            Title = "Unload",
            Content = "Close Universal Hub?",
            Buttons = {
                { Title = "Yes", Callback = function() Fluent:Destroy() end },
                { Title = "No" },
            },
        })
    end,
})

----------------------------------------------------------------------
-- Cleanup on unload
----------------------------------------------------------------------
task.spawn(function()
    repeat task.wait(1) until Fluent.Unloaded
    for _, c in ipairs(connections) do c:Disconnect() end
    stopFly()
    restoreNoclip()
    clearESP()
    if savedLighting then
        for prop, value in pairs(savedLighting) do Lighting[prop] = value end
    end
    local hum = getHumanoid()
    if hum and Options.MoveOverride.Value then
        hum.WalkSpeed = 16
        hum.JumpPower = 50
    end
end)

----------------------------------------------------------------------
-- Settings
----------------------------------------------------------------------
SaveManager:SetLibrary(Fluent)
InterfaceManager:SetLibrary(Fluent)
SaveManager:IgnoreThemeSettings()
SaveManager:SetIgnoreIndexes({})
InterfaceManager:SetFolder("UniversalHub")
SaveManager:SetFolder("UniversalHub/configs")
InterfaceManager:BuildInterfaceSection(Tabs.Settings)
SaveManager:BuildConfigSection(Tabs.Settings)

Window:SelectTab(1)
Fluent:Notify({ Title = "Universal Hub", Content = "Loaded. LeftCtrl = hide/show.", Duration = 5 })
SaveManager:LoadAutoloadConfig()
