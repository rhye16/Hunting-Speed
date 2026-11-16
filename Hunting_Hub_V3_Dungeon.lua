--[[
    HUNTING HUB V3.1 | Combat Range Fix + Dungeon Assistant
    Main > Config Movement / Config Dungeon, Info, Save Config, Keybind
    Visual inspired by a dark sidebar-style hub.
    Dungeon module follows nearby enemies while the native Auto Battle handles attacks.
    It does NOT spoof attack/damage/reward requests or bypass progression checks.
    Executor file APIs are optional; config persistence uses them when available.
]]

local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")

local player = Players.LocalPlayer
local waitUntil = os.clock() + 15
while not player and os.clock() < waitUntil do
    task.wait(0.15)
    player = Players.LocalPlayer
end
if not player then warn("[Hunting Hub V2] LocalPlayer not available") return end

local playerGui = player:WaitForChild("PlayerGui", 12)
if not playerGui then warn("[Hunting Hub V2] PlayerGui not available") return end

-- Cleanup from previous execution. Avoid stacking Heartbeat/input handlers.
local globalEnv = _G
pcall(function()
    if type(getgenv) == "function" then globalEnv = getgenv() end
end)
if globalEnv.__HuntingHubV2 then
    pcall(function() globalEnv.__HuntingHubV2() end)
end
if globalEnv.__HuntingHubV3 then
    pcall(function() globalEnv.__HuntingHubV3() end)
end
local oldGui = playerGui:FindFirstChild("HuntingHubV3")
if oldGui then oldGui:Destroy() end

local COLOR = {
    bg = Color3.fromRGB(14, 16, 20),
    side = Color3.fromRGB(17, 19, 23),
    card = Color3.fromRGB(24, 27, 33),
    card2 = Color3.fromRGB(31, 35, 43),
    stroke = Color3.fromRGB(53, 58, 67),
    fg = Color3.fromRGB(239, 240, 242),
    muted = Color3.fromRGB(159, 164, 173),
    green = Color3.fromRGB(80, 160, 99),
    greenDark = Color3.fromRGB(37, 71, 47),
    red = Color3.fromRGB(195, 78, 83),
    blue = Color3.fromRGB(74, 119, 199)
}
local WIDTH, HEIGHT = 710, 434
local CONFIG_DIR = "HuntingHubV2"
local CONFIG_FILE = CONFIG_DIR .. "/config.json"
local cfg = {
    dungeonHeight = 1,
    dungeonRange = 4,
    dungeonAutoNext = true,
    walkSpeed = 36,
    jumpPower = 50,
    speedOn = false,
    jumpOn = false,
    autoReapply = true,
    dim = false,
    hotkey = "RightShift"
}

local function loadConfig()
    if type(readfile) ~= "function" then return false end
    local ok, result = pcall(function()
        if type(isfile) == "function" and not isfile(CONFIG_FILE) then return nil end
        return HttpService:JSONDecode(readfile(CONFIG_FILE))
    end)
    if not ok or type(result) ~= "table" then return false end
    if type(result.dungeonHeight) == "number" then cfg.dungeonHeight = math.clamp(math.floor(result.dungeonHeight), 0, 2) end
    if type(result.dungeonRange) == "number" then cfg.dungeonRange = math.clamp(math.floor(result.dungeonRange), 2, 5) end
    if type(result.dungeonAutoNext) == "boolean" then cfg.dungeonAutoNext = result.dungeonAutoNext end
    if type(result.walkSpeed) == "number" then cfg.walkSpeed = math.clamp(math.floor(result.walkSpeed + 0.5), 8, 150) end
    if type(result.jumpPower) == "number" then cfg.jumpPower = math.clamp(math.floor(result.jumpPower + 0.5), 10, 120) end
    if type(result.speedOn) == "boolean" then cfg.speedOn = result.speedOn end
    if type(result.jumpOn) == "boolean" then cfg.jumpOn = result.jumpOn end
    if type(result.autoReapply) == "boolean" then cfg.autoReapply = result.autoReapply end
    if type(result.dim) == "boolean" then cfg.dim = result.dim end
    if type(result.hotkey) == "string" and Enum.KeyCode[result.hotkey] then cfg.hotkey = result.hotkey end
    return true
end
local wasLoaded = loadConfig()
-- V3.1 migrates overly large V3 hover settings into a conservative combat range.
-- This deliberately prioritizes attacks being within likely effective range,
-- rather than the previous (10 horizontal, 5 vertical) position.


local function saveConfig()
    if type(writefile) ~= "function" then return false, "Executor tidak mendukung writefile" end
    local ok, err = pcall(function()
        if type(makefolder) == "function" then
            if type(isfolder) ~= "function" or not isfolder(CONFIG_DIR) then
                makefolder(CONFIG_DIR)
            end
        end
        writefile(CONFIG_FILE, HttpService:JSONEncode(cfg))
    end)
    return ok, ok and "Config disimpan di workspace executor" or tostring(err)
end

local alive = true
local connections = {}
local function listen(signal, handler)
    local c = signal:Connect(handler)
    table.insert(connections, c)
    return c
end
local function new(class, props, parent)
    local o = Instance.new(class)
    for k, v in pairs(props or {}) do o[k] = v end
    if parent then o.Parent = parent end
    return o
end
local function round(o, r)
    new("UICorner", {CornerRadius = UDim.new(0, r or 8)}, o)
end
local function stroke(o, c, t)
    new("UIStroke", {Color = c or COLOR.stroke, Thickness = t or 1}, o)
end
local function txt(parent, text, x, y, w, h, size, bold, color)
    return new("TextLabel", {
        Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(w, h),
        BackgroundTransparency = 1, Text = text, TextSize = size or 13,
        TextColor3 = color or COLOR.fg,
        Font = bold and Enum.Font.GothamBold or Enum.Font.Gotham,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Center
    }, parent)
end
local function button(parent, text, x, y, w, h, color)
    local b = new("TextButton", {
        Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(w, h),
        BackgroundColor3 = color or COLOR.card2, BorderSizePixel = 0,
        Text = text, TextColor3 = COLOR.fg, TextSize = 12,
        Font = Enum.Font.GothamBold, AutoButtonColor = true
    }, parent)
    round(b, 8)
    return b
end

local gui = new("ScreenGui", {
    Name = "HuntingHubV3", ResetOnSpawn = false,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    DisplayOrder = 9000, IgnoreGuiInset = true
}, playerGui)
local dimmer = new("Frame", {
    Name = "OptionalDim", Size = UDim2.fromScale(1, 1),
    BackgroundColor3 = Color3.new(0, 0, 0),
    BackgroundTransparency = 0.54, BorderSizePixel = 0,
    Active = false, Visible = cfg.dim
}, gui)
local panel = new("Frame", {
    Name = "HubWindow", AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.fromScale(0.5, 0.5),
    Size = UDim2.fromOffset(WIDTH, HEIGHT),
    BackgroundColor3 = COLOR.bg, BorderSizePixel = 0,
    Active = true, ClipsDescendants = true
}, gui)
round(panel, 12)
stroke(panel, Color3.fromRGB(72, 76, 84))
local scale = new("UIScale", {Scale = 1}, panel)
local function resize()
    local camera = workspace.CurrentCamera
    if not camera then return end
    local view = camera.ViewportSize
    scale.Scale = math.clamp(math.min((view.X - 22) / WIDTH, (view.Y - 22) / HEIGHT), 0.4, 1)
end
resize()
local cameraConn
local function connectCamera()
    if cameraConn then cameraConn:Disconnect() end
    local camera = workspace.CurrentCamera
    if camera then cameraConn = listen(camera:GetPropertyChangedSignal("ViewportSize"), resize) end
    resize()
end
connectCamera()
listen(workspace:GetPropertyChangedSignal("CurrentCamera"), connectCamera)

local side = new("Frame", {
    Name = "Sidebar", Size = UDim2.fromOffset(188, HEIGHT),
    BackgroundColor3 = COLOR.side, BorderSizePixel = 0
}, panel)
new("Frame", {Position = UDim2.fromOffset(187, 0), Size = UDim2.fromOffset(1, HEIGHT),
    BackgroundColor3 = COLOR.stroke, BorderSizePixel = 0}, panel)
local logo = new("Frame", {
    Position = UDim2.fromOffset(16, 17), Size = UDim2.fromOffset(37, 37),
    BackgroundColor3 = COLOR.greenDark, BorderSizePixel = 0
}, side)
round(logo, 10)
txt(logo, "H", 12, 3, 24, 30, 18, true, Color3.fromRGB(178, 242, 193))
txt(side, "Hunting Hub", 62, 19, 123, 21, 15, true)
txt(side, "v3.1  |  combat fix", 62, 40, 111, 18, 10, false, COLOR.muted)
new("Frame", {Position = UDim2.fromOffset(14, 70), Size = UDim2.fromOffset(160, 1),
    BackgroundColor3 = COLOR.stroke, BorderSizePixel = 0}, side)
txt(side, "NAVIGATION", 17, 87, 145, 16, 10, true, COLOR.muted)

local function nav(text, glyph, y)
    local b = button(side, "", 12, y, 163, 42, COLOR.side)
    local glyphBox = new("Frame", {
        Position = UDim2.fromOffset(9, 7), Size = UDim2.fromOffset(28, 28),
        BackgroundColor3 = COLOR.card2, BorderSizePixel = 0
    }, b)
    round(glyphBox, 7)
    txt(glyphBox, glyph, 9, 3, 20, 22, 12, true, COLOR.fg)
    txt(b, text, 46, 6, 110, 31, 13, false)
    return b
end
local mainNav = nav("Main", "M", 112)
local dungeonNav = nav("Dungeon", "D", 161)
local infoNav = nav("Info", "i", 210)
txt(side, "CONFIGURATION", 17, 263, 151, 17, 10, true, COLOR.muted)
local moveSub = txt(side, "  Config Movement", 17, 286, 160, 24, 12, false, COLOR.green)
local dungeonSub = txt(side, "  Config Dungeon", 17, 313, 160, 24, 12, false, COLOR.muted)
txt(side, "RightShift: Show / Hide", 16, 388, 169, 20, 10, false, COLOR.muted)

local content = new("Frame", {
    Position = UDim2.fromOffset(189, 0), Size = UDim2.fromOffset(WIDTH - 189, HEIGHT),
    BackgroundTransparency = 1
}, panel)
local titleBar = new("Frame", {Size = UDim2.fromOffset(WIDTH - 189, 54),
    BackgroundTransparency = 1, Active = true}, content)
txt(titleBar, "MAIN", 20, 12, 310, 26, 17, true)
local mini = button(titleBar, "_", 432, 13, 31, 29, COLOR.card2)
local close = button(titleBar, "X", 471, 13, 31, 29, Color3.fromRGB(101, 45, 49))
new("Frame", {Position = UDim2.fromOffset(20, 53), Size = UDim2.fromOffset(481, 1),
    BackgroundColor3 = COLOR.stroke, BorderSizePixel = 0}, content)
local mainPage = new("Frame", {Position = UDim2.fromOffset(0, 55),
    Size = UDim2.fromOffset(520, 379), BackgroundTransparency = 1}, content)
local dungeonPage = new("Frame", {Position = UDim2.fromOffset(0, 55),
    Size = UDim2.fromOffset(520, 379), BackgroundTransparency = 1,
    Visible = false}, content)
local infoPage = new("Frame", {Position = UDim2.fromOffset(0, 55),
    Size = UDim2.fromOffset(520, 379), BackgroundTransparency = 1,
    Visible = false}, content)

local movementCard = new("Frame", {
    Position = UDim2.fromOffset(18, 11), Size = UDim2.fromOffset(485, 286),
    BackgroundColor3 = COLOR.card, BorderSizePixel = 0
}, mainPage)
round(movementCard, 10)
stroke(movementCard)
txt(movementCard, "Config Movement", 16, 10, 335, 27, 15, true)
txt(movementCard, "Pengaturan lokal character Humanoid", 16, 37, 434, 19, 11, false, COLOR.muted)

local function inputRow(label, detail, y, value)
    txt(movementCard, label, 17, y, 255, 23, 13, true)
    txt(movementCard, detail, 17, y + 23, 262, 19, 10, false, COLOR.muted)
    local box = new("TextBox", {
        Position = UDim2.fromOffset(345, y + 1), Size = UDim2.fromOffset(119, 34),
        BackgroundColor3 = COLOR.card2, BorderSizePixel = 0,
        Text = tostring(value), Font = Enum.Font.GothamBold, TextSize = 14,
        TextColor3 = COLOR.fg, ClearTextOnFocus = false,
        PlaceholderText = tostring(value)
    }, movementCard)
    round(box, 7)
    return box
end
local speedBox = inputRow("WalkSpeed", "8 - 150  |  default disesuaikan karakter", 68, cfg.walkSpeed)
local jumpBox = inputRow("JumpPower", "10 - 120  |  opsi lompatan", 130, cfg.jumpPower)
local speedToggle = button(movementCard, "Speed: OFF", 17, 194, 138, 31)
local jumpToggle = button(movementCard, "Jump: OFF", 168, 194, 138, 31)
local reapplyToggle = button(movementCard, "Keep: ON", 319, 194, 145, 31)
local applyBtn = button(movementCard, "APPLY", 17, 238, 141, 34, COLOR.greenDark)
local resetBtn = button(movementCard, "RESET", 171, 238, 141, 34, COLOR.card2)
local saveBtn = button(movementCard, "SAVE CONFIG", 326, 238, 138, 34, COLOR.blue)

local statCard = new("Frame", {
    Position = UDim2.fromOffset(18, 308), Size = UDim2.fromOffset(485, 58),
    BackgroundColor3 = COLOR.card, BorderSizePixel = 0
}, mainPage)
round(statCard, 10)
stroke(statCard)
local liveStat = txt(statCard, "Live: character not ready", 14, 8, 460, 22, 12, false)
local status = txt(statCard, wasLoaded and "Config tersimpan dimuat" or "Siap - konfigurasi default", 14, 29, 462, 22, 11, false, COLOR.muted)

-- Dungeon UI. This module uses the game's own Auto Battle for attacks.
-- The portal/next-floor logic is heuristic until real dungeon structures are known.
local dungeonCard = new("Frame", {
    Position = UDim2.fromOffset(18, 11), Size = UDim2.fromOffset(485, 286),
    BackgroundColor3 = COLOR.card, BorderSizePixel = 0
}, dungeonPage)
round(dungeonCard, 10)
stroke(dungeonCard)
txt(dungeonCard, "Config Dungeon", 16, 9, 360, 25, 15, true)
txt(dungeonCard, "Aktifkan Auto Battle game. Low hover bukan anti-damage.", 16, 34, 453, 22, 11, false, COLOR.muted)
local function dungeonField(label, description, y, val)
    txt(dungeonCard, label, 17, y, 261, 23, 13, true)
    txt(dungeonCard, description, 17, y + 23, 295, 18, 10, false, COLOR.muted)
    local field = new("TextBox", {
        Position = UDim2.fromOffset(344, y + 1), Size = UDim2.fromOffset(120, 34),
        BackgroundColor3 = COLOR.card2, BorderSizePixel = 0,
        Font = Enum.Font.GothamBold, TextSize = 14, TextColor3 = COLOR.fg,
        Text = tostring(val), ClearTextOnFocus = false
    }, dungeonCard)
    round(field, 7)
    return field
end
local heightBox = dungeonField("Hover height", "Rendah untuk combat (0 - 2 studs)", 68, cfg.dungeonHeight)
local rangeBox = dungeonField("Target distance", "Dekat agar hit valid (2 - 5 studs)", 127, cfg.dungeonRange)
local dungeonToggle = button(dungeonCard, "DUNGEON: OFF", 17, 192, 211, 32, COLOR.card2)
local nextToggle = button(dungeonCard, "NEXT STAGE: ON", 240, 192, 224, 32, COLOR.greenDark)
local dungeonStop = button(dungeonCard, "STOP / LAND", 17, 239, 211, 33, COLOR.card2)
local dungeonSave = button(dungeonCard, "SAVE DUNGEON", 240, 239, 224, 33, COLOR.blue)
local dungeonStatCard = new("Frame", {
    Position = UDim2.fromOffset(18, 308), Size = UDim2.fromOffset(485, 58),
    BackgroundColor3 = COLOR.card, BorderSizePixel = 0
}, dungeonPage)
round(dungeonStatCard, 10)
stroke(dungeonStatCard)
local dungeonStateText = txt(dungeonStatCard, "Status: OFF - enter dungeon manually", 14, 7, 458, 22, 12, false)
local dungeonTargetText = txt(dungeonStatCard, "Target: - | Auto Battle should be ON", 14, 30, 460, 19, 11, false, COLOR.muted)
-- Info page
local infoCard = new("Frame", {
    Position = UDim2.fromOffset(18, 11), Size = UDim2.fromOffset(485, 328),
    BackgroundColor3 = COLOR.card, BorderSizePixel = 0
}, infoPage)
round(infoCard, 10)
stroke(infoCard)
txt(infoCard, "Hunting Hub V3", 17, 14, 390, 27, 17, true)
txt(infoCard, "Dark sidebar UI  |  Main / Dungeon / Info", 17, 42, 440, 22, 12, false, COLOR.muted)
new("Frame", {Position = UDim2.fromOffset(17, 75), Size = UDim2.fromOffset(450, 1),
    BackgroundColor3 = COLOR.stroke, BorderSizePixel = 0}, infoCard)
txt(infoCard, "Hotkey untuk tampil / sembunyi", 17, 87, 330, 24, 13, true)
local keyButton = button(infoCard, cfg.hotkey, 298, 116, 164, 34, COLOR.card2)
txt(infoCard, "Klik tombol ini, lalu tekan tombol keyboard baru.", 17, 116, 276, 36, 11, false, COLOR.muted)
local dimButton = button(infoCard, "Dim: OFF", 298, 168, 164, 34, COLOR.card2)
txt(infoCard, "Background dim (opsional)", 17, 165, 276, 37, 12, false)
txt(infoCard, "Config disimpan secara lokal pada workspace executor.", 17, 219, 441, 25, 11, false, COLOR.muted)
txt(infoCard, "Server game mungkin menolak atau mereset perubahan movement.", 17, 246, 454, 25, 11, false, COLOR.muted)
local saveInfo = button(infoCard, "SAVE SETTINGS", 17, 279, 445, 34, COLOR.greenDark)

local floatButton = button(gui, "H", 18, 105, 48, 48, COLOR.greenDark)
floatButton.Visible = false
stroke(floatButton, Color3.fromRGB(95, 175, 115))

local humanoid, initialValues, attachedSerial = nil, nil, 0
local function resetOnHumanoid()
    if not humanoid or not humanoid.Parent or not initialValues then return end
    pcall(function()
        humanoid.WalkSpeed = initialValues.walk
        humanoid.JumpPower = initialValues.power
        humanoid.JumpHeight = initialValues.height
    end)
end
local function applyProperties()
    if not humanoid or not humanoid.Parent then return end
    pcall(function()
        if cfg.speedOn then humanoid.WalkSpeed = cfg.walkSpeed end
        if cfg.jumpOn then
            if humanoid.UseJumpPower then
                humanoid.JumpPower = cfg.jumpPower
            else
                -- JumpHeight uses a different scale than JumpPower.
                humanoid.JumpHeight = 7.2 * (cfg.jumpPower / 50) ^ 2
            end
        end
    end)
end
local function attachCharacter(character)
    attachedSerial = attachedSerial + 1
    local serial = attachedSerial
    humanoid = nil
    initialValues = nil
    local newHumanoid = character:WaitForChild("Humanoid", 10)
    if not alive or serial ~= attachedSerial or not newHumanoid then return end
    humanoid = newHumanoid
    initialValues = {
        walk = newHumanoid.WalkSpeed,
        power = newHumanoid.JumpPower,
        height = newHumanoid.JumpHeight
    }
    applyProperties()
end

local function setStatus(message, good)
    status.Text = message
    status.TextColor3 = good == false and COLOR.red or (good == true and COLOR.green or COLOR.muted)
end
local function applyInputs()
    local speed = tonumber(speedBox.Text)
    local jump = tonumber(jumpBox.Text)
    if not speed or speed ~= speed or speed < 8 or speed > 150 then
        speedBox.Text = tostring(cfg.walkSpeed)
        setStatus("WalkSpeed harus 8 - 150", false)
        return false
    end
    if not jump or jump ~= jump or jump < 10 or jump > 120 then
        jumpBox.Text = tostring(cfg.jumpPower)
        setStatus("JumpPower harus 10 - 120", false)
        return false
    end
    cfg.walkSpeed = math.floor(speed + 0.5)
    cfg.jumpPower = math.floor(jump + 0.5)
    speedBox.Text = tostring(cfg.walkSpeed)
    jumpBox.Text = tostring(cfg.jumpPower)
    applyProperties()
    setStatus("Nilai movement diterapkan pada client", true)
    return true
end
local function updateToggles()
    speedToggle.Text = cfg.speedOn and "Speed: ON" or "Speed: OFF"
    speedToggle.BackgroundColor3 = cfg.speedOn and COLOR.greenDark or COLOR.card2
    jumpToggle.Text = cfg.jumpOn and "Jump: ON" or "Jump: OFF"
    jumpToggle.BackgroundColor3 = cfg.jumpOn and COLOR.greenDark or COLOR.card2
    reapplyToggle.Text = cfg.autoReapply and "Keep: ON" or "Keep: OFF"
    reapplyToggle.BackgroundColor3 = cfg.autoReapply and COLOR.greenDark or COLOR.card2
    dimButton.Text = cfg.dim and "Dim: ON" or "Dim: OFF"
    dimButton.BackgroundColor3 = cfg.dim and COLOR.greenDark or COLOR.card2
    keyButton.Text = cfg.hotkey
    dimmer.Visible = cfg.dim and panel.Visible
end
local activePage = "Main"
local function setPage(page)
    activePage = page
    mainPage.Visible = page == "Main"
    dungeonPage.Visible = page == "Dungeon"
    infoPage.Visible = page == "Info"
    mainNav.BackgroundColor3 = page == "Main" and COLOR.greenDark or COLOR.side
    dungeonNav.BackgroundColor3 = page == "Dungeon" and COLOR.greenDark or COLOR.side
    infoNav.BackgroundColor3 = page == "Info" and COLOR.greenDark or COLOR.side
    moveSub.TextColor3 = page == "Main" and COLOR.green or COLOR.muted
    dungeonSub.TextColor3 = page == "Dungeon" and COLOR.green or COLOR.muted
    titleBar:FindFirstChildWhichIsA("TextLabel").Text = string.upper(page)
end
local function setVisible(isVisible)
    panel.Visible = isVisible
    floatButton.Visible = not isVisible
    dimmer.Visible = isVisible and cfg.dim
    if isVisible then
        panel.Position = UDim2.fromScale(0.5, 0.5)
        pcall(function()
            TweenService:Create(panel, TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                BackgroundTransparency = 0
            }):Play()
        end)
    end
end

listen(mainNav.MouseButton1Click, function() setPage("Main") end)
listen(dungeonNav.MouseButton1Click, function() setPage("Dungeon") end)
listen(infoNav.MouseButton1Click, function() setPage("Info") end)
listen(speedToggle.MouseButton1Click, function()
    cfg.speedOn = not cfg.speedOn
    if cfg.speedOn then
        applyInputs()
    elseif humanoid and initialValues then
        humanoid.WalkSpeed = initialValues.walk
    end
    updateToggles()
end)
listen(jumpToggle.MouseButton1Click, function()
    cfg.jumpOn = not cfg.jumpOn
    if cfg.jumpOn then
        applyInputs()
    elseif humanoid and initialValues then
        humanoid.JumpPower = initialValues.power
        humanoid.JumpHeight = initialValues.height
    end
    updateToggles()
end)
listen(reapplyToggle.MouseButton1Click, function()
    cfg.autoReapply = not cfg.autoReapply
    updateToggles()
end)
listen(applyBtn.MouseButton1Click, applyInputs)
listen(resetBtn.MouseButton1Click, function()
    cfg.speedOn, cfg.jumpOn = false, false
    cfg.walkSpeed, cfg.jumpPower = 36, 50
    speedBox.Text, jumpBox.Text = "36", "50"
    resetOnHumanoid()
    updateToggles()
    setStatus("Reset ke nilai karakter asli (toggle OFF)", true)
end)
local function saveAndNotify()
    if not applyInputs() then return end
    local ok, message = saveConfig()
    setStatus(message, ok)
end
listen(saveBtn.MouseButton1Click, saveAndNotify)
listen(saveInfo.MouseButton1Click, saveAndNotify)
listen(dimButton.MouseButton1Click, function()
    cfg.dim = not cfg.dim
    updateToggles()
end)
local waitingKey = false
listen(keyButton.MouseButton1Click, function()
    waitingKey = true
    keyButton.Text = "Press a key..."
end)
listen(mini.MouseButton1Click, function() setVisible(false) end)
listen(floatButton.MouseButton1Click, function() setVisible(true) end)


-- DUNGEON ASSISTANT: hover above nearby enemies and approach next-stage gate.
-- Combat is performed by the game's built-in Auto Battle. No remote spoofing.
local dungeonActive = false
local hoverMover = nil
local hoverGyro = nil
local hoverRoot = nil
local dungeonTarget = nil
local noEnemySince = nil
local lastGateAttempt = -1e6
local lastScanTime = 0
local cachedEnemies = {}
local cachedGate = nil
local lastMovementClock = os.clock()
local dungeonCycle = 0
local function dungeonStatus(msg, targetName)
    dungeonStateText.Text = "Status: " .. msg
    dungeonTargetText.Text = "Target: " .. (targetName or "-")
end
local function land()
    if hoverMover then pcall(function() hoverMover:Destroy() end) end
    if hoverGyro then pcall(function() hoverGyro:Destroy() end) end
    hoverMover, hoverGyro, hoverRoot = nil, nil, nil
end
local function stopDungeon(reason)
    dungeonActive = false
    dungeonCycle = dungeonCycle + 1
    dungeonTarget = nil
    noEnemySince = nil
    cachedGate = nil
    land()
    dungeonToggle.Text = "DUNGEON: OFF"
    dungeonToggle.BackgroundColor3 = COLOR.card2
    dungeonStatus(reason or "OFF - landed", "-")
end
local function applyDungeonFields()
    local h, r = tonumber(heightBox.Text), tonumber(rangeBox.Text)
    if not h or h ~= h or h < 0 or h > 2 then
        dungeonStatus("Hover height must be 0 - 2", "-")
        return false
    end
    if not r or r ~= r or r < 2 or r > 5 then
        dungeonStatus("Target distance must be 2 - 5", "-")
        return false
    end
    cfg.dungeonHeight = math.floor(h)
    cfg.dungeonRange = math.floor(r)
    heightBox.Text = tostring(cfg.dungeonHeight)
    rangeBox.Text = tostring(cfg.dungeonRange)
    return true
end
local function makeHover(root)
    if hoverRoot == root and hoverMover and hoverMover.Parent then return end
    land()
    hoverRoot = root
    hoverMover = Instance.new("BodyPosition")
    hoverMover.Name = "HuntingHubDungeonHover"
    hoverMover.MaxForce = Vector3.new(115000, 135000, 115000)
    hoverMover.P = 6000
    hoverMover.D = 1100
    hoverMover.Position = root.Position
    hoverMover.Parent = root
    hoverGyro = Instance.new("BodyGyro")
    hoverGyro.Name = "HuntingHubDungeonFacing"
    hoverGyro.MaxTorque = Vector3.new(0, 250000, 0)
    hoverGyro.P = 4500
    hoverGyro.D = 500
    hoverGyro.CFrame = root.CFrame
    hoverGyro.Parent = root
end
local function normalizedName(name)
    return string.lower(tostring(name or "")):gsub("[%s_%-%p]", "")
end
local exclusions = {"trainingdummy", "merchant", "shop", "villageguard", "quest", "statmaster", "blacksmith", "npc", "friend", "pet", "companion", "vendor", "dummy", "bank", "teleporter"}
local threats = {"boss", "enemy", "monster", "mob", "skeleton", "goblin", "slime", "wolf", "rabbit", "spider", "hellhound", "tiger", "orc", "zombie", "bandit", "dungeon", "bat", "ghost", "golem", "dragon", "boar", "undead", "serpent", "beast", "knight", "imp", "mimic", "minion"}
local function hasTerm(s, terms)
    for _, term in ipairs(terms) do
        if string.find(s, term, 1, true) then return true end
    end
    return false
end
local function isPlayerModel(model)
    return Players:GetPlayerFromCharacter(model) ~= nil
end
local function isAliveEnemy(model)
    if not model or not model.Parent or not model:IsA("Model") then return nil end
    if isPlayerModel(model) then return nil end
    local key = normalizedName(model.Name)
    if hasTerm(key, exclusions) then return nil end
    -- V3 wrongly targeted nested body-part models like "Head".
    -- They can inherit an Enemy/Dungeon parent name but are not target entities.
    if hasTerm(key, {"head", "torso", "upperbody", "lowerbody", "leftarm", "rightarm", "leftleg", "rightleg", "weapon", "accessory", "hitbox", "collider", "visual", "vfx"}) then return nil end
    local anc = model.Parent
    local flagged = hasTerm(key, threats)
    for _ = 1, 3 do
        if not anc or anc == workspace then break end
        local f = normalizedName(anc.Name)
        if hasTerm(f, {"enemy", "monster", "mobs", "dungeon", "boss"}) then flagged = true end
        anc = anc.Parent
    end
    if model:GetAttribute("IsEnemy") == true or model:GetAttribute("IsBoss") == true then flagged = true end
    if not flagged then return nil end
    local hp = nil
    local humanoid = model:FindFirstChildOfClass("Humanoid")
    if humanoid then hp = humanoid.Health end
    if hp == nil then
        for _, attr in ipairs({"HP", "Health", "CurrentHP", "CurrentHealth"}) do
            local v = model:GetAttribute(attr)
            if type(v) == "number" then hp = v break end
        end
    end
    if hp == nil then
        for _, attr in ipairs({"HP", "Health"}) do
            local v = model:FindFirstChild(attr)
            if v and (v:IsA("NumberValue") or v:IsA("IntValue")) then hp = v.Value break end
        end
    end
    if hp ~= nil and hp <= 0 then return nil end
    if model:GetAttribute("Dead") == true then return nil end
    -- Require evidence this model is an actual creature rather than a nested decoration.
    -- Some games expose Humanoid; others expose HP attributes or an explicit root part.
    local ownRoot = model:FindFirstChild("HumanoidRootPart")
        or model:FindFirstChild("RootPart") or model.PrimaryPart
    local explicitEnemy = model:GetAttribute("IsEnemy") == true
        or model:GetAttribute("IsBoss") == true
    if not (humanoid or hp ~= nil or ownRoot or explicitEnemy) then return nil end
    local part = ownRoot or model:FindFirstChildWhichIsA("BasePart")
    return part
end
local function scanEnemies(origin)
    local monsters = {}
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("Model") then
            local part = isAliveEnemy(obj)
            if part and (part.Position - origin).Magnitude < 180 then
                local name = normalizedName(obj.Name)
                local isBoss = hasTerm(name, {"boss", "lord", "king", "queen"}) or obj:GetAttribute("IsBoss") == true
                table.insert(monsters, {model=obj, part=part, boss=isBoss})
            end
        end
    end
    return monsters
end
local gateTerms = {"nextfloor", "nextstage", "nextwave", "nextroom", "portal", "gate", "stairs", "staircase", "proceed", "continue", "advance"}
local badGates = {"exit", "leave", "lobby", "return", "home", "spawn", "shop"}
local function findGate(origin)
    local best, bestDist = nil, 180
    for _, item in ipairs(workspace:GetDescendants()) do
        local target, prompt, label
        if item:IsA("ProximityPrompt") then
            prompt = item
            target = item.Parent
            label = normalizedName(item.ActionText .. item.ObjectText .. (target and target.Name or ""))
        elseif item:IsA("BasePart") then
            target = item
            label = normalizedName(item.Name)
        end
        if target and label and hasTerm(label, gateTerms) and not hasTerm(label, badGates) then
            local part = target:IsA("BasePart") and target or target:FindFirstChildWhichIsA("BasePart")
            if part then
                local dist = (part.Position - origin).Magnitude
                if dist < bestDist then
                    bestDist = dist
                    best = {part=part, prompt=prompt, label=label}
                end
            end
        end
    end
    return best
end
local function approach(destination, facing, dt)
    local char = player.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if not root or not hum or hum.Health <= 0 then
        stopDungeon("Character unavailable/dead")
        return
    end
    makeHover(root)
    local delta = destination - root.Position
    local maxStep = math.clamp(dt, 0.05, 0.4) * 44
    hoverMover.Position = root.Position + (delta.Magnitude > maxStep and delta.Unit * maxStep or delta)
    local look = Vector3.new(facing.X, root.Position.Y, facing.Z)
    if (look - root.Position).Magnitude > 0.5 then
        hoverGyro.CFrame = CFrame.lookAt(root.Position, look)
    end
end
local function pickTarget(root)
    local nonBoss, boss, nd, bd
    nd, bd = math.huge, math.huge
    for _, entry in ipairs(cachedEnemies) do
        local part = isAliveEnemy(entry.model)
        if part then
            local d = (part.Position - root.Position).Magnitude
            if d <= 180 then
                if entry.boss then
                    if d < bd then boss, bd = {model=entry.model, part=part}, d end
                else
                    if d < nd then nonBoss, nd = {model=entry.model, part=part}, d end
                end
            end
        end
    end
    return nonBoss or boss
end
local function flyStep(dt)
    if not dungeonActive or not alive then return end
    local char = player.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if not root or not hum or hum.Health <= 0 then
        stopDungeon("Character unavailable/dead")
        return
    end
    local now = os.clock()
    if now - lastScanTime > 1.2 then
        lastScanTime = now
        cachedEnemies = scanEnemies(root.Position)
    end
    local selected = pickTarget(root)
    if selected then
        cachedGate = nil
        noEnemySince = nil
        dungeonTarget = selected.model
        local part = selected.part
        local facingAway = root.Position - part.Position
        facingAway = Vector3.new(facingAway.X, 0, facingAway.Z)
        if facingAway.Magnitude < 0.1 then facingAway = Vector3.new(1, 0, 0) end
        -- The previous V3 could chase targets >10 studs away vertically/horizontally.
        -- Use only low-hover, short-range positioning; this does not bypass server combat rules.
        local goal = part.Position + facingAway.Unit * cfg.dungeonRange
            + Vector3.new(0, cfg.dungeonHeight, 0)
        approach(goal, part.Position, dt)
        local separation = (root.Position - part.Position).Magnitude
        dungeonStatus(selected.model.Name:lower():find("boss", 1, true)
            and "BOSS - low hover" or "Combat - low hover",
            string.format("%s | %.1f studs", selected.model.Name, separation))
        return
    end
    dungeonTarget = nil
    if not noEnemySince then noEnemySince = now end
    if not cfg.dungeonAutoNext then
        land()
        dungeonStatus("No recognized monsters", "Auto Next disabled")
        return
    end
    if now - noEnemySince < 6 then
        land()
        dungeonStatus("Waiting for next wave...", "-")
        return
    end
    if not cachedGate or not cachedGate.part or not cachedGate.part.Parent then
        cachedGate = findGate(root.Position)
    end
    if not cachedGate then
        land()
        dungeonStatus("No next-stage gate detected", "Check dungeon mechanics")
        return
    end
    local gatePart = cachedGate.part
    local goal = gatePart.Position + Vector3.new(0, 3, 0)
    approach(goal, gatePart.Position, dt)
    dungeonStatus("Approaching next gate", gatePart.Name)
    if (root.Position - gatePart.Position).Magnitude < 11 then
        local prompt = cachedGate.prompt
        if prompt and prompt.Parent and prompt.Enabled and now - lastGateAttempt > 9 then
            lastGateAttempt = now
            local cycle = dungeonCycle
            task.spawn(function()
                local ok, err = pcall(function()
                    prompt:InputHoldBegin()
                    task.wait(math.clamp(prompt.HoldDuration + 0.1, 0.1, 3))
                    prompt:InputHoldEnd()
                end)
                if dungeonActive and dungeonCycle == cycle then
                    dungeonStatus(ok and "Gate interaction attempted" or "Gate interaction unavailable", gatePart.Name)
                    if not ok then warn("[Hub V3] gate:", tostring(err)) end
                end
            end)
        end
    end
end
listen(dungeonToggle.MouseButton1Click, function()
    if dungeonActive then
        stopDungeon("Stopped by user")
        return
    end
    if not applyDungeonFields() then return end
    dungeonActive = true
    dungeonCycle = dungeonCycle + 1
    lastScanTime = 0
    lastMovementClock = os.clock()
    noEnemySince = nil
    cachedGate = nil
    dungeonToggle.Text = "DUNGEON: ON"
    dungeonToggle.BackgroundColor3 = COLOR.greenDark
    dungeonStatus("Scanning nearby monsters", "Use game Auto Battle ON")
end)
listen(nextToggle.MouseButton1Click, function()
    cfg.dungeonAutoNext = not cfg.dungeonAutoNext
    nextToggle.Text = cfg.dungeonAutoNext and "NEXT STAGE: ON" or "NEXT STAGE: OFF"
    nextToggle.BackgroundColor3 = cfg.dungeonAutoNext and COLOR.greenDark or COLOR.card2
end)
listen(dungeonStop.MouseButton1Click, function() stopDungeon("Stopped by user") end)
listen(dungeonSave.MouseButton1Click, function()
    if not applyDungeonFields() then return end
    local ok, msg = saveConfig()
    dungeonStatus(ok and "Dungeon settings saved" or "Cannot save: " .. tostring(msg), "-")
end)
listen(player.CharacterAdded, function()
    if dungeonActive then stopDungeon("Respawn - re-enable dungeon") end
end)
listen(RunService.Heartbeat, function()
    if not dungeonActive then return end
    local now = os.clock()
    if now - lastMovementClock < 0.15 then return end
    local dt = now - lastMovementClock
    lastMovementClock = now
    local ok, err = pcall(flyStep, dt)
    if not ok then
        warn("[Hunting Hub V3 Dungeon]", tostring(err))
        stopDungeon("Error - stopped safely")
    end
end)
nextToggle.Text = cfg.dungeonAutoNext and "NEXT STAGE: ON" or "NEXT STAGE: OFF"
nextToggle.BackgroundColor3 = cfg.dungeonAutoNext and COLOR.greenDark or COLOR.card2

-- Character respawn and single Heartbeat update loop.
listen(player.CharacterAdded, function(char)
    task.spawn(attachCharacter, char)
end)
if player.Character then task.spawn(attachCharacter, player.Character) end
local timer = 0
listen(RunService.Heartbeat, function(dt)
    timer = timer + dt
    if timer < 0.33 then return end
    timer = 0
    if cfg.autoReapply then applyProperties() end
    if humanoid and humanoid.Parent then
        liveStat.Text = string.format("Live  |  Speed: %.1f  |  Jump: %.1f  |  ASPD: %s",
            humanoid.WalkSpeed,
            humanoid.UseJumpPower and humanoid.JumpPower or humanoid.JumpHeight,
            tostring(player:GetAttribute("ASPD") or "-"))
    else
        liveStat.Text = "Live: menunggu karakter..."
    end
end)
listen(UIS.InputBegan, function(input, processed)
    if waitingKey and input.UserInputType == Enum.UserInputType.Keyboard then
        cfg.hotkey = input.KeyCode.Name
        waitingKey = false
        updateToggles()
        return
    end
    if processed or UIS:GetFocusedTextBox() then return end
    if input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode.Name == cfg.hotkey then
        setVisible(not panel.Visible)
    end
end)

-- Header drag (mouse / touch); account for UIScale when moving panel.
local dragging = false
local dragInput, dragOrigin, posOrigin
listen(titleBar.InputBegan, function(input)
    if input.UserInputType ~= Enum.UserInputType.MouseButton1 and
       input.UserInputType ~= Enum.UserInputType.Touch then return end
    dragging = true
    dragInput = input
    dragOrigin = input.Position
    posOrigin = panel.Position
    listen(input.Changed, function()
        if input.UserInputState == Enum.UserInputState.End then dragging = false end
    end)
end)
listen(UIS.InputChanged, function(input)
    if not dragging or not dragOrigin then return end
    if input ~= dragInput and not (
        dragInput.UserInputType == Enum.UserInputType.MouseButton1 and
        input.UserInputType == Enum.UserInputType.MouseMovement) then return end
    local delta = (input.Position - dragOrigin) / scale.Scale
    panel.Position = UDim2.new(posOrigin.X.Scale, posOrigin.X.Offset + delta.X,
        posOrigin.Y.Scale, posOrigin.Y.Offset + delta.Y)
end)
listen(UIS.InputEnded, function(input)
    if input == dragInput or (input.UserInputType == Enum.UserInputType.MouseButton1) then
        dragging = false
    end
end)

local shutdown
shutdown = function()
    if not alive then return end
    alive = false
    stopDungeon("Hub closed")
    resetOnHumanoid()
    for _, c in ipairs(connections) do pcall(function() c:Disconnect() end) end
    if globalEnv.__HuntingHubV3 == shutdown then globalEnv.__HuntingHubV3 = nil end
    if gui and gui.Parent then gui:Destroy() end
end
globalEnv.__HuntingHubV3 = shutdown
listen(close.MouseButton1Click, shutdown)
listen(gui.Destroying, shutdown)
updateToggles()
setPage("Main")
print("[Hunting Hub V3.1] Loaded. Keybind:", cfg.hotkey)
print("[Hunting Hub V3] Save config:", CONFIG_FILE)
print("[Hunting Hub V3.1] Low hover only; enemy AoE, evasion, server hit range still apply.")
