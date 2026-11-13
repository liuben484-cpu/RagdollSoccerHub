-- Ragdoll Soccer diagnose: copies a report to your clipboard (and prints it to F9)
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local lp = Players.LocalPlayer
local out = {}
local function add(s) table.insert(out, tostring(s)) end

add("PlaceId: " .. game.PlaceId)
add("Executor: " .. (identifyexecutor and identifyexecutor() or "?"))
add("firetouchinterest: " .. tostring(typeof(firetouchinterest) == "function"))

local char = lp.Character
add("Character: " .. (char and char:GetFullName() or "nil"))
if char then
    local hum = char:FindFirstChildOfClass("Humanoid")
    add("Humanoid: " .. (hum and ("WalkSpeed=" .. hum.WalkSpeed .. " JumpPower=" .. hum.JumpPower .. " UseJumpPower=" .. tostring(hum.UseJumpPower) .. " State=" .. tostring(hum:GetState())) or "nil"))
    add("HumanoidRootPart: " .. tostring(char:FindFirstChild("HumanoidRootPart") ~= nil))
    local kids = {}
    for _, c in ipairs(char:GetChildren()) do table.insert(kids, c.Name .. "(" .. c.ClassName .. ")") end
    add("Char children: " .. table.concat(kids, ", "))
end

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

local report = table.concat(out, "\n")
print(report)
if setclipboard then setclipboard(report) print("[diag] copied to clipboard") end
