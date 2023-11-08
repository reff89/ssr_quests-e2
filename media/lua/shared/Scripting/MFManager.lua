-- Copyright (c) 2022-2023 Oneline/D.Borovsky
-- All rights reserved
require "Scripting/ScriptManagerNeo"
require "Communications/QSystem"

MFManager = ScriptManagerNeo:derive("MFManager");
MFManager.initialized = false;
MFManager.instance = nil;
MFManager.error = false;

MFManager.templates = {};
function MFManager.getTemplate(name)
    for i=1, #MFManager.templates do
        if MFManager.templates[i].name == name then
            return MFManager.templates[i];
        end
    end
end

local function playScript(id)
    MFManager.instance.items[id].script:reset();
    QuestLogger.print("[QSystem*] MannequinFolks: "..MFManager.instance.items[id].script.file);
    while true do
        local result = MFManager.instance.items[id].script:play(MFManager.instance.items[id]);
        if result then
            if result ~= -1 then
                print(result);
            end
            break;
        end
    end
end

function MFManager.updateSpawnPoints(name, forced)
    if not forced then QuestLogger.mute = true; end
    local success = false;
    for i=1, MFManager.instance.items_size do
        if name == MFManager.instance.items[i].name or not name then
            if MFManager.instance.items[i].instance then
                if (not MFManager.instance.items[i].instance.javaObject and not MFManager.instance.items[i].forced) or forced then -- when object is out of range and pos isn't set by action/dialogue command
                    playScript(i);
                end
            else -- create instance if null
                playScript(i);
            end
            success = true;
            if name then break end
        end
    end
    QuestLogger.mute = false;

    return success;
end

local function getDistance(x1, y1, x2, y2)
    local absX = math.abs(x2 - x1);
    local absY = math.abs(y2 - y1);
    return math.sqrt(absX^2 + absY^2);
end

function MFManager.render()
    if MFManager.instance then
        for a=1, MFManager.instance.items_size do
            if MFManager.instance.items[a].instance then
                if MFManager.instance.items[a].instance.javaObject then
                    local attached = MFManager.instance.items[a].instance.javaObject:getAttachedAnimSprite();
                    if attached then
                        for i=0, attached:size()-1 do
                            local anim = attached:get(i);
                            local s = anim:getParentSprite();
                            s:update();
                        end
                    end
                end
            end
        end
    end
end

function MFManager.update()
    local square = getPlayer():getSquare();
    if square then
        for i=1, MFManager.instance.items_size do
            if MFManager.instance.items[i].instance then
                local distance = getDistance(square:getX(), square:getY(), MFManager.instance.items[i].instance.x, MFManager.instance.items[i].instance.y);
                if distance > 35 and MFManager.instance.items[i].instance.javaObject then
                    MFManager.instance.items[i].instance:despawn();
                elseif distance <= 30 and not MFManager.instance.items[i].instance.javaObject then
                    MFManager.instance.items[i].instance:spawn();
                end
            end
        end
    end
    --MFManager.render();
end

function MFManager:create(name, template, state, x, y, z, direction, forced)
    for i=1, self.items_size do
        if name == self.items[i].name then
            if self.items[i].instance then
                if self.items[i].instance.x ~= x or self.items[i].instance.y ~= y or self.items[i].instance.z ~= z or self.items[i].instance.template.name ~= template.name or self.items[i].instance.script:getAnimState() ~= state then
                    self.items[i].instance:despawn();
                    self.items[i].instance = MNPC:new(name, template, state, x, y, z, direction);
                    if DialoguePanel.instance and DialoguePanel.instance.sprite == "3D:"..self.items[i].name then
                        DialoguePanel.instance.sprite = nil;
                    end
                elseif self.items[i].instance.direction ~= direction then
                    self.items[i].instance:setDirection(direction);
                end
            else
                self.items[i].instance = MNPC:new(name, template, state, x, y, z, direction);
            end
            self.items[i].forced = forced;
            return;
        end
    end
end

function MFManager:remove(name, destroy)
    for i=1, self.items_size do
        if name == self.items[i].name and self.items[i].instance then
            self.items[i].instance:despawn();
            if destroy then
                self.items[i].instance = nil;
            end
            return;
        end
    end
end

function MFManager:removeAll(destroy)
    for i=1, self.items_size do
        if self.items[i].instance then
            self.items[i].instance:despawn();
            if destroy then
                self.items[i].instance = nil;
            end
        end
    end
end

function MFManager:exists(name)
    for i=1, self.items_size do
        if name == self.items[i].name then
            return true;
        end
    end
end

function MFManager:isState(character, state)
    for i=1, self.items_size do
        if character == self.items[i].name then
            if self.items[i].instance.state == state then
                return true;
            else
                return false;
            end
        end
    end
end

function MFManager:reportEvent(character, event)
    for i=1, self.items_size do
        if character == self.items[i].name then
            self.items[i].instance:reportEvent(event);
            return;
        end
    end
end

function MFManager:clearEvent(character, event)
    for i=1, self.items_size do
        if character == self.items[i].name then
            self.items[i].instance:clearEvent(event);
            return;
        end
    end
end

function MFManager:new()
    local o = ScriptManagerNeo:new("characters");
    setmetatable(o, self);
    self.__index = self;
    return o;
end

function MFManager.reset()
    if MFManager.instance then
        MFManager.instance:removeAll(true);
        MFManager.instance.items_size = 0;
        MFManager.instance.items = {};
    end
end

function MFManager.start()
    if not MFManager.initialized then
        SSRTimer.add_ms(MFManager.update, 100, true);
        SSRTimer.add_s(MFManager.updateSpawnPoints, 15, true);
        MFManager.initialized = true;
    end
end

function MFManager.load()
    if MFManager.instance and not MFManager.error then
        MFManager.instance.items = {};
        for i=1, CharacterManager.instance.items_size do
            local file = CharacterManager.instance.items[i].file;
            local mod = CharacterManager.instance.items[i].mod;
            local language = CharacterManager.instance.items[i].language;
            if file:ends_with(".txt") then
                local index = string.lastIndexOf(file, ".txt");
                file = string.sub(file, 1, index).."_pos.txt";
            end
            local npc = {};
            npc.name = tostring(CharacterManager.instance.items[i].name);
            npc.position = nil;
            npc.instance = nil;
            npc.character_id = i;
            npc.script = MFManager.instance:load_script(file, mod, true, language);
            npc.forced = false;
            npc.Type = "MannequinFolk";
            if npc.script then
                MFManager.instance.items_size = MFManager.instance.items_size + 1; MFManager.instance.items[MFManager.instance.items_size] = npc;
            end
        end
        MFManager.updateSpawnPoints();
    else
        QuestLogger.error = true;
    end
end

function MFManager.init()
    if not MFManager.instance then MFManager.instance = MFManager:new() end
    for i=1, #MFManager.templates do
        if MFManager.templates[i].script and MFManager.templates[i].script ~= "" then
            if not getScriptManager():getMannequinScript(tostring(MFManager.templates[i].script)) then
                print(string.format("[QSystem] (Error) MannequinFolks: Invalid script specified for template '%s'", tostring(MFManager.templates[i].name)));
                MFManager.error = true;
            end
        end
    end
    MFManager.load();
    if not isServer() then
        Events.OnQSystemStart.Add(MFManager.start);
    end
end

function MFManager.preinit()
    MFManager.instance = MFManager:new();
    for entry_id=1, #QImport.scripts do
        print(string.format("[QSystem] MannequinFolks: Loading data for plugin 'ssr-plugin-e2' from mod '%s'", tostring(QImport.scripts[entry_id].mod)));
        for i=1, #QImport.scripts[entry_id].char_data do
            local file = QImport.scripts[entry_id].char_data[i];
            if file:ends_with(".txt") then
                local index = string.lastIndexOf(file, ".txt");
                file = string.sub(file, 1, index).."_pos.txt";
            end
            MFManager.instance:load_script(file, QImport.scripts[entry_id].mod, true, QImport.scripts[entry_id].language)
        end
    end
end

if QSystem.validate("ssr-quests-e2") then
    Events.OnQSystemInit.Add(MFManager.init);
    Events.OnQSystemRestart.Add(MFManager.load); -- FIXME: probably need to update pos on OnQSystemUpdate event as well
    Events.OnQSystemReset.Add(MFManager.reset);

    if not isServer() then
        Events.OnQSystemPreInit.Add(MFManager.preinit);
    end
end