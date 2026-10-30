-- expect: ok 5.4 3 1
-- <const> and <close> attributes arrive in 5.4.
local limit <const> = 3
local closed = 0
do
  local guard <close> = setmetatable({}, { __close = function() closed = closed + 1 end })
end
print("ok 5.4 " .. limit .. " " .. closed)
