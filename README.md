# YUE-router
Simple mapping of requests to actions.

Example:
```lua
local request = {
    host = "localhost",
    method = "GET",
    path = "/user/10"
}

local viewRoute = RegexRoute:new({
    method = { "GET" },
    pathPatterns = {
        "/user/{id:[0-9]*}"
    },
    parameters = {
      _action = "UserController:view"
    }
})

local deleteRoute = RegexRoute:new({
    method = { "DELETE" },
    pathPatterns = {
        "/user/{id:[0-9]*}"
    },
    parameters = {
      _action = "UserController:delete"
    }
})

local router = Router:new()
router:addRoute(viewRoute)
router:addRoute(deleteRoute)

local action, parameters = router:route(request)
print(action) -- "UserController:view"
print(parameters.id) -- "10"
```
