--[[
    RHYE HUB V3.3 | Wall-Aware Dodge + Adjustable Dungeon Travel
    Main > Config Movement / Config Dungeon, Info, Save Config, Keybind
    Visual inspired by a dark sidebar-style hub.
    Dungeon module follows nearby enemies while the native Auto Battle handles attacks.
    It does NOT spoof attack/damage/reward requests or bypass progression checks.
    Dodge observes nearby RED world parts; purely visual GPU effects may be invisible to it.
    Executor file APIs are optional; config persistence uses them when available.
]]

local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")
local PathfindingService = game:GetService("PathfindingService")

local player = Players.LocalPlayer
local waitUntil = os.clock() + 15
while not player and os.clock() < waitUntil do
    task.wait(0.15)
    player = Players.LocalPlayer
end
if not player then warn("[RHYE Hub] LocalPlayer not available") return end

local playerGui = player:WaitForChild("PlayerGui", 12)
if not playerGui then warn("[RHYE Hub] PlayerGui not available") return end

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
if globalEnv.__RHYEHubV3 then
    pcall(function() globalEnv.__RHYEHubV3() end)
end
for _, previousName in ipairs({"HuntingHubV3", "RHYEHubV3_2", "RHYEHubV3_3"}) do
    local previous = playerGui:FindFirstChild(previousName)
    if previous then previous:Destroy() end
end

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
local CONFIG_DIR = "RHYEHub"
local CONFIG_FILE = CONFIG_DIR .. "/config.json"
-- Migrate old V2/V3.1 settings automatically on the first run.
local LEGACY_CONFIG_FILE = "HuntingHubV2/config.json"
local cfg = {
    dungeonHeight = 1,
    dungeonRange = 6,
    dungeonMoveSpeed = 78,
    dungeonAutoNext = true,
    dungeonAutoDodge = false,
    dungeonDodgeNoclip = false,
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
        local path = CONFIG_FILE
        if type(isfile) == "function" then
            if not isfile(path) then
                if isfile(LEGACY_CONFIG_FILE) then
                    path = LEGACY_CONFIG_FILE
                else
                    return nil
                end
            end
        end
        return HttpService:JSONDecode(readfile(path))
    end)
    if not ok or type(result) ~= "table" then return false end
    if type(result.dungeonHeight) == "number" then cfg.dungeonHeight = math.clamp(math.floor(result.dungeonHeight), 0, 2) end
    if type(result.dungeonRange) == "number" then cfg.dungeonRange = math.clamp(math.floor(result.dungeonRange), 2, 30) end
    if type(result.dungeonMoveSpeed) == "number" then cfg.dungeonMoveSpeed = math.clamp(math.floor(result.dungeonMoveSpeed), 20, 150) end
    if type(result.dungeonDodgeNoclip) == "boolean" then cfg.dungeonDodgeNoclip = result.dungeonDodgeNoclip end
    if type(result.dungeonAutoNext) == "boolean" then cfg.dungeonAutoNext = result.dungeonAutoNext end
    if type(result.dungeonAutoDodge) == "boolean" then cfg.dungeonAutoDodge = result.dungeonAutoDodge end
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
    Name = "RHYEHubV3_3", ResetOnSpawn = false,
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
txt(logo, "R", 12, 3, 24, 30, 18, true, Color3.fromRGB(178, 242, 193))
txt(side, "RHYE Hub", 62, 19, 123, 21, 15, true)
txt(side, "v3.3  |  wall-safe", 62, 40, 117, 18, 10, false, COLOR.muted)
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
local dungeonPage = new("ScrollingFrame", {Position = UDim2.fromOffset(0, 55),
    Size = UDim2.fromOffset(520, 379), BackgroundTransparency = 1,
    BorderSizePixel = 0, ScrollBarThickness = 5,
    CanvasSize = UDim2.fromOffset(0, 513),
    ScrollingDirection = Enum.ScrollingDirection.Y,
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
    Position = UDim2.fromOffset(18, 11), Size = UDim2.fromOffset(485, 399),
    BackgroundColor3 = COLOR.card, BorderSizePixel = 0
}, dungeonPage)
round(dungeonCard, 10)
stroke(dungeonCard)
txt(dungeonCard, "Config Dungeon", 16, 9, 360, 25, 15, true)
txt(dungeonCard, "Auto Battle game ON. Auto Dodge membaca zona merah berupa Parts.", 16, 34, 460, 22, 11, false, COLOR.muted)
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
local heightBox = dungeonField("Hover height", "Low hover (0 - 2 studs)", 65, cfg.dungeonHeight)
local rangeBox = dungeonField("Attack range", "2 - 30 studs | terlalu jauh bisa MISS", 120, cfg.dungeonRange)
local dungeonSpeedBox = dungeonField("Dungeon speed", "20 - 150 | kecepatan follow + dodge", 175, cfg.dungeonMoveSpeed)
txt(dungeonCard, "Dodge cek dinding; optional Noclip hanya saat dodge.", 17, 221, 450, 18, 10, false, COLOR.muted)
local dungeonToggle = button(dungeonCard, "DUNGEON: OFF", 17, 244, 145, 32, COLOR.card2)
local nextToggle = button(dungeonCard, "NEXT: ON", 171, 244, 141, 32, COLOR.greenDark)
local dodgeToggle = button(dungeonCard, "DODGE: OFF", 322, 244, 142, 32, COLOR.card2)
local noclipToggle = button(dungeonCard, "NOCLIP (DODGE): OFF", 17, 290, 447, 32, COLOR.card2)
txt(dungeonCard, "Noclip bisa desync; gunakan saat dodge terjebak saja.", 17, 329, 440, 18, 10, false, COLOR.muted)
local dungeonStop = button(dungeonCard, "STOP / LAND", 17, 354, 211, 32, COLOR.card2)
local dungeonSave = button(dungeonCard, "SAVE DUNGEON", 240, 354, 224, 32, COLOR.blue)
local dungeonStatCard = new("Frame", {
    Position = UDim2.fromOffset(18, 421), Size = UDim2.fromOffset(485, 78),
    BackgroundColor3 = COLOR.card, BorderSizePixel = 0
}, dungeonPage)
round(dungeonStatCard, 10)
stroke(dungeonStatCard)
local dungeonStateText = txt(dungeonStatCard, "Status: OFF - enter dungeon manually", 14, 8, 458, 25, 12, false)
local dungeonTargetText = txt(dungeonStatCard, "Target: - | Auto Battle should be ON", 14, 34, 460, 33, 11, false, COLOR.muted)
dungeonTargetText.TextWrapped = true
-- Info page
local infoCard = new("Frame", {
    Position = UDim2.fromOffset(18, 11), Size = UDim2.fromOffset(485, 328),
    BackgroundColor3 = COLOR.card, BorderSizePixel = 0
}, infoPage)
round(infoCard, 10)
stroke(infoCard)
txt(infoCard, "RHYE Hub V3.3", 17, 14, 390, 27, 17, true)
txt(infoCard, "Dark sidebar UI  |  Main / Dungeon / Info", 17, 42, 440, 22, 12, false, COLOR.muted)
new("Frame", {Position = UDim2.fromOffset(17, 75), Size = UDim2.fromOffset(450, 1),
    BackgroundColor3 = COLOR.stroke, BorderSizePixel = 0}, infoCard)
txt(infoCard, "Hotkey untuk tampil / sembunyi", 17, 87, 330, 24, 13, true)
local keyButton = button(infoCard, cfg.hotkey, 298, 116, 164, 34, COLOR.card2)
txt(infoCard, "Klik tombol ini, lalu tekan tombol keyboard baru.", 17, 116, 276, 36, 11, false, COLOR.muted)
local dimButton = button(infoCard, "Dim: OFF", 298, 168, 164, 34, COLOR.card2)
txt(infoCard, "Background dim (opsional)", 17, 165, 276, 37, 12, false)
txt(infoCard, "Config disimpan secara lokal pada workspace executor.", 17, 219, 441, 25, 11, false, COLOR.muted)
txt(infoCard, "Wall-aware dodge dan Noclip opsional tidak menjamin kebal AoE.", 17, 246, 454, 25, 11, false, COLOR.muted)
local saveInfo = button(infoCard, "SAVE SETTINGS", 17, 279, 445, 34, COLOR.greenDark)

local floatButton = button(gui, "R", 18, 105, 48, 48, COLOR.greenDark)
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
-- Red telegraph detector: passive world-part observation, no remotes.
local recentVisualParts = setmetatable({}, {__mode = "k"})
local nearbyHazards = {}
local lastHazardScan = -1e6
local dodgeGoal = nil
local dodgeWaypoint = nil
local dodgeNoclipTravel = false
local dodgeFailed = {}
local dodgeRetry = 0
local dodgeProgressPosition = nil
local dodgeProgressAt = 0
local dodgeHoldUntil = 0
-- Original CanCollide flags must be restored when dodge/Hub ends.
local collisionCache = setmetatable({}, {__mode = "k"})
local noclipActive = false
local dodgeCount = 0
local lastDodgeLog = -1e6
local dungeonCycle = 0
local function dungeonStatus(msg, targetName)
    dungeonStateText.Text = "Status: " .. msg
    dungeonTargetText.Text = "Target: " .. (targetName or "-")
end
local function setDodgeNoclip(enabled)
    if enabled then
        noclipActive = true
        local char = player.Character
        if not char then return end
        for _, obj in ipairs(char:GetDescendants()) do
            if obj:IsA("BasePart") then
                if collisionCache[obj] == nil then collisionCache[obj] = obj.CanCollide end
                if obj.CanCollide then obj.CanCollide = false end
            end
        end
    elseif noclipActive then
        noclipActive = false
        for part, wasCollidable in pairs(collisionCache) do
            if part.Parent then pcall(function() part.CanCollide = wasCollidable end) end
            collisionCache[part] = nil
        end
    end
end
local function land()
    setDodgeNoclip(false)
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
    dodgeGoal = nil
    dodgeWaypoint = nil
    dodgeNoclipTravel = false
    dodgeFailed = {}
    dodgeRetry = 0
    dodgeProgressPosition = nil
    dodgeProgressAt = 0
    dodgeHoldUntil = 0
    nearbyHazards = {}
    land()
    dungeonToggle.Text = "DUNGEON: OFF"
    dungeonToggle.BackgroundColor3 = COLOR.card2
    dungeonStatus(reason or "OFF - landed", "-")
end
local function applyDungeonFields()
    local h, r, speed = tonumber(heightBox.Text), tonumber(rangeBox.Text), tonumber(dungeonSpeedBox.Text)
    if not h or h ~= h or h < 0 or h > 2 then
        dungeonStatus("Hover height must be 0 - 2", "-")
        return false
    end
    if not r or r ~= r or r < 2 or r > 30 then
        dungeonStatus("Attack range must be 2 - 30", "-")
        return false
    end
    if not speed or speed ~= speed or speed < 20 or speed > 150 then
        dungeonStatus("Dungeon speed must be 20 - 150", "-")
        return false
    end
    cfg.dungeonHeight = math.floor(h)
    cfg.dungeonRange = math.floor(r)
    cfg.dungeonMoveSpeed = math.floor(speed)
    heightBox.Text = tostring(cfg.dungeonHeight)
    rangeBox.Text = tostring(cfg.dungeonRange)
    dungeonSpeedBox.Text = tostring(cfg.dungeonMoveSpeed)
    return true
end
local function makeHover(root)
    if hoverRoot == root and hoverMover and hoverMover.Parent then return end
    land()
    hoverRoot = root
    hoverMover = Instance.new("BodyPosition")
    hoverMover.Name = "RHYEHubDungeonHover"
    hoverMover.MaxForce = Vector3.new(210000, 245000, 210000)
    hoverMover.P = 10200
    hoverMover.D = 1400
    hoverMover.Position = root.Position
    hoverMover.Parent = root
    hoverGyro = Instance.new("BodyGyro")
    hoverGyro.Name = "RHYEHubDungeonFacing"
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
local function approach(destination, facing, dt, movementSpeed)
    local char = player.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if not root or not hum or hum.Health <= 0 then
        stopDungeon("Character unavailable/dead")
        return
    end
    makeHover(root)
    local delta = destination - root.Position
    local maxStep = math.clamp(dt, 0.03, 0.25) * (movementSpeed or cfg.dungeonMoveSpeed)
    hoverMover.Position = root.Position + (delta.Magnitude > maxStep and delta.Unit * maxStep or delta)
    local look = Vector3.new(facing.X, root.Position.Y, facing.Z)
    if (look - root.Position).Magnitude > 0.5 then
        hoverGyro.CFrame = CFrame.lookAt(root.Position, look)
    end
end

-- Telegraphed AoE scanner (experimental): supports nearby RED BaseParts/MeshParts.
-- Does not see BillboardGui, screen effects, Beams or purely GPU particle textures.
-- IMPORTANT: Red visual objects are not proof of actual server hitboxes.
local hazardWords = {
    "telegraph", "warning", "danger", "aoe", "attackzone", "hitarea",
    "redzone", "spikeline", "spike", "indicator", "hazard", "attackpreview"
}
local function isRedWarningPart(part, origin)
    if not part:IsA("BasePart") or not part.Parent then return false end
    if part.Transparency >= 0.96 then return false end
    if (part.Position - origin).Magnitude > 44 then return false end
    if math.abs(part.Position.Y - origin.Y) > 9 then return false end
    local color = part.Color
    if not (color.R >= 0.60 and color.R >= color.G * 1.65
        and color.R >= color.B * 1.55) then return false end
    local size = part.Size
    if math.max(size.X, size.Z) < 2 or size.X * size.Z < 3 then return false end
    local named = hasTerm(normalizedName(part.Name), hazardWords)
    local ancestor = part.Parent
    for _ = 1, 3 do
        if not ancestor or ancestor == workspace then break end
        if hasTerm(normalizedName(ancestor.Name), hazardWords) then named = true end
        ancestor = ancestor.Parent
    end
    -- Flat red markings are most likely to be ground telegraphs. Exclude red NPC parts.
    local flat = size.Y <= math.max(2.5, math.min(size.X, size.Z) * 0.5)
    if not (named or flat) then return false end
    local creature = part:FindFirstAncestorOfClass("Model")
    if creature and creature:FindFirstChildOfClass("Humanoid") and not named then
        return false
    end
    local fresh = recentVisualParts[part] and os.clock() - recentVisualParts[part] < 15
    local visual = part.Transparency > 0.02 or part.Material == Enum.Material.Neon
    if not (named or fresh or visual) then return false end
    return true
end

local function refreshHazards(origin)
    local now = os.clock()
    if now - lastHazardScan < 0.24 then return end
    lastHazardScan = now
    local found, used = {}, {}
    local params = OverlapParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = player.Character and {player.Character} or {}
    local ok, nearby = pcall(function()
        return workspace:GetPartBoundsInRadius(origin, 44, params)
    end)
    if ok and nearby then
        for _, part in ipairs(nearby) do
            if not used[part] and isRedWarningPart(part, origin) then
                found[#found + 1] = part
                used[part] = true
            end
        end
    end
    -- CanQuery=false warning parts may be missing from spatial overlap queries.
    -- Recently inserted parts are checked separately as a small fallback cache.
    for part, inserted in pairs(recentVisualParts) do
        if not part.Parent or now - inserted > 20 then
            recentVisualParts[part] = nil
        elseif not used[part] and isRedWarningPart(part, origin) then
            found[#found + 1] = part
            used[part] = true
        end
    end
    nearbyHazards = found
end

local function pointInsideRed(point)
    for _, part in ipairs(nearbyHazards) do
        if part.Parent and math.abs(point.Y - part.Position.Y) < 9 then
            -- Conservative world-space XZ bounds of an oriented red warning part.
            local cf, sz = part.CFrame, part.Size
            local right, up, look = cf.RightVector, cf.UpVector, cf.LookVector
            local halfX = (math.abs(right.X) * sz.X + math.abs(up.X) * sz.Y
                + math.abs(look.X) * sz.Z) * 0.5 + 1.2
            local halfZ = (math.abs(right.Z) * sz.X + math.abs(up.Z) * sz.Y
                + math.abs(look.Z) * sz.Z) * 0.5 + 1.2
            if math.abs(point.X - part.Position.X) < halfX
                and math.abs(point.Z - part.Position.Z) < halfZ then
                return part
            end
        end
    end
    return nil
end

-- Wall-aware dodge: the old version checked only destination floor and red color.
-- V3.3 rejects blocked straight routes, tries a 2-segment side path, and
-- can optionally cross blocking parts ONLY during a danger dodge.
local function rayParams(excludeEnemy)
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.RespectCanCollide = true
    params.IgnoreWater = true
    local ignore = {}
    if player.Character then ignore[#ignore + 1] = player.Character end
    if excludeEnemy then ignore[#ignore + 1] = excludeEnemy end
    params.FilterDescendantsInstances = ignore
    return params
end
local function groundBelow(point)
    local hit = workspace:Raycast(point + Vector3.new(0, 8, 0),
        Vector3.new(0, -24, 0), rayParams())
    if hit and hit.Normal.Y > 0.60 then return hit.Position end
    return nil
end
local function validDodgeGround(point)
    local ground = groundBelow(point)
    return ground and math.abs((point.Y - 2.8) - ground.Y) < 5 or false
end
local function clearTravelLine(a, b, excludeEnemy)
    local direction = b - a
    if direction.Magnitude < 1 then return true end
    local side = Vector3.new(-direction.Z, 0, direction.X)
    if side.Magnitude < 0.05 then side = Vector3.new(1,0,0) else side = side.Unit end
    local params = rayParams(excludeEnemy)
    -- Three torso-level rays approximating player clearance (not a full capsule cast).
    for _, offset in ipairs({0, 1.15, -1.15}) do
        local off = side * offset
        local origin = a + off
        local hit = workspace:Raycast(origin, b + off - origin, params)
        if hit and hit.Distance < direction.Magnitude - 0.7 then
            return false, hit.Instance
        end
    end
    return true
end
local function segmentCrossesRed(a, b)
    for i = 1, 7 do
        -- Once already inside the hazard, permit exiting, not passing back through it.
        local fraction = i / 7
        local point = a:Lerp(b, fraction)
        if i >= 3 and pointInsideRed(point) then return true end
    end
    return false
end
local function findSideRoute(from, destination, enemyModel)
    local travel = destination - from
    local flat = Vector3.new(travel.X, 0, travel.Z)
    if flat.Magnitude < 1 then return nil end
    local forward = flat.Unit
    local side = Vector3.new(-forward.Z, 0, forward.X)
    local best, bestDist
    for _, lateral in ipairs({4, 8, 12}) do
        for _, sideSign in ipairs({1,-1}) do
            for _, forwardStep in ipairs({0, 4, -4}) do
                local point = from + side * lateral * sideSign + forward * forwardStep
                if validDodgeGround(point) and not pointInsideRed(point)
                    and clearTravelLine(from, point, enemyModel)
                    and clearTravelLine(point, destination, enemyModel)
                    and not segmentCrossesRed(point, destination) then
                    local total = (point-from).Magnitude + (destination-point).Magnitude
                    if not bestDist or total < bestDist then best, bestDist = point, total end
                end
            end
        end
    end
    return best
end
-- Asynchronous PathfindingService fallback for winding corridors. It is
-- intentionally cached for one dodge, never computed every Heartbeat.
local pathRequestId = 0
local pathPending = false
local pathFailed = false
local pathWaypoints = nil
local pathIndex = 1
local function clearPath()
    pathRequestId = pathRequestId + 1
    pathPending = false
    pathFailed = false
    pathWaypoints = nil
    pathIndex = 1
end
local function requestPath(from, to, enemyModel)
    if pathPending then return end
    pathPending = true
    pathFailed = false
    pathRequestId = pathRequestId + 1
    local requestId = pathRequestId
    local fromPos, toPos = from, to
    task.delay(2.5, function()
        if pathPending and pathRequestId == requestId then
            pathRequestId = pathRequestId + 1
            pathPending = false
            pathFailed = true
            warn("[RHYE Hub DODGE] Wall-route planning timed out")
        end
    end)
    task.spawn(function()
        local ok, result = pcall(function()
            local path = PathfindingService:CreatePath({
                AgentRadius = 2, AgentHeight = 5,
                AgentCanJump = true, WaypointSpacing = 3
            })
            path:ComputeAsync(fromPos, toPos)
            if path.Status ~= Enum.PathStatus.Success then return nil end
            return path:GetWaypoints()
        end)
        if requestId ~= pathRequestId or not dungeonActive then return end
        pathPending = false
        local acceptable = ok and result and #result > 1
        if acceptable then
            -- Being inside the initial red marker is expected: exit from it.
            -- Only reject later path segments that return into the red zone.
            for index, step in ipairs(result) do
                local at = Vector3.new(step.Position.X, fromPos.Y, step.Position.Z)
                if index > 2 and (at-fromPos).Magnitude > 5 and pointInsideRed(at) then
                    acceptable = false
                    break
                end
            end
        end
        if acceptable then
            pathWaypoints = result
            pathIndex = 2
            pathFailed = false
        else
            pathFailed = true
        end
    end)
end
local function dodgeKey(p)
    return string.format("%d/%d", math.floor(p.X + 0.5), math.floor(p.Z + 0.5))
end
local function chooseDodgeGoal(root, enemyPart)
    local from = root.Position
    local direction = Vector3.new(enemyPart.Position.X - from.X, 0,
        enemyPart.Position.Z - from.Z)
    if direction.Magnitude < 0.2 then direction = root.CFrame.LookVector end
    direction = Vector3.new(direction.X, 0, direction.Z).Unit
    local side = Vector3.new(-direction.Z, 0, direction.X)
    local dirs = {side, -side, -direction,
        (side-direction*0.7).Unit, (-side-direction*0.7).Unit, direction}
    local best, score = nil, math.huge
    local fallback, fallbackScore = nil, math.huge
    for _, radius in ipairs({4, 6, 9, 12, 16, 20}) do
        for _, dir in ipairs(dirs) do
            local p = from + dir * radius
            p = Vector3.new(p.X, from.Y, p.Z)
            local flat = Vector3.new(p.X-enemyPart.Position.X,0,p.Z-enemyPart.Position.Z)
            if not dodgeFailed[dodgeKey(p)] and not pointInsideRed(p)
                and validDodgeGround(p) then
                local s = math.abs(flat.Magnitude-cfg.dungeonRange) * 1.0 + radius*0.20
                local open = clearTravelLine(from,p,enemyPart.Parent)
                local via = not open and radius <= 12
                    and findSideRoute(from,p,enemyPart.Parent) or nil
                if (open or via) and s < score then
                    best, score = {goal=p, via=via, noclip=false}, s
                end
                if s < fallbackScore then
                    fallback, fallbackScore = {goal=p,via=nil,noclip=true},s
                end
            end
        end
    end
    if best then return best end
    if cfg.dungeonDodgeNoclip then return fallback end
    return fallback and {goal=fallback.goal, via=nil, blocked=true} or nil
end
local function resetDodgeState()
    dodgeGoal = nil
    dodgeWaypoint = nil
    dodgeNoclipTravel = false
    dodgeRetry = 0
    dodgeFailed = {}
    dodgeProgressPosition = nil
    dodgeProgressAt = 0
    clearPath()
    setDodgeNoclip(false)
end
local function attemptAutoDodge(root, monsterPart, combatGoal, dt)
    if not cfg.dungeonAutoDodge then
        if dodgeGoal or noclipActive then resetDodgeState() end
        return false
    end
    local now = os.clock()
    refreshHazards(root.Position)
    local danger = pointInsideRed(root.Position) or pointInsideRed(combatGoal)
    if danger then
        if not dodgeGoal or pointInsideRed(dodgeGoal) then
            local option = chooseDodgeGoal(root, monsterPart)
            if not option then
                stopDungeon("No safe dodge spot - stopped")
                return true
            end
            dodgeGoal = option.goal
            dodgeWaypoint = option.via
            dodgeNoclipTravel = option.noclip or false
            if option.blocked then
                -- Do not keep pushing against a solid wall. Ask pathfinding
                -- for a longer route; Noclip remains OFF by default.
                requestPath(root.Position, dodgeGoal, monsterPart.Parent)
            end
            dodgeProgressPosition = root.Position
            dodgeProgressAt = now
            dodgeHoldUntil = now + 1.0
            dodgeCount = dodgeCount + 1
            if now - lastDodgeLog > 1.5 then
                print(string.format("[RHYE Hub DODGE] %s | hazards=%d | route=%s",
                    danger.Name, #nearbyHazards,
                    option.blocked and "PATHFIND" or (option.noclip and "NOCLIP" or "CLEAR")))
                lastDodgeLog = now
            end
        end
    elseif dodgeGoal and (now > dodgeHoldUntil or not pointInsideRed(root.Position)) then
        resetDodgeState()
        return false
    end
    if not dodgeGoal then return false end
    if pathFailed and not cfg.dungeonDodgeNoclip then
        stopDungeon("No wall-safe dodge route - stopped")
        return true
    end
    if pathPending and not cfg.dungeonDodgeNoclip then
        makeHover(root)
        hoverMover.Position = root.Position
        dungeonStatus("DODGE: checking wall-safe route", monsterPart.Parent.Name)
        return true
    end
    local travelGoal = dodgeWaypoint or dodgeGoal
    if pathWaypoints then
        if pathIndex <= #pathWaypoints then
            local p = pathWaypoints[pathIndex].Position
            travelGoal = Vector3.new(p.X, root.Position.Y, p.Z)
            if (root.Position - travelGoal).Magnitude < 2.2 then
                pathIndex = pathIndex + 1
            end
        else
            pathWaypoints = nil
        end
    end
    if dodgeWaypoint and (root.Position-dodgeWaypoint).Magnitude < 2.3 then
        dodgeWaypoint = nil
        travelGoal = dodgeGoal
    end
    if pathFailed and cfg.dungeonDodgeNoclip then
        dodgeNoclipTravel = true
    end
    if not dodgeNoclipTravel and not pathPending and not pathWaypoints
        and not clearTravelLine(root.Position,travelGoal,monsterPart.Parent) then
        if cfg.dungeonDodgeNoclip then
            dodgeNoclipTravel = true
        else
            requestPath(root.Position,dodgeGoal,monsterPart.Parent)
        end
    end
    if not dodgeNoclipTravel and not pathPending and not pathWaypoints
        and not clearTravelLine(root.Position,travelGoal,monsterPart.Parent) then
        -- Never push against a wall without an alternate route.
        makeHover(root)
        hoverMover.Position = root.Position
        dungeonStatus("Wall ahead - searching path", monsterPart.Parent.Name)
        return true
    end
    setDodgeNoclip(dodgeNoclipTravel and cfg.dungeonDodgeNoclip)
    if now - dodgeProgressAt > 1.0 then
        if (root.Position - (dodgeProgressPosition or root.Position)).Magnitude < 0.55
            and (root.Position - travelGoal).Magnitude > 2.1 then
            dodgeRetry = dodgeRetry + 1
            dodgeFailed[dodgeKey(dodgeGoal)] = true
            local option = chooseDodgeGoal(root,monsterPart)
            if option and dodgeRetry <= 3 then
                clearPath()
                dodgeGoal = option.goal
                dodgeWaypoint = option.via
                dodgeNoclipTravel = option.noclip or false
                if option.blocked then requestPath(root.Position,dodgeGoal,monsterPart.Parent) end
            else
                stopDungeon("Dodge blocked by wall - stopped safely")
                return true
            end
        end
        dodgeProgressPosition = root.Position
        dodgeProgressAt = now
    end
    approach(travelGoal,monsterPart.Position,dt,
        math.min(150,cfg.dungeonMoveSpeed*1.35))
    dungeonStatus(pathPending and "DODGE: planning around wall"
        or (dodgeNoclipTravel and "DODGE: optional noclip" or "DODGE: safe path"),
        string.format("%s | %d red | range %d | speed %d",
            monsterPart.Parent.Name,#nearbyHazards,cfg.dungeonRange,cfg.dungeonMoveSpeed))
    return true
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
        if attemptAutoDodge(root, part, goal, dt) then return end
        -- Do not ram solid walls during ordinary target following.
        local open = clearTravelLine(root.Position,goal,part.Parent)
        if not open then
            local via = findSideRoute(root.Position,goal,part.Parent)
            if via then
                approach(via,part.Position,dt)
                dungeonStatus("Following around obstacle", selected.model.Name)
            else
                makeHover(root)
                hoverMover.Position = root.Position
                dungeonStatus("Combat route blocked - change position", selected.model.Name)
            end
            return
        end
        approach(goal, part.Position, dt)
        local separation = (root.Position - part.Position).Magnitude
        dungeonStatus(selected.model.Name:lower():find("boss", 1, true)
            and "BOSS - low hover" or "Combat - low hover",
            string.format("%s | %.1f studs%s", selected.model.Name, separation,
                cfg.dungeonAutoDodge and (" | red zones: " .. #nearbyHazards) or ""))
        return
    end
    dungeonTarget = nil
    resetDodgeState()
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
    approach(goal, gatePart.Position, dt, cfg.dungeonMoveSpeed)
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
                    if not ok then warn("[RHYE Hub] gate:", tostring(err)) end
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
    resetDodgeState()
    nearbyHazards = {}
    lastHazardScan = -1e6
    dungeonStatus("Scanning nearby monsters", "Use game Auto Battle ON")
end)
listen(nextToggle.MouseButton1Click, function()
    cfg.dungeonAutoNext = not cfg.dungeonAutoNext
    nextToggle.Text = cfg.dungeonAutoNext and "NEXT: ON" or "NEXT: OFF"
    nextToggle.BackgroundColor3 = cfg.dungeonAutoNext and COLOR.greenDark or COLOR.card2
end)
listen(dodgeToggle.MouseButton1Click, function()
    cfg.dungeonAutoDodge = not cfg.dungeonAutoDodge
    resetDodgeState()
    dodgeHoldUntil = 0
    nearbyHazards = {}
    dodgeToggle.Text = cfg.dungeonAutoDodge and "DODGE: ON" or "DODGE: OFF"
    dodgeToggle.BackgroundColor3 = cfg.dungeonAutoDodge and COLOR.greenDark or COLOR.card2
    dungeonStatus(cfg.dungeonAutoDodge and "Auto Dodge enabled (red Parts only)"
        or "Auto Dodge disabled", "-")
end)
listen(noclipToggle.MouseButton1Click, function()
    cfg.dungeonDodgeNoclip = not cfg.dungeonDodgeNoclip
    noclipToggle.Text = cfg.dungeonDodgeNoclip
        and "NOCLIP (DODGE): ON" or "NOCLIP (DODGE): OFF"
    noclipToggle.BackgroundColor3 = cfg.dungeonDodgeNoclip and COLOR.greenDark or COLOR.card2
    if not cfg.dungeonDodgeNoclip then setDodgeNoclip(false) end
    dungeonStatus(cfg.dungeonDodgeNoclip
        and "Noclip enabled only during blocked dodge" or "Noclip disabled", "-")
end)
listen(workspace.DescendantAdded, function(obj)
    if obj:IsA("BasePart") then recentVisualParts[obj] = os.clock() end
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
    if now - lastMovementClock < 0.08 then return end
    local dt = now - lastMovementClock
    lastMovementClock = now
    local ok, err = pcall(flyStep, dt)
    if not ok then
        warn("[RHYE Hub Dungeon]", tostring(err))
        stopDungeon("Error - stopped safely")
    end
end)
nextToggle.Text = cfg.dungeonAutoNext and "NEXT: ON" or "NEXT: OFF"
nextToggle.BackgroundColor3 = cfg.dungeonAutoNext and COLOR.greenDark or COLOR.card2
dodgeToggle.Text = cfg.dungeonAutoDodge and "DODGE: ON" or "DODGE: OFF"
dodgeToggle.BackgroundColor3 = cfg.dungeonAutoDodge and COLOR.greenDark or COLOR.card2
noclipToggle.Text = cfg.dungeonDodgeNoclip and "NOCLIP (DODGE): ON" or "NOCLIP (DODGE): OFF"
noclipToggle.BackgroundColor3 = cfg.dungeonDodgeNoclip and COLOR.greenDark or COLOR.card2

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
    if globalEnv.__RHYEHubV3 == shutdown then globalEnv.__RHYEHubV3 = nil end
    if gui and gui.Parent then gui:Destroy() end
end
globalEnv.__RHYEHubV3 = shutdown
listen(close.MouseButton1Click, shutdown)
listen(gui.Destroying, shutdown)
updateToggles()
setPage("Main")
print("[RHYE Hub V3.3] Loaded. Keybind:", cfg.hotkey)
print("[RHYE Hub V3.3] Save config:", CONFIG_FILE)
print("[RHYE Hub V3.3] Wall-aware dodge, optional noclip only during dodge. Combat range server-limited.")
