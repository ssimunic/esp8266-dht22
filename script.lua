-- Created for Temp Monitor project.
-- https://github.com/ssimunic/Temp-Monitor

PIN = 2 --  data pin, GPIO4
uid="YOUR_SENSOR_ID"
apikey="YOUR_API_KEY"
responsetype = "esp8266"

-- settings received from server
ip="http://tempmonitor.silviosimunic.com/" -- ip or http address
dsleep=1

tmr.alarm(0,100, 1, function()
    if wifi.sta.status() == 5 then
        print("\nDevice IP:"..wifi.sta.getip())
        tmr.stop(0)
		print("-----STARTING NEW SESSION-----")
		conn=net.createConnection(net.TCP, 0)
        conn:on("receive", function(conn, payload)
			--print(payload)
			_, _, response = string.find (payload, "QS1=(.*)QE1")
			_, _, sleeptime= string.find (payload, "QS2=(.*)QE2")
			_, _, server= string.find (payload, "QS3=(.*)QE3")
			print("Response: "..response)
			print("Sleep time: "..sleeptime.." minutes")
			print("Server address: "..server)

			dsleep = sleeptime
			ip = server

            conn:close()
		end)
		conn:connect(80,ip)

        dht22 = require("dht22")
        dht22.read(PIN)

        t = dht22.getTemperature()
        h = dht22.getHumidity()

        if h == nil then
			print("DHT Error")
        else
            temp = ((t-(t % 10)) / 10).."."..(t % 10)
			hum = ((h - (h % 10)) / 10).."."..(h % 10)
			majorVer, minorVer, devVer, chipid, flashid, flashsize, flashmode, flashspeed = node.info();
			firmware = majorVer.."."..minorVer.."."..devVer
			mac = wifi.sta.getmac()

            conn:send("GET /api/data/push?id="..uid.."&t="..temp.."&h="..hum.."&api_key="..apikey.."&response_type="..responsetype.." HTTP/1.1\r\nHost: "..ip.."\r\n"
			.."Connection: keep-alive\r\nAccept: */*\r\n\r\n")
            print("Sent to server.\nDHT OK: T:"..temp.." H:"..hum)
        end

        conn:on("sent",function(conn)
            --print("Closing connection.")
        end)

        conn:on("disconnection", function(conn)
			minute=60000000 -- 1 minute for multiplication
            -- release module
            dht22 = nil
            package.loaded["dht22"]=nil
			-- reset time
			-- tmr.wdclr()
            -- sleep for x time
            print("Going to sleep.")
            node.dsleep(dsleep*minute)
        end)
    end
end)
