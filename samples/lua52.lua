-- expect: ok 5.2 3
-- goto and labels arrive in 5.2.
local n = 0
::again::
n = n + 1
if n < 3 then goto again end
print("ok 5.2 " .. n)
