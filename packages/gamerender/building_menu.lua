local ecs = ...

local global = require "global"
local cache_names = global.cache_names
local objects = global.objects
local vsobject_manager = ecs.require "vsobject_manager"
local general = require "gameplay.utility.general"
local rotate_area = general.rotate_area
local dir_tonumber = general.dir_tonumber
local rotate_dir_times = general.rotate_dir_times
local terrain = ecs.require "terrain"
local gameplay_core = require "gameplay.core"
local prototype_api = require "gameplay.prototype"

local M = {}

function M:rotate_object(id)
    local object = assert(objects:get(cache_names, id))
    local vsobject = assert(vsobject_manager:get(id))
    local dir = rotate_dir_times(object.dir, -1)

    local typeobject = prototype_api.queryByName("entity", object.prototype_name)
    local _, position = terrain.adjust_position_by_coord(object.x, object.y, vsobject:get_position(), rotate_area(typeobject.area, dir))
    if not position then
        return
    end

    local e = gameplay_core.query_entity("entity:in", object.x, object.y)
    if e then
        e.entity.direction = dir_tonumber(dir)
        gameplay_core.sync("entity:out", e)
    else
        log.error(("can not found entity (%s, %s)"):format(object.x, object.y))
    end

    object.dir = dir
    vsobject:set_position(position)
    vsobject:set_dir(object.dir)

    gameplay_core.build()
end

function M:set_recipe(id, recipe_name)
    local object = assert(objects:get(cache_names, id))
    local e = gameplay_core.query_entity("entity:in assembling?in fluidboxes:in", object.x, object.y)
    if e.assembling then
        gameplay_core.set_recipe(e, recipe_name)
        gameplay_core.build()
    else
        log.error(("can not found assembling `%s`(%s, %s)"):format(object.name, object.x, object.y))
    end
end
return M