setfenv(1, VoiceOver)

local CURRENT_MODULE_VERSION = 1
local LOAD_ALL_MODULES = true

DataModules =
{
    availableModules = {}, -- To store the list of modules present in Interface\AddOns folder, whether they're loaded or not
    availableModulesOrdered = {}, -- To store the list of modules present in Interface\AddOns folder, whether they're loaded or not
    registeredModules = {}, -- To keep track of which module names were already registered
    registeredModulesOrdered = {}, -- To have a consistent ordering of modules (which key-value hashmaps don't provide) to avoid bugs that can only be reproduced randomly
}

local function SortModules(a, b)
    a = a.METADATA or a
    b = b.METADATA or b
    if a.ModulePriority ~= b.ModulePriority then
        return a.ModulePriority > b.ModulePriority
    end
    return a.AddonName < b.AddonName
end

function DataModules:Register(name, module)
    assert(not self.registeredModules[name], format([[Module "%s" already registered]], name))

    local metadata = assert(self.availableModules[name], format([[Module "%s" attempted to register but wasn't detected during addon enumeration]], name))
    local moduleVersion = assert(tonumber(GetAddOnMetadata(name, "X-VoiceOver-DataModule-Version")), format([[Module "%s" is missing data format version]], name))

    -- Ideally if module format would ever change - there should be fallbacks in place to handle outdated formats
    assert(moduleVersion == CURRENT_MODULE_VERSION, format([[Module "%s" contains outdated data format (version %d, expected %d)]], name, moduleVersion, CURRENT_MODULE_VERSION))

    module.METADATA = metadata

    self.registeredModules[name] = module
    table.insert(self.registeredModulesOrdered, module)

    -- Order the modules by priority (higher first) then by name (case-sensitive alphabetical)
    -- Modules with higher priority will be iterated through first, so one can create a module with "overrides" for data in other modules by simply giving it a higher priority
    table.sort(self.registeredModulesOrdered, SortModules)
end

function DataModules:GetModule(name)
    return self.registeredModules[name]
end

function DataModules:GetModules()
    return ipairs(self.registeredModulesOrdered)
end

function DataModules:GetAvailableModules()
    return ipairs(self.availableModulesOrdered)
end

function DataModules:EnumerateAddons()
    local playerName = UnitName("player")
    for i = 1, GetNumAddOns() do
        local moduleVersion = tonumber(GetAddOnMetadata(i, "X-VoiceOver-DataModule-Version"))
        if moduleVersion and GetAddOnEnableState(playerName, i) ~= 0 then
            local name = GetAddOnInfo(i)
            local mapsString = GetAddOnMetadata(i, "X-VoiceOver-DataModule-Maps")
            local maps = {}
            if mapsString then
                for _, mapString in ipairs({ strsplit(",", mapsString) }) do
                    local map = tonumber(mapString)
                    if map then
                        maps[map] = true
                    end
                end
            end
            local module =
            {
                AddonName = name,
                LoadOnDemand = IsAddOnLoadOnDemand(name),
                ModuleVersion = moduleVersion,
                ModulePriority = tonumber(GetAddOnMetadata(name, "X-VoiceOver-DataModule-Priority")) or 0,
                ContentVersion = GetAddOnMetadata(name, "Version"),
                Title = GetAddOnMetadata(name, "Title") or name,
                Maps = maps,
            }
            self.availableModules[name] = module
            table.insert(self.availableModulesOrdered, module)

            -- Maybe in the future we can load modules based on the map the player is in (select(8, GetInstanceInfo())), but for now - just load everything
            if LOAD_ALL_MODULES and IsAddOnLoadOnDemand(name) then
                LoadAddOn(name)
            end
        end
    end

    table.sort(self.availableModulesOrdered, SortModules)
    for order, module in self:GetAvailableModules() do
        Options:AddDataModule(module, order)
    end
end

function DataModules:GetNPCGossipTextHash(soundData)
    local npcId = VoiceOverUtils:getIdFromGuid(soundData.unitGuid)
    local text = soundData.text

    local text_entries = {}

    for _, module in self:GetModules() do
        local data = module.NPCToTextToTemplateHash
        if data then
            local npc_gossip_table = data[npcId]
            if npc_gossip_table then
                for text, hash in pairs(npc_gossip_table) do
                    text_entries[text] = text_entries[text] or
                        hash -- Respect module priority, don't overwrite the entry if there is already one
                end
            end
        end
    end

    local best_result = FuzzySearchBestKeys(text, text_entries)
    return best_result and best_result.value
end

function DataModules:GetQuestLogNPCID(questId)
    for _, module in self:GetModules() do
        local data = module.QuestlogNpcGuidTable
        if data then
            local npcId = data[questId]
            if npcId then
                return npcId
            end
        end
    end
end

function DataModules:GetQuestIDByQuestTextHash(hash, npcId)
    local hashWithNpc = format("%s:%d", hash, npcId)
    for _, module in self:GetModules() do
        local data = module.QuestTextHashToQuestID
        if data then
            local questId = data[hashWithNpc] or data[hash]
            if questId then
                return questId
            end
        end
    end
end

local getFileNameForEvent = setmetatable(
    {
        accept = function(soundData) return format("%d-%s", soundData.questId, "accept") end,
        progress = function(soundData) return format("%d-%s", soundData.questId, "progress") end,
        complete = function(soundData) return format("%d-%s", soundData.questId, "complete") end,
        gossip = function(soundData) return DataModules:GetNPCGossipTextHash(soundData) end,
    }, { __index = function(self, event) error(format([[Unhandled VoiceOver sound event "%s"]], event)) end })

function DataModules:PrepareSound(soundData)
    soundData.fileName = getFileNameForEvent[soundData.event](soundData)

    if soundData.fileName == nil then
        return false
    end

    for _, module in self:GetModules() do
        local data = module.SoundLengthTable
        if data then
            local playerGenderedFileName = DataModules:addPlayerGenderToFilename(soundData.fileName)
            if data[playerGenderedFileName] then
                soundData.fileName = playerGenderedFileName
            end
            local length = data[soundData.fileName]
            if length then
                soundData.filePath = format([[Interface\AddOns\%s\%s]], module.METADATA.AddonName,
                    module.GetSoundPath and module:GetSoundPath(soundData.fileName, soundData.event) or
                    soundData.fileName)
                soundData.length = length
                soundData.module = module
                return true
            end
        end
    end
    
    return false
end

function DataModules:addPlayerGenderToFilename(fileName)
    local playerGender = UnitSex("player")

    if playerGender == 2 then     -- male
        return "m-" .. fileName
    elseif playerGender == 3 then -- female
        return "f-" .. fileName
    else                          -- unknown or error
        return fileName
    end
end
