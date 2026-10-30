-- expect: ok 5.3 3 2
-- Floor division and bitwise operators arrive in 5.3.
print("ok 5.3 " .. (7 // 2) .. " " .. (6 & 3))
