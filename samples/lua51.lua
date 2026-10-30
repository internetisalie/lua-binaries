-- expect: ok 5.1 1,4,9
-- 5.1 has no syntax of its own over later versions; setfenv exists only in 5.1.
local squares = {}
for i = 1, 3 do squares[#squares + 1] = i * i end
local function read() return x end
setfenv(read, { x = table.concat(squares, ",") })
print("ok 5.1 " .. read())
