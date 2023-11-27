local ecs = ...
local world = ecs.world

local BUILDING_EFK_SCALE <const> = {
    ["1x1"] = {4, 4, 4},
    ["1x2"] = {5, 5, 5},
    ["2x1"] = {5, 5, 5},
    ["2x2"] = {5, 5, 5},
    ["3x2"] = {7, 7, 7},
    ["3x3"] = {7, 7, 7},
    ["3x5"] = {10, 10, 10},
    ["4x2"] = {7, 7, 7},
    ["4x4"] = {10, 10, 10},
    ["5x3"] = {10, 10, 10},
    ["5x5"] = {12, 12, 12},
    ["6x6"] = {12, 12, 12},
}

local vsobject_manager = ecs.require "vsobject_manager"
local iprototype = require "gameplay.interface.prototype"
local iefk = ecs.require "engine.system.efk"
local math3d = require "math3d"
local icoord = require "coord"
local igroup = ecs.require "group"
local changeset = {}
local removed = {}

local _new_object_id; do
    local id = 0
    function _new_object_id()
        id = id + 1
        return id
    end
end

local mt = {
    __index = function(t, k)
        return t.__lastversion[k]
    end,
    __newindex = function(t, k, v)
        t.__change_keys[k] = true
        t.__lastversion[k] = v
        changeset[t.__lastversion.id] = t
    end,
    __pairs = function (t)
        return function(t, key)
            return next(t.__lastversion, key)
        end, t
    end,
}

local function new(init)
    local t = {}
    t.__change_keys = {}
	t.__lastversion = {
        id = _new_object_id(),
        prototype_name = assert(init.prototype_name),
        dir = assert(init.dir), 
        x = assert(init.x),
        y = assert(init.y),
        fluid_name = init.fluid_name,
        srt = init.srt,
        group_id = init.group_id,
        items = init.items,
        debris = init.debris,
    }

    local outer = setmetatable(t, mt)
    changeset[t.__lastversion.id] = outer
    return outer
end

local function clone(outer)
    local t = {}
    t.__change_keys = {}
	t.__lastversion = {
        id = outer.id or _new_object_id(),
        prototype_name = assert(outer.prototype_name),
        dir = assert(outer.dir),
        x = assert(outer.x),
        y = assert(outer.y),
        fluid_name = outer.fluid_name,
        gameplay_eid = outer.gameplay_eid,
        srt = outer.srt,
        group_id = outer.group_id,
    }

    local outer = setmetatable(t, mt)
    changeset[t.__lastversion.id] = outer
    return outer
end

local function remove(outer)
    if not outer then
        return
    end

    removed[outer.id] = true
end

local function flush()
    local funcs = {
        prototype_name = function(outer)
            local vsobject = assert(vsobject_manager:get(outer.id))
            vsobject:update {prototype_name = outer.prototype_name, srt = outer.srt}
        end,
        dir = function(outer)
            local vsobject = assert(vsobject_manager:get(outer.id))
            vsobject:set_dir(outer.dir)
        end,
        srt = function(outer)
            local vsobject = assert(vsobject_manager:get(outer.id))
            vsobject:set_position(outer.srt.t)
        end,
    }

    local prepare = {}
    local appear = {}

    local vsobject
    for object_id, outer in pairs(changeset) do
        if removed[object_id] then
            goto continue
        end
        vsobject = vsobject_manager:get(object_id)
        outer.srt = outer.srt or {}

        if not vsobject then
            vsobject = vsobject_manager:create {
                id = outer.id,
                prototype_name = outer.prototype_name,
                dir = outer.dir,
                position = outer.srt.t,
                group_id = outer.group_id or igroup.id(outer.x, outer.y),
                debris = outer.debris,
            }
        else
            for k in pairs(outer.__change_keys) do
                local func = funcs[k]
                if func then
                    func(outer)
                end
            end
        end

        if outer.PREPARE then
            prepare[#prepare+1] = outer
            outer.PREPARE = nil
        end

        if outer.APPEAR then
            appear[#appear+1] = outer
            outer.APPEAR = nil
        end

        outer.__change_keys = {}
        ::continue::
    end
    changeset = {}

    for object_id in pairs(removed) do
        vsobject_manager:remove(object_id)
    end
    removed = {}

    for _, outer in ipairs(prepare) do
        local vsobject = vsobject_manager:get(outer.id)
        if vsobject then
            vsobject:modifier("start_bone_modifier", {name = "confirm"})

            local typeobject = iprototype.queryByName(outer.prototype_name)
            local w, h = iprototype.rotate_area(typeobject.area, outer.dir)
            local scale = assert(BUILDING_EFK_SCALE[w.."x"..h])
            iefk.play("/pkg/vaststars.resources/effects/building-animat.efk", {s = scale, t = outer.srt.t})
        end
    end

    for _, outer in ipairs(appear) do
        local vsobject = vsobject_manager:get(outer.id)
        if vsobject then
            vsobject:modifier("start_bone_modifier", {name = "appear", forwards = true})
        end
    end
end

local function move_delta(object, delta_vec)
    local vsobject = vsobject_manager:get(object.id)
    if not vsobject then
        return
    end

    local typeobject = iprototype.queryByName(object.prototype_name)
    local position = math3d.add(object.srt.t, delta_vec)
    local coord = icoord.align(position, iprototype.rotate_area(typeobject.area, object.dir))
    if not coord then
        log.error(("can not get coord"))
        return
    end

    object.x, object.y = coord[1], coord[2]
    object.srt.t = position
    return object
end

local function coord(object, x, y)
    assert(object)
    assert(object.prototype_name ~= "")
    local typeobject = iprototype.queryByName(object.prototype_name)
    local position = math3d.vector(icoord.position(x, y, iprototype.rotate_area(typeobject.area, object.dir)))
    if not position then
        log.error(("can not get position"))
        return
    end
    object.x, object.y = x, y
    object.srt.t = position
end

return {
    new = new,
    new_object_id = _new_object_id,
    clone = clone,
    flush = flush,
    move_delta = move_delta,
    coord = coord,
    remove = remove,
}