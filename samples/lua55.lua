-- expect: ok 5.5 42
-- Global declarations arrive in 5.5; after them, only declared names are visible.
global print
global <const> answer = 42
print("ok 5.5 " .. answer)
