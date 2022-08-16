module(..., package.seeall)

require"lang"

local configurator = require"conf"
local conf_door = configurator:new("Door","V01",{
    TriggerMode = 0,
    PlusWidth = 2000,
})
conf_door:Fetch()

local DoorPin = pins.setup(pio.P0_13, 1)

local function DoorInit()
    if conf_door.content.TriggerMode == 0 then  
        DoorPin(1)
    end
    if conf_door.content.TriggerMode == 1 then  
        DoorPin(0)
    end
end
DoorInit()

function ConfFetch()
    return conf_door:Fetch()
end

sys.subscribe("Controller.Open",function()
    if conf_door.content.TriggerMode == 0 then  
        sys.timerStopAll(DoorPin)-- 删掉应该也可以
        DoorPin(0)
        sys.timerStart(DoorPin, conf_door.content.PlusWidth, 1)
    end
    if conf_door.content.TriggerMode == 1 then  
        sys.timerStopAll(DoorPin)-- 删掉应该也可以
        DoorPin(1)
        sys.timerStart(DoorPin, conf_door.content.PlusWidth, 0)
    end
    if conf_door.content.TriggerMode == 2 then  
        log.info("controller","433")
    end
end)

sys.subscribe("Controller.Conf",function(Conf)   
    conf_door:Update(Conf)
    sys.publish("ali_event","property",{DoorConf = conf_door.content})
    DoorInit()
end)