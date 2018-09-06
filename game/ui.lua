local lni = require 'lni'
local lni_writer = require 'ac.base.lni_writer'

local ROOT = {}
local MSG  = { root = ROOT }

local SUBSCRIPT = {}

local proto = {}

local logger = log.warn
if ac.test then
    logger = log.error
end

function proto.notify(data)
    local callback = SUBSCRIPT[data.id]
    if not callback then
        return
    end
    callback(table.unpack(data.args))
end

function ac.runtime.player:ui(type)
    return function (args)
        ROOT.type = type
        ROOT.args = args
        local msg = lni_writer(MSG)
        self:ui_message(msg)
    end
end

function ac.game:ui(type)
    return function (args)
        ROOT.type = type
        ROOT.args = args
        local msg = lni_writer(MSG)
        for player in ac.each_player 'user' do
            player:ui_message(msg)
        end
    end
end

ac.game:event('玩家-界面消息', function (_, player, str)
    if str:find('--!', 1, true) then
        logger(table.concat({('玩家[%d]发送了非法的消息'):format(player:get_slot_id()), str}, '\r\n'))
        return
    end
    local suc, res = pcall(lni, str)
    if not suc then
        logger(table.concat({('玩家[%d]发送了错误的消息'):format(player:get_slot_id()), str, res}, '\r\n'))
        return
    end
    local type, args = res.type, res.args
    if not proto[type] then
        logger(table.concat({('玩家[%d]发送了错误的消息'):format(player:get_slot_id()), str, res}, '\r\n'))
        return
    end
    xpcall(proto[type], logger, args)
end)

ac.loop(33, function ()
    ac.game:ui 'tick' (ac.clock())
end)

local function copy_key(key, keys)
    local new_keys = {}
    if keys then
        for i, k in ipairs(keys) do
            new_keys[i] = k
        end
    end
    new_keys[#new_keys+1] = key
    return new_keys
end

local function new_bind(player, name, keys)
    local state = {}
    return setmetatable({}, {
        __index = function (self, key)
            if not state[key] then
                local t = new_bind(player, name, copy_key(key, keys))
                state[key] = t
            end
            return state[key]
        end,
        __newindex = function (self, key, value)
            -- 把旧的订阅释放掉（客户端不需要释放，因为客户端是通过事件名来存储的，会被新的订阅覆盖）
            local old = state[key]
            if type(old) == 'function' then
                local pointer = tostring(old)
                SUBSCRIPT[pointer] = nil
            end

            state[key] = value
            if type(value) == 'function' then
                -- 通知客户端订阅事件，将函数pointer作为id，监听返回时使用notify协议
                local pointer = tostring(value)
                SUBSCRIPT[pointer] = value
                player:ui 'subscript' {
                    name = name,
                    key = copy_key(key, keys),
                    value = pointer,
                }
            else
                player:ui 'bind' {
                    name = name,
                    key = copy_key(key, keys),
                    value = value,
                }
            end
        end,
    })
end

local function bind(player, name)
    return new_bind(player, name)
end

ac.ui = {
    bind = bind,
}
