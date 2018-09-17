--[[
multistream implements multistream select negotiation
--]]
local varint = require("varint")

local M = {}

function stringToBytePretty(s)
	out = "[ "
	for i=1,s:len(),1 do
		local b = string.byte(s, i)
		out = out .. b .. " "
	end
	out = out .. "]"
	return out
end


function M.lpRead(r)
	local len = assert(varint.readUvarint(r))
	local val = assert(r:receive(len))

	if(val:len() ~= len) then
		return nil, "failed to read enough"
	end

	return string.sub(val, 1, -2)
end


function M.lpWrite(w, val)
	local lenBuf = varint.UvarintBuf(val:len()+1)
	return w:send(lenBuf .. val .. "\n")
end

M.ProtocolID = "/multistream/1.0.0"

local incorrectHeader = "did not get correct multistream header back"

function M.negotiate(con, proto)
	assert(M.lpWrite(con, M.ProtocolID))
	local header = assert(M.lpRead(con))
	if (header ~= M.ProtocolID) then
		print("got header: ", header)
		return nil,incorrectHeader
	end

	assert(M.lpWrite(con, proto))
	return assert(M.lpRead(con))
end

function M.list(con)
	assert(M.lpWrite(con, M.ProtocolID))
	if (assert(M.lpRead(con)) ~= M.ProtocolID) then return incorrectHeader end

	assert(M.lpWrite(con, "ls"))
	local out = {}
	local totLen = varint.readUvarint(con)
	local numStr = varint.readUvarint(con)
	for i = 1,numStr,1 do
		out[i] = assert(M.lpRead(con))
	end
	return out, nil
end

function M.route(con, opts)
	local num, err = M.lpWrite(con, M.ProtocolID)
	if err then
		print("multistream route write error:", err)
		return err
	end
	local header = assert(M.lpRead(con))
	if (header ~= M.ProtocolID) then
		print("got header: ", header)
		return nil, incorrectHeader
	end

	while 1 do
		local attempt, err = M.lpRead(con)
		if err then return nil, err end

		if opts[attempt] ~= nil then
			local n, err = M.lpWrite(con, attempt)
			if err then
				print("WRITE ERROR: ", err)
				return nil, err
			end
			return attempt, nil
		end

		local n, err = M.lpWrite(con, "na")
		if err then
			print("ROUTE ERRORED ON WRITE: ", err)
			return err
		end
	end
end

return M
