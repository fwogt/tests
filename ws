-- Made by sskint & Demonware Team - Enhanced Pig Feeding & Cooking Automation

--// Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local LocalPlayer = Players.LocalPlayer
local Backpack = LocalPlayer.Backpack

--// Remotes
local CookingPotService_RE = ReplicatedStorage.GameEvents.CookingPotService_RE
local SubmitFoodService_RE = ReplicatedStorage.GameEvents.SubmitFoodService_RE
local Notification_RE = ReplicatedStorage.GameEvents.Notification

--// State
local autoCookEnabled = false
local autoFeedEnabled = false
local webhookURL = ""
local maxKG = 12
local blacklist = {}
local feedingInProgress = false
local sugarAppleCount = 0
local cookingPaused = false

--// Config save/load
local configFolder = "AutoCookFarm"
local configFile = "Config.json"
local function saveConfig()
    isfile(configFolder.."/"..configFile) or makefolder(configFolder)
    writefile(configFolder.."/"..configFile, HttpService:JSONEncode({
        webhookURL = webhookURL,
        autoCookEnabled = autoCookEnabled,
        autoFeedEnabled = autoFeedEnabled,
        maxKG = maxKG,
        blacklist = blacklist
    }))
end
local function loadConfig()
    if isfile(configFolder.."/"..configFile) then
        local data = HttpService:JSONDecode(readfile(configFolder.."/"..configFile))
        webhookURL = data.webhookURL or ""
        autoCookEnabled = data.autoCookEnabled or false
        autoFeedEnabled = data.autoFeedEnabled or false
        maxKG = data.maxKG or 12
        blacklist = data.blacklist or {}
    end
end
loadConfig()

--// Helpers
local function getWeightFromName(name)
    local kg = name:match("%[([%d%.]+)kg%]")
    return kg and tonumber(kg) or math.huge
end
local function hasBlacklistedMutation(name)
    for _, mutation in ipairs(blacklist) do
        if name:find(mutation) then return true end
    end
    return false
end
local function isFruit(tool)
    return tool:FindFirstChild("Item_Seed") ~= nil
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
        if item:IsA("Tool") and isFruit(item) and item.Name:lower():find("sugar apple") then
            local w = getWeightFromName(item.Name)
            if w <= maxKG and not hasBlacklistedMutation(item.Name) then
                table.insert(apples, {name = item.Name, weight = w})
            end
        end
    end
    table.sort(apples, function(a, b) return a.weight < b.weight end)
    return apples[1] and apples[1].name or nil
end
local function getFoodMatchingCraving(craving)
    craving = craving:lower()
    for _, item in ipairs(Backpack:GetChildren()) do
        if item:IsA("Tool") and item.Name:lower():find(craving) then
            return item.Name
        end
    end
    return nil
end

--// Webhook
local function sendWebhook(content)
    if webhookURL == "" then return end
    local payload = HttpService:JSONEncode({
        embeds = {{
            title = "Pig Reward",
            description = content,
            color = 65280
        }}
    })
    request({Url = webhookURL, Method = "POST", Headers = {["Content-Type"] = "application/json"}, Body = payload})
end

--// Event Listeners
CookingPotService_RE.OnClientEvent:Connect(function(action, plantName)
    if action == "PlantAdded" and plantName == "Sugar Apple" then
        sugarAppleCount += 1
        if sugarAppleCount >= 5 then
            CookingPotService_RE:FireServer("CookBest")
            sugarAppleCount = 0
        end
    end
end)

Notification_RE.OnClientEvent:Connect(function(message)
    local lowerMsg = message:lower()
    if lowerMsg:find("your") and lowerMsg:find("done cooking") then
        CookingPotService_RE:FireServer("GetFoodFromPot")
    elseif lowerMsg:find("rewarded") then
        sendWebhook(message)
        if feedingInProgress then
            feedingInProgress = false
            task.delay(5, function()
                cookingPaused = false
            end)
        end
    end
end)

--// Auto Cook Loop
task.spawn(function()
    while task.wait(1) do
        if autoCookEnabled and not cookingPaused then
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
end)

--// Auto Feed Loop
task.spawn(function()
    while task.wait(1) do
        if autoFeedEnabled and not feedingInProgress then
            local cravingTextLabel = workspace.CookingEventModel.PigChefFolder.Cravings
                .CravingThoughtBubblePart.CravingBillboard.BG.CravingTextLabel
            local craving = cravingTextLabel.Text:lower()
            if craving:find("smoothie") or craving:find("candyapple") then
                local foodName = getFoodMatchingCraving(craving)
                if foodName then
                    feedingInProgress = true
                    cookingPaused = true
                    equipToolByName(foodName)
                    SubmitFoodService_RE:FireServer("SubmitHeldFood")
                end
            end
        end
    end
end)

--// UI
local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()
local Window = Rayfield:CreateWindow({
    Name = "Auto Cook Farm | sskint & Demonware",
    LoadingTitle = "Auto Cook Farm",
    LoadingSubtitle = "by sskint & Demonware",
    ConfigurationSaving = {Enabled = false}
})
local MainTab = Window:CreateTab("Main", 4483362458)

MainTab:CreateToggle({
    Name = "Auto Cook Sugar Apples",
    CurrentValue = autoCookEnabled,
    Callback = function(v) autoCookEnabled = v saveConfig() end
})
MainTab:CreateToggle({
    Name = "Auto Feed Pig (Smoothie & CandyApple)",
    CurrentValue = autoFeedEnabled,
    Callback = function(v) autoFeedEnabled = v saveConfig() end
})
MainTab:CreateSlider({
    Name = "Max KG for Sugar Apples",
    Range = {1, 50},
    Increment = 1,
    Suffix = "KG",
    CurrentValue = maxKG,
    Callback = function(v) maxKG = v saveConfig() end
})
MainTab:CreateTextbox({
    Name = "Webhook URL",
    PlaceholderText = "Enter Discord Webhook URL",
    RemoveTextAfterFocusLost = false,
    Callback = function(v) webhookURL = v saveConfig() end
})
MainTab:CreateButton({
    Name = "Test Webhook",
    Callback = function() sendWebhook("Test message from Auto Cook Farm!") end
})
