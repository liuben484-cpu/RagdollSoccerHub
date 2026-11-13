--// Universal Hub (Fluent-Custom)
print("[RSHub] starting...")

local function safeLoad(name, url)
    local ok, result = pcall(function()
        return loadstring(game:HttpGet(url))()
    end)
    if not ok or not result then
        warn("[RSHub] could not load " .. name .. ": " .. tostring(result))
        return nil
    end
    print("[RSHub] loaded " .. name)
    return result
end

local Fluent = safeLoad("Fluent", "https://raw.githubusercontent.com/Hund335/Fluent-Custom/main/Fluent.lua")
local SaveManager = safeLoad("SaveManager", "https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/SaveManager.lua")
local InterfaceManager = safeLoad("InterfaceManager", "https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/InterfaceManager.lua")
if not (Fluent and SaveManager and InterfaceManager) then
    warn("[RSHub] stopped: a library failed to load (see messages above)")
    return
end

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
    Title = "Ragdoll Soccer Hub",
    SubTitle = "Fluent-Custom",
    TabWidth = 160,
    Size = UDim2.fromOffset(580, 460),
    Acrylic = true,
    Theme = "Dark",
    MinimizeKey = Enum.KeyCode.LeftControl,
})

local Tabs = {
    Soccer = Window:AddTab({ Title = "Soccer", Icon = "trophy" }),
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
-- SOCCER: Ball finder
----------------------------------------------------------------------
local BallSec = Tabs.Soccer:AddSection("Ball")

Tabs.Soccer:AddParagraph({
    Title = "Ball detection",
    Content = "Finds the nearest part with \"ball\" in its name.\nIf the wrong part is found, type the exact ball name below.",
})

local cachedBall, lastSearch = nil, 0

BallSec:AddInput("BallName", {
    Title = "Ball name (optional)",
    Default = "",
    Placeholder = "auto",
    Finished = true,
    Callback = function()
        cachedBall, lastSearch = nil, 0
    end,
})

local function isBall(part, wanted)
    if not part:IsA("BasePart") then return false end
    local name = part.Name:lower()
    if wanted ~= "" then return name == wanted end
    return name:find("ball") ~= nil
end

local function getBall()
    if cachedBall and cachedBall:IsDescendantOf(workspace) then return cachedBall end
    if os.clock() - lastSearch < 1 then return nil end -- don't scan workspace every frame
    lastSearch = os.clock()

    local wanted = (Options.BallName.Value or ""):lower()
    local root = getRoot()
    local best, bestDist = nil, math.huge
    for _, d in ipairs(workspace:GetDescendants()) do
        if isBall(d, wanted) then
            local model = d:FindFirstAncestorOfClass("Model")
            if not (model and Players:GetPlayerFromCharacter(model)) then
                local dist = root and (d.Position - root.Position).Magnitude or 0
                if dist < bestDist then best, bestDist = d, dist end
            end
        end
    end
    cachedBall = best
    return best
end

BallSec:AddButton({
    Title = "Re-scan Ball",
    Callback = function()
        cachedBall, lastSearch = nil, 0
        local ball = getBall()
        Fluent:Notify({
            Title = "Ball",
            Content = ball and ("Found: " .. ball:GetFullName()) or "No ball found.",
            Duration = 4,
        })
    end,
})

BallSec:AddButton({
    Title = "Teleport to Ball",
    Callback = function()
        local ball, root = getBall(), getRoot()
        if ball and root then
            root.CFrame = CFrame.new(ball.Position + Vector3.new(0, 3, 0))
        end
    end,
})

----------------------------------------------------------------------
-- SOCCER: Auto follow + reach
----------------------------------------------------------------------
local Assist = Tabs.Soccer:AddSection("Assist")

Assist:AddToggle("FollowBall", { Title = "Auto Follow Ball", Description = "Walks to the ball", Default = false })
Options.FollowBall:OnChanged(function(on)
    if not on then return end
    task.spawn(function()
        while Options.FollowBall.Value and not Fluent.Unloaded do
            local ball, hum = getBall(), getHumanoid()
            if ball and hum then hum:MoveTo(ball.Position) end
            task.wait(0.1)
        end
    end)
end)

local hasTouch = typeof(firetouchinterest) == "function"
Assist:AddToggle("BallReach", {
    Title = "Ball Reach",
    Description = hasTouch and "Touches the ball from a distance" or "Your executor has no firetouchinterest",
    Default = false,
})
Assist:AddSlider("ReachRange", {
    Title = "Reach Range", Min = 2, Max = 30, Default = 10, Increment = 1, Suffix = " studs",
})

Options.BallReach:OnChanged(function(on)
    if not on or not hasTouch then return end
    task.spawn(function()
        while Options.BallReach.Value and not Fluent.Unloaded do
            local ball, char, root = getBall(), getChar(), getRoot()
            if ball and char and root and (ball.Position - root.Position).Magnitude <= Options.ReachRange.Value then
                for _, part in ipairs(char:GetChildren()) do
                    if part:IsA("BasePart") then
                        firetouchinterest(part, ball, 0)
                        firetouchinterest(part, ball, 1)
                    end
                end
            end
            task.wait(0.05)
        end
    end)
end)

----------------------------------------------------------------------
-- SOCCER: Anti ragdoll
----------------------------------------------------------------------
Assist:AddToggle("AntiRagdoll", {
    Title = "Anti Ragdoll",
    Description = "Blocks Humanoid ragdoll/fall states (custom ragdolls may still work)",
    Default = false,
})

local function setRagdollStates(enabled)
    local hum = getHumanoid()
    if not hum then return end
    hum:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, enabled)
    hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, enabled)
end

Options.AntiRagdoll:OnChanged(function(on)
    setRagdollStates(not on)
end)

track(RunService.Heartbeat:Connect(function()
    if not Options.AntiRagdoll.Value then return end
    local hum = getHumanoid()
    if not hum then return end
    local state = hum:GetState()
    if state == Enum.HumanoidStateType.Ragdoll or state == Enum.HumanoidStateType.FallingDown then
        hum:ChangeState(Enum.HumanoidStateType.GettingUp)
    end
end))

track(LocalPlayer.CharacterAdded:Connect(function(char)
    char:WaitForChild("Humanoid")
    if Options.AntiRagdoll.Value then setRagdollStates(false) end
end))

----------------------------------------------------------------------
-- SOCCER: Ball ESP
----------------------------------------------------------------------
local BallVis = Tabs.Soccer:AddSection("Ball ESP")
local BALL_ESP = "RSHubBallESP"

BallVis:AddToggle("BallESP", { Title = "Ball ESP", Description = "Highlight + distance", Default = false })
BallVis:AddColorpicker("BallEspColor", { Title = "Ball ESP Color", Default = Color3.fromRGB(255, 200, 40) })

local ballHighlight, ballBillboard, ballLabel

local function clearBallESP()
    if ballHighlight then ballHighlight:Destroy() end
    if ballBillboard then ballBillboard:Destroy() end
    ballHighlight, ballBillboard, ballLabel = nil, nil, nil
end

local function updateBallESP()
    local ball = getBall()
    if not (Options.BallESP.Value and ball) then
        clearBallESP()
        return
    end
    if not ballHighlight or ballHighlight.Parent ~= ball then
        clearBallESP()
        ballHighlight = Instance.new("Highlight")
        ballHighlight.Name = BALL_ESP
        ballHighlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        ballHighlight.FillTransparency = 0.3
        ballHighlight.Adornee = ball
        ballHighlight.Parent = ball

        ballBillboard = Instance.new("BillboardGui")
        ballBillboard.Name = BALL_ESP
        ballBillboard.AlwaysOnTop = true
        ballBillboard.Size = UDim2.fromOffset(120, 24)
        ballBillboard.StudsOffset = Vector3.new(0, 3, 0)
        ballBillboard.Adornee = ball
        ballBillboard.Parent = ball

        ballLabel = Instance.new("TextLabel")
        ballLabel.BackgroundTransparency = 1
        ballLabel.Size = UDim2.fromScale(1, 1)
        ballLabel.Font = Enum.Font.GothamBold
        ballLabel.TextSize = 14
        ballLabel.TextStrokeTransparency = 0.4
        ballLabel.Parent = ballBillboard
    end
    local color = Options.BallEspColor.Value
    ballHighlight.FillColor = color
    ballHighlight.OutlineColor = color
    ballLabel.TextColor3 = color
    local root = getRoot()
    ballLabel.Text = root and string.format("Ball [%d]", math.floor((ball.Position - root.Position).Magnitude)) or "Ball"
end

Options.BallESP:OnChanged(updateBallESP)
Options.BallEspColor:OnChanged(updateBallESP)

task.spawn(function()
    while not Fluent.Unloaded do
        if Options.BallESP.Value then updateBallESP() end
        task.wait(0.1)
    end
end)

----------------------------------------------------------------------
-- SOCCER: Diagnose (copies a report so the script can be adapted to the game)
----------------------------------------------------------------------
local DebugSec = Tabs.Soccer:AddSection("Debug")

local function buildReport()
    local RS = game:GetService("ReplicatedStorage")
    local out = {}
    local function add(s) table.insert(out, tostring(s)) end

    add("PlaceId: " .. game.PlaceId)
    add("Executor: " .. (identifyexecutor and tostring(identifyexecutor()) or "?"))
    add("firetouchinterest: " .. tostring(hasTouch))

    local char = getChar()
    add("Character: " .. (char and char:GetFullName() or "nil"))
    if char then
        local hum = char:FindFirstChildOfClass("Humanoid")
        add("Humanoid: " .. (hum and string.format("WalkSpeed=%s JumpPower=%s UseJumpPower=%s State=%s",
            hum.WalkSpeed, hum.JumpPower, tostring(hum.UseJumpPower), tostring(hum:GetState())) or "nil"))
        add("HumanoidRootPart: " .. tostring(getRoot() ~= nil))
        local kids = {}
        for _, c in ipairs(char:GetChildren()) do table.insert(kids, c.Name .. "(" .. c.ClassName .. ")") end
        add("Char children: " .. table.concat(kids, ", "))
    end

    local ball = getBall()
    add("Detected ball: " .. (ball and ball:GetFullName() or "nil"))
    add("-- Parts with 'ball' in name:")
    local n = 0
    for _, d in ipairs(workspace:GetDescendants()) do
        if d:IsA("BasePart") and d.Name:lower():find("ball") then
            n += 1
            if n <= 15 then add("  " .. d:GetFullName() .. " size=" .. tostring(d.Size)) end
        end
    end
    add("  total: " .. n)

    add("-- Remotes in ReplicatedStorage:")
    local r = 0
    for _, d in ipairs(RS:GetDescendants()) do
        if d:IsA("RemoteEvent") or d:IsA("RemoteFunction") then
            r += 1
            if r <= 30 then add("  " .. d:GetFullName()) end
        end
    end

    add("-- Workspace top level:")
    for _, c in ipairs(workspace:GetChildren()) do add("  " .. c.Name .. " (" .. c.ClassName .. ")") end
    return table.concat(out, "\n")
end

DebugSec:AddButton({
    Title = "Copy Diagnose Report",
    Description = "Copies game info to the clipboard (also printed in F9)",
    Callback = function()
        local ok, report = pcall(buildReport)
        if not ok then report = "Report error: " .. tostring(report) end
        print(report)
        local copied = setclipboard and pcall(setclipboard, report)
        Fluent:Notify({
            Title = "Diagnose",
            Content = copied and "Report copied. Paste it in the chat." or "Clipboard unavailable. Open F9 to copy it.",
            Duration = 6,
        })
    end,
})

----------------------------------------------------------------------
-- Player tab: Unload button
----------------------------------------------------------------------
Tabs.Player:AddButton({
    Title = "Unload Script",
    Description = "Turns everything off and closes the UI",
    Callback = function()
        Window:Dialog({
            Title = "Unload",
            Content = "Close Ragdoll Soccer Hub?",
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
    clearBallESP()
    setRagdollStates(true)
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
InterfaceManager:SetFolder("RagdollSoccerHub")
SaveManager:SetFolder("RagdollSoccerHub/configs")
InterfaceManager:BuildInterfaceSection(Tabs.Settings)
SaveManager:BuildConfigSection(Tabs.Settings)

Window:SelectTab(1)
Fluent:Notify({ Title = "Ragdoll Soccer Hub", Content = "Loaded. LeftCtrl = hide/show.", Duration = 5 })
SaveManager:LoadAutoloadConfig()
print("[RSHub] ready")
