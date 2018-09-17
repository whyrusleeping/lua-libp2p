--[[
identify implements the libp2p identify protocol.
This package is currently a WIP
--]]
local varint = require("varint")
local pb = require("pb")
local protoc = require("protoc")

assert(protoc:load [[
message Identify {
  optional bytes publicKey = 1;
  repeated bytes listenAddrs = 2;
  repeated string protocols = 3;
  optional bytes observedAddr = 4;
  optional string protocolVersion = 5;
  optional string agentVersion = 6; 
}
]])

local M = {}

M.protocolID = "/ipfs/id/1.0.0"

function M.handle(str)
	local myInfo = {
		agentVersion = "lua-libp2p/0.0.0",
		protocolVersion = "ipfs/0.1.0",
	}
	local data, err = pb.encode("Identify", myInfo)
	if err then
		print("pb encode error: ", err)
		return
	end

	local lenbuf = varint.UvarintBuf(data:len())
	local n, err = str:send(lenbuf .. data)
	if err then
		print("identify sending error:", err)
		return
	end
end


return M
