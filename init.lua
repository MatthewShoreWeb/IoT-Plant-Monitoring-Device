wifi.sta.sethostname("plantSensor")
wifi.setmode(wifi.STATION)
station_cfg={}
station_cfg.ssid = "REMOVED" 
station_cfg.pwd = "REMOVED"
station_cfg.save = true
wifi.sta.config(station_cfg)
wifi.sta.connect()
connected = false

connectToWifi = tmr.create()
connectToWifi:register(1000, 1, function() 
   if wifi.sta.getip()==nil then
        print("Connecting to local network...")
   else
        connectToWifi:stop()
        print("Connected to:  ", wifi.sta.getip())
        m:connect("io.adafruit.com" , 1883, false, false, function(conn) end, function(conn,reason)
            print("Error: "..reason)
        end)
      
   end 
end)
connectToWifi:start()

ADAFRUIT_IO_USERNAME = "REMOVED"
ADAFRUIT_IO_KEY = "REMOVED"

-- Subscribes to.
acceptable_temp_sub  = "REMOVED/feeds/acceptable-temperature"
acceptable_humi_sub  = "REMOVED/feeds/acceptable-humidity"
acceptable_light_sub = "REMOVED/feeds/acceptable-light"
acceptable_moisture_sub  = "REMOVED/feeds/acceptable-soil"
on_off_button = "REMOVED/feeds/turn-device-on"

-- Publishes to.
publish_humidity = "REMOVED/feeds/humidity"
publish_temperature = "REMOVED/feeds/temperature"
publish_soil = "REMOVED/feeds/soil-moisture"
publish_light = "REMOVED/feeds/light-level"
status = "REMOVED/feeds/overall-status"

m = mqtt.Client("Client1", 300, ADAFRUIT_IO_USERNAME, ADAFRUIT_IO_KEY)

-- Default values.
acceptable_temp = 30
acceptable_humi = 40
acceptable_light = 20000
acceptable_soil = 30

m:on("connect",function(client) 
    print("Connected to io.adafruit.com") 
    connected = true
--    Sets the on/off switch on the dashboard to "ON".
    m:publish(on_off_button, "ON", 1, 0, function(client) end)
    client:subscribe(on_off_button, 1)
    client:subscribe(acceptable_temp_sub, 1)
    client:subscribe(acceptable_humi_sub, 1)
    client:subscribe(acceptable_light_sub, 1)
    client:subscribe(acceptable_moisture_sub, 1)
end)

m:on("message", function(client, topic, data)  
  -- User switches device on or off.
  if (data == "OFF") then
    print("Device turned off.")
    pollSensors:stop()
  elseif (data == "ON") then
    print("Device turned on.")
    getData(m)
  end

  -- If user changes threshold.
  if (topic == acceptable_temp_sub) then
      acceptable_temp = data
  elseif (topic == acceptable_humi_sub) then
     acceptable_humi = data
  elseif (topic == acceptable_light_sub) then
    acceptable_light = data
  elseif (topic == acceptable_moisture_sub) then
    acceptable_soil = data
  end 
  print("Conditions: Temp:"..acceptable_temp.." Humidity: "..acceptable_humi.. " Light: "..acceptable_light.." Soil: ".. acceptable_soil)
end)

-- Green
pwm.setup(1,1000, 1023)
pwm.start(1)

-- Red
pwm.setup(2,1000, 1023)
pwm.start(2)

-- Checks data against threshold.
function checkData(client, temperature, humididty, moisture, light)
    if (tonumber(temperature) > tonumber(acceptable_temp) or tonumber(humididty) > tonumber(acceptable_humi) or tonumber(moisture) > tonumber(acceptable_soil) or tonumber(light) > tonumber(acceptable_light)) then
        pwm.setduty(2,1023)
        pwm.setduty(1, 0)
--        client:publish(status, 1, 1, 0, function(client) end)
    else 
        pwm.setduty(2, 1023)
        pwm.setduty(1, 0)
--        client:publish(status, 2, 1, 0, function(client) end)
    end
end

bh1750_SCL = 5
bh1750_SDA = 6

bh1750 = require("bh1750")
bh1750.init(bh1750_SDA, bh1750_SCL)

-- Obtains the soil data from analog.
function getSoilData()
       local moisture_percentage =  (100.00 - ((adc.read(0) / 1023.00) * 100.00)) 
       if (moisture_percentage < 0) then
           moisture_percentage = 0
       end
       return moisture_percentage
end

pollSensors = tmr.create()

-- Publishes temeperature and humidity information.
function getData(client)
    pollSensors:register(10000,tmr.ALARM_AUTO,function(m)
              status, temp, humi, temp_dec, humi_dec = dht.read11(4)
              print("Temperature:"..temp.." & ".."Humidity:"..humi)
              client:publish(publish_humidity, tostring(humi), 1, 0)
              client:publish(publish_temperature, tostring(temp), 1, 0)
              
              bh1750.read()
              light = (bh1750.getlux()/100)                  
              client:publish(publish_light, tostring(light), 1, 0)
              print("Light: "..light)
                 
              print(string.format("Soil Moisture(in Percentage) = %0.4g", getSoilData()))
              client:publish(publish_soil, tostring(getSoilData()), 1, 0)
              checkData(client, temp, humi, getSoilData(), light)
    end)
    pollSensors:start()
end
   
waitForConnection = tmr.create()
waitForConnection:alarm(2000, tmr.ALARM_AUTO, function()
    if (connected) then
        getData(m)
        waitForConnection:stop()
    end
end)
  
