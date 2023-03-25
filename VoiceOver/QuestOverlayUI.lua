local _G = _G

QuestOverlayUI = {}
QuestOverlayUI.__index = QuestOverlayUI

function QuestOverlayUI:new(soundQueue)
    local questOverlayUI = {}
    setmetatable(questOverlayUI, QuestOverlayUI)

    questOverlayUI.soundQueue = soundQueue
    questOverlayUI.questPlayButtons = {}

    return questOverlayUI
end

function QuestOverlayUI:createPlayButton(questIndex, questLogTitleFrame)
    local playButton = CreateFrame("Button", nil, questLogTitleFrame, "UIPanelButtonTemplate")
    playButton:SetWidth(15)
    playButton:SetHeight(15)
    playButton:SetPoint("LEFT", questLogTitleFrame, "LEFT", 215, 0)
    playButton:SetNormalTexture("Interface\\Buttons\\UI-SpellbookIcon-NextPage-Up")
    self.questPlayButtons[questIndex] = playButton
end

function QuestOverlayUI:updatePlayButton(soundTitle, questID, questIndex)
    self.questPlayButtons[questIndex]:SetScript("OnClick", function()
        local soundData = {
            ["fileName"] = questID .. "-accept",
            ["questId"] = questID,
            ["title"] = soundTitle,
            ["unitGuid"] = QuestlogNpcGuidTable[questID]
        }
        self.soundQueue:addSoundToQueue(soundData)
    end)
end

function QuestOverlayUI:updateQuestOverlayUI()
    local numEntries, numQuests = GetNumQuestLogEntries()
    if numEntries == 0 then
        return
    end

    -- Traverse through the quests displayed in the UI
    for i = 1, QUESTS_DISPLAYED do
        local questIndex = i + FauxScrollFrame_GetOffset(QuestLogListScrollFrame)
        if questIndex > numEntries then
            break
        end

        -- Get quest title
        local questLogTitleFrame = _G["QuestLogTitle" .. i]
        local title, level, suggestedGroup, isHeader, isCollapsed, isComplete, frequency, questID = GetQuestLogTitle(
            questIndex)

        if isHeader then
            if self.questPlayButtons[questIndex] then
                self.questPlayButtons[questIndex]:Hide()
            end
        else
            if not self.questPlayButtons[questIndex] then
                self:createPlayButton(questIndex, questLogTitleFrame)
            end

            self:updatePlayButton(title, questID, questIndex)
            self.questPlayButtons[questIndex]:Show()
        end

    end
end