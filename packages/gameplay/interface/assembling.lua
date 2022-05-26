local prototype = require "prototype"
local query = require "prototype".queryById
local fluidbox = require "interface.fluidbox"

local STATUS_IDLE <const> = 0
local STATUS_DONE <const> = 1

local IN <const> = 0
local OUT <const> = 1
local INOUT <const> = 2

local PipeEdgeType <const> = {
    ["input"] = IN,
    ["output"] = OUT,
    ["input-output"] = INOUT,
}

local function isFluidId(id)
    return id & 0x0C00 == 0x0C00
end

local function findFluidbox(init, id)
    local name = query(id).name
    for i, v in ipairs(init) do
        if name == v then
            return i
        end
    end
    return 0
end

local function needRecipeLimit(fb)
    for _, conn in ipairs(fb.connections) do
        local type = PipeEdgeType[conn.type]
        if type == INOUT or type == OUT then
            return false
        end
    end
    return true
end

local function createContainerAndFluidBox(init, fluidboxes, s, max, needlimit)
    s = s:sub(5)
    assert(#s <= 4 * 15)
    local container = {}
    local fluids = {}
    for idx = 1, #s//4 do
        local id, n = string.unpack("<I2I2", s, 4*idx-3)
        local limit = 0
        if isFluidId(id) then
            local fluid_idx = findFluidbox(init, id)
            if fluid_idx > max then
                error "The assembling does not support this recipe."
            end
            fluids[fluid_idx] = idx
            local fb = fluidboxes[fluid_idx]
            if needlimit and needRecipeLimit(fb) then
                limit = n * 2
            else
                limit = fb.capacity
            end
        else
            limit = n * 2
        end
        container[#container+1] = string.pack("<I2I2", id, limit)
    end
    container = table.concat(container)
    for i = 1, max do
        fluids[i] = fluids[i] or 0
    end
    local fb = 0
    for i = max, 1, -1 do
        fb = (fb << 4) | fluids[i]
    end
    return container, fb
end

local function createContainer(s)
    local container = {}
    for idx = 2, #s//4 do
        local id, n = string.unpack("<I2I2", s, 4*idx-3)
        assert(not isFluidId(id))
        local limit = n * 2
        container[#container+1] = string.pack("<I2I2", id, limit)
    end
    return table.concat(container)
end

local function set_recipe(world, e, pt, recipe_name, fluids)
    local assembling = e.assembling
    assembling.progress = 0
    assembling.status = STATUS_IDLE
    fluidbox.update_fluidboxes(e, pt, fluids)
    if recipe_name == nil then
        assembling.recipe = 0
        assembling.container = 0xffff
        assembling.fluidbox_in = 0
        assembling.fluidbox_out = 0
        return
    end
    local recipe = assert(prototype.query("recipe", recipe_name), "unknown recipe: "..recipe_name)
    if not fluids or not pt.fluidboxes then
        local container_in = createContainer(recipe.ingredients)
        local container_out = createContainer(recipe.results)
        assembling.recipe = recipe.id
        assembling.container = world:container_create("assembling", container_in, container_out)
        assembling.fluidbox_in = 0
        assembling.fluidbox_out = 0
        return
    end
    local needlimit = #pt.fluidboxes.input > 0
    local container_in, fluidbox_in = createContainerAndFluidBox(fluids.input, pt.fluidboxes.input, recipe.ingredients, 4, needlimit)
    local container_out, fluidbox_out = createContainerAndFluidBox(fluids.output, pt.fluidboxes.output, recipe.results, 3, needlimit)
    assembling.recipe = recipe.id
    assembling.container = world:container_create("assembling", container_in, container_out)
    assembling.fluidbox_in = fluidbox_in
    assembling.fluidbox_out = fluidbox_out
end

local function set_direction(_, e, dir)
    local DIRECTION <const> = {
        N = 0, North = 0,
        E = 1, East  = 1,
        S = 2, South = 2,
        W = 3, West  = 3,
    }
    local d = assert(DIRECTION[dir])
    local entity = e.entity
    if entity.direction ~= d then
        entity.direction = d
        e.fluidbox_changed = true
    end
end

local function what_status(e)
    --TODO
    --  no_power
    --  disabled
    --  no_minable_resources
    local a = e.assembling
    if a.recipe == 0 then
        return "idle"
    end
    if a.progress <= 0 then
        if a.status == STATUS_IDLE then
            return "insufficient_input"
        elseif a.status == STATUS_DONE then
            return "full_output"
        end
    end
    if a.low_power ~= 0 then
        return "low_power"
    end
    return "working"
end

return {
    set_recipe = set_recipe,
    set_direction = set_direction,
    what_status = what_status,
}
