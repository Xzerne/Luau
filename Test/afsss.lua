local ANIME_FIGHTERS_PLACE_ID = 6299805723
if game.PlaceId ~= ANIME_FIGHTERS_PLACE_ID then 
    return warn("Wrong game! This script is for Anime Fighters Simulator only.") 
end

local fuckingasshelldammit = {
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

local player = fuckingasshelldammit.Players.LocalPlayer
local tweenService = fuckingasshelldammit.TweenService
local virtualInputManager = fuckingasshelldammit.VirtualInputManager

local Player = fuckingasshelldammit.Players.LocalPlayer
local Character = Player.Character or Player.CharacterAdded:Wait()
local HumanoidRootPart = Character:WaitForChild("HumanoidRootPart")
local PlayerGui = Player.PlayerGui

local Fluent = loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()

local fuckingdata = {
    disabled = false,
    selectedWorld = nil,
    selectedMob = nil,
    selectedEgg = nil,
    selectedFuse = nil,
    selectedDefenseWorld = nil,
    farmDistance = 100,
    loopSpeed = 0.1,
    maxRetries = 3,
    cooldownTime = 0.5,
    lastAction = 0,
    artiSelected = nil,
    artiTwo = nil,
    connections = {},
    mobs = {},
    worlds = {},
    eggs = {},
    farmingMobs = {},
    savedPos = nil,
    currentWorld = nil,
    killingMeteor = false,
    defenseWorlds = {},
    ignoredMeteorWorlds = {"Tower", "Raid"},
    tempMeteorFarmIgnore = {},
    maxTimesToCheckMeteor = 30
}

local Toggles = {
    autoEgg = false,
    autoClick = true,
    autoEggCurrent = false,
    autoFarm = false,
    autoFarmAll = false,
    autoFarmDistance = false,
    autoCollect = true,
    autoRaid = false,
    autoTrial = false,
    autoDefense = false,
    autoQuest = false,
    autoFuse = false,
    antiAfk = false,
    hidePets = false,
    autoMeteor = false,
    autoStartDefense = false,
    teleportToDefense = false,
    tpFromDefense = false
}

local RemoteEvents = {
    Remote = fuckingasshelldammit.ReplicatedStorage:WaitForChild("Remote"),
    Bindable = fuckingasshelldammit.ReplicatedStorage:WaitForChild("Bindable", 5)
}

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

if fuckingasshelldammit.ReplicatedStorage:FindFirstChild("ModuleScripts") then
    local moduleScripts = fuckingasshelldammit.ReplicatedStorage.ModuleScripts
    safeRequire(moduleScripts:FindFirstChild("StatCalc"), "StatCalc")
    safeRequire(moduleScripts:FindFirstChild("NumToString"), "NumToString")
    safeRequire(moduleScripts:FindFirstChild("PetStats"), "PetStats")
    safeRequire(moduleScripts:FindFirstChild("EggStats"), "EggStats")
    safeRequire(moduleScripts:FindFirstChild("WorldData"), "WorldData")
    safeRequire(moduleScripts:FindFirstChild("ConfigValues"), "ConfigValues")
    safeRequire(moduleScripts:FindFirstChild("LocalDairebStore"), "LocalDairebStore")
end

local Utils = {}

function Utils.wait(duration)
    local startTime = tick()
    while tick() - startTime < duration and fuckingasshelldammit.RunService.Heartbeat:Wait() do end
end

function Utils.teleportToPosition(targetCFrame)
    if not targetCFrame then return false end
    
    local currentTime = tick()
    if currentTime - fuckingdata.lastAction < fuckingdata.cooldownTime then 
        return false 
    end
    fuckingdata.lastAction = currentTime
    
    local distance = (HumanoidRootPart.Position - targetCFrame.Position).Magnitude
    if distance < 10 then return true end
    
    HumanoidRootPart.CFrame = targetCFrame
    return true
end

function Utils.teleportToWorld(world)
    local success = pcall(function()
        RemoteEvents.Remote.AttemptTravel:InvokeServer(world)
        if fuckingasshelldammit.Workspace.Worlds:FindFirstChild(world) then
            local spawn = fuckingasshelldammit.Workspace.Worlds[world].Spawns.SpawnLocation
            HumanoidRootPart.CFrame = spawn.CFrame + Vector3.new(0, 15, 0)
        end
        return true
    end)
    return success
end

function Utils.getDistance(pos1, pos2)
    return (pos1 - pos2).Magnitude
end

function Utils.getWorlds()
    local worldList = {}
    local worldsFolder = fuckingasshelldammit.Workspace:FindFirstChild("Worlds")
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
        local worldFolder = fuckingasshelldammit.Workspace.Worlds:FindFirstChild(currentWorld)
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
    
    local worldFolder = fuckingasshelldammit.Workspace.Worlds:FindFirstChild(currentWorld)
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

function Utils.getDefenseWorlds()
    local defenseWorldList = {}
    for _, world in ipairs(fuckingasshelldammit.Workspace.Worlds:GetChildren()) do
        if world:FindFirstChild("TitanSummon") and Modules.WorldData then
            local worldData = Modules.WorldData[world.Name]
            if worldData then
                local displayText = string.format("%s (%s)", worldData.DisplayName or world.Name, world.Name)
                table.insert(defenseWorldList, displayText)
                fuckingdata.defenseWorlds[displayText] = world.Name
            end
        end
    end
    return defenseWorldList
end

function Utils.movePetsToPlayer()
    for _, pet in ipairs(Player.Pets:GetChildren()) do
        local targetPart = pet.Value:FindFirstChild("TargetPart")
        local humanoidRootPart = pet.Value:FindFirstChild("HumanoidRootPart")
        
        if targetPart and humanoidRootPart then
            targetPart.CFrame = HumanoidRootPart.CFrame
            humanoidRootPart.CFrame = HumanoidRootPart.CFrame
        end
    end
end

function Utils.retreat()
    virtualInputManager:SendKeyEvent(true, "R", false, game)
    task.wait(0.1)
    virtualInputManager:SendKeyEvent(false, "R", false, game)
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

function equipArtifactOne(arte)
    local args = {
    [1] = arte,
    [2] = "CurrentArtefact"
}

game:GetService("ReplicatedStorage").Remote.EquipArtefact:FireServer(unpack(args))
end

local fuckass = {}

function fuckass.openEgg(eggName, teleport)
    if fuckingdata.disabled then return false end
    
    local attempts = 0
    local success = false
    
    while attempts < fuckingdata.maxRetries and not success do
        local openSuccess, result = pcall(function()
            if teleport and eggName then
                local eggModel = fuckingasshelldammit.Workspace.Worlds:FindFirstChild(eggName .. "Egg")
                if eggModel and Utils.teleportToPosition(eggModel:GetPivot()) then
                    Utils.wait(0.3)
                end
            end
            
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
            if attempts < fuckingdata.maxRetries then
                Utils.wait(0.1)
            end
        end
    end
    
    return success
end

function fuckass.fuckhomies(mobName)
    if fuckingdata.disabled then return false end
    
    local currentWorld = Player.World and Player.World.Value
    if not currentWorld then return false end
    
    local worldFolder = fuckingasshelldammit.Workspace.Worlds:FindFirstChild(currentWorld)
    if not worldFolder then return false end
    
    local enemies = worldFolder:FindFirstChild("Enemies")
    if not enemies then return false end
    
    for _, enemy in ipairs(enemies:GetChildren()) do
        local displayName = enemy:FindFirstChild("DisplayName")
        local humanoidRootPart = enemy:FindFirstChild("HumanoidRootPart")
        local attackers = enemy:FindFirstChild("Attackers")
        
        if displayName and displayName.Value == mobName and humanoidRootPart and attackers then
            Utils.teleportToPosition(humanoidRootPart.CFrame)
            
            local success, result = pcall(function()
            Utils.movePetsToPlayer()
                if RemoteEvents.Bindable and RemoteEvents.Bindable:FindFirstChild("SendPet") then
                    RemoteEvents.Bindable.SendPet:Fire(enemy, true)
                end
            end)
            
            return success
        end
    end
    
    return false
end

function fuckass.homiesshitarroundhere()
    if fuckingdata.disabled or not Toggles.autoFarmDistance then return end
    
    local mobsInRange = Utils.getMobsInDistance(fuckingdata.farmDistance)
    
    for _, mobData in ipairs(mobsInRange) do
        if not Toggles.autoFarmDistance or fuckingdata.disabled then break end
        
        local enemy = mobData.enemy
        local success, result = pcall(function()
            if RemoteEvents.Bindable and RemoteEvents.Bindable:FindFirstChild("SendPet") then
                RemoteEvents.Bindable.SendPet:Fire(enemy, true)
            end
        end)
        
        if success then
            fuckingdata.farmingMobs[enemy] = true
        end
    end
end

function fuckass.collectDrops()
    if fuckingdata.disabled then return end
    
    pcall(function()
        local effects = fuckingasshelldammit.Workspace:FindFirstChild("Effects")
        if effects then
            for _, effect in ipairs(effects:GetDescendants()) do
                if effect.Name == "Base" and effect:IsA("BasePart") then
                    effect.CFrame = HumanoidRootPart.CFrame
                end
            end
        end
    end)
end

function fuckass.autoFuse()
    if fuckingdata.disabled or not fuckingdata.selectedFuse then return false end
    
    local pets = Utils.getPets()
    local petToFuse = nil
    local fuseablePets = {}
    
    for _, pet in pairs(pets) do
        if tostring(pet.UID) == fuckingdata.selectedFuse then
            petToFuse = pet.UID
            break
        end
    end
    
    if not petToFuse then return false end
    
    local equippedPets = {}
    for _, petObj in ipairs(Player.Pets:GetChildren()) do
        if petObj.Value and petObj.Value.Data and petObj.Value.Data.UID then
            equippedPets[petObj.Value.Data.UID.Value] = true
        end
    end
    
    for _, pet in pairs(pets) do
        if not equippedPets[pet.UID] and pet.UID ~= petToFuse then
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

function fuckass.farmMeteors()
    if fuckingdata.disabled or fuckingdata.killingMeteor then return end
    
    local currentWorld = Player.World.Value
    if table.find(fuckingdata.ignoredMeteorWorlds, currentWorld) then return end
    
    for _, world in ipairs(fuckingasshelldammit.Workspace.Worlds:GetChildren()) do
        local enemies = world:FindFirstChild("Enemies")
        local fruitMeteor = nil
        
        if enemies then
            fruitMeteor = enemies:FindFirstChild("FruitMeteor")
        end
        
        if fruitMeteor and not table.find(fuckingdata.tempMeteorFarmIgnore, world.Name) then
            fuckingdata.killingMeteor = true
            
            local oldWorld = Player.World.Value
            local oldPos = HumanoidRootPart.CFrame
            
            Utils.teleportToWorld(world.Name)
            task.wait(1)
            
            local fruitMeteorHRP = fruitMeteor:FindFirstChild("HumanoidRootPart")
            local count = 1
         
            while fruitMeteorHRP == nil 
            and Toggles.autoMeteor
            and count <= fuckingdata.maxTimesToCheckMeteor 
            and not fuckingdata.disabled do
                for _, spawn in ipairs(world.EnemySpawners:GetChildren()) do
                    if fruitMeteorHRP then break end
                    HumanoidRootPart.CFrame = spawn.CFrame
                    fruitMeteorHRP = fruitMeteor:FindFirstChild("HumanoidRootPart")
                end
                count = count + 1
                task.wait(0.1)
            end
            
            if fruitMeteorHRP then
                HumanoidRootPart.CFrame = fruitMeteorHRP.CFrame
                Utils.movePetsToPlayer()
                task.wait()
                
                repeat
                    if fruitMeteor:FindFirstChild("Attackers") then
                        RemoteEvents.Bindable.SendPet:Fire(fruitMeteor, true)
                    end
                    task.wait()
                until fuckingdata.disabled
                or enemies:FindFirstChild("FruitMeteor") == nil
                or fruitMeteor:FindFirstChild("Attackers") == nil
                or not Toggles.autoMeteor
                
                Utils.retreat()
                
                if oldWorld ~= "Titan" and fuckingdata.savedPos then
                    Utils.teleportToWorld(fuckingdata.currentWorld or oldWorld)
                    HumanoidRootPart.CFrame = fuckingdata.savedPos
                end
            else
                table.insert(fuckingdata.tempMeteorFarmIgnore, world.Name)
                
                task.delay(300, function()
                    local index = table.find(fuckingdata.tempMeteorFarmIgnore, world.Name)
                    if index then
                        table.remove(fuckingdata.tempMeteorFarmIgnore, index)
                    end
                end)
                
                if oldWorld ~= "Titan" and fuckingdata.savedPos then
                    Utils.teleportToWorld(fuckingdata.currentWorld or oldWorld)
                    HumanoidRootPart.CFrame = fuckingdata.savedPos
                end
            end
            
            fuckingdata.killingMeteor = false
            break
        end
    end
end

function fuckass.autoDefense()
    if fuckingdata.disabled or Player.World.Value ~= "Titan" then return end
    
    local enemies = fuckingasshelldammit.Workspace.Worlds.Titan.Enemies
    
    for _, enemy in ipairs(enemies:GetChildren()) do
        if not Toggles.autoDefense or fuckingdata.disabled then break end
        
        if enemy:FindFirstChild("HumanoidRootPart") and enemy:FindFirstChild("Attackers") then
            pcall(function()
                HumanoidRootPart.CFrame = enemy.HumanoidRootPart.CFrame
                Utils.movePetsToPlayer()
                
                repeat
                    if enemy:FindFirstChild("Attackers") then
                        RemoteEvents.Bindable.SendPet:Fire(enemy, true)
                    end
                    task.wait()
                until fuckingdata.disabled
                or not enemy:FindFirstChild("HumanoidRootPart")
                or not enemy:FindFirstChild("Attackers")
                or not Toggles.autoDefense
                or Player.World.Value ~= "Titan"
                or (enemy:FindFirstChild("Health") and enemy.Health.Value <= 0)
                
                Utils.retreat()
            end)
        end
    end
end

function fuckass.autoStartDefense()
    if fuckingdata.disabled or not fuckingdata.selectedDefenseWorld then return end
    
    pcall(function()
        local data = Modules.LocalDairebStore.GetStoreProxy("GameData")
        local items = data:GetData("Items")
        
        if items and items.TitanSummon and items.TitanSummon > 0 then
            local trigger = fuckingasshelldammit.Workspace.Worlds[fuckingdata.selectedDefenseWorld].TitanSummon:FindFirstChild("Trigger")
            
            if trigger then
                RemoteEvents.Remote.SummonTitan:FireServer(trigger)
            end
        end
    end)
end

function fuckass.initAntiAfk()
    if fuckingdata.connections.antiAfk then return end
    
    fuckingdata.connections.antiAfk = Player.Idled:Connect(function()
        fuckingasshelldammit.VirtualUser:Button2Down(Vector2.new(0, 0), fuckingasshelldammit.Workspace.CurrentCamera.CFrame)
        task.wait(1)
        fuckingasshelldammit.VirtualUser:Button2Up(Vector2.new(0, 0), fuckingasshelldammit.Workspace.CurrentCamera.CFrame)
    end)
end

local Advanced = {}

function Advanced.autoRaid()
    if fuckingdata.disabled or Player.World.Value ~= "Raid" then return end
    
    local enemies = fuckingasshelldammit.Workspace.Worlds.Raid.Enemies
    
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

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

function Advanced.autoTrial()
    if not fuckingdata or fuckingdata.disabled or not Player or Player.World.Value ~= "Tower" then return end

    local towerWorld = fuckingasshelldammit and fuckingasshelldammit.Workspace:FindFirstChild("Worlds") and fuckingasshelldammit.Workspace.Worlds:FindFirstChild("Tower")
    if not towerWorld then return end

    local char = Players.LocalPlayer.Character or Players.LocalPlayer.CharacterAdded:Wait()
    local hrp = char:WaitForChild("HumanoidRootPart")

    while Player.World.Value == "Tower" and not fuckingdata.disabled do
        local enemies = towerWorld:FindFirstChild("Enemies")
        local enemyList = enemies and enemies:GetChildren() or {}

        if #enemyList > 0 then
            for _, enemy in ipairs(enemyList) do
                if enemy and enemy:FindFirstChild("HumanoidRootPart") and enemy:FindFirstChild("Attackers") then
                    pcall(function()
                        if Utils and Utils.teleportToPosition then
                            Utils.teleportToPosition(enemy.HumanoidRootPart.CFrame)
                        end
                        local sendPet = RemoteEvents and RemoteEvents.Bindable and RemoteEvents.Bindable:FindFirstChild("SendPet")
                        if sendPet then
                            task.wait(0.3)
                            sendPet:Fire(enemy, true)
                        end
                    end)
                end
            end
        else
            local map = towerWorld:FindFirstChild("Map")
            if map then
                local nearestConfirmPart = nil
                local shortestDistance = math.huge

                for _, part in ipairs(map:GetChildren()) do
                    local confirmPart = part:FindFirstChild("ConfirmPart", true)
                    if confirmPart and confirmPart:IsA("BasePart") then
                        local dist = (confirmPart.Position - hrp.Position).Magnitude
                        if dist < shortestDistance then
                            shortestDistance = dist
                            nearestConfirmPart = confirmPart
                        end
                    end
                end
                if nearestConfirmPart and nearestConfirmPart:FindFirstChildOfClass("ProximityPrompt") then
                    local prompt = nearestConfirmPart:FindFirstChildOfClass("ProximityPrompt")
                    pcall(function()
                        local FirePrompt = fireproximityprompt or (prompt and function(p)
                            p:InputHoldBegin()
                            task.wait(p.HoldDuration)
                            p:InputHoldEnd()
                        end)
                        FirePrompt(prompt)
                    end)
                end
            end
        end

        task.wait(0.1)
    end
end


local QuestTracker = {
    lastQuestText = "",
    currentTarget = nil,
    currentKilled = 0,
    requiredKills = 0,
    questCompleted = false,
    questCheckInterval = 0.5,
    lastQuestCheck = 0,
    questChainActive = false,
    consecutiveQuestAttempts = 0,
    maxQuestAttempts = 3
}

local function trim(s)
    return s:match("^()%s*$") and "" or s:match("^%s*(.-)%s*$")
end

function QuestTracker.parseQuestText(questText)
    if not questText or questText == "" then return nil, 0, 0 end
    local killed, required, mobName = string.match(questText, "%[(%d+)/(%d+)%]%s*(.+)")
    if killed and required and mobName then
        return trim(mobName), tonumber(killed), tonumber(required)
    end
    return nil, 0, 0
end

function QuestTracker.getCurrentQuestInfo()
    local success, result = pcall(function()
        local questUI = PlayerGui:WaitForChild("MainGui", 5)
        local quest = questUI:WaitForChild("Quest", 5)
        local objectives = quest:WaitForChild("Objectives", 5)
        local questText = objectives:WaitForChild("QuestText", 5)

        if questText:IsA("TextLabel") and questText.Text ~= "" then
            return questText.Text
        end

        local contentText = questText:FindFirstChild("ContentText")
        if contentText and contentText:IsA("TextLabel") and contentText.Text ~= "" then
            return contentText.Text
        end

        return nil
    end)
    return success and result or nil
end

function QuestTracker.findTargetMob(mobName)
    if not mobName then return nil end
    local currentWorld = Player.World and Player.World.Value
    if not currentWorld then return nil end
    local worldFolder = fuckingasshelldammit.Workspace.Worlds:FindFirstChild(currentWorld)
    if not worldFolder or not worldFolder:FindFirstChild("Enemies") then return nil end
    for _, enemy in ipairs(worldFolder.Enemies:GetChildren()) do
        local displayName = enemy:FindFirstChild("DisplayName")
        if displayName and displayName.Value == mobName then
            local humanoidRootPart = enemy:FindFirstChild("HumanoidRootPart")
            local attackers = enemy:FindFirstChild("Attackers")
            if humanoidRootPart and attackers then
                return enemy
            end
        end
    end
    return nil
end

function QuestTracker.attackTargetMob(enemy)
    if not enemy or not enemy.Parent then return false end
    local humanoidRootPart = enemy:FindFirstChild("HumanoidRootPart")
    if not humanoidRootPart then return false end
    local success = Utils.teleportToPosition(humanoidRootPart.CFrame)
    if not success then return false end
    local attackSuccess = pcall(function()
        Utils.movePetsToPlayer()
        if RemoteEvents.Bindable and RemoteEvents.Bindable:FindFirstChild("SendPet") then
            RemoteEvents.Bindable.SendPet:Fire(enemy, true)
            return true
        end
        return false
    end)
    return attackSuccess
end

function QuestTracker.finishQuest()
    local currentWorld = Player.World and Player.World.Value
    if not currentWorld then return false end
    local success = pcall(function()
        local npc = fuckingasshelldammit.Workspace.Worlds[currentWorld]:FindFirstChild(currentWorld)
        if npc then
            RemoteEvents.Remote:FindFirstChild("FinishQuest"):FireServer(npc)
            RemoteEvents.Remote:FindFirstChild("FinishQuestline"):FireServer(npc)
            QuestTracker.consecutiveQuestAttempts = 0
            return true
        end
        return false
    end)
    return success
end

function QuestTracker.startQuest()
    local currentWorld = Player.World and Player.World.Value
    if not currentWorld then return false end
    QuestTracker.consecutiveQuestAttempts = QuestTracker.consecutiveQuestAttempts + 1
    if QuestTracker.consecutiveQuestAttempts > QuestTracker.maxQuestAttempts then
        task.wait(5)
        QuestTracker.consecutiveQuestAttempts = 0
        return false
    end
    local success = pcall(function()
        local npc = fuckingasshelldammit.Workspace.Worlds[currentWorld]:FindFirstChild(currentWorld)
        if npc then
            RemoteEvents.Remote:FindFirstChild("StartQuest"):FireServer(npc)
            QuestTracker.questChainActive = true
            return true
        end
        return false
    end)
    return success
end

function Advanced.autoQuest()
    if fuckingdata.disabled or not Toggles.autoQuest then return end
    local currentTime = tick()
    if currentTime - QuestTracker.lastQuestCheck < QuestTracker.questCheckInterval then
        if QuestTracker.currentTarget and QuestTracker.currentKilled < QuestTracker.requiredKills then
            local targetMob = QuestTracker.findTargetMob(QuestTracker.currentTarget)
            if targetMob then QuestTracker.attackTargetMob(targetMob) end
        end
        return
    end
    QuestTracker.lastQuestCheck = currentTime

    local questText = QuestTracker.getCurrentQuestInfo()

    if not questText or questText == "" or questText:lower():find("no active quest") then
        QuestTracker.questCompleted = false
        QuestTracker.startQuest()
        QuestTracker.currentTarget, QuestTracker.currentKilled, QuestTracker.requiredKills = nil, 0, 0
        QuestTracker.lastQuestText = ""
        return
    end

    local mobName, killed, required = QuestTracker.parseQuestText(questText)
    if not mobName then
        return
    end

    if killed >= required then
        if not QuestTracker.questCompleted then
            QuestTracker.questCompleted = true
            QuestTracker.finishQuest()
            task.wait(1.5)
            QuestTracker.startQuest()
            task.wait(1)
            QuestTracker.currentTarget, QuestTracker.currentKilled, QuestTracker.requiredKills = nil, 0, 0
            QuestTracker.questCompleted = false
            QuestTracker.lastQuestText = ""
        end
        return
    end

    QuestTracker.currentTarget = mobName
    QuestTracker.currentKilled = killed
    QuestTracker.requiredKills = required

    if questText ~= QuestTracker.lastQuestText then
        QuestTracker.lastQuestText = questText
    end

    local targetMob = QuestTracker.findTargetMob(mobName)
    if targetMob then
        QuestTracker.attackTargetMob(targetMob)
    end
end

-- Artifact equip function
function EquipArtifact(artifact)
    local args = {
        artifact,
        "CurrentSecondArtefact"
    }
    game:GetService("ReplicatedStorage"):WaitForChild("Remote"):WaitForChild("EquipArtefact"):FireServer(unpack(args))
end

local function createFluentUI()
    local Window = Fluent:CreateWindow({
        Title = "Nanashi Hub | AFS",
        SubTitle = "by no name",
        TabWidth = 160,
        Size = UDim2.fromOffset(580, 460),
        Acrylic = true,
        Theme = "Dark",
        MinimizeKey = Enum.KeyCode.LeftControl
    })
    
    -- Tabs
    local Tabs = {
        Farming = Window:AddTab({ Title = "Farming", Icon = "zap" }),
        Main = Window:AddTab({ Title = "Eggs", Icon = "home" }),
        Advanced = Window:AddTab({ Title = "Advanced", Icon = "settings" }),
        Defense = Window:AddTab({ Title = "Defense & Meteor", Icon = "shield" }),
        Arte = Window:AddTab({ Title = "Artifacts", Icon = "star" }),
        Misc = Window:AddTab({ Title = "Misc", Icon = "more-horizontal" }),
        Team = Window:AddTab({ Title = "Teams", Icon = "people" })
    }
    
    local Options = Fluent.Options
    
    -- Main Tab
    do
        local worldDropdown = Tabs.Main:AddDropdown("WorldSelect", {
            Title = "Select World",
            Values = Utils.getWorlds(),
            Multi = false,
            Default = ""
        })
        
        worldDropdown:OnChanged(function(Value)
            fuckingdata.selectedWorld = Value
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
            end
        end)
        
        Tabs.Main:AddButton({
            Title = "TP to Selected World",
            Description = "Teleport to selected world",
            Callback = function()
                if fuckingdata.selectedWorld and fuckingdata.selectedWorld ~= "" then
                    local success = Utils.teleportToWorld(fuckingdata.selectedWorld)
                    if success then
                        Fluent:Notify({
                            Title = "Success",
                            Content = "Teleported to " .. fuckingdata.selectedWorld,
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
    
    local autoClickToggle = Tabs.Farming:AddToggle("AutoClick", {
            Title = "Auto Click [Visual]",
            Default = true
        })
        
        autoClickToggle:OnChanged(function(Value)
            Toggles.autoClick = Value
        end)
        
        local mobDropdown = Tabs.Farming:AddDropdown("MobSelect", {
            Title = "Select Mob",
            Values = Utils.getMobs(),
            Multi = false,
            Default = ""
        })
        
        mobDropdown:OnChanged(function(Value)
            fuckingdata.selectedMob = Value
        end)
        
        Tabs.Farming:AddButton({
            Title = "Refresh Mobs",
            Description = "Update mob list for current world",
            Callback = function()
                fuckingdata.mobs = Utils.getMobs()
                Options.MobSelect:SetValues(fuckingdata.mobs)
                Fluent:Notify({
                    Title = "Updated",
                    Content = string.format("Found %d mobs in current world", #fuckingdata.mobs),
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
            end
        end)
        
        local farmDistanceSlider = Tabs.Farming:AddSlider("FarmDistance", {
            Title = "Farm Distance",
            Description = "Distance to farm mobs around you",
            Default = 200,
            Min = 50,
            Max = 500,
            Rounding = 0
        })
        
        farmDistanceSlider:OnChanged(function(Value)
            fuckingdata.farmDistance = Value
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
            Default = true
        })
        
        autoCollectToggle:OnChanged(function(Value)
            Toggles.autoCollect = Value
        end)
    end
    
   
    
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
            fuckingdata.loopSpeed = Value
        end)
        
        Tabs.Advanced:AddButton({
            Title = "Stop all",
            Description = "Stop all farming activities",
            Callback = function()
                for key, _ in pairs(Toggles) do
                    if key ~= "antiAfk" then
                        Toggles[key] = false
                    end
                end
                
                for optionName, option in pairs(Options) do
                    if option.SetValue and optionName ~= "AntiAfk" then
                        option:SetValue(false)
                    end
                end
                
                Fluent:Notify({
                    Title = "Stopped",
                    Content = "All actions stopped",
                    Duration = 3
                })
            end
        })
    end
    
    -- NEW DEFENSE & METEOR TAB
    do
        -- Meteor Farming Section
        Tabs.Defense:AddButton({
            Title = "Set Spawn for Auto Farm/Summon",
            Description = "Save current position to tp back",
            Callback = function()
                fuckingdata.savedPos = HumanoidRootPart.CFrame
                fuckingdata.currentWorld = Player.World.Value
                Fluent:Notify({
                    Title = "Spawn Set",
                    Content = "Location saved for " .. fuckingdata.currentWorld,
                    Duration = 3
                })
            end
        })
        
        local autoMeteorToggle = Tabs.Defense:AddToggle("AutoMeteor", {
            Title = "Auto Farm Meteors",
            Description = "Automatically farm meteors",
            Default = false
        })
        
        autoMeteorToggle:OnChanged(function(Value)
            Toggles.autoMeteor = Value
        end)
        
        -- Defense Mode Section
        local defenseWorldDropdown = Tabs.Defense:AddDropdown("DefenseWorldSelect", {
            Title = "Select Defense World",
            Values = Utils.getDefenseWorlds(),
            Multi = false,
            Default = ""
        })
        
        defenseWorldDropdown:OnChanged(function(Value)
            fuckingdata.selectedDefenseWorld = fuckingdata.defenseWorlds[Value]
        end)
        
        local autoDefenseToggle = Tabs.Defense:AddToggle("AutoDefense", {
            Title = "Auto Defense Mode",
            Description = "Automatically do defense mode",
            Default = false
        })
        
        autoDefenseToggle:OnChanged(function(Value)
            Toggles.autoDefense = Value
        end)
        
        local autoStartDefenseToggle = Tabs.Defense:AddToggle("AutoStartDefense", {
            Title = "Auto Start Defense",
            Description = "Automatically start defense mode when you have tokens",
            Default = false
        })
        
        autoStartDefenseToggle:OnChanged(function(Value)
            Toggles.autoStartDefense = Value
        end)
        
        local teleportToDefenseToggle = Tabs.Defense:AddToggle("TeleportToDefense", {
            Title = "Auto TP to Defense Mode",
            Description = "Automatically teleport to defense mode",
            Default = false
        })
        
        teleportToDefenseToggle:OnChanged(function(Value)
            Toggles.teleportToDefense = Value
        end)
        
        local tpFromDefenseToggle = Tabs.Defense:AddToggle("TpFromDefense", {
            Title = "Auto Return from Defense",
            Description = "Return to saved position after defense",
            Default = false
        })
        
        tpFromDefenseToggle:OnChanged(function(Value)
            Toggles.tpFromDefense = Value
        end)
        
        Tabs.Defense:AddButton({
            Title = "TP to Defense World",
            Description = "Manually teleport to selected defense world",
            Callback = function()
                if fuckingdata.selectedDefenseWorld then
                    Utils.teleportToWorld("Titan")
                    task.wait(0.5)
                    local spawn = fuckingasshelldammit.Workspace.Worlds.Titan.Spawns:FindFirstChild("Spawn")
                    if spawn then
                        HumanoidRootPart.CFrame = spawn.CFrame + Vector3.new(0, 5, 0)
                    end
                    Fluent:Notify({
                        Title = "Success",
                        Content = "Teleported to Defense Mode",
                        Duration = 3
                    })
                else
                    Fluent:Notify({
                        Title = "Error",
                        Content = "No defense world selected!",
                        Duration = 3
                    })
                end
            end
        })
    end
    
    -- Artifacts Tab
    do
        local arti = {"Drops", "Luck", "Time", "Dungeon", "Dreams", "Yen", "Leveling", "Equip"}
        
        local ArtiDropdownOne = Tabs.Arte:AddDropdown("ArtiDropdown", {
            Title = "Choose An Artifact To Equip | Slot 1",
            Values = arti,
            Multi = false,
            Default = "",
        })
        
        ArtiDropdownOne:OnChanged(function(Value)
            fuckingdata.artiTwo = Value
        end)
        
        local ArtiDropdown = Tabs.Arte:AddDropdown("ArtiDropdown", {
            Title = "Choose An Artifact To Equip | Slot 2",
            Values = arti,
            Multi = false,
            Default = "",
        })
        
        ArtiDropdown:OnChanged(function(Value)
            fuckingdata.artiSelected = Value
        end)
        
        Tabs.Arte:AddButton({
            Title = "Equip Slot 2",
            Description = "Equip selected slot 2 artifact",
            Callback = function()
                if fuckingdata.artiTwo then
                    EquipArtifact(fuckingdata.artiSelected)
                    Fluent:Notify({
                        Title = "Success",
                        Content = "Equipped " .. fuckingdata.artiSelected,
                        Duration = 3
                    })
                else
                    Fluent:Notify({
                        Title = "Error",
                        Content = "No artifact two selected",
                        Duration = 3
                    })
                end
            end
        })
        
        Tabs.Arte:AddButton({
            Title = "Equip Slot 2",
            Description = "Equip selected slot 2 artifact",
            Callback = function()
                if fuckingdata.artiSelected then
                    equipArtifactOne(fuckingdata.artiTwo)
                    Fluent:Notify({
                        Title = "Success",
                        Content = "Equipped " .. fuckingdata.artiSelected,
                        Duration = 3
                    })
                else
                    Fluent:Notify({
                        Title = "Error",
                        Content = "No artifact two selected",
                        Duration = 3
                    })
                end
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
                fuckass.initAntiAfk()
            elseif fuckingdata.connections.antiAfk then
                fuckingdata.connections.antiAfk:Disconnect()
                fuckingdata.connections.antiAfk = nil
            end
        end)
        
        Tabs.Misc:AddButton({
            Title = "FPS Boost",
            Description = "Optimize game performance",
            Callback = function()
                pcall(function()
                    settings().Rendering.QualityLevel = 1
                    
                    local lighting = game:GetService("Lighting")
                    lighting.GlobalShadows = false
                    lighting.FogEnd = math.huge
                    
                    local terrain = fuckingasshelldammit.Workspace:FindFirstChildOfClass('Terrain')
                    if terrain then
                        terrain.WaterWaveSize = 0
                        terrain.WaterWaveSpeed = 0
                        terrain.WaterReflectance = 0
                        terrain.WaterTransparency = 0
                    end
                end)
                
                Fluent:Notify({
                    Title = "FPS Boost",
                    Content = "Performance optimized",
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
        
        button.Text = "UI"
        task.wait(0.1)
        button.Text = "•"
        
        unclickTween:Play()
    end)
    
    button.ZIndex = 999
    shadow.ZIndex = 998
    
    return screenGui
end

local function holdashit()
    -- Auto Egg
    fuckingdata.connections.autoEgg = fuckingasshelldammit.RunService.Heartbeat:Connect(function()
        if fuckingdata.disabled then return end
        
        if Toggles.autoEgg and fuckingdata.selectedWorld then
            local eggName = fuckingdata.selectedWorld .. "Egg"
            fuckass.openEgg(eggName, false)
        elseif Toggles.autoEggCurrent then
            local currentWorld = Player.World and Player.World.Value
            if currentWorld then
                local eggName = currentWorld .. "Egg"
                fuckass.openEgg(eggName, false)
            end
        end
        
        Utils.wait(fuckingdata.loopSpeed)
    end)
    
    -- Auto Farm
    fuckingdata.connections.autoFarm = fuckingasshelldammit.RunService.Heartbeat:Connect(function()
        if fuckingdata.disabled then return end
        
        if Toggles.autoFarm and fuckingdata.selectedMob then
            fuckass.fuckhomies(fuckingdata.selectedMob)
        elseif Toggles.autoFarmDistance then
            fuckass.homiesshitarroundhere()
        end
        
        if Toggles.autoCollect then
            fuckass.collectDrops()
        end
        
        Utils.wait(fuckingdata.loopSpeed)
    end)
    
    fuckingdata.connections.advanced = fuckingasshelldammit.RunService.Heartbeat:Connect(function()
        if fuckingdata.disabled then return end
        
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
            fuckass.autoFuse()
        end
        
        Utils.wait(fuckingdata.loopSpeed * 2)
    end)
    
    fuckingdata.connections.meteorFarm = fuckingasshelldammit.RunService.Heartbeat:Connect(function()
        if fuckingdata.disabled then return end
        
        if Toggles.autoMeteor then
            fuckass.farmMeteors()
        end
        
        Utils.wait(1)
    end)
    
    fuckingdata.connections.defenseMode = fuckingasshelldammit.RunService.Heartbeat:Connect(function()
        if fuckingdata.disabled then return end
        
        if Toggles.autoDefense then
            fuckass.autoDefense()
        end
        
        if Toggles.autoStartDefense then
            fuckass.autoStartDefense()
        end
        
        if Toggles.teleportToDefense and not fuckingdata.killingMeteor then
            if fuckingdata.selectedDefenseWorld and Player.World.Value ~= "Titan" then
                Utils.teleportToWorld("Titan")
                task.wait(0.5)
                local spawn = fuckingasshelldammit.Workspace.Worlds.Titan.Spawns:FindFirstChild("Spawn")
                if spawn then
                    HumanoidRootPart.CFrame = spawn.CFrame + Vector3.new(0, 5, 0)
                end
            end
        end
        
        if Toggles.tpFromDefense then
            local defenseResult = PlayerGui:FindFirstChild("TitanGui")
            if defenseResult and defenseResult:FindFirstChild("DefenseResult") and defenseResult.DefenseResult.Visible then
                defenseResult.DefenseResult.Visible = false
                if fuckingdata.savedPos and fuckingdata.currentWorld then
                    Utils.teleportToWorld(fuckingdata.currentWorld)
                    HumanoidRootPart.CFrame = fuckingdata.savedPos
                end
            end
        end
        
        Utils.wait(fuckingdata.loopSpeed * 3)
    end)
end

local function onCharacterAdded(char)
    Character = char
    HumanoidRootPart = char:WaitForChild("HumanoidRootPart")
end

Player.CharacterAdded:Connect(onCharacterAdded)

local function clearthefuckup()
    fuckingdata.disabled = true
    for name, connection in pairs(fuckingdata.connections) do
        if connection then
            connection:Disconnect()
        end
    end
end

fuckingasshelldammit.Players.PlayerRemoving:Connect(function(player)
    if player == Player then
        clearthefuckup()
    end
end)

-- Init 
local function initialize()
    print("Loading Script...")
    
    fuckingdata.worlds = Utils.getWorlds()
    fuckingdata.mobs = Utils.getMobs()
    fuckingdata.eggs = Utils.getEggs()
    
    local ui = createFluentUI()
    if not ui then
        warn("Failed to load UI")
        return
    end
    
    holdashit()
    
    Toggles.antiAfk = true
    fuckass.initAntiAfk()
   
    ToogleButtonV()
    
    print("loaded")
end

spawn(function()
    while task.wait() do
        if Toggles.autoQuest then
            local currentWorld = Player.World and Player.World.Value
            if currentWorld then
                local npc = fuckingasshelldammit.Workspace.Worlds[currentWorld]:FindFirstChild(currentWorld)
                if npc then
                    RemoteEvents.Remote:FindFirstChild("StartQuest"):FireServer(npc)
                end
            end
        end
    end
end)





local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

local GameData = require(ReplicatedStorage.ModuleScripts.LocalDairebStore).GetStoreProxy("GameData")
local allData = GameData:GetData() or {}
local petTeams = allData["PetTeams"] or {}

local teamsTable = {}
for _, team in ipairs(petTeams) do
    table.insert(teamsTable, team.Name)
end

function equipTeam(teamName)
    local selectedTeam
    for _, team in ipairs(petTeams) do
        if team.Name == teamName then
            selectedTeam = team
            break
        end
    end

    if not selectedTeam then
        warn("Không tìm thấy team:", teamName)
        return
    end

    local uids = selectedTeam.UIDs or {}
    for slotStr, uid in pairs(uids) do
        local slot = tonumber(slotStr)
        local args = {
            [1] = uid,
            [2] = "Equip",
            [3] = slot
        }
        ReplicatedStorage.Remote.ManagePet:FireServer(unpack(args))
    end
end


    local TeamsDropdown = Tabs.Team:AddDropdown("TeamsSelectDropDown", {
        Title = "Select Defense World",
        Values = teamsTable,
        Multi = false,
        Default = ""
    })

    TeamsDropdown:OnChanged(function(Value)
        getgenv().TeamSelected = Value
    end)

    Tabs.Team:AddButton({
        Title = "Change Team",
        Description = "Just change to the selected team",
        Callback = function()
            local selected = getgenv().TeamSelected
            if selected then
                equipTeam(selected)
                Fluent:Notify({
                    Title = "Team Changed",
                    Content = "Equipped team: " .. selected,
                    Duration = 3
                })
            else
                Fluent:Notify({
                    Title = "No Team Selected",
                    Content = "Go!! select a team first.",
                    Duration = 3
                })
            end
        end
    })


        
     


initialize()
