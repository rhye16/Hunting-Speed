
-- Hunting Together RPG
-- Training Dummy Stats Monitor v2
-- Read only / No game modification

local dummy = workspace:FindFirstChild("TrainingDummy")

if not dummy then
    warn("[Monitor] TrainingDummy not found")
    return
end

local nameplate = dummy:FindFirstChild("Nameplate", true)

if not nameplate then
    warn("[Monitor] Nameplate not found")
    return
end

print("===== DUMMY STATS MONITOR =====")
print("Monitoring:", nameplate:GetFullName())

local connections = {}
local watched = {}
local active = true
local changeCount = 0

local function clean(value)
    return tostring(value):gsub("\n", " | ")
end

local function isTextObject(obj)
    return obj:IsA("TextLabel")
        or obj:IsA("TextButton")
        or obj:IsA("TextBox")
end

local function watch(obj)
    if watched[obj] or not isTextObject(obj) then
        return
    end

    watched[obj] = true

    print("[FOUND]", obj:GetFullName())
    print("[TEXT]", clean(obj.Text))

    local lastPrint = 0

    local connection =
        obj:GetPropertyChangedSignal("Text"):Connect(function()

        if not active then
            return
        end

        local now = os.clock()

        if now - lastPrint < 0.5 then
            return
        end

        lastPrint = now
        changeCount = changeCount + 1

        print("[UPDATED]", obj:GetFullName())
        print("[VALUE]", clean(obj.Text))
    end)

    table.insert(connections, connection)
end

watch(nameplate)

for _, obj in ipairs(nameplate:GetDescendants()) do
    watch(obj)
end

table.insert(connections,
    nameplate.DescendantAdded:Connect(function(obj)
        watch(obj)
    end)
)

print("[Monitor] Attack the dummy now!")
print("[Monitor] Recording for 30 seconds")

task.delay(30, function()
    active = false

    for _, connection in ipairs(connections) do
        connection:Disconnect()
    end

    print("===== MONITOR FINISHED =====")
    print("Text changes:", changeCount)
end)
