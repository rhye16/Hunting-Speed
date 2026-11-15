
-- Hunting Together RPG
-- Training Dummy UI Inspector
-- Read-only: tidak mengubah game

local Players = game:GetService("Players")
local player = Players.LocalPlayer

if not player then
    warn("[Dummy Inspector] LocalPlayer unavailable")
    return
end

local count = 0

local function scan(root)
    for _, obj in ipairs(root:GetDescendants()) do
        if obj:IsA("TextLabel")
            or obj:IsA("TextButton") then

            local value = tostring(obj.Text)
            local lower = string.lower(value)

            if string.find(lower, "total damage", 1, true)
                or string.find(lower, "dps", 1, true) then

                count = count + 1

                print("[DUMMY UI FOUND]")
                print("Path:", obj:GetFullName())
                print("Text:", value)
                print("-----------------------")
            end
        end
    end
end

scan(workspace)

local playerGui = player:FindFirstChild("PlayerGui")

if playerGui then
    scan(playerGui)
end

print("[Dummy Inspector] Found:", count)
