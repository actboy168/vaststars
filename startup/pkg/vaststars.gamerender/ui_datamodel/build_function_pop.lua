local ecs, mailbox = ...
local world = ecs.world
local w = world.w

local gameplay_core = require "gameplay.core"
local objects = require "objects"
local iprototype = require "gameplay.interface.prototype"
local vsobject_manager = ecs.require "vsobject_manager"
local iui = ecs.import.interface "vaststars.gamerender|iui"

local set_recipe_mb = mailbox:sub {"set_recipe"}
local detail_mb = mailbox:sub {"detail"}
local close_mb = mailbox:sub {"close"}
local teardown_mb = mailbox:sub {"teardown"}
local move_mb = mailbox:sub {"move"}
local road_builder_mb = mailbox:sub {"road_builder"}
local pipe_builder_mb = mailbox:sub {"pipe_builder"}
local igameplay = ecs.import.interface "vaststars.gamerender|igameplay"
local iobject = ecs.require "object"
local ichest = require "gameplay.interface.chest"
local ipower = ecs.require "power"
local ipower_line = ecs.require "power_line"
local assembling_common = require "ui_datamodel.common.assembling"

-- An object may contain multiple types at the same time
-- The types are listed in order, with the earlier ones taking precedence over the later ones
local detail_rml = {
    {
        type = "station",
        rml = "logistic_center.rml",
    },
    {
        type = "lorry_factory",
        rml = "assemble.rml",
    },
    {
        type = "assembling",
        rml = "assemble.rml",
    },
    {
        type = "chest",
        rml = "chest.rml",
    },
    {
        type = "base",
        rml = "chest.rml",
    },
    {
        type = "laboratory",
        rml = "lab.rml",
    },
}

local function __get_detail_rml(typeobject)
    if typeobject.build_center == true then
        return
    end

    for _, v in ipairs(detail_rml) do
        if iprototype.has_type(typeobject.type, v.type) then
            return v.rml
        end
    end
    return nil
end

local function __show_detail(typeobject)
    if typeobject.show_detail == false then
        return false
    end
    return __get_detail_rml(typeobject) ~= nil
end

local function __show_set_recipe(typeobject)
    if typeobject.build_center == true then
        return true
    end

    if not iprototype.has_type(typeobject.type, "assembling") and
       not iprototype.has_type(typeobject.type, "lorry_factory") then
        return false
    end

    return typeobject.recipe == nil and not iprototype.has_type(typeobject.type, "mining")
end

---------------
local M = {}
local current_object_id
function M:create(object_id, object_position, ui_x, ui_y)
    if current_object_id and current_object_id ~= object_id then
        local vsobject = vsobject_manager:get(current_object_id)
        if vsobject then -- current_object_id may be destroyed
            vsobject:modifier("start", {name = "over", forwards = true})
        end
    end
    if current_object_id ~= object_id then
        local vsobject = vsobject_manager:get(object_id)
        vsobject:modifier("start", {name = "talk", forwards = true})
    end
    current_object_id = object_id
    local object = assert(objects:get(object_id))
    local e = gameplay_core.get_entity(assert(object.gameplay_eid))
    if not e then
        return
    end
    local typeobject = iprototype.queryByName(object.prototype_name)

    -- 组装机才显示设置配方菜单
    local show_set_recipe = __show_set_recipe(typeobject)
    local show_detail = __show_detail(typeobject)
    local recipe_name = ""

    if iprototype.has_type(typeobject.type, "assembling") or iprototype.has_type(typeobject.type, "lorry_factory") then
        if e.assembling.recipe ~= 0 then
            local recipe_typeobject = iprototype.queryById(e.assembling.recipe)
            recipe_name = recipe_typeobject.name
        end
    end

    local build_center_icon, build_center_count, build_center_ingredients
    if typeobject.build_center == true then
        if e.assembling.recipe == 0 then
            build_center_icon = "textures/assemble/setup2.texture"
            build_center_count = 0
        else
            local results
            build_center_ingredients, results = assembling_common.get(gameplay_core.get_world(), e)
            assert(results and results[1])
            build_center_icon = results[1].icon
            build_center_count = results[1].count
        end
    end

    return {
        show_teardown = false,
        show_move = false,
        show_set_recipe = show_set_recipe,
        show_road_builder = typeobject.road_builder,
        show_pipe_builder = typeobject.pipe_builder,
        build_center_icon = build_center_icon,
        build_center_count = build_center_count,
        build_center_ingredients = build_center_ingredients,
        show_detail = show_detail,
        recipe_name = recipe_name,
        object_id = object_id,
        left = ui_x,
        top = ui_y,
        object_position = object_position,
    }
end

local function __build_center_update(datamodel, object_id)
    local object = assert(objects:get(object_id))
    local e = gameplay_core.get_entity(assert(object.gameplay_eid))
    if not e then
        return
    end
    local typeobject = iprototype.queryByName(object.prototype_name)
    local build_center_icon, build_center_count, build_center_ingredients
    if typeobject.build_center == true then
        if e.assembling.recipe == 0 then
            build_center_icon = "textures/assemble/setup2.texture"
            build_center_count = 0
        else
            local results
            build_center_ingredients, results = assembling_common.get(gameplay_core.get_world(), e)
            assert(results and results[1])
            build_center_icon = results[1].icon
            build_center_count = results[1].count
        end
    end
    datamodel.build_center_icon = build_center_icon
    datamodel.build_center_count = build_center_count
    datamodel.build_center_ingredients = build_center_ingredients

end

function M:update(datamodel, object_id, recipe_name)
    if datamodel.object_id ~= object_id then
        return
    end
    datamodel.recipe_name = recipe_name
    __build_center_update(datamodel, object_id)
    return true
end

function M:stage_ui_update(datamodel, object_id)
    -- show pickup material button when object has result
    local object = objects:get(object_id)
    if not object then
        assert(false)
    end

    __build_center_update(datamodel, object_id)

    for _, _, _, object_id in set_recipe_mb:unpack() do
        local object = assert(objects:get(object_id))
        local typeobject = iprototype.queryByName(object.prototype_name)
        if typeobject.build_center == true then
            iui.open({"build_center.rml"}, object_id)
        else
            iui.open({"recipe_pop.rml"}, object_id)
        end
    end

    for _, _, _, object_id in detail_mb:unpack() do
        local object = assert(objects:get(object_id))
        local typeobject = iprototype.queryByName(object.prototype_name)
        local rml = __get_detail_rml(typeobject)
        if rml then
            iui.open({rml}, object_id)
        end
    end

    for _, _, _, object_id in teardown_mb:unpack() do
        local object = assert(objects:get(object_id))
        igameplay.remove_entity(object.gameplay_eid)
        gameplay_core.build()

        iobject.remove(object)
        objects:remove(object_id, "CONSTRUCTED")
        iui.close("build_function_pop.rml")
        iui.close("detail_panel.rml")

        local typeobject_item = iprototype.queryByName(object.prototype_name)
        if typeobject_item then
            ichest.base_chest_place(gameplay_core.get_world(), typeobject_item.id, 1)
        end

        local typeobject_entity = iprototype.queryByName(object.prototype_name)
        if typeobject_entity.power_supply_area then
            ipower:build_power_network(gameplay_core.get_world())
            ipower_line.update_line(ipower:get_pole_lines())
        end
    end

    for _, _, _, object_id in move_mb:unpack() do
        iui.close("build_function_pop.rml")
        iui.close("detail_panel.rml")

        local vsobject = vsobject_manager:get(object_id)
        vsobject:modifier("start", {name = "over", forwards = true})

        iui.redirect("construct.rml", "move", object_id)
    end

    for _, _, _, object_id in close_mb:unpack() do
        local vsobject = vsobject_manager:get(object_id)
        vsobject:modifier("start", {name = "over", forwards = true})
    end

    for _, _, _, object_id in road_builder_mb:unpack() do
        iui.redirect("construct.rml", "road_builder", object_id)
    end

    for _, _, _, object_id in pipe_builder_mb:unpack() do
        iui.redirect("construct.rml", "pipe_builder", object_id)
    end
end

return M