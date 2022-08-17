module(..., package.seeall)

require"sys"
require"string"
require"common"
require"lang"
local uartparser = require"radioUHF"
local cache = require"cache"

local UART_ID = 3
local PIN485 = pio.P0_17
local command = nil
-- sys.subscribe("ali_connect",function(params)
--     parser.rs485_oe(0)
-- end)
local configurator = require"conf"
local conf_etc = configurator:new("ETC","V03",{
    Mode = 0,
    Interval_s = 30,
})

sys.subscribe("UHF.Conf",function(params)
    command = params
end)

function ETCFetch( )
    return conf_etc:Fetch()
end
function taskRead(kv) -- 应该把数据库传进来
    conf_etc:Fetch()

    local parser = uartparser:new(UART_ID,PIN485)
    local cache_etc = cache:new()
    parser.rs485_oe(0)
    while true do    
        if command~=nil then
            parser:Set(command)
            command = nil
        end
        if parser:getchar() then
            local temp = parser:parse()
            if temp ~= nil and temp.epc ~= nil and temp.devsn ~= nil then
                sys.wait(1)
                log.info("Mem Free Size KB:", collectgarbage("count"),1360- collectgarbage("count"))
                local result = cache_etc:read(temp.epc)
                if result ~= nil then   
                    if result == temp.devsn then
                        cache_etc:write(temp.epc,temp.devsn,conf_etc.content.Interval_s)
                        sys.publish("Controller.Open")
                        log.info("etc catch",temp.epc,temp.devsn)
                    else
                        log.info("etc lock",temp.epc,temp.devsn)
                    end
                else   
                    if conf_etc.content.Mode == 0 then 
                        sys.publish("Controller.Open")
                        cache_etc:write(temp.epc,temp.devsn,conf_etc.content.Interval_s)
                        log.info("etc open",temp.epc)
                    else 
                        -- 先判断sto是不是正常 如果没有正常挂载就执行另一套操作

                        local kv_result = kv:read(temp.epc) 
                        if kv_result ~= nil then  
                            if lang.indue(kv_result["dueDate"])then
                                sys.publish("Controller.Open")
                                cache_etc:write(temp.epc,temp.devsn,conf_etc.content.Interval_s)
                            else
                                -- 删卡
                            end
                        else
                            log.info("etc no found",temp.epc)
                        end
                    end
                end 
            end
        else
            sys.wait(50)
        end
    end
end


sys.subscribe("ETC.Conf",function(Conf)   
    conf_etc:Update(Conf)
    sys.publish("ali_event","property",{ETCConf = conf_etc.content})
end)


