--[[
switch implements the libp2p switch

TODO: this is very much WIP. It doesn't do MANY of the things that the switch
is supposed to do.

--]]
local multistream = require("multistream")
local socket = require("socket")
local varint = require("varint")
local pq = require("pq")
local ythr = require("ythr")
local multiplex = require("multiplex")
local conn = require("conn")

local Switch = {}
Switch.__index = Switch

function Switch:new()
	local s = {}
	setmetatable(s, Switch)
	s.handlers = {}

	return s
end

function Switch:setProtocolHandler(proto, handler)
	self.handlers[proto] = handler
end

function Switch:cryptoUpgrade(con)
	ptext = "/plaintext/1.0.0"

	local val, err = multistream.negotiate(con, ptext)
	if err then
		return nil, err
	end

	return con, nil
end

function Switch:mplexUpgrade(con)
	local val, err = multistream.negotiate(con, "/mplex/6.7.0")
	if err then
		print("negotiate error: ", err)
		return nil, err
	end

	local mplex = multiplex:new(con, function (str)
		local protoID, err = multistream.route(str, self.handlers)
		if err then
			print("failed to route stream negotiation", err)
			return
		end

		self.handlers[protoID](str)
	end, 1)

	return mplex, nil
end

function Switch:dial(host, port)
	local tcp = assert(socket.tcp())
	tcp:connect(host, port)

	local c = conn:new(tcp)

	local secCon, err = self:cryptoUpgrade(c)
	if err then return nil, err end

	local mplx, err = self:mplexUpgrade(c)
	if err then return nil, err end

	return mplx, nil
end

return Switch
