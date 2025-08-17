
local ANIME_FIGHTERS_PLACE_ID = 6299805723
if game.PlaceId ~= ANIME_FIGHTERS_PLACE_ID then 
    return warn("Wrong game! This script is for Anime Fighters Simulator only.") 
end


local Services = {
    ReplicatedStorage = game:GetService("ReplicatedStorage"),
    Players = game:GetService("Players"),
    RunService = game:GetService("RunService"),
    UserInputService = game:GetService("UserInputService"),
    TweenService = game:GetService("TweenService"),
    VirtualInputManager = game:GetService("VirtualInputManager"),
    VirtualUser = game:GetService("VirtualUser"),
    Workspace = game:GetService("Workspace"),
    HttpService = game:GetService("HttpService")
}


local player = Services.Players.LocalPlayer
local tweenService = Services.TweenService
local virtualInputManager = Services.VirtualInputManager

local Player = Services.Players.LocalPlayer
local Character = Player.Character or Player.CharacterAdded:Wait()
local HumanoidRootPart = Character:WaitForChild("HumanoidRootPart")
local PlayerGui = Player.PlayerGui


local Fluent = loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()


local ScriptData = {
    disabled = false,
    selectedWorld = nil,
    selectedMob = nil,
    selectedEgg = nil,
    selectedFuse = nil,
    farmDistance = 100,
    loopSpeed = 0.1,
    maxRetries = 3,
    cooldownTime = 0.5,
    lastAction = 0,
    artiSelected = nil,
    connections = {},
    mobs = {},
    worlds = {},
    eggs = {},
    farmingMobs = {}
}

local Toggles = {
    autoEgg = false,
    autoEggCurrent = false,
    autoFarm = false,
    autoFarmAll = false,
    autoFarmDistance = false,
    autoCollect = false,
    autoRaid = false,
    autoTrial = false,
    autoDefense = false,
    autoQuest = false,
    autoFuse = false,
    antiAfk = false,
    hidePets = false
}

-- Remote/Bindable References
local RemoteEvents = {
    Remote = Services.ReplicatedStorage:WaitForChild("Remote"),
    Bindable = Services.ReplicatedStorage:WaitForChild("Bindable", 5)
}

-- Module Requirements (with error handling)
local Modules = {}
local function safeRequire(path, name)
    local success, result = pcall(function()
        return require(path)
    end)
    if success then
        Modules[name] = result
    else
        warn(string.format("Failed to load module %s: %s", name, tostring(result)))
    end
end

-- Load essential modules
if Services.ReplicatedStorage:FindFirstChild("ModuleScripts") then
    local moduleScripts = Services.ReplicatedStorage.ModuleScripts
    safeRequire(moduleScripts:FindFirstChild("StatCalc"), "StatCalc")
    safeRequire(moduleScripts:FindFirstChild("NumToString"), "NumToString")
    safeRequire(moduleScripts:FindFirstChild("PetStats"), "PetStats")
    safeRequire(moduleScripts:FindFirstChild("EggStats"), "EggStats")
    safeRequire(moduleScripts:FindFirstChild("WorldData"), "WorldData")
    safeRequire(moduleScripts:FindFirstChild("ConfigValues"), "ConfigValues")
    safeRequire(moduleScripts:FindFirstChild("LocalDairebStore"), "LocalDairebStore")
end

-- Utility Functions
local Utils = {}

function Utils.wait(duration)
    local startTime = tick()
    while tick() - startTime < duration and Services.RunService.Heartbeat:Wait() do end
end

function Utils.teleportToPosition(targetCFrame)
    if not targetCFrame then return false end
    
    local currentTime = tick()
    if currentTime - ScriptData.lastAction < ScriptData.cooldownTime then 
        return false 
    end
    ScriptData.lastAction = currentTime
    
    local distance = (HumanoidRootPart.Position - targetCFrame.Position).Magnitude
    if distance < 10 then return true end
    
    HumanoidRootPart.CFrame = targetCFrame
    return true
end

function Utils.getDistance(pos1, pos2)
    return (pos1 - pos2).Magnitude
end

function Utils.getWorlds()
    local worldList = {}
    local worldsFolder = Services.Workspace:FindFirstChild("Worlds")
    if worldsFolder then
        for _, world in ipairs(worldsFolder:GetChildren()) do
            if world:IsA("Model") or world:IsA("Folder") then
                table.insert(worldList, world.Name)
            end
        end
    end
    table.sort(worldList)
    return worldList
end

function Utils.getMobs()
    local mobList = {}
    local currentWorld = Player.World and Player.World.Value
    if currentWorld then
        local worldFolder = Services.Workspace.Worlds:FindFirstChild(currentWorld)
        if worldFolder and worldFolder:FindFirstChild("Enemies") then
            for _, enemy in ipairs(worldFolder.Enemies:GetChildren()) do
                local displayName = enemy:FindFirstChild("DisplayName")
                if displayName and not table.find(mobList, displayName.Value) then
                    table.insert(mobList, displayName.Value)
                end
            end
        end
    end
    return mobList
end

function Utils.getMobsInDistance(distance)
    local mobsInRange = {}
    local currentWorld = Player.World and Player.World.Value
    if not currentWorld or not HumanoidRootPart then return mobsInRange end
    
    local worldFolder = Services.Workspace.Worlds:FindFirstChild(currentWorld)
    if worldFolder and worldFolder:FindFirstChild("Enemies") then
        for _, enemy in ipairs(worldFolder.Enemies:GetChildren()) do
            local humanoidRootPart = enemy:FindFirstChild("HumanoidRootPart")
            local displayName = enemy:FindFirstChild("DisplayName")
            local attackers = enemy:FindFirstChild("Attackers")
            
            if humanoidRootPart and displayName and attackers then
                local dist = Utils.getDistance(HumanoidRootPart.Position, humanoidRootPart.Position)
                if dist <= distance then
                    table.insert(mobsInRange, {
                        enemy = enemy,
                        distance = dist,
                        name = displayName.Value
                    })
                end
            end
        end
    end
    
    -- Sort by distance (closest first)
    table.sort(mobsInRange, function(a, b)
        return a.distance < b.distance
    end)
    
    return mobsInRange
end

function Utils.getEggs()
    local eggList = {}
    if Modules.EggStats then
        for eggName, info in pairs(Modules.EggStats) do
            if info.Currency ~= "Robux" and not info.Hidden then
                local displayText = string.format("%s (%s)", info.DisplayName or eggName, eggName)
                table.insert(eggList, displayText)
            end
        end
    end
    return eggList
end

function Utils.getPets()
    if Modules.LocalDairebStore then
        local store = Modules.LocalDairebStore
        local gameData = store.GetStoreProxy("GameData")
        return gameData:GetData("Pets") or {}
    end
    return {}
end

function Utils.equipArtifact(artifactName)
    if not artifactName then return false end
    
    local success, result = pcall(function()
        local args = {artifactName, "CurrentSecondArtefact"}
        RemoteEvents.Remote:FindFirstChild("EquipArtefact"):FireServer(unpack(args))
        return true
    end)
    
    return success
end

-- Core Functions
local Core = {}

function Core.openEgg(eggName, teleport)
    if ScriptData.disabled then return false end
    
    local attempts = 0
    local success = false
    
    while attempts < ScriptData.maxRetries and not success do
        local openSuccess, result = pcall(function()
            -- Find egg and teleport if needed
            if teleport and eggName then
                local eggModel = Services.Workspace.Worlds:FindFirstChild(eggName .. "Egg")
                if eggModel and Utils.teleportToPosition(eggModel:GetPivot()) then
                    Utils.wait(0.3)
                end
            end
            
            -- Attempt to open egg
            local remote = RemoteEvents.Remote:FindFirstChild("AttemptMultiOpen")
            if remote then
                remote:FireServer(eggName)
                return true
            end
            return false
        end)
        
        if openSuccess and result then
            success = true
        else
            attempts = attempts + 1
            if attempts < ScriptData.maxRetries then
                Utils.wait(0.1)
            end
        end
    end
    
    return success
end

function Core.farmMob(mobName)
    if ScriptData.disabled then return false end
    
    local currentWorld = Player.World and Player.World.Value
    if not currentWorld then return false end
    
    local worldFolder = Services.Workspace.Worlds:FindFirstChild(currentWorld)
    if not worldFolder then return false end
    
    local enemies = worldFolder:FindFirstChild("Enemies")
    if not enemies then return false end
    
    for _, enemy in ipairs(enemies:GetChildren()) do
        local displayName = enemy:FindFirstChild("DisplayName")
        local humanoidRootPart = enemy:FindFirstChild("HumanoidRootPart")
        local attackers = enemy:FindFirstChild("Attackers")
        
        if displayName and displayName.Value == mobName and humanoidRootPart and attackers then
            -- Move to enemy
            Utils.teleportToPosition(humanoidRootPart.CFrame)
            
            -- Send pets to attack
            local success, result = pcall(function()
                if RemoteEvents.Bindable and RemoteEvents.Bindable:FindFirstChild("SendPet") then
                    RemoteEvents.Bindable.SendPet:Fire(enemy, true)
                end
            end)
            
            return success
        end
    end
    
    return false
end

function Core.farmAllMobsInDistance()
    if ScriptData.disabled or not Toggles.autoFarmDistance then return end
    
    local mobsInRange = Utils.getMobsInDistance(ScriptData.farmDistance)
    
    for _, mobData in ipairs(mobsInRange) do
        if not Toggles.autoFarmDistance or ScriptData.disabled then break end
        
        local enemy = mobData.enemy
        local success, result = pcall(function()
            -- Send pets to attack without moving character
            if RemoteEvents.Bindable and RemoteEvents.Bindable:FindFirstChild("SendPet") then
                RemoteEvents.Bindable.SendPet:Fire(enemy, true)
            end
        end)
        
        if success then
            -- Add to farming list for tracking
            ScriptData.farmingMobs[enemy] = true
        end
    end
end

function Core.collectDrops()
    if ScriptData.disabled then return end
    
    pcall(function()
        local effects = Services.Workspace:FindFirstChild("Effects")
        if effects then
            for _, effect in ipairs(effects:GetDescendants()) do
                if effect.Name == "Base" and effect:IsA("BasePart") then
                    effect.CFrame = HumanoidRootPart.CFrame
                end
            end
        end
    end)
end

function Core.autoFuse()
    if ScriptData.disabled or not ScriptData.selectedFuse then return false end
    
    local pets = Utils.getPets()
    local petToFuse = nil
    local fuseablePets = {}
    
    -- Find the selected pet to fuse into
    for _, pet in pairs(pets) do
        if tostring(pet.UID) == ScriptData.selectedFuse then
            petToFuse = pet.UID
            break
        end
    end
    
    if not petToFuse then return false end
    
    -- Get fuseable pets (exclude equipped pets and special rarities)
    local equippedPets = {}
    for _, petObj in ipairs(Player.Pets:GetChildren()) do
        if petObj.Value and petObj.Value.Data and petObj.Value.Data.UID then
            equippedPets[petObj.Value.Data.UID.Value] = true
        end
    end
    
    for _, pet in pairs(pets) do
        if not equippedPets[pet.UID] and pet.UID ~= petToFuse then
            -- Add logic to exclude special rarities if needed
            table.insert(fuseablePets, pet.UID)
        end
    end
    
    if #fuseablePets > 0 then
        local success, result = pcall(function()
            RemoteEvents.Remote:FindFirstChild("FeedPets"):FireServer(fuseablePets, petToFuse)
            return true
        end)
        return success
    end
    
    return false
end

-- Anti-AFK
function Core.initAntiAfk()
    if ScriptData.connections.antiAfk then return end
    
    ScriptData.connections.antiAfk = Player.Idled:Connect(function()
        Services.VirtualUser:Button2Down(Vector2.new(0, 0), Services.Workspace.CurrentCamera.CFrame)
        task.wait(1)
        Services.VirtualUser:Button2Up(Vector2.new(0, 0), Services.Workspace.CurrentCamera.CFrame)
    end)
end

-- Additional Features from OTIMOS
local Advanced = {}

function Advanced.autoRaid()
    if ScriptData.disabled or Player.World.Value ~= "Raid" then return end
    
    local raidData = Services.Workspace.Worlds.Raid.RaidData
    local enemies = Services.Workspace.Worlds.Raid.Enemies
    
    for _, enemy in ipairs(enemies:GetChildren()) do
        if enemy:FindFirstChild("HumanoidRootPart") and enemy:FindFirstChild("Attackers") then
            pcall(function()
                Utils.teleportToPosition(enemy.HumanoidRootPart.CFrame)
                if RemoteEvents.Bindable and RemoteEvents.Bindable:FindFirstChild("SendPet") then
                    RemoteEvents.Bindable.SendPet:Fire(enemy, true)
                end
            end)
        end
    end
end

function Advanced.autoTrial()
    if ScriptData.disabled or Player.World.Value ~= "Tower" then return end
    
    local enemies = Services.Workspace.Worlds.Tower.Enemies
    for _, enemy in ipairs(enemies:GetChildren()) do
        if enemy:FindFirstChild("HumanoidRootPart") and enemy:FindFirstChild("Attackers") then
            pcall(function()
                Utils.teleportToPosition(enemy.HumanoidRootPart.CFrame)
                if RemoteEvents.Bindable and RemoteEvents.Bindable:FindFirstChild("SendPet") then
                    RemoteEvents.Bindable.SendPet:Fire(enemy, true)
                end
            end)
        end
    end
end

function Advanced.autoQuest()
    if ScriptData.disabled then return end
    
    local currentWorld = Player.World and Player.World.Value
    if currentWorld then
        pcall(function()
            local npc = Services.Workspace.Worlds[currentWorld]:FindFirstChild(currentWorld)
            if npc then
                RemoteEvents.Remote:FindFirstChild("StartQuest"):FireServer(npc)
                RemoteEvents.Remote:FindFirstChild("FinishQuest"):FireServer(npc)
                RemoteEvents.Remote:FindFirstChild("FinishQuestline"):FireServer(npc)
            end
        end)
    end
end

-- Create Fluent UI
local function createFluentUI()
    local Window = Fluent:CreateWindow({
        Title = "Enhanced AFS Script " .. tostring(math.random(1000, 9999)),
        SubTitle = "by Enhanced Team",
        TabWidth = 160,
        Size = UDim2.fromOffset(580, 460),
        Acrylic = true,
        Theme = "Dark",
        MinimizeKey = Enum.KeyCode.LeftControl
    })
    
    -- Create Tabs
    local Tabs = {
        Main = Window:AddTab({ Title = "Main", Icon = "home" }),
        Farming = Window:AddTab({ Title = "Farming", Icon = "zap" }),
        Advanced = Window:AddTab({ Title = "Advanced", Icon = "settings" }),
        Arte = Window:AddTab({ Title = "Artifacts", Icon = "" }),
        Misc = Window:AddTab({ Title = "Misc", Icon = "more-horizontal" })
    }
    
    local Options = Fluent.Options
    

    do
        Tabs.Main:AddParagraph({
            Title = "Status",
            Content = "Script loaded successfully! Ready to farm."
        })
        
        local worldDropdown = Tabs.Main:AddDropdown("WorldSelect", {
            Title = "Select World",
            Values = Utils.getWorlds(),
            Multi = false,
            Default = ""
        })
        
        worldDropdown:OnChanged(function(Value)
            ScriptData.selectedWorld = Value
        end)
        
        local autoEggToggle = Tabs.Main:AddToggle("AutoEgg", {
            Title = "Auto Open Egg",
            Default = false
        })
        
        autoEggToggle:OnChanged(function(Value)
            Toggles.autoEgg = Value
            if Value then
                Toggles.autoEggCurrent = false
                Options.AutoEggCurrent:SetValue(false)
            end
        end)
        
        local autoEggCurrentToggle = Tabs.Main:AddToggle("AutoEggCurrent", {
            Title = "Auto Open Egg (Current World)",
            Default = false
        })
        
        autoEggCurrentToggle:OnChanged(function(Value)
            Toggles.autoEggCurrent = Value
            if Value then
                Toggles.autoEgg = false
                Options.AutoEgg:SetValue(false)
            end
        end)
        
        Tabs.Main:AddButton({
            Title = "Refresh Worlds",
            Description = "Update world list",
            Callback = function()
                ScriptData.worlds = Utils.getWorlds()
                Options.WorldSelect:SetValues(ScriptData.worlds)
                Fluent:Notify({
                    Title = "Updated",
                    Content = "World list refreshed!",
                    Duration = 3
                })
            end
        })
        
        Tabs.Main:AddButton({
            Title = "TP to Selected World",
            Description = "Teleport to selected world",
            Callback = function()
                if ScriptData.selectedWorld and ScriptData.selectedWorld ~= "" then
                    local success, result = pcall(function()
                        RemoteEvents.Remote.AttemptTravel:InvokeServer(ScriptData.selectedWorld)
                        if Services.Workspace.Worlds:FindFirstChild(ScriptData.selectedWorld) then
                            local spawn = Services.Workspace.Worlds[ScriptData.selectedWorld].Spawns.SpawnLocation
                            HumanoidRootPart.CFrame = spawn.CFrame + Vector3.new(0, 5, 0)
                        end
                    end)
                    if success then
                        Fluent:Notify({
                            Title = "Success",
                            Content = "Teleported to " .. ScriptData.selectedWorld,
                            Duration = 3
                        })
                    end
                else
                    Fluent:Notify({
                        Title = "Error",
                        Content = "No world selected!",
                        Duration = 3
                    })
                end
            end
        })
    end
    
    -- Farming Tab
    do
        local mobDropdown = Tabs.Farming:AddDropdown("MobSelect", {
            Title = "Select Mob",
            Values = Utils.getMobs(),
            Multi = false,
            Default = ""
        })
        
        mobDropdown:OnChanged(function(Value)
            ScriptData.selectedMob = Value
        end)
        
        
      Tabs.Farming:AddButton({
            Title = "Refresh Mobs",
            Description = "Update mob list for current world",
            Callback = function()
                ScriptData.mobs = Utils.getMobs()
                Options.MobSelect:SetValues(ScriptData.mobs)
                Fluent:Notify({
                    Title = "Updated",
                    Content = string.format("Found %d mobs in current world", #ScriptData.mobs),
                    Duration = 3
                })
            end
        })
        
        local autoFarmToggle = Tabs.Farming:AddToggle("AutoFarm", {
            Title = "Auto Farm Selected Mob",
            Default = false
        })
        
        autoFarmToggle:OnChanged(function(Value)
            Toggles.autoFarm = Value
            if Value then
                Toggles.autoFarmDistance = false
                Options.AutoFarmDistance:SetValue(false)
            end
        end)
        
        -- New Distance Farm Feature
        local farmDistanceSlider = Tabs.Farming:AddSlider("FarmDistance", {
            Title = "Farm Distance",
            Description = "Distance to farm mobs around you",
            Default = 100,
            Min = 50,
            Max = 500,
            Rounding = 0
        })
        
        farmDistanceSlider:OnChanged(function(Value)
            ScriptData.farmDistance = Value
        end)
        
        local autoFarmDistanceToggle = Tabs.Farming:AddToggle("AutoFarmDistance", {
            Title = "Farm All Mobs in Distance",
            Description = "Farm all mobs within the specified distance",
            Default = false
        })
        
        autoFarmDistanceToggle:OnChanged(function(Value)
            Toggles.autoFarmDistance = Value
            if Value then
                Toggles.autoFarm = false
                Options.AutoFarm:SetValue(false)
            end
        end)
        
        local autoCollectToggle = Tabs.Farming:AddToggle("AutoCollect", {
            Title = "Auto Collect Drops",
            Default = false
        })
        
        autoCollectToggle:OnChanged(function(Value)
            Toggles.autoCollect = Value
        end)
        
        
        
        
    -- Advanced Tab
    do
        local autoRaidToggle = Tabs.Advanced:AddToggle("AutoRaid", {
            Title = "Auto Raid",
            Default = false
        })
        
        autoRaidToggle:OnChanged(function(Value)
            Toggles.autoRaid = Value
        end)
        
        local autoTrialToggle = Tabs.Advanced:AddToggle("AutoTrial", {
            Title = "Auto Trial",
            Default = false
        })
        
        autoTrialToggle:OnChanged(function(Value)
            Toggles.autoTrial = Value
        end)
        
        local autoQuestToggle = Tabs.Advanced:AddToggle("AutoQuest", {
            Title = "Auto Quest",
            Default = false
        })
        
        autoQuestToggle:OnChanged(function(Value)
            Toggles.autoQuest = Value
        end)
        
        local autoFuseToggle = Tabs.Advanced:AddToggle("AutoFuse", {
            Title = "Auto Fuse Pets",
            Default = false
        })
        
        autoFuseToggle:OnChanged(function(Value)
            Toggles.autoFuse = Value
        end)
        
        local loopSpeedSlider = Tabs.Advanced:AddSlider("LoopSpeed", {
            Title = "Loop Speed",
            Description = "Adjust script loop speed (seconds)",
            Default = 0.1,
            Min = 0.05,
            Max = 2,
            Rounding = 2
        })
        
        loopSpeedSlider:OnChanged(function(Value)
            ScriptData.loopSpeed = Value
        end)
        
        Tabs.Advanced:AddButton({
            Title = "Emergency Stop",
            Description = "Stop all farming activities",
            Callback = function()
                for key, _ in pairs(Toggles) do
                    if key ~= "antiAfk" then
                        Toggles[key] = false
                    end
                end
                
                -- Update all toggles in UI
                for optionName, option in pairs(Options) do
                    if option.SetValue and optionName ~= "AntiAfk" then
                        option:SetValue(false)
                    end
                end
                
                Fluent:Notify({
                    Title = "Emergency Stop",
                    Content = "All activities stopped!",
                    Duration = 3
                })
            end
        })
    end
    
    -- Misc Tab
    do
        local antiAfkToggle = Tabs.Misc:AddToggle("AntiAfk", {
            Title = "Anti-AFK",
            Default = true
        })
        
        antiAfkToggle:OnChanged(function(Value)
            Toggles.antiAfk = Value
            if Value then
                Core.initAntiAfk()
            elseif ScriptData.connections.antiAfk then
                ScriptData.connections.antiAfk:Disconnect()
                ScriptData.connections.antiAfk = nil
            end
        end)
        
        Tabs.Misc:AddButton({
            Title = "FPS Boost",
            Description = "Optimize game performance",
            Callback = function()
                pcall(function()
                    -- Optimize rendering
                    settings().Rendering.QualityLevel = 1
                    
                    -- Disable lighting effects
                    local lighting = game:GetService("Lighting")
                    lighting.GlobalShadows = false
                    lighting.FogEnd = math.huge
                    
                    -- Optimize terrain
                    local terrain = Services.Workspace:FindFirstChildOfClass('Terrain')
                    if terrain then
                        terrain.WaterWaveSize = 0
                        terrain.WaterWaveSpeed = 0
                        terrain.WaterReflectance = 0
                        terrain.WaterTransparency = 0
                    end
                end)
                
                Fluent:Notify({
                    Title = "FPS Boost",
                    Content = "Performance optimizations applied!",
                    Duration = 3
                })
            end
        })
        
        Tabs.Misc:AddButton({
            Title = "Hide Script",
            Description = "Hide the script interface",
            Callback = function()
                Window:Minimize()
            end
        })
    end
    
    return Window
end


-- Artifacts tabs

do

function EquipArtifact(artifact)
    local args = {
        artifact,
        "CurrentSecondArtefact"
    }
    game:GetService("ReplicatedStorage"):WaitForChild("Remote"):WaitForChild("EquipArtefact"):FireServer(unpack(args))
end

local arti = {"Drops", "Luck", "Time", "Dungeon", "Dreams"}

local ArtiDropdown = Tabs.Arte:AddDropdown("ArtiDropdown", {
    Title = "Choose An Artifact To Equip | Slot 2",
    Values = arti,
    Multi = false,
    Default = "",
})

ArtiDropdown:OnChanged(function(Value)
    ScriptData.artiSelected = Value
end)

Tabs.Arte:AddButton({
    Title = "Equip",
    Description = "Equip selected artifact",
    Callback = function()
        if ScriptData.artiSelected then
    EquipArtifact(ScriptData.artiSelected)
        else
            warn("No artifact selected!")
        end
    end
})


end


local function initMainLoops()
    ScriptData.connections.autoEgg = Services.RunService.Heartbeat:Connect(function()
        if ScriptData.disabled then return end
        
        if Toggles.autoEgg and ScriptData.selectedWorld then
            local eggName = ScriptData.selectedWorld .. "Egg"
            Core.openEgg(eggName, false)
        elseif Toggles.autoEggCurrent then
            local currentWorld = Player.World and Player.World.Value
            if currentWorld then
                local eggName = currentWorld .. "Egg"
                Core.openEgg(eggName, false)
            end
        end
        
        Utils.wait(ScriptData.loopSpeed)
    end)
    
    ScriptData.connections.autoFarm = Services.RunService.Heartbeat:Connect(function()
        if ScriptData.disabled then return end
        
        if Toggles.autoFarm and ScriptData.selectedMob then
            Core.farmMob(ScriptData.selectedMob)
        elseif Toggles.autoFarmDistance then
            Core.farmAllMobsInDistance()
        end
        
        if Toggles.autoCollect then
            Core.collectDrops()
        end
        
        Utils.wait(ScriptData.loopSpeed)
    end)
    
    ScriptData.connections.advanced = Services.RunService.Heartbeat:Connect(function()
        if ScriptData.disabled then return end
        
        if Toggles.autoRaid then
            Advanced.autoRaid()
        end
        
        if Toggles.autoTrial then
            Advanced.autoTrial()
        end
        
        if Toggles.autoQuest then
            Advanced.autoQuest()
        end
        
        if Toggles.autoFuse then
            Core.autoFuse()
        end
        
        Utils.wait(ScriptData.loopSpeed * 2) -- Slower for advanced features
    end)
end

local function onCharacterAdded(char)
    Character = char
    HumanoidRootPart = char:WaitForChild("HumanoidRootPart")
end

Player.CharacterAdded:Connect(onCharacterAdded)

local function cleanup()
    ScriptData.disabled = true
    for name, connection in pairs(ScriptData.connections) do
        if connection then
            connection:Disconnect()
        end
    end
end

Services.Players.PlayerRemoving:Connect(function(player)
    if player == Player then
        cleanup()
    end
end)


-- Init
local function initialize()
    print("🚀 Loading Enhanced AFS Script with Fluent UI...")
    
    ScriptData.worlds = Utils.getWorlds()
    ScriptData.mobs = Utils.getMobs()
    ScriptData.eggs = Utils.getEggs()
    
    
    local ui = createFluentUI()
    if not ui then
        warn("❌ Failed to create UI")
        return
    end
    
    
    initMainLoops()
    
   
    Toggles.antiAfk = true
    Core.initAntiAfk()
    
   
    end
    
    -- \\ TOGGLE BUTTON
local function ToogleButtonV()
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "DraggableControlButton"
    screenGui.Parent = player.PlayerGui
    screenGui.ResetOnSpawn = false
    
    local button = Instance.new("TextButton")
    button.Name = "ControlButton"
    button.Parent = screenGui
    button.Size = UDim2.new(0, 60, 0, 60)
    button.Position = UDim2.new(0, 100, 0, 100)
    button.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
    button.BorderSizePixel = 0
    button.Text = "•"
    button.TextColor3 = Color3.fromRGB(255, 255, 255)
    button.TextScaled = true
    button.Font = Enum.Font.GothamBold
    button.Active = true
    button.Draggable = true
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 12)
    corner.Parent = button
    
    local shadow = Instance.new("Frame")
    shadow.Name = "Shadow"
    shadow.Parent = button
    shadow.Size = UDim2.new(1, 4, 1, 4)
    shadow.Position = UDim2.new(0, 2, 0, 2)
    shadow.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    shadow.BackgroundTransparency = 0.7
    shadow.BorderSizePixel = 0
    shadow.ZIndex = button.ZIndex - 1
    
    local shadowCorner = Instance.new("UICorner")
    shadowCorner.CornerRadius = UDim.new(0, 12)
    shadowCorner.Parent = shadow
    
    local originalSize = button.Size
    local hoverSize = UDim2.new(0, 65, 0, 65)
    
    local hoverTween = tweenService:Create(
        button,
        TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        {Size = hoverSize, BackgroundColor3 = Color3.fromRGB(55, 55, 55)}
    )
    
    local unhoverTween = tweenService:Create(
        button,
        TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        {Size = originalSize, BackgroundColor3 = Color3.fromRGB(45, 45, 45)}
    )
    
    button.MouseEnter:Connect(function()
        hoverTween:Play()
    end)
    
    button.MouseLeave:Connect(function()
        unhoverTween:Play()
    end)
    
    local clickTween = tweenService:Create(
        button,
        TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        {Size = UDim2.new(0, 55, 0, 55), BackgroundColor3 = Color3.fromRGB(35, 35, 35)}
    )
    
    local unclickTween = tweenService:Create(
        button,
        TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        {Size = originalSize, BackgroundColor3 = Color3.fromRGB(45, 45, 45)}
    )
    
    button.MouseButton1Click:Connect(function()
        clickTween:Play()
        
        pcall(function()
            virtualInputManager:SendKeyEvent(true, Enum.KeyCode.LeftControl, false, game)
            task.wait(0.05)
            virtualInputManager:SendKeyEvent(false, Enum.KeyCode.LeftControl, false, game)
        end)
        
        button.Text = "Erm"
        task.wait(0.1)
        button.Text = "Nuh"
        
        unclickTween:Play()
    end)
    
    button.ZIndex = 999
    shadow.ZIndex = 998
    
    return screenGui
end

    initialize()