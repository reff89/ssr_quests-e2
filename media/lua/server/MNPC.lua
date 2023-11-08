-- Copyright (c) 2022-2023 Oneline/D.Borovsky
-- All rights reserved
require "BuildingObjects/ISBuildingObject"
require "BuildingObjects/ISDestroyCursor"
require "BuildingObjects/ISMoveableCursor"

-- Remove NPCs from Movable and Sledgehammer lists
local ISMoveableCursor_getObjectList = ISMoveableCursor.getObjectList;
function ISMoveableCursor:getObjectList() -- Pick up
    local objects = ISMoveableCursor_getObjectList(self);
    for i=#objects, 1, -1 do
        local name = objects[i].object:getName() or "";
        if string.starts_with(name, "NPC_") then
            table.remove(objects, i);
        end
    end
    return objects;
end

local ISMoveableCursor_getScrapObjectList = ISMoveableCursor.getScrapObjectList;
function ISMoveableCursor:getScrapObjectList() -- Scrap
    local objects = ISMoveableCursor_getScrapObjectList(self);
    for i=#objects, 1, -1 do
        local name = objects[i].object:getName() or "";
        if string.starts_with(name, "NPC_") then
            table.remove(objects, i);
        end
    end
    return objects;
end

local ISMoveableCursor_getRotateableObject = ISMoveableCursor.getRotateableObject;
function ISMoveableCursor:getRotateableObject() -- Rotate
    local object = ISMoveableCursor_getRotateableObject(self);
    if object then
        local name = object.object:getName() or "";
        if string.starts_with(name, "NPC_") then
            return false;
        end
    end
    return object;
end

local ISDestroyCursor_canDestroy = ISDestroyCursor.canDestroy;
function ISDestroyCursor:canDestroy(object) -- Destroy
    if ISDestroyCursor_canDestroy(self, object) then
        local name = object:getName() or "";
        if string.starts_with(name, "NPC_") then
            return false;
        end
        return true;
    else
        return false;
    end
end


MNPC = ISBuildingObject:derive("MNPC");

local function createSurvivorDesc(name, mannequin, template, isFemale)
    local desc = SurvivorFactory.CreateSurvivor();
    if isFemale then
        desc:setFemale(true);
        desc:getExtras():clear();
    else
        desc:setFemale(false);
    end -- remove the beard
    local visual = mannequin:getHumanVisual();
    desc:getHumanVisual():copyFrom(visual);
    for i=1, #template.clothes do
        if type(template.clothes[i]) == "string" then
            local item = InventoryItemFactory.CreateItem(template.clothes[i])
            if item then
                desc:setWornItem(item:getBodyLocation(), item);
                --QuestLogger.print("[QSystem*] MannequinFolks: Added clothing item - "..tostring(template.clothes[i]));
            else
                print("[QSystem] (Error) MannequinFolks: Unknown item - "..tostring(template.clothes[i]));
            end
        elseif type(template.clothes[i]) == "table" then
            local item = InventoryItemFactory.CreateItem(template.clothes[i][1])
            if item then
                if item:getVisual() then
                    for j=2, #template.clothes[i] do
                        if type(template.clothes[i][j]) == "number" then
                            local choices = item:getVisual():getClothingItem():getTextureChoices():size();
                            if template.clothes[i][j] > -1 and template.clothes[i][j] < choices then
                                item:getVisual():setTextureChoice(template.clothes[i][j])
                            end
                        elseif type(template.clothes[i][j]) == "table" then
                            if #template.clothes[i][j] == 3 then
                                local color = ImmutableColor.new(template.clothes[i][j][1], template.clothes[i][j][2], template.clothes[i][j][3], 1);
                                if color then
                                    item:getVisual():setTint(color);
                                end
                            end
                        end
                    end
                    desc:setWornItem(item:getBodyLocation(), item);
                end
                --QuestLogger.print("[QSystem*] MannequinFolks: Added clothing item - "..tostring(template.clothes[i][1]));
            else
                print("[QSystem] (Error) MannequinFolks: Unknown item - "..tostring(template.clothes[i][1]));
            end
        end
    end
    template.desc = desc;
end

local function dress(name, mannequin, template)
    local visual = mannequin:getHumanVisual();
    --QuestLogger.print("[QSystem*] MannequinFolks: Applying visuals for NPC - "..tostring(name));
    if type(template.skin) == "table" then
        local color = ImmutableColor.new(template.skin[1], template.skin[2], template.skin[3], 1);
        if color then
            visual:setSkinColor(color);
        end
        --QuestLogger.print(string.format("[QSystem*] MannequinFolks: Changed skin color to %.2f, %.2f, %.2f", template.skin[1], template.skin[2], template.skin[3]));
    end

    local color = ImmutableColor.new(0, 0, 0, 1);
    if template.haircut then
        if type(template.haircut) == "table" then
            visual:setHairModel(template.haircut[1]);
            color = template.haircut[2] and ImmutableColor.new(template.haircut[2][1], template.haircut[2][2], template.haircut[2][3], 1) or color;
            --QuestLogger.print("[QSystem*] MannequinFolks: Changed haircut to "..tostring(template.haircut[1]));
        elseif type(template.haircut) == "string" then
            visual:setHairModel(template.haircut);
            --QuestLogger.print("[QSystem*] MannequinFolks: Changed haircut to "..tostring(template.haircut));
        end
        if color then
            visual:setNaturalHairColor(color);
            visual:setHairColor(color);
        end
    end

    if template.beard then
        if type(template.beard) == "table" then
            visual:setBeardModel(template.beard[1])
            color = template.beard[2] and ImmutableColor.new(template.beard[2][1], template.beard[2][2], template.beard[2][3], 1) or color;
            --QuestLogger.print("[QSystem*] MannequinFolks: Changed beard to "..tostring(template.beard[1]));
        elseif type(template.beard) == "string" then
            visual:setBeardModel(template.beard)
            --QuestLogger.print("[QSystem*] MannequinFolks: Changed beard to "..tostring(template.beard));
        end
        if color then
            visual:setNaturalBeardColor(color);
            visual:setBeardColor(color);
        end
    end

    if type(template.clothes) == "table" then
        for i=1, #template.clothes do
            if type(template.clothes[i]) == "string" then
                local item = InventoryItemFactory.CreateItem(template.clothes[i])
                if item then
                    mannequin:getContainer():getItems():add(item);
                    mannequin:wearItem(item, nil);
                    --QuestLogger.print("[QSystem*] MannequinFolks: Added clothing item - "..tostring(template.clothes[i]));
                else
                    print("[QSystem] (Error) MannequinFolks: Unknown item - "..tostring(template.clothes[i]));
                end
            elseif type(template.clothes[i]) == "table" then
                local item = InventoryItemFactory.CreateItem(template.clothes[i][1])
                if item then
                    if item:getVisual() then
                        for j=2, #template.clothes[i] do
                            if type(template.clothes[i][j]) == "number" then
                                local choices = item:getVisual():getClothingItem():getTextureChoices():size();
                                if template.clothes[i][j] > -1 and template.clothes[i][j] < choices then
                                    item:getVisual():setTextureChoice(template.clothes[i][j])
                                end
                            elseif type(template.clothes[i][j]) == "table" then
                                if #template.clothes[i][j] == 3 then
                                    local color = ImmutableColor.new(template.clothes[i][j][1], template.clothes[i][j][2], template.clothes[i][j][3], 1);
                                    if color then
                                        item:getVisual():setTint(color);
                                    end
                                end
                            end
                        end
                        mannequin:getContainer():getItems():add(item);
                        mannequin:wearItem(item, nil);
                        --QuestLogger.print("[QSystem*] MannequinFolks: Added clothing item - "..tostring(template.clothes[i][1]));
                    end
                else
                    print("[QSystem] (Error) MannequinFolks: Unknown item - "..tostring(template.clothes[i][1]));
                end
            end
        end
    end
end

function MNPC:setDirection(direction)
    if self.javaObject and direction then
        self.javaObject:setDir(direction);
        self.direction = direction;
    end
end

function MNPC:reportEvent(event) -- switch animation state
    if self.javaObject then
        local animatedModel = self.javaObject:getAnimatedModel();
        if animatedModel then
            local context = animatedModel:getActionContext();
            if context then
                --context:reportEvent(0, event); -- FIXME: unimplemented (wait until TIS exposes more fields in IsoMannequin)
            end
        end
    end
end

function MNPC:clearEvent(event) -- remove occured event from list
    if self.javaObject then
        local animatedModel = self.javaObject:getAnimatedModel();
        if animatedModel then
            local context = animatedModel:getActionContext();
            if context then
                --context:clearEvent(event); -- FIXME: unimplemented (wait until TIS exposes more fields in IsoMannequin)
            end
        end
    end
end

function MNPC:invalidate()
    if self.script then
        if self.script:getAnimState() ~= self.state then
            self.script:setAnimState(self.state);
        end
    end
end

function MNPC:spawn()
    if self.javaObject then
        self:despawn();
    end
    self.sq = getWorld():getCell():getGridSquare(self.x, self.y, self.z);

    if self.sq and self.script then
        local sprite = self.script:isFemale() and "location_shop_mall_01_65" or "location_shop_mall_01_68";
        self.javaObject = IsoMannequin.new(getCell(), self.sq, getSprite(sprite))
        if self.javaObject then
            self.javaObject:setMannequinScriptName(self.script:getName())
            self.javaObject:setDir(self.direction);
            self.javaObject:setName("NPC_"..self.name);
            dress(self.name, self.javaObject, self.template);
            self.javaObject:removeAllContainers();
            --self.javaObject:setAnimate(true); -- enable animation
            self:invalidate();
            if not self.template.desc then createSurvivorDesc(self.name, self.javaObject, self.template, self.script:isFemale()) end
            self.sq:AddSpecialObject(self.javaObject);
            print("[QSystem] MannequinFolks: Added character '"..tostring(self.name).."' to square "..tostring(self.sq:getX())..", "..tostring(self.sq:getY())..", "..tostring(self.sq:getZ()));
            MFDuplicateRemoval.addSquare(self.sq);
            --self:reportEvent(self.script:getAnimState());
        else
            print("[QSystem] (Error) MannequinFolks: Java Object is NULL. "..self.info);
        end
    else
        print("[QSystem] (Error) MannequinFolks: Grid Square is NULL. "..self.info);
    end
end

function MNPC:despawn()
    if self.javaObject then
        if self.sq then
            self.javaObject:removeFromSquare();
            self.javaObject = nil;
            print("[QSystem] MannequinFolks: Removed character '"..tostring(self.name).."' from square "..tostring(self.sq:getX())..", "..tostring(self.sq:getY())..", "..tostring(self.sq:getZ()));
            MFDuplicateRemoval.clearSquare(self.sq);
        else
            self.sq = getWorld():getCell():getGridSquare(self.x, self.y, self.z);
        end
    end
end

function MNPC:new(name, template, state, x, y, z, direction)
    local o = {};
    setmetatable(o, self);
    self.__index = self;
    o:init();
    o.template = template;
    o.state = state;
    o.script = getScriptManager():getMannequinScript(template.script);
    o.animation = {};
    o.name = name or "none";
    o.x = x;
    o.y = y;
    o.z = z;
    o.direction = direction or IsoDirections.SE; -- N(0), NW(1), W(2), SW(3), S(4), SE(5), E(6), NE(7), Max(8);
    o.info = string.format("name='%s', template='%s', state='%s', x=%i, y=%i, z=%i", o.name, tostring(template.name), tostring(state), x, y, z);
    return o;
end

function MNPC:getHealth()
    return 100;
end

function MNPC:isValid(square)
    return true;
end

function MNPC:render(x, y, z, square)
    ISBuildingObject.render(self, x, y, z, square)
end
