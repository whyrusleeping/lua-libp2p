local switch = require("switch")
local identify = require("identify")
local multistream = require("multistream")
local ythr = require("ythr")
local ping = require("ping")

local sw = switch:new()

sw:setProtocolHandler(identify.protocolID, identify.handle)

ythr.go(function ()
	local mp, err = sw:dial("127.0.0.1", 4001)
	if err then return err end

	local s, err = mp:newStream()
	if err then return err end

	local val, err = multistream.negotiate(s, "/ipfs/ping/1.0.0")
	if err then return err end
	print("negotiated", val)


	ping.doPing(s)

end)


--[[ notes: how to listen on a server in lua
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

