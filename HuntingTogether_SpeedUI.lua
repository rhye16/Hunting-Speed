
-- Hunting Together RPG - Speed UI
-- Fixed LocalPlayer nil / WaitForChild error
-- Client-side WalkSpeed controller

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

-- Wait for game to load
local loadDeadline = os.clock() + 20
while not game:IsLoaded() and os.clock() < loadDeadline do
    task.wait(0.2)
end

-- Wait for LocalPlayer
local player = Players.LocalPlayer
local playerDeadline = os.clock() + 15

while not player and os.clock() < playerDeadline do
    task.wait(0.2)
    player = Players.LocalPlayer
end

if not player then
    warn("[Speed UI] LocalPlayer tidak tersedia!")
    warn("[Speed UI] Pastikan executor berjalan di client.")
    return
end

-- Wait for PlayerGui
local playerGui =
    player:FindFirstChildOfClass("PlayerGui")
    or player:WaitForChild("PlayerGui", 15)

if not playerGui then
    warn("[Speed UI] PlayerGui tidak ditemukan!")
    return
end

-- Remove previous UI
local existing = playerGui:FindFirstChild(
    "HuntingTogetherSpeedUI"
)

if existing then
    existing:Destroy()
end

-- Create ScreenGui
local gui = Instance.new("ScreenGui")
gui.Name = "HuntingTogetherSpeedUI"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = playerGui

-- UI helper
local function create(className, properties, parent)
    local object = Instance.new(className)

    for property, value in pairs(properties) do
        object[property] = value
    end

    object.Parent = parent
    return object
end

-- Main Panel
local panel = create("Frame", {
    Name = "Panel",
    Size = UDim2.fromOffset(270, 168),
    Position = UDim2.new(0, 20, 0.5, -84),
    BackgroundColor3 = Color3.fromRGB(23, 26, 36),
    BorderSizePixel = 0,
    Active = true
}, gui)

create("UICorner", {
    CornerRadius = UDim.new(0, 12)
}, panel)

create("UIStroke", {
    Color = Color3.fromRGB(69, 75, 98),
    Thickness = 1
}, panel)

-- Header
local header = create("Frame", {
    Name = "DragBar",
    Size = UDim2.new(1, 0, 0, 39),
    BackgroundTransparency = 1,
    Active = true
}, panel)

create("TextLabel", {
    BackgroundTransparency = 1,
    Position = UDim2.fromOffset(13, 0),
    Size = UDim2.fromOffset(165, 39),
    Font = Enum.Font.GothamBold,
    Text = "HUNTING | SPEED",
    TextSize = 13,
    TextXAlignment = Enum.TextXAlignment.Left,
    TextColor3 = Color3.fromRGB(235, 239, 255)
}, header)

-- Minimize Button
local minimize = create("TextButton", {
    Name = "Minimize",
    Position = UDim2.new(1, -70, 0, 7),
    Size = UDim2.fromOffset(27, 25),
    Text = "-",
    Font = Enum.Font.GothamBold,
    TextSize = 19,
    TextColor3 = Color3.fromRGB(226, 230, 244),
    BackgroundColor3 = Color3.fromRGB(44, 49, 65),
    BorderSizePixel = 0
}, header)

create("UICorner", {
    CornerRadius = UDim.new(0, 6)
}, minimize)

-- Close Button
local close = create("TextButton", {
    Name = "Close",
    Position = UDim2.new(1, -38, 0, 7),
    Size = UDim2.fromOffset(27, 25),
    Text = "X",
    Font = Enum.Font.GothamBold,
    TextSize = 12,
    TextColor3 = Color3.fromRGB(255, 225, 225),
    BackgroundColor3 = Color3.fromRGB(104, 43, 52),
    BorderSizePixel = 0
}, header)

create("UICorner", {
    CornerRadius = UDim.new(0, 6)
}, close)

-- Body
local body = create("Frame", {
    Position = UDim2.fromOffset(10, 43),
    Size = UDim2.new(1, -20, 1, -52),
    BackgroundTransparency = 1
}, panel)

create("TextLabel", {
    Size = UDim2.new(1, 0, 0, 21),
    BackgroundTransparency = 1,
    Text = "WalkSpeed (8 - 150)",
    TextXAlignment = Enum.TextXAlignment.Left,
    Font = Enum.Font.Gotham,
    TextSize = 12,
    TextColor3 = Color3.fromRGB(164, 176, 200)
}, body)

-- Speed Input
local speedBox = create("TextBox", {
    Name = "SpeedInput",
    Position = UDim2.fromOffset(0, 26),
    Size = UDim2.new(0.46, 0, 0, 37),
    Text = "36",
    PlaceholderText = "Speed",
    ClearTextOnFocus = false,
    Font = Enum.Font.GothamBold,
    TextSize = 16,
    TextColor3 = Color3.fromRGB(245, 248, 255),
    BackgroundColor3 = Color3.fromRGB(38, 42, 58),
    BorderSizePixel = 0
}, body)

create("UICorner", {
    CornerRadius = UDim.new(0, 7)
}, speedBox)

-- Apply Button
local apply = create("TextButton", {
    Name = "Apply",
    Position = UDim2.new(0.5, 0, 0, 26),
    Size = UDim2.new(0.5, 0, 0, 37),
    Text = "APPLY",
    Font = Enum.Font.GothamBold,
    TextSize = 12,
    TextColor3 = Color3.fromRGB(255, 255, 255),
    BackgroundColor3 = Color3.fromRGB(55, 108, 224),
    BorderSizePixel = 0
}, body)

create("UICorner", {
    CornerRadius = UDim.new(0, 7)
}, apply)

-- Toggle Button
local toggle = create("TextButton", {
    Name = "Toggle",
    Position = UDim2.fromOffset(0, 71),
    Size = UDim2.new(1, 0, 0, 34),
    Text = "SPEED: OFF",
    Font = Enum.Font.GothamBold,
    TextSize = 13,
    TextColor3 = Color3.fromRGB(235, 240, 255),
    BackgroundColor3 = Color3.fromRGB(72, 78, 96),
    BorderSizePixel = 0
}, body)

create("UICorner", {
    CornerRadius = UDim.new(0, 7)
}, toggle)

-- Speed System
local enabled = false
local targetSpeed = 36
local humanoid = nil
local originalSpeed = nil
local generation = 0
local closed = false
local connections = {}

local function connect(signal, handler)
    local connection = signal:Connect(handler)
    table.insert(connections, connection)
    return connection
end

local function updateButton()
    if enabled then
        toggle.Text = "SPEED: ON | " .. targetSpeed
        toggle.BackgroundColor3 =
            Color3.fromRGB(34, 139, 104)
    else
        toggle.Text = "SPEED: OFF"
        toggle.BackgroundColor3 =
            Color3.fromRGB(72, 78, 96)
    end
end

local function applySpeed()
    if humanoid and humanoid.Parent and enabled then
        humanoid.WalkSpeed = targetSpeed
    end
end

-- Handle character spawn and respawn
local function attachCharacter(character)
    generation = generation + 1
    local myGeneration = generation

    humanoid = nil
    originalSpeed = nil

    local found = character:WaitForChild("Humanoid", 10)

    if closed or myGeneration ~= generation or not found then
        return
    end

    humanoid = found
    originalSpeed = found.WalkSpeed

    applySpeed()
end

-- Validate speed input
local function readSpeed()
    local value = tonumber(speedBox.Text)

    if not value or value ~= value
        or value < 8 or value > 150 then
        speedBox.Text = tostring(targetSpeed)
        return
    end

    targetSpeed = math.floor(value + 0.5)
    speedBox.Text = tostring(targetSpeed)

    applySpeed()
    updateButton()
end

-- Apply
connect(apply.MouseButton1Click, readSpeed)

connect(speedBox.FocusLost, function()
    readSpeed()
end)

-- Toggle ON/OFF
connect(toggle.MouseButton1Click, function()
    enabled = not enabled

    if enabled then
        readSpeed()
        applySpeed()
    elseif humanoid and humanoid.Parent
        and originalSpeed then
        humanoid.WalkSpeed = originalSpeed
    end

    updateButton()
end)

-- Minimize
local minimized = false

connect(minimize.MouseButton1Click, function()
    minimized = not minimized

    body.Visible = not minimized

    panel.Size = minimized
        and UDim2.fromOffset(270, 39)
        or UDim2.fromOffset(270, 168)

    minimize.Text = minimized and "+" or "-"
end)

-- Cleanup
local function shutdown()
    if closed then
        return
    end

    closed = true

    if enabled and humanoid
        and humanoid.Parent and originalSpeed then
        humanoid.WalkSpeed = originalSpeed
    end

    for _, connection in ipairs(connections) do
        connection:Disconnect()
    end

    gui:Destroy()
end

connect(close.MouseButton1Click, shutdown)
connect(gui.Destroying, shutdown)

-- Draggable UI
local dragging = false
local startInputPosition
local startPanelPosition

connect(header.InputBegan, function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then

        dragging = true
        startInputPosition = input.Position
        startPanelPosition = panel.Position
    end
end)

connect(UserInputService.InputChanged, function(input)
    if not dragging or not startInputPosition then
        return
    end

    if input.UserInputType ~= Enum.UserInputType.MouseMovement
        and input.UserInputType ~= Enum.UserInputType.Touch then
        return
    end

    local delta = input.Position - startInputPosition

    panel.Position = UDim2.new(
        startPanelPosition.X.Scale,
        startPanelPosition.X.Offset + delta.X,
        startPanelPosition.Y.Scale,
        startPanelPosition.Y.Offset + delta.Y
    )
end)

connect(UserInputService.InputEnded, function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
        dragging = false
    end
end)

-- Reapply speed periodically
local updateClock = 0

connect(RunService.Heartbeat, function(dt)
    if not enabled then
        return
    end

    updateClock = updateClock + dt

    if updateClock < 0.3 then
        return
    end

    updateClock = 0

    if humanoid and humanoid.Parent
        and humanoid.WalkSpeed ~= targetSpeed then
        humanoid.WalkSpeed = targetSpeed
    end
end)

-- Respawn support
connect(player.CharacterAdded, function(character)
    task.spawn(attachCharacter, character)
end)

if player.Character then
    task.spawn(attachCharacter, player.Character)
end

updateButton()

print("[Hunting Speed UI] Loaded successfully!")
