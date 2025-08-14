-- Made by sskint & Demonware Team | Updated with Smart Pot, Auto Feed, Webhook System

--// Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer
local Backpack = LocalPlayer.Backpack

--// Remotes
local CookingPotService_RE = ReplicatedStorage.GameEvents.CookingPotService_RE
local SubmitFoodService_RE = ReplicatedStorage.GameEvents.SubmitFoodService_RE
local Notification_RE = ReplicatedStorage.GameEvents.Notification

--// State variables
local autoCookEnabled = false
local autoClaimEnabled = false
local autoFeedEnabled = false
local webhookURL = ""
local blacklist = {}
local maxKG = 12

-- Pot tracking
local sugarAppleCount = 0
local waitingToCook = false

--// Helper Functions
local function getWeightFromName(name)
    local kg = name:match("%[([%d%.]+)kg%]")
    return kg and tonumber(kg) or math.huge
end

local function hasBlacklistedMutation(name)
    for _, mutation in ipairs(blacklist) do
        if name:find(mutation) then
            return true
        end
    end
    return false
end

local function equipToolByName(toolName)
    local tool = Backpack:FindFirstChild(toolName)
    if tool then
        LocalPlayer.Character.Humanoid:EquipTool(tool)
        task.wait(0.2)
        return true
    end
    return false
end

local function getLowestKGSugarApple()
    local apples = {}
    for _, item in ipairs(Backpack:GetChildren()) do
        if item:IsA("Tool") and item.Name:lower():find("sugar apple") then
            local w = getWeightFromName(item.Name)
            if w <= maxKG and not hasBlacklistedMutation(item.Name) then
                table.insert(apples, {name = item.Name, weight = w})
            end
        end
    end
    table.sort(apples, function(a, b) return a.weight < b.weight end)
    return apples[1] and apples[1].name or nil
end

local function getItemsByName(partial)
    local items = {}
    for _, item in ipairs(Backpack:GetChildren()) do
        if item:IsA("Tool") and item.Name:lower():find(partial:lower()) then
            table.insert(items, item.Name)
        end
    end
    return items
end

local function sendWebhook(msg)
    if webhookURL ~= "" then
        local payload = game:GetService("HttpService"):JSONEncode({
            embeds = {{
                title = "Game Notification",
                description = msg,
                color = 65280
            }}
        })
        request({
            Url = webhookURL,
            Method = "POST",
            Headers = {["Content-Type"] = "application/json"},
            Body = payload
        })
    end
end

--// Automation Loops
task.spawn(function()
    while task.wait(1) do
        if autoCookEnabled then
            if not waitingToCook then
                for i = 1, 5 do
                    local appleName = getLowestKGSugarApple()
                    if appleName then
                        if equipToolByName(appleName) then
                            CookingPotService_RE:FireServer("SubmitHeldPlant")
                            task.wait(0.3)
                        end
                    end
                end
            end
        end
    end
end)

task.spawn(function()
    while task.wait(1) do
        if autoFeedEnabled then
            local cravingTextLabel = workspace.CookingEventModel.PigChefFolder.Cravings
                .CravingThoughtBubblePart.CravingBillboard.BG.CravingTextLabel
            local craving = cravingTextLabel.Text:lower()

            local foodList = {}
            if craving:find("smoothie") then
                foodList = getItemsByName("smoothie")
            elseif craving:find("candyapple") then
                foodList = getItemsByName("candyapple")
            end

            for _, foodName in ipairs(foodList) do
                if equipToolByName(foodName) then
                    SubmitFoodService_RE:FireServer("SubmitHeldFood")
                    task.wait(1)
                end
            end
        end
    end
end)

--// Pot Fill Tracking
CookingPotService_RE.OnClientEvent:Connect(function(action, plantName)
    if action == "PlantAdded" and plantName:lower():find("sugar apple") then
        sugarAppleCount = sugarAppleCount + 1
        if sugarAppleCount >= 5 then
            waitingToCook = true
            task.delay(0.5, function()
                CookingPotService_RE:FireServer("CookBest")
                sugarAppleCount = 0
                waitingToCook = false
            end)
        end
    end
end)

--// Cooking Done Detection
Notification_RE.OnClientEvent:Connect(function(message)
    local lowerMsg = message:lower()
    if lowerMsg:find("done cooking") then
        if autoClaimEnabled then
            CookingPotService_RE:FireServer("GetFoodFromPot")
        end
    end
    if lowerMsg:find("rewarded") then
        sendWebhook(message)
    end
end)

--// Rayfield UI
local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

local Window = Rayfield:CreateWindow({
    Name = "Auto Cook Farm | sskint & Demonware",
    LoadingTitle = "Auto Cook Farm",
    LoadingSubtitle = "by sskint & Demonware",
    ConfigurationSaving = {
        Enabled = true,
        FolderName = "AutoCookFarm",
        FileName = "Config"
    },
    Discord = {Enabled = false},
    KeySystem = false
})

local MainTab = Window:CreateTab("Main", 4483362458)

MainTab:CreateToggle({
    Name = "Auto Cook Sugar Apples",
    CurrentValue = false,
    Flag = "AutoCookToggle",
    Callback = function(v) autoCookEnabled = v end
})

MainTab:CreateToggle({
    Name = "Auto Claim Food",
    CurrentValue = false,
    Flag = "AutoClaimToggle",
    Callback = function(v) autoClaimEnabled = v end
})

MainTab:CreateSlider({
    Name = "Max KG for Sugar Apples",
    Range = {1, 50},
    Increment = 1,
    Suffix = "KG",
    CurrentValue = 12,
    Flag = "MaxKGSlider",
    Callback = function(v) maxKG = v end
})

MainTab:CreateDropdown({
    Name = "Blacklist Mutations",
    Options = {},
    MultipleOptions = true,
    Flag = "BlacklistDropdown",
    Callback = function(v) blacklist = v end
})

MainTab:CreateToggle({
    Name = "Auto Feed Pig (Smoothie/CandyApple)",
    CurrentValue = false,
    Flag = "AutoFeedToggle",
    Callback = function(v) autoFeedEnabled = v end
})

MainTab:CreateInput({
    Name = "Discord Webhook URL",
    PlaceholderText = "Enter your Discord webhook here...",
    RemoveTextAfterFocusLost = false,
    CurrentValue = webhookURL,
    Flag = "WebhookInput",
    Callback = function(v) webhookURL = v end
})

MainTab:CreateButton({
    Name = "Test Webhook",
    Callback = function()
        if webhookURL == nil or webhookURL == "" then
            warn("Webhook URL is empty!")
            return
        end
        sendWebhook("✅ Webhook test successful! If you see this in Discord, it works.")
    end
})
