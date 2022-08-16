module(..., package.seeall)

--- 模块功能：网关功能.
-- @author weakcat
-- @module gateway
-- @license MIT
-- @copyright openLuat
-- @release 2021.11.22

-- require"ntp"
require"net"
require"misc"
require"aLiYun"

PRODUCT_KEY = "g8smk7rpYDw"
PRODUCT_SECRECT = "7oZMzbFv0jaO376P"
local INSTANCE_ID = "iot-060a06vm"



local function getDeviceName(  )
    return misc.getImei()
end

local function getIccid(  )
    return sim.getIccid()
end

local function getDeviceSecret()
    return misc.getSn()
end
local function setDeviceSecret(DeviceSecret)
    misc.setSn(DeviceSecret)
end

local topics = {
    pub = {
        post = function(event)
            event = event or "property"
            return "/sys/"..PRODUCT_KEY.."/"..getDeviceName().."/thing/event/"..event.."/post"
        end,
        retAsync = function(serviceName)
            return "/sys/"..PRODUCT_KEY.."/"..getDeviceName().."/thing/service/"..serviceName.."_reply"
        end,
        retSync = function(msgId)
            return "/sys/"..PRODUCT_KEY.."/"..getDeviceName().."/rrpc/response/"..msgId
        end,
    },
    sub = {
        call = function(service)
            service = service or 'property/set'
            return '/sys/'..PRODUCT_KEY..'/'..getDeviceName()..'/thing/service/'..service
        end,
        callSync = "/sys/"..PRODUCT_KEY.."/"..getDeviceName().."/rrpc/request/+"
    },
}

local function service_reply(serviceName,payload)
    aLiYun.publish(topics.pub.retAsync(serviceName),payload,0)
end

local function event(eventName,params)
    local event_post_data = {id = math.random(100000),params = params, method = "thing.event."..eventName..".post"}
    aLiYun.publish(topics.pub.post(eventName),json.encode(event_post_data),0)
end

local function connectCb()
    aLiYun.subscribe(topics.sub.call("+"),0)
    sys.publish("PropertyUpdate")
end

local function reciveCb(topic,qos,payload)
    local tJsonDecode,result = json.decode(payload)
    log.info("method", tJsonDecode["method"],payload)
    sys.publish(tJsonDecode["method"],tJsonDecode["params"],tJsonDecode["id"],tJsonDecode["version"])
    -- debug
end


-- 这是一个定时器，可以用来执行一些周期任务
-- 比如判断sim卡和sd卡的状态
sys.timerLoopStart(function ()
    sys.publish("ali_event","property",{
        NetRssi=net.getRssi(),
    })
    -- 心跳包由谁来管理呢
end, 60000)

function aliyunLanch() 
    aLiYun.on("connect", connectCb)
    aLiYun.on("receive", reciveCb)
    aLiYun.setup(PRODUCT_KEY,PRODUCT_SECRECT,getDeviceName,getDeviceSecret,setDeviceSecret)
    aLiYun.setConnectMode("direct",INSTANCE_ID..".mqtt.iothub.aliyuncs.com",1883)
    require"aLiYunOta"

    sys.subscribe("ali_service_reply",service_reply)
    sys.subscribe("ali_event",event)

    sys.subscribe("thing.service.Reboot",function() sys.restart("ali reboot cmd") end)
end