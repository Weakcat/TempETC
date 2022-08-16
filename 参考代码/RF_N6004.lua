require"sys"
require"os"
require"bit"
require"string"
require"common"
require"my_utils"
-- 串口配置读头
-- 串口接收读头数据
-- 此代码暂时不支持用户区的读写
-- 还要支持一步一读

local UART_ID = 2

local cmd_stop = {0x00,0x01 ,0x02 ,0xFF ,0x00 ,0x00}

local function RFID_Version()
    local software_query = {0x00 ,0x01 ,0x01 ,0x01 ,0x00 ,0x00} --查询基带软件版本
    local hardware_query = {0x00 ,0x01 ,0x02 ,0x00 ,0x00 ,0x00}-- 查询读写器RFID能力
    RFN6_send(cmd_stop)
    RFN6_send(software_query)
    RFN6_send(hardware_query) 
end

local function RFID_Start( )
    local cmd_tid = {0x00 ,0x01 ,0x02 ,0x10 ,0x00 ,0x08 ,0x00 ,0x00 ,0x00 ,0x0F ,0x01 ,0x02 ,0x00 ,0x06}
    RFN6_send(cmd_stop)
    RFN6_send(cmd_tid) 
end

local function RFID_Inventory( )
    local cmd_tid = {0x00 ,0x01 ,0x02 ,0x10 ,0x00 ,0x08 ,0x00 ,0x00 ,0x00 ,0x0F ,0x00 ,0x02 ,0x00 ,0x06}
    RFN6_send(cmd_stop)
    RFN6_send(cmd_tid) 
end

local function RFID_Power_query( )
    local power_query = {0x00,0x01 ,0x02 ,0x02 ,0x00 ,0x00}-- 查询读卡器功率
    RFN6_send(cmd_stop)
    RFN6_send(power_query) 
end

local function RFID_Filter_query( )
    local filter_query = {0x00,0x01 ,0x02 ,0x0A ,0x00 ,0x00}-- 查询读卡器过滤配置
    RFN6_send(cmd_stop)
    RFN6_send(filter_query) 
end

function RFN6_send( data )
    crc = my_utils.xmodem_num_table(data)
    uart.write(UART_ID,0x5a)
    uart.write(UART_ID,unpack(data))
    uart.write(UART_ID,unpack(crc))
end

local function taskRead()
    local buff = {}
    local property = {}
    local crc_value = 0
    uart.setup(UART_ID,115200,8,uart.PAR_NONE,uart.STOP_1)
    -- sys.wait(100)
    -- RFID_Start( )
    while true do
        buff = {}
        property = {}
        while true do            
            data = uart.read(UART_ID,1)
            if not data or string.len(data) == 0 then break end

            byte_data =  string.byte(data)
            table.insert(buff,byte_data)

            crc_value = my_utils.xmodem_crc(#buff-1,data,crc_value)

            if buff[1] ~= 0x5a then buff = {} 
            elseif #buff >= 8 then
                local data_len = bit.rshift(buff[8],8)+bit.band(buff[7],0xFF) --youbug
                if data_len+9 == #buff then 
                    if crc_value == 0 then
                        local str0 = ''
                        for key,value in ipairs(buff)
                        do
                            str0 = str0..string.format("%02x",value)
                        end

                        if buff[4] == 0x02 and buff[5] == 0x00 then
                            log.info("rfid ability",str0) 
                        elseif buff[4] == 0x02 and buff[5] == 0x01 then
                            RFID_Power_query()
                        elseif buff[4] == 0x02 and buff[5] == 0x02 then
                            property['RFID:Power']={buff[9],buff[11],buff[13],buff[15]}
                        elseif buff[4] == 0x02 and buff[5] == 0x09 then
                            RFID_Filter_query()
                        elseif buff[4] == 0x02 and buff[5] == 0x0A then
                            property['RFID:Filter']={t_ms=10*(bit.lshift(buff[8],8)+buff[9]),rssi=buff[10]}
                        elseif buff[4] == 0x02 and buff[5] == 0x10 then
                            log.info("UHF", str0)
                            if buff[8] == 0 then property['RFID:State'] = 1
                            else property['RFID:State'] = 2
                            end
                        elseif buff[4] == 0x02 and buff[5] == 0xFF then
                            if buff[8] == 0 then property['RFID:State'] = 0
                            else property['RFID:State'] = 2
                            end
                        elseif buff[4] == 0x12 and buff[5] == 0x00 then
                            local epc_lenth = bit.lshift(buff[8],8)+buff[9]
                            local epc = {unpack(buff,10,9+epc_lenth)}
                            local PC_value = bit.lshift(buff[10+epc_lenth],8)+buff[11+epc_lenth] 
                            local antenna_ID = buff[12+epc_lenth]
                            if  (bit.rshift(PC_value,11)*2>=epc_lenth) and antenna_ID<=4  then
                                local str = ''

                                for key,value in ipairs(epc)
                                do
                                    str = str..string.format("%02x",value)
                                end
    
                                local optinal = {unpack(buff,13+epc_lenth,#buff - 2)}
                                local opt_flag = 0
                                local opt_leng = 0
                                local opt_table = {}
                                local str_tid = ""
                                local str_usr = ""
                                for key,value in ipairs(optinal)
                                do
                                    if opt_flag == 0 then
                                        if opt_table[value]==nil then opt_flag = value end
                                    else
                                        if opt_flag == 0x01 then table.insert(opt_table,0x01,value) opt_flag=0x00 
                                        elseif opt_flag == 0x02 then table.insert(opt_table,0x02,value) opt_flag=0x00 
                                        elseif opt_flag == 0x03 then opt_leng = value opt_flag=0x0103 
                                        elseif opt_flag == 0x0103 then 
                                            opt_leng = bit.lshift(opt_leng,8)+value 
                                            opt_flag=0x0203 
                                        elseif opt_flag == 0x0203 then 
                                            opt_leng=opt_leng-1
                                            str_tid = str_tid..string.format("%02x",value)
                                            if opt_leng < 1 then 
                                                table.insert(opt_table,0x03,str_tid) opt_flag=0x00 
                                            end
                                        elseif opt_flag == 0x04 then opt_leng = value opt_flag=0x0104 
                                        elseif opt_flag == 0x0104 then 
                                            opt_leng = bit.lshift(opt_leng,8)+value 
                                            opt_flag=0x0204 
                                        elseif opt_flag == 0x0204 then 
                                            opt_leng=opt_leng-1
                                            str_user = str_usr..string.format("%02x",value)
                                            if opt_leng < 1 then 
                                                log.info("usr", str_user)
                                                table.insert(opt_table,0x04,str_user) opt_flag=0x00 
                                            end
                                        elseif opt_flag == 0x08 then table.insert(opt_table,0x08,0) opt_flag=0x0108 
                                        elseif opt_flag == 0x0108 then opt_table[0x08]=value opt_flag=0x0208  
                                        elseif opt_flag == 0x0208 then opt_table[0x08]=bit.lshift(opt_table[0x08],8)+value opt_flag=0x0308 
                                        elseif opt_flag == 0x0308 then opt_table[0x08]=bit.lshift(opt_table[0x08],8)+value opt_flag=0x0408 
                                        elseif opt_flag == 0x0408 then opt_table[0x08]=bit.lshift(opt_table[0x08],8)+value opt_flag=0x00 
                                        end

                                        
                                    end
                                end
                                log.info("Read OPtinal",string.format("%02x",PC_value),epc_lenth,antenna_ID,str,opt_table[0x01],opt_table[0x02],opt_table[0x03],opt_table[0x04],opt_table[0x08])

                            else
                                log.error("PC_value", string.format("%02x",PC_value))
                            end
                        elseif buff[4] == 0x12 and buff[5] == 0x02 then
                            -- log.info("ant change", buff[8],buff[14])
                        else 

                            log.info("UHF", str0)
                        end
                        buff = {}
                    else
                        log.info("Read fail", unpack(buff))
                        buff = {}
                    end
                end
            end

            -- if #buff > 32 then
            --     buff = {}
            -- end
        end
        sys.wait(100)
        if next(property) ~= nil then sys.publish("ali_event","property",property) end
    end

end


sys.taskInit(taskRead)


sys.subscribe("thing.service.property.set",function( params,msg_id )
    if params['RFID:Power'] then 
        local cmd_power_set = {0x00 ,0x01 ,0x02 ,0x01 ,0x00}
        local data = params['RFID:Power']
        if #data <= 4 then
            table.insert(cmd_power_set,#data*2)
            for key,value in ipairs(data)
            do
                table.insert(cmd_power_set,key)
                table.insert(cmd_power_set,value)
            end
            RFN6_send(cmd_stop)
            RFN6_send(cmd_power_set) 
        end
    end
    if params['RFID:Filter'] then 
        local cmd_filter_set = {0x00 ,0x01 ,0x02 ,0x09 ,0x00 ,0x05, 0x01, 0x00, 0x0a,0x02, 0x00}-- 设置过滤时间100ms rssi阈值0
        local data = params['RFID:Filter']
        local timer = data['t_ms']
        local rssi = data['rssi']
        if timer ~= nil and rssi~=nil then
            timer = math.floor(timer/10)
            cmd_filter_set[8] = bit.rshift( timer ,8)
            cmd_filter_set[9] = bit.band( timer ,0xFF)
            cmd_filter_set[11] =bit.band( rssi ,0xFF)
            RFN6_send(cmd_stop)
            RFN6_send(cmd_filter_set) 
        end
    end   
end)

sys.subscribe("thing.service.RFID:Start",function( params,msg_id )
    RFID_Inventory()
end)