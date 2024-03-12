local ecs = ...
local world = ecs.world
local w = world.w

local imessage = ecs.require "message"
local imaterial = ecs.require "ant.render|material"
local iom = ecs.require "ant.objcontroller|obj_motion"

imessage:sub("show", function(instance, visible)
    for _, eid in ipairs(instance.tag['*']) do
        local e <close> = world:entity(eid, "visible?out")
        e.visible = visible
    end
end)

imessage:sub("material", function(instance, method, ...)
    for _, eid in ipairs(instance.tag['*']) do
        local e <close> = world:entity(eid, "material?in")
        if e.material then
            imaterial[method](e, ...)
        end
    end
end)

imessage:sub("obj_motion", function(instance, method, ...)
    for _, eid in ipairs(instance.noparent) do
        local e <close> = world:entity(eid)
        iom[method](e, ...)
    end
end)

imessage:sub("remove", function(instance)
    world:remove_instance(instance)
end)

return imessage
