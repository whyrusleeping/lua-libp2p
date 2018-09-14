local multistream = require("multistream")
local socket = require("socket")
local varint = require("varint")
local pq = require("pq")
local ythr = require("ythr")
local multiplex = require("multiplex")
local conn = require("conn")


function tryMultistream()
	local tcp = assert(socket.tcp())
	local host, port = "127.0.0.1", 4001
	tcp:connect(host, port)

	print("tcp = ", tcp)

	local c = conn:new(tcp)

	ptext = "/plaintext/1.0.0"

	print("about to negotiate")
	local val, err = multistream.negotiate(c, ptext)
	print("after negotiate")
	if err then
		print(err)
	else
		print("val: ", val)
	end

	print("about to negotiate2")
	local val, err = multistream.negotiate(c, "/mplex/6.7.0")
	print("after negotiate2")
	if err then
		print(err)
	else
		print("val: ", val)
	end

	local protoOpts = {}
	local mplex = multiplex:new(c, function (str)
		print("New stream handler!")
		local protoID, err = multistream.route(str, protoOpts)
		if err then
			print("failed to route stream negotiation", err)
			return
		end
		print("route returned: ", protoID)
	end)
	print("new multiplex")
end

ythr.go(tryMultistream)

--[[
local ch = ythr.makeChan()
ythr.go(function ()
	for i=1,20,1 do
		ch:send(i)
	end
end)

ythr.go(function ()
	for i=100,80,-1 do
		ch:send(i)
	end
end)

ythr.go(function ()
	for i=1,100,1 do
		local val = ch:recv()
		print(val)
	end
end)
]]--

--[[
ythr.go(function ()
	for i=1,10,1 do
		print(i)
		ythr.polite()
	end
end)

ythr.go(function ()
	for i=1,10,1 do
		print((i*4)+10)
		ythr.polite()
	end
end)



ythr.go(function ()
	do return end
	local buf = ""
	while 1 do
		local r, err = ythr.read(tcp, 5)
		if err ~= nil then
			if err == "closed" then
				break
			end
			return
		end
		if r == "" then break end
		print("read data: ", r)
		buf = buf .. r
	end
	print("final read: ", buf)
end)

function startServer()
	print("START SERVER")
	local server = assert(socket.bind("*", 0))

	local ip, port = server:getsockname()

	print(ip, port)


	while 1 do
		print("in loop")
		local client, err = ythr.accept(server)
		if err then print("ACCEPT ERROR: ", err) end

		client:settimeout(10)
		local line, err = client:receive()

		if not err then client:send(line .. "\n") end
		client:close()
	end
end

--ythr.go(startServer)
]]--

ythr.scheduler()

