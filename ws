--// Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local LocalPlayer = Players.LocalPlayer
local Backpack = LocalPlayer.Backpack

--// Remotes
local CookingPotService_RE = ReplicatedStorage.GameEvents.CookingPotService_RE
local SubmitFoodService_RE = ReplicatedStorage.GameEvents.SubmitFoodService_RE
local Notification = ReplicatedStorage.GameEvents.Notification

--// State
local autoCookEnabled = false
local autoClaimEnabled = false
local autoFeedEnabled = false
local webhookURL = ""
local maxKG = 12
local blacklist = {}
local sugarAppleCount = 0

--// Mutations Table
local Mutations = {
    Amber = 10, AncientAmber = 50, Aurora = 90, Bloodlit = 5, Burnt = 4,
    Celestial = 120, Ceramic = 30, Chakra = 15, Chilled = 2, Choc = 2,
    Clay = 5, Cloudtouched = 5, Cooked = 10, Dawnbound = 150, Disco = 125,
    Drenched = 5, Eclipsed = 15, Enlightened = 35, FoxfireChakra = 90,
    Friendbound = 70, Frozen = 10, Galactic = 120, Gold = 20, Heavenly = 5,
    HoneyGlazed = 5, Infected = 75, Molten = 25, Moonlit = 2, Meteoric = 125,
    OldAmber = 20, Paradisal = 100, Plasma = 5, Pollinated = 3, Radioactive = 80,
    Rainbow = 50, Sandy = 3, Shocked = 100, Sundried = 85, Tempestuous = 19,
    Toxic = 12, Tranquil = 20, Twisted = 5, Verdant = 5, Voidtouched = 135,
    Wet = 2, Windstruck = 2, Wiltproof = 4, Zombified = 25
}

--// Helpers
local function sendWebhook(content)
    if webhookURL == nil or webhookURL == "" then return end
    local data = HttpService:JSONEncode({
        embeds = {{
            title = "Game Notification",
            description = content,
            color = 16753920
        }}
    })
    request = http_request or request or HttpPost or syn.request
    if request then
        request({
            Url = webhookURL,
            Method = "POST",
            Headers = {["Content-Type"] = "application/json"},
            Body = data
        })
    end
end

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

local function getFoodMatchingCraving(craving)
    for _, item in ipairs(Backpack:GetChildren()) do
        if item:IsA("Tool") and item.Name:lower():find(craving:lower()) then
            return item.Name
        end
    end
    return nil
end

--// Automation Loops
task.spawn(function()
    while task.wait(1) do
        if autoCookEnabled and sugarAppleCount >= 5 then
            CookingPotService_RE:FireServer("CookBest")
            sugarAppleCount = 0
        elseif autoCookEnabled then
            local appleName = getLowestKGSugarApple()
            if appleName then
                if equipToolByName(appleName) then
                    CookingPotService_RE:FireServer("SubmitHeldPlant")
                end
            end
        end
    end
end)

task.spawn(function()
    while task.wait(1) do
        if autoClaimEnabled then
            CookingPotService_RE:FireServer("GetFoodFromPot")
        end
    end
end)

task.spawn(function()
    while task.wait(1) do
        if autoFeedEnabled then
            local cravingTextLabel = workspace.CookingEventModel.PigChefFolder.Cravings
                .CravingThoughtBubblePart.CravingBillboard.BG.CravingTextLabel
            local craving = cravingTextLabel.Text
            local foodName = getFoodMatchingCraving(craving)
            if foodName then
                if equipToolByName(foodName) then
                    SubmitFoodService_RE:FireServer("SubmitHeldFood")
                end
            end
        end
    end
end)

--// Remote Listeners
CookingPotService_RE.OnClientEvent:Connect(function(event, plantName)
    if event == "PlantAdded" and plantName == "Sugar Apple" then
        sugarAppleCount = sugarAppleCount + 1
    end
end)

Notification.OnClientEvent:Connect(function(msg)
    local cleanMsg = msg:gsub("<.->", "") -- strip HTML tags
    if cleanMsg:lower():find("soup is done cooking") or cleanMsg:lower():find("is done cooking") then
        CookingPotService_RE:FireServer("GetFoodFromPot")
    elseif cleanMsg:lower():find("rewarded") then
        sendWebhook(cleanMsg)
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
    Name = "Auto Claim Pot",
    CurrentValue = false,
    Flag = "AutoClaimToggle",
    Callback = function(v) autoClaimEnabled = v end
})

MainTab:CreateToggle({
    Name = "Auto Feed Pig (Smoothie / CandyApple)",
    CurrentValue = false,
    Flag = "AutoFeedToggle",
    Callback = function(v) autoFeedEnabled = v end
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
    Options = table.keys(Mutations),
    MultipleOptions = true,
    Flag = "BlacklistDropdown",
    Callback = function(v) blacklist = v end
})

MainTab:CreateInput({
    Name = "Webhook URL",
    PlaceholderText = "Enter Discord Webhook",
    RemoveTextAfterFocusLost = false,
    Flag = "WebhookInput",
    Callback = function(v) webhookURL = v end
})

MainTab:CreateButton({
    Name = "Test Webhook",
    Callback = function()
        sendWebhook("✅ Webhook test successful!")
    end
})
