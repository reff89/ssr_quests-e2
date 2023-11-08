-- Copyright (c) 2022-2023 Oneline/D.Borovsky
-- All rights reserved
require "Scripting/Commands/CommandList_a"
require "UI/DialoguePanel"
require "Communications/QSystem"

if not QSystem.validate("ssr-quests-e2") then return end

local type_mf = "MannequinFolk";
local type_dialogue = "DialoguePanel";

-- allow execution of existing commands
for i=1, #CommandList_a do
    if CommandList_a[i].command == "is_flag" or CommandList_a[i].command == "set_flag" or CommandList_a[i].command == "jump" or CommandList_a[i].command == "is_quest" or CommandList_a[i].command == "is_task" or CommandList_a[i].command == "is_event" or CommandList_a[i].command == "is_stat" or CommandList_a[i].command == "is_time" or CommandList_a[i].command == "is_alive" or CommandList_a[i].command == "exit" then
        CommandList_a[i].supported[#CommandList_a[i].supported+1] = type_mf;
    end
end

local setModel = DialoguePanel.setModel;
function DialoguePanel:setModel(model)
    if model == "3D:Player" then
        return setModel(self, model);
    else
        local name = string.sub(model, 4);
        local desc, exists = false, false;
        for i=1, MFManager.instance.items_size do
            if name == MFManager.instance.items[i].name then
                if MFManager.instance.items[i].instance then
                    if MFManager.instance.items[i].instance.javaObject then
                        desc = MFManager.instance.items[i].instance.template.desc;
                    end
                end
                exists = true;
                break;
            end
        end
        if desc then
            self.model:setSurvivorDesc(desc);
            self.model:render();
            self.model:setVisible(true);
            self.sprite = model;
        elseif exists then
            QuestLogger.print("[QSystem*] DialoguePanel: Unable to create 3D portrait due to no instance of NPC '"..tostring(name).."' being spawned");
        else
            self:clearAvatar();
            return false;
        end
        return true;
    end
end

local function getDirection(dir)
    if dir == "N" then
        return IsoDirections.N;
    elseif dir == "NW" then
        return IsoDirections.NW;
    elseif dir == "W" then
        return IsoDirections.W;
    elseif dir == "SW" then
        return IsoDirections.SW;
    elseif dir == "S" then
        return IsoDirections.S;
    elseif dir == "SE" then
        return IsoDirections.SE;
    elseif dir == "E" then
        return IsoDirections.E;
    elseif dir == "NE" then
        return IsoDirections.NE;
    else
        return nil;
    end
end

-- npc_create name|template|state|x,y,z|dir
-- npc_create name|template|state|x,y,z|dir|forced
local npc_create = Command:derive("npc_create")
function npc_create:execute(sender)
    self:debug();
    -- N(0), NW(1), W(2), SW(3), S(4), SE(5), E(6), NE(7), Max(8);
    self.args[5] = getDirection(self.args[5]);
    if not self.args[5] then
        return "Invalid direction";
    end
    local coord = self.args[4]:ssplit(',');
    if #coord == 3 then
        for i=1, #coord do
            local status;
            status, coord[i] = pcall(tonumber, coord[i]);
            if not status or not coord[i] then
                return "Argument is not number";
            end
        end
    else
        return "Invalid argument";
    end
    if MFManager.instance:exists(self.args[1]) then
        local template = MFManager.getTemplate(self.args[2]);
        if template then
            if #self.args == 6 then
                if self.args[6] == "true" or self.args[6] == 1 then
                    self.args[6] = true;
                else
                    self.args[6] = false;
                end
                MFManager.instance:create(self.args[1], template, self.args[3], coord[1], coord[2], coord[3], self.args[5], self.args[6]);
            else
                MFManager.instance:create(self.args[1], template, self.args[3], coord[1], coord[2], coord[3], self.args[5]);
            end
        else
            return "Template '"..tostring(self.args[2]).."' not found";
        end
    else
        return "Character with name '"..tostring(self.args[1]).."' doesn't exist";
    end
end

-- npc_remove
-- npc_remove name
local npc_remove = Command:derive("npc_remove")
function npc_remove:execute(sender)
    self:debug();
    if #self.args == 0 then
        MFManager.instance:removeAll(true);
    elseif #self.args == 1 then
        MFManager.instance:remove(self.args[1], true);
    else
        return "Unexpected amount of arguments";
    end
end

-- npc_update name
local npc_update = Command:derive("npc_update")
function npc_update:execute(sender)
    self:debug();
    if not MFManager.instance.updateSpawnPoints(self.args[1], true) then
        return "Invalid npc name specified";
    end
end

CommandList_a[#CommandList_a+1] = npc_create:new("npc_create", 5, 6, {type_mf, type_dialogue});
CommandList_a[#CommandList_a+1] = npc_remove:new("npc_remove", 0, 1, {type_dialogue});
CommandList_a[#CommandList_a+1] = npc_update:new("npc_update", 1, nil, {type_dialogue});

-- is_state character_name|state
local is_state = Command:derive("is_state")
function is_state:execute(sender)
    self:debug();
    if not MFManager.instance:isState(self.args[1], self.args[2]) then
        QuestLogger.print("[QSystem*] #is_state: Skipping block due to state not being equal \""..tostring(self.args[2]))
        sender.script.skip = sender.script.layer+1;
    end
end

CommandList_a[#CommandList_a+1] = is_state:new("is_state", 2, nil, {type_mf, type_dialogue});