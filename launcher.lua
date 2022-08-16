module(..., package.seeall)

require"os"
require"sys"
require"string"
require"common"

require "appETC"
require"gateway"
require"controller"

local kvdb = require"kvdb"

pm.wake("usb")
local mount_flag = io.mount(io.SDCARD,"/sdcard0")-- sdCard可能挂载不上，这边需要判断，可能中途被拔卡，要再写一个管理app
local kv = kvdb:new("/sdcard0","epc6")
-- pm.sleep("usb")

function run()
    gateway.aliyunLanch()
    sys.taskInit(appETC.taskRead,kv)
end

sys.subscribe("PropertyUpdate",function()   
    sys.timerStart(function ()
        sys.publish("ali_event","property",{
            FlagMount = mount_flag,
            DoorConf = controller.ConfFetch(),
            ETCConf = appETC.ETCFetch(),
            })
    end, 1000)
end)

sys.subscribe("thing.service.property.set",function( params,msg_id ,version )   
    log.info("conf",mount_flag,json.encode(params))
    -- 配置批发
    if  params["UHFConf"] ~= nil then
        sys.publish("UHF.Conf",params["UHFConf"])
    end
    if  params["ETCConf"] ~= nil then
        sys.publish("ETC.Conf",params["ETCConf"])
    end
    if  params["DoorConf"] ~= nil then
        sys.publish("Controller.Conf",params["DoorConf"])
    end
    sys.publish("PropertyUpdate")
end)

sys.subscribe("thing.service.cardSet",function( params,msg_id ,version )   
    log.info("data",json.encode(params))
    -- 判断EPCID 并且转换为全大写，因为hash的时候区分大小写
    if params["EPCID"]~=nil and type(params["EPCID"])=='string' then
        local epcid = string.upper(params["EPCID"])
        local table_temp = {
            EPCID = epcid,
            dueDate = misc.getClock()
        }
        lang.tableUpdate(table_temp,params)
        kv:write(epcid,table_temp)
    else
        log.info("launcher","params error")
    end

    -- sys.publish("ali_service_reply","property/set",payload)
end)

sys.subscribe("thing.service.cardDelete",function( params,msg_id ,version )   
    log.info("data",json.encode(params))
    if params["EPCID"]~=nil and type(params["EPCID"])=='string' then
        local epcid = string.upper(params["EPCID"])
        kv:delete(epcid)
        log.info("cardDelete",epcid)
        -- cach里的缓存是不是也要删除
        -- 但是又怕耦合太厉害
    end
    -- sys.publish("ali_service_reply","property/set",payload)
end)

sys.subscribe("thing.service.cardQuery",function( params,msg_id ,version )   
    log.info("data",json.encode(params))
    local payload_table = {
        code =400,
        data ={
            dueDate={
                year=2000,
                month=1,
                day=1
        }},
        id = msg_id,
        message = "success",
        version = version
    }

    if params["EPCID"]~=nil and type(params["EPCID"])=='string' then
        local epcid = string.upper(params["EPCID"])
        local table_temp = kv:read(epcid)
        if table_temp ~= nil and type(table_temp["dueDate"]) == 'table' then
            payload_table.code = 200
            lang.tableUpdate(payload_table.data.dueDate,table_temp["dueDate"])
        end
    end
    local  payload = json.encode(payload_table)
    sys.publish("ali_service_reply","cardQuery",payload)
end)

sys.subscribe("thing.service.gateOpen",function( params,msg_id ,version )   
    sys.publish("Controller.Open")
end)