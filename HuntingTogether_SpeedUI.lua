
-- Archer Basic Attack Monitor
-- Hunting Together RPG
-- Read-only damage measurement

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local deadline = os.clock() + 15

while not player and os.clock() < deadline do
    task.wait(0.2)
    player = Players.LocalPlayer
end

if not player then
    warn("[Archer Monitor] LocalPlayer unavailable")
    return
end

local parent = player:WaitForChild("PlayerGui", 10)
if not parent then return end

local old = parent:FindFirstChild("ArcherHitMonitor")
if old then old:Destroy() end

local gui = Instance.new("ScreenGui")
gui.Name = "ArcherHitMonitor"
gui.ResetOnSpawn = false
gui.Parent = parent

local function make(class, props, container)
    local obj = Instance.new(class)
    for key, value in pairs(props) do
        obj[key] = value
    end
    obj.Parent = container
    return obj
end

local panel = make("Frame", {
    Size = UDim2.fromOffset(320, 230),
    Position = UDim2.new(0, 20, 0.5, -115),
    BackgroundColor3 = Color3.fromRGB(25, 29, 40),
    BorderSizePixel = 0
}, gui)

make("UICorner", {
    CornerRadius = UDim.new(0, 10)
}, panel)

local function label(text, y)
    return make("TextLabel", {
        Position = UDim2.fromOffset(12, y),
        Size = UDim2.fromOffset(296, 27),
        BackgroundTransparency = 1,
        Text = text,
        TextSize = 14,
        Font = Enum.Font.Gotham,
        TextColor3 = Color3.new(1, 1, 1),
        TextXAlignment = Enum.TextXAlignment.Left
    }, panel)
end

label("ARCHER | BASIC ATTACK MONITOR", 8)

local status = label("Target: Not selected", 43)
local hitLabel = label("HP decreases: 0", 75)
local rateLabel = label("Estimated hits/s: 0", 104)
local dpsLabel = label("DPS: 0", 133)

local function button(text, x, action)
    local btn = make("TextButton", {
        Position = UDim2.fromOffset(x, 177),
        Size = UDim2.fromOffset(94, 35),
        Text = text,
        TextSize = 12,
        Font = Enum.Font.GothamBold,
        TextColor3 = Color3.new(1, 1, 1),
        BackgroundColor3 = Color3.fromRGB(48, 110, 210)
    }, panel)

    make("UICorner", {
        CornerRadius = UDim.new(0, 7)
    }, btn)

    btn.MouseButton1Click:Connect(action)
    return btn
end

local mouse = player:GetMouse()
local readHP = nil
local targetName = nil
local selecting = false
local armAt = 0
local recording = false
local started = 0
local lastHP = 0
local hits = 0
local damage = 0
local elapsed = 0
local connections = {}

local healthNames = {
    "Health", "HP", "CurrentHealth", "CurrentHP"
}

local function findHealth(part)
    local current = part

    while current and current ~= workspace do
        if current:IsA("Model") then
            local humanoid =
                current:FindFirstChildOfClass("Humanoid")

            if humanoid then
                return current.Name, function()
                    return humanoid.Health
                end
            end

            for _, name in ipairs(healthNames) do
                local value = current:FindFirstChild(name, true)

                if value and (
                    value:IsA("NumberValue")
                    or value:IsA("IntValue")
                ) then
                    return current.Name, function()
                        return value.Value
                    end
                end

                local attribute = current:GetAttribute(name)
                if type(attribute) == "number" then
                    return current.Name, function()
                        return current:GetAttribute(name)
                    end
                end
            end
        end

        current = current.Parent
    end

    return nil, nil
end

local selectBtn = button("SELECT DUMMY", 8, function()
    recording = false
    selecting = true
    armAt = os.clock() + 0.4
    status.Text = "Click the Training Dummy..."
end)

local startBtn = button("START 30S", 113, function()
    if not readHP then
        status.Text = "Select dummy first!"
        return
    end

    local hp = readHP()
    if type(hp) ~= "number" then
        status.Text = "Target HP unavailable"
        return
    end

    hits = 0
    damage = 0
    elapsed = 0
    lastHP = hp
    started = os.clock()
    recording = true
    status.Text = "Recording: " .. targetName
end)

local closeBtn = button("CLOSE", 218, function()
    gui:Destroy()
end)

table.insert(connections,
    mouse.Button1Down:Connect(function()
        if not selecting or os.clock() < armAt then
            return
        end

        local part = mouse.Target
        if not part then return end

        local name, reader = findHealth(part)

        if reader then
            readHP = reader
            targetName = name
            selecting = false
            recording = false
            status.Text = "Selected: " .. name
        else
            status.Text = "No readable HP found"
        end
    end)
)

local displayClock = 0

table.insert(connections,
    RunService.Heartbeat:Connect(function(dt)
        if not recording then return end

        elapsed = math.min(os.clock() - started, 30)

        local hp = readHP and readHP()

        if type(hp) ~= "number" then
            recording = false
            status.Text = "Lost target HP"
            return
        end

        if hp < lastHP then
            damage = damage + (lastHP - hp)
            hits = hits + 1
        end

        lastHP = hp

        displayClock = displayClock + dt

        if displayClock >= 0.15 then
            displayClock = 0

            local duration = math.max(elapsed, 0.01)

            hitLabel.Text = "HP decreases: " .. hits
            rateLabel.Text = string.format(
                "Estimated hits/s: %.2f",
                hits / duration
            )
            dpsLabel.Text = string.format(
                "DPS: %.2f",
                damage / duration
            )
        end

        if elapsed >= 30 then
            recording = false
            status.Text = "Finished: " .. targetName
            print(string.format(
                "[Archer Monitor] Hits=%d Rate=%.2f DPS=%.2f",
                hits, hits / 30, damage / 30
            ))
        end
    end)
)

gui.Destroying:Connect(function()
    recording = false
    for _, connection in ipairs(connections) do
        connection:Disconnect()
    end
end)

print("[Archer Monitor] Ready")
