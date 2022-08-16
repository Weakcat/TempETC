require"string"
require"common"
require"filesystem"
require"lang"
local class = require 'middleclass'


---@class KVDB
local UHF = class('UHF')


function UHF:initialize(uart_id,pin_485)
    self.buff = {}
    self.uart_id = uart_id
    self.pin_485 = pin_485
    self.rs485_oe =pins.setup(pin_485, 1)
    uart.setup(self.uart_id,115200,8,uart.PAR_NONE,uart.STOP_1)
    self.rs485_oe(0)
end

function UHF:_datacheck()
    local sum = 0
    for i=1,#self.buff do
        sum = sum + self.buff[i]
    end
    sum = bit.band(sum,0xFF) 
    if sum == 0 then 
        return true 
    else 
        log.info("UHF","error buff",unpack(self.buff))
        self.buff = {}
        return false 
    end
end

function UHF:_buff_to_hex(begin_pos,end_pos)
    if begin_pos > end_pos then return nil end
    if end_pos > #self.buff then return nil end
    local temp_str = ""
    for i=begin_pos,end_pos do
        temp_str = temp_str..string.toHex(string.char(self.buff[i]))
    end
    return temp_str
end

function UHF:getchar()
    local data = uart.read(self.uart_id,1)--或者换成getchar
    if data and string.len(data) == 1 then 
        local byte_data =  string.byte(data)
        table.insert(self.buff,byte_data)
        return true
    else    
        return false
    end
end

function UHF:parse()
    local parse_result = nil
    if #self.buff == 1 and self.buff[1] ~= 0x43 then self.buff = {} end
    if #self.buff == 2 and self.buff[2] ~= 0x54 then self.buff = {} end
    if #self.buff > 4 and #self.buff >= self.buff[4]+4 and self:_datacheck() then 
        
        if #self.buff > 6 then
            if self.buff[6] == 0x45 then 
                local devsn_str = self:_buff_to_hex(8,13)
                local epc_str = self:_buff_to_hex(19,30)
                parse_result = {devsn=devsn_str,epc=epc_str}
            else
                log.info("raw unknow", unpack(self.buff))
            end
        end
        self.buff = {}
    end
    return parse_result
end

function UHF:_Write(table_content)
    uart.write(self.uart_id,unpack(table_content))
    uart.write(self.uart_id,lang.compsum(table_content))
end

function UHF:FilterSet( filter_number )
    self:_Write({0x53,0x57,0x00,0x05,0xff,0x24,0x04,filter_number})
end

function UHF:PowerSet( power_number )
    self:_Write({0x53,0x57,0x00,0x05,0xff,0x24,0x05,power_number})
end

function UHF:BuzzerSet( buzzer_number )
    self:_Write({0x53,0x57,0x00,0x05,0xff,0x24,0x06,buzzer_number})
end

function UHF:Set(command)
    self.rs485_oe(1)
    sys.wait(50)

    -- if type(command["Filter"]) == 'number' then
    --     self:FilterSet(command["Filter"])
    --     sys.wait(5)
    -- end

    if type(command["Power"]) == 'number' then
        self:PowerSet(command["Power"])
        log.info("power",command["Power"])
        sys.wait(5)
    end
    if type(command["Buzzer"]) == 'number' then
        self:BuzzerSet(command["Buzzer"])
        sys.wait(5)
    end
    sys.wait(50)
    self.rs485_oe(0)
end

return UHF

-- TODO: