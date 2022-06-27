local ecs, mailbox = ...
local world = ecs.world
local w = world.w

local save_mb = mailbox:sub {"save"}
local restore_mb = mailbox:sub {"restore"}
local restart_mb = mailbox:sub {"restart"}
local close_mb = mailbox:sub {"close"}

local camera = ecs.require "engine.camera"
local saveload = ecs.require "saveload"
local iui = ecs.import.interface "vaststars.gamerender|iui"

---------------
local M = {}

function M:create()
    local archival_files = {}
    for _, v in ipairs(saveload:get_archival_list()) do
        archival_files[#archival_files+1] = v.dir
    end
    return {
        archival_files = archival_files,
    }
end

function M:stage_camera_usage()
    for _ in save_mb:unpack() do -- 存档时会保存摄像机的位置
        saveload:backup()
    end

    for _, _, _, index in restore_mb:unpack() do -- 读档时会还原摄像机的位置
        if saveload:restore(index) then
            iui.close("option_pop.rml")
        end
    end

    for _ in restart_mb:unpack() do
        camera.init("camera_default.prefab")
        saveload:restart()
    end

    for _ in close_mb:unpack() do
        if saveload.running then
            iui.close("option_pop.rml")
        end
    end
end

return M