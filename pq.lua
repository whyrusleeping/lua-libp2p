PQ = {}
PQ.__index = PQ

function PQ:new(cmp)
	local o = {}
	setmetatable(o, PQ)
	o.cmp = cmp
	o.arr = {}
	o.len = 0
	return o
end

function PQ:push(v)
	print("push: ", v)
	self.len = self.len + 1
	self.arr[self.len] = v
	self:perc_up(self.len)
end

function PQ:perc_up(pos)
	if(pos == 1) then return end
	up = pos // 2
	if (self.cmp(self.arr[pos], self.arr[up])) then
		local tmp = self.arr[pos]
		self.arr[pos] = self.arr[up]
		self.arr[up] = tmp
		self:perc_up(up)
	end
end

function PQ:perc_down(pos)
	if pos > self.len then return end

	local l = self.arr[pos*2]
	local r = self.arr[(pos*2)+1]

	if l == nil and r == nil then
		return
	end


	local swap_pos = 0
	local swap_val = 0

	if (r == nil or self.cmp(l, r)) then
		swap_pos = pos*2
		swap_val = l
	else
		swap_pos = (pos*2)+1
		swap_val = r
	end

	if swap_val ~= nil and self.cmp(swap_val, self.arr[pos]) then
		self.arr[swap_pos] = self.arr[pos]
		self.arr[pos] = swap_val
		self:perc_down(swap_pos)
	end
end

function PQ:pop()
	if (self.len == 0) then return nil, "pq empty" end
	local out = self.arr[1]
	self.arr[1] = self.arr[self.len]
	self.arr[self.len] = nil
	self.len = self.len - 1
	self:perc_down(1)
	return out
end

return PQ
